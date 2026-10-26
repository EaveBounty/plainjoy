#!/usr/bin/env python3
"""Generate 清欢 / Plainjoy brand assets.

Outputs
-------
assets/icon/app_icon.png              1024x1024 legacy launcher icon
assets/icon/app_icon_foreground.png   1024x1024 adaptive foreground (safe zone)
assets/icon/app_icon_monochrome.png   1024x1024 themed-icon silhouette
assets/icon/app_icon_512.png          store / web icon
assets/brand/splash_ink.png           1080x1920 semi-transparent ink-wash layer

The pixel cat is drawn on a 32x32 grid and upscaled with nearest-neighbour so
the pixel grid stays honest at every launcher size.
"""
from __future__ import annotations

import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICON_DIR = os.path.join(ROOT, "assets", "icon")
BRAND_DIR = os.path.join(ROOT, "assets", "brand")

OUTLINE = (43, 35, 31, 255)
CREAM = (250, 240, 226, 255)
CREAM_DARK = (238, 222, 200, 255)
ORANGE = (232, 164, 92, 255)
ORANGE_DARK = (198, 120, 59, 255)
PINK = (242, 166, 160, 255)
WHITE = (255, 255, 255, 255)
BOWL = (86, 128, 120, 255)
BOWL_DARK = (61, 98, 92, 255)
RICE = (255, 252, 242, 255)
GREEN = (110, 158, 106, 255)
INK = (34, 31, 28, 255)

SIZE = 32


def canvas() -> np.ndarray:
    return np.zeros((SIZE, SIZE, 4), dtype=np.uint8)


def put(a: np.ndarray, x: int, y: int, c) -> None:
    if 0 <= x < SIZE and 0 <= y < SIZE:
        a[y, x] = c


def rect(a, x0, y0, x1, y1, c) -> None:
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(a, x, y, c)


def ellipse(a, cx: float, cy: float, rx: float, ry: float, c) -> None:
    for y in range(SIZE):
        for x in range(SIZE):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                put(a, x, y, c)


def triangle(a, p1, p2, p3, c) -> None:
    def sign(p, q, r):
        return (p[0] - r[0]) * (q[1] - r[1]) - (q[0] - r[0]) * (p[1] - r[1])

    for y in range(SIZE):
        for x in range(SIZE):
            px, py = x + 0.5, y + 0.5
            d1, d2, d3 = sign((px, py), p1, p2), sign((px, py), p2, p3), sign((px, py), p3, p1)
            if not ((d1 < 0 or d2 < 0 or d3 < 0) and (d1 > 0 or d2 > 0 or d3 > 0)):
                put(a, x, y, c)


def outline_mask(a: np.ndarray, c=OUTLINE) -> None:
    """1px 4-neighbour outline around every opaque cluster."""
    alpha = a[:, :, 3] > 0
    grow = alpha.copy()
    grow[1:, :] |= alpha[:-1, :]
    grow[:-1, :] |= alpha[1:, :]
    grow[:, 1:] |= alpha[:, :-1]
    grow[:, :-1] |= alpha[:, 1:]
    edge = grow & ~alpha
    a[edge] = c


