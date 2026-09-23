"""Frames the raw screen renders (store_screenshots_test.dart) into Google
Play screenshots, 24-bit PNG (no alpha), caption on top:
phone 1080x1920 (portrait), 7" and 10" tablet 1920x1080 (landscape).

    python tool/store_screenshots/frame_screenshots.py

Input:  build/store_screenshots/raw/<profile>/*.png
Output: assets/store/screenshots/<profile>/*.png
Needs Pillow and a bold/regular font (Segoe UI or Arial on Windows,
DejaVu on Linux).
"""
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RAW = os.path.join(ROOT, "build", "store_screenshots", "raw")
OUT = os.path.join(ROOT, "assets", "store", "screenshots")

BG = (24, 24, 27)          # zinc-900, same as the launcher icon
TITLE = (255, 255, 255)
SUBTITLE = (212, 212, 216)  # zinc-300

# (file, title, subtitle). Keep claims to what the app actually does.
CAPTIONS = [
    ("01_garson_masalar", "Masalar tek bakışta", "Boş, dolu ve hesap isteyen masalar"),
    ("02_masa_adisyon", "Adisyon her an güncel", "Siparişin mutfaktaki durumu anında görünür"),
    ("03_menu_siparis", "Siparişi hızla alın", "Kategorili menü, ürün notları"),
    ("04_mutfak", "Mutfak ekranı", "Siparişler sırayla, bekleme süreleriyle"),
    ("05_kasa", "Kasa takibi", "Hesap isteyen masalar öne çıkar"),
    ("06_odeme", "Nakit, kart, parçalı ödeme", "Kalan tutar otomatik hesaplanır"),
    ("07_abonelik", "Size uygun plan", "Ücretsiz deneme süresince tüm özellikler açık"),
]


def font(bold, size):
    candidates = (
        ["segoeuib.ttf", "arialbd.ttf", "DejaVuSans-Bold.ttf"]
        if bold
        else ["segoeui.ttf", "arial.ttf", "DejaVuSans.ttf"]
    )
    for name in candidates:
        for folder in (r"C:\Windows\Fonts", "/usr/share/fonts/truetype/dejavu"):
            path = os.path.join(folder, name)
            if os.path.exists(path):
                return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def centered(draw, width, y, text, fnt, fill):
    box = draw.textbbox((0, 0), text, font=fnt)
    text_w = box[2] - box[0]
    assert text_w <= width - 80, f"caption too wide: {text!r}"
    draw.text(((width - text_w) / 2 - box[0], y), text, font=fnt, fill=fill)


def rounded(image, radius):
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, image.size[0] - 1, image.size[1] - 1], radius=radius, fill=255)
    return mask


# profile -> canvas size, caption sizes/positions, screenshot box
LAYOUTS = {
    "phone": dict(size=(1080, 1920), title=(70, 120), subtitle=(38, 222), shot_w=860, shot_y=340, radius=44),
    "tablet7": dict(size=(1920, 1080), title=(58, 52), subtitle=(32, 132), shot_w=1520, shot_y=210, radius=28),
    "tablet10": dict(size=(1920, 1080), title=(58, 52), subtitle=(32, 132), shot_w=1520, shot_y=210, radius=28),
}


def frame(profile, name, title, subtitle):
    raw_path = os.path.join(RAW, profile, f"{name}.png")
    if not os.path.exists(raw_path):
        return False
    layout = LAYOUTS[profile]
    W, H = layout["size"]
    canvas = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(canvas)
    centered(draw, W, layout["title"][1], title, font(True, layout["title"][0]), TITLE)
    centered(draw, W, layout["subtitle"][1], subtitle, font(False, layout["subtitle"][0]), SUBTITLE)

    shot = Image.open(raw_path).convert("RGB")
    shot_w = layout["shot_w"]
    shot = shot.resize((shot_w, round(shot.height * shot_w / shot.width)), Image.LANCZOS)
    x, y = (W - shot_w) // 2, layout["shot_y"]
    visible_h = min(shot.height, H - y + 60)  # may run off the bottom edge like a device
    shot = shot.crop((0, 0, shot_w, visible_h))

    r = layout["radius"]
    shadow = Image.new("L", (shot_w + 80, visible_h + 80), 0)
    ImageDraw.Draw(shadow).rounded_rectangle([40, 40, shot_w + 40, visible_h + 40], radius=r, fill=120)
    shadow = shadow.filter(ImageFilter.GaussianBlur(24))
    canvas.paste((0, 0, 0), (x - 40, y - 30), shadow)
    canvas.paste(shot, (x, y), rounded(shot, r))

    out_dir = os.path.join(OUT, profile)
    os.makedirs(out_dir, exist_ok=True)
    canvas.save(os.path.join(out_dir, f"{name}.png"), optimize=True)
    return True


if __name__ == "__main__":
    for profile in LAYOUTS:
        count = sum(frame(profile, *entry) for entry in CAPTIONS)
        print(f"{profile}: {count} screenshots -> {os.path.join(OUT, profile)}")
