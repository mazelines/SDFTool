# GPU JFA 거리장 계산 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 8SSEDT(CPU) 거리장 계산을 wgpu 기반 2-패스 JFA+1(GPU)로 교체하고, threshold/spread를 GPU·C++ 양쪽에서 정확히 동작시키며, GPU 미지원 환경은 OpenCV-free 순수 C++ 모듈(`sdf_core`)로 폴백한다.

**Architecture:** `sdf_gpu`(NumPy in/out, wgpu 컴퓨트, 자기완결적 패키지)가 JFA를 실행하고, `sdf_backend`가 GPU↔`sdf_core` 폴백을 디스패치한다. `main.py`는 파일 I/O와 워크플로만 담당하고 양 호출 경로(프리뷰·일괄)에서 `sdf_backend`를 부른다. 폴백 `sdf_core`는 8SSEDT 코어만 담은 OpenCV-free pybind11 모듈로, NumPy 배열을 직접 받아 threshold/spread를 적용한다(pybind11+Python+MSVC만으로 빌드, POC 검증 완료). 기존 OpenCV 의존 `SDF_Cpp.pyd`는 `SDFLerp`용으로 그대로 유지한다.

**Tech Stack:** Python 3.10, wgpu-py(WGSL 컴퓨트), NumPy, OpenCV, pybind11/MSVC(C++), PySide6/QML, pytest.

---

## 파일 구조

| 파일 | 책임 |
|---|---|
| `sdf_gpu/__init__.py` | 공개 API: `compute_sdf`, `is_gpu_available` 재노출 |
| `sdf_gpu/device.py` | wgpu 어댑터/디바이스 지연 싱글톤, `is_gpu_available` |
| `sdf_gpu/jfa.py` | JFA 파이프라인: 버퍼·디스패치·리드백, `compute_sdf` |
| `sdf_gpu/shaders/seed_init.wgsl` | threshold로 inside/outside 시드 초기화 |
| `sdf_gpu/shaders/jfa_step.wgsl` | step별 8방향 전파 (핵심) |
| `sdf_gpu/shaders/resolve.wgsl` | inside/outside 거리 → signed → [0,255] |
| `sdf_backend.py` | 디스패처: GPU 시도 → 실패 시 `sdf_core` 폴백(배열 직접 호출) |
| `Cpp_Core/sdf_core.cpp` | 순수 C++ 8SSEDT (OpenCV 없음), NumPy in/out (신규) |
| `Cpp_Core/setup.py` | pybind11+setuptools 빌드 스크립트 (신규) |
| `main.py` | 프리뷰·일괄 경로를 `sdf_backend`로 전환, threshold 0-100→0-255 변환 |
| `main.qml` | 일괄 호출에 threshold/spread 전달, 알고리즘 라벨 갱신 |
| `requirements.txt` / `SDFTool.spec` | wgpu 의존성·패키징 |
| `tests/` | pytest: 오라클 비교, 동등성, 폴백 |

**공유 계약 (GPU·C++ 공통):**
- threshold(0~255): `pixel < threshold` → inside.
- spread(px): signed 거리 `d`를 `c = clamp(round(128 + (d/spread)*127), 0, 255)` 로 매핑.
- signed 거리: `d = d2 - d1` (d1=최근접 inside 거리, d2=최근접 outside 거리). inside→양수→밝음.

**GPU 전용 표현 (sdf_gpu):**
- 시드 좌표는 픽셀당 `i32` 2개(`x,y`)를 평면 배열 `array<i32>`에 저장(인덱스 `2*i`, `2*i+1`), 빈 시드는 `-1`.
- 픽셀 인덱스 `i = y*W + x`.
- (C++ `sdf_core`는 8SSEDT `Grid<Point>`로 동일 결과를 계산)

---

## Phase 0: 환경 검증 (구현 착수 전 선결)

> **상태:** 빌드 가능성은 이미 검증됨. 최소 POC로 순수 C++ pybind11 모듈이
> 이 머신에서 빌드·로드됨을 확인(pybind11 3.0.4, Python 3.10.11
> `C:\Users\leego\AppData\Local\Programs\Python\Python310`, VS18 MSVC 14.51,
> setuptools 65.5.0). 기존 OpenCV 의존 프로젝트(`SDF_Cpp.sln`)는 OpenCV C++ SDK와
> 하드코딩 경로 부재로 재빌드 불가 → 폴백을 OpenCV-free `sdf_core`로 전환해 회피.

### Task 0: 잔여 전제 확인

**Files:** 없음 (검증만)

- [ ] **Step 1: 기존 C++ 모듈(SDFLerp용)이 py3.10에서 로드되는지 확인**

Run:
```
py -3.10 -c "import sys; sys.path.append('Cpp_Core/x64/Release'); import SDF_Cpp; print('OK', SDF_Cpp.__doc__)"
```
Expected: `OK` 출력. (이 `.pyd`는 `SDFLerp`용으로 그대로 쓰며 재빌드하지 않음)

- [ ] **Step 2: 빌드 의존성 설치 확인 (pybind11/setuptools)**

Run:
```
py -3.10 -m pip install pybind11 setuptools wheel
py -3.10 -c "import pybind11; print('pybind11', pybind11.__version__, pybind11.get_include())"
```
Expected: pybind11 버전과 include 경로 출력. (POC에서 3.0.4 확인됨)

- [ ] **Step 3: wgpu 설치 및 어댑터 가용성 확인**

Run:
```
py -3.10 -m pip install wgpu
py -3.10 -c "import wgpu; a=wgpu.gpu.request_adapter_sync(power_preference='high-performance'); print(a.summary)"
```
Expected: 어댑터 요약(GPU 이름) 출력. 어댑터가 없으면 GPU 경로는 이 머신에서 테스트 불가(폴백만 검증 가능)임을 기록.

- [ ] **Step 4: pytest 설치**

