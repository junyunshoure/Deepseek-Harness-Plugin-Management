# 补丁 v2.0.2-patch.1 — 环境自愈（CL-001 … CL-007）

**版本类型**：补丁（Latest）· **发布日**：2026-10-29 · **基线**：v2.0.0（可与 v2.0.1-patch.1 并存）· **体积**：20.1 KB

把 `docs/改动日志.md` 里七条手工改动（CL-001…CL-007）固化成**幂等、可回滚、可重复运行**的小工具。不重打整包，不碰插件载荷与配置骨架。

## 附件

| 文件 | 内容 | SHA-256 |
|---|---|---|
| `DSH-Plugins-v2.0.2-patch.1.zip` | 补丁包：安装器 + 七条修复 + 中文文档 | `bdd3ec636c4ab0b60ce52c15b584fa0ef9cd399025a7e59b19082507bd22398a` |

仓库内另存解压后的源码树与 `release-validation.json`：`patch/v2.0.2-patch.1/`。

## 修什么

| 编号 | 问题 | 补丁行为 |
|---|---|---|
| CL-001 | ReMe `logger_utils.py` 用 `rotation="00:00"`，每天一个文件且永不删除，日志无限膨胀 | 改为 `rotation="100 MB"`；`retention="7 days"`、`compression="zip"` 原样保留；已改过则跳过 |
| CL-002 | `node_modules` 里残留旧插件包目录（dsh-skill-hub / dsh-my-skill-manager / web-ui-skill-explorer） | 只删**0 文件**的空壳目录；有内容的目录保留并报告 |
| CL-003 | 上述残留若仍被 `dependencies` 引用，会变成断链 | 从 profile 的 `package.json` 里剥掉对应引用（先备份，改写后仍是合法 JSON） |
| CL-004 | profile 里声明了但空的插件目录 | 检出并报告；`-RepairEmpty` 补建空目录 |
| CL-005 | `feature-profiles/` 下的 `*.tmp` 临时文件 | 直接清理 |
| CL-006 | 巨型日志（默认 >100 MB，且写入进程 PID 已死） | 默认只报告；`-PurgeLogs` 才删；PID 仍活着的日志一律不动 |
| CL-007 | ReMe 记忆大模型需要的四个 `LLM_*` 用户环境变量 | 只核验存在性；补写要求 `-LlmBackend/-LlmModel/-LlmBaseUrl/-LlmApiKey` 四值齐全，**密钥永不入包、不入报告、不入日志** |

## 装（3 步）

