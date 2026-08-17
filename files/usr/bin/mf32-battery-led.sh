#!/bin/sh
# ============================================================
# mf32-battery-led.sh — 用 4 颗电量 LED 显示电池电量
# 用法：放到 /usr/bin，用 cron 或启动脚本周期调用（建议每分钟一次）
# 自动探测：电量节点 + 4 颗电量 LED（按名称匹配 bat/battery/led）
# 可通过环境变量 BAT_LEDS 手动指定（空格分隔的 /sys/class/leds 路径，顺序=由低到高）
# 尊重电源键脚本的“关灯模式”标志 /tmp/.led_off
# ============================================================

# 关灯模式下不碰 LED
[ -f /tmp/.led_off ] && exit 0

# ---------- 1) 探测电量来源 ----------
CAP=""
for p in /sys/class/power_supply/battery/capacity \
         /sys/class/power_supply/BAT/capacity \
         /sys/class/power_supply/*/capacity; do
  [ -r "$p" ] && { CAP="$p"; break; }
done
[ -z "$CAP" ] && exit 0
LEVEL=$(cat "$CAP" 2>/dev/null | tr -d '\n' | grep -o '[0-9]*')
[ -z "$LEVEL" ] && exit 0

# ---------- 2) 探测充电状态 ----------
STATUS=""
for s in /sys/class/power_supply/*/status; do
  [ -r "$s" ] && STATUS=$(cat "$s" 2>/dev/null | tr -d '\n') && [ -n "$STATUS" ] && break
done

# ---------- 3) 探测 4 颗电量 LED ----------
if [ -z "$BAT_LEDS" ]; then
  BAT_LEDS=$(ls -d /sys/class/leds/* 2>/dev/null | grep -iE 'bat|battery|led' | sort | head -4)
fi
[ -z "$BAT_LEDS" ] && exit 0

# ---------- 4) 电量 -> 点亮颗数 ----------
if [ "$LEVEL" -le 0 ]; then LIT=0
elif [ "$LEVEL" -lt 25 ]; then LIT=1
elif [ "$LEVEL" -lt 50 ]; then LIT=2
elif [ "$LEVEL" -lt 75 ]; then LIT=3
else LIT=4; fi

# ---------- 5) 写 LED ----------
i=1
for led in $BAT_LEDS; do
  [ -e "$led/brightness" ] || { i=$((i+1)); continue; }
  if [ "$i" -le "$LIT" ]; then
    echo none > "$led/trigger" 2>/dev/null
    echo 255 > "$led/brightness"
  else
    echo 0 > "$led/brightness"
  fi
  i=$((i+1))
done

# ---------- 6) 充电时让最亮那颗 LED 闪烁（timer 触发器，无需循环）----------
if [ "$STATUS" = "Charging" ] && [ "$LIT" -gt 0 ]; then
  TOP=$(echo "$BAT_LEDS" | sed -n "${LIT}p")
  [ -e "$TOP/trigger" ] && echo timer > "$TOP/trigger" 2>/dev/null
fi
exit 0
