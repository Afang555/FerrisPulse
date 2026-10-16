# 电量管家 (FerrisPulse) Agent Rules & Superpowers Configuration

> 本文件为“电量管家”工作区的最高指令文件。在本项目中，Superpowers 默认开启，且必须与项目的 7 大开发铁律协同执行。

---

## 1. Superpowers 项目级默认启用规范 (Project-Level Superpowers Active)

<EXTREMELY-IMPORTANT>
在“电量管家”项目中，Superpowers 工程方法论为【默认开启 (Always On)】状态：

1. **新功能 / 需求开发**：
   - 编写任何代码之前，必须先调用 `brainstorming` 技能，通过对话明确意图、推演设计方案并获得确认。
   - 确认设计后，使用 `writing-plans` 制定分步实现计划，严格遵循决策记录与测试断言规范。
   - 执行阶段遵循 `test-driven-development` 与 `executing-plans`。

2. **缺陷排查 / Bug 修复**：
   - 遇到任何异常、逻辑缺陷或报错，必须先调用 `systematic-debugging` 技能，严格执行四步法（复现 -> 追踪根因 -> 根除修复 -> 回归验证），严禁盲目打补丁或掩盖症状。

3. **任务跟踪与验证**：
   - 多步计划使用 Task Artifacts (`write_to_file` 配合 `ArtifactType: "task"`) 维护并用 `replace_file_content` 打勾。
   - 宣布完成前，必须执行 `verification-before-completion` 验证实际编译与运行输出。
</EXTREMELY-IMPORTANT>

---

## 2. FerrisPulse 维护规范与工程准则（7 大铁律）

本项目开发同时必须严格遵守 [AGENT_RULES.md](file:///D:/%E7%94%B5%E9%87%8F%E7%AE%A1%E5%AE%B6/AGENT_RULES.md) 中的底层铁律：

1. **语言标准与编译器基准**: 严格 C# 5.0 / .NET Framework 4.0，使用 Windows 原生自带 `csc.exe` 编译。严禁使用 C# 6.0+ 语法（禁止 `$"..."` 插值、禁止 `?.` 空条件运算符、禁止 `nameof` 等）。
2. **零外部依赖铁律**: 仅允许引用 .NET 4.0 核心程序集。系统交互严格采用 Win32 P/Invoke，严禁引入 NuGet 包或第三方 DLL。
3. **文件编码安全**: 所有 `.cs`, `.bat`, `.md`, `.ps1` 源码文件必须以 **UTF-8 带签名 (BOM)** 保存，编译始终加 `/codepage:65001`。
4. **模块化工程架构**: 禁止单文件巨石化，严格分层存放于 `src/Core/`, `src/Hardware/`, `src/Models/`, `src/Services/`, `src/UI/`。
5. **任务栏自愈与自启动守护**: 必须维护注册表自启动与 `WM_TASKBARCREATED` 托盘重建自愈逻辑；桌面图标绝不静默自建，严格由用户托盘手动触发。
6. **维护准则注释保留**: 每个代码文件头部必须永久保留 `// ⚠️ AI 维护准则 (AI MAINTENANCE DIRECTIVE - DO NOT REMOVE) ⚠️`。
7. **工作区锁定与文件卫生规范**:
   - 唯一合法工作区为 **`D:\FerrisPulse · 灵脉\`**（`proud-hertz` 与 `电量管家` 原目录已彻底废弃）。
   - 根目录只保留标准工程文件，严禁散落临时测试图、草稿代码或日志。
   - **严禁向 Git 仓库提交编译二进制（`*.exe`, `*.zip` 等）**，发布走 GitHub Releases 附件。
   - 临时脚本放 `tools/scratch/`，宣传素材放 `promo/`，归档放 `archive/`（均已配 `.gitignore`）。
   - Agent 收工前必须执行 `git status` 审查工作区，主动清除临时垃圾。