1. 解压到固定目录（例如 `D:\dsh-patch\`）。
2. `CHECK.cmd` —— 只校验 + 预演，**一个字节都不写**（连备份目录都不建）。
3. `APPLY.cmd` —— SHA-256 校验 8 个文件 → 建回滚集（备份）→ 逐条执行 → 写 `maintenance-report.json`。

装完按提示重启 DSH（CL-001 / CL-007 需重启 DSH 与 ReMe 生效）。macOS/Linux：`bash apply.command`（`--check` / `--rollback`）。

## 开关

| 开关 | 作用 |
|---|---|
| `-CheckOnly` | 只预演，出「会改什么」清单 |
| `-PurgeDeprecated` | 强删有内容的旧插件残留目录（默认保留） |
| `-PurgeLogs` | 删除 PID 已死且超阈值的日志（默认只报告） |
| `-LogSizeMB <n>` | 巨日志阈值，默认 100 |
| `-RepairEmpty` | 补建 CL-004 检测到的空插件目录 |
| `-Rollback` | 按最近一次回滚集还原 |
| `-LlmBackend/-LlmModel/-LlmBaseUrl/-LlmApiKey` | 补写 CL-007 环境变量（四值齐全才写，只写用户级） |

## 安全边界（写死在实现里）

1. **只删 0 文件目录**——任何有内容的目录都不删，只报告。
2. **活进程的日志不删**——PID 存活即跳过。
3. **密钥不落盘**——CL-007 只从参数或交互提示取值，报告里只记录「已设置 / 缺失」。
4. **每次写盘前先备份**，`-Rollback` 一次还原；`-CheckOnly` 全程零写入。

## 验证（11 项，全部实测）

| # | 项 | 结果 |
|---|---|---|
| T1 | 包内 8 个文件 SHA-256 自校验 | 通过；篡改任一文件即 `checksum mismatch` 中止 |
| T2 | `-CheckOnly` 不写盘 | 通过（fixture 树哈希前后一致，备份目录未创建） |
| T3 | CL-001 轮转改写 | 通过（`00:00` → `100 MB`，retention/compression 未动，原文件在备份里） |
| T4 | CL-002/003 残留清理 | 通过（0 文件目录删、有内容目录留、`package.json` 引用剥离后仍合法） |
| T5 | CL-004 空插件目录 | 通过（检出并报告） |
| T6 | 重复运行幂等 | 通过（树哈希不变、轮转只出现一次、第二次报 skip） |
| T7 | CL-006 门控 | 通过（死 PID 大日志报告 → `-PurgeLogs` 才删；活 PID 日志两次都保留） |
| T8 | 回滚 | 通过（`logger_utils.py`、`package.json` 逐字节还原，被删空目录按需补建） |
| T9 | `bash -n apply.command` | 通过（exit 0） |
| T10 | 本机实跑 | 通过（CL-001 已是 100 MB → skip；`dsh-shared` 32 文件 → 保留；无 tmp、无巨日志、四个 `LLM_*` 全在；零写入，故不建备份） |
| T11 | Release zip 解压后端到端 | 通过（8/8 校验、预演、执行走通，单字节篡改被拒） |

## 回滚

`ROLLBACK.cmd`（= `apply.ps1 -Rollback`）按 `%LOCALAPPDATA%\DSHPluginMigration\maintenance-20261029\` 下的回滚集还原 `logger_utils.py`、各 profile 的 `package.json`，并补建被删的空目录。可反复装卸。

## 已知边界

- CL-001 改的是 `site-packages` 里的文件，**ReMe 升级会覆盖**，升级后重跑 `APPLY.cmd` 即可。
- CL-007 只处理用户级环境变量；`Machine` 级与 macOS/Linux 的 shell profile 只报告并打印 `export` 行。
- `apply.command`（macOS/Linux）不自动剥离 `package.json` 里的废弃引用，只警告并指明要删的行。
- 本补丁是「把改动日志变成可执行清单」的第一步；v2.1.0 整包会把同一引擎折进 `install.ps1`（安装/升级/修复三条路径），届时补丁自动被整包吸收。

---

# 补丁 v2.0.1-patch.1 — 对齐提问协议（ALIGNMENT_PROTOCOL v1.0）

**版本类型**：补丁（Latest）· **发布日**：2026-10-29 · **基线**：v2.0.0 · **体积**：16.4 KB

只做一件事：**让 agent 在每次任务动手前，先按任务难度和广度提出若干条对齐问题，把方案对齐再执行。**

不重打整包，不碰插件载荷与配置骨架；只往 `%USERPROFILE%\.dsh\AGENTS.md` 追加一个带标记的规则块。

## 附件

| 文件 | 内容 | SHA-256 |
|---|---|---|
| `DSH-Plugins-v2.0.1-patch.1.zip` | 补丁包：安装器 + 规则全文 + 逐条解释文档 | `2dedef50058d0964b9b5187bf5dd3ea28150bacf013ab8edec85c12b5283c6d2` |

仓库内另存解压后的源码树与 `release-validation.json`：`patch/v2.0.1-patch.1/`。

## 装（3 步）

1. 解压到固定目录（例如 `D:\dsh-patch\`）。
2. `CHECK.cmd` —— 只校验 + 预演，不改任何文件。
3. `APPLY.cmd` —— SHA-256 校验 9 个文件 → 备份现有 `AGENTS.md` → 写入/替换标记块 → 回读验证 → 写 `patch-result.json`。

装完**开新会话**生效（全局指令按会话读取）。macOS/Linux：`bash apply.command`。

## 规则要点

1. **难度四档**：D0 微改 0–2 问 / D1 常规 3–6 问 / D2 跨面 8–15 问 / D3 不可逆 15–30 问（最多 50）；取最高项。
2. **每问三件**：问题本身 + 推荐默认值 + 一句取舍；末尾给「回『全部按推荐』即开工」。
3. **执行参数（深度档位）单独提问，必须用交互卡片**，不许混进长清单；方案问题超过 4 条一律走文字编号清单。
4. **不触发白名单**：只读查询、单条命令、已锁定方案、说「直接做/别问」、紧急排障中的止血动作、已被上级对齐的子任务。
5. **与 `DEPTH_MODE` 合并成固定两步**：先卡片定档，再按档位决定出不出清单，避免开场问两遍。
6. **收尾给对齐回执**：按推荐项 / 被改单项 / 实测证据 / 未验证遗留项 / 回滚路径。
7. **子代理继承**：派 subagent / teammate 时 brief 里写明档位与已对齐结论。

## 验证（8 项，全部实测）

| # | 项 | 结果 |
|---|---|---|
| T1 | 包内 9 个文件 SHA-256 自校验 | 通过 |
| T2 | `-CheckOnly` 不写盘 | 通过（目标前后 13 字符不变） |
| T3 | 追加到已有内容的 `AGENTS.md` | 通过（13 → 2613 字符，用户原有行保留） |
| T4 | 重复运行幂等 | 通过（第二次运行后字节相同，标记数 = 1） |
| T5 | 卸载只删标记块 | 通过（标记消失、用户内容完整、卸载前有备份） |
| T6 | Release zip 解压后端到端安装 | 通过 |
| T7 | `bash -n apply.command` | 通过（exit 0） |
| T8 | 本机实际安装 | 通过（668 → 3269 字符，`DEPTH_MODE` 段完整保留） |

## 回滚

`UNINSTALL.cmd`（只删标记块），或把 `%LOCALAPPDATA%\DSHPluginMigration\align-protocol-20261029\backup-<时间戳>\AGENTS.md` 覆盖回去。备份在每次安装/卸载前自动生成，可反复装卸。

## 已知边界

- 生效需要**新会话**；旧会话不会热更新。
- 补丁只写全局 `AGENTS.md`；用 `-Target` 可改装到某个项目的 `AGENTS.md`，默认不改。
- 规则靠模型遵守，没有运行时强制层：模型忽略规则时不会报错，只能靠回执里「有没有先提问」自查。

---

# DeepSeek Harness 插件整合包 v2.0.0（Windows x64）

**版本类型**：大版本（Latest）· **发布日**：2026-10-28 · **适用内核**：DSH `0.2.x`（按 `0.2.1-rc.2` 构建）

从「照着 v1 手动搬配置」升级为「空壳机器双击装完就能用」。v1.0.0 的三个 Release 全部保留，Latest 改指本版本；仓库里 `stable/` 是 v1 存档，`stable-v2/` 是当前版本。

## 附件

| 文件 | 内容 | SHA-256 |
|---|---|---|
| `DSH-Plugins-v2.0.0-Windows-x64.zip` | **插件包（必装）**：32 个插件 + 6 个技能 + 配置骨架 + 安装器 + 6 份文档 | `58af4c08ec27ca65540eef503bc970da45a63f11e26e71b6234b029a87a7937d` |
| `DSH-Plugins-v2.0.0-Services.zip` | 服务本体包（可选）：ReMe / OpenViking / Hindsight / WeKnora 的可移植运行时 | `106fce67b33b3c9548132839e1c1ad1972cb76dcddf5379251616c307f2397a6` |

两个包各自独立：只装插件包，DSH 一切正常，仅本地记忆/知识库入口显示「未连接」。

## 安装

解压到短路径（如 `D:\DSH-Plugins-v2.0.0`）→ 双击 `INSTALL.cmd` → 选 A（干净机器）/ B（智能合并，默认）/ C（备份覆盖）→ 装完自动启动 DSH → 在 设置 → 模型 里把 `baseURL` 从 `https://YOUR-ENDPOINT.example.com` 换成你自己的地址并填密钥。

