#!/bin/sh
# MF32 电量灯：读 pm8916-bms-vm/capacity，按 4 段点亮 bat_1~4
LEDS="bat_1 bat_2 bat_3 bat_4"
CAP=""
for d in /sys/class/power_supply/*/; do
  [ -r "${d}capacity" ] && CAP="${d}capacity" && break
done
if [ -z "$CAP" ]; then
  LEVEL=100   # 无电量源时 4 颗全亮作"已通电"指示
else
  LEVEL=$(cat "$CAP" 2>/dev/null | tr -d '\n' | grep -o '[0-9]*')
  [ -z "$LEVEL" ] && LEVEL=100
fi
SEG=$(( (LEVEL + 24) / 25 ))   # 0-4 段
i=1
for led in $LEDS; do
  p="/sys/class/leds/$led"
  [ -d "$p" ] || { i=$((i+1)); continue; }
  MAX=$(cat "$p/max_brightness" 2>/dev/null); [ -z "$MAX" ] && MAX=1
  echo none > "$p/trigger" 2>/dev/null
  if [ "$i" -le "$SEG" ]; then
    echo "$MAX" > "$p/brightness" 2>/dev/null
  else
    echo 0 > "$p/brightness" 2>/dev/null
  fi
  i=$((i+1))
done
