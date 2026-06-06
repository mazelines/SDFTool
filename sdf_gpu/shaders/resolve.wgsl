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
  let sdist = d2 - d1;
  var c = floor(128.0 + (sdist / P.spread) * 127.0 + 0.5);
  c = clamp(c, 0.0, 255.0);
  outbuf[i] = u32(c);
}
