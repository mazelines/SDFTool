# GPU JFA 거리장 계산 설계

- **날짜**: 2026-06-06
- **브랜치**: GPU-preview
- **상태**: 승인됨 (구현 계획 대기)

## 1. 목표와 범위

현재 SDF 거리장 계산은 C++ `SDF_Cpp.GenerateSDF`의 8SSEDT 알고리즘(CPU)으로
처리된다. 8SSEDT는 패스 내 픽셀 간 순차 의존성이 있어 GPU 병렬화에 부적합하다.
이를 GPU 친화적인 **JFA(Jump Flooding Algorithm)** 로 교체해 wgpu(WGSL 컴퓨트)에서
실행하고, GPU를 못 쓰는 환경에서는 수정된 C++ 8SSEDT로 폴백한다.

### 범위에 포함
- 거리장 계산(`GenerateSDF`의 8SSEDT → GPU JFA)
- `threshold` / `spread` 파라미터를 GPU·CPU 양쪽에서 **정확히** 동작시키기
- 프리뷰 경로와 일괄 생성 경로 양쪽 통합

### 범위에서 제외
- `SDFLerp`(프레임 보간) — 기존 CPU 유지
- `make_Atlas`(아틀라스 합성, OpenCV) — 기존 CPU 유지

## 2. 결정 사항 (확정)

| 항목 | 결정 |
|---|---|
| 작업 범위 | 거리장 계산만 |
| GPU 백엔드 | wgpu (WGSL 컴퓨트, Vulkan/DX12/Metal) |
| 알고리즘 | 2-패스 JFA + JFA+1 (정확도 보정) |
| CPU 폴백 | 순수 C++ 모듈(OpenCV 의존 없음) 신규, NumPy in/out, pybind11+setuptools 빌드 |
| 출력 | threshold/spread를 실제 반영 (현재는 무시됨) |
| 모듈 인터페이스 | NumPy 배열 in → out (파일 I/O는 호출부가 담당) |

## 3. 아키텍처 (모듈 구조)

```
SDFTool/
├─ sdf_gpu/                  새 wgpu 컴퓨트 패키지 (자기완결적)
│  ├─ __init__.py            공개 API: compute_sdf(), is_gpu_available()
│  ├─ device.py              wgpu 어댑터/디바이스 지연 싱글톤 (headless)
│  ├─ jfa.py                 JFA 파이프라인: 버퍼 생성·디스패치·리드백
│  └─ shaders/
│     ├─ seed_init.wgsl      임계값으로 시드 초기화
│     ├─ jfa_step.wgsl       step별 8방향 전파 (핵심)
│     └─ resolve.wgsl        inside/outside 거리 → signed → [0,255]
├─ sdf_backend.py            디스패처: GPU 시도 → 실패 시 sdf_core 폴백
├─ Cpp_Core/sdf_core.cpp     순수 C++ 8SSEDT (OpenCV 없음), NumPy in/out
├─ Cpp_Core/setup.py         pybind11+setuptools 빌드 스크립트
└─ main.py                   호출부를 sdf_backend로 변경
```

### 경계 원칙
- `sdf_gpu`는 NumPy 배열만 안다. 파일/Qt/OpenCV를 모름 → 독립 테스트 가능,
  향후 GPU 셰이더 확장의 토대.
- `sdf_backend`는 "GPU냐 C++냐" 선택과 폴백만 책임진다.
- `main.py`는 파일 I/O(cv2)와 워크플로만 담당한다.

## 4. 컴포넌트 인터페이스

### sdf_gpu 공개 API
```python
def is_gpu_available() -> bool:
    """wgpu 어댑터 요청을 1회 시도(캐시). 성공하면 True."""

def compute_sdf(gray: np.ndarray,   # uint8 그레이스케일 (H, W)
                threshold: int,      # 0~255 이진화 기준
                spread: float        # 거리 정규화 범위(px)
                ) -> np.ndarray:     # uint8 SDF (H, W)
    """inside/outside 부호화 + [0,255] 정규화된 SDF 반환."""
```

### sdf_backend 디스패처
```python
def generate_distance_field(gray, threshold, spread) -> np.ndarray:
    if sdf_gpu.is_gpu_available():
        try:
            return sdf_gpu.compute_sdf(gray, threshold, spread)
        except Exception as e:
            print("GPU 실패, C++ 폴백:", e)
    return _cpp_fallback(gray, threshold, spread)
```