完整步骤与排障见包内 `docs/使用说明书.md`；服务包见 `docs/服务部署指南.md`。

## 这个版本做了什么

1. **6 个本机自研插件入包**：`dsh-feature-profiles` 0.1.0（47 篇能力手册按需加载）、`dsh-memory-fusion` 1.0.0（ReMe + OpenViking 双端检索融合）、`dsh-skill-fusion` 1.0.2（技能融合中心，替换旧 Skill Hub / My Skill Manager / Skill Explorer）、`dsh-ollama` 0.1.0（本地模型面板）、`dsh-purge` 3.0.0（逆向指挥体系）、`@local/dsh-client-ui-workbench` 0.1.0（多场景工作台）。
2. **安装器重写（v2）**：A/B/C 三模式、18 类内核错误归类、条目级 YAML 合并（只补缺、写前备份）、256 个条目组合校验、安装结束自动启动 DSH 并核验，结果写 `installation-result.json`。
3. **配置自动套用**：`config/` 从「只读参考」升级为按条目补缺；`cordis.patch.yml` 里 9 处中转站地址统一为占位符，包内不含任何密钥。
4. **服务本体包**：独立 CPython + site-packages 快照 + 启动器，现场建 venv，四个服务一键装（`SETUP-SERVICES.cmd`），含健康检查与启停脚本。
5. **macOS 通道**：`macos/install.command`（网络安装 + 本地源码链接）、`build-payload-on-mac.command`（在 Mac 上生成等价载荷）、`setup-services.command`、`INSTALL-MAC.md`。
6. **47 篇能力手册 + 索引 + `always.json`**：随配置复制到 `%USERPROFILE%\.dsh\profiles\desktop\feature-profiles`。
7. **6 个技能包**：`dsh` 与 `agents` 两档，装到 `%USERPROFILE%\.dsh\skills` / `~/.agents/skills`，已存在的先备份。
8. **体检 / 回滚 / 卸载**：`DOCTOR.cmd`（内核、CLI、依赖、断链、端口、条目命中）、`ROLLBACK.cmd`（按备份回退）、`UNINSTALL.cmd`（撤链接并清理）。
9. **可机读凭据**：`inventory.json`（256 条目 / 32 包 / 6 技能 / 47 手册）、`checksums.json`（23,249 文件逐文件 SHA-256）、`release-validation.json`（14 项自检全过）。
10. **6 份中文文档**：使用说明书（435 行）、新功能说明、配置参考、服务部署指南、AI-agent 适配指南、常见问题。