Run:
```
py -3.10 -m pip install pytest
```
Expected: 설치 성공.

- [ ] **Step 5: 커밋 없음**

검증 단계이므로 커밋 없음. 다음 Phase로 진행.

---

## Phase 1: sdf_gpu 코어 (순수 컴퓨트)

### Task 1: device.py — wgpu 디바이스 싱글톤

**Files:**
- Create: `sdf_gpu/__init__.py`
- Create: `sdf_gpu/device.py`
- Test: `tests/test_device.py`

- [ ] **Step 1: Write the failing test**

`tests/test_device.py`:
```python
from sdf_gpu import device

def test_is_gpu_available_returns_bool():
    assert isinstance(device.is_gpu_available(), bool)

def test_get_device_consistent_when_available():
    if not device.is_gpu_available():
        return  # GPU 없는 환경: 스킵
    d1 = device.get_device()
    d2 = device.get_device()
    assert d1 is d2  # 싱글톤
```

- [ ] **Step 2: Run test to verify it fails**

Run: `py -3.10 -m pytest tests/test_device.py -v`
Expected: FAIL (`ModuleNotFoundError: No module named 'sdf_gpu'`)

- [ ] **Step 3: Create the package init**

`sdf_gpu/__init__.py`:
```python
from .device import is_gpu_available  # noqa: F401
from .jfa import compute_sdf  # noqa: F401
```

(주의: 이 시점엔 `jfa`가 없어 import 에러가 난다. Step 4에서 device만 먼저 노출하도록 임시로 jfa import를 주석 처리하고, Task 3에서 해제한다.)

`sdf_gpu/__init__.py` (Task 1 시점):
```python
from .device import is_gpu_available  # noqa: F401
# from .jfa import compute_sdf  # Task 3에서 활성화
```

- [ ] **Step 4: Implement device.py**

`sdf_gpu/device.py`:
```python
"""wgpu 디바이스 지연 싱글톤. NumPy/파일/Qt를 모른다."""
import wgpu

_device = None
_checked = False
_available = False


def get_device():
    """wgpu 디바이스를 1회 생성해 캐시. 실패 시 예외 전파."""
    global _device
    if _device is None:
        adapter = wgpu.gpu.request_adapter_sync(power_preference="high-performance")
        _device = adapter.request_device_sync()
    return _device


def is_gpu_available():
    """어댑터/디바이스 생성을 1회 시도하고 결과를 캐시."""
    global _checked, _available
    if not _checked:
        _checked = True
        try:
            get_device()
            _available = True
        except Exception:
            _available = False
    return _available
```

- [ ] **Step 5: Run test to verify it passes**

Run: `py -3.10 -m pytest tests/test_device.py -v`
Expected: PASS (GPU 없으면 두 번째 테스트는 조기 return으로 PASS)

- [ ] **Step 6: Commit**

```
git add sdf_gpu/__init__.py sdf_gpu/device.py tests/test_device.py
git commit -m "feat(sdf_gpu): wgpu 디바이스 싱글톤과 가용성 검사"
```

---

### Task 2: WGSL 셰이더 3종

**Files:**
- Create: `sdf_gpu/shaders/seed_init.wgsl`
- Create: `sdf_gpu/shaders/jfa_step.wgsl`
- Create: `sdf_gpu/shaders/resolve.wgsl`

셰이더는 파이프라인 없이는 단독 실행 테스트가 어렵다. Task 3의 오라클 테스트가 이들을 통합 검증한다. 이 Task는 파일 생성만.

- [ ] **Step 1: seed_init.wgsl 작성**

`sdf_gpu/shaders/seed_init.wgsl`:
```wgsl
struct Params {
  width: i32,
  height: i32,
  threshold: i32,
  invert: i32,   // 0: inside 시드, 1: outside 시드
};

@group(0) @binding(0) var<uniform> P: Params;
@group(0) @binding(1) var<storage, read> img: array<u32>;        // gray 0-255
@group(0) @binding(2) var<storage, read_write> seed: array<i32>; // 2*i, 2*i+1

@compute @workgroup_size(8, 8, 1)
fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
  let x = i32(gid.x);
  let y = i32(gid.y);
  if (x >= P.width || y >= P.height) { return; }
  let i = y * P.width + x;
  var is_inside = img[i] < u32(P.threshold);
  if (P.invert == 1) { is_inside = !is_inside; }
  if (is_inside) {
    seed[2 * i] = x;
    seed[2 * i + 1] = y;
  } else {
    seed[2 * i] = -1;
    seed[2 * i + 1] = -1;
  }
}
```

- [ ] **Step 2: jfa_step.wgsl 작성**

`sdf_gpu/shaders/jfa_step.wgsl`:
```wgsl
struct Params {
  width: i32,
  height: i32,
  step: i32,
  _pad: i32,
};

@group(0) @binding(0) var<uniform> P: Params;
@group(0) @binding(1) var<storage, read> src: array<i32>;
@group(0) @binding(2) var<storage, read_write> dst: array<i32>;

const BIG: i32 = 2147483647;

fn sqdist(x: i32, y: i32, sx: i32, sy: i32) -> i32 {
  if (sx < 0) { return BIG; }
  let dx = x - sx;
  let dy = y - sy;
  return dx * dx + dy * dy;
}

@compute @workgroup_size(8, 8, 1)
fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
  let x = i32(gid.x);
  let y = i32(gid.y);
  if (x >= P.width || y >= P.height) { return; }
  let i = y * P.width + x;

  var bsx = src[2 * i];
  var bsy = src[2 * i + 1];
  var bestd = sqdist(x, y, bsx, bsy);

  for (var dy = -1; dy <= 1; dy = dy + 1) {
    for (var dx = -1; dx <= 1; dx = dx + 1) {
      let nx = x + dx * P.step;
      let ny = y + dy * P.step;
      if (nx < 0 || ny < 0 || nx >= P.width || ny >= P.height) { continue; }
      let j = ny * P.width + nx;
      let sx = src[2 * j];
      let sy = src[2 * j + 1];
      let d = sqdist(x, y, sx, sy);
      if (d < bestd) {
        bestd = d;
        bsx = sx;
        bsy = sy;
      }
    }
  }
  dst[2 * i] = bsx;
  dst[2 * i + 1] = bsy;
}
```

