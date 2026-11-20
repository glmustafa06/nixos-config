#!/usr/bin/env bash
# desk'in ekran görüntüsü yardımcısı. services/Screenshot.qml çağırır; elle de çalışır.
#
#   freeze <dosya> [ekran]                      Seçim ekranı için o anki görüntü (ekran: eDP-1 gibi)
#   crop   <kaynak> <WxH+X+Y> <yarıçap> <dosya> [copy]
#                                               Donmuş görüntüden kes (piksel)
#   grab   <"X,Y WxH"> <yarıçap> <dosya> [copy]
#                                               Ekrandan o an çek (Hyprland koordinatı; zamanlayıcıyla)
#   output <ekran> <dosya> [copy]               Bir ekranın tamamı (Shift+Print)
#
# yarıçap > 0: köşeler saydam yuvarlatılır (pencere görüntüsü, macOS'taki gibi; piksel).
# copy: resim panoya da kopyalanır. Dosya önce yanına yazılır, bitince yerine taşınır.
set -euo pipefail

die() {
    echo "capture.sh: $*" >&2
    exit 1
}

# Köşeleri yuvarlat (yerinde)
round_corners() {
    local file="$1" radius="$2" size w h
    [ "$radius" -gt 0 ] || return 0
    size="$(magick identify -format '%w %h' "$file")"
    w="${size% *}"
    h="${size#* }"
    magick "$file" \( -size "${w}x${h}" xc:black -fill white \
        -draw "roundrectangle 0,0,$((w - 1)),$((h - 1)),$radius,$radius" \) \
        -alpha off -compose CopyOpacity -composite "$file"
}

# Panoya kopyala. wl-copy arka planda kalır; çıktıları kapatılır ki çağıran beklemesin.
copy() {
    wl-copy --type image/png <"$1" >/dev/null 2>&1
}

# Yarım dosya hedefin yanında gizli adla (Dolphin'de görünmesin); bitince yerine taşınır
part() {
    mkdir -p "$(dirname "$1")"
    echo "$(dirname "$1")/.$(basename "$1").part.png"
}

finish() {
    local tmp="$1" out="$2" mode="${3:-}"
    mv -f "$tmp" "$out"
    [ "$mode" = copy ] && copy "$out"
    return 0
}

cmd="${1:-}"
shift || true

case "$cmd" in
    freeze)
        out="${1:?dosya}"
        mkdir -p "$(dirname "$out")"
        # Eski donmuş görüntüler silinir
        find "$(dirname "$out")" -maxdepth 1 -name 'frozen-*.png' ! -path "$out" -delete 2>/dev/null || true
        if [ -n "${2:-}" ]; then
            grim -o "$2" "$out"
        else
            grim "$out"
        fi
        ;;
    crop)
        src="${1:?kaynak}" geometry="${2:?WxH+X+Y}" radius="${3:-0}" out="${4:?dosya}"
        [ -f "$src" ] || die "donmuş görüntü yok: $src"
        tmp="$(part "$out")"
        magick "$src" -crop "$geometry" +repage "$tmp"
        round_corners "$tmp" "$radius"
        finish "$tmp" "$out" "${5:-}"
        ;;
    grab)
        geometry="${1:?X,Y WxH}" radius="${2:-0}" out="${3:?dosya}"
        tmp="$(part "$out")"
        grim -g "$geometry" "$tmp"
        round_corners "$tmp" "$radius"
        finish "$tmp" "$out" "${4:-}"
        ;;
    output)
        name="${1-}" out="${2:?dosya}"
        tmp="$(part "$out")"
        if [ -n "$name" ]; then
            grim -o "$name" "$tmp"
        else
            grim "$tmp"
        fi
        finish "$tmp" "$out" "${3:-}"
        ;;
    *)
        echo "Kullanım: $0 freeze|crop|grab|output …" >&2
        exit 2
        ;;
esac