## 与 v1.0.0 的关系

- 旧 Release（`v0.1.0-demo.1` / `v1.0.0` / `v1.0.0-patch.1`）全部保留，可随时回退。
- 仓库新增 `stable-v2/`，`stable/` 与 `patch/` 原样存档；根 README 已换成 v2 版并附版本导航。
- `patch/`（逆向能力按需加载）在 v2 里由 `dsh-purge` 插件接管，无需再打补丁。

## 已知限制

- 包按 `0.2.1-rc.2` 构建；内核换代（0.3.x）需按 `docs/AI-agent-适配指南.md` 重新核对 CLI 入口与条目命中。
- 6 个本地插件是 `link:` 安装，指向 `%LOCALAPPDATA%\DSHPluginsPack\v2.0.0-windows`，该目录不可删。
- 服务包只含 Windows 构建；macOS 用 `setup-services.command` 现场安装。
- 未做截图与第二台物理机 GUI 验收；本版本验证方式是打包前自检 14/14 + 逐文件哈希 + 既有环境的 `DOCTOR` 对照。

## 文档

包内 `docs/`：使用说明书 / 新功能说明 / 配置参考 / 服务部署指南 / AI-agent 适配指南 / 常见问题。仓库内可直接读：[`stable-v2/docs/`](https://github.com/junyunshoure/Deepseek-Harness-Plugin-Management/tree/main/stable-v2/docs)。
