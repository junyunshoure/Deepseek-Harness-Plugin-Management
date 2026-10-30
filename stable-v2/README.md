# DSH 插件整合包 v2.1.3

给「只装了一个 DeepSeek Harness 空壳，别的什么都没有」的机器用的一键装机盘；也给已经装过 v2.0.x 的人**直接升级**用。
解压 → 双击 `INSTALL.cmd` → 选一个模式 → 装完自动启动。不需要装 Node.js，不需要手改任何 YAML。

- **适用内核**：DeepSeek Harness `0.2.x` / `0.3.x`（本包按 `0.2.1-rc.2` 构建；门禁 `>=0.2.0 <0.4.0`，版本不同**只提示不阻断**）
- **适用平台**：Windows 10/11 x64；macOS 见 [`macos/INSTALL-MAC.md`](macos/INSTALL-MAC.md)
- **包内规模**：32 个插件包（26 个来自 npm + 6 个本机自研）· 36 个 bundle · 256 个插件条目 · 6 个技能 · 48 份能力手册 · **23,265 个文件 · payload 503.24 MB**
- **服务包**：`DSH-Plugins-v2.1.3-Services.zip`（本地记忆/知识库服务本体，可选）—— **v2.1.3 起随插件包一起重出**，两包版本号同步为 2.1.3（v2.1.0 / v2.1.1 / v2.1.2 曾沿用 v2.0.0 的那一份）

> 一个版本一个目录：`stable-v2/` 是当前版本，`stable/` 是 v1.0.0 存档（内容不再变动，仅供回退与对照）。

---

## 三分钟装完

1. 把 `DSH-Plugins-v2.1.3-Windows-x64.zip` **完整解压**到一个短路径，例如 `D:\DSH-Plugins-v2.1.3`（不要直接在压缩包里双击，也不要放在带空格和中文的长路径里）。
2. 双击 `INSTALL.cmd`（或右键 `install.ps1` → 用 PowerShell 运行）。
3. 按提示选模式：

   | 模式 | 什么时候选 | 行为 |
   |---|---|---|
   | **A 全新安装** | 机器上还没装过第三方插件 | 目标 profile 必须是干净的，否则中止（最安全） |
   | **B 智能合并**（默认，回车即用） | 已经装了一些插件 | 只补缺的，你已有的版本与配置一律不动 |
   | **C 备份覆盖** | 想用本包版本统一覆盖 | 先整份备份，再用本包版本覆盖同名插件 |
   | **D 升级** | **装过旧版整合包（v2.0.x / 更早）** | 读出 profile 里现有的 `link:` 指向，把 32 个插件逐条**重指向本包载荷**，旧载荷保持可回滚 |
   | **E 修复** | 插件"装过但不见了" | 只重挂本包已声明的插件，不动其它任何东西 |

4. 等它跑完。中途会：校验 23,263 个文件 → 把载荷复制到持久目录 `%LOCALAPPDATA%\DSHPluginsPack\v2.1.3-windows` → 备份 → 挂载 32 个插件 → **逐条核对 realpath** → 校验 256 个条目组合 → 合并配置 → 装 6 个技能 → 出安装结果 → 启动 DSH。
5. 打开 DSH → **设置 → 模型**：把 provider 的 `baseURL` 从 `https://YOUR-ENDPOINT.example.com` 换成你自己的中转站或官方地址，填上密钥。这是唯一需要你手填的东西（详见 [`docs/配置参考.md`](docs/配置参考.md)）。

6. **不用再做别的了**：装完它会打印「对齐协议：已写入 `~/.dsh/AGENTS.md`（127 行，新会话生效）」。深度档位与对齐协议已经写好——**v2.1.0 起不需要再跑 `MAINTAIN.cmd`**（那是 v2.0.x 时代的步骤）。想换档位就编辑 `~/.dsh/AGENTS.md` 里的 `## DEPTH_MODE:` 一行（`ask` / `auto` / `deep` / `fast`），下次安装会保留你改的值。

