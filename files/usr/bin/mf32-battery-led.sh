#!/bin/sh
# MF32 电量灯：电量分段点亮 bat_1~bat_4。
# 借鉴 openstick-ledmonitor-mf32：优先直读 capacity，回退电压线性估算；写灯前先读去抖。
# 尊重 /etc/config/mf32led：led 总开关、battery 电量灯开关、use_capacity 是否直读容量、sleep 睡眠模式。
CFG=/etc/config/mf32led
uci_get() { uci -q get "$CFG.$1" 2>/dev/null; }

# 总开关
[ "$(uci_get mf32led.led)" = "0" ] && exit 0
# 电量灯开关
[ "$(uci_get mf32led.battery)" = "0" ] && exit 0

# sleeping 模式：灭电量灯后退出
if [ -f /var/run/mf32_led_sleep ] || [ "$(uci_get mf32led.sleep)" = "1" ]; then
  for n in 1 2 3 4; do
    p="/sys/class/leds/bat_$n"; [ -d "$p" ] && { echo none > "$p/trigger" 2>/dev/null; echo 0 > "$p/brightness" 2>/dev/null; }
  done
  exit 0
fi

LEDS="bat_1 bat_2 bat_3 bat_4"

set_led() {  # $1=index $2=0|max  （先读后写，去抖）
  p="/sys/class/leds/bat_$1"; [ -d "$p" ] || return
  echo none > "$p/trigger" 2>/dev/null
  cur=$(cat "$p/brightness" 2>/dev/null)
  [ "$cur" = "$2" ] && return
  echo "$2" > "$p/brightness" 2>/dev/null
}

# 电源节点选择（优先 voltage_ocv，回退 voltage_now），与 charge-blink 一致
NODE=""
for d in /sys/class/power_supply/*/; do
  [ -e "${d}voltage_ocv" ] || [ -e "${d}voltage_now" ] && NODE="$d" && break
done
STATUS=""
if [ -n "$NODE" ]; then
  [ -r "${NODE}status" ] && STATUS=$(cat "${NODE}status" 2>/dev/null | tr -d '\n')
fi

# 充电检测：拉起/退出叠加亮灯守护
BLINK_PIDF=/var/run/mf32-charge-blink.pid
if [ "$STATUS" = "Charging" ]; then
  RUNNING=0
  if [ -f "$BLINK_PIDF" ]; then
    OPID=$(cat "$BLINK_PIDF" 2>/dev/null | tr -d '\n')
    [ -n "$OPID" ] && kill -0 "$OPID" 2>/dev/null && RUNNING=1
  fi
  if [ "$RUNNING" -ne 1 ]; then
    rm -f "$BLINK_PIDF"
    ( /usr/bin/mf32-charge-blink.sh >/dev/null 2>&1 & )
  fi
  exit 0   # 充电时由 charge-blink 独占电量灯
else
  if [ -f "$BLINK_PIDF" ]; then
    OPID=$(cat "$BLINK_PIDF" 2>/dev/null | tr -d '\n')
    [ -n "$OPID" ] && kill "$OPID" 2>/dev/null
    rm -f "$BLINK_PIDF"
  fi
fi

# 电量百分比
LEVEL=100
if [ -z "$NODE" ]; then
  LEVEL=100
else
  use_cap="$(uci_get mf32led.use_capacity)"
  cap=""
  if [ "$use_cap" != "0" ]; then
    for d in /sys/class/power_supply/*/; do
      if [ -e "${d}capacity" ]; then cap=$(cat "${d}capacity" 2>/dev/null | tr -d '\n'); break; fi
    done
  fi
  if [ -n "$cap" ] && [ "$cap" -ge 0 ] 2>/dev/null; then
    LEVEL=$cap
  else
    V=""
    if [ -r "${NODE}voltage_ocv" ]; then V=$(cat "${NODE}voltage_ocv" 2>/dev/null | tr -d '\n'); fi
    if [ -z "$V" ] || [ "$V" -eq 0 ] 2>/dev/null; then
      if [ -r "${NODE}voltage_now" ]; then V=$(cat "${NODE}voltage_now" 2>/dev/null | tr -d '\n'); fi
    fi
    VMIN=3000000; VMAX=4200000
   VMIN_SYS=$(cat "${NODE}voltage_min_design" 2>/dev/null | tr -d '\n')
    VMAX_SYS=$(cat "${NODE}voltage_max_design" 2>/dev/null | tr -d '\n')
    [ -n "$VMIN_SYS" ] && [ "$VMIN_SYS" -ne 0 ] 2>/dev/null && VMIN=$VMIN_SYS
    [ -n "$VMAX_SYS" ] && [ "$VMAX_SYS" -ne 0 ] 2>/dev/null && VMAX=$VMAX_SYS
    if [ -z "$V" ] || [ "$V" -eq 0 ] 2>/dev/null || [ -z "$VMIN" ] || [ "$VMIN" -eq 0 ] 2>/dev/null; then
      LEVEL=100
    else
      PCT=$(( (V - VMIN) * 100 / (VMAX - VMIN) ))
      [ "$PCT" -lt 0 ] && PCT=0
      [ "$PCT" -gt 100 ] && PCT=100
      LEVEL=$PCT
    fi
  fi
fi

SEG=$(( (LEVEL + 24) / 25 ))   # 0-4 段
[ "$SEG" -lt 1 ] && SEG=1
[ "$SEG" -gt 4 ] && SEG=4

i=1
for led in $LEDS; do
  p="/sys/class/leds/$led"; [ -d "$p" ] || { i=$((i+1)); continue; }
  MAX=$(cat "$p/max_brightness" 2>/dev/null); [ -z "$MAX" ] && MAX=1
  if [ "$i" -le "$SEG" ]; then set_led "$i" "$MAX"
  else set_led "$i" 0; fi
  i=$((i+1))
done
