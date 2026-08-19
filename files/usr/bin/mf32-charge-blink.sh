#!/bin/sh
# MF32 充电叠加亮灯守护进程：status=Charging 时让 bat_1~bat_4 累加式点亮（1 → 1+2 → 1+2+3 → 全亮 → 循环）。
# 由 mf32-battery-led.sh 在充电时拉起；非充电或本进程被杀即退出。
# 注意：MF32 上 LED 的 timer 触发不生效，只能用脚本周期翻转 brightness 实现。
PIDF=/var/run/mf32-charge-blink.pid
echo $$ > "$PIDF"
trap 'for n in 1 2 3 4; do p="/sys/class/leds/bat_$n"; [ -d "$p" ] && { echo none > "$p/trigger" 2>/dev/null; echo 0 > "$p/brightness" 2>/dev/null; }; done; rm -f "$PIDF"' EXIT

NODE=""
for d in /sys/class/power_supply/*/; do
  [ -e "${d}voltage_now" ] && NODE="$d" && break
done
max_of() {
  m=$(cat "/sys/class/leds/$1/max_brightness" 2>/dev/null); [ -z "$m" ] && m=1; echo "$m"
}
# 跑马灯：每次只亮一颗，从 bat_1 走到 bat_4 循环
while true; do
  st=$(cat "${NODE}status" 2>/dev/null)
  [ "$st" = "Charging" ] || exit 0
  for i in 1 2 3 4; do
    st=$(cat "${NODE}status" 2>/dev/null)
    [ "$st" = "Charging" ] || exit 0
    for j in 1 2 3 4; do
      p="/sys/class/leds/bat_$j"; [ -d "$p" ] || continue
      echo none > "$p/trigger" 2>/dev/null
      if [ "$j" -le "$i" ]; then echo "$(max_of bat_$j)" > "$p/brightness" 2>/dev/null
      else echo 0 > "$p/brightness" 2>/dev/null; fi
    done
    sleep 1
  done
done
