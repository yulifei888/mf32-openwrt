# MF32 随身WiFi 云编译 (OpenStick / 高通410 MSM8916)

基于 GitHub Actions 的 **MF32 随身WiFi（高通410 / MSM8916）OpenWrt 固件在线云编译**方案。
无需本地 Linux 环境，浏览器里点几下就能编译出可刷机的固件包。

- 基础源码：**`yulifei888/immortalwrt`**（`lkiuyu/immortalwrt` 的 fork，`master` 分支，自带 `msm89xx` 目标）。workflow 实际克隆此 fork 并锁定 `upstream_lock.txt` 的 commit。
- 软件源（由 `scripts/diy-part1.sh` 注入）：`kenzok8/small-package`（含 openclash/passwall/ssr-plus 等）+ `linkease/istore`（iStore 应用商店）。**本仓库 build 不会自动加 `yulifei888/openstick-feeds`**，如需可在 `diy-part1.sh` 自行追加。
- 产出：`OpenWrt_MF32_刷机包.zip` = `boot.img` + `system.img` + 刷机脚本
- 版本线：编译自 `master`，`VERSION_NUMBER=SNAPSHOT`、内核 **6.12**；故固件内 `opkg` 源指向 `snapshots`（见 `files/etc/opkg/distfeeds.conf`）。

> ⚠️ **刷机前必读**：务必先全量备份原厂固件，尤其是含基带校准的分区
> `fsc / fsg / modemst1 / modemst2 / 其他 nv 分区`。这些分区丢失**无法恢复**，会变砖！
> 本方案会重写分区表，刷入后不再兼容原厂安卓系统。

---

## 项目结构

```
.
├── .github/workflows/
│   └── mf32-cloud-build.yml      # 核心：MF32 云编译工作流
├── config/
│   └── mf32.config               # MF32 完整编译配置（8202 行，含全部插件/驱动）
├── scripts/
│   ├── diy-part1.sh              # 编译前：添加 small-package / istore 软件源
│   └── diy-part2.sh              # 编译后：设置默认主题（openwrt-2020；argon 已移除）
├── files/                        # 编译时覆盖进固件的系统文件（rc.local、opkg、cardswitch、首页）
├── upstream_lock.txt            # 锁定的上游 commit hash（防上游改动导致编译失败）
└── README.md
```

> 说明：`config/mf32.config` 是从已验证可编译的 `yulifei888/immortalwrt-Actios` 仓库原样取来的 MF32 配置，
> 直接可用。想加 / 减插件优先用下面「自定义」里的 **额外包名** 方式，少改这个大文件。

---

## 使用方法（4 步）

### 1. Fork 到你的 GitHub
把本目录内容推到你自己的一个仓库（或从原仓库 Fork 后，用本目录覆盖）。

### 2. 启用 Actions
进入仓库 → **Settings → Actions → General → 允许 workflow 读写**（默认即允许）；
然后 **Actions** 标签页里启用 workflows。

### 3. 运行编译
仓库 → **Actions → 🚀 MF32 云编译 (OpenStick) → Run workflow**，填写三个输入：

| 输入项 | 说明 | 建议 |
|--------|------|------|
| `ssh` | 是否开启 SSH 调试（6 小时） | 一般留 `false` |
| `custom_hash` | 指定 `yulifei888/immortalwrt`（workflow 克隆的仓库）的 commit hash | **留空**，用 `upstream_lock.txt` 锁定值最稳 |
| `extra_packages` | 额外要装的包名，逗号/空格分隔 | 见下方示例 |

**`extra_packages` 写法示例：**
```
luci-app-openclash,luci-app-adbyby-plus,luci-app-ttyd
```
支持两个特殊前缀（改默认网络）：
```
__ip__192.168.10.1 __hostname__MyMF32 luci-app-openclash
```

常用可加包名：`luci-app-openclash`、`luci-app-passwall`、`luci-app-ssr-plus`、`luci-app-store`(iStore)、
`luci-app-adbyby-plus`、`luci-app-ttyd`、`luci-app-turboacc`（会自动执行安装脚本）。

> ⚠️ **iStore 默认未编译进固件**：基础 `config/mf32.config` 不含 `luci-app-store`，
> 必须在 `extra_packages` 里显式填入 `luci-app-store`（且 `diy-part1.sh` 已加 `linkease/istore` 源）才会生效。

### 4. 下载固件
编译约 **1.5–2 小时**。完成后：
- **GitHub Releases**（推荐）：进入仓库 Releases 下载 `OpenWrt_MF32_..._刷机包.zip`
- 或 **Actions → 本次运行 → Artifacts** 下载

---

## 刷机

解压 `刷机包.zip`，里面是 `boot.img` + `system.img` + 刷机脚本（若已放 `刷机脚本/` 目录）。

> 想让刷机包带「一键刷机脚本」，把 `yulifei888/immortalwrt-Actios` 仓库里的
> **`刷机脚本/`** 目录（含 adb / fastboot / EDL 工具与 `.bat`）原样复制到本仓库根目录再编译即可，
> 工作流会自动把它打进 zip。该目录含 Windows 二进制工具，不强制需要也能编译出镜像。

