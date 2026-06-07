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
