# DeepSeek Harness 插件整合包（配置包 · 装机盘）

给 **只装了一个 DeepSeek Harness 空壳**、别的什么都没有的机器用的一键装机盘：解压 → 双击 `INSTALL.cmd` → 选一个模式 → 装完自动启动 DSH。不用装 Node.js，不用手改 YAML。

当前版本：**v2.1.2**（Latest，整合包）· 上一版 **v2.0.0** + 补丁 **v2.0.2-patch.1** / **v2.0.1-patch.1**（两份补丁均已被 v2.1.0 吸收，旧机器仍可单独装）· 适用内核 `0.2.x` / `0.3.x`（按 `0.2.1-rc.2` 构建；门禁 `>=0.2.0 <0.4.0`，版本不同只提示不阻断）· Windows 10/11 x64，另附 macOS 通道

> **v2.1.2（2026-10-30，Latest）— 只修 bug，载荷不动**：外部用户装完 v2.1.1 后跑 `UPGRADE.cmd` / `MAINTAIN.cmd` / `VERIFY.cmd`，33 个插件**全部挂好**却仍报「✗ 安装未完成：挂载后的校验没通过：dsh-migration-plugin-state（bundle 未启用）」并以退出码 1 结束；原地修复（`--store` 指向自己所在的持久目录）还会直接死在「持久安装目录不能与解压目录重叠」。根因是收尾断言把**启停状态快照** `dsh-migration-plugin-state` 当成第 33 个插件去比 `profile.bundles` —— 它按设计不进 bundles，必然缺 1 条。v2.1.2 把它拆成独立数组、断言各看各的，顺带修掉同一段里**形同虚设的前缀过滤**（`@junyunshoure/` 早已不匹配任何包，导致校验实际上一个包都没检查）、原地 repair 被误挡、启动等待 120 秒空等、启停差异提示自相矛盾等 6 处。**插件载荷与 v2.1.1 逐文件相同**（唯一改动的载荷内文件是 `install-helper.cjs`），不需要重装，跑一次 `UPGRADE.cmd` 即可。

> **v2.1.1（2026-10-29，上一版）— 撤回载荷瘦身**：v2.1.0 为省 60 MB 删掉插件内嵌 `node_modules`，外部实测导致部分插件装完就废（侧栏「技能 / Ollama / 逆向」入口消失、点开报错），`install.ps1 -Action upgrade` 还会因 stderr 直崩。v2.1.1 把载荷口径**退回 v2.0.0 的完整复制**（23,172 文件 / 503.24 MB，与 v2.0.0 逐文件比对缺 0，只跳 `.git`/`.vite`/`.cache` 325 文件），同时修掉 stderr 崩溃、改成**不再覆盖你的模型/外观配置**、macOS 也能写入对齐协议，并新增「载荷依赖闭包」安装期断言。安装包回到约 182.5 MB —— 用体积换「装了就一定能跑」。
>
> **v2.1.0（2026-10-29）**：把两份补丁的修复**收进主包并变成默认行为**，同时瘦身 36.6%。新增 `UPGRADE.cmd`（D 升级：整包换版本后一条命令把 6 个自研插件重新指到新载荷，不必卸载重装）、`INSTALL` 菜单多出 D 升级 / E 修复、`MAINTAIN.cmd`（8 步环境体检与自愈）、`PRUNE.cmd`（清理 7 天前的旧载荷）、`appendix/AGENTS.appendix.md`（对齐提问协议改为可替换的标记块，不叠加）、`templates/workbench-toolkit/`（场景记忆 7 文件，只放模板不自动写）。载荷 502.41 MB → 318.45 MB、23,071 → 10,670 个文件，安装包 182.5 MB → 120.65 MB，装得更快、校验更快（10,761 个文件 3 秒）。**装完即生效**：安装/升级/修复会自动把「对齐提问协议 + 深度档位」写进 `~/.dsh/AGENTS.md`（替换式标记块、保留你改过的档位值），并顺手做与数据无关的安全清理 —— 不需要再手动跑 `MAINTAIN.cmd`。
>
> **补丁 v2.0.2-patch.1（2026-10-29）**：环境自愈——CL-001…CL-007 七条改动做成可反复运行的小工具（日志轮转、废包残留清理、临时文件清理、巨日志体检、记忆服务环境变量核验）。**已全部并入 v2.1.0 的 `MAINTAIN.cmd`**，新机器不用单独装。
>
> **补丁 v2.0.1-patch.1（2026-10-29）**：对齐提问协议 ALIGNMENT_PROTOCOL v1.0。**已并入 v2.1.0 的 `appendix/AGENTS.appendix.md`**（安装/升级/修复**装完自动写入**，替换式标记块不会叠加；`maintain.ps1` 第 3 步已改为转发同一实现，也可用 `install.ps1 -Action appendix` 单独重写）。

