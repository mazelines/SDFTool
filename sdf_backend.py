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