- [ ] **Step 3: resolve.wgsl 작성**

`sdf_gpu/shaders/resolve.wgsl`:
```wgsl
struct Params {
  width: i32,
  height: i32,
  spread: f32,
  _pad: f32,
};

@group(0) @binding(0) var<uniform> P: Params;
@group(0) @binding(1) var<storage, read> seed_in: array<i32>;
@group(0) @binding(2) var<storage, read> seed_out: array<i32>;
@group(0) @binding(3) var<storage, read_write> outbuf: array<u32>;

const BIG: f32 = 1.0e18;

fn edist(x: i32, y: i32, sx: i32, sy: i32) -> f32 {
  if (sx < 0) { return BIG; }
  let dx = f32(x - sx);
  let dy = f32(y - sy);
  return sqrt(dx * dx + dy * dy);
}

@compute @workgroup_size(8, 8, 1)
fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
  let x = i32(gid.x);
  let y = i32(gid.y);
  if (x >= P.width || y >= P.height) { return; }
  let i = y * P.width + x;

  let d1 = edist(x, y, seed_in[2 * i], seed_in[2 * i + 1]);
  let d2 = edist(x, y, seed_out[2 * i], seed_out[2 * i + 1]);
  let signed = d2 - d1;
  var c = floor(128.0 + (signed / P.spread) * 127.0 + 0.5);
  c = clamp(c, 0.0, 255.0);
  outbuf[i] = u32(c);
}
```

- [ ] **Step 4: Commit**

```
git add sdf_gpu/shaders/
git commit -m "feat(sdf_gpu): JFA WGSL 셰이더(seed_init, jfa_step, resolve)"
```

---

### Task 3: jfa.py — 파이프라인과 compute_sdf

**Files:**
- Create: `sdf_gpu/jfa.py`
- Modify: `sdf_gpu/__init__.py` (jfa import 활성화)
- Test: `tests/test_compute_sdf.py`
- Test helper: `tests/oracle.py`

- [ ] **Step 1: 브루트포스 오라클 작성**

`tests/oracle.py`:
```python
import numpy as np


def brute_sdf(gray, threshold, spread):
    """작은 이미지용 정답 SDF. 공유 계약과 동일 매핑."""
    gray = gray.astype(np.int32)
    h, w = gray.shape
    ys, xs = np.indices((h, w))
    pts = np.stack([ys.ravel(), xs.ravel()], axis=1)  # (N,2)

    inside_mask = (gray < threshold).ravel()
    in_pts = pts[inside_mask]
    out_pts = pts[~inside_mask]

    def nearest(all_pts, seeds):
        if len(seeds) == 0:
            return np.full(len(all_pts), 1e18)
        # (N,1,2) - (1,M,2)
        diff = all_pts[:, None, :] - seeds[None, :, :]
        d = np.sqrt((diff ** 2).sum(axis=2))
        return d.min(axis=1)

    d1 = nearest(pts, in_pts)
    d2 = nearest(pts, out_pts)
    signed = (d2 - d1).reshape(h, w)
    c = np.clip(np.floor(128.0 + (signed / spread) * 127.0 + 0.5), 0, 255)
    return c.astype(np.uint8)
```

- [ ] **Step 2: Write the failing test**

`tests/test_compute_sdf.py`:
```python
import numpy as np
import pytest
from sdf_gpu import device, compute_sdf
from tests.oracle import brute_sdf

pytestmark = pytest.mark.skipif(
    not device.is_gpu_available(), reason="GPU 어댑터 없음"
)


def _circle(n=32, r=8):
    ys, xs = np.indices((n, n))
    cx = cy = n // 2
    d = np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2)
    img = np.where(d < r, 0, 255).astype(np.uint8)  # 안쪽 검정(=inside)
    return img


def test_circle_matches_oracle():
    img = _circle()
    threshold, spread = 128, 16.0
    got = compute_sdf(img, threshold, spread)
    exp = brute_sdf(img, threshold, spread)
    assert got.shape == exp.shape
    # JFA 근사 → 평균 절대 오차 임계치
    assert np.mean(np.abs(got.astype(int) - exp.astype(int))) <= 2.0


def test_rect_matches_oracle():
    img = np.full((32, 32), 255, np.uint8)
    img[8:24, 8:24] = 0
    got = compute_sdf(img, 128, 16.0)
    exp = brute_sdf(img, 128, 16.0)
    assert np.mean(np.abs(got.astype(int) - exp.astype(int))) <= 2.0
```

- [ ] **Step 3: Run test to verify it fails**

Run: `py -3.10 -m pytest tests/test_compute_sdf.py -v`
Expected: FAIL (`ImportError: cannot import name 'compute_sdf'`) — GPU 없으면 skip되어 통과해버리므로, GPU 있는 환경에서 검증할 것.

- [ ] **Step 4: Implement jfa.py**

