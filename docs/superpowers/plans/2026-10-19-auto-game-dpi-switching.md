# 全屏游戏自动切换 DPI 功能实现计划 (Auto Game DPI Switching)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现当检测到全屏电竞游戏运行时，鼠标 DPI 与回报率可同步或独立自动切换至预设电竞档位，退出游戏后平滑恢复桌面原档位。

**Architecture:** 扩展现有的 `GameDetector` 监听引擎与 `cardPerformance` 卷帘门自适应卡片容器，新增独立 `autoGameDpiEnabled` 开关、`gameDpiStage` 档位选择与 `desktopDpiStage` 原状态快照回退机制，无缝覆盖 Razer、Valkyrie、Logitech、Rapoo 等全生态鼠标。

**Tech Stack:** C# 5.0, .NET Framework 4.0, Windows Forms, Win32 NativeMethods, Registry API

**Spec:** In-chat approved design (方案A: 档位选择 + 选项1: 独立开关)

## Global Constraints

- 严禁使用 C# 6.0+ 语法（保持 C# 5.0 / .NET Framework 4.0 纯净原生编译）。
- 所有修改与新建文件必须严格保存为【UTF-8 with BOM】编码。
- 延续既有的统一 9px 垂直行间距规范与 Cubic Ease-Out 平滑卷帘门动效。
- 不抢占游戏焦点，切档过程毫秒级完成，杜绝线程卡顿与异常阻塞。

## Review Focus

1. 鼠标处于 XY 轴独立灵敏度（X != Y）时切档，确保 X 与 Y 轴数值同步被正确切入与复原。
2. 游戏过程中若用户在软件 UI 中手动更改 DPI 档位，应更新当前电竞档位设定，退出游戏时仍准确恢复进游戏前的桌面档位。
3. 仅勾选“自动切换 DPI”或仅勾选“自动切换回报率”或两者同时勾选时，卡片折叠/展开高度应精准自适应（148px / 218px / 255px）。
4. 游戏退出防抖（2 秒连续离线判定），避免切出桌面 Alt-Tab 瞬间频繁抖动切档。
5. 当所选设备不具备 DPI 调节能力时，相关游戏控制项安全禁用/隐藏，不报空指针异常。

---

### Task 1: 编写自动化回归测试集 `tests/test_auto_game_dpi.ps1` (TDD Red)

**Files:**
- Create: `tests/test_auto_game_dpi.ps1`

- [ ] **Step 1:** 编写测试用例，覆盖：
  - 数据模型与字段定义（`autoGameDpiEnabled`, `gameDpiStage`, `desktopDpiStage`）
  - 注册表读写契约（`AutoGameDpiEnabled`, `GameTargetDpiStage`）
  - 卡片 2 高度自适应计算逻辑（148 / 218 / 255）
  - 游戏进入与退出时 DPI 切档与恢复状态机逻辑
  - 悬浮 OSD 与通知文本格式（独立与组合模式）
- [ ] **Step 2:** 执行测试，确认当前处于 Failing (Red) 状态。
- [ ] **Step 3:** 确保测试脚本 UTF-8 BOM 编码。

---

### Task 2: 数据契约、注册表持久化与托盘菜单项实现

**Files:**
- Modify: `src/UI/Forms/MainForm.cs`
- Modify: `src/UI/Forms/MainForm.Tray.cs`

- [ ] **Step 1:** 在 `MainForm.cs` 中增加核心字段：
  - `private bool autoGameDpiEnabled = false;`
  - `private int gameDpiStage = 2;`
  - `private int desktopDpiStage = 0;`
  - `private ModernCheckBox chkAutoGameDpi;`
  - `private Label lblGameDpiTitle;`
  - `private ModernSegmentButton[] btnGameDpiStages;`
  - `private ToolStripMenuItem autoGameDpiToggleItem;`
  - `private ToolStripMenuItem gameDpiSub;`
