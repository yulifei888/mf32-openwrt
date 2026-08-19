#!/bin/sh
# MF32 充电呼吸闪烁守护进程：status=Charging 时让当前最高电量颗(bat_SEG)亮灭交替。
# 由 mf32-battery-led.sh 在充电时拉起；非充电或本进程被杀即退出。
# 注意：MF32 上 LED 的 timer 触发不生效，只能用脚本周期翻转 brightness 实现闪烁。
PIDF=/var/run/mf32-charge-blink.pid
echo $$ > "$PIDF"
trap 'rm -f "$PIDF"' EXIT

NODE=""
for d in /sys/class/power_supply/*/; do
  [ -e "${d}voltage_now" ] && NODE="$d" && break
done
VMIN=3000000; VMAX=4200000
if [ -n "$NODE" ]; then
  [ -r "${NODE}voltage_min_design" ] && VMIN=$(cat "${NODE}voltage_min_design" 2>/dev/null | tr -d '\n')
  [ -r "${NODE}voltage_max_design" ] && VMAX=$(cat "${NODE}voltage_max_design" 2>/dev/null | tr -d '\n')
fi
seg_of() {
  V=$(cat "${1}voltage_now" 2>/dev/null | tr -d '\n')
  if [ -z "$V" ] || [ "$V" -eq 0 ] 2>/dev/null || [ -z "$VMIN" ] || [ "$VMIN" -eq 0 ] 2>/dev/null; then
    echo 4; return
  fi
  PCT=$(( (V - VMIN) * 100 / (VMAX - VMIN) )); [ "$PCT" -lt 0 ] && PCT=0; [ "$PCT" -gt 100 ] && PCT=100
  S=$(( (PCT + 24) / 25 )); [ "$S" -lt 1 ] && S=1; [ "$S" -gt 4 ] && S=4
  echo $S
}
while true; do
  st=$(cat "${NODE}status" 2>/dev/null)
  [ "$st" = "Charging" ] || exit 0
  SEG=$(seg_of "$NODE")
  LED="/sys/class/leds/bat_${SEG}"
  [ -d "$LED" ] || { sleep 2; continue; }
  MAX=$(cat "$LED/max_brightness" 2>/dev/null); [ -z "$MAX" ] && MAX=1
  echo none > "$LED/trigger" 2>/dev/null
  echo "$MAX" > "$LED/brightness" 2>/dev/null; sleep 1
  echo 0 > "$LED/brightness" 2>/dev/null; sleep 1
done
