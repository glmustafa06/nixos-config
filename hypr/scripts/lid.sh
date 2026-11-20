#!/usr/bin/env bash
# Kapak davranışı (Ayarlar → Pil ve güç → Kapak kapanınca)
#   close: kilitle; pildeysen birkaç dakika sonra uyut (ya da ayara göre hemen uyut)
#   open : bekleyen uyku zamanlayıcısını iptal et
# Ayarları desk ~/.local/state/desk/lid.env dosyasına yazar (services/PowerSettings.qml):
#   LID_ACTION=lock|suspend   LID_SUSPEND_MINUTES=15 (0: kilitli kalır, uyumaz)
# Dosya yoksa: kilitle, pilde 15 dakika sonra uyu.
# Türkçe yerel ayarı betiği bozmasın (plan: Sorun 19)
export LC_ALL=C

action=lock
minutes=15
env_file="${XDG_STATE_HOME:-$HOME/.local/state}/desk/lid.env"
if [ -r "$env_file" ]; then
    # source değil: yalnızca bu iki değer, doğrulanarak okunur
    while IFS='=' read -r key value; do
        case "$key" in
            LID_ACTION) [ "$value" = suspend ] && action=suspend || action=lock ;;
            LID_SUSPEND_MINUTES) case "$value" in '' | *[!0-9]*) ;; *) minutes="$value" ;; esac ;;
        esac
    done < "$env_file"
fi

stop_timer() {
    systemctl --user stop lid-suspend.timer lid-suspend.service 2>/dev/null
    systemctl --user reset-failed lid-suspend.timer lid-suspend.service 2>/dev/null
}

on_ac() {
    grep -qs 1 /sys/class/power_supply/{AC,ADP,ACAD}*/online
}

case "$1" in
    close)
        stop_timer
        if [ "$action" = suspend ]; then
            # Uykudan önce hypridle kilitler (before_sleep_cmd)
            systemctl suspend
            exit 0
        fi
        loginctl lock-session
        # Prize takılı değilse birkaç dakika sonra uyku
        if ! on_ac && [ "$minutes" -gt 0 ]; then
            systemd-run --user --on-active="${minutes}min" --unit=lid-suspend systemctl suspend
        fi
        ;;
    open)
        stop_timer
        ;;
    *)
        echo "Usage: $0 close|open" >&2
        exit 1
        ;;
esac
