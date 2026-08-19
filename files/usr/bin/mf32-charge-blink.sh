#!/bin/sh
# MF32 充电叠加亮灯守护：Charging 时 bat_1~bat_4 叠加式点亮(1→1+2→...→全亮→循环)。
# 由 mf32-battery-led.sh 在充电时拉起；非充电或进程被杀即退出。
# 借鉴点：与 battery-led 统一电源节点选择（优先 voltage_ocv），写灯前去抖（先读后写）。
CFG=/etc/config/mf32led
uci_get() { uci -q get "$CFG.$1" 2>/dev/null; }
[ "$(uci_get mf32led.led)" = "0" ] && exit 0
[ "$(uci_get mf32led.battery)" = "0" ] && exit 0

PIDF=/var/run/mf32-charge-blink.pid
echo $$ > "$PIDF"
trap 'for n in 1 2 3 4; do p="/sys/class/leds/bat_$n"; [ -d "$p" ] && { echo none > "$p/trigger" 2>/dev/null; echo 0 > "$p/brightness" 2>/dev/null; }; done; rm -f "$PIDF"' EXIT

# 电源节点选择：与 battery-led 一致（优先 voltage_ocv，回退 voltage_now）
NODE=""
for d in /sys/class/power_supply/*/; do
  if [ -e "${d}voltage_ocv" ]; then NODE="$d"; break; fi
  [ -e "${d}voltage_now" ] && [ -z "$NODE" ] && NODE="$d"
done

max_of() { m=$(cat "/sys/class/leds/$1/max_brightness" 2>/dev/null); [ -z "$m" ] && m=1; echo "$m"; }
set_led() {  # $1=index $2=0|max  （先读后写，去抖）
  p="/sys/class/leds/bat_$1"; [ -d "$p" ] || return
  echo none > "$p/trigger" 2>/dev/null
  cur=$(cat "$p/brightness" 2>/dev/null)
  [ "$cur" = "$2" ] && return
  echo "$2" > "$p/brightness" 2>/dev/null
}

while true; do
  st=$(cat "${NODE}status" 2>/dev/null)
  [ "$st" = "Charging" ] || exit 0
  for i in 1 2 3 4; do
    st=$(cat "${NODE}status" 2>/dev/null)
    [ "$st" = "Charging" ] || exit 0
    for j in 1 2 3 4; do
      if [ "$j" -le "$i" ]; then want=$(max_of "bat_$j"); else want=0; fi
      set_led "$j" "$want"
    done
    sleep 1
  done
done