装完想确认没毛病：`VERIFY.cmd`（逐文件哈希）+ `DOCTOR.cmd`（环境体检）。

**已经装过 v2.0.x 的人**：解压 → `UPGRADE.cmd`（等于 `INSTALL.cmd` 选 D）→ 完事。旧的 v2.0.x 载荷留在原处，`PRUNE.cmd` 会在 7 天后才允许清理它。

---

## v2.1.3 修了什么（相对 v2.1.2）

**四条都来自外部用户对 v2.1.2 的实测反馈。安装器与配置改动为主；payload 只动了两个第三方包的两处 bug，插件行为零新增。**
**本版起插件包与服务包一起重出：`DSH-Plugins-v2.1.3-Windows-x64.zip` + `DSH-Plugins-v2.1.3-Services.zip`（版本号同步到 2.1.3）。**

| # | 症状（外部实测） | 根因 | 本版处理 |
|---|---|---|---|
| 1 | `UPGRADE.cmd` 当天 exit 0；**第二天起 `VERIFY.cmd` 永远报** `✗ 文件内容与校验清单不符（下载或解压损坏）：payload/node_modules/billion-context/CONFIGURATION.md`，重下重装都没用；`DOCTOR.cmd` 却全绿；把该包换回 0.1.208 立刻恢复 | `billion-context` 默认 `autoUpdate=true`，装完当天就把自己换成 npm 上的 0.1.209；`checksums.json` 封存的是 0.1.208，于是磁盘与清单永久失配。校验器没有排除名单，还把三类不同原因混成一句「下载或解压损坏」 | 三重掐死自更新：① `config/cordis.patch.yml` 给该插件注入 `ACP_AUTO_UPDATE=0`；② 安装器写 `~/.config/billion-context/billion-context.json` 的 `autoUpdate:false`（幂等、写前备份）；③ 依赖从 `^0.1.208` 钉成 `0.1.208`。校验器跳过自更新包文件，失败分成「缺文件 / 内容变了」两组报并给下一步；`DOCTOR.cmd` 新增随机 32 文件哈希抽查 |
| 2 | 第一次 `UPGRADE.cmd` 33 个插件全挂好、界面照开，末行仍 `✗ 升级后这些 bundle 没启用：dsh-whale-widget`，退出码 1（半完成） | 该包声明了 `dsh.bundle.patch` 却没进 `profile.bundles`；收尾断言把「配置缺口」当成「升级失败」 | 挂载后自动把缺的 bundle 补进 `profile.bundles` 并打印补入清单；仍补不上的降级为提醒 + 可复制的修复命令。链接缺失、payload 缺包、条目缺失依然判失败（真坏了不能装没事） |
| 3 | 没装 WeKnora 的机器上，`weknora_ask` 一点就卡 5 分钟才报错，像 DSH 卡死 | `@wxg-prc-cpg/dsh-weknora@0.1.0` 不管后端在不在都注册 4 个工具，`ask` 的 `chatTimeoutMs` 是 `300000` | vendor patch：`apply()` 前做 500 ms 存活探测，探不到只注册 `listKnowledgeBases` 并把原因写进日志（见 `docs/新功能说明.md` §12） |
| 4 | 在小码酱默认稿上改了几行再保存，重启后改动消失，`customized:true` 也不管用，日志里什么都没有 | `dsh-purge@3.0.0` 的 `isKeepableUserOverride()` 先跑 `looksLikePluginDefault()`，而它用「ChatML 头 + `<project_instructions>` + 小码酱」三条全含判「这是插件默认稿」——**在默认稿上改正是最自然的改法**，于是被无条件回滚，`atomicWriteSync` 静默覆盖且把 state 重置成 `customized:false` | vendor patch：先认「用户保存过且哈希一致」这一最强证据，再走默认稿血统兜底；覆盖前备份到 `prompt-inject.md.pack-bak-<时间>` 并 `emitWarning`，state 记 `lastRestore`（见 §12） |

