# 玄熊猫适配：缺陷记录与回归要求

记录日期：2026-10-20。主工作区：`D:\github\mouse`，分支：`MetapandaMouse05`。本文记录本次问题、修复契约及后续修改必须检查的行为；不能以已有文档代替实际回归。

配套入口：[使用与参数](metapanda-guide.md)、[其他电脑与鼠标适配手册](mouse-adaptation-handbook.md)、[架构](../ARCHITECTURE.md)。

## 1. 设备与证据边界

- 实物：玄派玄熊猫 3395 P1 Pro Max 4K，官方程序 MetapandaMouse05 / Mouse Drive Beta。
- 本轮实测端点：VID `3554` / PID `F5AC`，4K 接收器；UsagePage `FF02`、Usage `2`、输入/输出报告均为 17 字节。
- 本机当时档位表为 800 / 1600，电量曾读到 85%；这些是当时读数，不是型号固定参数。档位是 1、2、3……的编号，DPI 内容可由用户修改。
- F5AC 六档回报率均完成官方软件抓包、匹配回复及独立写入回读；没有用专用仪器证明实际报告频率。
- F5A9 旧 1K 接收器保留此前验证能力；F5AB 有线保留此前抓包与适配，本轮未完成有线实机写入。不能把 F5AC 结论推广到所有连接方式或相同 VID 产品。
- 最后现场验收由用户点击软件按钮，确认一次点击更新、浮窗出现且按钮正常切换。没有据此证明实体 DPI 键即时监听。
- 原始抓包与临时脚本位于被 Git 忽略的 `tools/scratch/`；新电脑 clone 不会自动获得这些证据，交接时另存必要抓包和操作时间线。

## 2. 已出现的问题与修复

### R1：硬件立刻切换，界面等待十多秒

**现象**：点击另一个 DPI，鼠标速度已经变化，按钮和硬件生效文字仍是旧值，等待后台刷新才可能更新。

**根因**：后台 `ApplyDeviceStatus` 会替换设备对象，只修改设置调用捕获的旧对象或少数字段，不能可靠更新当前界面；较早启动的扫描也可能在写入后返回旧快照。

**修复契约**：

1. 设置接口通过 `out MouseBatteryInfo confirmed` 返回匹配 ACK 后重新读取的完整状态，不把目标值直接当成成功值。
2. `PublishMetapandaConfirmedState` 在 UI 线程统一更新当前设备、列表、托盘和按钮，保留名称、主设备标记、优先级等元数据。
3. 用 `LastUpdated` 拦截旧扫描和迟到回调；允许更新的真实硬件状态继续生效，不能永久锁住手动设置值。
4. 设置成功后不等待常规电量刷新周期才更新 UI。

入口：`MetapandaDeviceHelper.cs`、`MainForm.Metapanda.Feedback.cs`、`MainForm.Hardware.cs`。测试：[test_metapanda_feedback.ps1](../tests/test_metapanda_feedback.ps1)。

### R2：第一次点击改硬件，第二次点击按钮才更新

**现象**：第一次点 800，硬件已是 800、按钮仍显示 1600；再点一次 800 才更新。R1 的发布函数修复和局部测试通过后，用户仍复现此问题。

**确定根因**：`HasActiveMetapandaApplicationProfile` 在 `Monitor.TryEnter(metapandaProfileGate)` 失败时保守返回 true，适合作为写入前保护，却被手动成功回调用来直接返回，把锁忙误当成应用规则接管，丢弃已确认结果。确定性测试持有调度锁，复现了空规则服务也返回所有权 true。

**修复契约**：

- 成功回调进入 `QueueMetapandaManualFeedback`，每端点保存最后一条待发布操作。
- UI 计时器每 50 毫秒非阻塞尝试取锁；锁释放后检查真实规则所有权，再发布。不得阻塞 UI，也不得要求第二次点击。
- 连续点击合并该端点最新结果；真正的应用规则所有权仍优先。
- 窗体释放时释放计时器并清空队列。

入口：`MainForm.Metapanda.Feedback.cs`、`MainForm.Metapanda.cs`、`MainForm.Hardware.cs`。测试：[test_metapanda_feedback_contention.ps1](../tests/test_metapanda_feedback_contention.ps1)，覆盖锁忙后自动重试、无竞争立即发布、最新操作合并、真实规则接管。

**禁止退回**：在成功回调中仅凭上述保守结果丢弃状态；只测发布函数，不测入口到成功回调的链路。

### R3：软件档位按钮能切换，但没有 DPI 浮窗

**根因**：玄熊猫手动路径只发布确认状态，遗漏了公共 `OnDpiChanged` 通知。

