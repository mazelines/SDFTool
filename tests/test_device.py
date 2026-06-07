from sdf_gpu import device


def test_is_gpu_available_returns_bool():
    assert isinstance(device.is_gpu_available(), bool)


def test_get_device_consistent_when_available():
    if not device.is_gpu_available():
        return  # GPU 없는 환경: 스킵
    d1 = device.get_device()
    d2 = device.get_device()
    assert d1 is d2  # 싱글톤
