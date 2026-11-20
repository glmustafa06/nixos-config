#!/usr/bin/env bash
# hypridle'ın çağırdığı işler. Pilde ve prizde süreler farklı (Ayarlar → Pil ve güç; desk süreleri
# ~/.local/state/desk/hypridle.conf'a yazar, yoksa ~/.config/hypr/hypridle.conf):
#   dim <battery|ac>     : o güç kaynağındaysan ekranı karart
#   lock <battery|ac>    : o güç kaynağındaysan kilitle ve ekranı kapat
#   suspend <battery|ac> : o güç kaynağındaysan uyut
#   late                 : 15 dk — pildeysen uyut, prizdeysen kilitle ve ekranı kapat (eski dosya)
#   undim, wake          : kullanıcı döndü: parlaklığı geri al, ekranı aç
# Türkçe yerel ayarı betiği bozmasın (plan: Sorun 19)
export LC_ALL=C

state="${XDG_RUNTIME_DIR:-/tmp}/desk-idle"
mkdir -p "$state"

# Parlaklık tuşlarıyla aynı aygıt (keybinds.lua); yoksa brightnessctl kendisi seçer
device=(-d amdgpu_bl1)
brightnessctl "${device[@]}" info >/dev/null 2>&1 || device=()

on_ac() {
    grep -qs 1 /sys/class/power_supply/{AC,ADP,ACAD}*/online
}
source_is() {
    if [ "$1" = ac ]; then on_ac; else ! on_ac; fi
}

screen() {
    hyprctl dispatch "hl.dsp.dpms({ action = \"$1\" })" >/dev/null
}

case "${1:-}" in
    dim)
        source_is "${2:-battery}" || exit 0
        [ -e "$state/dimmed" ] && exit 0
        current="$(brightnessctl "${device[@]}" get)" || exit 0
        target=$(( current * 40 / 100 ))
        [ "$target" -lt 1 ] && target=1
        # -s: önceki parlaklığı sakla (undim geri alır)
        brightnessctl "${device[@]}" -s set "$target" >/dev/null && touch "$state/dimmed"
        ;;
    undim)
        if [ -e "$state/dimmed" ]; then
            brightnessctl "${device[@]}" -r >/dev/null
            rm -f "$state/dimmed"
        fi
        ;;
    lock)
        source_is "${2:-battery}" || exit 0
        loginctl lock-session
        sleep 2
        screen off
        ;;
    suspend)
        source_is "${2:-battery}" || exit 0
        systemctl suspend
        ;;
    late)
        if on_ac; then
            loginctl lock-session
            sleep 2
            screen off
        else
            systemctl suspend
        fi
        ;;
    wake)
        screen on
        "$0" undim
        ;;
    *)
        echo "Usage: $0 dim|lock|suspend <battery|ac> | late | undim | wake" >&2
        exit 1
        ;;
esac