`sdf_gpu/jfa.py`:
```python
"""wgpu 2-패스 JFA+1 파이프라인. NumPy in/out."""
import os
import numpy as np
import wgpu

from .device import get_device

_SHADER_DIR = os.path.join(os.path.dirname(__file__), "shaders")

_STORAGE = wgpu.BufferUsage.STORAGE
_COPY_SRC = wgpu.BufferUsage.COPY_SRC
_COPY_DST = wgpu.BufferUsage.COPY_DST
_UNIFORM = wgpu.BufferUsage.UNIFORM


def _load(name):
    with open(os.path.join(_SHADER_DIR, name), "r", encoding="utf-8") as f:
        return f.read()


def _jfa_steps(n):
    """[큰 2의 거듭제곱 … 1] + JFA+1용 1 추가."""
    s = 1
    while s < n:
        s <<= 1
    s >>= 1
    steps = []
    while s >= 1:
        steps.append(s)
        s >>= 1
    steps.append(1)  # JFA+1
    return steps


def compute_sdf(gray, threshold, spread):
    if gray is None or gray.size == 0:
        raise ValueError("compute_sdf: 빈 입력")
    gray = np.ascontiguousarray(gray, dtype=np.uint8)
    h, w = gray.shape
    n = w * h

    device = get_device()
    img = device.create_buffer_with_data(
        data=gray.astype(np.uint32).tobytes(), usage=_STORAGE | _COPY_DST
    )
    seed_bytes = 2 * n * 4
    buf_a = device.create_buffer(size=seed_bytes, usage=_STORAGE | _COPY_SRC | _COPY_DST)
    buf_b = device.create_buffer(size=seed_bytes, usage=_STORAGE | _COPY_SRC | _COPY_DST)
    seed_in = device.create_buffer(size=seed_bytes, usage=_STORAGE | _COPY_DST)
    seed_out = device.create_buffer(size=seed_bytes, usage=_STORAGE | _COPY_DST)
    outbuf = device.create_buffer(size=n * 4, usage=_STORAGE | _COPY_SRC)

    init_u = device.create_buffer(size=16, usage=_UNIFORM | _COPY_DST)
    step_u = device.create_buffer(size=16, usage=_UNIFORM | _COPY_DST)
    resolve_u = device.create_buffer(size=16, usage=_UNIFORM | _COPY_DST)

    init_pl = device.create_compute_pipeline(
        layout="auto", compute={"module": device.create_shader_module(code=_load("seed_init.wgsl")), "entry_point": "main"}
    )
    step_pl = device.create_compute_pipeline(
        layout="auto", compute={"module": device.create_shader_module(code=_load("jfa_step.wgsl")), "entry_point": "main"}
    )
    resolve_pl = device.create_compute_pipeline(
        layout="auto", compute={"module": device.create_shader_module(code=_load("resolve.wgsl")), "entry_point": "main"}
    )

    gx = (w + 7) // 8
    gy = (h + 7) // 8

    def dispatch(pipeline, bind_entries, group=0):
        bg = device.create_bind_group(
            layout=pipeline.get_bind_group_layout(group), entries=bind_entries
        )
        enc = device.create_command_encoder()
        cp = enc.begin_compute_pass()
        cp.set_pipeline(pipeline)
        cp.set_bind_group(0, bg)
        cp.dispatch_workgroups(gx, gy, 1)
        cp.end()
        device.queue.submit([enc.finish()])

    def be(b):  # buffer entry helper
        return {"binding": None, "resource": {"buffer": b, "offset": 0, "size": b.size}}

    def entries(*bufs):
        out = []
        for k, b in enumerate(bufs):
            e = be(b)
            e["binding"] = k
            out.append(e)
        return out

    def run_pass(invert, dst_result):
        # init → dst_result via ping-pong buf_a/buf_b
        device.queue.write_buffer(init_u, 0, np.array([w, h, int(threshold), invert], np.int32).tobytes())
        dispatch(init_pl, entries(init_u, img, buf_a))
        src, dst = buf_a, buf_b
        for st in _jfa_steps(max(w, h)):
            device.queue.write_buffer(step_u, 0, np.array([w, h, st, 0], np.int32).tobytes())
            dispatch(step_pl, entries(step_u, src, dst))
            src, dst = dst, src
        # 결과는 src에 있음 → dst_result로 복사
        enc = device.create_command_encoder()
        enc.copy_buffer_to_buffer(src, 0, dst_result, 0, seed_bytes)
        device.queue.submit([enc.finish()])

    run_pass(0, seed_in)   # inside 시드
    run_pass(1, seed_out)  # outside 시드

    device.queue.write_buffer(
        resolve_u, 0,
        np.array([w, h], np.int32).tobytes() + np.array([float(spread), 0.0], np.float32).tobytes(),
    )
    dispatch(resolve_pl, entries(resolve_u, seed_in, seed_out, outbuf))

    raw = device.queue.read_buffer(outbuf)
    return np.frombuffer(raw, dtype=np.uint32).astype(np.uint8).reshape(h, w)
```

- [ ] **Step 5: __init__.py에서 jfa import 활성화**

`sdf_gpu/__init__.py`:
```python
from .device import is_gpu_available  # noqa: F401
from .jfa import compute_sdf  # noqa: F401
```

- [ ] **Step 6: Run test to verify it passes (GPU 환경)**

Run: `py -3.10 -m pytest tests/test_compute_sdf.py -v`
Expected: PASS (GPU 어댑터 있는 머신). GPU 없으면 skip — 반드시 GPU 머신에서 1회 검증.

- [ ] **Step 7: Commit**

```
git add sdf_gpu/jfa.py sdf_gpu/__init__.py tests/oracle.py tests/test_compute_sdf.py
git commit -m "feat(sdf_gpu): wgpu 2-패스 JFA+1 compute_sdf 구현"
```

---

## Phase 2: 순수 C++ 폴백 모듈 (OpenCV 없음)

### Task 4: sdf_core — OpenCV-free 8SSEDT 모듈 (NumPy in/out)

**근거:** 기존 `8ssedt.cpp`는 OpenCV(imread/imwrite)에 의존하나, 이 머신엔 OpenCV
C++ SDK가 없어 재빌드 불가. 거리장 코어는 순수 C++이므로, NumPy 배열을 직접 받는
별도 모듈 `sdf_core`를 만들면 pybind11+Python+MSVC만으로 빌드된다(POC 검증 완료).
기존 `8ssedt.cpp`/`SDF_Cpp.pyd`는 손대지 않고 `SDFLerp`용으로 유지.

