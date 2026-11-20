#!/usr/bin/env python3
"""Okunabilirlik denetimi. Renk ya da saydamlık değiştirdikten sonra çalıştır:

    python3 scripts/contrast.py

Cam yüzeylerin (menüler, kontrol merkezi, ses göstergesi…) arkasında en kötü
durumda bembeyaz bir sayfa vardır. Bu betik theme/Colors.qml'deki renkleri ve
Hyprland'in blur ayarını okuyup o durumdaki kontrastı hesaplar.

Kural (README → Tasarım kuralları):
  yazı ve gri yazı ≥ 4.5   (WCAG AA)
  soluk yazı, simge ≥ 3.0  (yalnızca önemsiz bilgiler: süre, ipucu, başlık)
  üstüne gelince değişen geçici zeminlerde gri yazı ≥ 3.0

Ayrıca modules/ ve components/ içinde elle yazılmış renk var mı diye bakar:
bütün renkler theme/Colors.qml'den gelmeli ki bu denetim hepsini görsün.

Bir kural bozulursa 1 ile çıkar.
"""

import argparse
import re
import sys

import themelib as tl

AA, LARGE = 4.5, 3.0


def glass_checks(t):
    """(yüzey adı, alttan üste katmanlar, [(ön plan adı, renk, eşik)])"""
    glass = t["glass"]
    tile = [glass, t["tile"]]
    return [
        ("cam (menü, panel)", [glass], [
            ("yazı", t["text"], AA),
            ("gri yazı", t["textMuted"], AA),
            ("soluk yazı", t["textFaint"], LARGE),
            ("alt satır", t["footerText"], AA),
            ("uyarı", t["warning"], AA),
        ]),
        ("kutu", tile, [
            ("yazı", t["text"], AA),
            ("gri yazı", t["textMuted"], AA),
            ("soluk yazı", t["textFaint"], LARGE),
            ("tehlike", t["danger"], AA),
        ]),
        ("kutu, üstüne gelince", [glass, t["tileHover"]], [
            ("yazı", t["text"], AA),
        ]),
        ("kutudaki satır, üstüne gelince", tile + [t["hover"]], [
            ("yazı", t["text"], AA),
            ("gri yazı", t["textMuted"], LARGE),
        ]),
        ("düğme", tile + [t["button"]], [
            ("yazı", t["text"], AA),
            ("simge", t["circleOffIcon"], LARGE),
            ("gri yazı", t["textMuted"], LARGE),
            ("uyarı simgesi", t["warning"], LARGE),   # acil bildirimin simgesi (merkez)
        ]),
        ("düğme, üstüne gelince", tile + [t["buttonHover"]], [
            ("yazı", t["text"], AA),
            ("simge", t["circleOffIcon"], LARGE),
        ]),
        ("yuvarlak düğme, üstüne gelince", tile + [t["circleHover"]], [
            ("simge", t["circleOffIcon"], LARGE),
        ]),
        ("tehlikeli düğme", tile + [t["dangerFillHover"]], [
            ("yazı", t["danger"], AA),
        ]),
        ("dock'taki ad etiketi", [t["tooltip"]], [
            ("yazı", t["text"], AA),
        ]),
        ("dock", [glass], [
            ("açık uygulama noktası", t["dockIndicator"], LARGE),
        ]),
        ("dock'taki bildirim rozeti", [t["badge"]], [
            ("sayı", t["badgeText"], AA),
        ]),
        ("ekran görüntüsü araç çubuğu", [t["tooltip"]], [
            ("yazı", t["text"], AA),
            ("gri yazı", t["textMuted"], AA),
        ]),
        ("önizlemenin düğmesi (bembeyaz görüntü üstünde)", [t["previewBadge"]], [
            ("simge", t["text"], LARGE),
        ]),
        ("önizlemedeki kayıt süresi (bembeyaz görüntü üstünde)", [t["previewShade"]], [
            ("yazı", t["text"], AA),
        ]),
        ("ada", [t["island"]], [
            ("kayıt noktası", t["recordDot"], LARGE),
        ]),
        ("yazı kutusu", tile + [t["field"]], [
            ("yazı", t["text"], AA),
            ("ipucu", t["textFaint"], LARGE),
        ]),
        # Ayarlar penceresi: kenar çubuğu cam, sayfa örtücü (arkası önemsiz)
        ("Ayarlar: kenar çubuğunda seçili bölüm", [glass, t["sidebarSelected"]], [
            ("yazı", t["text"], AA),
        ]),
        ("Ayarlar: kenar çubuğu, üstüne gelince", [glass, t["settingsRowHover"]], [
            ("yazı", t["text"], AA),
            ("gri yazı", t["textMuted"], AA),
        ]),
        ("Ayarlar: kenar çubuğundaki arama", [glass, t["field"]], [
            ("yazı", t["text"], AA),
            ("ipucu", t["textFaint"], LARGE),
        ]),
        ("Ayarlar: sayfa", [t["settingsBackground"]], [
            ("başlık", t["text"], AA),
            ("açıklama", t["textMuted"], AA),
            ("bölüm adı, kart altı notu", t["textFaint"], AA),
        ]),
        ("Ayarlar: kart", [t["settingsBackground"], t["settingsCard"]], [
            ("yazı", t["text"], AA),
            ("açıklama", t["textMuted"], AA),
            ("tutamak simgesi", t["textFaint"], LARGE),
        ]),
        ("Ayarlar: seçenekler", [t["settingsBackground"], t["settingsCard"], t["segment"]], [
            ("seçili olmayan", t["textMuted"], AA),
        ]),
        ("Ayarlar: seçili seçenek", [t["settingsBackground"], t["settingsCard"], t["segment"], t["segmentSelected"]], [
            ("yazı", t["text"], AA),
        ]),
        ("Ayarlar: düğme", [t["settingsBackground"], t["settingsCard"], t["circleOff"]], [
            ("yazı", t["text"], AA),
        ]),
        ("Ayarlar: sıfırla düğmesi", [t["settingsBackground"], t["settingsCard"], t["dangerFill"]], [
            ("yazı", t["danger"], AA),
        ]),
        ("Ayarlar: kısayol tuşu", [t["settingsBackground"], t["settingsCard"], t["keyCap"]], [
            ("yazı", t["text"], AA),
        ]),
        ("Ayarlar: sürüklenen satır", [t["settingsBackground"]], [
            ("yazı", t["text"], AA),
        ]),
    ]


