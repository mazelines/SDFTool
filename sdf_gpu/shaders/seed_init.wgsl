struct Params {
  width: i32,
  height: i32,
  threshold: i32,
  invert: i32,   // 0: inside 시드, 1: outside 시드
};

@group(0) @binding(0) var<uniform> P: Params;
@group(0) @binding(1) var<storage, read> img: array<u32>;        // gray 0-255
@group(0) @binding(2) var<storage, read_write> seed: array<i32>; // 2*i, 2*i+1

@compute @workgroup_size(8, 8, 1)
fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
  let x = i32(gid.x);
  let y = i32(gid.y);
  if (x >= P.width || y >= P.height) { return; }
  let i = y * P.width + x;
  var is_inside = img[i] < u32(P.threshold);
  if (P.invert == 1) { is_inside = !is_inside; }
  if (is_inside) {
    seed[2 * i] = x;
    seed[2 * i + 1] = y;
  } else {
    seed[2 * i] = -1;
    seed[2 * i + 1] = -1;
  }
}