**为什么这三处要打 vendor patch**：bug 在第三方包里、上游还没修，而整合包发的就是这些包的副本。补丁只改判决顺序与探活，不改任何工具的语义；每处都带 `pack-patch 2.1.3` 注释和上游坐标，升级上游版本时按注释重打即可。

**怎么确认修好了**：`node tests/issue-guard.test.mjs`（四条各有正反例，纯 Node，不依赖真实 DSH 或服务）+ 隔离 `DSH_HOME` 跑 `new / upgrade / repair / verify / doctor` 五个模式 + `validate-release` 20/20。

---

## v2.1.2 修了什么（相对 v2.1.1）

**只修 bug，不加功能；payload 与 v2.1.1 逐文件相同（23,172 文件 / 503.24 MB）。**
这一版针对的是外部用户装完 v2.1.1 后交回来的实测报告：三个入口（`UPGRADE.cmd` / `MAINTAIN.cmd` / `VERIFY.cmd`）都会在最后一步误报失败。

| # | 症状（外部实测） | 根因 | 本版处理 |
|---|---|---|---|
| 1 | `UPGRADE.cmd` 先打印「✓ 重指向核对通过：33 个插件全部指到 …」，紧接着 `✗ 升级后这些 bundle 没启用：dsh-migration-plugin-state`，退出码 1 —— 用户以为升级失败，其实 33 个依赖已经全指到新载荷 | 启停状态快照 `dsh-migration-plugin-state` 和 32 个真插件混在同一个 `targets` 里，收尾断言拿它去比 `profile.bundles`，而它按设计不进 bundles（它是状态快照，由内置 loader 认领） | 真插件与状态快照拆成 `pluginTargets` / `stateTargets`，两处收尾断言各看各的；state 只断言「链接存在且指向正确」 |
| 2 | 在持久目录里原地跑 `--mode repair` 被「持久安装目录不能与解压目录重叠」挡下 —— 升级失败后就地自救这条路走不通 | 重叠检查没排除 `ROOT === store`，而复制分支本来就为这种形态写了整段跳过 | 加 `ROOT !== store` 快速通道，原地 repair 恢复可用 |
| 3 | 技能写入失败只打印 `! 技能没能写入：xxx（EPERM）`，不知道下一步该做什么 | 提示缺动作 | 补「先完全退出 DSH（含托盘图标与后台进程）再重跑 `VERIFY.cmd`」 |
| 4 | 装完自动启动时，GUI 明明已经开着，仍空等 120 秒才报「没能在 2 分钟内探测到界面端口」 | DSH 是单实例应用，新 spawn 的进程会自己退出，端口只挂在旧进程上 | 先探活已有实例直接报就绪；`waitForPort` 双通道（子进程口 / 已有实例口），等待上限 20 秒 |
| 5 | `启停状态不一致 bash-sandbox（期望 停用，实际 停用）` —— 两边打印同一个词，完全没法排查 | 判定用 `=== true`、文案用真值判断，遇到字符串 `'true'` 就出现「mismatch 但两边显示相同」 | 判定与文案共用同一个 normalize，并打印快照与实际的原始值 |

**怎么确认修好了**：`tests/state-bundle-guard.test.mjs`（纯 Node，不依赖真实 DSH）—— 正例 33 条依赖全在时必须 `exit 0`，反例删掉一个真插件必须 `exit 1`。`validate-release` 18/18。

---

## v2.1.1 新增了什么（相对 v2.0.0，v2.1.2 / v2.1.3 在此基础上只修 bug）

v2.1.1 = v2.1.0 的能力（把「补丁要人记命令」变成默认行为）**减去两次裁错的地方**：载荷恢复完整分发、`install.ps1` 不再因 stderr 崩、`cordis.patch.yml` 不再覆盖你的模型/外观配置。