`_cpp_fallback`은 순수 C++ 모듈 `sdf_core`를 직접 호출:
`sdf_core.compute_sdf(gray, threshold, spread)` → uint8 배열 반환. 파일 브리지
불필요. 기존 `SDF_Cpp.pyd`(OpenCV 의존)는 `SDFLerp`용으로 그대로 유지하며 재빌드
하지 않는다.

### 왜 순수 C++ 모듈인가 (환경 검증 결과)
기존 `8ssedt.cpp`는 OpenCV(imread/imwrite/cvtColor)에 의존하지만, 거리장 계산
코어(`Grid`, `GenerateDistanceField`)는 순수 C++/std다. 우리 설계가 I/O를 Python으로
옮겼으므로, 폴백을 NumPy 배열을 직접 받는 OpenCV-free 모듈로 만들면 빌드에
**pybind11(pip) + Python310 + MSVC**만 필요하다. 이 머신에서 OpenCV C++ SDK와
하드코딩 경로가 없어 기존 프로젝트는 재빌드 불가였으나, 순수 C++ 모듈은 최소 POC로
빌드·로드가 검증되었다(setuptools가 VS18 MSVC 자동 감지).

## 5. threshold·spread 공유 계약

GPU와 C++가 동일 출력을 내기 위한 단일 정의. 양쪽이 동일하게 구현한다.

- **threshold** (0~255): `pixel < threshold` → inside, 그 외 → outside.
  - C++ `sdf_core.cpp`의 시드 분류에서 `pixel < threshold` (8SSEDT 코어를 lift).
- **spread** (px): signed 거리 `d`(px)를 다음 식으로 매핑.
  ```
  c = clamp(round(128 + (d / spread) * 127), 0, 255)
  ```
  d=0 → 128, d=+spread → 255, d=−spread → ≈0.
  - C++ `sdf_core.cpp`의 최종 매핑에서 위 식 사용.
  - GPU `resolve.wgsl`도 동일 식 사용.
- C++ 노출 함수: `sdf_core.compute_sdf(gray, threshold, spread)` → uint8 배열 (pybind11).
  기존 `8ssedt.cpp`는 수정하지 않는다.

## 6. 데이터 흐름

두 호출 경로 모두 "cv2 읽기 → gray → `generate_distance_field` → cv2 쓰기"로 통일.

### ① 프리뷰 (`generate_sdf_preview_result`, main.py:242)
- 이미 threshold/spread를 받음 → 백엔드에 전달(현재 무시되던 게 살아남).
- `SDF_Cpp.GenerateSDF` 호출(main.py:255)을 백엔드 호출로 교체, 결과 배열을
  `output/<stem>.png`로 저장.
- 뒤따르는 `SDFLerp`(보간)는 범위 밖 — 그대로 유지.

### ② 일괄 생성 (`generate_sdf_result` → `lerp_SDF` → `SDF_Generate`, main.py:286/60/48)
- 문제: 이 경로엔 threshold/spread 인자가 없음. QML 슬롯 `generateSDF(path)`
  (main.py:382), `generateSDFAsync(path)`(main.py:390)도 path만 받음.
- 해결: 슬롯과 그 아래 함수 체인에 `threshold, spread` 인자 추가 → UI(프리뷰와
  같은 컨트롤)에서 전달. 폴더 내 각 파일을 백엔드로 처리.

### 흐름 요약
```
QML(threshold, spread) → main 슬롯 → cv2.imread → gray(uint8)
   → sdf_backend.generate_distance_field(gray, threshold, spread)
        ├─ GPU 가능: sdf_gpu.compute_sdf (JFA, wgpu)
        └─ 폴백: sdf_core (순수 C++, 배열 직접)
   → sdf(uint8) → cv2.imwrite → (이후 SDFLerp/아틀라스는 기존대로)
```

## 7. JFA 알고리즘 상세 (2-패스 + JFA+1)

`sdf_gpu/jfa.py`가 디스패치를 오케스트레이션, 셰이더 3종이 계산.

### 버퍼 구성 (storage buffer)
- `input`: gray → R8 또는 u32 패킹 (H×W)
- `seedA`, `seedB`: ping-pong 시드 좌표 버퍼. 각 픽셀이 `vec2<i32>`(최근접 시드
  좌표) 저장. inside용·outside용 각각 실행.
- `output`: 최종 uint8 SDF (H×W)
- `params`: uniform — width, height, threshold, spread

### 패스 구성
1. **seed_init.wgsl**: `input`을 읽어 `pixel < threshold`면 inside 시드(자기 좌표),
   아니면 무효(`empty`=큰 값). outside는 조건 반전.