def run_glass(t, blur, verbose=True):
    failures = []
    behind = tl.backdrop(tl.WHITE, blur)
    for surface, layers, pairs in glass_checks(t):
        bg = tl.stack(layers, behind)
        if verbose:
            print(f"  {surface}  ({tl.hexcolor(bg)})")
        for name, fg, minimum in pairs:
            ratio = tl.contrast(fg, bg)
            ok = ratio >= minimum
            if verbose:
                print(f"    {'✓' if ok else '✗'} {name:<12} {ratio:4.1f}  (en az {minimum})")
            if not ok:
                failures.append(f"{surface} → {name}: {ratio:.1f} < {minimum}")
    return failures


def run_accent(t, blur, verbose=True):
    """Vurgu rengi her tonda okunur mu: vurgu zemin üstündeki yazı, kutu üstündeki vurgu simgesi."""
    failures = []
    behind = tl.backdrop(tl.WHITE, blur)
    tile = tl.stack([t["glass"], t["tile"]], behind)
    worst_icon = worst_label = (99, None)
    for hue, raw, accent, foreground in tl.sample_accents(t):
        icon = tl.contrast(accent, tile)
        label = tl.contrast(foreground, accent)
        worst_icon = min(worst_icon, (icon, (hue, tl.hexcolor(raw), tl.hexcolor(accent))))
        worst_label = min(worst_label, (label, (hue, tl.hexcolor(raw), tl.hexcolor(accent))))
    for name, (ratio, info), minimum in (("kutu üstünde vurgu simgesi", worst_icon, LARGE),
                                         ("vurgu zemin üstünde yazı", worst_label, AA)):
        ok = ratio >= minimum
        if verbose:
            print(f"    {'✓' if ok else '✗'} {name:<28} en kötü {ratio:4.1f}  (en az {minimum}; ton {info[0]}°, {info[1]} → {info[2]})")
        if not ok:
            failures.append(f"vurgu → {name}: {ratio:.1f} < {minimum} ({info[1]})")
    return failures


def bar_report(t, blur):
    """Barın iki görünümü hangi duvar kâğıdı parlaklıklarında okunur (bilgi amaçlı)."""
    for tone in ("Dark", "Light"):
        fg, bg = t[f"bar{tone}Text"], t[f"bar{tone}Background"]
        ok = []
        for i in range(0, 101, 5):
            v = i / 100
            surface = tl.over(bg, tl.backdrop((v, v, v), blur))
            if tl.contrast(fg, surface) >= AA:
                ok.append(v)
        span = f"{min(ok):.2f}–{max(ok):.2f}" if ok else "hiçbiri"
        name = "koyu duvar kâğıdı (açık yazı)" if tone == "Dark" else "açık duvar kâğıdı (koyu yazı)"
        print(f"    {name}: arkası {span} gri düzeyindeyken ≥ {AA}")