- [ ] **Step 2:** 在 `LoadConfig()` 与 `SaveConfig()` 中增加注册表持久化支持：
  - `AutoGameDpiEnabled` (0/1)
  - `GameTargetDpiStage` (1..5)
- [ ] **Step 3:** 在 `MainForm.Tray.cs` 中扩展托盘菜单：
  - 在“全屏游戏自动切换”菜单下新增 `[✓] 自动切换 DPI`
  - 新增 `电竞 DPI 档位 (第1档..第5档)` 二级子菜单
- [ ] **Step 4:** 确保修改文件保持 UTF-8 BOM 编码。

---

### Task 3: 卡片 2 UI 控件布局、按钮联动与高度自适应动效

**Files:**
- Modify: `src/UI/Forms/MainForm.UI.cs`

- [ ] **Step 1:** 在 `InitializeUI()` 中实例化 `chkAutoGameDpi`、`lblGameDpiTitle` 与 `btnGameDpiStages[5]`。
- [ ] **Step 2:** 重构 Row 3 排版，并列容纳：
  - `chkAutoGameRate`（全屏自动回报率）
  - `chkAutoGameDpi`（全屏自动 DPI）
  - `btnManageGames`（游戏管理按钮）
- [ ] **Step 3:** 布局 Row 4（电竞 DPI 档位）与 Row 5（电竞回报率）：
  - `RelayoutPerformanceControls()` 中实现按勾选状态动态排布。
  - 档位按钮点击事件联动 `SetGameDpiStageFromUI(int stage)`。
- [ ] **Step 4:** 重构 `UpdatePerformanceCardHeightForCurrentDevice()` 与 `RelayoutFormForDpi()`：
  - 无勾选：`148 * dpiScale`
  - 勾选其一：`218 * dpiScale`
  - 两者均勾选：`255 * dpiScale`
- [ ] **Step 5:** 确保修改文件保持 UTF-8 BOM 编码。

---

### Task 4: 游戏检测监听器联动与硬件 DPI 自动切档/恢复引擎

**Files:**
- Modify: `src/UI/Forms/MainForm.Hardware.cs`

- [ ] **Step 1:** 改造 `StartGameMonitor()` 轮询保护条件：
  - 当 `autoGameRateEnabled || autoGameDpiEnabled` 任一开启时均持续监听前台游戏。
- [ ] **Step 2:** 实现 `ApplyGameDpiStage()` 与 `RestoreDesktopDpiStage()`：
  - 进游戏前缓存 `desktopDpiStage`；
  - 进游戏时切换到 `gameDpiStage`；
  - 退游戏时切回 `desktopDpiStage` 并重置；
  - 底层兼容 Razer, Valkyrie, Logitech, Rapoo 等全系设备。
- [ ] **Step 3:** 增强 OSD 提示与通知气泡：
  - 组合模式：`🎮 电竞加速: 4000 Hz · 800 DPI (第2档)`
  - 单 DPI 模式：`🎮 电竞加速: 800 DPI (第2档)`
  - 退游戏恢复提示：`常规桌面: 1000 Hz · 1600 DPI (第3档)`
- [ ] **Step 4:** 实现 UI 手动切档时的记忆联动：
  - 若在游戏激活期间点击 DPI 档位，自动同步更新 `gameDpiStage` 并高亮。
- [ ] **Step 5:** 确保修改文件保持 UTF-8 BOM 编码。

---

### Task 5: 全量编译验证与自动化回归测试 (TDD Green)

**Files:**
- Test: `tests/test_auto_game_dpi.ps1`
- Test: `tools/run_all_tests.ps1`

- [ ] **Step 1:** 运行 `tests/test_auto_game_dpi.ps1` 验证新增功能 100% PASS。
- [ ] **Step 2:** 运行 `build.bat` 验证 0 错误 0 警告成功编译生成 `FerrisPulse.exe`。
- [ ] **Step 3:** 运行 `tools/run_all_tests.ps1` 确保全套 30 项自动化测试全量 PASS。
- [ ] **Step 4:** Git 提交与文档更新。
