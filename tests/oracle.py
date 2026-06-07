import numpy as np


def brute_sdf(gray, threshold, spread):
    """작은 이미지용 정답 SDF. 공유 계약과 동일 매핑."""
    gray = gray.astype(np.int32)
    h, w = gray.shape
    ys, xs = np.indices((h, w))
    pts = np.stack([ys.ravel(), xs.ravel()], axis=1)  # (N,2)

    inside_mask = (gray < threshold).ravel()
    in_pts = pts[inside_mask]
    out_pts = pts[~inside_mask]

    def nearest(all_pts, seeds):
        if len(seeds) == 0:
            return np.full(len(all_pts), 1e18)
        # (N,1,2) - (1,M,2)
        diff = all_pts[:, None, :] - seeds[None, :, :]
        d = np.sqrt((diff ** 2).sum(axis=2))
        return d.min(axis=1)

    d1 = nearest(pts, in_pts)
    d2 = nearest(pts, out_pts)
    sdist = (d2 - d1).reshape(h, w)
    c = np.clip(np.floor(128.0 + (sdist / spread) * 127.0 + 0.5), 0, 255)
    return c.astype(np.uint8)
