#!/usr/bin/env python3
"""Bar açık mı koyu mu olsun: duvar kâğıdının üst şeridini ölçer.

    python3 scripts/bar_tone.py <resim>                      # sonucu yazar
    python3 scripts/bar_tone.py <resim> --merge a.json --out b.json

Bar duvar kâğıdının en üst şeridinin üstünde durur ve arkasını Hyprland bulanıklaştırır.
Betik o şeridi ekran boyutuna göre kırpar, bulanıklığı taklit etmek için küçük bloklara
böler ve her blokta iki görünümün (koyu duvar kâğıdı → açık yazı, açık duvar kâğıdı →
koyu yazı) kontrastını hesaplar. En kötü bloğu daha iyi olan görünüm seçilir.
Ortadaki ada her zaman siyah olduğu için onun altı hesaba katılmaz.
Şerit çok karışıksa (yarısı beyaz, yarısı siyah gibi) seçilen görünümün zemini,
en kötü yerde bile yazı okunana kadar koyulaştırılır ("barOpacity").

Kilit ekranı için de ölçer: yazıların durduğu yerlerde (themelib.LOCK_ZONES) beyaz yazının
okunması için resmin ne kadar karartılması gerektiğini "lockDim" olarak yazar.

Resmi ImageMagick okur (NixOS: home.nix → imagemagick). Yoksa koyu görünüm kalır.
"""

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

import themelib as tl

BAR_HEIGHT = 32       # Metrics.barHeight
BLUR_SPREAD = 16      # bulanıklık barın biraz altını da içeri çeker
BLOCK = 40            # bulanıklığın yaklaşık genişliği (size 5, passes 2)
ISLAND = (0.35, 0.65) # ada bu aralıkta: altında yazı yok


def screen_size():
    """Odaktaki ekranın mantıksal boyutu; Hyprland yoksa 1920x1080."""
    try:
        out = subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True, text=True, timeout=3).stdout
        monitors = json.loads(out)
        monitor = next((m for m in monitors if m.get("focused")), monitors[0])
        scale = monitor.get("scale", 1) or 1
        width, height = monitor["width"], monitor["height"]
        if monitor.get("transform", 0) % 2:
            width, height = height, width
        return round(width / scale), round(height / scale)
    except Exception:
        return 1920, 1080


