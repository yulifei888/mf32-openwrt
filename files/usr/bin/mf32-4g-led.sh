#!/bin/sh
# ============================================================
# mf32-4g-led.sh — 4G 状态 LED 指示（常亮，不依赖内核 timer）
#   红灯常亮：断网
#   绿灯常亮：注册中
#   蓝灯常亮：正常联网
# 自动探测 red/green/blue 三颗 LED；可用环境变量覆盖：
#   LED_4G_RED / LED_4G_GREEN / LED_4G_BLUE  —— /sys/class/leds 下节点名(不含路径)
# 本机实测 timer 触发器不稳定，故改用常亮指示，保证可见。
# ============================================================

LED_DIR=/sys/class/leds
STFILE=/tmp/.4g_state
LOG="logger -t 4gled"

[ -f /tmp/.led_off ] && exit 0

pick_led() {
  color="$1"
  for n in $(ls "$LED_DIR" 2>/dev/null); do
    lc=$(echo "$n" | tr 'A-Z' 'a-z')
    case "$lc" in *4g*|*net*|*wwan*|*signal*)
      case "$lc" in *"$color"*) echo "$n"; return;; esac
    esac
  done
  for n in $(ls "$LED_DIR" 2>/dev/null); do
    lc=$(echo "$n" | tr 'A-Z' 'a-z')
    case "$lc" in *power*|*bat*) continue;; esac
    case "$lc" in *"$color"*) echo "$n"; return;; esac
  done
  echo ""
}

RED=${LED_4G_RED:-$(pick_led red)}
GREEN=${LED_4G_GREEN:-$(pick_led green)}
BLUE=${LED_4G_BLUE:-$(pick_led blue)}

led_on() {
  bp="$LED_DIR/$1/brightness"
  [ -e "$bp" ] || return
  mb=$(cat "$LED_DIR/$1/max_brightness" 2>/dev/null || echo 255)
  echo none >"$LED_DIR/$1/trigger" 2>/dev/null
  echo "$mb" >"$bp" 2>/dev/null
}
led_off() {
  bp="$LED_DIR/$1/brightness"
  [ -e "$bp" ] || return
  echo none >"$LED_DIR/$1/trigger" 2>/dev/null
  echo 0    >"$bp" 2>/dev/null
}
set_state() {
  # $1=RED亮 $2=GREEN亮 $3=BLUE亮 (1=亮 0=灭)
  [ "$1" = "1" ] && led_on  "$RED"   || led_off "$RED"
  [ "$2" = "1" ] && led_on  "$GREEN" || led_off "$GREEN"
  [ "$3" = "1" ] && led_on  "$BLUE"  || led_off "$BLUE"
}

detect_4g() {
  if command -v mmcli >/dev/null 2>&1 && mmcli -m 0 >/dev/null 2>&1; then
    st=$(mmcli -m 0 2>/dev/null | sed -n 's/.*[[:space:]]state:[[:space:]]*//p' | head -1 | awk '{print $1}')
    case "$st" in
      connected)     echo connected;   return;;
      registered|searching|connecting|registering) echo registering; return;;
      *)             echo disconnected; return;;
    esac
  fi
  if command -v uqmi >/dev/null 2>&1 && ls /dev/cdc-wdm* >/dev/null 2>&1; then
    dev=$(ls /dev/cdc-wdm* | head -1)
    data=$(uqmi -d "$dev" --get-data-status 2>/dev/null)
    [ "$data" = "connected" ] && { echo connected; return; }
    ss=$(uqmi -d "$dev" --get-serving-system 2>/dev/null)
    case "$ss" in
      *registered*|*searching*|*connecting*) echo registering; return;;
    esac
    echo disconnected; return
  fi
  if command -v qmicli >/dev/null 2>&1 && ls /dev/cdc-wdm* >/dev/null 2>&1; then
    dev=$(ls /dev/cdc-wdm* | head -1)
    if qmicli -d "$dev" --wds-get-packet-service-status 2>/dev/null | grep -qi connected; then
      echo connected; return
    fi
    echo registering; return
  fi
  for if in wwan0 usb0 rmnet0; do
    if ip link show "$if" 2>/dev/null | grep -q 'state UP' \
       && ip route show default 2>/dev/null | grep -q "$if"; then
      echo connected; return
    fi
  done
  echo disconnected
}

STATE=$(detect_4g)
LAST=$(cat "$STFILE" 2>/dev/null)
[ "$STATE" = "$LAST" ] && exit 0
echo "$STATE" >"$STFILE"

case "$STATE" in
  connected)
    set_state 0 0 1
    $LOG "4G 正常联网 (蓝)"
    ;;
  registering)
    set_state 0 1 0
    $LOG "4G 注册中 (绿)"
    ;;
  disconnected)
    set_state 1 0 0
    $LOG "4G 断网 (红)"
    ;;
esac
exit 0