---

## 下载哪个

| 文件 | 用途 | 大小 |
|---|---|---|
| `DSH-Plugins-v2.1.2-Windows-x64.zip` | **插件包（必装，Latest）**：32 个插件 + 6 个技能 + 配置骨架 + 安装器 + 维护引擎 + 文档（**完整载荷，不裁剪**） | 约 182.22 MB |
| `DSH-Plugins-v2.0.0-Services.zip` | 服务本体包（可选）：ReMe / OpenViking / Hindsight / WeKnora 四个本地服务（v2.1.0 未重出，继续用这一份） | 约 680 MB |

只装插件包，DSH 一切正常，只是本地记忆/知识库入口显示「未连接」；要那四个能力再装服务包。两个包各自独立，互不依赖。

到 [Releases](../../releases/latest) 下这两个文件，同页附 `.sha256`。GitHub 自动生成的 Source code 压缩包不含插件载荷，**不能用来安装**。

**从 v2.0.0 升上来**：解压新包 → 双击 `UPGRADE.cmd`（等价 `INSTALL.cmd` 选 D）。它会读你现有 profile 里的 6 条 `link:`，逐个重指向新载荷并核对，全程离线、不动你的配置与技能历史。

**从 v2.1.1 升上来**：解压新包 → 跑 `UPGRADE.cmd` 就行。本次只改安装器收尾校验，载荷没动，升级是 33 个包重指向 + 几秒核对，不碰你的配置与技能历史。**注意**：升级完成后若再看到「bundle 未启用」字样，说明你手上的包还是 v2.1.1。

**从 v2.1.0 升上来**：一样跑 `UPGRADE.cmd`。v2.1.0 的载荷被裁过（部分插件缺依赖），v2.1.1 已恢复 v2.0.0 的完整载荷，升级后那些消失的入口会回来。

---

## 三分钟装完

1. 把 `DSH-Plugins-v2.1.2-Windows-x64.zip` **完整解压**到短路径，例如 `D:\DSH-Plugins-v2.1.2`（别在压缩包里双击，别放带空格/中文的长路径）。
2. 双击 `INSTALL.cmd`，选模式：

   | 模式 | 什么时候选 | 行为 |
   |---|---|---|
   | **A 全新安装** | 机器上没装过第三方插件 | 目标 profile 必须干净，否则中止（最安全） |
   | **B 智能合并**（默认） | 已装了一些插件 | 只补缺的，已有版本与配置一律不动 |
   | **C 备份覆盖** | 想用本包版本统一覆盖 | 先整份备份，再覆盖 |
   | **D 升级** | 机器上装的是旧版整合包 | 读现有 `link:` → 备份 → 逐个重指向新载荷 → 核对 realpath → 报告差异 |
   | **E 修复** | 插件在某次升级后「消失」了 | 同 D，但不新增任何未声明的依赖 |

