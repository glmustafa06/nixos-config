#!/usr/bin/env python3
"""Uygulamaların renkleri desk'le aynı olsun: kitty ve Dolphin (Kvantum).

    python3 scripts/apps_theme.py            # colors.sh sonunda kendiliğinden çalışır

Vurgu rengi ~/.local/state/desk/colors.json'dan gelir ve Colors.qml'deki adımlarla
okunur hâle getirilir (themelib.accent_from). Yazılanlar:

  ~/.config/kitty/desk-colors.conf     kitty.conf'un sonunda: include desk-colors.conf
                                        Yazı tipi, boşluklar, imleç (theme/kitty/settings.conf)
                                        ve renkler. Açık kitty pencereleri SIGUSR1 ile yenilenir.
  ~/.config/Kvantum/Desk/              Kvantum teması (KvMojave'den uyarlandı): Grafit renkler,
                                        Finder gibi saydam kenar çubuğu, opak dosya alanı.
                                        kvantum.kvconfig'te seçili tema da Desk yapılır.
  ~/.local/share/color-schemes/Desk.colors
                                        aynı renklerle KDE renk şeması
  ~/.config/kdeglobals                 KDE programlarının stili (kvantum) ve renk şeması (Desk);
                                        dosyadaki başka ayarlara dokunulmaz.
Açık Dolphin yeniden açılınca değişir.

Okunabilirlik scripts/contrast.py'de denetlenir (arkada beyaz sayfa olsa da).
"""

import colorsys
import json
import subprocess
import sys
from pathlib import Path

import themelib as tl

STATE = Path.home() / ".local/state/desk/colors.json"
KITTY = Path.home() / ".config/kitty/desk-colors.conf"
KVANTUM = Path.home() / ".config/Kvantum/Desk"
TEMPLATES = tl.ROOT / "theme" / "kvantum"

# ---------- kitty ----------
# Koyu, buzlu cam zemin (Hyprland arkasını bulanıklaştırır; desk camına yakın örtücülük).
# 16 renk, arkada beyaz bir sayfa varken de okunacak açıklıkta; contrast.py denetler.
KITTY_OPACITY = 0.80
KITTY_BACKGROUND = "#121316"
KITTY_FOREGROUND = "#e6e3dd"
KITTY_PALETTE = {
    "color0": "#2b2e33", "color8": "#9399a1",    # siyah / gri (yorumlar)
    "color1": "#f79595", "color9": "#ffadad",    # kırmızı
    "color2": "#93d68f", "color10": "#aee6aa",   # yeşil
    "color3": "#ecc679", "color11": "#f6d896",   # sarı
    "color4": "#90b8f8", "color12": "#accaff",   # mavi
    "color5": "#d0a9f5", "color13": "#e0c2ff",   # mor
    "color6": "#74d3c8", "color14": "#9ae6dd",   # camgöbeği
    "color7": "#cfd2d6", "color15": "#f3f1ed",   # beyaz
}

# ---------- Dolphin (Kvantum) ----------
# Kenar çubuğu, araç çubuğu ve alt satır pencere zemininde: desk camıyla aynı renk, biraz daha
# örtücü. Dosya alanı (base) opak.
KVANTUM_WINDOW = "#1e2024"
KVANTUM_WINDOW_INACTIVE = "#1b1c20"
KVANTUM_WINDOW_OPACITY = 0.82
KVANTUM_COLORS = {
    "window.color": "#1e2024",
    "inactive.window.color": "#1b1c20",
    "base.color": "#17181b",
    "inactive.base.color": "#151619",
    "alt.base.color": "#1c1d21",
    "inactive.alt.base.color": "#1a1b1e",
    "button.color": "#34373c",
    "light.color": "#4c5057",
    "mid.light.color": "#43474d",
    "dark.color": "#0f1012",
    "mid.color": "#2c2f34",
    "tooltip.base.color": "#2a2c30",
    "text.color": "#f3f1ed",
    "inactive.text.color": "#e2dfd9",
    "window.text.color": "#f3f1ed",
    "inactive.window.text.color": "#e2dfd9",
    "button.text.color": "#f3f1ed",
    "disabled.text.color": "#9a9ea5",
    "tooltip.text.color": "#f3f1ed",
    # vurgu: aşağıda eklenir (highlight, link)
    "link.visited.color": "#c99ff1",
}


