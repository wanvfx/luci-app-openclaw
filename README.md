# luci-app-openclaw

[![Bilibili](https://img.shields.io/badge/B%E7%AB%99-59438380-00a1d6?logo=bilibili)](https://space.bilibili.com/59438380)
[![Blog](https://img.shields.io/badge/Blog-910501.xyz-orange)](https://blog.910501.xyz/)
[![Build & Release](https://github.com/10000ge10000/luci-app-openclaw/actions/workflows/build.yml/badge.svg)](https://github.com/10000ge10000/luci-app-openclaw/actions/workflows/build.yml)
[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](LICENSE)

[OpenClaw](https://github.com/nicepkg/openclaw) AI 网关的 OpenWrt LuCI 管理插件。

在路由器上运行 OpenClaw，通过 LuCI 管理界面完成安装、配置和服务管理。

**系统要求**

| 项目 | 要求 |
|------|------|
| 架构 | x86_64 或 aarch64 (ARM64) |
| C 库 | glibc 或 musl（自动检测） |
| 依赖 | luci-compat, luci-base, curl, openssl-util |
| 存储 | 1.5GB 以上可用空间 |
| 内存 | 推荐 2GB 及以上 |

### 🖥️ 兼容性矩阵

#### 支持的架构 × C 库组合

| 架构 | C 库 | Node.js 来源 | 状态 |
|------|------|-------------|------|
| x86_64 | musl | [unofficial-builds.nodejs.org](https://unofficial-builds.nodejs.org/) | ✅ 已验证 |
| x86_64 | glibc | [nodejs.org](https://nodejs.org/) 官方 | ✅ 支持 |
| aarch64 | musl | 项目自托管（Alpine 打包，含完整依赖） | ✅ 已验证 |
| aarch64 | glibc | [nodejs.org](https://nodejs.org/) 官方 | ✅ 支持 |
| mips / mipsel | - | — | ❌ 不支持 |
| armv7l / armv6l | - | — | ❌ 不支持 |

> **说明**：Node.js 22+ 仅提供 x86_64 和 aarch64 预编译包，不支持 MIPS（如 MT7620/MT7621 路由器）和 32 位 ARM（armv7l/armv6l）。大部分老旧路由器（MT76xx 系列）为 MIPS 架构，无法运行。

#### 支持的 OpenWrt 版本

| OpenWrt 版本 | LuCI 版本 | 验证状态 | 说明 |
|-------------|-----------|---------|------|
| 24.x (iStoreOS 24.10) | LuCI 24.x | ✅ 已验证 | 推荐版本 |
| 23.05 | LuCI openwrt-23.05 | ✅ 支持 | |
| 22.03 (iStoreOS 22.03) | LuCI openwrt-22.03 | ✅ 已验证 | 需自托管 Node.js（ARM64 musl） |
| 21.02 | LuCI openwrt-21.02 | ⚠️ 应兼容 | 未测试，procd / LuCI API 兼容 |
| 19.07 | LuCI openwrt-19.07 | ⚠️ 应兼容 | 未测试 |
| 18.06 及更早 | LuCI 旧版 | ❌ 不保证 | procd API 可能不兼容 |

> 插件使用标准 procd init 和 LuCI CBI (luci-compat) 接口，理论上兼容 OpenWrt 19.07+。

#### 已验证的典型设备

| 设备 / 平台 | 架构 | 系统 | 验证结果 |
|------------|------|------|---------|
| N100 / N5105 软路由 | x86_64 musl | iStoreOS 24.10.5 | ✅ 通过 |
| 晶晨 S905 系列 (Cortex-A53) | aarch64 musl | iStoreOS 22.03.7 | ✅ 通过 |
| Raspberry Pi 4/5 | aarch64 | OpenWrt 23.05+ | ✅ 应支持 |
| FriendlyElec R4S/R5S | aarch64 | OpenWrt / FriendlyWrt | ✅ 应支持 |
| 通用 x86 虚拟机 (PVE/ESXi) | x86_64 | OpenWrt 22.03+ | ✅ 应支持 |
| MT7621 路由器 (如 Redmi AC2100) | mipsel | — | ❌ 不支持 (MIPS) |
| MT7620/MT7628 路由器 | mipsel | — | ❌ 不支持 (MIPS) |

#### ARM64 musl 特别说明

ARM64 + musl 的 OpenWrt 设备（绝大多数 ARM64 路由器）使用**项目自托管的 Node.js 包**：

- 基于 Alpine Linux 3.21 ARM64 环境打包
- 包含完整的共享库（libstdc++、libssl、libicu 等）和 musl 动态链接器
- 包含完整 ICU 国际化数据（`icudt74l.dat`）
- 通过 `patchelf` 将 ELF interpreter 和 rpath 指向打包的 musl 链接器，**不依赖系统库版本**
- 因此即使系统是 OpenWrt 22.03（musl 1.2.3）也能正常运行 Alpine 3.21 编译的 Node.js

## 📦 安装

### 方式一：.run 自解压包（推荐）

无需 SDK，适用于已安装好的系统。

```bash
wget https://github.com/10000ge10000/luci-app-openclaw/releases/latest/download/luci-app-openclaw.run
sh luci-app-openclaw.run
```

### 方式二：.ipk 安装

```bash
wget https://github.com/10000ge10000/luci-app-openclaw/releases/latest/download/luci-app-openclaw.ipk
opkg install luci-app-openclaw.ipk
```

### 方式三：集成到固件编译

适用于自行编译固件或使用在线编译平台的用户。

```bash
cd /path/to/openwrt

# 添加 feeds
echo "src-git openclaw https://github.com/10000ge10000/luci-app-openclaw.git" >> feeds.conf.default

# 更新安装
./scripts/feeds update -a
./scripts/feeds install -a

# 选择插件
make menuconfig
# LuCI → Applications → luci-app-openclaw

# 编译
make package/luci-app-openclaw/compile V=s
```

使用 OpenWrt SDK 单独编译：

```bash
git clone https://github.com/10000ge10000/luci-app-openclaw.git package/luci-app-openclaw
make defconfig
make package/luci-app-openclaw/compile V=s
find bin/ -name "luci-app-openclaw*.ipk"
```

### 方式四：手动安装

```bash
git clone https://github.com/10000ge10000/luci-app-openclaw.git
cd luci-app-openclaw

cp -r root/* /
mkdir -p /usr/lib/lua/luci/controller /usr/lib/lua/luci/model/cbi/openclaw /usr/lib/lua/luci/view/openclaw
cp luasrc/controller/openclaw.lua /usr/lib/lua/luci/controller/
cp luasrc/model/cbi/openclaw/*.lua /usr/lib/lua/luci/model/cbi/openclaw/
cp luasrc/view/openclaw/*.htm /usr/lib/lua/luci/view/openclaw/

chmod +x /etc/init.d/openclaw /usr/bin/openclaw-env /usr/share/openclaw/oc-config.sh
sh /etc/uci-defaults/99-openclaw
rm -f /tmp/luci-indexcache /tmp/luci-modulecache/*
```

## 🔰 首次使用

1. 打开 LuCI → 服务 → OpenClaw，点击「安装运行环境」
2. 安装完成后服务会自动启动，点击「刷新页面」查看状态
3. 进入「Web 控制台」添加 AI 模型和 API Key
4. 进入「配置管理」可使用向导配置消息渠道

## ⬆️ 升级

本项目包含两个独立组件，可分别升级，互不影响。

### 升级 OpenClaw 核心程序

OpenClaw 核心是通过 npm 安装的 Node.js 程序，有两种升级方式：

**方式一：通过 LuCI 界面（推荐）**

LuCI → 服务 → OpenClaw → 点击「🔍 检测升级」按钮 → 如有新版本，点击「⬆️ 立即升级」。

升级完成后服务会**自动重启**。

**方式二：通过 SSH 命令行**

```bash
openclaw-env upgrade
/etc/init.d/openclaw restart
```

### 升级 luci-app-openclaw 插件

插件更新**不影响正在运行的 OpenClaw 服务**——只替换 LuCI 界面文件和配置脚本，Gateway 和 Web PTY 进程无需重启。

**方式一：.run 覆盖安装**

```bash
wget https://github.com/10000ge10000/luci-app-openclaw/releases/latest/download/luci-app-openclaw.run
sh luci-app-openclaw.run
```

**方式二：.ipk 覆盖安装**

```bash
wget https://github.com/10000ge10000/luci-app-openclaw/releases/latest/download/luci-app-openclaw.ipk
opkg install --force-reinstall luci-app-openclaw.ipk
```

**方式三：手动覆盖文件**

```bash
cd /tmp && git clone --depth 1 https://github.com/10000ge10000/luci-app-openclaw.git
cd luci-app-openclaw
cp -r root/* /
cp luasrc/controller/openclaw.lua /usr/lib/lua/luci/controller/
cp luasrc/model/cbi/openclaw/*.lua /usr/lib/lua/luci/model/cbi/openclaw/
cp luasrc/view/openclaw/*.htm /usr/lib/lua/luci/view/openclaw/
rm -f /tmp/luci-indexcache /tmp/luci-modulecache/*
rm -rf /tmp/luci-app-openclaw
```

> **说明**：
> - `/etc/config/openclaw` 是 conffile，不会被覆盖，现有配置完全保留
> - 刷新浏览器即可看到新的 LuCI 界面
> - 如果新版本更新了 `oc-config.sh` 或 `web-pty.js`，在下次进入「配置管理」或重启服务后自动生效

## 📂 目录结构

```
luci-app-openclaw/
├── Makefile                          # OpenWrt 包定义
├── luasrc/
│   ├── controller/openclaw.lua       # LuCI 路由和 API
│   ├── model/cbi/openclaw/basic.lua  # 主页面
│   └── view/openclaw/
│       ├── status.htm                # 状态面板
│       ├── advanced.htm              # 配置管理（终端）
│       └── console.htm               # Web 控制台
├── root/
│   ├── etc/
│   │   ├── config/openclaw           # UCI 配置
│   │   ├── init.d/openclaw           # 服务脚本
│   │   └── uci-defaults/99-openclaw  # 初始化脚本
│   └── usr/
│       ├── bin/openclaw-env          # 环境管理工具
│       └── share/openclaw/           # 配置终端资源
├── scripts/
│   ├── build_ipk.sh                  # 本地 IPK 构建
│   └── build_run.sh                  # .run 安装包构建
└── .github/workflows/build.yml       # GitHub Actions
```

## ❓ 常见问题

**安装后 LuCI 菜单没有出现**

```bash
rm -f /tmp/luci-indexcache /tmp/luci-modulecache/*
```

刷新浏览器即可。

**提示缺少依赖 luci-compat**

```bash
opkg update && opkg install luci-compat
```

**Node.js 下载失败**

网络问题，可指定国内镜像：

```bash
NODE_MIRROR=https://npmmirror.com/mirrors/node openclaw-env setup
```

**是否支持 ARM 路由器**

支持 aarch64（ARM64），包括晶晨 S905 系列、Raspberry Pi 4/5、R4S/R5S 等。ARM64 musl 设备使用项目自托管的 Node.js 包，自带完整依赖库，不依赖系统库版本。**不支持** 32 位 ARM（armv7l/armv6l），Node.js 22 没有 32 位预编译包。

**ARM64 设备安装后 Node.js 显示 Segmentation fault**

旧版 OpenWrt（如 22.03）的系统 musl 版本较低，与新版 Node.js 不兼容。请确保使用最新版本的 `openclaw-env`（v1.0.1+），它会自动下载包含独立 musl 链接器的自托管 Node.js 包。

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 License

[GPL-3.0](LICENSE)
