#!/usr/bin/env bash
# Pil koruma: şarjı erken durdurur, pil daha uzun ömürlü olur (Ayarlar → Pil ve güç).
#   Lenovo (Legion, IdeaPad): "koruma modu", şarj ~%60'ta durur (conservation_mode)
#   ötekiler (ThinkPad, ASUS, Dell…): şarj %80'de durur (charge_control_end_threshold)
# Yazma izni nixos.nix'teki udev kuralından gelir (users grubu).
#
#   battery_care.sh status   → "<tür> <açık 0/1> <yazılabilir 0/1>"   tür: ideapad, threshold, none
#   battery_care.sh set on|off
export LC_ALL=C

ideapad=""
for f in /sys/bus/platform/drivers/ideapad_acpi/*/conservation_mode; do
    [ -e "$f" ] && ideapad="$f" && break
done
threshold=""
for f in /sys/class/power_supply/BAT*/charge_control_end_threshold; do
    [ -e "$f" ] && threshold="$f" && break
done

writable() {
    [ -w "$1" ] && echo 1 || echo 0
}

case "${1:-}" in
    status)
        if [ -n "$ideapad" ]; then
            echo "ideapad $(cat "$ideapad" 2>/dev/null || echo 0) $(writable "$ideapad")"
        elif [ -n "$threshold" ]; then
            value="$(cat "$threshold" 2>/dev/null || echo 100)"
            on=0
            [ "$value" -lt 100 ] 2>/dev/null && on=1
            echo "threshold $on $(writable "$threshold")"
        else
            echo "none 0 0"
        fi
        ;;
    set)
        case "${2:-}" in
            on) on=1 ;;
            off) on=0 ;;
            *) echo "Usage: $0 set on|off" >&2; exit 2 ;;
        esac
        if [ -n "$ideapad" ]; then
            echo "$on" > "$ideapad" || exit 1
        elif [ -n "$threshold" ]; then
            if [ "$on" = 1 ]; then echo 80 > "$threshold"; else echo 100 > "$threshold"; fi || exit 1
        else
            echo "Bu bilgisayarda pil koruma yok" >&2
            exit 1
        fi
        ;;
    *)
        echo "Usage: $0 status | set on|off" >&2
        exit 2
        ;;
esac
