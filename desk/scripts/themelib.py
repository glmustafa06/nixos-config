"""Renk hesapları: contrast.py ve bar_tone.py ortak kullanır.

- theme/Colors.qml'deki sabit renkleri okur (Qt.rgba, "#rrggbb", sayılar).
- Hyprland'in blur ayarını (brightness, contrast) appearance.lua'dan okur.
- Hyprland'in cam arkasını nasıl işlediğini ve Qt'nin katmanları nasıl
  üst üste koyduğunu taklit edip WCAG kontrastını hesaplar.
"""

import colorsys
import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
COLORS_QML = ROOT / "theme" / "Colors.qml"
METRICS_QML = ROOT / "theme" / "Metrics.qml"
# ~/.config/hypr → ~/nixos-config/hypr bağlantısı üzerinden
HYPR_APPEARANCE = Path(os.environ.get("DESK_HYPR_APPEARANCE", Path.home() / ".config/hypr/config/appearance.lua"))

WHITE = (1.0, 1.0, 1.0)
BLACK = (0.0, 0.0, 0.0)


# ---------- Renk matematiği ----------

def to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def luminance(rgb):
    r, g, b = (to_linear(c) for c in rgb[:3])
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = luminance(a), luminance(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def over(top, bottom):
    """Yarı saydam rengi alttakinin üstüne koyar (Qt ve Hyprland sRGB'de karıştırır)."""
    r, g, b, a = top
    return tuple(a * t + (1 - a) * u for t, u in zip((r, g, b), bottom[:3]))


def stack(layers, backdrop):
    """Alttan üste katmanlar: [cam, kutu, üstüne gelme…]"""
    color = backdrop
    for layer in layers:
        color = over(layer, color)
    return color


def hexcolor(rgb):
    return "#" + "".join(f"{round(min(max(c, 0), 1) * 255):02x}" for c in rgb[:3])


def parse_hex(text):
    text = text.lstrip("#")
    if len(text) == 8:  # Qt biçimi: #AARRGGBB
        a, text = int(text[:2], 16) / 255, text[2:]
    else:
        a = 1.0
    return tuple(int(text[i:i + 2], 16) / 255 for i in (0, 2, 4)) + (a,)


# ---------- Hyprland bulanıklığı ----------

def _gain(x, k):
    # Hyprland blurprepare.frag'daki "contrast" işlemi
    a = 0.5 * pow(2.0 * (x if x < 0.5 else 1.0 - x), k)
    return a if x < 0.5 else 1.0 - a


def read_blur(path=HYPR_APPEARANCE):
    """appearance.lua → blur bloğundaki brightness ve contrast (yoksa Hyprland varsayılanı)."""
    blur = {"brightness": 1.0, "contrast": 0.8916, "found": False, "path": str(path)}
    try:
        text = Path(path).read_text()
    except OSError:
        return blur
    match = re.search(r"\bblur\s*=\s*\{(.*?)\}", text, re.S)
    if not match:
        return blur
    blur["found"] = True
    for key in ("brightness", "contrast"):
        value = re.search(rf"^\s*{key}\s*=\s*([\d.]+)", match.group(1), re.M)
        if value:
            blur[key] = float(value.group(1))
    return blur


def backdrop(rgb, blur):
    """Camın arkasındaki rengin Hyprland'den geçtikten sonraki hâli."""
    return tuple(min(max(_gain(c, blur["contrast"]) * blur["brightness"], 0.0), 1.0) for c in rgb[:3])


# ---------- Colors.qml ----------

_PROPERTY = re.compile(r"^\s*readonly property (color|real|bool|string|int) (\w+):\s*(.+?)\s*$")


def _strip_comment(expr):
    # "//" yorumunu at ama "#rrggbb" gibi dizgilerin içine dokunma
    out, quote = [], None
    i = 0
    while i < len(expr):
        ch = expr[i]
        if quote:
            if ch == quote:
                quote = None
        elif ch in "\"'":
            quote = ch
        elif expr.startswith("//", i):
            break
        out.append(ch)
        i += 1
    return "".join(out).strip()


def read_colors(path=COLORS_QML):
    """Colors.qml'deki hesaplanabilen sabitleri döndürür.
    Renkler (r, g, b, a) olarak; koşullu ya da dosyadan gelen değerler atlanır."""
    tokens = {}

    def rgba(r, g, b, a=1.0):
        return (float(r), float(g), float(b), float(a))

    # Ayarlara bağlı değerler (Settings.reduceTransparency gibi) varsayılanlarıyla hesaplanır:
    # ayar kapalıyken (0, false) en saydam, yani en zor durum
    class _Settings:
        def __getattr__(self, name):
            return False

    env = {"__builtins__": {}, "max": max, "min": min, "rgba": rgba, "Settings": _Settings()}
    for line in Path(path).read_text().splitlines():
        match = _PROPERTY.match(line)
        if not match:
            continue
        kind, name, expr = match.groups()
        expr = _strip_comment(expr)
        if "?" in expr or "colorFile" in expr:
            continue  # koşullu ya da çalışırken belli olan değer
        expr = expr.replace("Qt.rgba(", "rgba(").replace("Math.max(", "max(").replace("Math.min(", "min(")
        expr = re.sub(r'"(#[0-9a-fA-F]{6,8})"', lambda m: repr(parse_hex(m.group(1))), expr)
        try:
            value = eval(expr, env, tokens)  # yalnızca kendi tema dosyamız
        except Exception:
            continue
        if kind == "color" and isinstance(value, tuple):
            tokens[name] = value
        elif kind in ("real", "int") and isinstance(value, (int, float)):
            tokens[name] = float(value)
        elif kind == "bool" and isinstance(value, bool):
            tokens[name] = value
    return tokens


# ---------- Vurgu rengi (Colors.qml'deki hesabın aynısı) ----------

def accent_from(raw_rgb, t):
    """matugen'in rengi → kabuğun kullandığı vurgu. Colors.qml → accent ile aynı adımlar:
    doygunluk ve açıklık sınırlanır, sonra parlaklık tabanın altındaysa açılır."""
    h, l, s = colorsys.rgb_to_hls(*raw_rgb[:3])
    if s == 0:
        return tuple(raw_rgb[:3])  # gri: olduğu gibi (Qt'de hslHue < 0)
    s = min(max(s, t["accentSaturationMin"]), t["accentSaturationMax"])
    l = min(max(l, t["accentLightnessMin"]), t["accentLightnessMax"])
    rgb = colorsys.hls_to_rgb(h, l, s)
    while luminance(rgb) < t["accentMinLuminance"] and l < 0.9:
        l = round(l + 0.01, 4)
        rgb = colorsys.hls_to_rgb(h, l, s)
    return rgb


def accent_foreground_from(raw_rgb):
    h, _, _ = colorsys.rgb_to_hls(*raw_rgb[:3])
    return colorsys.hls_to_rgb(h, 0.08, 0.35)


def sample_accents(t, steps=24):
    """Olası bütün vurgu renklerinden örnekler (her ton; soluk ve canlı)."""
    for i in range(steps):
        hue = i / steps
        for s in (0.2, 1.0):
            for l in (0.3, 0.5, 0.8):
                raw = colorsys.hls_to_rgb(hue, l, s)
                yield round(hue * 360), raw, accent_from(raw, t), accent_foreground_from(raw)


# ---------- Kilit ekranı (LockSurface.qml) ----------
# Duvar kâğıdının bulanık hâli üstünde beyaz yazılar. Bütün resim karartılır (lockDim), üst ve
# alt kenarlar ayrıca koyulaşır (lockEdge; Metrics.lockEdgeTop/Bottom'a kadar azalarak).
# Yazıların durduğu bölgeler (ekranın oranı olarak) ve gereken kontrast:
#   (ad, x0, x1, y0, y1, yazı rengi, en az)
LOCK_ZONES = [
    ("durum satırı", 0.80, 1.00, 0.00, 0.06, "lockText", 4.5),
    ("tarih ve saat", 0.30, 0.70, 0.10, 0.32, "lockText", 3.0),   # büyük yazı
    ("ad, şifre, uyarı", 0.38, 0.62, 0.70, 0.90, "lockText", 4.5),
    ("güç düğmeleri", 0.75, 1.00, 0.88, 1.00, "lockMuted", 3.0),
]


def lock_edge(y, t, m):
    """y yüksekliğinde (0..1) kenar karartmasının örtücülüğü."""
    a = t["lockEdge"][3]
    top, bottom = m["lockEdgeTop"], m["lockEdgeBottom"]
    edge = 0.0
    if y < top:
        edge = a * (1 - y / top)
    if y > bottom:
        edge = max(edge, a * (y - bottom) / (1 - bottom))
    return edge


def lock_worst(alpha, grid, columns, rows, t, m):
    """Karartma alpha iken bölgelerin en kötü kontrastı ve eşiği: [(ad, kontrast, en az)].
    grid: satır satır bloklar (r, g, b); bulanıklığı taklit eder."""
    result = []
    for name, x0, x1, y0, y1, token, minimum in LOCK_ZONES:
        worst = 99.0
        for row in range(rows):
            y = (row + 0.5) / rows
            if not (y0 <= y <= y1):
                continue
            for column in range(columns):
                x = (column + 0.5) / columns
                if not (x0 <= x <= x1):
                    continue
                bg = stack([(0, 0, 0, alpha), (0, 0, 0, lock_edge(y, t, m))], grid[row * columns + column])
                fg = over(t[token], bg) if len(t[token]) == 4 else t[token]
                worst = min(worst, contrast(fg, bg))
        result.append((name, worst, minimum))
    return result
