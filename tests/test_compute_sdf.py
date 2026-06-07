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