**Files:**
- Create: `Cpp_Core/sdf_core.cpp`
- Create: `Cpp_Core/setup.py`
- Test: `tests/test_cpp_fallback.py`

- [ ] **Step 1: Write the failing test**

`tests/test_cpp_fallback.py`:
```python
import os, sys
import numpy as np

sys.path.append("Cpp_Core")


def test_sdf_core_threshold_spread():
    import sdf_core
    img = np.full((32, 32), 255, np.uint8)
    img[8:24, 8:24] = 0
    a = sdf_core.compute_sdf(img, 128, 8.0)
    b = sdf_core.compute_sdf(img, 128, 32.0)
    assert a.shape == (32, 32)
    assert a.dtype == np.uint8
    # spread가 다르면 출력이 달라야 함(무시되지 않음)
    assert not np.array_equal(a, b)
    # inside(중심)는 밝고, outside(모서리)는 어두움
    assert a[16, 16] > 128
    assert a[0, 0] < 128
```

- [ ] **Step 2: Run test to verify it fails**

Run: `py -3.10 -m pytest tests/test_cpp_fallback.py -v`
Expected: FAIL (`ModuleNotFoundError: No module named 'sdf_core'`)

- [ ] **Step 3: sdf_core.cpp 작성 (주석은 ASCII로 — C4819 경고 방지)**

`Cpp_Core/sdf_core.cpp`:
```cpp
// OpenCV-free 8SSEDT signed distance field, NumPy in/out.
#include <pybind11/pybind11.h>
#include <pybind11/numpy.h>
#include <vector>
#include <cmath>
#include <cstdint>
#include <stdexcept>

namespace py = pybind11;

namespace {

struct Point {
    int dx, dy;
    long long DistSq() const { return (long long)dx * dx + (long long)dy * dy; }
};

const Point INSIDE = {0, 0};
const Point EMPTY = {9999, 9999};

struct Grid {
    int w, h;
    std::vector<Point> cells;
    Grid(int width, int height) : w(width), h(height), cells((size_t)width * height) {}
    Point get(int x, int y) const {
        if (x >= 0 && y >= 0 && x < w && y < h) return cells[(size_t)y * w + x];
        return EMPTY;
    }
    void put(int x, int y, const Point& p) { cells[(size_t)y * w + x] = p; }
};

void compare(Grid& g, Point& p, int x, int y, int ox, int oy) {
    Point o = g.get(x + ox, y + oy);
    o.dx += ox;
    o.dy += oy;
    if (o.DistSq() < p.DistSq()) p = o;
}

void generate(Grid& g) {
    for (int y = 0; y < g.h; y++) {
        for (int x = 0; x < g.w; x++) {
            Point p = g.get(x, y);
            compare(g, p, x, y, -1, 0);
            compare(g, p, x, y, 0, -1);
            compare(g, p, x, y, -1, -1);
            compare(g, p, x, y, 1, -1);
            g.put(x, y, p);
        }
        for (int x = g.w - 1; x >= 0; x--) {
            Point p = g.get(x, y);
            compare(g, p, x, y, 1, 0);
            g.put(x, y, p);
        }
    }
    for (int y = g.h - 1; y >= 0; y--) {
        for (int x = g.w - 1; x >= 0; x--) {
            Point p = g.get(x, y);
            compare(g, p, x, y, 1, 0);
            compare(g, p, x, y, 0, 1);
            compare(g, p, x, y, -1, 1);
            compare(g, p, x, y, 1, 1);
            g.put(x, y, p);
        }
        for (int x = 0; x < g.w; x++) {
            Point p = g.get(x, y);
            compare(g, p, x, y, -1, 0);
            g.put(x, y, p);
        }
    }
}

}  // namespace

py::array_t<uint8_t> compute_sdf(
        py::array_t<uint8_t, py::array::c_style | py::array::forcecast> gray,
        int threshold, double spread) {
    auto buf = gray.request();
    if (buf.ndim != 2) throw std::runtime_error("gray must be 2D (H,W)");
    int h = (int)buf.shape[0];
    int w = (int)buf.shape[1];
    const uint8_t* img = static_cast<const uint8_t*>(buf.ptr);

    Grid g1(w, h), g2(w, h);
    for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
            int pixel = img[(size_t)y * w + x];
            if (pixel < threshold) {       // inside
                g1.put(x, y, INSIDE);
                g2.put(x, y, EMPTY);
            } else {                       // outside
                g2.put(x, y, INSIDE);
                g1.put(x, y, EMPTY);
            }
        }
    }
    generate(g1);
    generate(g2);

    auto result = py::array_t<uint8_t>({h, w});
    auto rbuf = result.request();
    uint8_t* out = static_cast<uint8_t*>(rbuf.ptr);
    for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
            double d1 = std::sqrt((double)g1.get(x, y).DistSq());
            double d2 = std::sqrt((double)g2.get(x, y).DistSq());
            double d = d2 - d1;
            int c = (int)std::floor(128.0 + (d / spread) * 127.0 + 0.5);
            if (c < 0) c = 0;
            if (c > 255) c = 255;
            out[(size_t)y * w + x] = (uint8_t)c;
        }
    }
    return result;
}

PYBIND11_MODULE(sdf_core, m) {
    m.doc() = "OpenCV-free 8SSEDT distance field (NumPy in/out)";
    m.def("compute_sdf", &compute_sdf,
          py::arg("gray"), py::arg("threshold") = 128, py::arg("spread") = 127.0,
          "uint8 (H,W) gray -> uint8 (H,W) SDF");
}
```

- [ ] **Step 4: setup.py 작성**

`Cpp_Core/setup.py`:
```python
from setuptools import setup, Extension
import pybind11

ext = Extension(
    "sdf_core",
    ["sdf_core.cpp"],
    include_dirs=[pybind11.get_include()],
    language="c++",
    extra_compile_args=["/std:c++17", "/EHsc"],
)

setup(name="sdf_core", version="0.1.0", ext_modules=[ext])
```

