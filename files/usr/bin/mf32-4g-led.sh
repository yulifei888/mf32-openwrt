#!/bin/sh
# ============================================================
# mf32-4g-led.sh — 4G 状态三色 LED 指示
#   红灯闪烁：断网
#   绿灯闪烁：注册中
#   蓝灯闪烁：正常联网
#
# 自动探测 red/green/blue 三颗 4G 状态 LED；可用环境变量覆盖：
#   LED_4G_RED / LED_4G_GREEN / LED_4G_BLUE  —— /sys/class/leds 下的节点名(不含路径)
#
# 4G 状态检测（按可用性自动选择，无需强制额外依赖）：
#   1) mmcli -m 0          (ModemManager，最准)
#   2) uqmi  / qmicli      (QMI/MBIM，固件若已带对应包)
#   3) 4G 接口 up 且有默认路由 (零依赖近似，此时无“注册中”绿态)
#
# 设计要点：
#   - 尊重电源键“关灯”标志 /tmp/.led_off（关灯时交给电源键心跳逻辑）
#   - 仅在状态变化时改写 LED，避免 timer 触发器被反复重置导致抖动
#   - 闪烁用内核 timer 触发器实现，无需死循环
# ============================================================

LED_DIR=/sys/class/leds
STFILE=/tmp/.4g_state
LOG="logger -t 4gled"

# 关灯模式：把 4G LED 交给电源键的心跳逻辑，本脚本不抢
[ -f /tmp/.led_off ] && exit 0

# ---------------- 自动选灯 ----------------
# $1 = 颜色关键字(lower)，回显最佳匹配节点名(不含路径)
pick_led() {
  color="$1"
  # 第一优先：节点名同时含 4g/net/wwan/signal 与该颜色
  for n in $(ls "$LED_DIR" 2>/dev/null); do
    lc=$(echo "$n" | tr 'A-Z' 'a-z')
    case "$lc" in *4g*|*net*|*wwan*|*signal*)
      case "$lc" in *"$color"*) echo "$n"; return;; esac
    esac
  done
  # 回退：任意含该颜色、且排除 power/bat 的节点
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

led_off() {
  [ -e "$LED_DIR/$1/brightness" ] || return
  echo none >"$LED_DIR/$1/trigger" 2>/dev/null
  echo 0    >"$LED_DIR/$1/brightness" 2>/dev/null
}
led_blink() {
  # $1=节点 $2=delay_on(ms) $3=delay_off(ms)
  [ -e "$LED_DIR/$1/trigger" ] || return
  echo timer     >"$LED_DIR/$1/trigger" 2>/dev/null
  echo "$2"      >"$LED_DIR/$1/delay_on" 2>/dev/null
  echo "$3"      >"$LED_DIR/$1/delay_off" 2>/dev/null
}

# ---------------- 4G 状态检测 ----------------
detect_4g() {
  # 返回 connected | registering | disconnected
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

  # 零依赖近似：4G 接口 up 且承担默认路由
  for if in wwan0 usb0 rmnet0; do
    if ip link show "$if" 2>/dev/null | grep -q 'state UP' \
       && ip route show default 2>/dev/null | grep -q "$if"; then
      echo connected; return
    fi
  done
  echo disconnected
}

# ---------------- 主逻辑 ----------------
STATE=$(detect_4g)
LAST=$(cat "$STFILE" 2>/dev/null)
[ "$STATE" = "$LAST" ] && exit 0     # 状态未变，避免抖动
echo "$STATE" >"$STFILE"

case "$STATE" in
  connected)
    [ -n "$BLUE"  ] && led_blink "$BLUE" 300 300
    [ -n "$GREEN" ] && led_off "$GREEN"
    [ -n "$RED"   ] && led_off "$RED"
    $LOG "4G 正常联网 (蓝)"
    ;;
  registering)
    [ -n "$GREEN" ] && led_blink "$GREEN" 300 300
    [ -n "$BLUE"  ] && led_off "$BLUE"
    [ -n "$RED"   ] && led_off "$RED"
    $LOG "4G 注册中 (绿)"
    ;;
  disconnected)
    [ -n "$RED"   ] && led_blink "$RED" 300 300
    [ -n "$GREEN" ] && led_off "$GREEN"
    [ -n "$BLUE"  ] && led_off "$BLUE"
    $LOG "4G 断网 (红)"
    ;;
esac
exit 0
