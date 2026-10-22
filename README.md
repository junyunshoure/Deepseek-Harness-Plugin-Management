# deepseek-harness-插件——共同打造一个功能更加完全的deepseek harness插件包

这个仓库把一台**已经配置完成的 DSH Desktop**（DeepSeek Harness 桌面版）的插件配置整体打包，目标是让另一台 Windows 机器装完就是同一套环境：**插件本体 + 依赖 + 启停状态 + 界面偏好 + 模型提供方清单**，而不是让使用者从零一个个装。

分发方式：完整安装包（约 150 MB / 解压约 400 MB）作为 Release 附件；仓库里只保留**可审阅的**安装器、清单、配置快照与逐文件校验值。GitHub 自动生成的 "Source code" 压缩包不含插件与依赖，**不能用来安装**。

## 版本一览

| 版本 | 日期 | 内容 | Release |
|---|---|---|---|
| v0.1.0-demo.1 | 2026-10-21 | 首个 Demo，验证「整包迁移」这条路能走通 | [v0.1.0-demo.1](https://github.com/junyunshoure/Deepseek-Harness-Plugin-Management/releases/tag/v0.1.0-demo.1)（Pre-release） |
| v1.0.0 | 2026-10-22 | 正式版第一版：36 bundle / 247 组合行 / 17,453 文件 | [v1.0.0](https://github.com/junyunshoure/Deepseek-Harness-Plugin-Management/releases/tag/v1.0.0) |
| v1.0.0-patch.1 | 2026-10-22 | v1.0.0 的**独立补丁**：把逆向工具改成「按需加载」，并补全本说明 | [v1.0.0-patch.1](https://github.com/junyunshoure/Deepseek-Harness-Plugin-Management/releases/tag/v1.0.0-patch.1) |

## 正式版第一版 v1.0.0（2026-10-22）

首个**正式版**，基于 2026-10-22 的 DSH Desktop 配置快照（插件、启停状态、界面偏好、模型提供方与模型清单）。

完整安装包请从 [Releases → v1.0.0](https://github.com/junyunshoure/Deepseek-Harness-Plugin-Management/releases/tag/v1.0.0) 下载：

- `DSH-Plugins-v1.0.0-Windows-x64.zip`（156,568,436 字节，约 149 MB）
- `DSH-Plugins-v1.0.0-Windows-x64.zip.sha256`

SHA-256：`8a0a70c09dcc9a6576ee7e55d1537185614b744ee1ce26de214d31cb8e4e8823`

**规模**：bundle 36 个（4 个 DSH 内置 + 32 个第三方包，全部可安装）、插件组合行 247 条、文件 17,453 个、解压后约 400 MB。

仓库中的 `stable/` 保留可审阅的安装器、清单、配置快照、启停状态辅助 bundle、版本元数据和逐文件校验清单（`checksums.json`）。完整插件与依赖作为 Release 附件分发。

安装前先阅读 [正式版安装说明](stable/README.md)，版本变化见 [更新记录](stable/CHANGELOG.md)。仅面向 **Windows x64 / DSH 内核 0.2.1-rc.2 / 新初始化的 Desktop profile**；**未在第二台物理机、其他内核或其他架构上验证**，不承诺通用兼容。

安装包内 `config/` 只放配置结构（界面偏好、模型提供方与模型清单、插件启停），**不含任何 API 密钥或账号凭证**，需自行配置。

## 包里到底装了什么

一个包由三部分组成：

1. **安装器**：`install.ps1` + `install-helper.cjs`（另有 `INSTALL.cmd` / `VERIFY.cmd` 两个入口）。它不重写配置文件，而是调用 DSH Desktop 自带的插件 CLI，把本地目录以 `link:` 方式注册进目标 profile，再校验版本与加载结果。
2. **清单与状态**：`migration.json`（包清单）、`inventory.json`、`plugins.csv`、`bundles.csv`、`插件完整清单.txt`、`checksums.json`（17,453 个文件的逐文件 SHA-256）、`payload/migration-state/`（只记录每个插件 `disabled: true/false` 的辅助 bundle）。
3. **可参考的配置快照**：`config/`（`cordis.patch.yml`、`package.json`、`cordis.yml`、`pnpm-workspace.yaml`），只用于对照阅读，安装器**不会**自动套用。

### 36 个 bundle 的功能分组

DSH 内置（4 个，随内核分发）：`@deepseek-ai/dsh-base`、`@deepseek-ai/dsh-web-app`、`@deepseek-ai/dsh-experimental-agent-team-profile`（Agent Teams）、`@deepseek-ai/dsh-experimental-auto-review`。

第三方 32 个，按用途大致分组：

| 功能域 | 插件 | 作用 |
|---|---|---|
| 上下文与压缩 | `billion-context`、`dsh-context`、`@kenz1117/dsh-ui-usage-billing` | 长对话压缩与可回溯摘要、上下文用量可视化 |
| 记忆与知识 | `@openviking/dsh-memory-plugin`、`@agentscope-ai/reme-dsh-plugin`（ReMe）、`@vectorize-io/hindsight-coding-agents`、`@lemoncat7/dsh-knowledge`、`@wxg-prc-cpg/dsh-weknora` | 跨会话记忆、经验召回、知识库检索（WeKnora） |
| 技能体系 | `dsh-mattpocock-skills-deck`、`dsh-skill-hub`、`dsh-my-skill-manager`、`@wxg-prc-cpg/browser-skill-dsh-plugin` | 技能目录与市场、按来源分组启停、新建技能向导、浏览器操作技能 |
| 浏览器与抓取 | `dsh-ego-browser`、`@wxg-prc-cpg/browser-skill-dsh-plugin` | 驱动本机已登录浏览器（读页面、填表单、跑流程） |
| 逆向与二进制 | 技能 `reverse-engineer-anything` + REA 6.7.0（见补丁） | 原生二进制 / Electron ASAR / .NET / 网页应用的静态与运行时取证 |
| 创作与可视化 | `@changfenhuang/dsh-genui`、`@tt-a1i/archify-dsh`、`dsh-drawai`、`@liustack/modlens` | 对话内富组件、架构图、drawio 画布、图片理解 |
| 界面与娱乐 | `@linxin666/dsh-web-all`、`@linxin666/dsh-client-ui-git-graph`、`dsh-plugin-wallpaper-engine`、`dsh-plugin-whale-pet`、`dsh-whale-widget`、`@local/dsh-client-ui-workbench` | 界面增强、Git 图、壁纸引擎、桌面宠物、多场景工作台 |
| 工具与运维 | `dsh-undo-savepoint`、`dsh-rewind-plugin`、`dsh-approval-gate`、`dsh-cost-meter`、`dshmarket` | 配置快照与回滚、会话回退、审批门禁、成本计量、插件市场 |
| 外部集成 | `dsh-zotero`、`@xmanrui/dsh-im`、`treg-dsh`、`dsh-infinite-gen-5` | 本地 Zotero 文献库、IM 通道、外部数据工具集、长任务生成 |

（版本号见 `stable/migration.json` 与 `stable/bundles.csv`。）

## 装上之后能做什么

- **对话与上下文**：长会话自动压缩并保留可回溯记录；用量/成本可在界面里看到。
- **技能（skills）**：浏览、按来源分组、整组启停、从 GitHub 市场安装与跟踪上游更新；技能正文按需加载。
- **记忆**：跨会话记忆与经验召回（OpenViking / ReMe / Hindsight 三条线各自独立，可单独关）。
- **浏览器**：直接操作你本机已登录的 Chromium，完成登录态阅读、表单填写、页面核验。
- **逆向（按需）**：需要分析已发布二进制、安装包、ASAR/Electron 应用时才加载；平时只留一行描述。
- **逆向之外的创作**：对话内 UI 组件、架构图、drawio 画布、图片文字识别（modlens）。
- **运维**：配置改动前自动快照、改错可回滚；插件市场一键安装。

## 运行依赖与前提

| 项 | 要求 |
|---|---|
| 系统 | Windows 10/11 **x64** |
| DSH Desktop | 内核 **0.2.1-rc.2**（安装器会校验版本，不匹配即停） |
| profile | 必须是**新初始化的 desktop profile**；已有插件的 profile 会被拒绝，避免冲突 |
| 磁盘 | 约 400 MB（解压后） |
| 运行时 | Desktop 自带 Node 24.21.0；`~/.dsh/profiles/desktop` 里的第三方依赖已随包提供 |
| 网络 | 可选。插件本体离线可用；模型调用、插件市场、记忆服务、知识库需要联网 |
| 外部账号 | 模型 API Key（包内只有环境变量名，不含密钥）；可选 GitHub token（技能市场/来源跟踪）、Zotero（本地）、WeKnora / OpenViking（自建服务） |
| 可选组件 | Ghidra 12.1.4 + JDK 21（逆向的 Native/Ghidra 通道）；LibreOffice（office 渲染） |

## 已知缺陷与边界（重要）

1. **只在一台机器上验证过。** 没有第二台物理机、其他内核版本、其他架构的 GUI 安装验证；"能装" 与 "装完一切正常" 不是同一件事。
2. **只支持全新 profile。** 安装器遇到未知包、来源不一致、组合行对不上就**停**，不做合并。想保留现有配置，就另建 profile。
3. **安装不是原子的。** 中途失败可能留下半装状态；持久目录 `%LOCALAPPDATA%\DSHPluginMigration\plugins-20261022-stable` 请勿手动删除（里面有回滚所需副本）。
4. **`config/` 里的模型清单是快照，不是保证可用。** 其中若干模型 ID 在对应中转站上并不存在（会 404），且 `config/` 不会被自动套用，需要自己按实际可用模型改。
5. **中转站通道的缓存问题不在本包范围内。** 部分 OpenAI 兼容通道 `cacheRead` 恒为 0，长上下文每轮重传会明显变慢；官方 DeepSeek 直连通道正常。
6. **部分内置工具默认是关闭的。** 247 条组合行里有 20 条 `disabled: true`（如 `bash-sandbox`、`tool-bash`、若干 subagent / todo / goal / web 工具），这是所基于的 web-app bundle 自身补丁层的选择，本包如实保留，不擅自"修好"。
7. **逆向默认不注册 MCP。** REA 的 207 个工具 schema 会占掉约 19 万 token，足以把 196K/204K 的窗口塞爆（详见补丁说明）。现在改为技能按需加载 + 本地 CLI。
8. **`@local/dsh-client-ui-workbench` 是本地 link 包。** 打包时已按真实路径材料化（dereference）成普通目录，但它的上游在你机器上原本是个链接；后续手动更新它需要自己处理。
9. **手改技能会被市场更新覆盖。** 例如补丁改写的 `reverse-engineer-anything` 没有上游来源跟踪记录，但技能市场若重新安装/更新同名技能，会覆盖成上游版本（届时重跑补丁即可）。
10. **没有统一 LICENSE。** 第三方插件各自保留原许可与版权文件，本仓库只做分发，不代表取得再许可。
11. **不迁移隐私数据。** 不含 API 密钥、账号凭证、聊天记录、浏览器用户数据、Zotero 文献库。
12. **中文路径与 PowerShell 5.1。** 安装脚本以 UTF-8 BOM 保存且脚本内只用 ASCII 文案，避免 PS 5.1 按 ANSI 解析导致乱码/语法错误；请不要另存为无 BOM。

## 安装与校验

1. 确认 Windows x64、DSH 内核 0.2.1-rc.2、profile 为全新初始化。
2. 解压 ZIP 到任意目录（**不要只解出部分文件**）。
3. 双击 `INSTALL.cmd`，或在解压目录执行 `powershell -ExecutionPolicy Bypass -File .\install.ps1`。
4. 先自检不动手：`powershell -ExecutionPolicy Bypass -File .\install.ps1 -CheckOnly`（应输出「SHA-256 文件校验通过：17453 个文件」）。
5. 安装后复核：`VERIFY.cmd` 或 `install-helper.cjs --check-only`。

回滚：安装器会把目标 profile 的 5 个关键文件备份到持久目录；按 `install.ps1` 输出里的备份路径恢复，或改用你自己的 DSH 配置快照（`dsh-undo-savepoint`）回滚。

## 补丁 v1.0.0-patch.1：把逆向工具改成「按需加载」

**要解决的问题**：REA（`rea-agents`）注册 207 个 MCP 工具，schema 合计约 774,808 字节 ≈ 19.4 万 token。工具 schema 是**不可压缩的固定开销**，压缩工具省不掉，于是整个会话在发出前就被 DSH 拦下（413 `preflight_compress_failed`）。把 MCP 停用后，工具数从 371 降到 164、约 4.1 万 token，会话恢复正常。

**只停 MCP 还不够**：原技能正文 23,523 字节，内容仍然教 agent 去跑 `rea setup` 把 MCP 装回来——一次误操作就会复发。所以本补丁做的是**接口改造**，不只是关开关：

- 技能正文从 23,523 字节压到 **2,781 字节**（减少 88%），只留"什么时候该用、用之前先读手册、不要注册 MCP"。
- 常驻描述从 300 字符收到 **141 字符**，平时只占一行。
- 细节移到 `references/manual-cli.md`（6,290 字节），**只在真正要逆向时才读**：CLI 语法、三阶段工作流、输出裁剪（`--format` / `--filter-output` / `--token-limit`）、平台限制。
- 明确禁止：`rea setup`、`mcp add`、改 `cordis.patch.yml` 把 rea-mcp 插回来。
- 原有的 6 篇专题（native / javascript / android / evidence / runtime / connection）**原样保留**，不删内容。

**这个补丁不碰 DSH 配置**（`touchesDshConfig: false`），只改 `%USERPROFILE%\.agents\skills\reverse-engineer-anything\` 下的技能文件；安装前整目录备份，随时可还原。安装后无需重启 DSH——技能描述会即时刷新。

下载：`DSH-Plugins-v1.0.0-patch.1-Windows-x64.zip`（7 个文件，19,029 字节）+ 同名 `.sha256`。安装：解压后 `INSTALL.cmd`，或 `install.ps1 -CheckOnly` 先自检。

> 注意：本补丁**不包含** REA 本体。逆向能力依赖你机器上已有的 `REA`（`rea-agents` 6.7.0）与 Ghidra/JDK；没有它们时技能仍然只占一行描述，不会报错。

## 仓库结构

```
README.md              本说明
RELEASE_NOTES.md       发布记录
release-validation.json 发布自检结果
stable/                v1.0.0 可审阅部分（安装器、清单、配置快照、校验值）
demo/                  v0.1.0-demo.1 可审阅部分
patch/                 v1.0.0-patch.1 可审阅部分
```

## 第三方许可

各第三方插件的许可与版权文件保留在完整安装包内各自的 `package/` 目录中。本仓库只做个人环境的配置分发，不对第三方代码授予任何额外许可。