首次刷入（原厂安卓 → OpenWrt）请务必先看原仓库 README 与刷机教程图，按步骤并先备份分区。

---

## 已内置插件与功能

以下为本次配置固化进固件的内容：软件包来自 `config/mf32.config`，功能脚本来自 `files/` 覆盖层（均为 shell / UCI，零编译依赖即可生效）。

### LuCI 应用（显式选中）
- `luci-app-mmconfig`：4G 模组频段 / 模式配置界面（ACL 已收紧为「登录后可读写」，原实现为未认证即可改）
- `luci-app-ttyd`：网页终端
- `luci-app-cpu-perf` / `luci-app-cpu-status`：CPU 性能模式与状态
- `luci-app-temp-status`：温度状态
- `luci-app-firewall`：防火墙
- `luci-app-package-manager`：软件包管理（opkg GUI）
- `luci-app-gc`：存储空间清理
- `luci-app-bmx6`：BMX6 mesh 路由

### 4G / Modem 相关包与驱动
- `modemmanager` + `libmbim` + `libqmi`：ModemManager 及 MBIM / QMI 调制解调支持
- `luci-proto-modemmanager`：LuCI 中 ModemManager 上网协议
- `comgt` + `comgt-ncm`：Option / NCM 拨号工具
- `iwinfo`：无线信息（WiFi LED 检测使用）

### 主题
- `luci-theme-openwrt-2020`（默认主题）。**已移除 `luci-theme-argon` 及其配置 App**，避免界面依赖问题。

### 自定义功能（files/ 覆盖层）
- **4G 联网看门狗**：`/etc/init.d/4gmonitor` + `/etc/config/4gmonitor`，每分钟检测，registered 假死 >3 次自动重启 wwan 接口。
- **网络初始化**：`files/etc/uci-defaults/99-mf32-network`，首启用固化 `network.wwan`（proto=modemmanager，APN 留空自动）+ 加入 wan 防火墙区（NAT 出网）。
- **LED 状态显示**：`mf32-battery-led.sh` / `mf32-charge-blink.sh` / `mf32-modem-led.sh`（`init.d/mf32-modem-led` 由 procd 守护，断线自动拉起），由 `/etc/config/mf32led` UCI 统一开关；覆盖 bat_1~4 电量灯与 red:power / green:wlan / blue:wan / blue:wlan 状态灯，含直读 capacity、写灯去抖、sleeping 省电模式。
- **WiFi LED**：`hotplug.d/ieee80211/99-wifi-led`，UCI 开关 + 去抖 + sleeping 不亮。
- **电源键多击**：`rc.button/power`——单击切灯 / 双击关机 / 长按 ≥6s 重启网络。
- **切卡**：`files/etc/cardswitch/cardswitch.sh`（已重写为 case 结构，修 bashism）。
- **opkg 源修正**：`files/etc/opkg/distfeeds.conf` core 源指向 `targets/msm89xx/msm8916/packages`，全线快照源，避免刷机后装 kmod 失败。

> 说明：以上功能均为 shell / UCI 覆盖层，不引入需编译的 C 包；如需增删插件优先用工作流 `extra_packages`。

---

## 自定义

- **加 / 减插件**：优先用工作流的 `extra_packages` 输入，不用动大配置文件。
- **改默认 IP / 主机名**：在 `extra_packages` 里加 `__ip__x.x.x.x` / `__hostname__名称`。
- **改源码 / 分支**：编辑 `mf32-cloud-build.yml` 顶部的 `env.REPO_URL` / `REPO_BRANCH`。
- **换 / 加软件源**：编辑 `scripts/diy-part1.sh`，修改 `kenzok8/small-package` 或 `linkease/istore` 的地址；如需 `yulifei888/openstick-feeds` 可自行追加一行 `src-git`。
- **锁定到某个稳定源码版本**：把目标 commit 的 hash 写进 `upstream_lock.txt`，
  工作流会优先用它（除非 `custom_hash` 覆盖）。
- **换其他 MSM8916 机型**（ufi003 / uz801 / w001 / mf601 …）：把对应 `.config` 从
  `yulifei888/immortalwrt-Actios` 的 `config/` 取来，并把工作流里 `CONFIG_FILE` 改成对应文件名。

---

## 致谢 / 来源

- [yulifei888/immortalwrt-Actios](https://github.com/yulifei888/immortalwrt-Actios) — MF32 云编译方案原型（配置、刷机脚本、锁定 hash 取自此处）
- [yulifei888/openstick-feeds](https://github.com/yulifei888/openstick-feeds) — OpenStick 专用软件源（本项目 build 未直接启用，可选加入 `diy-part1.sh`）
- [lkiuyu/immortalwrt](https://github.com/lkiuyu/immortalwrt) — 带 `msm89xx` 目标的 ImmortalWrt 分支（编译基础源码）
- [kenzok8/small-package](https://github.com/kenzok8/small-package) / [linkease/istore](https://github.com/linkease/istore) — 第三方插件源
- [xuxin1955/Actions-immortalwrt](https://github.com/xuxin1955/Actions-immortalwrt) — 编译技术参考 / 依赖与 mkbootimg
- [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt) — 云编译框架

## License

MIT © P3TERX / 各上游作者
