# DSH 插件整合包 v2.0.0

给「只装了一个 DeepSeek Harness 空壳，别的什么都没有」的机器用的一键装机盘。
解压 → 双击 `INSTALL.cmd` → 选一个模式 → 装完自动启动。不需要装 Node.js，不需要手改任何 YAML。

- **适用内核**：DeepSeek Harness `0.2.x`（本包按 `0.2.1-rc.2` 构建）
- **适用平台**：Windows 10/11 x64；macOS 见 [`macos/INSTALL-MAC.md`](macos/INSTALL-MAC.md)
- **包内规模**：32 个插件包（26 个来自 npm + 6 个本机自研）· 36 个 bundle · 256 个插件条目 · 6 个技能 · 47 份能力手册与索引 · 23,249 个文件 · payload 约 503 MB
- **两个压缩包**：`DSH-Plugins-v2.0.0.zip`（插件，必装）+ `DSH-Plugins-v2.0.0-Services.zip`（本地记忆/知识库服务本体，可选，约 2.2 GB 解压后）

> 一个版本一个目录：`stable-v2/` 是当前版本，`stable/` 是 v1.0.0 存档（内容不再变动，仅供回退与对照）。

---

## 三分钟装完

1. 下载并把 `DSH-Plugins-v2.0.0.zip` **完整解压**到一个短路径，例如 `D:\DSH-Plugins-v2.0.0`（不要直接在压缩包里双击，也不要放在带空格和中文的长路径里）。
2. 双击 `INSTALL.cmd`（或右键 `install.ps1` → 用 PowerShell 运行）。
3. 按提示选模式：

   | 模式 | 什么时候选 | 行为 |
   |---|---|---|
   | **A 全新安装** | 机器上还没装过第三方插件 | 目标 profile 必须是干净的，否则中止（最安全） |
   | **B 智能合并**（默认，回车即用） | 已经装了一些插件 | 只补缺的，你已有的版本与配置一律不动 |
   | **C 备份覆盖** | 想用本包版本统一覆盖 | 先整份备份到 `%LOCALAPPDATA%\DSHPluginsPack\v2.0.0-windows\backups\<时间戳>`，再覆盖 |

4. 等它跑完。中途会：校验 23,249 个文件 → 把载荷复制到持久目录 `%LOCALAPPDATA%\DSHPluginsPack\v2.0.0-windows` → 备份 → 挂载 32 个插件 → 校验 256 个条目组合 → 合并配置 → 装 6 个技能 → 装 47 份能力手册 → 出安装结果 → 启动 DSH。
5. 打开 DSH → **设置 → 模型**：把 provider 的 `baseURL` 从 `https://YOUR-ENDPOINT.example.com` 换成你自己的中转站或官方地址，填上密钥。这是唯一需要你手填的东西（详见 [`docs/配置参考.md`](docs/配置参考.md)）。

装完想确认没毛病：双击 `VERIFY.cmd`（逐文件哈希）和 `DOCTOR.cmd`（环境体检）。

---

## v2 新增了什么（相对 v1.0.0）

| # | 新增 | 一句话 |
|---|---|---|
| 1 | **6 个本机自研插件** | 功能档位、记忆融合、技能融合中心、Ollama 面板、逆向指挥体系、多场景工作台，直接装好可用 |
| 2 | **安装器三模式菜单** | A/B/C 自己选；目标已有插件不再直接失败 |
| 3 | **配置自动套用** | `config/` 从「只读参考」升级为按条目补缺（你的条目一条不动，写前备份） |
| 4 | **服务本体包** | ReMe / OpenViking / Hindsight / WeKnora 四个本地服务一键装，不再让你自己找安装方式 |
| 5 | **macOS 通道** | `macos/install.command` + 在 Mac 上生成 payload 的脚本 + 服务安装脚本 |
| 6 | **47 份能力手册 + 索引** | 随包安装，插件按需加载，不再一次塞满上下文 |
| 7 | **6 个技能包** | 装到 `%USERPROFILE%\.dsh\skills` 与 `~/.agents/skills` |
| 8 | **体检 / 回滚 / 卸载入口** | `DOCTOR.cmd`、`ROLLBACK.cmd`、`UNINSTALL.cmd` |
| 9 | **可机读凭据** | `inventory.json`、`checksums.json`、`installation-result.json`，出问题给 agent 看就够了 |
| 10 | **6 份文档** | 说明书、新功能说明、配置参考、服务部署、AI-agent 适配、常见问题 |

