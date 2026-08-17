#!/bin/bash
# DIY脚本 - OpenStick MF32 云编译 第1部分（更新 feeds 之前执行）
# 在拉取源码、生成默认配置前运行：负责添加第三方软件源
# 参考：P3TERX/Actions-OpenWrt，yulifei888/immortalwrt-Actios

# 添加第三方 feed 源（small-package 含 openclash / passwall / ssr-plus 等常用插件）
echo 'src-git smpackage https://github.com/kenzok8/small-package' >> feeds.conf.default

# 添加 iStore 应用商店（编译时在 extra_packages 里填 luci-app-store 即可装）
echo 'src-git store https://github.com/linkease/istore.git;main' >> feeds.conf.default
