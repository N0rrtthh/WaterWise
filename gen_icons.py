"""Generate WaterWise launcher icons and droplet base texture."""

import math
from PIL import Image, ImageDraw, ImageFilter


def _lerp(a, b, t):
    return int(a + (b - a) * t)


def _vertical_gradient(size, top, bottom):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    for y in range(size):
        t = y / max(1, size - 1)
        r = _lerp(top[0], bottom[0], t)
        g = _lerp(top[1], bottom[1], t)
        b = _lerp(top[2], bottom[2], t)
        draw.line((0, y, size, y), fill=(r, g, b, 255))
    return img


def _rounded_mask(size, radius):
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def _droplet_points(size, padding_ratio):
    pad = int(size * padding_ratio)
    w = size - 2 * pad
    h = size - 2 * pad
    cx = size // 2

    r = int(w * 0.43)
    circle_cx = cx
    circle_cy = pad + int(h * 0.60)

    tip_x = cx
    tip_y = pad

    d = math.sqrt((circle_cx - tip_x) ** 2 + (circle_cy - tip_y) ** 2)
    d = max(d, r + 1)
    alpha = math.asin(r / d)
    base_angle = math.atan2(tip_y - circle_cy, tip_x - circle_cx)

    la = base_angle + math.pi / 2 - alpha
    ra = base_angle - math.pi / 2 + alpha

    lx = int(circle_cx + r * math.cos(la))
    ly = int(circle_cy + r * math.sin(la))
    rx = int(circle_cx + r * math.cos(ra))
    ry = int(circle_cy + r * math.sin(ra))

    points = [(tip_x, tip_y)]
    start_deg = math.degrees(math.atan2(ly - circle_cy, lx - circle_cx))
    end_deg = math.degrees(math.atan2(ry - circle_cy, rx - circle_cx))
    if end_deg < start_deg:
        end_deg += 360
    steps = 64
    for i in range(steps + 1):
        t = start_deg + (end_deg - start_deg) * i / steps
        tr = math.radians(t)
        px = int(circle_cx + r * math.cos(tr))
        py = int(circle_cy + r * math.sin(tr))
        points.append((px, py))
    return points


def _make_droplet_layer(size, padding_ratio, top, bottom, alpha=255):
    points = _droplet_points(size, padding_ratio)
    mask = Image.new("L", (size, size), 0)
    mdraw = ImageDraw.Draw(mask)
    mdraw.polygon(points, fill=255)

    grad = _vertical_gradient(size, top, bottom)
    if alpha < 255:
        grad.putalpha(alpha)

    base = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    return Image.composite(grad, base, mask)


def make_droplet(size, padding_ratio=0.08):
    base = _make_droplet_layer(
        size,
        padding_ratio,
        top=(110, 210, 255),
        bottom=(18, 110, 215),
    )

    inner_size = int(size * 0.78)
    inner = _make_droplet_layer(
        inner_size,
        padding_ratio,
        top=(170, 235, 255),
        bottom=(90, 185, 245),
        alpha=180,
    )
    inner_pos = (int(size * 0.10), int(size * 0.08))
    base.alpha_composite(inner, dest=inner_pos)

    glint = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glint)
    glint_r = max(3, int(size * 0.05))
    gx = int(size * 0.40)
    gy = int(size * 0.36)
    gdraw.ellipse(
        (gx - glint_r, gy - glint_r, gx + glint_r, gy + glint_r),
        fill=(255, 255, 255, 210),
    )
    g2r = max(2, int(size * 0.03))
    g2x = gx + int(size * 0.07)
    g2y = gy + int(size * 0.06)
    gdraw.ellipse(
        (g2x - g2r, g2y - g2r, g2x + g2r, g2y + g2r),
        fill=(255, 255, 255, 170),
    )
    base = Image.alpha_composite(base, glint)
    return base


def make_background(size, rounded=True):
    bg = _vertical_gradient(size, top=(22, 140, 220), bottom=(8, 70, 150))

    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    steps = 40
    for i in range(steps):
        t = i / max(1, steps - 1)
        r = int(size * (0.55 - 0.35 * t))
        alpha = int(100 * (1 - t) ** 2)
        gdraw.ellipse(
            (
                int(size * 0.05) - r,
                int(size * 0.08) - r,
                int(size * 0.05) + r,
                int(size * 0.08) + r,
            ),
            fill=(120, 220, 255, alpha),
        )
    bg = Image.alpha_composite(bg, glow)

    draw = ImageDraw.Draw(bg)
    stroke = max(2, int(size * 0.012))
    for i in range(3):
        y = int(size * (0.58 + i * 0.12))
        bbox = (-int(size * 0.2), y, int(size * 1.2), y + int(size * 0.65))
        draw.arc(bbox, start=200, end=340, fill=(255, 255, 255, 30), width=stroke)

    if rounded:
        radius = int(size * 0.22)
        mask = _rounded_mask(size, radius)
        bg.putalpha(mask)
    return bg


def compose_center(canvas_size, image):
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    off = ((canvas_size - image.width) // 2, (canvas_size - image.height) // 2)
    canvas.alpha_composite(image, dest=off)
    return canvas


if __name__ == "__main__":
    import os
    out_dir = r"f:\waterwise\assets\icons"
    character_dir = r"f:\waterwise\assets\characters"
    os.makedirs(out_dir, exist_ok=True)
    os.makedirs(character_dir, exist_ok=True)

    # Main launcher icon 192x192
    main_bg = make_background(192, rounded=True)
    main_drop = make_droplet(int(192 * 0.70))
    icon_192 = Image.alpha_composite(main_bg, compose_center(192, main_drop))
    icon_192.save(os.path.join(out_dir, "icon_main_192x192.png"))
    print("Saved icon_main_192x192.png")

    # Adaptive foreground 432x432 (droplet on transparent bg)
    fg_drop = make_droplet(int(432 * 0.66))
    icon_fg = compose_center(432, fg_drop)
    icon_fg.save(os.path.join(out_dir, "icon_adaptive_foreground_432x432.png"))
    print("Saved icon_adaptive_foreground_432x432.png")

    # Adaptive background 432x432 (solid gradient, no transparency needed)
    icon_bg = make_background(432, rounded=False)
    icon_bg.save(os.path.join(out_dir, "icon_adaptive_background_432x432.png"))
    print("Saved icon_adaptive_background_432x432.png")

    # Droplet base texture for cutscene character
    base_drop = make_droplet(512, padding_ratio=0.06)
    base_drop.save(os.path.join(character_dir, "droplet_base.png"))
    print("Saved droplet_base.png")

    print("All icons generated in", out_dir)
