# MF32 随身WiFi 云编译 (OpenStick / 高通410 MSM8916)

基于 GitHub Actions 的 **MF32 随身WiFi（高通410 / MSM8916）OpenWrt 固件在线云编译**方案。
无需本地 Linux 环境，浏览器里点几下就能编译出可刷机的固件包。

- 基础源码：**`lkiuyu/immortalwrt`**（`master` 分支，自带 `msm89xx` 目标，专为此类设备维护）
- 软件源：**`yulifei888/openstick-feeds`**（你自己的 fork）+ `kenzok8/small-package` + `linkease/istore`
- 产出：`OpenWrt_MF32_刷机包.zip` = `boot.img` + `system.img` + 刷机脚本

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
│   └── mf32.config               # MF32 完整编译配置（8186 行，含全部插件/驱动）
├── scripts/
│   ├── diy-part1.sh              # 编译前：添加 openstick / small-package / istore 软件源
│   └── diy-part2.sh              # 编译后：修改默认主题等为 argon
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
| `custom_hash` | 指定 `lkiuyu/immortalwrt` 的 commit hash | **留空**，用 `upstream_lock.txt` 锁定值最稳 |
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

## 自定义

- **加 / 减插件**：优先用工作流的 `extra_packages` 输入，不用动大配置文件。
- **改默认 IP / 主机名**：在 `extra_packages` 里加 `__ip__x.x.x.x` / `__hostname__名称`。
- **改源码 / 分支**：编辑 `mf32-cloud-build.yml` 顶部的 `env.REPO_URL` / `REPO_BRANCH`。
- **换 openstick 软件源**：编辑 `scripts/diy-part1.sh` 里 `yulifei888/openstick-feeds` 的地址。
- **锁定到某个稳定源码版本**：把目标 commit 的 hash 写进 `upstream_lock.txt`，
  工作流会优先用它（除非 `custom_hash` 覆盖）。
- **换其他 MSM8916 机型**（ufi003 / uz801 / w001 / mf601 …）：把对应 `.config` 从
  `yulifei888/immortalwrt-Actios` 的 `config/` 取来，并把工作流里 `CONFIG_FILE` 改成对应文件名。

---

## 致谢 / 来源

- [yulifei888/immortalwrt-Actios](https://github.com/yulifei888/immortalwrt-Actios) — MF32 云编译方案原型（配置、刷机脚本、锁定 hash 取自此处）
- [yulifei888/openstick-feeds](https://github.com/yulifei888/openstick-feeds) — OpenStick 专用软件源（本项目使用）
- [lkiuyu/immortalwrt](https://github.com/lkiuyu/immortalwrt) — 带 `msm89xx` 目标的 ImmortalWrt 分支（编译基础源码）
- [kenzok8/small-package](https://github.com/kenzok8/small-package) / [linkease/istore](https://github.com/linkease/istore) — 第三方插件源
- [xuxin1955/Actions-immortalwrt](https://github.com/xuxin1955/Actions-immortalwrt) — 编译技术参考 / 依赖与 mkbootimg
- [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt) — 云编译框架

## License

MIT © P3TERX / 各上游作者
