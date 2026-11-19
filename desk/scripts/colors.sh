#!/usr/bin/env bash
# Duvar kâğıdından kabuğun renklerini üretir ve ~/.local/state/desk/colors.json'a yazar:
#   - vurgu rengi (matugen)
#   - barın görünümü: açık duvar kâğıdında koyu yazı (scripts/bar_tone.py)
# Shell bu dosyayı izlediği için renkler anında değişir.
#   Kullanım: scripts/colors.sh <resim>
set -euo pipefail
export LC_ALL=C # Türkçe yerel ayarı betiği bozmasın

image="${1:?Usage: colors.sh <image>}"
root="$(cd "$(dirname "$0")/.." && pwd)"
state="$HOME/.local/state/desk"

mkdir -p "$state"

# Vurgu rengi → matugen.json (ara dosya)
# --prefer saturation: resimde birden fazla aday renk varsa en canlısını seç (soru sormadan)
matugen image "$image" \
    --config "$root/matugen/config.toml" \
    --mode dark \
    --type scheme-tonal-spot \
    --prefer saturation \
    --quiet

# Barın görünümü eklenip colors.json'a tek seferde yazılır
python3 "$root/scripts/bar_tone.py" "$image" \
    --merge "$state/matugen.json" \
    --out "$state/colors.json"

echo "Colors written: $state/colors.json"

# Aynı renkler kitty'ye ve Dolphin'e (Kvantum); bir sorun olsa da kabuğun renkleri yazıldı
python3 "$root/scripts/apps_theme.py" || echo "apps_theme.py failed" >&2