| # | 新增 | 一句话 |
|---|---|---|
| 1 | **`UPGRADE.cmd`／`install.ps1 -Action upgrade`** | 装过旧整合包的人一条命令升级；读出旧 `link:` 指向 → 备份 → 逐条重指向新载荷 → **realpath 逐条核对**，任何一条没指对就停 |
| 2 | **`REPAIR`（`-Action repair`）** | 插件"装过但不见了"时只重挂已声明的插件，不新增、不动别的 |
| 3 | **`MAINTAIN.cmd`／`maintain.ps1`** | 把 v2.0.1-patch.1 + v2.0.2-patch.1 的补丁动作折进包里，装完直接能跑：CL-001 日志轮转、CL-002/003 残留包、CL-004 空目录、CL-005 临时文件、CL-006 巨型日志、CL-007 ReMe 环境变量 |
| 4 | **`appendix/AGENTS.appendix.md` + 标记块替换** | 对齐提问协议（ALIGNMENT_PROTOCOL v1.0）写进 `~/.dsh/AGENTS.md`；**替换式**写入，写完断言 START/END 标记各 1 个，绝不叠加 |
| 5 | **`templates/workbench-toolkit/`** | 场景记忆工具箱 7 个文件（`场景记忆.mjs` / `发消息.mjs` / 例外清单 / 4 份规格文档）。**只放进 templates，不自动写**——它落到「工作台目录」才有意义 |
| 6 | **`PRUNE.cmd`（`--prune-old`）** | 清理旧载荷：默认只保留 7 天内、**仍被任何 profile 引用的永不删**；不带参数只预演 |
| 7 | **完整载荷（不裁剪）** | payload **503.24 MB / 23,172 个文件**，与 v2.0.0 逐文件对齐（缺 0）；插件内嵌 `node_modules` 249 个全保留 —— v2.1.0 的瘦身已整体撤回 |
| 8 | **内核门禁改为"只提示不阻断"** | 门禁 `>=0.2.0 <0.4.0`；0.2.x / 0.3.x 都放行，与本包基准不同只打印提示 |
| 9 | **离线优先，不再偷偷联网** | 挂载失败先 `--offline`，再 `--offline --config.lockfile=false`；仍失败**默认不联网**只告警并给出补挂办法。要联网必须显式 `--allow-network` |
| 10 | **`--skills-root` 隔离** | 让技能灌装写到指定目录，方便演练/测试时不碰真身 |
| 11 | **文档补齐** | 本 README + `CHANGELOG.md` + `docs/新功能说明.md` 逐条更新；`docs/使用说明书.md` 加"升级 / 修复 / 维护 / 清理"四节 |

逐项细节（含每个功能的边界与位置）：[`docs/新功能说明.md`](docs/新功能说明.md)。

---

## 包里到底装了什么

一个包由六部分组成：