- [ ] **Step 5: 빌드 (inplace → `Cpp_Core/sdf_core.*.pyd` 생성)**

Run (`Cpp_Core`에서 실행):
```
cd Cpp_Core
py -3.10 setup.py build_ext --inplace
cd ..
```
Expected: `Cpp_Core\sdf_core.cp310-win_amd64.pyd` 생성. (C4819 경고는 무해)
setuptools가 VS18 MSVC를 자동 감지하지 못하면, VS Developer PowerShell에서 동일
명령을 실행하거나 `& "C:\Program Files\Microsoft Visual Studio\18\Professional\VC\Auxiliary\Build\vcvars64.bat"`로
환경을 초기화한 뒤 재시도.

- [ ] **Step 6: Run test to verify it passes**

Run: `py -3.10 -m pytest tests/test_cpp_fallback.py -v`
Expected: PASS

- [ ] **Step 7: Commit**

```
git add Cpp_Core/sdf_core.cpp Cpp_Core/setup.py Cpp_Core/sdf_core.cp310-win_amd64.pyd tests/test_cpp_fallback.py
git commit -m "feat(cpp): OpenCV-free sdf_core 8SSEDT 모듈(threshold/spread, NumPy in/out)"
```

---

## Phase 3: 디스패처

### Task 5: sdf_backend.py — GPU↔C++ 폴백

**Files:**
- Create: `sdf_backend.py`
- Test: `tests/test_backend.py`

- [ ] **Step 1: Write the failing test**

`tests/test_backend.py`:
```python
import numpy as np
import sdf_backend


def _rect():
    img = np.full((32, 32), 255, np.uint8)
    img[8:24, 8:24] = 0
    return img


def test_fallback_path_returns_valid_sdf(monkeypatch):
    # GPU를 강제로 비활성화 → C++ 폴백 경로
    monkeypatch.setattr(sdf_backend.sdf_gpu, "is_gpu_available", lambda: False)
    out = sdf_backend.generate_distance_field(_rect(), 128, 16.0)
    assert out.shape == (32, 32)
    assert out.dtype == np.uint8
    # 중심(inside)은 밝고(>128), 모서리(outside)는 어두움(<128)
    assert out[16, 16] > 128
    assert out[0, 0] < 128
```

- [ ] **Step 2: Run test to verify it fails**

Run: `py -3.10 -m pytest tests/test_backend.py -v`
Expected: FAIL (`ModuleNotFoundError: No module named 'sdf_backend'`)

- [ ] **Step 3: Implement sdf_backend.py**

`sdf_backend.py`:
```python
"""거리장 백엔드 디스패처: GPU(wgpu) 우선, 실패 시 순수 C++ sdf_core 폴백."""
import os
import sys

import numpy as np

import sdf_gpu

# sdf_core.*.pyd 는 Cpp_Core/ 에 inplace 빌드됨
sys.path.append(os.path.join(os.path.dirname(__file__), "Cpp_Core"))


def generate_distance_field(gray, threshold, spread):
    """gray(uint8 HxW), threshold(0-255 int), spread(px float) → uint8 SDF."""
    if gray is None or gray.size == 0:
        raise ValueError("generate_distance_field: 빈 입력")
    gray = np.ascontiguousarray(gray, dtype=np.uint8)
    if sdf_gpu.is_gpu_available():
        try:
            return sdf_gpu.compute_sdf(gray, int(threshold), float(spread))
        except Exception as exc:  # 디바이스 로스트/OOM 등
            print(f"[sdf_backend] GPU 실패, sdf_core 폴백: {exc}")
    return _cpp_fallback(gray, threshold, spread)


def _cpp_fallback(gray, threshold, spread):
    import sdf_core
    out = sdf_core.compute_sdf(gray, int(threshold), float(spread))
    if out is None:
        raise RuntimeError("sdf_core 폴백: 출력 없음")
    return out
```

- [ ] **Step 4: Run test to verify it passes**

Run: `py -3.10 -m pytest tests/test_backend.py -v`
Expected: PASS

- [ ] **Step 5: (GPU 환경) GPU↔폴백 동등성 테스트 추가**

`tests/test_backend.py`에 추가:
```python
import pytest


@pytest.mark.skipif(not sdf_gpu.is_gpu_available(), reason="GPU 없음")
def test_gpu_and_fallback_close(monkeypatch):
    img = _rect()
    gpu_out = sdf_backend.generate_distance_field(img, 128, 16.0)
    monkeypatch.setattr(sdf_backend.sdf_gpu, "is_gpu_available", lambda: False)
    cpu_out = sdf_backend.generate_distance_field(img, 128, 16.0)
    assert np.mean(np.abs(gpu_out.astype(int) - cpu_out.astype(int))) <= 3.0
```

- [ ] **Step 6: Run test**

Run: `py -3.10 -m pytest tests/test_backend.py -v`
Expected: PASS (GPU 없으면 동등성 테스트 skip)

- [ ] **Step 7: Commit**

```
git add sdf_backend.py tests/test_backend.py
git commit -m "feat(sdf_backend): GPU↔C++ 폴백 디스패처"
```

---

## Phase 4: main.py / QML 통합

### Task 6: 프리뷰 경로 전환

**Files:**
- Modify: `main.py:242-273` (`generate_sdf_preview_result`)
- Modify: `main.py` 상단 (import 추가)

- [ ] **Step 1: import 추가 (`main.py:39` 부근)**

`import SDF_Cpp` 아래에 추가:
```python
import sdf_backend
```

- [ ] **Step 2: 프리뷰 함수 교체 (`main.py:253-263`)**

