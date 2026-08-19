#!/bin/sh
# MF32 电量灯：PM8916 BMS-VM 驱动只暴露电压、不暴露 capacity，
# 故用 voltage_ocv(优先)/voltage_now 配合 min/max 设计电压线性估算百分比。
LEDS="bat_1 bat_2 bat_3 bat_4"
NODE=""
for d in /sys/class/power_supply/*/; do
  [ -e "${d}voltage_ocv" ] || [ -e "${d}voltage_now" ] && NODE="$d" && break
done
if [ -z "$NODE" ]; then
  LEVEL=100   # 找不到任何电量源：4 颗全亮作"已通电"指示
else
  V=""
  if [ -r "${NODE}voltage_ocv" ]; then V=$(cat "${NODE}voltage_ocv" 2>/dev/null | tr -d '\n'); fi
  if [ -z "$V" ] || [ "$V" -eq 0 ] 2>/dev/null; then
    if [ -r "${NODE}voltage_now" ]; then V=$(cat "${NODE}voltage_now" 2>/dev/null | tr -d '\n'); fi
  fi
  VMIN=3000000; VMAX=4200000   # 默认 3.0V~4.2V（微伏），若 sysfs 有则以 sysfs 为准
  if [ -r "${NODE}voltage_min_design" ]; then VMIN=$(cat "${NODE}voltage_min_design" 2>/dev/null | tr -d '\n'); fi
  if [ -r "${NODE}voltage_max_design" ]; then VMAX=$(cat "${NODE}voltage_max_design" 2>/dev/null | tr -d '\n'); fi
  if [ -z "$V" ] || [ "$V" -eq 0 ] 2>/dev/null || [ -z "$VMIN" ] || [ "$VMIN" -eq 0 ] 2>/dev/null; then
    LEVEL=100
  else
    PCT=$(( (V - VMIN) * 100 / (VMAX - VMIN) ))
    [ "$PCT" -lt 0 ] && PCT=0
    [ "$PCT" -gt 100 ] && PCT=100
    LEVEL=$PCT
  fi
fi
SEG=$(( (LEVEL + 24) / 25 ))   # 0-4 段
[ "$SEG" -lt 1 ] && SEG=1
[ "$SEG" -gt 4 ] && SEG=4
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