**修复契约**：`PublishMetapandaConfirmedState` 返回是否接受状态；`PublishMetapandaManualDpiState` 只在接受后调用公共通知。软件档位入口和按值切档入口经反馈队列进入此路径，浮窗与按钮使用同一回读结果。

尊重 `dpiOsdEnabled`，显示实际 X/Y DPI、当前档位与档位数。失败、旧回调、真实规则接管不弹出旧成功提示；普通刷新、仅回报率刷新不误触发 DPI 浮窗。实体 DPI 键需要独立设计和验收。

测试：[test_metapanda_dpi_osd.ps1](../tests/test_metapanda_dpi_osd.ps1)。浮窗用 `SetWindowPos` 的 `SWP_NOACTIVATE | SWP_SHOWWINDOW`，原生可见时 WinForms `Form.Visible` 可能仍为 false；测试应检查 `IsWindowVisible` 和实际内容，不能为了错误断言让浮窗抢焦点。

### R4：回报率显示混用 2K、2000hz

窄布局会把按钮简写成 1K / 2K / 4K，其他入口保留完整数字。现在统一为 `125 Hz`、`250 Hz`、`500 Hz`、`1000 Hz`、`2000 Hz`、`4000 Hz`；主窗口基础宽度为 600 逻辑像素，为六项留足空间。

主界面、电竞按钮、硬件提示、托盘和规则下拉框须一致，显示文本与整数 Hz 分离。缩放继续使用既有 DPI 缩放方法，不能把截图尺寸写成固定物理尺寸。测试：[test_metapanda_ui.ps1](../tests/test_metapanda_ui.ps1)、[test_polling_rates_adaptive.ps1](../tests/test_polling_rates_adaptive.ps1)，改布局仍须检查当前构建实物界面。

### R5：自动点击工具无法操作自绘按钮

本轮截图出现 FrameArrived 超时，坐标点击报告 `coordinate input geometry is unavailable`，文字监测可用。按钮原先暴露为 Pane，现已补标准可访问对象：PushButton、Click 默认动作、Pressed 状态、StateChange 通知、禁用/释放保护及 UI 线程调用。

测试：[test_segment_button_accessibility.ps1](../tests/test_segment_button_accessibility.ps1)，通过真实 `AccessibleObject.DoDefaultAction` 检查 Click 事件和选中状态。该测试不等于桌面工具成功点击；修复后工具坐标输入仍不可用。本轮实际点击由用户完成，证据中必须保留这个区别。

## 3. 设计风险与确定性复现

以下为语义约束和测试中复现的风险，不应误写成全部都曾在用户现场发生。

### 档位编号不是固定 DPI

- 按编号：`DpiValue=0`、`DpiStage=1..8`，始终选该编号，其 DPI 可以变化。
- 按值：`DpiStage=0`、`DpiValue>0`，用新读到的表匹配 X/Y 均等于目标值的档位。
- 重复值优先当前匹配档，否则最小编号；X/Y 不同用档位模式。无匹配、未知扩展、无效编号禁止猜测写入。
- 本功能只选择已有档位；修改板载 DPI 数值需要另行抓包验证。
- 游戏 800 DPI / 4000 Hz、办公 1600 DPI / 125 Hz 是可编辑预设。无匹配应用时恢复实际基线，不是无条件套用办公预设。

### 表变化后的恢复

只保存原编号，会在表重排后恢复到不同 DPI，已通过确定性测试复现。现在保存原始 X/Y，恢复时先确认原编号仍指向原值，否则搜索新表；原值消失时保留待恢复状态，不擅自改写表。

测试：[test_metapanda_flexible_profiles.ps1](../tests/test_metapanda_flexible_profiles.ps1)、[test_application_mouse_profiles.ps1](../tests/test_application_mouse_profiles.ps1)。

### 端点与能力隔离

相同 VID 不代表相同协议。按已验证 PID、Usage、报告长度与完整路径路由，避免 VGN / 通用助手重复认领；断连不能改发另一只同型号鼠标。

F5AC 六档协议值为 `08 / 04 / 02 / 01 / 10 / 20`，不能外推 8000 Hz。F5A9 / F5AB 当前只开放既有 125 / 1000 Hz。未知值保留未知，失败不得更新成功状态。

测试：[test_metapanda_protocol.ps1](../tests/test_metapanda_protocol.ps1)、[test_metapanda_integration.ps1](../tests/test_metapanda_integration.ps1)。

## 4. 测量、版本与测试副作用

