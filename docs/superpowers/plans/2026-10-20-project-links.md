# 项目入口与默认更新设置调整

**目标**：按用户要求删除根 resources 赞赏资源，关于页替换为项目链接；README 说明基于 Ferris-echo/FerrisPulse 二次开发、适配玄熊猫 P1；默认自动更新关闭。

**范围**：保持 D:\github\mouse 主目录、MetapandaMouse05 分支、C# 5 / .NET Framework 4.0、UTF-8 BOM。保留原项目署名与许可证，手动检查更新入口保留。

- [x] 更新现有 AboutForm 展示与高 DPI 测试：检查当前项目/原项目链接、P1 二次开发说明、无二维码、链接不裁切。先运行展示测试，确认旧实现失败。
- [x] AboutForm 将 cardDonate/二维码面板改为 cardProject 与项目、说明、反馈、原项目链接；删除 DonateQrAssets.cs、仅生成赞赏码的脚本和经路径核对的根 resources 目录。更新相关架构说明。
- [x] README 改为当前适配分支主页，说明来源、已验证能力、档位/DPI 语义、构建与文档入口。ConfigManager.GetAutoCheckUpdate 的缺省值改为 false，当前电脑保存为关闭；扩展更新服务测试验证无配置时关闭与显式开启/关闭持久化，测试后恢复现场值。
- [x] 独立目录构建，运行 AboutForm、DPI、更新服务/更新界面及相关玄熊猫回归；检查渲染、编码、资源残留和 Git diff。GitHub 交付按本次会话的上传授权执行，最终状态以提交记录和远端核对为准。

手动更新模块的上游来源在 README 明示；本次不伪造本分支的 Release 附件或校验信息。程序若仍运行旧版，应明确区分源码/构建与运行版本，替换主 exe 时通过正常退出释放文件。

验证结果：新鲜构建和 7 项相关测试通过；旧实现分别在 P1 来源说明与默认关闭更新断言上失败。100%/200% 关于页离屏渲染已检查，100%/150%/200% 链接布局测试通过。最终主目录 exe 与测试构建 SHA256 一致，当前电脑 AutoCheckUpdate=0。
