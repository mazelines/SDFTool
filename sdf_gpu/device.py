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
