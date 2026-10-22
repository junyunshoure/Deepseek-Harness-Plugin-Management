# deepseek-harness-插件——共同打造一个功能更加完全的deepseek harness插件包

## 正式版第一版 v1.0.0（2026-10-22）

首个**正式版**，基于 2026-10-22 的 DSH Desktop 配置快照（插件、启停状态、界面偏好、模型提供方与模型清单）。

完整安装包请从本仓库 [Releases → v1.0.0](https://github.com/junyunshoure/deepseek-harness-Plugin-Management/releases/tag/v1.0.0) 下载：

- `DSH-Plugins-v1.0.0-Windows-x64.zip`（156,568,436 字节，约 149 MB）
- `DSH-Plugins-v1.0.0-Windows-x64.zip.sha256`

SHA-256：`8a0a70c09dcc9a6576ee7e55d1537185614b744ee1ce26de214d31cb8e4e8823`

**规模**：bundle 36 个（4 个 DSH 内置 + 32 个第三方包，全部可安装）、插件组合行 247 条、文件 17,453 个、解压后约 400 MB。

仓库中的 `stable/` 保留可审阅的安装器、清单、配置快照、启停状态辅助 bundle、版本元数据和逐文件校验清单（`checksums.json`）。完整插件与依赖作为 Release 附件分发；GitHub 自动生成的 Source code 下载不含它们，不能直接用于安装。

安装前先阅读 [正式版安装说明](stable/README.md)，版本变化见 [更新记录](stable/CHANGELOG.md)。仅面向 **Windows x64 / DSH 内核 0.2.1-rc.2 / 新初始化的 Desktop profile**；**未在第二台物理机、其他内核或其他架构上验证**，不承诺通用兼容。

安装包内 `config/` 只放配置结构（界面偏好、模型提供方与模型清单、插件启停），**不含任何 API 密钥或账号凭证**，需自行配置。

## 插件迁移包初始 Demo（v0.1.0-demo.1，2026-10-21）

初始 Demo 版本：**v0.1.0-demo.1**，基于 2026-10-21 插件快照。

完整安装包请从本仓库 [Releases → v0.1.0-demo.1](https://github.com/junyunshoure/deepseek-harness-Plugin-Management/releases/tag/v0.1.0-demo.1) 下载：

- `DSH-Plugins-Demo-v0.1.0-demo.1-Windows-x64.zip`
- `DSH-Plugins-Demo-v0.1.0-demo.1-Windows-x64.zip.sha256`

仓库中的 `demo/` 保留可审阅的安装器、清单、启停状态辅助 bundle、版本元数据和文件校验清单。完整插件和依赖作为 Release 附件分发；GitHub 自动生成的 Source code 下载不包含它们，不能直接用于安装。

安装前先阅读 [Demo 安装说明](demo/README.md)。本版本仅面向 **Windows x64 / DSH 内核 0.2.1-rc.2 / 新初始化的 Desktop profile**。验证范围与已知限制见 [发布记录](demo/CHANGELOG.md)。

第三方插件的原始许可与版权文件保留于完整安装包。该仓库不迁移个人账号、API 密钥、模型配置、聊天记录、浏览器用户数据或 Zotero 文献库。