1. **安装器**：`install.ps1`（向导、A–E 模式菜单、`verify`/`doctor`/`rollback`/`uninstall`/`maintain`/`prune` 动作）+ `install-helper.cjs`（对接官方插件 CLI、写依赖、合并配置、装技能、体检、回滚、卸载、旧载荷清理）。它不手写 `node_modules`，而是调用 DSH Desktop 自带的插件 CLI，把包内目录以 `link:` 方式注册进目标 profile，再**逐条核对 realpath**。
2. **维护引擎**：`maintain.ps1`（8 步：包自检 → 定位 → AGENTS 附录 → CL-001 → CL-002/003/004 → CL-005 → CL-006 → CL-007），每次写入前备份到 `%LOCALAPPDATA%\DSHPluginMigration\maintenance-20261029\backup-<时间戳>\`，`-Rollback` 逐文件还原。
3. **插件载荷**：`payload/node_modules/` 32 个包（含 6 个本地插件实体，**只带运行依赖**）、`payload/skills/` 6 个技能、`payload/migration-state/` 只记录启停状态的辅助 bundle。
4. **清单与凭据**：`migration.json`、`inventory.json`、`plugins.csv`、`bundles.csv`、`插件完整清单.txt`、`checksums.json`、`release-validation.json`。
5. **配置骨架**：`config/`（`cordis.patch.yml`、`cordis.yml`、`package.json`、`pnpm-workspace.yaml`、`feature-profiles/` 48 篇）。**不含任何密钥**，中转站地址统一是占位符。
6. **模板与文档**：`appendix/`、`templates/`、`docs/`、`macos/`。

---

### 36 个 bundle 的功能分组

- **内核自带（4）**：`dsh-bundle-base`、`dsh-bundle-web`、`dsh-bundle-desktop`、`dsh-bundle-cli`
- **插件管理（2）**：`dsh-plugin-manager`、`dsh-web-ui-plugin-manager`
- **模型与用量（4）**：`dsh-model-capabilities`、`modlens`、`cost-meter`、`@kenz1117/dsh-ui-usage-billing`
- **记忆与知识（6）**：`billion-context`、`hindsight-coding-agents`、`@lemoncat7/dsh-knowledge`、`@wxg-prc-cpg/dsh-weknora`、`dsh-zotero`、`dsh-memory-fusion`
- **技能与市场（4）**：`dsh-skill-fusion`、`@tt-a1i/archify-dsh`、`dsh-market`、`dsh-mattpocock-skills-deck`
- **工作台与界面（8）**：`@local/dsh-client-ui-workbench`、`dsh-infinite-gen-5`、`@linxin666/dsh-web-all`、`@linxin666/dsh-client-ui-git-graph`、`dsh-whale-widget`、`dsh-genui`、`dsh-drawai`、`browser-skill`
- **逆向与安全（4）**：`dsh-purge`、`@wxg-prc-cpg/browser-skill-dsh-plugin`、`dsh-approval-gate`、`dsh-rewind-plugin`
- **自动化与其他（4）**：`dsh-ollama`、`dsh-im`、`dsh-migration-plugin-state`、`treg`

---

## 本地记忆服务（可选包）

`DSH-Plugins-v2.1.3-Services.zip` 装的是四个本地服务本体：ReMe（2333）、OpenViking（1933）、Hindsight（8888）、WeKnora（8080）。
纯云端用户不装也能满血运行——本包的插件全部对服务缺失做了优雅降级。要装就跑 `SETUP-SERVICES.cmd`，详见 [`docs/服务部署指南.md`](docs/服务部署指南.md)。

装完之后 ReMe 还需要四个用户环境变量才能让"自动记忆"工作（模型地址 / 名称 / base url / key）。`MAINTAIN.cmd` 的 CL-007 会检查并告诉你缺哪个，也可以用 `-LlmBaseUrl -LlmModel -LlmApiKey` 让它代写。

---

## 文档

| 文档 | 讲什么 |
|---|---|
| [`docs/使用说明书.md`](docs/使用说明书.md) | 从"我只有一个空壳"讲到排障的全流程（含升级 / 修复 / 维护 / 清理四节） |
| [`docs/新功能说明.md`](docs/新功能说明.md) | v2.1.0 每一项新增的边界、落点、关闭办法 |
| [`docs/配置参考.md`](docs/配置参考.md) | 每个配置项是什么、改成自己的怎么改 |
| [`docs/服务部署指南.md`](docs/服务部署指南.md) | 四个本地服务怎么装、怎么停、端口冲突怎么办 |
| [`docs/AI-agent-适配指南.md`](docs/AI-agent-适配指南.md) | 让你的 AI agent 自己适配/改进这套东西 |
| [`docs/常见问题.md`](docs/常见问题.md) | 装不上、插件不见了、日志爆了等等 |
| [`CHANGELOG.md`](CHANGELOG.md) | 与 v2.0.0 的逐条差异 |

---

## 出问题怎么办

| 症状 | 先做这个 |
|---|---|
| 装到一半报错 | 看它打印的中文原因；再跑 `VERIFY.cmd` 确认包完整 |
| 插件在列表里"消失"了 | `DOCTOR.cmd` 会检查每个 `link:` 目标是否存在（断链时 DSH 会**静默跳过**插件、照常启动，所以只看 GUI 是看不出来的）；断链就跑 `install.ps1 -Action repair` |
| 升级后版本号没变 | 确认选的是 D 升级而不是 B 合并；`DOCTOR.cmd` 会打印"本包插件已挂载 N/N" |
| 日志几分钟涨几 MB | `MAINTAIN.cmd` 的 CL-001（ReMe 轮转 `00:00` → `100 MB`），改完重启 ReMe |
| 想退回升级前 | `ROLLBACK.cmd`（还原配置备份）；旧的 v2.0.x 载荷还在，把 `package.json` 里的 `link:` 指回去即可 |
| 想彻底删掉 | `UNINSTALL.cmd`（会先查有没有 profile 还在引用载荷目录，被引用就不删） |

---

## 已知边界（请先看一眼）

- **macOS 只做语法校验**（`bash -n`），没有实机跑过完整安装；Mac 走网络安装路线，Windows 侧的 `node_modules` 原生依赖搬不过去。**macOS 通道本版仍是 v2.0.0 的安装流程**：`macos/install.command` 里的版本号已更新为 2.1.0，但 D 升级 / E 修复 / `MAINTAIN` 三个新动作只有 Windows 入口；Mac 上升级请按 `macos/INSTALL-MAC.md` 重跑 `install.command`（它会重挂 `link:`），环境体检用 `dsh plugin --profile <名字> install` 加 `dsh --profile <名字> --dump-config` 自查。
- **0.3.x 内核只是放行，没有实机验证**。
- **不做第二台物理机验证**：所有验证都在同一台机器的隔离 profile 上完成（`DSH_HOME` 指向临时目录 + 真实 `--dump-config` 加载）。
- **旧载荷不会自动删**：`PRUNE.cmd` 默认 7 天、且被引用的永不删；急着腾空间就手动删，删前先 `DOCTOR.cmd`。
- **`config/cordis.patch.yml` 是脱敏快照**：中转站地址是 `https://YOUR-ENDPOINT.example.com`、密钥行被整行去掉（不是留 `-`）。它只用来"补缺"，不会覆盖你已有的条目。

