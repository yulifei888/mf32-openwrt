#!/bin/sh
# MF32 电量灯：PM8916 BMS-VM 驱动只暴露电压、不暴露 capacity，
# 故用 voltage_ocv(优先)/voltage_now 配合 min/max 设计电压线性估算百分比。
# 充电中(status=Charging) 拉起 mf32-charge-blink.sh 让 4 颗电量灯跑马灯。
LEDS="bat_1 bat_2 bat_3 bat_4"
NODE=""
for d in /sys/class/power_supply/*/; do
  [ -e "${d}voltage_ocv" ] || [ -e "${d}voltage_now" ] && NODE="$d" && break
done
STATUS=""
if [ -n "$NODE" ]; then
  [ -r "${NODE}status" ] && STATUS=$(cat "${NODE}status" 2>/dev/null | tr -d '\n')
fi
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

BLINK_PIDF=/var/run/mf32-charge-blink.pid
if [ "$STATUS" = "Charging" ]; then
  # 充电：拉起跑马灯守护进程（独占全部 4 颗电量灯），不点亮常亮段
  RUNNING=0
  if [ -f "$BLINK_PIDF" ]; then
    OPID=$(cat "$BLINK_PIDF" 2>/dev/null | tr -d '\n')
    [ -n "$OPID" ] && kill -0 "$OPID" 2>/dev/null && RUNNING=1
  fi
  if [ "$RUNNING" -ne 1 ]; then
    rm -f "$BLINK_PIDF"
    /usr/bin/mf32-charge-blink.sh >/dev/null 2>&1 &
  fi
else
  # 非充电：确保守护进程退出，全部按 SEG 常亮
  if [ -f "$BLINK_PIDF" ]; then
    OPID=$(cat "$BLINK_PIDF" 2>/dev/null | tr -d '\n')
    [ -n "$OPID" ] && kill "$OPID" 2>/dev/null
    rm -f "$BLINK_PIDF"
  fi
  i=1
  for led in $LEDS; do
    p="/sys/class/leds/$led"; [ -d "$p" ] || { i=$((i+1)); continue; }
    MAX=$(cat "$p/max_brightness" 2>/dev/null); [ -z "$MAX" ] && MAX=1
    echo none > "$p/trigger" 2>/dev/null
    if [ "$i" -le "$SEG" ]; then echo "$MAX" > "$p/brightness" 2>/dev/null
    else echo 0 > "$p/brightness" 2>/dev/null; fi
    i=$((i+1))
  done
fi