def run_bar_forced(t, blur, verbose=True):
    """Ayarlarda bar görünümü elle seçilince (koyu ya da açık) zemin barForcedOpacity kadar örtücü:
    o zaman her duvar kâğıdında okunmalı (en kötü durum: koyu barın arkası beyaz, açığınki siyah)."""
    failures = []
    alpha = t["barForcedOpacity"]
    for tone, name in (("Dark", "koyu bar"), ("Light", "açık bar")):
        base = t[f"bar{tone}Background"]
        bg = (base[0], base[1], base[2], max(base[3], alpha))
        for role, key, need in (("yazı", "Text", AA), ("soluk simge", "TextMuted", 3.0)):
            fg = t[f"bar{tone}{key}"]
            worst = min(tl.contrast(fg, tl.over(bg, tl.backdrop((v / 100,) * 3, blur))) for v in range(0, 101, 5))
            mark = "✓" if worst >= need else "✗"
            if verbose:
                print(f"    {mark} {name}, {role}: {worst:.1f}  (en az {need})")
            if worst < need:
                failures.append(f"elle seçilmiş {name} → {role}: {worst:.1f} < {need} (barForcedOpacity)")
    return failures


def run_lock(t, verbose=True):
    """Kilit ekranı: ölçülmemiş duvar kâğıdında kullanılan güvenli karartma (lockDimSafe),
    bembeyaz bir duvar kâğıdında bile bütün yazıları okutmalı."""
    failures = []
    m = tl.read_colors(tl.METRICS_QML)
    columns, rows = 16, 9
    white = [tl.WHITE] * (columns * rows)
    for name, ratio, minimum in tl.lock_worst(t["lockDimSafe"], white, columns, rows, t, m):
        ok = ratio >= minimum
        if verbose:
            print(f"    {'✓' if ok else '✗'} {name:<18} {ratio:4.1f}  (en az {minimum})")
        if not ok:
            failures.append(f"kilit ekranı → {name}: {ratio:.1f} < {minimum} (lockDimSafe {t['lockDimSafe']:.2f})")
    return failures


def run_apps(t, blur, verbose=True):
    """kitty ve Dolphin (Kvantum): arkada beyaz sayfa varken de okunur mu (scripts/apps_theme.py)."""
    import apps_theme as at
    failures = []
    behind = tl.backdrop(tl.WHITE, blur)
    hexrgb = tl.parse_hex

    kitty_bg = tl.over(hexrgb(at.KITTY_BACKGROUND)[:3] + (at.KITTY_OPACITY,), behind)
    window_bg = tl.over(hexrgb(at.KVANTUM_WINDOW)[:3] + (at.KVANTUM_WINDOW_OPACITY,), behind)
    checks = [("kitty", kitty_bg, [("yazı", at.KITTY_FOREGROUND, AA)] +
               [(n, c, LARGE if n in ("color8",) else AA) for n, c in at.KITTY_PALETTE.items() if n not in ("color0",)]),
              ("Dolphin kenar çubuğu", window_bg, [("yazı", at.KVANTUM_COLORS["window.text.color"], AA),
                                                  ("soluk yazı", at.KVANTUM_COLORS["disabled.text.color"], LARGE)]),
              ("Dolphin dosya alanı", hexrgb(at.KVANTUM_COLORS["base.color"]), [("yazı", at.KVANTUM_COLORS["text.color"], AA),
                                                                               ("soluk yazı", at.KVANTUM_COLORS["disabled.text.color"], AA)])]
    for surface, bg, pairs in checks:
        if verbose:
            print(f"  {surface}  ({tl.hexcolor(bg)})")
        for name, fg, minimum in pairs:
            ratio = tl.contrast(hexrgb(fg), bg)
            ok = ratio >= minimum
            if verbose:
                print(f"    {'✓' if ok else '✗'} {name:<12} {ratio:4.1f}  (en az {minimum})")
            if not ok:
                failures.append(f"{surface} → {name}: {ratio:.1f} < {minimum}")
    # Seçili dosya, seçili yer, menüde üstüne gelinen satır: her olası vurgudan çıkan seçim zemini
    worst = None
    for hue, raw, accent, _ in tl.sample_accents(t):
        selection = at.selection_from(accent)
        ratio = tl.contrast(hexrgb(at.SELECTION_TEXT), selection)
        if worst is None or ratio < worst[0]:
            worst = (ratio, hue, selection)
    ok = worst[0] >= AA
    if verbose:
        print(f"  Dolphin seçim (en kötü vurgu: {worst[1]}°, {tl.hexcolor(worst[2])})")
        print(f"    {'✓' if ok else '✗'} {'yazı':<12} {worst[0]:4.1f}  (en az {AA})")
    if not ok:
        failures.append(f"Dolphin seçim → yazı: {worst[0]:.1f} < {AA}")
    return failures