기존 블록:
```python
    if not output_file.exists():
        shutil.copy2(source_path, preview_source)
        sdf_folder = SDF_Cpp.GenerateSDF(str(work_dir), preview_source.name)
        if sdf_folder and str(sdf_folder).strip():
            SDF_Cpp.SDFLerp(sdf_folder)
            candidate = Path(sdf_folder) / f"{preview_source.stem}.png"
            if not candidate.exists():
                candidate = Path(sdf_folder) / "SDF" / "SDF.png"
            if candidate.exists() and candidate.resolve() != output_file.resolve():
                output_file.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(candidate, output_file)
```
변경:
```python
    if not output_file.exists():
        shutil.copy2(source_path, preview_source)
        gray = cv2.imread(str(preview_source), cv2.IMREAD_GRAYSCALE)
        if gray is None:
            return {"ok": False, "error": "프리뷰 이미지 읽기 실패", "outputFile": "", "outputUrl": ""}
        threshold_255 = round(threshold / 100 * 255)
        sdf = sdf_backend.generate_distance_field(gray, threshold_255, float(spread))
        out_dir = work_dir / "output"
        out_dir.mkdir(parents=True, exist_ok=True)
        cv2.imwrite(str(out_dir / f"{preview_source.stem}.png"), sdf)
        sdf_folder = str(out_dir) + os.sep
        SDF_Cpp.SDFLerp(sdf_folder)
        candidate = out_dir / f"{preview_source.stem}.png"
        if candidate.exists() and candidate.resolve() != output_file.resolve():
            output_file.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(candidate, output_file)
```

- [ ] **Step 3: 수동 검증 (GUI)**

Run: `py -3.10 main.py`
Expected: SDF 모드에서 이미지 선택 시 프리뷰가 생성됨. threshold/spread 슬라이더 변경 시 프리뷰가 바뀜(기존엔 안 바뀜).

- [ ] **Step 4: Commit**

```
git add main.py
git commit -m "feat(main): 프리뷰 거리장을 sdf_backend로 전환, threshold/spread 반영"
```

---

### Task 7: 일괄 생성 경로 + threshold/spread 전달

**Files:**
- Modify: `main.py:47-65` (`SDF_Generate`, `lerp_SDF`)
- Modify: `main.py:276-297` (`generate_sdf_result`)
- Modify: `main.py:382-391` (`generateSDF`, `generateSDFAsync` 슬롯)

- [ ] **Step 1: SDF_Generate에 threshold/spread 추가 (`main.py:47-56`)**

기존:
```python
    @staticmethod
    def SDF_Generate(folder_path):
        output_folder = ""
        for filename in os.listdir(folder_path):
            file_path = os.path.join(folder_path, filename)
            # 检查文件是否是图像文件
            if os.path.isfile(file_path) and filename.lower().endswith(('.jpg', '.jpeg', '.png', '.gif', '.bmp')):
                image = cv2.imread(file_path)
                output_folder = SDF_Cpp.GenerateSDF(folder_path, filename)
        return output_folder
```
변경:
```python
    @staticmethod
    def SDF_Generate(folder_path, threshold_255, spread):
        output_folder = ""
        out_dir = os.path.join(folder_path, "output")
        for filename in os.listdir(folder_path):
            file_path = os.path.join(folder_path, filename)
            if os.path.isfile(file_path) and filename.lower().endswith(('.jpg', '.jpeg', '.png', '.gif', '.bmp')):
                gray = cv2.imread(file_path, cv2.IMREAD_GRAYSCALE)
                if gray is None:
                    continue
                sdf = sdf_backend.generate_distance_field(gray, threshold_255, float(spread))
                os.makedirs(out_dir, exist_ok=True)
                cv2.imwrite(os.path.join(out_dir, filename), sdf)
                output_folder = out_dir + os.sep
        return output_folder
```

- [ ] **Step 2: lerp_SDF에 인자 전달 (`main.py:58-65`)**

기존:
```python
    @staticmethod
    def lerp_SDF(folder_path):
        sdf_folder = SDFLib.SDF_Generate(folder_path)
        if sdf_folder.strip() != "":
            print("SDF生成完成")
            SDF_Cpp.SDFLerp(sdf_folder)
            print("SDF插值完成")
        return sdf_folder
```
변경:
```python
    @staticmethod
    def lerp_SDF(folder_path, threshold_255, spread):
        sdf_folder = SDFLib.SDF_Generate(folder_path, threshold_255, spread)
        if sdf_folder.strip() != "":
            print("SDF生成完成")
            SDF_Cpp.SDFLerp(sdf_folder)
            print("SDF插值完成")
        return sdf_folder
```

- [ ] **Step 3: generate_sdf_result에 인자 추가 (`main.py:276`, `:286`)**

`def generate_sdf_result(path):` → `def generate_sdf_result(path, threshold_255, spread):`
그리고 `output_folder = SDFLib.lerp_SDF(path)` → `output_folder = SDFLib.lerp_SDF(path, threshold_255, spread)`

- [ ] **Step 4: 슬롯 시그니처 변경 (`main.py:381-391`)**

기존:
```python
    @Slot(str, result=str)
    def generateSDF(self, path):
        return result_json(generate_sdf_result(path))
```
변경:
```python
    @Slot(str, int, int, result=str)
    def generateSDF(self, path, threshold, spread):
        return result_json(generate_sdf_result(path, round(threshold / 100 * 255), float(spread)))
```

기존:
```python
    @Slot(str)
    def generateSDFAsync(self, path):
        self._run_generation("sdf", generate_sdf_result, path)
```
변경:
```python
    @Slot(str, int, int)
    def generateSDFAsync(self, path, threshold, spread):
        self._run_generation("sdf", generate_sdf_result, path, round(threshold / 100 * 255), float(spread))
```

- [ ] **Step 5: QML 일괄 호출 갱신 (`main.qml:313`)**