2. **jfa_step.wgsl** (핵심, 루프 디스패치): step = `N/2, N/4, … 1`,
   `ceil(log2(max(W,H)))` 회. 각 픽셀이 8방향 `±step` 이웃 시드 중 더 가까운 것으로
   갱신. ping↔pong 교대. inside·outside 각각 실행(2-패스).
3. **JFA+1**: step=1 패스 1회 추가 → 잔여 오차 제거.
4. **resolve.wgsl**: inside 거리 `d1=|p−seed_in|`, outside 거리 `d2=|p−seed_out|`,
   signed `d = d2 − d1`. 섹션 5 계약식으로 [0,255] 매핑.

### 디스패치
- 워크그룹 `8×8`, 그리드 `ceil(W/8)×ceil(H/8)`.
- 패스 수 ≈ `2·ceil(log2(N)) + 2`. 1024px이면 약 22 디스패치 — GPU에서 수 ms.

### 리드백
`output` 버퍼 → staging buffer 매핑 → `np.frombuffer` → `(H,W)` reshape.

## 8. 에러 처리 / 폴백 트리거

`generate_distance_field`가 GPU→C++ 폴백을 발동하는 경우:
- `sdf_gpu` import 실패 (wgpu 미설치)
- `is_gpu_available()` False (어댑터 요청 실패 — 드라이버/VM/RDP)
- `compute_sdf` 실행 중 예외 (디바이스 로스트, OOM 등)

폴백 발동 시 `print`로 사유 로깅(기존 코드 스타일 일치). `is_gpu_available()`
결과는 1회 캐시(매 호출 어댑터 재요청 방지). 입력 검증: gray가 None/빈 배열이면
명확한 에러 반환(기존 `inspect_image_folder` unreadable 처리와 정합).

## 9. 테스트 / 검증

- **단위 테스트** (`sdf_gpu` 독립): 합성 입력(원, 사각형)에 대해 `compute_sdf`
  출력 거리장이 해석적 정답과 오차 ≤2/255 인지.
- **GPU↔C++ 동등성**: 동일 입력·동일 threshold/spread로 GPU 출력과 `sdf_core`
  출력 비교, 평균 절대 오차 임계치 내인지(JFA 근사 → 픽셀 단위 완전 일치는 아님,
  허용 오차 명시).
- **회귀**: 기존 샘플로 디폴트 파라미터 출력이 기존과 시각적으로 동일한지.
- **폴백 경로**: wgpu 강제 비활성(환경변수/몽키패치)으로 C++ 폴백 동일 결과 확인.

## 10. 패키징 / 빌드 전제

- **의존성**: `wgpu`(wgpu-py)를 `requirements.txt`에 추가.
- **PyInstaller**: `SDFTool.spec`에 wgpu 네이티브 라이브러리(`wgpu_native` `.dll`)와
  WGSL 셰이더(`sdf_gpu/shaders/*.wgsl`), 그리고 빌드된 `sdf_core.*.pyd`를
  `datas`/`binaries`로 포함. 빌드 후 dist에서 GPU·폴백 양 경로 스모크 테스트.
- **C++ 빌드 (검증 완료)**: `sdf_core`는 `Cpp_Core/setup.py`로
  `py -3.10 setup.py build_ext --inplace` 빌드. 의존성은 pybind11(pip) + Python310
  + MSVC뿐 — OpenCV C++ SDK 불필요. 이 머신에서 setuptools가 VS18 MSVC 14.51을
  자동 감지해 순수 C++ pybind11 모듈을 빌드·로드함을 최소 POC로 확인함.
  기존 `SDF_Cpp.pyd`(OpenCV 의존, `SDFLerp`용)는 재빌드하지 않음.
- **런타임**: `QT_QUICK_BACKEND=software`(UI)와 wgpu(컴퓨트)는 독립 — 충돌 없음.

## 11. 미해결 리스크

1. ~~C++ 빌드 툴체인 검증~~ → **해결됨**. 순수 C++ pybind11 모듈이 이 머신에서
   빌드·로드됨을 POC로 확인(pybind11 3.0.4, Python 3.10.11, VS18 MSVC 14.51).
   기존 OpenCV 의존 프로젝트는 OpenCV SDK·하드코딩 경로 부재로 재빌드 불가였으나,
   폴백을 OpenCV-free `sdf_core`로 전환해 회피.
2. JFA는 근사 알고리즘 — 동등성 테스트의 허용 오차를 실측으로 확정해야 함.
3. wgpu-py의 PyInstaller 동봉 절차(네이티브 .dll 경로)는 빌드 시 실측 필요.
4. spread 디폴트값: 기존 C++ 스케일 1.0과 시각적으로 맞는 값을 회귀로 정해야 함.
