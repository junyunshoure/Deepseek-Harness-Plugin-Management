# DeepSeek Harness 插件迁移包 Demo v0.1.0-demo.1（Windows x64）

> **初始 Demo / 预发布版本**。这是 2026-10-21 插件迁移快照的首个版本化发布，供演示和迁移验证。安装器、插件版本与启停策略保持原已验证快照的行为；本次增加 Demo 标记和发布元数据。

**下载时选择 Release 附件 `DSH-Plugins-Demo-v0.1.0-demo.1-Windows-x64.zip`。GitHub 自动生成的 Source code ZIP/TAR 与仓库源码不包含完整插件依赖，不能替代安装包。** 下载后可用同名 `.sha256` 文件核对压缩包，再完整解压并运行 `INSTALL.cmd`。

版本与兼容范围见 `release.json`；本次发布说明见 `CHANGELOG.md`。

本包来自 2026-10-21 的 desktop profile。目标 DSH **内核版本必须为 0.2.1-rc.2**；Desktop 外壳的版本号可能不同。包中含实际插件代码和所需依赖，不需要重新到市场逐个下载。

## 如何在另一台电脑安装

1. 安装与源电脑同版的 DeepSeek Harness Desktop，启动一次完成初始化，然后从托盘**完全退出**。目标应是刚初始化的 desktop profile。脚本会使用目标同版 Desktop 自带的四个内置 bundle，并启用源环境使用的 Agent Teams 和自动审查组件。
2. 将 ZIP 复制到另一台 **Windows x64** 电脑，并完整解压。建议放在短路径，例如 `C:\DSHMigrate`，避免 Windows 旧版解压器的长路径限制。不要直接在 ZIP 预览窗口中运行。
3. 双击 **INSTALL.cmd**。脚本会自动找 Desktop；找不到时选择已安装的 `DeepSeek Harness.exe`。无需另外安装 Node/npm，也无需管理员身份。
4. 等待所有安装和配置验证通过，再打开 Desktop。账号、API/模型、登录、壁纸文件、Zotero 和其他外部软件按需在新电脑配置。

只校验文件完整性，可双击 **VERIFY.cmd**。它不会安装或修改 DSH profile。

若 Desktop 安装路径无法自动识别，也可在 PowerShell 中运行：

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -DshCmd 'D:\YourDesktop\resources\runtime\cli\bin\dsh.cmd'

## 包含什么

- **22 个另行安装的插件包及依赖的实际文件**。20 个当前可加载包会依源电脑顺序逐个安装。
- **4 个 DSH 内置 bundle** 只记录在清单中，继续使用目标同版 Desktop 自带文件，不打包另一份内核。
- **236 个当前加载器条目**：233 条组合配置插件行，以及 DSH 自动创建的根 include 和两条原生目录选择器条目。236 不是独立安装包数量。
- `插件完整清单.txt` / `bundles.csv` / `plugins.csv` / `inventory.json`：完整名称、版本、启停/加载状态。可用 Excel 打开 CSV。
- `payload/migration-state`：仅复制插件启停状态的辅助 bundle；安装后会多出一个名为 `dsh-migration-plugin-state` 的辅助 bundle，不代表多了一项原始插件。表达式形式的内置条件继续由相同内核计算。
- `checksums.json`：整个分发目录中每个文件的 SHA-256（校验清单自身除外）。ZIP 的 SHA-256 另附在压缩包旁。

## 两个已安装但不加载的包

源电脑安装了以下两包，但当前内核的兼容性检查已将它们跳过：

- `@michengai/dsh-code-review@0.1.12`
- `@michengai/dsh-archive-manager@1.0.19`

它们的实际文件仍完整保留在 `payload/node_modules`，清单中明确标记；一键脚本不会安装或强制启用它们，也不会自动授予版本豁免。因此可安装的第三方包为 20 个。今后换成兼容版本，请通过 DSH 插件管理器安装。

## 安装方式和保留目录

脚本先验证平台、文件哈希、内核版本和初始化状态，再复制整个分发目录到：

    %LOCALAPPDATA%\DSHPluginMigration\plugins-20261021

然后通过 Desktop 自带的官方 `dsh plugin --profile desktop add --offline --ignore-scripts --save-exact link:<本地目录>` 安装。所有依赖已在随包目录中；安装过程不下载 npm 包、不执行安装脚本。各插件之后调用外部服务或初始化浏览器等操作，仍可能需要联网或本地软件。它们与插件安装本身是不同步骤。

**安装后务必保留上述持久目录**，因为 profile 链接到其中的插件。原 ZIP 与原解压目录可以移动或删除。安装器不复制原电脑的用户名目录，也不要求两台电脑路径相同。

## 已有插件、失败和备份

为保证可预测的迁移效果，本脚本面向新初始化的 desktop profile。若目标有其他第三方插件，或已有同名但来源不同的安装，脚本会在改动前停止；请使用干净的目标环境，不要手工删除原有插件来强行通过。

每次安装前，将目标 profile 的清单、锁文件和覆盖文件复制到持久目录下 `backups/<时间>`。失败日志会给出此目录；官方命令不是整批原子事务，失败时可能已经安装了前面的包。修正报错后可再次运行同一安装器，已经使用本包固定目录的安装允许重跑。

安装成功会生成持久目录下的 `installation-result.json`，记录目标位置、备份位置、实际安装数量和组合配置验证结果。不要从日志中的“开始安装”判断完成，以最终“安装及组合配置验证通过”为准。

DSH 安装后的配置更改会由随包的快照插件自动保存为快照；改错时可在 DSH 中查看最近快照并撤销/回退。

## 不迁移的个人数据

本包不含 API 密钥、模型提供商配置、账号登录、浏览器 Cookie/用户目录、聊天记录、任务数据、Zotero 文献库、个人壁纸与音频文件，以及用户自定义外观设置。仅打包插件文件、公开包依赖、清单和插件启停状态。没有读取或复制 Zotero 文献库。

插件自带代码和文档中可能出现开发者的文件路径示例或 Cookie/credentials 类型名称；这些是发布包内容，不是账号数据。各包许可证和版权文件保留原样。请自行遵守第三方包原有许可。

## 验证范围

本包在原电脑的独立测试 DSH_HOME 和独立持久目录中通过官方 Desktop CLI 进行离线安装验证；另检查包版本、链接目标、bundle 启用状态、233 条插件组合和 ZIP 文件校验。未在第二台物理电脑启动 Desktop，也未验证需要个人账号或外部软件的插件功能。

## 文件索引

- `INSTALL.cmd`：一键安装入口。
- `VERIFY.cmd`：只校验分发文件。
- `install.ps1` / `install-helper.cjs`：可审阅的安装实现。
- `migration.json`：平台/版本/包安装顺序和跳过策略。
- `inventory.json` / `插件完整清单.txt`：源环境完整插件清单。
- `plugins.csv` / `bundles.csv`：Excel 友好清单。
- `payload/node_modules`：22 个直接安装包和完整依赖树。
- `payload/migration-state`：启停状态辅助 bundle。