3. 等它跑完：校验 23,263 个文件 → 复制载荷到 `%LOCALAPPDATA%\DSHPluginsPack\v2.1.2-windows` → 备份 → 挂 32 个插件 + 1 个状态包 → 校验 256 个条目 → 合并配置 → 装技能 → 装能力手册 → 出安装结果 → 启动 DSH。
4. **唯一需要手填的东西**：打开 DSH → 设置 → 模型，把 provider 的 `baseURL` 从 `https://YOUR-ENDPOINT.example.com` 换成你自己的中转站/官方地址并填密钥。填法见 [`stable-v2/docs/配置参考.md`](stable-v2/docs/配置参考.md)。
5. **对齐协议与深度档位已自动写好**：安装器会打印「对齐协议：已写入 `~/.dsh/AGENTS.md`（127 行，新会话生效）」。新开一个 DSH 会话即生效 —— v2.1.0 起**不需要再跑 `MAINTAIN.cmd`**；默认档是 `ask`，想换直接改 `AGENTS.md` 里 `## DEPTH_MODE:` 那一行（`ask` / `auto` / `deep` / `fast`），下次安装也不会覆盖你的选择。
6. 确认没毛病：`VERIFY.cmd`（逐文件哈希）+ `DOCTOR.cmd`（环境体检）。之后想体检/自愈就用 `MAINTAIN.cmd`，想清旧载荷用 `PRUNE.cmd`。

---

## 补丁（不重装整包）

补丁是给**已经装好 v2.0.0** 的机器打的小更新，16–20 KB 级别，不碰插件载荷、不改配置骨架。**两份补丁的修复已全部并入 v2.1.0**，只有在你暂时不想换整包时才需要单独装。

### v2.0.2-patch.1 — 环境自愈（2026-10-29，已被 v2.1.0 吸收）

把 `docs/改动日志.md` 里手工做过的七条改动固化成**可反复运行、幂等、带备份**的小工具。装完不用记命令，随时体检随时修：

| 编号 | 修什么 | 默认行为 |
|---|---|---|
| CL-001 | ReMe 日志轮转 `rotation="00:00"`（每天一个文件、永不删） | 改成 `100 MB`，保留 `retention="7 days"` 与 `compression="zip"` |
| CL-002/003 | `node_modules` 里的废包残留（dsh-skill-hub / dsh-my-skill-manager / web-ui-skill-explorer） | 只删**0 个文件**的目录；有内容的一律保留并报告 |
| CL-004 | profile 里声明了但空着的插件目录 | 报告（空目录自动补建回来，`-RepairEmpty`） |
| CL-005 | `feature-profiles/*.tmp` 临时文件 | 直接清 |
| CL-006 | 巨型日志（默认 >100 MB、且 PID 已死） | 只报告；`-PurgeLogs` 才删，活着的日志绝不动 |
| CL-007 | ReMe 记忆大模型的四个 `LLM_*` 用户环境变量 | 只核验在不在；补写要求三值齐全，密钥不进包、不进报告、不进日志 |