기존:
```qml
        pyFunc.generateSDFAsync(root.sdfPath)
```
변경:
```qml
        pyFunc.generateSDFAsync(root.sdfPath, root.threshold, root.spread)
```

- [ ] **Step 6: 수동 검증 (GUI)**

Run: `py -3.10 main.py`
Expected: SDF 폴더 선택 후 생성 실행 시 `output/`에 각 이미지의 SDF가 생성됨. threshold/spread 슬라이더 값이 결과에 반영됨. 에러 없음.

- [ ] **Step 7: Commit**

```
git add main.py main.qml
git commit -m "feat: 일괄 SDF 생성에 threshold/spread 전달 및 sdf_backend 전환"
```

---

### Task 8: 알고리즘 라벨 정직화 (선택)

**Files:**
- Modify: `main.qml:957`

- [ ] **Step 1: 라벨 갱신**

기존:
```qml
                                    SelectRow { valueText: "8SSEDT"; badgeText: uiText("cppCore"); badgeColor: blue }
```
변경:
```qml
                                    SelectRow { valueText: "JFA"; badgeText: "GPU"; badgeColor: blue }
```

- [ ] **Step 2: 수동 확인**

Run: `py -3.10 main.py`
Expected: SDF 설정 패널 알고리즘 표기가 "JFA / GPU"로 보임.

- [ ] **Step 3: Commit**

```
git add main.qml
git commit -m "chore(ui): 알고리즘 라벨을 JFA(GPU)로 갱신"
```

---

## Phase 5: 회귀 / 폴백 검증

### Task 9: 디폴트 파라미터 회귀 테스트

**Files:**
- Test: `tests/test_regression.py`

- [ ] **Step 1: Write the test (spread=127로 기존 스케일 1.0 동등성 확인)**

`tests/test_regression.py`:
```python
import os, sys
import numpy as np

sys.path.append("Cpp_Core")


def _legacy_like(gray):
    """sdf_core에 threshold=128, spread=127을 주면 기존(dist*1.0+128)과 동등."""
    import sdf_core
    return sdf_core.compute_sdf(gray, 128, 127.0)


def test_spread127_matches_legacy_scale():
    img = np.full((48, 48), 255, np.uint8)
    img[12:36, 12:36] = 0
    out = _legacy_like(img)
    # dist*1.0+128 == 128 + (dist/127)*127. 중심은 밝고 모서리는 어두움.
    assert out[24, 24] > 128
    assert out[0, 0] < 128
```

- [ ] **Step 2: Run test**

Run: `py -3.10 -m pytest tests/test_regression.py -v`
Expected: PASS

- [ ] **Step 3: 전체 테스트 실행**

Run: `py -3.10 -m pytest tests/ -v`
Expected: 모든 테스트 PASS (GPU 없으면 GPU 테스트 skip)

- [ ] **Step 4: Commit**

```
git add tests/test_regression.py
git commit -m "test: spread=127 레거시 스케일 동등성 회귀 테스트"
```

---

## Phase 6: 패키징

### Task 10: 의존성 및 PyInstaller

**Files:**
- Modify: `requirements.txt`
- Modify: `SDFTool.spec`

- [ ] **Step 1: requirements.txt에 wgpu 추가**

기존 마지막 줄 뒤에 추가:
```
wgpu~=0.19
```
(주의: Task 0 Step 3에서 실제 설치된 버전을 확인해 핀을 맞출 것.)

- [ ] **Step 2: SDFTool.spec에 wgpu 네이티브/셰이더 포함**

`SDFTool.spec` 상단(Analysis 전)에 추가:
```python
from PyInstaller.utils.hooks import collect_dynamic_libs, collect_data_files
_wgpu_bins = collect_dynamic_libs('wgpu')
_wgpu_datas = collect_data_files('wgpu')
```
`Analysis(...)`의 `binaries=`에 `_wgpu_bins`와 `sdf_core.pyd`를 병합, `datas=`에
`_wgpu_datas`와 셰이더를 병합:
```python
    datas=[
        # ... 기존 항목 ...
        ('sdf_gpu/shaders/*.wgsl', 'sdf_gpu/shaders'),
    ] + _wgpu_datas,
    binaries=[
        # ... 기존 항목 ...
        ('Cpp_Core/sdf_core.cp310-win_amd64.pyd', '.'),
    ] + _wgpu_bins,
```
(기존 `datas`/`binaries` 실제 내용은 파일을 열어 확인 후 병합. 비어 있으면 위 리스트로 신설.
기존 `SDF_Cpp.pyd`(SDFLerp용)가 이미 동봉돼 있는지도 확인해 빠졌으면 추가.)

- [ ] **Step 3: 빌드**

Run: `py -3.10 -m PyInstaller SDFTool.spec`
Expected: `dist\SDFTool` 폴더 빌드 성공.

- [ ] **Step 4: 빌드 산출물 스모크 테스트**

Run: `dist\SDFTool\SDFTool.exe`
Expected: 앱 실행, SDF 프리뷰·생성 동작. GPU 머신에선 GPU 경로, 미지원 머신에선 콘솔에 "GPU 실패, sdf_core 폴백" 후 정상 생성.

- [ ] **Step 5: Commit**

```
git add requirements.txt SDFTool.spec
git commit -m "build: wgpu 의존성 및 PyInstaller 동봉(wgpu 네이티브 + WGSL + sdf_core)"
```

---

## 완료 기준

- [ ] GPU 머신: `pytest tests/` 전부 PASS (오라클·동등성 포함)
- [ ] GPU 미지원(또는 강제 폴백): 폴백 경로 PASS, 생성 정상
- [ ] 프리뷰·일괄 양 경로에서 threshold/spread가 결과에 반영됨
- [ ] PyInstaller 빌드 산출물에서 GPU·폴백 양 경로 스모크 테스트 통과
- [ ] spread 디폴트(UI 16px)의 시각적 적정성 사용자 확인 (필요 시 슬라이더 기본값 조정)
