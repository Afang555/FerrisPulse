# FerrisPulse · 灵脉 系统架构与 AI 维护全域指南 (ARCHITECTURE.md)

本文档为 **FerrisPulse · 灵脉 (多品牌外设感知与电量管理系统)** 的全景架构地图与开发规范。
所有参与维护、功能扩展或 Bug 修复的工程师与 AI Agent，**必须严格遵循本文档定义的目录拓扑与行为准则**。

---

## 1. 系统目录拓扑与功能认知地图 (Cognitive Map)

```
D:\FerrisPulse · 灵脉\
├── FerrisPulse.exe             [单一原生二进制可执行文件]
├── app.ico                     [程序主图标]
├── build.bat                   [单命令模块化极速构建脚本]
├── AGENT_RULES.md              [AI 行为准则与高分屏规范]
└── src\
    ├── Properties\             [程序集版本信息与 PE 元数据]
    │   └── AssemblyInfo.cs     [Windows PE 元数据、版本号 4.0.0.0、版权与产品信息]
    │
    ├── Core\                   [系统核心中枢]
    │   ├── Program.cs          [应用入口、全局 Mutex 防多开、目录重置、异常兜底]
    │   ├── StartupManager.cs   [高鲁棒性自启动引擎：Run/StartupApproved 双键协同与快捷方式]
    │   ├── ConfigManager.cs    [统一注册表配置持久化管理]
    │   └── NativeMethods.cs    [Win32 P/Invoke API、COM 接口与 TaskbarCreated 消息定义]
    │
    ├── Models\                 [数据模型层（无副作用纯净模型）]
    │   ├── DeviceCategory.cs   [外设品类枚举：鼠标、键盘、耳机、手柄、接收器等]
    │   ├── MouseBatteryInfo.cs [全系统通用归一化外设状态实体]
    │   ├── CustomDeviceConfig.cs [用户手动添加与命名配置]
    │   ├── PriorityItem.cs     [优先级排序数据模型]
    │   ├── RunningProcessItem.cs [运行进程信息模型]
    │   └── RazerDeviceHardwareState.cs [雷蛇硬件内部状态缓存]
    │
    ├── Hardware\               [硬件协议驱动层（各品牌隔离）]
    │   ├── DeviceManager.cs    [外设扫描调度中心、优先级仲裁与多设备状态聚合]
    │   ├── RazerDeviceHelper.cs [雷蛇私有 HID 协议、90 字节报文、DPI 档位与 8K 轮询率]
    │   ├── RapooDeviceHelper.cs [雷柏无线鼠标 HID 通信协议]
    │   ├── VgnDeviceHelper.cs   [VGN / 蜻蜓 / ATK 协议解析]
    │   ├── LogitechDeviceHelper.cs [罗技 HID++ 协议解析]
    │   ├── NuphyDeviceHelper.cs [NuPhy 键盘电量协议与侧灯控制]
    │   ├── ValkyrieDeviceHelper.cs [瓦尔基里全系键盘/鼠标私有 HID 协议、2.4G 接收器多模解析、8K 回报率与 DPI 调节]
    │   ├── BluetoothDeviceHelper.cs [Windows 原生 BLE 电池服务]
    │   ├── GenericHidHelper.cs  [通用 HID 电池报告解析]
    │   ├── UniversalWinLockHelper.cs [Windows 键硬件/驱动级防误触锁定]
    │   ├── AudioDeviceHelper.cs [系统音频与耳机设备状态]
    │   └── XInputHelper.cs      [游戏手柄电量与状态检测]
    │
    ├── Services\               [后台长效服务层]
    │   ├── GameDetector.cs     [独占全屏与焦点游戏检测服务，带系统白名单与防抖]
    │   └── ChimeSynthesizer.cs [44.1kHz 16-bit PCM 柔和纯音双音合成器]
    │
    └── UI\                     [界面渲染与用户交互层]
        ├── Theme\              [设计系统与矢量渲染]
        │   ├── ModernThemeHelper.cs      [抗黑角矢量圆角算法、纯矢量闪电/电池绘制、色彩常量]
        │   └── ModernDarkMenuRenderer.cs [Fluent 暗黑上下文菜单渲染]
        │
        ├── Controls\           [22 个独立自绘制 GDI+ 原子控件]
        │   ├── RoundedCard.cs            [抗锯齿圆角卡片底板]
        │   ├── ModernButton.cs           [带悬浮微光质感现代按钮]
        │   ├── ModernBadge.cs            [状态徽章]
        │   ├── ModernCheckBox.cs         [矢量扁平勾选框]
        │   ├── ModernSegmentButton.cs    [分段选择按钮]
        │   ├── SmoothSegmentedTabBar.cs  [平滑滑动切换标签栏]
        │   ├── SubtleDivider.cs          [细腻冷灰分割线]
        │   ├── ModernProgressBar.cs      [抗锯齿进度条]
        │   ├── StatusPill.cs             [胶囊状态标签]
        │   ├── TactileSmoothSliderControl.cs [平滑阻尼滑块]
        │   ├── RapooStatusTile.cs        [雷柏状态小瓦片]
        │   ├── AnimatedContextMenuStrip.cs
        │   ├── ModernDarkDropdown.cs
        │   ├── ModernInputBox.cs
        │   ├── WizardRadarBadge.cs
        │   ├── ThreeLocksHudControl.cs
        │   ├── ScanningBeamControl.cs
        │   ├── HeadsetStatusTile.cs
        │   ├── FocusDeviceSelector.cs
        │   ├── PriorityReorderControl.cs
        │   ├── DpiStageRowControl.cs
        │   └── DpiActionButton.cs
        │
        └── Forms\              [独立弹窗与主窗体分部切片]
            ├── MainForm.cs               [主窗体生命周期中枢、DPI 初始化]
            ├── MainForm.UI.cs            [界面布局排布、60FPS 风琴折叠动画]
            ├── MainForm.Tray.cs          [托盘 NotifyIcon 与动态多设备右键菜单]
            ├── MainForm.Hardware.cs      [硬件轮询定时器与 UI 状态刷新]
            ├── MainForm.Events.cs        [WndProc 消息泵与 TaskbarCreated 重建机制]
            ├── ModernDeviceSwitcherFlyout.cs [悬浮式现代外设快速切换器]
            ├── DpiOsdForm.cs             [零焦点置顶无感 DPI 悬浮提示窗]
            ├── KeyRolloverSpeedForm.cs   [全键无冲与触发测速仪]
            ├── MouseRateTestDialog.cs    [回报率平滑度离线测试工具]
            ├── GameProcessManagerForm.cs [电竞游戏守护进程管理弹窗]
            ├── DevicePriorityForm.cs     [外设优先级排序调整窗口]
            ├── AddDeviceWizardForm.cs    [手动添加新设备向导]
            ├── PromptDialog.cs           [通用输入提示对话框]
            └── DpiManagementDialog.cs    [DPI 档位高级配置管理窗口]
```

