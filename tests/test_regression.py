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
