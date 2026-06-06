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