def minimum_opacity(t, blur):
    """Kuralların hepsini geçen en düşük cam saydamlığı."""
    base = t["glass"]
    for step in range(0, 101):
        alpha = step / 100
        trial = dict(t, glass=base[:3] + (alpha,))
        if not run_glass(trial, blur, verbose=False):
            return alpha
    return None


HARDCODED = re.compile(r'Qt\.rgba\(\s*[\d.]|Qt\.hsla\(\s*[\d.]|Qt\.(lighter|darker)\(|"#[0-9a-fA-F]{6,8}"')


def run_section_icons(verbose=True):
    """Ayarlar'daki bölüm simgeleri: renkli kare üstünde beyaz çizgi (Colors.settingsSections)."""
    failures = []
    text = (tl.ROOT / "theme" / "Colors.qml").read_text()
    block = re.search(r"settingsSections: \(\{(.*?)\}\)", text, re.S)
    white = (1.0, 1.0, 1.0)
    for name, value in re.findall(r"(\w+): \"(#[0-9a-fA-F]{6})\"", block.group(1) if block else ""):
        fill = tuple(int(value[i:i + 2], 16) / 255 for i in (1, 3, 5))
        # Üstü %12 aydınlık (SectionIcon'daki degrade): en kötü yer orası
        top = tuple(min(1.0, c * 1.12) for c in fill)
        ratio = min(tl.contrast(white, fill), tl.contrast(white, top))
        ok = ratio >= LARGE
        if verbose:
            print(f"    {'✓' if ok else '✗'} {name:<14} {value}  {ratio:4.1f}  (en az {LARGE})")
        if not ok:
            failures.append(f"Ayarlar bölüm simgesi {name} ({value}): {ratio:.1f} < {LARGE}")
    if not block:
        failures.append("Colors.qml → settingsSections okunamadı")
    return failures


def lint():
    """modules/ ve components/ içinde elle yazılmış renkler."""
    found = []
    for folder in ("modules", "components"):
        for path in sorted((tl.ROOT / folder).rglob("*.qml")):
            for number, line in enumerate(path.read_text().splitlines(), 1):
                if HARDCODED.search(line.split("//")[0]):
                    found.append(f"{path.relative_to(tl.ROOT)}:{number}: {line.strip()}")
    return found


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--hypr", help="appearance.lua yolu (varsayılan ~/.config/hypr/config/appearance.lua)")
    args = parser.parse_args()

    t = tl.read_colors()
    blur = tl.read_blur(args.hypr or tl.HYPR_APPEARANCE)
    if not blur["found"]:
        print(f"! {blur['path']} okunamadı; Hyprland varsayılanları kullanılıyor.")
    print(f"Hyprland blur: brightness {blur['brightness']}, contrast {blur['contrast']}")
    print(f"Cam saydamlığı: {t['glassOpacity']:.2f} (taban {t['glassMinOpacity']:.2f})")
    print(f"Arkada beyaz sayfa varken cam bu renge iner: {tl.hexcolor(tl.stack([t['glass']], tl.backdrop(tl.WHITE, blur)))}\n")

    print("Cam yüzeyler (en kötü durum: arkası beyaz)")
    failures = run_glass(t, blur)
    print("\nVurgu rengi (bütün tonlar)")
    failures += run_accent(t, blur)
    print("\nBar (duvar kâğıdına göre görünüm seçilir: scripts/bar_tone.py)")
    bar_report(t, blur)
    print(f"  Görünüm Ayarlar'da elle seçilince (zemin {t['barForcedOpacity']:.2f}, her duvar kâğıdında)")
    failures += run_bar_forced(t, blur)
    print(f"\nKilit ekranı (bembeyaz duvar kâğıdı, karartma {t['lockDimSafe']:.2f})")
    failures += run_lock(t)
    print("\nUygulamalar (kitty, Dolphin; scripts/apps_theme.py)")
    failures += run_apps(t, blur)
    print("\nAyarlar'daki bölüm simgeleri (beyaz simge, renkli kare)")
    failures += run_section_icons()

    lowest = minimum_opacity(t, blur)
    print(f"\nBu ayarlarla en düşük güvenli cam saydamlığı: {lowest}")
    if lowest is not None and t["glassMinOpacity"] < lowest:
        failures.append(f"Colors.qml → glassMinOpacity {t['glassMinOpacity']:.2f}, en az {lowest:.2f} olmalı")

    hardcoded = lint()
    if hardcoded:
        print("\nElle yazılmış renkler (theme/Colors.qml'e taşı):")
        for line in hardcoded:
            print("  " + line)
        failures.append(f"{len(hardcoded)} elle yazılmış renk")

    if failures:
        print("\n✗ Kural dışı:")
        for line in failures:
            print("  - " + line)
        return 1
    print("\n✓ Hepsi okunur.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
