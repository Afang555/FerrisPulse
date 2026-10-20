# FerrisPulse · 玄熊猫 P1 适配版

<p align="center">
  <img src="app.png" width="108" height="108" alt="FerrisPulse Logo" />
</p>

本项目基于 **[Ferris-echo/FerrisPulse](https://github.com/Ferris-echo/FerrisPulse)** 二次开发，由 Afang555 维护当前适配分支，重点适配 **玄熊猫 P1 驱动（MetapandaMouse05）**，已在玄派玄熊猫 3395 P1 Pro Max 4K 与 4K 接收器上验证。

保留原项目的跨品牌外设框架、原作者署名与 GPLv3 许可证，在此基础上增加玄熊猫协议支持、按应用切换和界面反馈修复。本项目是社区适配版本，并非玄派官方驱动。

- **当前项目**：[Afang555/FerrisPulse](https://github.com/Afang555/FerrisPulse)
- **适配分支**：[MetapandaMouse05](https://github.com/Afang555/FerrisPulse/tree/MetapandaMouse05)
- **原项目及致谢**：[Ferris-echo/FerrisPulse](https://github.com/Ferris-echo/FerrisPulse)
- **问题反馈**：[Issues](https://github.com/Afang555/FerrisPulse/issues)

## 下载

当前发布：**v2.1.2 · 玄熊猫 P1 / 4K 适配版**。下载 [最新 FerrisPulse.exe](https://github.com/Afang555/FerrisPulse/releases/latest/download/FerrisPulse.exe)，或查看 [全部发布版本](https://github.com/Afang555/FerrisPulse/releases)。单文件免安装，直接运行即可。

## 玄熊猫 P1 适配内容

- 读取电量、连接状态、当前 DPI 档位与实际 X/Y DPI。
- 软件按钮切换已有档位，硬件回读确认后同步按钮、硬件生效提示和托盘，并按设置显示 DPI 浮窗。
- F5AC 4K 接收器支持 `125 Hz`、`250 Hz`、`500 Hz`、`1000 Hz`、`2000 Hz`、`4000 Hz`，界面统一显示完整数字和单位。
- 按应用设置 DPI 与回报率，支持按 **DPI 值匹配** 或按 **档位编号选择**，离开规则后恢复进入前的实际设置。
- 修复硬件已切换而 UI 延迟、第一次点击不更新、软件切档不弹浮窗等问题，增加锁竞争和旧状态覆盖的回归验证。
- 关于页提供当前项目、使用说明、问题反馈和原项目入口，已移除赞赏二维码及内嵌资源。

### 档位与 DPI

**档位编号和 DPI 没有固定对应关系。** 第 1、2、3……档是编号，档内保存的 DPI 可以由用户修改。

| 选择方式 | 行为 |
|---|---|
| 按档位编号 | 选择该编号的已有档位，实际 DPI 跟随此档内容 |
| 按 DPI 值 | 从新读取的实际档位表匹配目标值，支持表顺序变化 |

当前适配只选择已有档位，不直接改写板载 DPI 数值。需要修改每档 DPI 时，请先在官方驱动中设置，再退出官方驱动后使用 FerrisPulse；找不到匹配值时不会猜测替代档位。

游戏 `800 DPI / 4000 Hz`、办公 `1600 DPI / 125 Hz` 是可编辑预设，需要鼠标已有对应 DPI。没有匹配应用时恢复进入规则前的基线，不会无条件套用办公预设。

### 连接与验证范围

| 端点 | VID / PID | 当前开放回报率 |
|---|---|---|
| 4K 无线接收器 | 3554 / F5AC | 125、250、500、1000、2000、4000 Hz |
| 旧 1K 无线端点 | 3554 / F5A9 | 125、1000 Hz |
| 有线端点 | 3554 / F5AB | 125、1000 Hz |

本轮 F5AC 六档已完成官方软件抓包、独立写入及回读；这些验证不等同于专用仪器测量实际报告频率。F5AB 保留此前适配，本轮未做有线实机写入；高 DPI 扩展编码、实体 DPI 按键的即时监听及其他型号需另行验证，不能仅按相同 VID 推广支持。

## 使用与更新

1. 下载本项目 Releases 中的 `FerrisPulse.exe`，或从当前适配分支构建；先退出官方 Mouse Drive Beta，再运行程序，避免同时通信。
2. 主界面选择已有 DPI 档位或已支持的回报率；设置成功以硬件回读为准。
3. 按应用规则入口：托盘右键 → **玄熊猫 · 按应用设置…**，选择实际前台 exe 和当前设备端点。
4. 换电脑或改变有线/无线连接方式后，重新选择设备端点及应用路径。

**自动检查更新默认关闭。** 在没有保存配置时，不执行开机和后台自动检查；用户可在关于页手动开启，也可使用“检查更新”按钮。已有用户显式保存的开关仍被尊重，本次操作已将当前电脑设置为关闭。

当前手动在线更新模块仍使用原项目发布源，尚未接入本适配分支的独立发布；需要玄熊猫适配版时，请使用本仓库 Releases 附件或 `MetapandaMouse05` 分支源码构建。

## 本地构建

项目使用 C# 5 / .NET Framework 4.0 与 Win32 P/Invoke，不需要 NuGet 或第三方运行时 DLL。Windows 上使用系统 .NET Framework 编译器：

```cmd
git clone --branch MetapandaMouse05 --single-branch https://github.com/Afang555/FerrisPulse.git FerrisPulse-Metapanda
cd FerrisPulse-Metapanda
build.bat
```

成功后在项目目录生成 `FerrisPulse.exe`。若已在本机开发，以 `D:\github\mouse` 主目录为准；二进制、临时日志和完整抓包不提交源码仓库。

## 文档与继续适配

- [玄熊猫使用指南与协议参数](docs/metapanda-guide.md)：两种 DPI 选择模式、应用规则、六档回报率与实测限制。
- [已知缺陷与回归要求](docs/metapanda-regressions.md)：根因、修复契约、自动化测试和单次点击验收。
- [新电脑、新鼠标适配手册](docs/mouse-adaptation-handbook.md)：环境恢复、端点定位、单变量抓包、协议分析、接入与交接模板。
- [系统架构](ARCHITECTURE.md)与 [维护入口](AGENTS.md)。

原项目还提供其他品牌的外设能力；本分支保留相关代码，具体支持以对应型号协议及实测为准。新增鼠标请在本项目 Issues 提供完整型号、连接方式、接收器/固件和 VID/PID，必要时补充脱敏协议样本。

## 来源与许可证

感谢 **Ferris-echo** 开源 FerrisPulse，并提供原有硬件协议、界面和外设调度框架。本分支在原项目基础上继续开发，玄熊猫适配修改及文档按项目现有 **[GNU GPL v3.0](LICENSE)** 许可证提供；原作者与贡献者的署名保留。