逐项细节（含每个功能的边界与位置）：[`docs/新功能说明.md`](docs/新功能说明.md)。

---

## 包里到底装了什么

一个包由五部分组成：

1. **安装器**：`install.ps1`（向导、模式菜单）+ `install-helper.cjs`（对接官方插件 CLI、写依赖、合并配置、装技能、体检、回滚、卸载）。它不手写 `node_modules`，而是调用 DSH Desktop 自带的插件 CLI，把包内目录以 `link:` 方式注册进目标 profile，再逐个核对结果。
2. **插件载荷**：`payload/node_modules/` 32 个包（含 6 个本地插件实体）、`payload/skills/` 6 个技能、`payload/migration-state/` 只记录启停状态的辅助 bundle。
3. **清单与凭据**：`migration.json`（包清单）、`inventory.json`、`plugins.csv`、`bundles.csv`、`插件完整清单.txt`、`checksums.json`、`release-validation.json`。
4. **配置骨架**：`config/`（`cordis.patch.yml`、`cordis.yml`、`package.json`、`pnpm-workspace.yaml`、`feature-profiles/` 47 篇 + `always.json`）。**不含任何密钥**，中转站地址统一是占位符。
5. **文档与 macOS 通道**：`docs/`、`macos/`。

### 36 个 bundle 的功能分组

DSH 内置（4 个，随内核分发）：`@deepseek-ai/dsh-base`、`@deepseek-ai/dsh-web-app`、`@deepseek-ai/dsh-experimental-agent-team-profile`（Agent Teams）、`@deepseek-ai/dsh-experimental-auto-review`。

第三方 32 个，按用途分组：

| 功能域 | 插件 | 作用 |
|---|---|---|
| 上下文与压缩 | `billion-context`、`dsh-context`、`@kenz1117/dsh-ui-usage-billing` | 长对话压缩与可回溯摘要、上下文用量可视化 |
| 记忆与知识 | `@openviking/dsh-memory-plugin`、`@agentscope-ai/reme-dsh-plugin`、`@vectorize-io/hindsight-coding-agents`、`@lemoncat7/dsh-knowledge`、`@wxg-prc-cpg/dsh-weknora`、**`dsh-memory-fusion`**（本地） | 跨会话记忆、经验召回、知识库检索、双端检索融合 |
| 技能体系 | **`dsh-skill-fusion`**（本地）、`dsh-mattpocock-skills-deck`、`@wxg-prc-cpg/browser-skill-dsh-plugin` | 技能目录与市场、分组启停、上游更新预览、新建向导 |
| 能力调度 | **`dsh-feature-profiles`**（本地） | 47 篇能力手册按需加载 |
| 浏览器与抓取 | `dsh-ego-browser`、`@wxg-prc-cpg/browser-skill-dsh-plugin` | 驱动本机已登录浏览器（读页面、填表单、跑流程） |
| 本地模型 | **`dsh-ollama`**（本地） | Ollama 模型管理面板与单次本地推理 |
| 逆向与二进制 | **`dsh-purge`**（本地）、技能 `reverse-engineer-anything` | 逆向指挥体系；原生二进制 / ASAR / .NET 取证 |
| 创作与可视化 | `@changfenhuang/dsh-genui`、`@tt-a1i/archify-dsh`、`dsh-drawai`、`@liustack/modlens` | 对话内富组件、架构图、drawio 画布、图片理解 |
| 界面与娱乐 | `@linxin666/dsh-web-all`、`@linxin666/dsh-client-ui-git-graph`、`dsh-plugin-wallpaper-engine`、`dsh-plugin-whale-pet`、`dsh-whale-widget`、**`@local/dsh-client-ui-workbench`**（本地） | 界面增强、Git 图、壁纸引擎、桌面宠物、多场景工作台 |
| 工具与运维 | `dsh-undo-savepoint`、`dsh-rewind-plugin`、`dsh-approval-gate`、`dsh-cost-meter`、`dshmarket` | 配置快照与回滚、会话回退、审批门禁、成本计量、插件市场 |
| 外部集成 | `dsh-zotero`、`@xmanrui/dsh-im`、`treg-dsh`、`dsh-infinite-gen-5` | 本地 Zotero 文献库、IM 通道、外部数据工具集、长任务生成 |

