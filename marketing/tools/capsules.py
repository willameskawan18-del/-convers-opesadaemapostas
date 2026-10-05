"""Gera as cápsulas da Steam/Epic a partir da arte-chave (screenshot 4K sem HUD).

uso: python3 capsules.py <keyart.png> <pasta_saida> "<TÍTULO LINHA 1>" "<LINHA 2>" <cor_titulo_hex> <cor_sombra_hex> [subtítulo]
"""
import sys, os
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageEnhance

FONT = os.path.join(os.path.dirname(__file__), "Poppins-ExtraBold.ttf")
FONT_B = os.path.join(os.path.dirname(__file__), "Poppins-Bold.ttf")

SIZES = {
    "header_capsule_920x430": (920, 430, True),
    "small_capsule_462x174": (462, 174, True),
    "main_capsule_1232x706": (1232, 706, True),
    "vertical_capsule_748x896": (748, 896, True),
    "library_capsule_600x900": (600, 900, True),
    "library_hero_3840x1240": (3840, 1240, False),
    "page_background_1438x810": (1438, 810, False),
    "epic_landscape_2560x1440": (2560, 1440, True),
    "epic_portrait_1200x1600": (1200, 1600, True),
}


def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def cover(img, w, h, focus=(0.5, 0.5)):
    """Recorta/escala preenchendo w×h, centrado no ponto de foco."""
    sw, sh = img.size
    k = max(w / sw, h / sh)
    im = img.resize((int(sw * k + 0.5), int(sh * k + 0.5)), Image.LANCZOS)
    x = int((im.width - w) * focus[0])
    y = int((im.height - h) * focus[1])
    return im.crop((x, y, x + w, y + h))


def fit_font(draw, text, max_w, max_h, path=FONT):
    size = int(max_h)
    while size > 8:
        f = ImageFont.truetype(path, size)
        b = draw.textbbox((0, 0), text, font=f)
        if b[2] - b[0] <= max_w and b[3] - b[1] <= max_h:
            return f
        size -= 2
    return ImageFont.truetype(path, 8)


def logo_layer(w, h, l1, l2, col, shadow, sub=None):
    """Logo em camada transparente: 2 linhas com contorno e sombra colorida."""
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    lines = [t for t in (l1, l2) if t]
    lh = h / (len(lines) + (0.55 if sub else 0))
    y = 0
    fonts = [fit_font(d, t, w * 0.96, lh * 0.92) for t in lines]
    size = min(f.size for f in fonts)
    f = ImageFont.truetype(FONT, size)
    total = 0
    boxes = []
    for t in lines:
        b = d.textbbox((0, 0), t, font=f, stroke_width=max(2, size // 14))
        boxes.append(b)
        total += (b[3] - b[1]) * 1.02
    sf = None
    if sub:
        sf = fit_font(d, sub, w * 0.9, lh * 0.38, FONT_B)
        sb = d.textbbox((0, 0), sub, font=sf)
        total += (sb[3] - sb[1]) * 1.6
    y = (h - total) / 2
    sh = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sh)
    for t, b in zip(lines, boxes):
        tw = b[2] - b[0]
        x = (w - tw) / 2 - b[0]
        off = max(3, size // 12)
        sd.text((x, y - b[1] + off), t, font=f, fill=shadow + (255,), stroke_width=max(2, size // 14), stroke_fill=shadow + (255,))
        d.text((x, y - b[1]), t, font=f, fill=col + (255,), stroke_width=max(2, size // 14), stroke_fill=(10, 10, 20, 255))
        y += (b[3] - b[1]) * 1.02
    if sub:
        sb = d.textbbox((0, 0), sub, font=sf)
        y += (sb[3] - sb[1]) * 0.35
        d.text(((w - (sb[2] - sb[0])) / 2 - sb[0], y - sb[1]), sub, font=sf, fill=(255, 255, 255, 255), stroke_width=max(1, sf.size // 10), stroke_fill=(10, 10, 20, 255))
    glow = sh.filter(ImageFilter.GaussianBlur(max(2, size // 10)))
    return Image.alpha_composite(Image.alpha_composite(glow, sh), layer)


def make(key, out, l1, l2, col, shadow, sub=None):
    os.makedirs(out, exist_ok=True)
    art = Image.open(key).convert("RGB")
    art = ImageEnhance.Contrast(ImageEnhance.Color(art).enhance(1.15)).enhance(1.08)
    for name, (w, h, text) in SIZES.items():
        tall = h > w
        im = cover(art, w, h, (0.5, 0.45)).convert("RGBA")
        if text:
            # escurece a faixa do logo para dar leitura
            grad = Image.new("L", (1, 256))
            for i in range(256):
                grad.putpixel((0, i), int(170 * max(0.0, 1 - i / 180)) if tall else int(150 * max(0.0, (i - 110) / 146)))
            grad = grad.resize((w, h))
            dark = Image.new("RGBA", (w, h), (5, 8, 20, 255))
            dark.putalpha(grad)
            im = Image.alpha_composite(im, dark)
            if tall:
                box = (int(w * 0.06), int(h * 0.04), int(w * 0.88), int(h * 0.36))
            elif name.startswith("small"):
                box = (int(w * 0.04), int(h * 0.12), int(w * 0.92), int(h * 0.8))
            else:
                box = (int(w * 0.08), int(h * 0.52), int(w * 0.84), int(h * 0.44))
            lg = logo_layer(box[2], box[3], l1, l2, col, shadow, None if name.startswith("small") else sub)
            im.alpha_composite(lg, (box[0], box[1]))
        im.convert("RGB").save(os.path.join(out, name + (".png")), optimize=True)
    # logo transparente (biblioteca da Steam: 1280x720)
    logo_layer(1280, 720, l1, l2, col, shadow).save(os.path.join(out, "library_logo_1280x720.png"))
    # ícone 256x256 (apenas o recorte da arte + inicial)
    ic = cover(art, 256, 256, (0.5, 0.45)).convert("RGBA")
    ic.alpha_composite(logo_layer(230, 150, l1[:1] + (l2[:1] if l2 else ""), None, col, shadow), (13, 90))
    ic.save(os.path.join(out, "icon_256.png"))


if __name__ == "__main__":
    a = sys.argv
    make(a[1], a[2], a[3], a[4], hexc(a[5]), hexc(a[6]), a[7] if len(a) > 7 else None)
