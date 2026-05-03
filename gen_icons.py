"""Generate WaterWise water-droplet launcher icons for Android export."""

import math
from PIL import Image, ImageDraw, ImageFilter

def make_droplet(size, padding_ratio=0.12):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    pad = int(size * padding_ratio)
    w = size - 2 * pad
    h = size - 2 * pad
    cx = size // 2
    cy = size // 2

    # Droplet: circle body + triangular tip pointing up
    # The circle center is at ~60% from top of the bounding box
    r = int(w * 0.44)
    circle_cy = pad + int(h * 0.56)
    circle_cx = cx

    # Tip of the droplet (top point)
    tip_x = cx
    tip_y = pad

    # Build polygon points for teardrop shape
    # Left tangent from tip to circle, right tangent from circle to tip
    # Angle from circle center to where tangent lines meet the circle
    # dx = circle_cx - tip_x = 0, dy = circle_cy - tip_y
    d = math.sqrt((circle_cx - tip_x)**2 + (circle_cy - tip_y)**2)
    alpha = math.asin(r / d)  # half-angle of tangent lines
    base_angle = math.atan2(tip_y - circle_cy, tip_x - circle_cx)  # pointing toward tip

    # Left tangent point on circle
    la = base_angle + math.pi / 2 - alpha
    lx = int(circle_cx + r * math.cos(la))
    ly = int(circle_cy + r * math.sin(la))
    # Right tangent point on circle
    ra = base_angle - math.pi / 2 + alpha
    rx = int(circle_cx + r * math.cos(ra))
    ry = int(circle_cy + r * math.sin(ra))

    # Build arc from left tangent to right tangent going around the bottom
    points = [(tip_x, tip_y)]
    # Arc from left to right going clockwise (bottom of circle)
    start_deg = math.degrees(math.atan2(ly - circle_cy, lx - circle_cx))
    end_deg = math.degrees(math.atan2(ry - circle_cy, rx - circle_cx))
    # We want the arc that goes through the bottom (180 deg)
    steps = 60
    # Go from start_deg to end_deg the long way (through 90 deg / bottom)
    if end_deg < start_deg:
        end_deg += 360
    for i in range(steps + 1):
        t = start_deg + (end_deg - start_deg) * i / steps
        t_rad = math.radians(t)
        px = int(circle_cx + r * math.cos(t_rad))
        py = int(circle_cy + r * math.sin(t_rad))
        points.append((px, py))

    # Main droplet body fill (deep ocean blue)
    draw.polygon(points, fill=(30, 120, 220, 255))

    # Highlight 1 – lighter blue inner glow (slightly inset droplet)
    scale = 0.72
    r2 = int(r * scale)
    off_x = int(w * -0.04)
    off_y = int(h * -0.04)
    cx2 = circle_cx + off_x
    cy2 = circle_cy + off_y
    tip2 = (tip_x + off_x, tip_y + int(h * 0.06))

    d2 = math.sqrt((cx2 - tip2[0])**2 + (cy2 - tip2[1])**2)
    if d2 > r2:
        alpha2 = math.asin(min(r2 / d2, 1.0))
        base2 = math.atan2(tip2[1] - cy2, tip2[0] - cx2)
        la2 = base2 + math.pi / 2 - alpha2
        lx2 = int(cx2 + r2 * math.cos(la2))
        ly2 = int(cy2 + r2 * math.sin(la2))
        ra2 = base2 - math.pi / 2 + alpha2
        rx2 = int(cx2 + r2 * math.cos(ra2))
        ry2 = int(cy2 + r2 * math.sin(ra2))

        pts2 = [(tip2[0], tip2[1])]
        sd2 = math.degrees(math.atan2(ly2 - cy2, lx2 - cx2))
        ed2 = math.degrees(math.atan2(ry2 - cy2, rx2 - cx2))
        if ed2 < sd2:
            ed2 += 360
        for i in range(steps + 1):
            t = sd2 + (ed2 - sd2) * i / steps
            t_rad = math.radians(t)
            px = int(cx2 + r2 * math.cos(t_rad))
            py = int(cy2 + r2 * math.sin(t_rad))
            pts2.append((px, py))
        draw.polygon(pts2, fill=(60, 160, 255, 200))

    # Highlight 2 – bright specular glint (top-left of circle)
    glint_r = max(4, int(r * 0.18))
    gx = circle_cx - int(r * 0.30)
    gy = circle_cy - int(r * 0.35)
    draw.ellipse(
        (gx - glint_r, gy - glint_r, gx + glint_r, gy + glint_r),
        fill=(220, 240, 255, 200)
    )

    # Small secondary glint
    g2r = max(2, int(r * 0.09))
    g2x = gx + int(r * 0.22)
    g2y = gy + int(r * 0.15)
    draw.ellipse(
        (g2x - g2r, g2y - g2r, g2x + g2r, g2y + g2r),
        fill=(255, 255, 255, 180)
    )

    # Subtle soft-shadow: render a dark copy beneath
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow)
    shadow_pts = [(x + int(size * 0.025), y + int(size * 0.025)) for x, y in points]
    sdraw.polygon(shadow_pts, fill=(0, 50, 120, 90))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=int(size * 0.025)))
    result = Image.alpha_composite(shadow, img)
    return result


def make_adaptive_bg(size):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Radial-ish gradient faked with concentric ellipses
    steps = 60
    for i in range(steps, -1, -1):
        t = i / steps
        r_val = int(20 + t * 30)
        g_val = int(100 + t * 60)
        b_val = int(200 + t * 40)
        margin = int((1 - t) * size * 0.5)
        draw.ellipse(
            (margin, margin, size - margin, size - margin),
            fill=(r_val, g_val, b_val, 255)
        )
    return img


if __name__ == "__main__":
    import os
    out_dir = r"f:\waterwise\assets\icons"
    os.makedirs(out_dir, exist_ok=True)

    # Main launcher icon 192x192
    icon_192 = make_droplet(192)
    icon_192.save(os.path.join(out_dir, "icon_main_192x192.png"))
    print("Saved icon_main_192x192.png")

    # Adaptive foreground 432x432 (droplet on transparent bg)
    icon_fg = make_droplet(432)
    icon_fg.save(os.path.join(out_dir, "icon_adaptive_foreground_432x432.png"))
    print("Saved icon_adaptive_foreground_432x432.png")

    # Adaptive background 432x432 (solid gradient, no transparency needed)
    icon_bg = make_adaptive_bg(432)
    icon_bg.save(os.path.join(out_dir, "icon_adaptive_background_432x432.png"))
    print("Saved icon_adaptive_background_432x432.png")

    print("All icons generated in", out_dir)