版本号与精确条目见 `migration.json`、`bundles.csv`、`plugins.csv`。

---

## 本地记忆服务（可选包）

插件包本身不启动任何后台服务：ReMe、OpenViking、Hindsight、WeKnora 是**独立进程**，装不装都能用 DSH，只是记忆/知识库类功能会显示「未连接」。

要装：解压 `DSH-Plugins-v2.0.0-Services.zip` → 双击 `SETUP-SERVICES.cmd`。它会装独立 CPython、为每个服务现场建 venv、灌入 site-packages 快照、生成启停脚本并做健康检查。

| 服务 | 端口 | 作用 | 额外依赖 |
|---|---|---|---|
| ReMe | 2333 | 自动记忆整理 | 需要一个可用的模型 API（`setx` 四个环境变量） |
| OpenViking | 1933 | 记忆库 / 资料 / 共享技能 | 可选接 Ollama |
| Hindsight | 8888 | 项目知识页 | 无 |
| WeKnora | 8080 | 组织知识库 RAG | WSL2（Linux Go 服务） |

细节：[`docs/服务部署指南.md`](docs/服务部署指南.md)。

---

## 文档

| 文件 | 内容 |
|---|---|
| [`docs/使用说明书.md`](docs/使用说明书.md) | 从装机到日常使用的完整手册（先读这个） |
| [`docs/新功能说明.md`](docs/新功能说明.md) | v2 相对 v1 的 10 类新增，逐项讲用途与边界 |
| [`docs/配置参考.md`](docs/配置参考.md) | 配置三层结构、每个文件能不能手改、模型接入怎么填 |
| [`docs/服务部署指南.md`](docs/服务部署指南.md) | 四个本地服务的安装、启停、排障 |
| [`docs/AI-agent-适配指南.md`](docs/AI-agent-适配指南.md) | 换内核版本 / 装崩了 / 想加功能时，怎么让 agent 自己改 |
| [`docs/常见问题.md`](docs/常见问题.md) | 按症状查的故障手册 |
| [`macos/INSTALL-MAC.md`](macos/INSTALL-MAC.md) | macOS 安装路线 |
| [`CHANGELOG.md`](CHANGELOG.md) | 版本差异与已知限制 |

---

## 出问题怎么办

按这个顺序，基本都能自己解决：

1. `DOCTOR.cmd` —— 它会把内核版本、CLI 入口、依赖完整性、链接是否断、服务端口、配置条目命中数全列出来。
2. 拿对照表看症状：[`docs/常见问题.md`](docs/常见问题.md)。
3. 装坏了：`ROLLBACK.cmd` 选一个备份退回去。
4. 还是不行：把 `installation-result.json`、`DOCTOR.cmd` 输出、`%USERPROFILE%\.dsh\profiles\desktop\cordis.patch.yml` 一起丢给 DSH 里的 AI agent，让它按 [`docs/AI-agent-适配指南.md`](docs/AI-agent-适配指南.md) 处理。

---

## 已知边界（请先看一眼）

- **本地插件是 `link:` 形态**：安装时载荷会被复制到 `%LOCALAPPDATA%\DSHPluginsPack\v2.0.0-windows`，链接指向那里——所以**解压目录装完可以删**，但那个持久目录不能动，动了 6 个自研插件就失效。要彻底移除请用 `UNINSTALL.cmd`。
- **改动要重启**：改代码或改配置后需要完全退出 DSH 再打开（不是最小化）。
- **配置骨架带占位符**：不解成你自己的模型地址，只有 DSH 账号自带的那档能直接对话。
- **服务包是 Windows 构建**：macOS 用 `macos/setup-services.command` 现装。
- **内核版本换代不保证兼容**：换到 0.3.x 请先走 AI-agent 适配流程。

---

## 版本导航

| 分支目录 | 版本 | 状态 |
|---|---|---|
| `stable-v2/` | v2.0.0 | 当前推荐 |
| `stable/` | v1.0.0 | 存档，只做参考与回退 |

Release 页保留全部历史版本，Latest 指向 v2.0.0。

## 许可

MIT，见 [`LICENSE`](LICENSE)。第三方插件版权归各自作者，包内保留其原始 LICENSE 与 NOTICE；仅供个人使用，请勿用于商业倒卖。
