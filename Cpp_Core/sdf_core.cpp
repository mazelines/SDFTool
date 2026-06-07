// OpenCV-free 8SSEDT signed distance field, NumPy in/out.
#include <pybind11/pybind11.h>
#include <pybind11/numpy.h>
#include <vector>
#include <cmath>
#include <cstdint>
#include <stdexcept>

namespace py = pybind11;

namespace {

struct Point {
    int dx, dy;
    long long DistSq() const { return (long long)dx * dx + (long long)dy * dy; }
};

const Point INSIDE = {0, 0};
const Point EMPTY = {9999, 9999};

struct Grid {
    int w, h;
    std::vector<Point> cells;
    Grid(int width, int height) : w(width), h(height), cells((size_t)width * height) {}
    Point get(int x, int y) const {
        if (x >= 0 && y >= 0 && x < w && y < h) return cells[(size_t)y * w + x];
        return EMPTY;
    }
    void put(int x, int y, const Point& p) { cells[(size_t)y * w + x] = p; }
};

void compare(Grid& g, Point& p, int x, int y, int ox, int oy) {
    Point o = g.get(x + ox, y + oy);
    o.dx += ox;
    o.dy += oy;
    if (o.DistSq() < p.DistSq()) p = o;
}

void generate(Grid& g) {
    for (int y = 0; y < g.h; y++) {
        for (int x = 0; x < g.w; x++) {
            Point p = g.get(x, y);
            compare(g, p, x, y, -1, 0);
            compare(g, p, x, y, 0, -1);
            compare(g, p, x, y, -1, -1);
            compare(g, p, x, y, 1, -1);
            g.put(x, y, p);
        }
        for (int x = g.w - 1; x >= 0; x--) {
            Point p = g.get(x, y);
            compare(g, p, x, y, 1, 0);
            g.put(x, y, p);
        }
    }
    for (int y = g.h - 1; y >= 0; y--) {
        for (int x = g.w - 1; x >= 0; x--) {
            Point p = g.get(x, y);
            compare(g, p, x, y, 1, 0);
            compare(g, p, x, y, 0, 1);
            compare(g, p, x, y, -1, 1);
            compare(g, p, x, y, 1, 1);
            g.put(x, y, p);
        }
        for (int x = 0; x < g.w; x++) {
            Point p = g.get(x, y);
            compare(g, p, x, y, -1, 0);
            g.put(x, y, p);
        }
    }
}

}  // namespace

py::array_t<uint8_t> compute_sdf(
        py::array_t<uint8_t, py::array::c_style | py::array::forcecast> gray,
        int threshold, double spread) {
    auto buf = gray.request();
    if (buf.ndim != 2) throw std::runtime_error("gray must be 2D (H,W)");
    int h = (int)buf.shape[0];
    int w = (int)buf.shape[1];
    const uint8_t* img = static_cast<const uint8_t*>(buf.ptr);

    Grid g1(w, h), g2(w, h);
    for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
            int pixel = img[(size_t)y * w + x];
            if (pixel < threshold) {       // inside
                g1.put(x, y, INSIDE);
                g2.put(x, y, EMPTY);
            } else {                       // outside
                g2.put(x, y, INSIDE);
                g1.put(x, y, EMPTY);
            }
        }
    }
    generate(g1);
    generate(g2);

    auto result = py::array_t<uint8_t>({h, w});
    auto rbuf = result.request();
    uint8_t* out = static_cast<uint8_t*>(rbuf.ptr);
    for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
            double d1 = std::sqrt((double)g1.get(x, y).DistSq());
            double d2 = std::sqrt((double)g2.get(x, y).DistSq());
            double d = d2 - d1;
            int c = (int)std::floor(128.0 + (d / spread) * 127.0 + 0.5);
            if (c < 0) c = 0;
            if (c > 255) c = 255;
            out[(size_t)y * w + x] = (uint8_t)c;
        }
    }
    return result;
}

PYBIND11_MODULE(sdf_core, m) {
    m.doc() = "OpenCV-free 8SSEDT distance field (NumPy in/out)";
    m.def("compute_sdf", &compute_sdf,
          py::arg("gray"), py::arg("threshold") = 128, py::arg("spread") = 127.0,
          "uint8 (H,W) gray -> uint8 (H,W) SDF");
}
