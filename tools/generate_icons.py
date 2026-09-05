#!/usr/bin/env python3
"""
Genera los iconos de Compás UCM: launcher (legacy + adaptive), web y favicon.

Motivo: brújula/reloj cálido — anillo terra sobre crema con aguja marrón.

Uso: python3 tools/generate_icons.py
"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "app" / "android" / "app" / "src" / "main" / "res"
WEB = ROOT / "app" / "web" / "icons"

CREAM = (0xFB, 0xF4, 0xEB)
TERRA = (0xB8, 0x5C, 0x38)
BROWN = (0x5F, 0x2E, 0x1C)
LIGHT = (0xC9, 0x8A, 0x6B)

SS = 8  # supersampling


def motif(draw, cx, cy, size, ring_radius_frac=0.34, needle_frac=0.30, stroke_frac=0.055):
    """Dibuja la brújula: anillo terra, aguja NE-SW, punto central."""
    ring_r = size * ring_radius_frac
    stroke = max(2, int(size * stroke_frac))

    # Anillo
    draw.ellipse(
        [cx - ring_r, cy - ring_r, cx + ring_r, cy + ring_r],
        outline=TERRA, width=stroke,
    )

    # Aguja (rombo NE-SW), contenida en el anillo: norte oscuro, sur claro.
    import math
    ang = math.radians(-45)
    ux, uy = math.cos(ang), math.sin(ang)  # eje de la aguja
    px, py = -uy, ux  # perpendicular

    def pt(dist_along, dist_perp):
        return (cx + ux * dist_along + px * dist_perp,
                cy + uy * dist_along + py * dist_perp)

    gap = ring_r * 0.06
    half = ring_r * 0.16
    tip_n = pt(ring_r * 0.82, 0)
    tip_s = pt(-ring_r * 0.72, 0)
    n_base = (pt(gap, half), pt(gap, -half))
    s_base = (pt(-gap, half), pt(-gap, -half))
    draw.polygon([tip_n, n_base[0], n_base[1]], fill=BROWN)
    draw.polygon([tip_s, s_base[0], s_base[1]], fill=LIGHT)

    # Punto central pequeño, color crema con aro fino
    dot = max(2, int(ring_r * 0.18))
    draw.ellipse(
        [int(cx - dot), int(cy - dot), int(cx + dot), int(cy + dot)],
        fill=CREAM,
        outline=LIGHT, width=max(1, int(size * 0.012)),
    )


def rounded_bg(draw, size, radius_frac=0.18, margin_frac=0.02):
    """Fondo crema con esquinas redondeadas (para el legacy y web)."""
    r = int(size * radius_frac)
    m = size * margin_frac
    draw.rounded_rectangle(
        [m, m, size - m, size - m], radius=r, fill=CREAM,
    )


def render_icon(size, *, transparent_bg=False, scale=1.0) -> Image.Image:
    """Dibuja a SSx tamaño y reduce con LANCZOS."""
    s = size * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0) if transparent_bg else CREAM)
    d = ImageDraw.Draw(img)
    if not transparent_bg:
        rounded_bg(d, s)
    cx = cy = s / 2
    motif(d, cx, cy, s * scale)
    return img.resize((int(size), int(size)), Image.LANCZOS)


def main() -> None:
    # Launcher legacy (con fondo crema)
    for name, size in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        out = RES / f"mipmap-{name}" / "ic_launcher.png"
        render_icon(size).save(out)
        print("legacy", out.relative_to(ROOT))

    # Adaptive foreground (fondo transparente, motivo centrado en zona segura)
    for name, size in {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}.items():
        out = RES / f"mipmap-{name}" / "ic_launcher_foreground.png"
        render_icon(size, transparent_bg=True, scale=0.72).save(out)
        print("adaptive fg", out.relative_to(ROOT))

    # Web
    for name, size, extra in [
        ("Icon-192", 192, 0.02),
        ("Icon-512", 512, 0.02),
        ("Icon-maskable-192", 192, 0.12),
        ("Icon-maskable-512", 512, 0.12),
    ]:
        img = render_icon(size, transparent_bg=True, scale=1.0 - extra)
        bg = Image.new("RGBA", (size, size), CREAM)
        bg.alpha_composite(img)
        bg.save(WEB / f"{name}.png")
        print("web", WEB / f"{name}.png")

    # favicon 32 y 64 (para el index de web)
    render_icon(32).save(ROOT / "app" / "web" / "favicon.png")
    render_icon(64).save(WEB / "favicon-64.png")
    print("favicon ok")


if __name__ == "__main__":
    main()
