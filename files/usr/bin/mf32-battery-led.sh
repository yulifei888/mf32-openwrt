#!/bin/sh
# MF32 电量灯：电量分段点亮 bat_1~bat_4。
# 修正：随身WiFi常供电、BMS status 恒为 Charging，原版会交权给 charge-blink 导致电量等级从不显示。
# 本版：不论是否 Charging，都用 voltage_now + dts OCV 容量表算等级并点亮；voltage_now 不可用时回退 status 驱动。
# 尊重 /etc/config/mf32led：led 总开关、battery 电量灯开关、sleep 睡眠模式。
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

# 关掉可能还在跑的 charge-blink，避免和等级显示抢灯
BLINK_PIDF=/var/run/mf32-charge-blink.pid
if [ -f "$BLINK_PIDF" ]; then
  OPID=$(cat "$BLINK_PIDF" 2>/dev/null | tr -d '\n')
  [ -n "$OPID" ] && kill "$OPID" 2>/dev/null
  rm -f "$BLINK_PIDF"
fi

# 选电源节点（本机 bms-vm 有 voltage_now；voltage_ocv 会 read error，故优先 voltage_now）
NODE=""
for d in /sys/class/power_supply/*/; do
  [ -e "${d}voltage_now" ] && NODE="$d" && break
done

LEVEL=""
if [ -n "$NODE" ]; then
  V=$(cat "${NODE}voltage_now" 2>/dev/null | tr -d '\n')
  if [ -n "$V" ] && [ "$V" -gt 0 ] 2>/dev/null; then
    # dts 的 OCV 容量表（电压uV / 容量%），降序；取 V 落入的最高一档容量
    TBL="4327000 100 4264000 95 4187000 90 4119000 85 4069000 80 4022000 75 3964000 70 3924000 65 3890000 60 3853000 55 3801000 50 3778000 45 3769000 40 3766000 35 3760000 30 3721000 25 3660000 20 3608000 16 3579000 13 3563000 11 3548000 10 3531000 9 3520000 8 3514000 7 3502000 6 3495000 5 3489000 4 3475000 3 3460000 2 3444000 1 3400000 0"
    set -- $TBL
    LEVEL=0
    while [ $# -ge 2 ]; do
      tv=$1; tc=$2; shift 2
      if [ "$V" -ge "$tv" ] 2>/dev/null; then LEVEL=$tc; break; fi
    done
  fi
fi

# voltage 不可用 → 回退 status 驱动
if [ -z "$LEVEL" ]; then
  ST=$(cat "${NODE}status" 2>/dev/null | tr -d '\n')
  case "$ST" in
    Charging) LEVEL=25 ;;
    Full)     LEVEL=100 ;;
    *)        LEVEL=50 ;;
  esac
fi

[ "$LEVEL" -lt 0 ] 2>/dev/null && LEVEL=0
[ "$LEVEL" -gt 100 ] 2>/dev/null && LEVEL=100

SEG=$(( (LEVEL + 24) / 25 ))   # 1-4 段
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