def hexcolor(rgb):
    return tl.hexcolor(rgb)


def accents():
    """(vurgu, vurgunun üstündeki yazı) — Colors.qml'deki accent ve accentForeground."""
    t = tl.read_colors()
    raw_hex = "#5DBFAE"
    try:
        raw_hex = json.loads(STATE.read_text()).get("accent", raw_hex)
    except (OSError, ValueError):
        pass
    raw = tl.parse_hex(raw_hex)
    return tl.accent_from(raw, t), tl.accent_foreground_from(raw)


def shade(rgb, lightness):
    h, _, s = colorsys.rgb_to_hls(*rgb[:3])
    return colorsys.hls_to_rgb(h, lightness, s)


# Seçili dosya, kenar çubuğunda seçili yer, menüde üstüne gelinen satır: vurgunun tonunda, açık
# yazının okunacağı kadar koyu bir zemin (Finder gibi). Dolphin seçili dosyanın yazısını da normal
# yazı renginde çizer; açık vurgunun üstünde okunmazdı.
SELECTION_TEXT = "#f3f1ed"
SELECTION_CONTRAST = 4.6


def selection_from(accent):
    h, lightness, s = colorsys.rgb_to_hls(*accent[:3])
    text = tl.parse_hex(SELECTION_TEXT)
    while lightness > 0.05 and tl.contrast(text, colorsys.hls_to_rgb(h, lightness, s)) < SELECTION_CONTRAST:
        lightness -= 0.01
    return colorsys.hls_to_rgb(h, lightness, s)


def kitty_text(accent, foreground):
    a, fg = hexcolor(accent), hexcolor(foreground)
    settings = (tl.ROOT / "theme" / "kitty" / "settings.conf").read_text().rstrip("\n")
    lines = [
        "# desk: scripts/apps_theme.py üretir (duvar kâğıdı değişince); elle değiştirme.",
        "# kitty.conf'un sonunda: include desk-colors.conf",
        "# Kendi ayarların bunları ezsin istersen kitty.conf'ta include satırının altına yaz.",
        "",
        settings,
        "",
        "# --- Renkler (desk: Grafit, vurgu duvar kâğıdından)",
        f"background_opacity {KITTY_OPACITY}",
        f"background {KITTY_BACKGROUND}",
        f"foreground {KITTY_FOREGROUND}",
        f"cursor {a}",
        f"cursor_text_color {KITTY_BACKGROUND}",
        f"selection_background {a}",
        f"selection_foreground {fg}",
        f"url_color {a}",
        f"active_border_color {a}",
        "inactive_border_color #3a3d42",
        "tab_bar_background #17181b",
        f"active_tab_background {a}",
        f"active_tab_foreground {fg}",
        "inactive_tab_background #2a2c30",
        "inactive_tab_foreground #a9adb3",
        f"mark1_background {a}",
    ]
    lines += [f"{name} {value}" for name, value in KITTY_PALETTE.items()]
    return "\n".join(lines) + "\n"


def kvantum_files(accent, foreground):
    selection = hexcolor(selection_from(accent))
    colors = dict(KVANTUM_COLORS)
    colors["highlight.color"] = selection
    colors["inactive.highlight.color"] = selection
    colors["highlight.text.color"] = SELECTION_TEXT
    colors["inactive.highlight.text.color"] = SELECTION_TEXT
    colors["link.color"] = hexcolor(accent)
    general = "\n".join(f"{k}={v}" for k, v in colors.items())
    kvconfig = (TEMPLATES / "Desk.kvconfig.in").read_text().replace("{{general_colors}}", general)
    svg = (TEMPLATES / "Desk.svg.in").read_text()
    values = {
        "window": KVANTUM_WINDOW,
        "window_inactive": KVANTUM_WINDOW_INACTIVE,
        "window_opacity": f"{KVANTUM_WINDOW_OPACITY:.2f}",
        "accent": hexcolor(accent),
        "accent_dark": hexcolor(shade(accent, 0.38)),
        "accent_light": hexcolor(shade(accent, 0.78)),
        "accent_muted": hexcolor(shade(accent, 0.45)),
        "selection": selection,
    }
    for key, value in values.items():
        svg = svg.replace("{{" + key + "}}", value)
    return kvconfig, svg


