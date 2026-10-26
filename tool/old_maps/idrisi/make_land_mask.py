"""고지도 이미지에서 육지(황토색)와 바다(청회색)를 분리해 알파 마스크 PNG(3배 해상도)를 만든다.

섬과 해안선 디테일을 살리기 위해 3배로 확대한 뒤 분류하고, 약한 평활화만 적용한다.
"""
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

HERE = Path(__file__).parent
Z = 3


def main(out):
    im = Image.open(HERE / 'idrisi.webp').convert('RGB')
    im = im.resize((im.width * Z, im.height * Z), Image.LANCZOS)
    a = np.asarray(im).astype(float)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]

    # 바다: 어둡고 채도가 낮은 청회색. 육지의 갈색 선/점은 r-b가 커서 제외된다.
    sea = ((r + g) < 300) & ((r - b) < 35)
    # 바다에 그려진 가는 격자선(밝은 가로줄)을 메운다.
    sea = ndi.binary_closing(sea, structure=np.ones((3, 9)))
    sea = ndi.median_filter(sea.astype(np.uint8), size=5).astype(bool)

    # 작은 바다 얼룩(육지 위의 검은 점/글씨)은 육지로, 작은 육지 얼룩은 바다로 정리
    def drop_small(mask, min_px):
        lab, n = ndi.label(mask)
        sizes = ndi.sum(mask, lab, range(1, n + 1))
        keep = [i + 1 for i, s in enumerate(sizes) if s >= min_px]
        return np.isin(lab, keep)

    sea = drop_small(sea, 220)        # 3배 해상도 기준(원본 약 24px²)
    land = drop_small(~sea, 25)       # 섬은 원본 약 3px²까지 살린다
    f = ndi.gaussian_filter(land.astype(float), 1.1)
    alpha = np.clip((f - 0.35) / 0.3, 0, 1)

    rgba = np.zeros(alpha.shape + (4,), np.uint8)
    rgba[..., :3] = 255
    rgba[..., 3] = (alpha * 255).astype(np.uint8)
    Image.fromarray(rgba, 'RGBA').save(out, optimize=True)
    print(Path(out).stat().st_size // 1024, 'KB, land ratio', round(float(land.mean()), 3))


if __name__ == '__main__':
    import sys
    main(sys.argv[1] if len(sys.argv) > 1 else HERE / 'idrisi_land_mask.png')
