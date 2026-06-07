import numpy as np
import pytest
import sdf_backend
import sdf_gpu


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


@pytest.mark.skipif(not sdf_gpu.is_gpu_available(), reason="GPU 없음")
def test_gpu_and_fallback_close(monkeypatch):
    img = _rect()
    gpu_out = sdf_backend.generate_distance_field(img, 128, 16.0)
    monkeypatch.setattr(sdf_backend.sdf_gpu, "is_gpu_available", lambda: False)
    cpu_out = sdf_backend.generate_distance_field(img, 128, 16.0)
    assert np.mean(np.abs(gpu_out.astype(int) - cpu_out.astype(int))) <= 3.0