---

## 2. 功能路由直达表 (Feature Routing Table)

当 Agent 或工程师需要修改具体功能时，请直接查阅下表直达对应文件：

| 目标修改功能 | 直达文件路径 | 说明 |
| :--- | :--- | :--- |
| **开机自启动与注册表 Run 键** | `src/Core/StartupManager.cs` | 处理自启动注册、StartupApproved 协同 |
| **托盘图标丢失 / Explorer 重启自愈** | `src/UI/Forms/MainForm.Events.cs` | 监听 `WM_TASKBARCREATED` 并自动恢复 |
| **雷蛇 DPI 档位 / 8K 回报率 / XY 轴独立灵敏度** | `src/Hardware/RazerDeviceHelper.cs` | 雷蛇私有 HID 报文、独立 X/Y 轴与板载 Flash 写入 |
| **瓦尔基里全系键盘/鼠标支持** | `src/Hardware/ValkyrieDeviceHelper.cs` | 瓦尔基里全系 2.4G 接收器/HID 协议解析、双模电量、8K 回报率与独立 X/Y 轴 DPI 调节 |
| **DPI 档位管理与 XY 轴比例调节** | `src/UI/Forms/DpiManagementDialog.cs` / `src/UI/Controls/DpiStageRowControl.cs` | DPI 档位增删、XY 轴独立调节 (4:3/16:10 比例联动) 与板载固化 |
| **屏幕悬浮 OSD 指示器** | `src/UI/Forms/DpiOsdForm.cs` | 游戏前台免切焦点悬浮 HUD、DPI/XY独立双轴显示与回报率变动提示 |
| **多设备优先级拖拽与首选设备** | `src/Hardware/DeviceManager.cs` / `DevicePriorityForm.cs` | 外设优先级权重与展示顺序 |
| **按钮、滑块、分段选项卡外观** | `src/UI/Controls/*.cs` | 独立的原子自定义双缓冲 GDI+ 控件 |

