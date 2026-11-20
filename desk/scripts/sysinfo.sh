#!/usr/bin/env bash
# Ayarlar → Hakkında: bilgisayarın özeti, "ad=değer" satırları
export LC_ALL=C

read_file() {
    [ -r "$1" ] && tr -d '\n' < "$1"
}

vendor="$(read_file /sys/class/dmi/id/sys_vendor)"
# Lenovo modelin satış adını product_version'da tutar (product_name "82B5" gibi bir kod)
if [ "$vendor" = LENOVO ]; then
    model="$(read_file /sys/class/dmi/id/product_version)"
else
    model="$(read_file /sys/class/dmi/id/product_name)"
fi
echo "vendor=$vendor"
echo "model=$model"
echo "host=$(read_file /proc/sys/kernel/hostname)"
echo "cpu=$(grep -m1 '^model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//')"
echo "threads=$(nproc 2>/dev/null)"
echo "cores=$(grep -m1 '^cpu cores' /proc/cpuinfo | cut -d: -f2 | tr -d ' ')"
echo "memory=$(awk '/^MemTotal:/ { print $2 * 1024 }' /proc/meminfo)"
df -B1 --output=size,used / 2>/dev/null | awk 'NR == 2 { print "disk=" $1; print "diskUsed=" $2 }'
if [ -r /etc/os-release ]; then
    . /etc/os-release
    echo "os=${PRETTY_NAME:-$NAME}"
fi
echo "kernel=$(uname -r)"
echo "hyprland=$(hyprctl version 2>/dev/null | head -n1 | sed -E 's/^Hyprland ([^ ]+).*/\1/')"
echo "quickshell=$(qs --version 2>/dev/null | head -n1 | sed -E 's/^[Qq]uickshell ([^ ,]+).*/\1/')"
echo "uptime=$(cut -d. -f1 /proc/uptime)"
# Ekran kartları (lspci yoksa sürücü adları)
gpus=""
for card in /sys/class/drm/card[0-9]; do
    [ -e "$card/device/driver" ] || continue
    driver="$(basename "$(readlink "$card/device/driver")")"
    case " $gpus " in *" $driver "*) ;; *) gpus="$gpus $driver" ;; esac
done
echo "gpus=${gpus# }"
