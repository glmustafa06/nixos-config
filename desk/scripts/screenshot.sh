#!/usr/bin/env bash
# Ekran görüntüsü (Print ve Shift+Print):
#   region: fareyle bir alan seç (Esc vazgeçer)
#   full  : bütün ekranlar
# Resim panoya kopyalanır ve Resimler/Ekran görüntüleri klasörüne kaydedilir.
# Bildirimine tıklayınca resim açılır.
set -uo pipefail

mode="${1:-region}"

# Resimler klasörü ~/.config/user-dirs.dirs'ten (Türkçe kurulumda "Resimler")
pictures="$(. "$HOME/.config/user-dirs.dirs" 2>/dev/null; echo "${XDG_PICTURES_DIR:-}")"
[ -n "$pictures" ] && [ "$pictures" != "$HOME" ] || pictures="$HOME/Pictures"
dir="$pictures/Ekran görüntüleri"
mkdir -p "$dir"
file="$dir/Ekran görüntüsü $(date +%Y-%m-%d\ %H.%M.%S).png"

case "$mode" in
    region)
        # Seçim iptal edilirse sessizce çık
        geometry="$(slurp -d)" || exit 0
        grim -g "$geometry" "$file" || exit 1
        ;;
    full)
        grim "$file" || exit 1
        ;;
    *)
        echo "Usage: $0 region|full" >&2
        exit 1
        ;;
esac

wl-copy --type image/png < "$file"

# Bildirim; tıklanınca (varsayılan eylem) resmi aç. notify-send tıklanmayı arka planda bekler
# (en çok bir saat; sonra bildirim merkezde kalır ama tıklamak resmi açmaz).
(
    action="$(timeout 1h notify-send --app-name "Ekran görüntüsü" --icon "$file" \
        --action "default=Aç" \
        "Ekran görüntüsü alındı" "Panoya kopyalandı · ${file#"$HOME"/}")"
    [ "$action" = "default" ] && xdg-open "$file"
) >/dev/null 2>&1 &
