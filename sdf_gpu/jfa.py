"""wgpu 2-패스 JFA+1 파이프라인. NumPy in/out."""
import os
import sys
import numpy as np
import wgpu

from .device import get_device

if getattr(sys, "frozen", False):
    _SHADER_DIR = os.path.join(sys._MEIPASS, "sdf_gpu", "shaders")
else:
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
        layout="auto",
        compute={"module": device.create_shader_module(code=_load("seed_init.wgsl")), "entry_point": "main"},
    )
    step_pl = device.create_compute_pipeline(
        layout="auto",
        compute={"module": device.create_shader_module(code=_load("jfa_step.wgsl")), "entry_point": "main"},
    )
    resolve_pl = device.create_compute_pipeline(
        layout="auto",
        compute={"module": device.create_shader_module(code=_load("resolve.wgsl")), "entry_point": "main"},
    )

    gx = (w + 7) // 8
    gy = (h + 7) // 8

    def entries(pipeline, *bufs):
        out = []
        for k, b in enumerate(bufs):
            out.append({"binding": k, "resource": {"buffer": b, "offset": 0, "size": b.size}})
        return device.create_bind_group(layout=pipeline.get_bind_group_layout(0), entries=out)

    def dispatch(pipeline, bind_group):
        enc = device.create_command_encoder()
        cp = enc.begin_compute_pass()
        cp.set_pipeline(pipeline)
        cp.set_bind_group(0, bind_group)
        cp.dispatch_workgroups(gx, gy, 1)
        cp.end()
        device.queue.submit([enc.finish()])

    def run_pass(invert, dst_result):
        device.queue.write_buffer(init_u, 0, np.array([w, h, int(threshold), invert], np.int32).tobytes())
        dispatch(init_pl, entries(init_pl, init_u, img, buf_a))
        src, dst = buf_a, buf_b
        for st in _jfa_steps(max(w, h)):
            device.queue.write_buffer(step_u, 0, np.array([w, h, st, 0], np.int32).tobytes())
            dispatch(step_pl, entries(step_pl, step_u, src, dst))
            src, dst = dst, src
        enc = device.create_command_encoder()
        enc.copy_buffer_to_buffer(src, 0, dst_result, 0, seed_bytes)
        device.queue.submit([enc.finish()])

    run_pass(0, seed_in)   # inside 시드
    run_pass(1, seed_out)  # outside 시드

    device.queue.write_buffer(
        resolve_u, 0,
        np.array([w, h], np.int32).tobytes() + np.array([float(spread), 0.0], np.float32).tobytes(),
    )
    dispatch(resolve_pl, entries(resolve_pl, resolve_u, seed_in, seed_out, outbuf))

    raw = device.queue.read_buffer(outbuf)
    return np.frombuffer(raw, dtype=np.uint32).astype(np.uint8).reshape(h, w)