# ---------- KDE renk şeması (kdeglobals) ----------
# Plasma dışında KDE programları (Dolphin, Okular, Ark…) iki şeyi kendileri seçer:
#   stil: kdeglobals [KDE] widgetStyle; yazılı değilse Breeze (qt6ct'yi dinlemez). Dolphin'in
#         Kvantum temasını hiç almamasının nedeni buydu → widgetStyle=kvantum
#   renk: [UiSettings] ColorScheme; yazılı değilse Breeze Açık/Koyu şemasını kendisi uygular ve
#         Kvantum'un renklerini ezer → kendi şemamız (Desk.colors) ve ColorScheme=Desk
# Aynı renkler kdeglobals'a da yazılır (şema yöneticisi olmayan KDE programları oradan okur).
KDEGLOBALS = Path.home() / ".config/kdeglobals"
COLOR_SCHEME = Path.home() / ".local/share/color-schemes/Desk.colors"
KVANTUM_SELECTED = Path.home() / ".config/Kvantum/kvantum.kvconfig"
SCHEME_EXTRA = {
    "ColorEffects:Disabled": {
        "Color": "56,56,56", "ColorAmount": "0", "ColorEffect": "0", "ContrastAmount": "0.65",
        "ContrastEffect": "1", "IntensityAmount": "0.1", "IntensityEffect": "2",
    },
    "ColorEffects:Inactive": {
        "ChangeSelectionColor": "true", "Color": "112,111,110", "ColorAmount": "0.025", "ColorEffect": "2",
        "ContrastAmount": "0.1", "ContrastEffect": "2", "Enable": "false", "IntensityAmount": "0",
        "IntensityEffect": "0",
    },
    "KDE": {"contrast": "4"},
}


def rgb(hex_or_rgb):
    c = tl.parse_hex(hex_or_rgb) if isinstance(hex_or_rgb, str) else hex_or_rgb
    return ",".join(str(round(v * 255)) for v in c[:3])


def scheme_groups(accent, foreground):
    """Renk şemasının [Colors:*] grupları."""
    c = KVANTUM_COLORS
    a = rgb(accent)
    common = {
        "ForegroundNormal": rgb(c["text.color"]),
        "ForegroundInactive": rgb(c["disabled.text.color"]),
        "ForegroundActive": a,
        "ForegroundLink": a,
        "ForegroundVisited": rgb(KITTY_PALETTE["color5"]),
        "ForegroundNegative": rgb(KITTY_PALETTE["color1"]),
        "ForegroundNeutral": rgb(KITTY_PALETTE["color3"]),
        "ForegroundPositive": rgb(KITTY_PALETTE["color2"]),
        "DecorationFocus": a,
        "DecorationHover": a,
    }

    def group(normal, alternate):
        return dict(common, BackgroundNormal=rgb(normal), BackgroundAlternate=rgb(alternate))

    chosen = selection_from(accent)
    text = rgb(SELECTION_TEXT)
    selection = dict(common, BackgroundNormal=rgb(chosen), BackgroundAlternate=rgb(shade(chosen, 0.3)),
                     ForegroundNormal=text, ForegroundInactive=text, ForegroundActive=text, ForegroundLink=text)
    return {
        "Colors:Window": group(c["window.color"], c["inactive.window.color"]),
        "Colors:View": group(c["base.color"], c["alt.base.color"]),
        "Colors:Button": group(c["button.color"], c["mid.color"]),
        "Colors:Selection": selection,
        "Colors:Tooltip": group(c["tooltip.base.color"], c["button.color"]),
        "Colors:Header": group(c["window.color"], c["inactive.window.color"]),
        "Colors:Header][Inactive": group(c["inactive.window.color"], c["inactive.window.color"]),
        "Colors:Complementary": group(c["base.color"], c["window.color"]),
    }


