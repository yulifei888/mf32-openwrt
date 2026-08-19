#!/bin/bash
# DIY脚本 - OpenStick MF32 云编译 第2部分（更新 feeds 之后、生成配置前执行）
# 参考：P3TERX/Actions-OpenWrt，yulifei888/immortalwrt-Actios

# 默认主题由 luci-theme-glass 包的 uci-defaults（30_luci-theme-glass）在新装时
# 自动设置 mediaurlbase=/luci-static/glass，无需在此 sed 改 luci Makefile。
# 此前残留的 's/luci-theme-bootstrap/luci-theme-argon/g' 已移除（argon 已不编译）。
