#!/bin/sh
# MF32 4G 状态灯守护进程：轮询 ModemManager(mmcli) 状态，用 RGB 三通道指示：
#   断网/无服务  -> 红灯(red:power) 闪烁
#   注册中/搜网  -> 绿灯(green:wlan) 闪烁
#   正常联网     -> 蓝灯(blue:wan) 闪烁
# 注：MF32 的 LED timer 触发不生效，闪烁由脚本周期翻转 brightness 实现。
# 红/绿/蓝三通道物理上就是同一颗 4G RGB 灯的三个脚（GPIO28/30/29）。
RED=/sys/class/leds/red:power
GRN=/sys/class/leds/green:wlan
BLU=/sys/class/leds/blue:wan

led_on() {  # $1: red|grn|blu  -> 只亮该通道，其余灭
  for n in red grn blu; do
    case $n in red) L=$RED;; grn) L=$GRN;; blu) L=$BLU;; esac
    [ -d "$L" ] || continue
    MAX=$(cat "$L/max_brightness" 2>/dev/null); [ -z "$MAX" ] && MAX=1
    echo none > "$L/trigger" 2>/dev/null
    if [ "$n" = "$1" ]; then echo "$MAX" > "$L/brightness" 2>/dev/null
    else echo 0 > "$L/brightness" 2>/dev/null; fi
  done
}
led_off_all() {
  for L in "$RED" "$GRN" "$BLU"; do
    [ -d "$L" ] && { echo none > "$L/trigger" 2>/dev/null; echo 0 > "$L/brightness" 2>/dev/null; }
  done
}

modem_state() {
  # 先快速判断数据接口是否已 up（联网成功）
  up=$(ifstatus modem 2>/dev/null | jsonfilter -e '@.up' 2>/dev/null)
  [ "$up" = "true" ] && { echo connected; return; }
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
  s=$(modem_state)
  case "$s" in
    connected)   C=blu;;
    registering) C=grn;;
    *)           C=red;;
  esac
  led_on "$C";  sleep 0.6
  led_off_all;  sleep 0.6
done
