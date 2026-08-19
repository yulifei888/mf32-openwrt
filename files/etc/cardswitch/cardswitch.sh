#!/bin/sh
# 切卡脚本：选择 SIM 卡槽并重启 modem 相关服务
# 用法：cardswitch.sh <1|2|3|4>

slot="$1"

if [ -z "$slot" ]; then
  echo "Run with the slot you want to switch to (1-4)"
  exit 1
fi

case "$slot" in
  1)
    echo 1 > /sys/class/leds/sim:sel/brightness
    echo 0 > /sys/class/leds/sim:en/brightness
    echo 0 > /sys/class/leds/sim:sel2/brightness
    echo 0 > /sys/class/leds/sim:en2/brightness
    ;;
  2)
    echo 0 > /sys/class/leds/sim:sel/brightness
    echo 1 > /sys/class/leds/sim:en/brightness
    echo 0 > /sys/class/leds/sim:sel2/brightness
    echo 0 > /sys/class/leds/sim:en2/brightness
    ;;
  3)
    echo 0 > /sys/class/leds/sim:sel/brightness
    echo 0 > /sys/class/leds/sim:en/brightness
    echo 1 > /sys/class/leds/sim:sel2/brightness
    echo 0 > /sys/class/leds/sim:en2/brightness
    ;;
  4)
    echo 0 > /sys/class/leds/sim:sel/brightness
    echo 0 > /sys/class/leds/sim:en/brightness
    echo 0 > /sys/class/leds/sim:sel2/brightness
    echo 1 > /sys/class/leds/sim:en2/brightness
    ;;
  *)
    echo "Invalid slot: $slot (expected 1-4)"
    exit 1
    ;;
esac

rmmod qcom-q6v5-mss
modprobe qcom-q6v5-mss
service rmtfs restart
service modemmanager restart
