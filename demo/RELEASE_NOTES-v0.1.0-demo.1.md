# DeepSeek Harness 插件迁移包 Demo v0.1.0-demo.1

初始 Demo / 预发布版本，基于 2026-10-21 已验证的 Windows x64 插件迁移快照。

## 下载与安装

下载附件 **DSH-Plugins-Demo-v0.1.0-demo.1-Windows-x64.zip** 及同名 `.sha256`。请勿选择 GitHub 自动生成的 Source code 压缩包，它不含完整依赖。

先初始化 DSH Desktop 并从托盘完全退出，将安装包解压到短路径，再双击 `INSTALL.cmd`。可先运行 `VERIFY.cmd` 只校验文件。

## 兼容范围与内容

- Windows x64；DSH **内核 0.2.1-rc.2**。
- 面向新初始化的 Desktop profile；不覆盖其他来源的第三方插件。
- 记录 26 个 bundle，携带 22 个第三方包及其依赖；安装其中 20 个兼容包及一个启停状态辅助 bundle。
- 保留 233 条插件组合行的布尔启停状态。
- `@michengai/dsh-code-review@0.1.12` 和 `@michengai/dsh-archive-manager@1.0.19` 文件保留，因兼容性跳过安装。

## 验证与限制

原快照已通过独立环境的官方 CLI 离线安装、包链接、版本与组合配置验证；Demo 仅增加发布标记与说明，并重新验证 ZIP 内每个文件的 SHA-256。未在第二台物理电脑验证 GUI 或账号相关功能。

安装后须保留 `%LOCALAPPDATA%\DSHPluginMigration\plugins-20261021`。不包含个人账号、模型/API 配置、聊天记录、浏览器用户数据或 Zotero 文献库。第三方包的原始版权与许可保留。

## 补丁 v1.0.0-patch.1：逆向能力按需加载（2026-10-22）

正式版 v1.0.0 的独立补丁，不改动插件本体与已发布附件。下载 `DSH-Plugins-v1.0.0-patch.1-Windows-x64.zip`，
解压后运行 `install.ps1`（可先加 `-CheckOnly` 自检）。说明见 `patch/README.md`，发布页见
https://github.com/junyunshoure/Deepseek-Harness-Plugin-Management/releases/tag/v1.0.0-patch.1