def read_strip(image, width, height):
    """Duvar kâğıdını ekranı dolduracak şekilde kırpar (ortalı), üst şeridi bloklara böler.
    [(r, g, b)] döndürür (0..1)."""
    tool = shutil.which("magick") or shutil.which("convert")
    if not tool:
        raise RuntimeError("ImageMagick yok (magick ya da convert bulunamadı)")
    columns = max(8, width // BLOCK)
    strip = BAR_HEIGHT + BLUR_SPREAD
    command = [tool, str(image) + "[0]", "-auto-orient",
               "-resize", f"{width}x{height}^", "-gravity", "center", "-extent", f"{width}x{height}",
               "+gravity", "-crop", f"{width}x{strip}+0+0", "+repage",
               "-scale", f"{columns}x1!",  # kutu ortalaması: her blok tek renk
               "-depth", "8", "ppm:-"]
    data = subprocess.run(command, capture_output=True, check=True, timeout=30).stdout
    # PPM (P6): başlık üç satır, sonra RGB baytları
    parts = data.split(b"\n", 3)
    if parts[0] != b"P6":
        raise RuntimeError("ImageMagick beklenmeyen çıktı verdi")
    w, h = map(int, parts[1].split())
    pixels = parts[3]
    return [tuple(pixels[i + k] / 255 for k in range(3)) for i in range(0, w * h * 3, 3)]


LOCK_GRID = (16, 9)   # kilit ekranının çok güçlü bulanıklığını kaba bloklar taklit eder


def read_grid(image, width, height, columns, rows):
    """Bütün resim, ekranı dolduracak şekilde kırpılmış, columns x rows bloğa ortalanmış."""
    tool = shutil.which("magick") or shutil.which("convert")
    if not tool:
        raise RuntimeError("ImageMagick yok (magick ya da convert bulunamadı)")
    command = [tool, str(image) + "[0]", "-auto-orient",
               "-resize", f"{width}x{height}^", "-gravity", "center", "-extent", f"{width}x{height}",
               "+gravity", "-scale", f"{columns}x{rows}!", "-depth", "8", "ppm:-"]
    data = subprocess.run(command, capture_output=True, check=True, timeout=30).stdout
    parts = data.split(b"\n", 3)
    if parts[0] != b"P6":
        raise RuntimeError("ImageMagick beklenmeyen çıktı verdi")
    pixels = parts[3]
    return [tuple(pixels[i + k] / 255 for k in range(3)) for i in range(0, columns * rows * 3, 3)]


def lock_dim(grid, colors, metrics):
    """Bütün bölgelerde yazı okunsun diye gereken en az karartma (lockDimMin ile lockDimSafe arası)."""
    columns, rows = LOCK_GRID
    low, high = colors["lockDimMin"], colors["lockDimSafe"]
    for step in range(round(low * 100), round(high * 100) + 1):
        alpha = step / 100
        if all(c >= minimum for _, c, minimum in tl.lock_worst(alpha, grid, columns, rows, colors, metrics)):
            return alpha
    return high


def worst(blocks, text, background, blur):
    return min(tl.contrast(text, tl.over(background, tl.backdrop(b, blur))) for b in blocks)


def decide(blocks, colors, blur):
    """Her görünüm için en kötü bloktaki kontrast; büyük olan kazanır.
    Kazanan bile 4.5'in altındaysa zeminin gereken en düşük örtücülüğü de bulunur."""
    left, right = ISLAND
    n = len(blocks)
    visible = [b for i, b in enumerate(blocks) if not (left * n <= i < right * n)]
    scores = {}
    for tone, prefix in (("dark", "barDark"), ("light", "barLight")):
        scores[tone] = worst(visible, colors[prefix + "Text"], colors[prefix + "Background"], blur)
    tone = max(scores, key=scores.get)

    prefix = "barDark" if tone == "dark" else "barLight"
    text, background = colors[prefix + "Text"], colors[prefix + "Background"]
    opacity = 0.0  # 0: Colors.qml'deki değer
    if scores[tone] < 4.5:
        for step in range(round(background[3] * 100), 96):
            opacity = step / 100
            if worst(visible, text, background[:3] + (opacity,), blur) >= 4.5:
                break
    return tone, scores, opacity


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("image")
    parser.add_argument("--merge", help="bu JSON'a barTone ekle (matugen çıktısı)")
    parser.add_argument("--out", help="sonucu buraya yaz")
    parser.add_argument("--size", help="ekran boyutu, ör. 1920x1200 (varsayılan: Hyprland'den)")
    parser.add_argument("--hypr", help="appearance.lua yolu")
    args = parser.parse_args()

    colors = tl.read_colors()
    blur = tl.read_blur(args.hypr or tl.HYPR_APPEARANCE)
    width, height = map(int, args.size.split("x")) if args.size else screen_size()

    try:
        blocks = read_strip(args.image, width, height)
        tone, scores, opacity = decide(blocks, colors, blur)
        print(f"Bar: {'açık (koyu yazı)' if tone == 'light' else 'koyu (açık yazı)'}"
              f" · en kötü yerde kontrast {scores[tone]:.1f}"
              f" (öteki görünüm {scores['dark' if tone == 'light' else 'light']:.1f})", file=sys.stderr)
        if opacity:
            print(f"  Üst şerit karışık; okunsun diye barın zemini koyulaştırıldı (örtücülük {opacity:.2f}).",
                  file=sys.stderr)
    except Exception as error:
        print(f"Bar görünümü ölçülemedi ({error}); koyu kalıyor.", file=sys.stderr)
        tone, opacity = "dark", 0.0

    try:
        grid = read_grid(args.image, width, height, *LOCK_GRID)
        dim = lock_dim(grid, colors, tl.read_colors(tl.METRICS_QML))
        print(f"Kilit ekranı: duvar kâğıdı %{round(dim * 100)} karartılır", file=sys.stderr)
    except Exception as error:
        print(f"Kilit ekranı ölçülemedi ({error}); güvenli karartma kullanılır.", file=sys.stderr)
        dim = 0.0

    result = {}
    if args.merge:
        result = json.loads(Path(args.merge).read_text())
    result["barTone"] = tone
    result["barOpacity"] = opacity
    result["lockDim"] = dim
    text = json.dumps(result, indent=2) + "\n"
    if args.out:
        # Yerinde yaz (taşıma değil): kabuk dosyayı izliyor
        Path(args.out).write_text(text)
    else:
        sys.stdout.write(text)


if __name__ == "__main__":
    main()