---

## 3. 全局 AI 维护准则 (AI Maintenance Directives)

任何 AI Agent 在本代码库中工作时，必须严格遵守以下法则：

1. **内嵌契约同步更新 (Contract Priming)**：
   每个 `.cs` 文件顶部均包含 `[AI MAINTENANCE DIRECTIVE]`。修改任何文件时，**必须同步维护该文件头部的核心职责与依赖说明**，严禁让文档与实现脱节。
2. **C# 5 / .NET 4.0 语法铁律**：
   本项目使用 Windows 原生 `csc.exe` 4.8 编译，**严禁使用任何 C# 6+ 语法**：
   - ❌ 禁用 `$"..."` 字符串插值（必须使用 `string.Format("{0}", ...)` 或 `+` 拼接）；
   - ❌ 禁用 `?.` 空条件操作符（必须显式 `if (obj != null)`）；
   - ❌ 禁用 `nameof()` 操作符；
   - ❌ 禁用 `out var` 内联变量声明；
   - ❌ 禁用表达式主体定义 `=>`（必须使用传统函数体 `{ return ...; }`）。
3. **编码格式锁定 (UTF-8 with BOM)**：
   所有新建与修改的源文件必须保存为带有 BOM 的 UTF-8 编码，彻底消除因编码丢失导致的 `?` 乱码与字符截断。
4. **高分屏绝对自适应 (High-DPI Adaptive)**：
   严禁在控件、窗口、边距、圆角处使用硬编码像素数值。必须统一通过 `S(...)` 或 `DpiScale` 计算缩放后的物理尺寸。
5. **单实例安全互斥**：
   严禁通过遍历进程名暴力调用 `Process.Kill()`。必须使用系统命名全局互斥体 `Mutex("Global\\FerrisPulse_SingleInstance_Mutex")` 进行优雅管理。

## 4. 玄熊猫协议与按应用配置

玄熊猫当前以按应用配置为主要入口，用户操作见 [玄熊猫使用指南](docs/metapanda-guide.md)。以下模块均遵循 C# 5 / .NET 4.0、零外部依赖与 UTF-8 BOM 约束。