def draw_cat() -> np.ndarray:
    a = canvas()

    # --- ears (wide, attached low so they read as cat ears at 48px) -------
    triangle(a, (6.0, 2.4), (4.6, 11.0), (13.0, 9.4), CREAM)
    triangle(a, (26.0, 2.4), (27.4, 11.0), (19.0, 9.4), CREAM)

    # --- head -------------------------------------------------------------
    ellipse(a, 16.0, 14.2, 10.4, 9.0, CREAM)

    # calico patches
    ellipse(a, 10.2, 7.6, 3.6, 3.2, ORANGE)
    ellipse(a, 22.6, 8.4, 3.0, 2.6, ORANGE)
    ellipse(a, 22.8, 16.2, 2.2, 1.8, ORANGE)

    # --- paws resting on the rim -----------------------------------------
    ellipse(a, 8.6, 22.4, 2.8, 2.0, CREAM)
    ellipse(a, 23.4, 22.4, 2.8, 2.0, CREAM)

    outline_mask(a)

    # --- inner ears -------------------------------------------------------
    triangle(a, (6.8, 4.6), (6.0, 9.8), (10.6, 9.0), PINK)
    triangle(a, (25.2, 4.6), (26.0, 9.8), (21.4, 9.0), PINK)

    # --- eyes: 2x2 with a highlight --------------------------------------
    for x0 in (11, 19):
        rect(a, x0, 12, x0 + 1, 13, OUTLINE)
        put(a, x0, 12, WHITE)

    # --- blush ------------------------------------------------------------
    rect(a, 8, 16, 9, 16, PINK)
    rect(a, 22, 16, 23, 16, PINK)

    # --- muzzle, nose, open mouth ----------------------------------------
    ellipse(a, 16.0, 17.4, 4.6, 2.8, CREAM_DARK)
    rect(a, 15, 15, 16, 15, PINK)
    put(a, 14, 17, OUTLINE)
    put(a, 15, 18, OUTLINE)
    put(a, 16, 18, (150, 84, 78, 255))
    put(a, 17, 18, OUTLINE)
    put(a, 18, 17, OUTLINE)
    put(a, 15, 19, PINK)
    put(a, 16, 19, PINK)
    # whisker dots
    for x, y in ((7, 15), (24, 15)):
        put(a, x, y, OUTLINE)

    # --- rice mound -------------------------------------------------------
    ellipse(a, 16.0, 22.6, 8.0, 3.0, RICE)
    ellipse(a, 12.6, 21.6, 2.0, 1.4, WHITE)
    ellipse(a, 18.8, 21.2, 2.4, 1.5, WHITE)
    # fish tail
    triangle(a, (19.8, 20.4), (22.8, 19.0), (22.8, 21.8), ORANGE_DARK)

    # --- bowl -------------------------------------------------------------
    triangle(a, (4.6, 23.6), (27.4, 23.6), (23.6, 28.8), BOWL)
    rect(a, 4, 22, 27, 23, BOWL_DARK)
    put(a, 13, 26, BOWL_DARK)
    put(a, 18, 26, BOWL_DARK)

    outline_mask(a)

    # --- garnish ----------------------------------------------------------
    put(a, 12, 21, GREEN)
    put(a, 12, 20, GREEN)
    put(a, 13, 21, GREEN)
    put(a, 20, 21, GREEN)
    put(a, 20, 20, GREEN)
    put(a, 19, 21, GREEN)

    for x, y in ((6, 21), (5, 20), (26, 21), (27, 20)):
        put(a, x, y, (214, 205, 193, 255))
    return a


def upscale(a: np.ndarray, size: int) -> Image.Image:
    img = Image.fromarray(a, "RGBA")
    return img.resize((size, size), Image.Resampling.NEAREST)


def icon_with_background(a: np.ndarray, size: int = 1024, pad: float = 0.0) -> Image.Image:
    bg = Image.new("RGBA", (size, size), (255, 246, 232, 255))
    inner = int(size * (1 - 2 * pad))
    cat = upscale(a, inner)
    if pad:
        bg.alpha_composite(cat, (int(size * pad), int(size * pad)))
        return bg
    bg.alpha_composite(cat)
    return bg


def monochrome(a: np.ndarray, size: int = 1024) -> Image.Image:
    alpha = (a[:, :, 3] > 0).astype(np.uint8) * 255
    rgba = np.zeros((SIZE, SIZE, 4), dtype=np.uint8)
    rgba[:, :, 0:3] = 255
    rgba[:, :, 3] = alpha
    return upscale(rgba, size)


