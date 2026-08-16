#!/bin/bash
# DIY脚本 - OpenStick MF32 云编译 第2部分（更新 feeds 之后、生成配置前执行）
# 参考：P3TERX/Actions-OpenWrt，yulifei888/immortalwrt-Actios

# 修改默认主题为 argon（路径不存在时跳过，不中断编译）
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile 2>/dev/null || true