| 模块 / 路由 | 职责与契约 |
| :--- | :--- |
| `src/Hardware/MetapandaProtocol.cs` | 纯 17 字节 Report `08` 编解码；校验总和、命令、读内存地址/长度与写入回显。读取实际电量、已有 DPI 表与当前回报率；未知扩展编码不猜测。仅构造已有档位切换及 125/1000 Hz 命令，不改写 DPI 表。 |
| `src/Hardware/MetapandaDeviceHelper.cs` | 枚举 VID `3554` / PID `F5A9`、`F5AB` 且 UsagePage `FF02` / Usage `2`、输入输出均 17 字节的端点；使用有超时与取消清理的原生重叠 I/O。每端点串行化通信，写入后重新读取并确认目标设置。 |
| `src/Hardware/DeviceManager.cs` | 接入玄熊猫独立扫描结果，保留各 HID 端点身份。`VgnDeviceHelper.cs` 与 `UniversalGamingDeviceHelper.cs` 排除这些已知端点，避免重复归类。 |
| `src/Models/ApplicationMouseProfile.cs` | 规则字段为完整 exe 路径、端点 ID、从 1 开始的 DPI 档位、125/1000 Hz 与启用状态；拒绝只有文件名、盘符相对路径、通配符等规则。 |
| `src/Services/ApplicationMouseProfileService.cs` | 无硬件副作用的规则持久化与状态转换服务；按 exe 完整路径（忽略大小写）及精确端点 ID 匹配，第一个启用且有效的规则优先。保存使用同目录临时文件和原子替换，路径为 `%LocalAppData%\FerrisPulse\application-profiles.xml`。 |
| `src/UI/Forms/ApplicationMouseProfilesDialog.cs` | 添加/浏览 exe、选择端点、编辑档位和回报率、校验重复规则与保存；编辑器本身不写硬件。 |
| `src/UI/Forms/MainForm.Metapanda.cs` | 托盘顶部入口、前台完整路径读取、500 ms 调度和 750 ms 前台稳定判定、串行工作项及应用/退出恢复；编辑期间暂停调度。 |
| `src/UI/Forms/MainForm.Hardware.cs` / `MainForm.UI.cs` | 主界面展示真实档位与电量，仅切换已有 DPI 档位、限制 125/1000 Hz；应用规则持有端点时旧游戏自动设置让位。 |

### 身份、状态与恢复约束

- `DeviceId` 与 `HardwareFingerprint` 使用 `Metapanda:` 加完整 HID 路径，不按某一只样机序列号硬编码，也不按 VID/PID 合并同型号端点。无线与有线是独立端点；查找失败时不回退到任意同型号设备。此隔离设计不能代替多只同型号鼠标的实物 UI 验证。
- `QueryDevices()` / `QueryDevice(id)` 返回端点实际状态；电量未知为 `-1`，未知 DPI/回报率不伪造默认值。已知基础 DPI 编码按 `(值 + 1) × 50` 解码；非零扩展字节尚未验证，整组设置保持未知。
- `SetDpiStage(id, stage)` / `SetPollingRate(id, hz)` 只操作指定已连接端点，拒绝越界或未知状态；收到匹配回显后仍需读回目标设置才返回成功。支持上限为 1000 Hz，不能据此宣称支持 4K。
- 服务首次应用规则前保存该端点原始档位与回报率；规则间切换沿用原始快照。已知前台路径无匹配时恢复快照，恢复成功才释放；暂时无法读取前台路径不等同于规则退出。断连会丢弃该端点的运行期快照，不转移到其他设备。
- `Update()` 与编辑访问由调用方串行化。应用回调须同时确认 DPI 档位和回报率，只有两项均成功才能返回 `true`；失败清除成功缓存，下一次调度重试。主窗体回调对回报率写入失败尝试回滚，随后以实际回读为准。
- `RestoreAll()` 为显式退出恢复路径，仍只处理连接且状态可确认的端点；失败保留快照供存活的服务重试，不能保证断电、强制结束或退出时通信失败后的恢复。

### 当前验证边界

无线实机已确认 85% 电量、800/1600 DPI 档位及 125/1000 Hz 实际写入与回读。有线 `F5AB` 有抓包依据，尚未据此确认有线实机写入；高 DPI 扩展编码、4K 回报率及多只同型号设备的完整实物交互均不在当前验证结论内。使用时应关闭官方 Mouse Drive Beta，避免通信竞争。