# ---------------------------------------------------------------------------
# splash: 半透明东坡词意象（雪沫 / 乳花 / 午盏 / 春盘 / 远山），不画人
# ---------------------------------------------------------------------------
def splash(width: int = 1080, height: int = 1920) -> Image.Image:
    """半透明东坡词意象：雪沫、乳花、午盏、春盘、远山。不画人。"""
    rng = random.Random(20261027)
    layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    # 远山：三层湿墨，越远越淡
    hill = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hill)
    base_y = int(height * 0.46)
    for i, (amp, alpha, offset) in enumerate([(70, 26, 0.0), (110, 19, 0.35), (150, 13, 0.7)]):
        pts = []
        for x in range(0, width + 20, 20):
            t = x / width * math.tau * 0.85 + offset * math.tau
            y = base_y + i * 84 + math.sin(t * 1.7 + i) * amp + math.sin(t * 0.6) * amp * 0.6
            pts.append((x, y))
        pts += [(width, height), (0, height)]
        hd.polygon(pts, fill=(52, 62, 66, alpha))
    hill = hill.filter(ImageFilter.GaussianBlur(11))
    layer.alpha_composite(hill)

    # 淡月
    moon = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    md = ImageDraw.Draw(moon)
    md.ellipse(
        [width * 0.56, height * 0.07, width * 0.94, height * 0.07 + width * 0.38],
        fill=(238, 230, 214, 16),
    )
    moon = moon.filter(ImageFilter.GaussianBlur(20))
    layer.alpha_composite(moon)

    # 午盏
    cup_cx, cup_cy = width * 0.415, height * 0.520
    cup_w, cup_h = width * 0.165, height * 0.066
    cup = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    cd = ImageDraw.Draw(cup)
    # 盏身淡墨
    cd.arc(
        [cup_cx - cup_w * 0.46, cup_cy - cup_h * 0.15, cup_cx + cup_w * 0.46, cup_cy + cup_h * 1.05],
        12, 168, fill=(58, 54, 47, 30), width=14,
    )
    # 盏口
    cd.ellipse(
        [cup_cx - cup_w / 2, cup_cy - cup_h * 0.26, cup_cx + cup_w / 2, cup_cy + cup_h * 0.26],
        outline=(52, 48, 42, 120), width=3,
    )
    # 乳花
    cd.ellipse(
        [cup_cx - cup_w * 0.40, cup_cy - cup_h * 0.15, cup_cx + cup_w * 0.40, cup_cy + cup_h * 0.14],
        fill=(255, 252, 244, 105),
    )
    for _ in range(11):
        fx = cup_cx + rng.uniform(-cup_w * 0.34, cup_w * 0.34)
        fy = cup_cy + rng.uniform(-cup_h * 0.07, cup_h * 0.09)
        r = rng.uniform(3, 10)
        cd.ellipse([fx - r, fy - r * 0.66, fx + r, fy + r * 0.66], fill=(255, 253, 246, 130))
    # 盏身淡墨填充
    cd.polygon(
        [
            (cup_cx - cup_w * 0.46, cup_cy + cup_h * 0.05),
            (cup_cx + cup_w * 0.46, cup_cy + cup_h * 0.05),
            (cup_cx + cup_w * 0.33, cup_cy + cup_h * 0.72),
            (cup_cx - cup_w * 0.33, cup_cy + cup_h * 0.72),
        ],
        fill=(58, 54, 47, 34),
    )
    # 盏托：扁椭圆，不做弧线（避免读成笑脸）
    cd.ellipse(
        [cup_cx - cup_w * 0.58, cup_cy + cup_h * 0.70, cup_cx + cup_w * 0.58, cup_cy + cup_h * 0.90],
        fill=(58, 54, 47, 30),
        outline=(52, 48, 42, 60),
        width=2,
    )
    cup = cup.filter(ImageFilter.GaussianBlur(1.1))
    layer.alpha_composite(cup)

    # 茶烟
    smoke = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    sd = ImageDraw.Draw(smoke)
    for k in range(3):
        pts = []
        for i in range(64):
            t = i / 63
            x = cup_cx + (k - 1) * 26 + math.sin(t * 5.0 + k * 1.7) * 18
            y = cup_cy - cup_h * 0.35 - t * height * 0.17
            pts.append((x, y))
        sd.line(pts, fill=(64, 60, 52, 40), width=2)
    smoke = smoke.filter(ImageFilter.GaussianBlur(2.6))
    layer.alpha_composite(smoke)

    # 春盘：蓼茸蒿笋
    plate_cx, plate_cy = width * 0.605, height * 0.535
    plate_w, plate_h = width * 0.155, height * 0.030
    plate = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    pd = ImageDraw.Draw(plate)
    pd.ellipse(
        [plate_cx - plate_w / 2, plate_cy - plate_h, plate_cx + plate_w / 2, plate_cy + plate_h],
        fill=(236, 232, 220, 26),
        outline=(54, 60, 50, 85),
        width=3,
    )
    for i in range(8):
        bx = plate_cx + rng.uniform(-plate_w * 0.32, plate_w * 0.32)
        by = plate_cy + rng.uniform(0, plate_h * 0.45)
        top = (bx + rng.uniform(-16, 16), by - rng.uniform(52, 112))
        pd.line([bx, by, (bx + top[0]) / 2 + rng.uniform(-9, 9), (by + top[1]) / 2, top[0], top[1]],
                fill=(66, 92, 62, 95), width=2)
        # 嫩叶
        for side in (-1, 1):
            for j in range(2):
                lx = top[0] + side * rng.uniform(9, 24)
                ly = top[1] + rng.uniform(8, 30) + j * 9
                pd.line([top[0], top[1] + j * 8, lx, ly], fill=(66, 92, 62, 80), width=2)
    plate = plate.filter(ImageFilter.GaussianBlur(0.9))
    layer.alpha_composite(plate)

    # 雪沫
    snow = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    sdw = ImageDraw.Draw(snow)
    for _ in range(190):
        x = rng.uniform(width * 0.08, width * 0.92)
        y = rng.uniform(height * 0.05, height * 0.9)
        r = rng.choice([1.0, 1.4, 1.9, 2.6])
        sdw.ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 255, rng.randint(60, 130)))
    snow = snow.filter(ImageFilter.GaussianBlur(0.7))
    layer.alpha_composite(snow)

    # 上下渐隐，保证文字压得住
    fade = Image.new("L", (1, height), 0)
    fp = fade.load()
    for y in range(height):
        t = y / height
        v = 1.0
        if t < 0.16:
            v = t / 0.16
        if t > 0.9:
            v = (1 - t) / 0.1
        fp[0, y] = int(max(0.0, min(1.0, v)) * 255)
    fade = fade.resize((width, height))
    r, g, b, a = layer.split()
    layer.putalpha(Image.composite(a, Image.new("L", (width, height), 0), fade))
    return layer


def main() -> None:
    os.makedirs(ICON_DIR, exist_ok=True)
    os.makedirs(BRAND_DIR, exist_ok=True)

    cat = draw_cat()
    icon = icon_with_background(cat, 1024)
    icon.save(os.path.join(ICON_DIR, "app_icon.png"))
    icon.resize((512, 512), Image.Resampling.LANCZOS).save(
        os.path.join(ICON_DIR, "app_icon_512.png")
    )

    fg = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    fg.alpha_composite(upscale(cat, 640), (192, 192))
    fg.save(os.path.join(ICON_DIR, "app_icon_foreground.png"))

    monochrome(cat).save(os.path.join(ICON_DIR, "app_icon_monochrome.png"))

    splash_img = splash()
    splash_img.save(os.path.join(BRAND_DIR, "splash_ink.webp"), quality=88, method=6)

    print("icon:", icon.size)
    print("splash:", splash_img.size, os.path.getsize(os.path.join(BRAND_DIR, "splash_ink.webp")) // 1024, "KB")


if __name__ == "__main__":
    main()
