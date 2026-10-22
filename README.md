# 玄派玄熊猫 P1 系列鼠标驱动优化 · FerrisPulse 二次开发版

<p align="center">
  <img src="app.png" width="108" height="108" alt="FerrisPulse 玄派玄熊猫 P1 鼠标驱动优化工具图标" />
</p>

**面向 Windows 的玄派玄熊猫 P1 系列鼠标驱动优化工具**，提供电量监测、DPI 档位切换、4K 接收器回报率设置、按游戏或应用自动切换，以及本机诊断日志。适合希望在托盘查看鼠标状态、为游戏和办公分别配置鼠标参数的用户。

本项目由 **Afang555** 基于 **[Ferris-echo/FerrisPulse](https://github.com/Ferris-echo/FerrisPulse)** 二次开发，保留原作者署名、跨品牌外设框架与 GPLv3 许可证，重点改进玄熊猫鼠标的协议适配、设置反馈和使用体验。**这是社区适配工具，并非玄派官方驱动。**

当前已在 **玄派玄熊猫 3395 P1 Pro Max 4K + 4K 接收器**上验证。P1 系列是本项目的适配方向，其他 P1 型号、接收器和固件版本仍需逐一验证；不能仅凭系列名称或相同 VID 判断兼容。

- **项目源码**：[Afang555/FerrisPulse](https://github.com/Afang555/FerrisPulse)
- **主分支**：[MetapandaMouse05](https://github.com/Afang555/FerrisPulse/tree/MetapandaMouse05)
- **上游项目**：[Ferris-echo/FerrisPulse](https://github.com/Ferris-echo/FerrisPulse)
- **问题反馈**：[提交鼠标型号与复现信息](https://github.com/Afang555/FerrisPulse/issues)

**快速导航**：[下载](#玄熊猫-p1-驱动优化工具下载) · [功能](#主要功能电量dpi回报率与游戏切换) · [使用方法](#使用方法设置玄熊猫-p1-鼠标参数) · [常见问题](#常见问题) · [适配指南](docs/metapanda-guide.md)

## 玄熊猫 P1 驱动优化工具下载

当前公开发布版本：**[v2.1.4 · 玄熊猫电量与游戏模式稳定性](https://github.com/Afang555/FerrisPulse/releases/tag/v2.1.4)**，发布于 2026-10-22。可下载单文件程序，或选择包含使用说明、更新日志和许可证的便携包。

- [下载 FerrisPulse.exe](https://github.com/Afang555/FerrisPulse/releases/latest/download/FerrisPulse.exe)
- [下载 v2.1.4 便携包 ZIP](https://github.com/Afang555/FerrisPulse/releases/download/v2.1.4/FerrisPulse_v2.1.4_Portable.zip)
- [查看发布说明、校验文件与历史版本](https://github.com/Afang555/FerrisPulse/releases)

v2.1.4 包含休眠电量误报处理、放电期间最低值显示、游戏切回后的设置校正与统一绿色配色，发布构建已通过 25 项相关回归。2026-10-23 用户反馈游戏实机切换 DPI 约需 1 秒，使用正常；该耗时为用户观察值，尚未结合本轮日志计时，微信同时闪烁的具体复现条件未单独确认。详情见 [使用指南](docs/metapanda-guide.md) 和 [缺陷记录](docs/metapanda-regressions.md)。

## 主要功能：电量、DPI、回报率与游戏切换

| 功能 | 适配内容 |
|---|---|
| 鼠标电量监测 | 显示连接状态与电量；非充电时按 P1 已验证电压曲线估算，充电或没有电压时使用设备读数 |
| DPI 档位切换 | 读取当前档位表与实际 X/Y DPI，软件切档后经硬件回读同步按钮、托盘和 DPI 浮窗 |
| 4K 接收器回报率 | F5AC 端点支持 125、250、500、1000、2000、4000 Hz，界面统一使用完整数字和 Hz 单位 |
| 常用回报率按钮 | 默认显示 125 / 1000 / 4000 Hz，可在齿轮设置中自选，支持显示全部六档 |
| 游戏与办公自动切换 | 按应用配置 DPI 和回报率，支持按 DPI 值匹配或指定档位编号，离开规则后恢复进入前的实际设置 |
| 快速状态刷新 | 选定端点在窗口打开或鼠标活动时约每秒回读，托盘空闲约每 5 秒回读；设置后直接发布确认结果 |
| 本机诊断日志 | 保存设置请求、回读结果、异常与连续电量 CSV，便于复查电量变化和切换问题 |

已修复软件切换时硬件 DPI 已改变、界面却延迟更新或需要点击两次，以及软件切档不弹浮窗等问题；相关约束与验证方法记录在 [缺陷与回归要求](docs/metapanda-regressions.md)，供后续更新核对。

### DPI 档位编号与 DPI 数值的区别

**档位编号和 DPI 没有固定对应关系。** 第 1、2、3……档是编号，档内保存的 DPI 可以由用户在官方软件中修改。

| 选择方式 | 切换行为 |
|---|---|
| 按档位编号 | 选择该编号的已有档位，实际 DPI 跟随此档内容 |
| 按 DPI 值 | 从重新读取的实际档位表匹配目标值，档位顺序变化后仍按值寻找 |

当前工具只选择已有档位，**不直接改写板载 DPI 数值**。需要修改每档 DPI 时，先在官方驱动中设置，再退出官方驱动后使用 FerrisPulse；目标 DPI 不存在时不会猜测替代档位。

游戏 `800 DPI / 4000 Hz`、办公 `1600 DPI / 125 Hz` 是可编辑预设，需要鼠标已有对应 DPI。没有匹配应用时恢复进入规则前的基线，不会无条件套用办公预设。回报率快捷按钮也不会改写 DPI 表。

### P1 接收器、有线连接与回报率支持范围

| 端点 | VID / PID | 当前开放回报率 | 验证说明 |
|---|---|---|---|
| 4K 无线接收器 | 3554 / F5AC | 125、250、500、1000、2000、4000 Hz | 本轮已完成官方软件抓包、六档独立写入与回读 |
| 旧 1K 无线端点 | 3554 / F5A9 | 125、1000 Hz | 保留已有适配，不外推为六档支持 |
| 有线端点 | 3554 / F5AB | 125、1000 Hz | 保留此前适配，本轮未做有线实机写入 |

写入与回读验证不等同于专用仪器测量实际报告频率。高 DPI 扩展编码、实体 DPI 按键的即时监听，以及其他型号和固件仍需另行验证。

## 使用方法：设置玄熊猫 P1 鼠标参数

1. 下载本仓库 Releases 中的 `FerrisPulse.exe`，或从当前主分支构建。先从托盘退出官方 Mouse Drive Beta，再运行程序，避免两个程序同时通信。
2. 在主界面选择设备，查看电量、连接状态、当前 DPI 与回报率。选择已有 DPI 档位或支持的回报率，设置结果以硬件回读为准。
3. 通过回报率区域的齿轮选择常用按钮，例如 `125 Hz / 1000 Hz / 4000 Hz`。
4. 需要自动切换时，托盘右键 → **玄熊猫 · 按应用设置…**，选择实际前台程序的 exe 和当前设备端点，再配置 DPI 与回报率。
5. 换电脑或改变有线/无线连接方式后，重新选择设备端点及应用路径。完整参数说明见 [玄派玄熊猫 P1 使用指南](docs/metapanda-guide.md)。

**自动检查更新默认关闭**，已有用户显式保存的开关会被保留。当前手动在线更新模块仍使用上游发布源，尚未接入本适配分支的独立发布；更新玄熊猫适配版请使用 [本仓库 Releases](https://github.com/Afang555/FerrisPulse/releases) 或主分支源码构建。

## 常见问题

### 这是玄派官方鼠标驱动吗？

这是基于 FerrisPulse 的开源社区二次开发版，重点优化玄熊猫 P1 的电量读取、参数切换和界面反馈。修改板载 DPI 数值等尚未接入的功能，仍需使用官方软件。

### 玄熊猫 P1 系列所有型号都能使用吗？

目前已验证玄派玄熊猫 3395 P1 Pro Max 4K 与 F5AC 4K 接收器。其他 P1 设备需要核对完整型号、连接方式、接收器、固件和 VID/PID，再验证协议；相同品牌或系列不代表已适配。

### 为什么电量和官方软件显示不完全相同？

本工具在非充电时根据已验证的电压曲线估算，官方软件可能保留历史平滑结果，短时间内可能有差别。这是估算电量；充电或缺少电压时会使用设备原始读数。v2.1.4 增加休眠读数保护，并在本次运行的同一放电阶段按端点保留有效最低值，减少电量来回波动；充电、新放电阶段或重启程序后重新建立基线。

### 游戏切回来后 DPI 没恢复，如何排查？

检查规则选择的是否为实际游戏进程，而非启动器，并记录切出、切回的时间。v2.1.4 增加前台进程、规则匹配和设置校正日志；2026-10-23 用户反馈游戏实机约 1 秒完成 DPI 切换，使用正常。如再次异常，请保留对应时间段日志；微信同时闪烁的具体条件尚未单独确认。

### 程序日志在哪里？

默认保存在 `%LocalAppData%\FerrisPulse\logs`，可从托盘右键选择 **打开诊断日志文件夹**。

- `diagnostic.log`：启动版本、刷新原因、设置请求与结果、界面发布、异常等诊断信息。
- `battery.csv`：时间、脱敏端点标识、原始电量、电压、充电状态、估算值、显示值、DPI、回报率与耗时等采样。

每类日志单文件上限为 1 MiB，保留当前文件和 4 个轮转文件，默认仅存本机，不自动上传。复验电量变化或游戏切换问题时，请及时复制相关日志，避免后续轮转覆盖。字段和采样限制见 [使用指南](docs/metapanda-guide.md)。

## 从源码构建 Windows 程序

项目使用 C# 5 / .NET Framework 4.0 与 Win32 P/Invoke，不需要 NuGet 或第三方运行时 DLL。在 Windows 上使用系统 .NET Framework 编译器：

```cmd
git clone --branch MetapandaMouse05 --single-branch https://github.com/Afang555/FerrisPulse.git FerrisPulse-Metapanda
cd FerrisPulse-Metapanda
build.bat
```

成功后在项目目录生成 `FerrisPulse.exe`。本机主开发目录为 `D:\github\mouse`；迁移电脑时以实际选定目录为准。编译二进制、临时日志和完整抓包不提交源码仓库，公开程序通过 Releases 发布。

## 使用文档、缺陷记录与其他鼠标适配

- [玄派玄熊猫 P1 使用指南与协议参数](docs/metapanda-guide.md)：DPI 值与档位编号、应用规则、六档回报率、电量与日志说明。
- [已知缺陷与回归要求](docs/metapanda-regressions.md)：问题根因、修复约束、自动化测试和单次点击验收。
- [新电脑、新鼠标适配手册](docs/mouse-adaptation-handbook.md)：环境恢复、端点定位、单变量抓包、协议分析、接入与交接。
- [系统架构](ARCHITECTURE.md)与 [维护入口](AGENTS.md)。

原项目还提供其他品牌的外设能力；本分支保留相关框架，具体支持以对应型号协议和实测为准。希望适配其他鼠标时，请在 [Issues](https://github.com/Afang555/FerrisPulse/issues) 提供完整型号、连接方式、接收器/固件版本与 VID/PID，必要时补充脱敏协议样本。

## English overview

FerrisPulse is an open-source Windows mouse utility. This community fork focuses on **Metapanda P1 series** mouse support and is based on [Ferris-echo/FerrisPulse](https://github.com/Ferris-echo/FerrisPulse). It provides battery monitoring, existing DPI stage selection, polling rate controls for the verified 4K receiver, per-application settings, and local diagnostic logs.

Verified hardware: 玄派玄熊猫 3395 P1 Pro Max 4K with the F5AC receiver. Other models and firmware require separate validation. This is not an official vendor driver. See [Releases](https://github.com/Afang555/FerrisPulse/releases) for downloads and [the usage guide](docs/metapanda-guide.md) for compatibility and limitations.

## 上游项目、二次开发说明与许可证

感谢 **Ferris-echo** 开源 [FerrisPulse](https://github.com/Ferris-echo/FerrisPulse)，并提供原有硬件协议、界面和外设调度框架。本项目由 Afang555 在此基础上继续开发，主要增加玄熊猫 P1 适配、按应用参数切换、交互修复与诊断文档，保留原作者及贡献者署名。

本项目及适配修改按现有 **[GNU GPL v3.0](LICENSE)** 许可证提供。项目名称、源码来源和社区适配身份均在此明确说明。