- 四次独立写入和回读曾耗时 502、503、503、503 毫秒，UI 发布函数单独测试约 45～50 毫秒；不能证明完整点击链路没有丢回调。
- 现场单击记录中，从档位写入 ACK 到文字监测读到新状态为 814 毫秒，包含回读及约 200 毫秒采样间隔；不是纯绘制耗时或完整点击延迟。性能记录须说明起止点和采样方法。
- 构建成功不代表运行新版。曾出现旧 outputs 程序仍运行；交付须核对进程完整路径和当前构建。主目录是 `D:\github\mouse`，聊天 outputs 仅为旧交付快照。
- 替换 exe 前从托盘正常退出；关窗口可能只是收进托盘。按明确路径/PID确认，不按进程名批量结束，不强杀跳过规则恢复。
- PowerShell 内构造 `MainForm` 曾将 HKCU Run 的 FerrisPulse 改成 `powershell.exe`。部分新测试已备份恢复，不能假设所有旧测试均隔离。测试前记录配置和自启动，测试后还原；原先关闭自启动不能擅自开启。
- 不删除用户规则来让测试通过，不留下第二实例，不让启动项指向 scratch / 测试宿主。
- 旧程序集、SKIP、未进入运行时分支、静态源码断言通过，不能作为完整运行通过的证据。

## 5. 后续更新的必查清单

触及硬件设置、调度、设备状态、控件、OSD 或布局时，按范围执行自动化与实机验收。

### 自动化基线

下列 16 项在本轮代码修复后通过；这是历史记录，不代表未来构建自动通过。脚本均在 `tests/`。

| 范围 | 脚本 |
|---|---|
| 协议、规则、能力与路由 | `test_metapanda_protocol.ps1`、`test_application_mouse_profiles.ps1`、`test_metapanda_flexible_profiles.ps1`、`test_metapanda_integration.ps1` |
| UI、确认、锁竞争、浮窗、可访问性 | `test_metapanda_ui.ps1`、`test_metapanda_feedback.ps1`、`test_metapanda_feedback_contention.ps1`、`test_metapanda_dpi_osd.ps1`、`test_segment_button_accessibility.ps1` |
| 既有行为 | `test_auto_game_dpi.ps1`、`test_polling_rates_adaptive.ps1`、`test_startup_game_buttons_visibility.ps1`、`test_razer_ui_routing.ps1`、`test_universal_dpi_adaptation.ps1`、`test_device_switch_ui_cleanup.ps1`、`test_tray_menu_behavior.ps1` |

先编译当前源码，再将 `FERRISPULSE_TEST_ASSEMBLY` 设为该构建完整路径，不能加载旧二进制。示例：

```powershell
Set-Location -LiteralPath 'D:\github\mouse'
cmd /c build.bat
if ($LASTEXITCODE -ne 0) { throw 'Build failed' }
$env:FERRISPULSE_TEST_ASSEMBLY = (Resolve-Path -LiteralPath '.\FerrisPulse.exe').Path
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\test_metapanda_feedback_contention.ps1
if ($LASTEXITCODE -ne 0) { throw 'Contention regression failed' }
```

其他测试分别运行并检查输出。`tools/run_all_tests.ps1` 枚举所有测试、每个子进程 8 秒超时，成功摘要不展示正常输出；必要时直接运行相关脚本检查是否跳过运行时分支。不得把上述历史结果写成全仓所有测试通过。

### 实机验收

- [ ] 正在运行刚构建的主目录 exe；官方程序已退出，核对端点和实际档位表。
- [ ] 先不启用接管该端点的规则，只点击一次另一 DPI：速度、按钮、硬件文字、托盘一致，不靠第二次点击补救。
- [ ] 反向切回；快速连续切换最终一致，旧扫描/迟到回调不回滚，UI 保持响应。
- [ ] 开启 OSD 时浮窗内容正确且不抢焦点；关闭后不弹；只改回报率不误弹 DPI 提示。
- [ ] 真正规则接管时规则优先，退出恢复实际基线；切换设备不更新错设备。
- [ ] 各开放回报率写入和回读正确，各入口完整显示数字及 ` Hz`，缩放下六档不被裁切。
- [ ] 用隔离配置测试表重排、重复值、X/Y 不同、无匹配；涉及实物表修改先记录并恢复原表。
- [ ] 按范围验证断连、重连、退出和其他品牌路由；还原用户设置与启动项。
- [ ] 记录构建、设备/固件、操作、预期/实测、证据位置和未测项，不以推测代替。

纯文档更新无需重启或操作硬件。以后缺陷记录应包含：触发条件 → 确定根因 → 修复契约 → 自动化测试 → 实机证据与限制，避免只写已修复。
