#!/bin/sh
# MF32 4G 状态灯守护：轮询 ModemManager(mmcli) 状态，RGB 三通道指示：
#   断网/无服务 -> 红灯(red:power) 闪烁
#   注册中/搜网 -> 绿灯(green:wlan) 闪烁
#   正常联网   -> 蓝灯(blue:wan) 闪烁
# 借鉴 openstick-ledmonitor-mf32：sleeping 极慢呼吸、写灯前去抖（先读后写）。
# 注：MF32 LED timer 触发不生效，闪烁由脚本周期翻转 brightness 实现。
CFG=/etc/config/mf32led
uci_get() { uci -q get "$CFG.$1" 2>/dev/null; }
[ "$(uci_get mf32led.led)" = "0" ] && exit 0
[ "$(uci_get mf32led.modem)" = "0" ] && exit 0

RED=/sys/class/leds/red:power
GRN=/sys/class/leds/green:wlan
BLU=/sys/class/leds/blue:wan
max_red=$(cat "$RED/max_brightness" 2>/dev/null); [ -z "$max_red" ] && max_red=1
max_grn=$(cat "$GRN/max_brightness" 2>/dev/null); [ -z "$max_grn" ] && max_grn=1
max_blu=$(cat "$BLU/max_brightness" 2>/dev/null); [ -z "$max_blu" ] && max_blu=1

led_set() {  # $1: red|grn|blu  $2: 0|max  （先读后写，去抖）
  case $1 in red) L=$RED;; grn) L=$GRN;; blu) L=$BLU;; esac
  [ -d "$L" ] || return
  echo none > "$L/trigger" 2>/dev/null
  cur=$(cat "$L/brightness" 2>/dev/null)
  [ "$cur" = "$2" ] && return
  echo "$2" > "$L/brightness" 2>/dev/null
}
led_on() {  # $1: red|grn|blu -> 只亮该通道，其余灭
  led_set red  "$([ "$1" = red  ] && echo "$max_red" || echo 0)"
  led_set grn  "$([ "$1" = grn  ] && echo "$max_grn" || echo 0)"
  led_set blu  "$([ $1 = blu ] && echo "$max_blu" || echo 0)"
}
led_off_all() { led_set red 0; led_set grn 0; led_set blu 0; }

modem_state() {
  # 先快速判断数据接口是否已 up（联网成功），接口名自适应 modem/wwan
  for n in modem wwan; do
    up=$(ifstatus "$n" 2>/dev/null | jsonfilter -e '@.up' 2>/dev/null)
    [ "$up" = "true" ] && { echo connected; return; }
  done
  # 否则看 modem 注册状态（ModemManager）
  st=$(mmcli -m any 2>/dev/null | grep -E "^[[:space:]]*state: " | head -1 | sed "s/.*'\([a-z]*\)'.*/\1/")
  case "$st" in
    connected|connecting) echo connected;;
    registered|registering|searching) echo registering;;
    *) echo down;;
  esac
}

PIDF=/var/run/mf32-modem-led.pid
echo $$ > "$PIDF"
trap 'led_off_all; rm -f "$PIDF"' EXIT

while true; do
  # sleeping 模式：4G 灯极慢呼吸（亮1s/灭5s），shell 等效 timer（MF32 timer 不生效）
  if [ -f /var/run/mf32_led_sleep ] || [ "$(uci_get mf32led.sleep)" = "1" ]; then
    led_set blu "$max_blu"; sleep 1; led_off_all; sleep 5; continue
  fi
  s=$(modem_state)
  case "$s" in
    connected)   C=blu;;
    registering) C=grn;;
    *)           C=red;;
  esac
  led_on "$C";  sleep 0.6
  led_off_all;  sleep 0.6
done
