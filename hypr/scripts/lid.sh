#!/usr/bin/env bash
# Kapak davranışı
#   close: ekranı kilitle; pildeysen 15 dakika sonra uyut
#   open : bekleyen uyku zamanlayıcısını iptal et
# Türkçe yerel ayarı betiği bozmasın (plan: Sorun 19)
export LC_ALL=C

stop_timer() {
    systemctl --user stop lid-suspend.timer lid-suspend.service 2>/dev/null
    systemctl --user reset-failed lid-suspend.timer lid-suspend.service 2>/dev/null
}

case "$1" in
    close)
        loginctl lock-session
        stop_timer
        # Prize takılı değilse 15 dakika sonra uyku
        if ! grep -qs 1 /sys/class/power_supply/{AC,ADP,ACAD}*/online; then
            systemd-run --user --on-active=15min --unit=lid-suspend systemctl suspend
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