def scheme_file(accent, foreground):
    """~/.local/share/color-schemes/Desk.colors"""
    groups = dict(SCHEME_EXTRA)
    groups.update(scheme_groups(accent, foreground))
    groups["General"] = {"ColorScheme": "Desk", "Name": "Desk", "shadeSortColumn": "true"}
    lines = ["# desk: scripts/apps_theme.py üretir (duvar kâğıdı değişince); elle değiştirme."]
    for name in sorted(groups):
        lines += ["", f"[{name}]"] + [f"{k}={v}" for k, v in groups[name].items()]
    return "\n".join(lines) + "\n"


def kde_groups(accent, foreground):
    """kdeglobals'ta değiştirilen gruplar ve anahtarlar."""
    groups = scheme_groups(accent, foreground)
    groups["General"] = {"ColorScheme": "Desk", "AccentColor": rgb(accent)}
    groups["KDE"] = {"widgetStyle": "kvantum"}
    groups["UiSettings"] = {"ColorScheme": "Desk"}
    return groups


def ini_update(text, groups):
    """KDE ayar dosyasında yalnızca verilen grupların verilen anahtarlarını değiştirir;
    başka her şey (yorumlar, başka gruplar, başka anahtarlar) olduğu gibi kalır."""
    lines = text.splitlines()
    out, current, seen = [], None, {}

    def flush(group):
        # Grubun sonunda henüz yazılmamış anahtarlar (grubun ardındaki boş satırlardan önce)
        missing = [(k, v) for k, v in groups.get(group, {}).items() if k not in seen.setdefault(group, set())]
        blanks = 0
        while out and not out[-1].strip():
            out.pop()
            blanks += 1
        for key, value in missing:
            out.append(f"{key}={value}")
            seen[group].add(key)
        out.extend([""] * blanks)

    for line in lines:
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            if current is not None:
                flush(current)
            current = stripped[1:-1]
            out.append(line)
            continue
        if current in groups and "=" in line and not stripped.startswith("#"):
            key = line.split("=", 1)[0].strip()
            if key in groups[current]:
                out.append(f"{key}={groups[current][key]}")
                seen.setdefault(current, set()).add(key)
                continue
        out.append(line)
    if current is not None:
        flush(current)
    present = {l.strip()[1:-1] for l in lines if l.strip().startswith("[") and l.strip().endswith("]")}
    for group, values in groups.items():
        if group not in present:
            if out and out[-1].strip():
                out.append("")
            out.append(f"[{group}]")
            out += [f"{k}={v}" for k, v in values.items()]
    return "\n".join(out) + "\n"


def write_if_changed(path, text):
    """Değiştiyse yazar; değişti mi döndürür."""
    try:
        if path.read_text() == text:
            return False
    except OSError:
        pass
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    return True


def update_ini(path, groups):
    """Dosyadaki yalnızca verilen anahtarları değiştirir (ini_update); değişti mi döndürür."""
    try:
        old = path.read_text()
    except OSError:
        old = ""
    return write_if_changed(path, ini_update(old, groups))


def main():
    accent, foreground = accents()

    if write_if_changed(KITTY, kitty_text(accent, foreground)):
        # Açık kitty pencereleri ayarı yeniden okusun (kitty yoksa sessizce geç)
        subprocess.run(["pkill", "-USR1", "-x", "kitty"], check=False)
        print(f"kitty: {KITTY}", file=sys.stderr)

    kvconfig, svg = kvantum_files(accent, foreground)
    changed = write_if_changed(KVANTUM / "Desk.kvconfig", kvconfig)
    changed |= write_if_changed(KVANTUM / "Desk.svg", svg)
    changed |= update_ini(KVANTUM_SELECTED, {"General": {"theme": "Desk"}})
    changed |= write_if_changed(COLOR_SCHEME, scheme_file(accent, foreground))
    changed |= update_ini(KDEGLOBALS, kde_groups(accent, foreground))
    if changed:
        print(f"Dolphin: {KVANTUM}, {COLOR_SCHEME} ve {KDEGLOBALS} (açık Dolphin yeniden açılınca değişir)",
              file=sys.stderr)


if __name__ == "__main__":
    main()