---

## 版本导航

| 版本 | 位置 | 说明 |
|---|---|---|
| **v2.1.3**（当前） | `stable-v2/` + Release `v2.1.3` + `DSH-Plugins-v2.1.3-Services.zip` | **只修 bug + 服务包重出**：修掉自更新插件与校验清单的永久冲突、把配置缺口当升级失败、没服务却注册 5 分钟超时的工具、用户改过的稿被静默回滚 |
| v2.1.2 | Release `v2.1.2` | 修掉 upgrade/repair 必报「bundle 未启用」退出码 1、原地 repair 被目录重叠挡住、EPERM 提示缺动作、GUI 已在运行仍空等 120 秒、启停差异文案自相矛盾 |
| v2.1.1 | Release `v2.1.1` | **撤回瘦身**（回到 v2.0.0 完整载荷）+ 修 `install.ps1` stderr 崩溃 + 不再覆盖用户模型/外观配置 + macOS 也能写入对齐协议 |
| v2.1.0 | Release `v2.1.0` | 整合两份补丁 + 升级/修复/维护/清理入口；**载荷裁剪导致部分插件缺依赖，请改用 v2.1.1** |
| v2.0.2-patch.1 | `patch/DASH...` / Release `v2.0.2-patch.1` | 环境维护补丁，**已被 v2.1.0 吸收** |
| v2.0.1-patch.1 | `patch/...` / Release `v2.0.1-patch.1` | 首个补丁，**已被 v2.1.0 吸收** |
| v2.0.0 | Release `v2.0.0` | 首个 v2 大版本（插件 32 个，payload 502 MB） |
| v1.0.0 | `stable/` + Release `v1.0.0` | 存档，仅供回退与对照 |
| v0.1.0-demo.1 | `demo/` | 早期演示，不再维护 |

---

## 许可

见 [`LICENSE`](LICENSE)。第三方插件按各自许可分发，来源与版本见 `plugins.csv` 与 `插件完整清单.txt`。