- 包：`patch/v2.0.2-patch.1/DSH-Plugins-v2.0.2-patch.1.zip`（含 `.sha256`）
- 装：解压 → `CHECK.cmd`（只预演，一个字节都不写）→ `APPLY.cmd`（校验 8 个文件哈希 → 备份 → 执行 → 写报告）→ 按提示重启 DSH
- 只做一件事：`apply.ps1 -CheckOnly` 出「会改什么」清单；`-PurgeLogs` 清巨日志；`-PurgeDeprecated` 强删残留；`-RepairEmpty` 补建空目录；`-Rollback` 回滚上一次
- 撤：`ROLLBACK.cmd`（按备份集还原文件；只清掉临时文件这种可再生的东西不备份）
- macOS/Linux：`bash apply.command`（`--check` / `--rollback`）
- 报告：`%LOCALAPPDATA%\DSHPluginMigration\maintenance-20261029\`（含 `maintenance-report.json`、每次运行明细、`user-env-before.json`）
- 自检结果：`patch/v2.0.2-patch.1/release-validation.json`（11 项，含幂等、回滚、篡改拒绝、真机实测）

安全边界写死三条：**只删 0 文件目录**、**活进程的日志不删**、**密钥不落盘**。不确定性全部走「报告 + 需显式开关」。

### v2.0.1-patch.1 — 对齐提问协议（2026-10-29）

给 DSH 里的 AI agent 装一条硬规则：**每次任务动手前，先按任务难度和广度生成若干个对齐问题（0 到 50 个，看任务多大），把方案对齐，再执行。**

| 任务类型 | 装之前 | 装之后 |
|---|---|---|
| 查命令、读配置 | 直接答 | 直接答（白名单，不打扰） |
| 改一个文件、写一份文档 | 直接做 | 先问 3–6 条（每条带推荐值） |
| 跨模块 / 代码+文档+配置 | 边做边问 | 先问 8–15 条，对齐后动手 |
| 发版 / 动全局环境 / 删数据 | 直接做 | 先问 15–30 条（最多 50），含验收与回滚 |

另外：**执行参数（深度档位）必须单独用交互卡片提问**，不许混进长清单。

- 包：`patch/v2.0.1-patch.1/DSH-Plugins-v2.0.1-patch.1.zip`（含 `.sha256`）
- 装：解压 → `CHECK.cmd`（只预演）→ `APPLY.cmd`（校验 9 个文件哈希 → 备份 → 写入 → 回读验证）→ 重启 DSH
- 落点：`%USERPROFILE%\.dsh\AGENTS.md` 的标记块，从不整份覆盖你自己的指令
- 撤：`UNINSTALL.cmd`（只删标记块）；或把备份的 `AGENTS.md` 覆盖回去
- macOS/Linux：`bash apply.command`（`--check` / `--uninstall`）
- 规则全文与逐条解释：`patch/v2.0.1-patch.1/DSH-Plugins-v2.0.1-patch.1/ALIGNMENT-PROTOCOL.md`、`docs/对齐提问协议.md`
- 自检结果：`patch/v2.0.1-patch.1/release-validation.json`（8 项，含幂等与卸载实测）

补丁与整包的关系：整包 v2.0.0 是 2026-10-28 打的，**不含**本补丁；装完整包再跑一次 `APPLY.cmd` 即可，重复运行幂等。

---

## v2.1.0 新增了什么（相对 v2.0.0）

| # | 新增 | 一句话 |
|---|---|---|
| 1 | **D 升级 / E 修复** | `UPGRADE.cmd` 与 `INSTALL.cmd` 的 D/E：读现有 `link:` → 备份 → 逐个重指向新载荷 → 按 realpath 核对 → 报告差异。整包换版本不再需要卸载重装 |
| 2 | **维护引擎 `MAINTAIN.cmd`** | 把 v2.0.2-patch.1 的 CL-001…CL-007 收进主包，8 步幂等自愈（含 `-Rollback`），装完不用记命令 |
| 3 | **`PRUNE.cmd` 旧载荷清理** | 默认只预演：保留 7 天内、仍被 `link:` 引用的目录永不删 |
| 4 | **对齐提问协议改为标记块** | `appendix/AGENTS.appendix.md` 由 MAINTAIN 以 START/END 标记块替换写入，重复运行不会叠加第二份 |
| 5 | **场景记忆模板** | `templates/workbench-toolkit/`（7 文件）随包分发，**只放模板不自动写**你机器上的 `workbench/memory` |
| 6 | **瘦身 36.6%** | 载荷 502.41 MB → 318.45 MB、23,071 → 10,670 文件；安装包 182.5 MB → 120.65 MB |
| 7 | **载荷按运行依赖面裁剪** | `dsh-skill-fusion` 91.8 MB → 3.0 MB（只带 `js-yaml`，`@deepseek-ai/*` 由内核提供），实测加载结果与原始版逐字段一致 |
| 8 | **内核门禁放宽为二选** | `>=0.2.0 <0.4.0`：0.2.x / 0.3.x 都放行，与本包基准不同只提示不阻断（原为硬拦） |
| 9 | **离线优先** | 挂载插件三级回退（`--offline` → `--offline --config.lockfile=false` → 只告警继续），默认不联网；要联网须显式 `--allow-network` |
| 10 | **`--skills-root`** | 技能可以装到隔离目录，演练与多环境不再互相踩 |
| 11 | **文档补齐** | 9 个入口、8 篇文档，新增「升级 / 修复 / 维护 / 清理」四节与 5 条 v2.1.0 专属 FAQ |

逐项细节与边界：[`stable-v2/docs/新功能说明.md`](stable-v2/docs/新功能说明.md)。完整变更见 [`stable-v2/CHANGELOG.md`](stable-v2/CHANGELOG.md)。

## v2.0.0 新增了什么（相对 v1.0.0）

| # | 新增 | 一句话 |
|---|---|---|
| 1 | **6 个本机自研插件** | 功能档位 `dsh-feature-profiles`、记忆融合 `dsh-memory-fusion`、技能融合中心 `dsh-skill-fusion`、Ollama 面板 `dsh-ollama`、逆向指挥 `dsh-purge`、多场景工作台 |
| 2 | **安装器三模式菜单** | A/B/C 自己选；目标已有插件不再直接失败 |
| 3 | **配置自动套用** | `config/` 从 v1 的「只读参考」升级为按条目补缺（你的条目一条不动，写前备份） |
| 4 | **服务本体包** | 四个本地记忆/知识库服务一键装，不再让你自己找安装方式 |
| 5 | **macOS 通道** | `macos/install.command` + 在 Mac 上生成载荷的脚本 + 服务安装脚本 |
| 6 | **47 篇能力手册 + 索引** | 随包安装，插件按需加载，不再一次塞满上下文 |
| 7 | **6 个技能包** | 装到 `%USERPROFILE%\.dsh\skills` 与 `~/.agents/skills` |
| 8 | **体检 / 回滚 / 卸载入口** | `DOCTOR.cmd`、`ROLLBACK.cmd`、`UNINSTALL.cmd` |
| 9 | **可机读凭据** | `inventory.json`、`checksums.json`、`installation-result.json`、`release-validation.json`，出问题给 agent 看就够 |
| 10 | **6 份中文文档** | 使用说明书、新功能说明、配置参考、服务部署、AI-agent 适配、常见问题 |

---

## 仓库结构

```
├── stable-v2/          ← v2.1.2 当前版本（源码/清单/安装器/维护引擎/文档，不含插件载荷）
├── stable/             ← v1.0.0 存档（不再变动，仅供回退与对照）
├── patch/              ← 补丁：v2.0.2-patch.1（环境自愈，已并入 v2.1.0）/ v2.0.1-patch.1（对齐提问协议，已并入 v2.1.0）/ v1.0.0-patch.1 存档
├── demo/               ← v0.1.0-demo.1 存档
├── README.md           ← 本文件
├── RELEASE_NOTES.md    ← 当前版本发布说明
├── release-validation.json  ← 发布前自检结果（v2.1.2 为 19 项，含 v2.1.2 防回退断言）
└── LICENSE
```

`stable-v2/` 里有什么：`install.ps1` + `install-helper.cjs` + `maintain.ps1`（安装器与维护引擎）、`9 个入口 .cmd`、`migration.json` / `inventory.json`（schema v3）/ `checksums.json` / `release-validation.json`（清单与凭据）、`config/`（配置骨架 + 47 篇能力手册 + `always.json` + `_index.md`）、`docs/`（6 份文档）、`appendix/`、`templates/workbench-toolkit/`、`macos/`、`README.md`、`CHANGELOG.md`。插件载荷（`payload/`，318.79 MB）不打进仓库，只随 Release 压缩包分发。

---

## 文档导航

| 文件 | 内容 |
|---|---|
| [`stable-v2/docs/使用说明书.md`](stable-v2/docs/使用说明书.md) | 从装机到升级、修复、维护、清理的完整手册（先读这个） |
| [`stable-v2/docs/新功能说明.md`](stable-v2/docs/新功能说明.md) | v2.1.0 的 11 条新增，逐项讲用途、边界与关闭办法 |
| [`stable-v2/docs/配置参考.md`](stable-v2/docs/配置参考.md) | 配置三层结构、每个文件能不能手改、模型接入怎么填、内核门禁 |
| [`stable-v2/docs/服务部署指南.md`](stable-v2/docs/服务部署指南.md) | 四个本地服务的安装、启停、排障 |
| [`stable-v2/docs/AI-agent-适配指南.md`](stable-v2/docs/AI-agent-适配指南.md) | 换内核版本 / 装崩了 / 想加功能时，怎么让 agent 自己改 |
| [`stable-v2/docs/常见问题.md`](stable-v2/docs/常见问题.md) | 按症状查的故障手册（含 v2.1.0 专属 5 条） |
| [`stable-v2/appendix/AGENTS.appendix.md`](stable-v2/appendix/AGENTS.appendix.md) | 对齐提问协议全文（由 `MAINTAIN.cmd` 写入你的 `AGENTS.md`） |
| [`stable-v2/templates/workbench-toolkit/README.md`](stable-v2/templates/workbench-toolkit/README.md) | 场景记忆工具箱 7 文件怎么拷、怎么验收 |
| [`stable-v2/macos/INSTALL-MAC.md`](stable-v2/macos/INSTALL-MAC.md) | macOS 安装路线 |
| [`stable-v2/CHANGELOG.md`](stable-v2/CHANGELOG.md) | 版本差异与已知限制 |

---

## 出问题怎么办

1. `DOCTOR.cmd` —— 内核版本、CLI 入口、依赖完整性、链接是否断、服务端口、配置条目命中数全列出来。
2. 插件在升级后「消失」了：多半是 `link:` 指向了已被清掉的旧载荷。跑 `DOCTOR.cmd` 看 link 断链，再 `UPGRADE.cmd`（或 `INSTALL.cmd` 选 E 修复）。
3. 按症状查 [`stable-v2/docs/常见问题.md`](stable-v2/docs/常见问题.md)。
4. 装坏了：`ROLLBACK.cmd` 选一个备份退回去。
5. 还不行：把 `installation-result.json`、`DOCTOR.cmd` 输出、`%USERPROFILE%\.dsh\profiles\desktop\cordis.patch.yml` 一起丢给 DSH 里的 AI agent，让它按 [`stable-v2/docs/AI-agent-适配指南.md`](stable-v2/docs/AI-agent-适配指南.md) 处理。

## 已知边界

- **本地插件是 `link:` 形态**：载荷会被复制到 `%LOCALAPPDATA%\DSHPluginsPack\v2.1.2-windows`，链接指向那里——解压目录装完可以删，但那个持久目录不能动。彻底移除请用 `UNINSTALL.cmd`；清旧版本载荷用 `PRUNE.cmd`（默认只预演）。
- **旧载荷不自动删**：升级后旧版本目录会留着（默认保留 7 天），方便回滚；确认没问题再 `PRUNE.cmd`。
- **改动要重启**：改代码或改配置后需完全退出 DSH 再打开。
- **配置骨架带占位符**：不换成你自己的模型地址，只有 DSH 账号自带那档能直接对话。
- **服务包是 Windows 构建**：macOS 用 `macos/setup-services.command` 现装。
- **内核换代只提示不拦**：门禁 `>=0.2.0 <0.4.0`，0.3.x 可用但属「未验证组合」，换到 0.4+ 才会拒绝。换版本先走 AI-agent 适配流程。

## 许可

MIT，见 [`LICENSE`](LICENSE)。第三方插件版权归各自作者，包内保留其原始 LICENSE 与 NOTICE；仅供个人使用，请勿用于商业倒卖。
