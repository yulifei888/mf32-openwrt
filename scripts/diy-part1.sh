#!/bin/bash
# DIY脚本 - OpenStick MF32 云编译 第1部分（更新 feeds 之前执行）
# 在拉取源码、生成默认配置前运行：负责添加第三方软件源
# 参考：P3TERX/Actions-OpenWrt，yulifei888/immortalwrt-Actios

# 添加第三方 feed 源（small-package 含 openclash / passwall / ssr-plus 等常用插件）
echo 'src-git smpackage https://github.com/kenzok8/small-package' >> feeds.conf.default

# 添加 iStore 应用商店（编译时在 extra_packages 里填 luci-app-store 即可装）
echo 'src-git store https://github.com/linkease/istore.git;main' >> feeds.conf.default

# ========== 引入 openstick-feeds 源（使用你自己 fork 的 yulifei888/openstick-feeds）==========
# 注意：lkiuyu/immortalwrt 自带的 feeds.conf.default 已有一个名为 openstick 的源，
# 直接追加会同名报错（Duplicate feed name），所以先删掉原有 openstick 行，再注册我们的。
sed -i '/openstick/d' feeds.conf.default
# 浅克隆源码，加快速度
git clone --depth 1 https://github.com/yulifei888/openstick-feeds.git feeds/openstick
# 注册到 feeds 配置（本地路径，避免每次走网络）
echo 'src-git openstick file:feeds/openstick' >> feeds.conf.default
# 只更新并安装需要的插件，避免全量安装引入冲突的驱动/包
./scripts/feeds update openstick
./scripts/feeds install luci-app-mmconfig -p openstick

# ========== 给 openstick 的 android-tools(adbd) 打 gcc14 编译补丁 ==========
# 源码（gxpeng/android-tools 2013 年 commit）在 gcc14+musl 下因 prctl/capset
# 隐式声明而编不过。我们把补丁注入克隆下来的 feed 包目录，OpenWrt 会在
# Build/Prepare 阶段自动应用；并给 Makefile 的 CFLAGS 加 -Wno-error 安全网，
# 防止 adbd.mk 里其它 .c 文件也有类似的隐式声明被当成硬错误。
PATCH_SRC="$GITHUB_WORKSPACE/patches/0001-android-tools-gcc14.patch"
if [ -f "$PATCH_SRC" ]; then
  mkdir -p feeds/openstick/utils/android-tools/patches
  cp "$PATCH_SRC" feeds/openstick/utils/android-tools/patches/
  echo "✅ 已注入 android-tools gcc14 补丁"
else
  echo "⚠️ 未找到 $PATCH_SRC，跳过补丁（adbd 可能编译失败）"
fi
if [ -f feeds/openstick/utils/android-tools/Makefile ]; then
  sed -i 's#CFLAGS="$(TARGET_CFLAGS) $(TARGET_CPPFLAGS)"#CFLAGS="$(TARGET_CFLAGS) $(TARGET_CPPFLAGS) -Wno-error=implicit-function-declaration -Wno-implicit-function-declaration"#' \
    feeds/openstick/utils/android-tools/Makefile
  echo "✅ 已给 android-tools Makefile 加 -Wno-error 安全网"
fi
# =========================================================================

