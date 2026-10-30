# 变更记录（CHANGELOG）

本文件记录每个版本相对上一版的**实际差异**。所有人可见的行为变化都写在这里；内部重构不写。

---

## v2.1.3（2026-10-30）— 四条外部反馈全修 + 插件包与服务包一起重出

**一句话**：v2.1.2 的插件行为一个字没动，修的是「装完之后一直骗你失败」的四条 —— 自更新插件与校验清单的永久冲突、
把配置缺口当升级失败、没有 WeKnora 服务却注册 5 分钟超时的工具、把用户改过的稿当默认稿静默回滚。
本版起 `-Services` 服务包不再沿用 v2.0.0，与插件包一起重出并同步版本号。

| # | 修了什么 | 位置 | 外部现象 |
|---|---|---|---|
| 1 | 校验器跳过自更新包文件（`SELF_UPDATING_PREFIXES`）；失败改为「缺文件 / 内容变了」分组报告，删掉「下载或解压损坏」误导 | `install-helper.cjs` `verifyFiles()` | `VERIFY.cmd` 永久报 `billion-context/CONFIGURATION.md` 不符，重下重装无效 |
| 2 | `DOCTOR.cmd` 新增随机 32 文件哈希抽查（`--hash-sample N` 可调），只 warn 并指路 VERIFY | 同上 `doctorMode()` | 体检全绿、校验红，两套结论互相打脸 |
| 3 | 三重关闭 `billion-context` 自更新：`cordis.patch.yml` 注入 `ACP_AUTO_UPDATE=0`、写 `~/.config/billion-context/billion-context.json` 的 `autoUpdate:false`、依赖钉成 `0.1.208` | `config/cordis.patch.yml`、`config/package.json`、`install-helper.cjs` | 装完当天正常，第二天起校验必红（插件已自更新到 0.1.209） |
| 4 | 挂载后自动把「声明了 `dsh.bundle.patch` 却没进 `profile.bundles`」的包补进 bundles，并打印补入清单 | `install-helper.cjs` 挂载后校验段 | 33 个插件全挂好、界面照开，末行仍 exit 1 报 `bundle 未启用` |
| 5 | 两处收尾断言从 `die` 降级为 `warn` + 可复制修复命令；链接缺失/缺包/缺条目仍 `die` | 同上 `:736` / upgrade 收尾 | 「半完成」被伪装成「升级失败」，用户不敢重试 |
| 6 | 任何失败收场先打三行「当前处于哪一步 / 载荷已换到新目录 / 怎么回滚或就地修」 | 顶层 `catch` | 看到 ✗ 就以为什么都没发生，直接重装 |
| 7 | vendor patch：`@wxg-prc-cpg/dsh-weknora@0.1.0` 在 `apply()` 前 500 ms 探活，探不到只注册 `listKnowledgeBases` | `payload/node_modules/@wxg-prc-cpg/dsh-weknora/dist/index.js` | 没装 WeKnora 时 `ask` 卡 5 分钟（`chatTimeoutMs: 300000`） |
| 8 | vendor patch：`dsh-purge@3.0.0` 先认「用户保存过且哈希一致」，覆盖前备份 + `emitWarning` + state 记 `lastRestore` | `payload/node_modules/dsh-purge/lib/core.js`（同步 `Xsdsh-purge/lib/core.js`） | 在默认稿上改几行保存，重启即被静默回滚 |
| 9 | `install.ps1` / `maintain.ps1` / 9 个 `.cmd` / `migration.json` / `inventory.json` / `migration-state` / macOS 四件套版本号统一 2.1.3（macOS 侧此前一直停在 2.1.0） | 各入口脚本与清单 | 横幅、`--version`、macOS 向导报的版本号与实际不一致 |
| 10 | 服务包重出：`payload/services/manifest.json` 版本 2.0.0 → 2.1.3，打 `DSH-Plugins-v2.1.3-Services.zip` | `_build-v2.1.3/DSH-Plugins-v2.1.3-Services` | 服务包一直停在 v2.0.0，与插件包版本对不上 |

**payload 变化（只有这两个包，可逐字节核对）**：
`billion-context` 一个文件都没改（只是依赖钉住 + 关闭自更新）；`dsh-weknora` 的 `dist/index.js` 与 `dsh-purge` 的 `lib/core.js` 各两处 `pack-patch 2.1.3` 注释块。
其余 30 个插件与全部技能、能力手册、templates 逐字节未动。

验收：`tests/issue-guard.test.mjs` 正反例双通过（四条各一组）；隔离 `DSH_HOME` 跑 `new` / `upgrade` / `repair` / `--check-only` / `doctor` 全绿；
`validate-release` **20/20**（新增第 20 条：防回退 —— `verifyFiles` 必须含 `SELF_UPDATING_PREFIXES`，`:736` 不得再往 `failed` 里 push）。

---

## v2.1.2（2026-10-30）— 只修 bug：修掉 v2.1.1 的「假失败」退出码

**一句话**：v2.1.1 的载荷与能力一个字没动，修的是它收尾断言把「启停状态快照」当成第 33 个插件去比
`profile.bundles` —— 于是 33/33 全部挂好、条目组合也通过，仍以 exit 1 收场。外部用户报告的两个退出码
（upgrade 的「bundle 未启用」、repair 的「没指到本包载荷」同源）都指向这一处。

| # | 修了什么 | 位置 | 现象 |
|---|---|---|---|
| 1 | 真插件与状态快照拆成 `pluginTargets` / `stateTargets`，收尾断言各看各的 | `install-helper.cjs` 挂载清单构造 + 两处收尾校验 | upgrade 末行必报 `✗ 升级后这些 bundle 没启用：dsh-migration-plugin-state`，退出码 1 |
| 2 | 重叠检查加 `ROOT !== store` 快速通道 | 同一文件，持久目录判定 | 在持久目录里原地 `--mode repair` 被「不能让目录重叠」挡死 |
| 3 | 启停差异的判定与文案共用 normalize，并打印原始值 | 插件组合校验 | 打印「期望 停用，实际 停用」这种自相矛盾的结果 |
| 4 | 启动前先探活已有实例；`waitForPort` 双通道，上限 120 秒 → 20 秒 | 安装收尾自动启动 | GUI 已开着仍空等 2 分钟后报「没探测到界面端口」 |
| 5 | `EPERM` 技能写入失败补动作提示 | 技能安装循环 | 只说「没能写入」，用户不知道下一步 |
| 6 | `install.ps1` 的 `$PackVersion`、`maintain.ps1` 的 `$patchVersion` 同步到 2.1.2（v2.1.1 漏改，一直显示 2.1.0） | 两个入口脚本 | 横幅与 `--version` 报的是旧版本号 |
| 7 | README 规模行改回实测值（23,263 文件 / payload 503.24 MB） | `README.md` | v2.1.1 发版时漏改，仍写着 v2.1.0 的 10,763 文件 / 318.45 MB |

**payload 与 v2.1.1 逐文件相同**：23,172 文件 / 503.24 MB / 249 个内嵌 `node_modules`，`compare-payload.mjs` 比对缺 0。

验收：`validate-release` 18/18；新增 `tests/state-bundle-guard.test.mjs` 正反例双通过；隔离 `DSH_HOME` 跑
`--mode new` / `upgrade` / `repair` / `--check-only` 四模式全绿。

---

## v2.1.1（2026-10-29）— 撤回瘦身 + 修 3 个真 bug

**一句话**：v2.1.0 的载荷裁剪害人，v2.1.1 把载荷口径**退回 v2.0.0 的完整复制**，并修掉外部实测暴露的 3 个真 bug；对齐提问协议在 Windows 与 macOS 都自动写入。

| # | 变更 | v2.1.0 | **v2.1.1** |
|---|---|---|---|
| 1 | payload 口径 | 裁剪 36.6%（10,667 文件 / 318.79 MB） | **完整复制 23,172 文件 / 503.24 MB**，与 v2.0.0 逐文件比对缺 0 |
| 2 | 插件内嵌 `node_modules` | 全删，只留顶层反链 | **249 个全保留**；只跳 `.git`/`.vite`/`.cache`（325 文件 5.29 MB） |
| 3 | `install.ps1 -Action upgrade` | `$ErrorActionPreference='Stop'` 下 stderr 直接抛异常退出 | **捕获 stderr 转告警**，退出码按真实结果判定 |
| 4 | `cordis.patch.yml` 合并 | 无条件覆盖，用户的 `llm-pi-ai` / 默认模型 / 主题被打回 | **敏感条目默认不合并**（模型、外观、宠物坐标、进度状态），只补功能开关 |
| 5 | macOS | `install.command` 不写 `AGENTS.md`，对齐协议在 mac 上等于没有 | **新增 write_appendix**，与 Windows 同口径（幂等、保留用户 DEPTH_MODE、写前备份） |

验收：`validate-release` 17/17、`test-mac-appendix.sh` 19/19、mac 两个脚本 bash -n 通过、payload 与 v2.0.0 逐文件比对缺 0。

---

## v2.1.0 —— 2026-10-29（载荷裁剪有问题，已被 v2.1.1 取代，请勿使用）

**一句话**：把 v2.0.1-patch.1 与 v2.0.2-patch.1 两份补丁的动作**折进包里变成默认行为**，同时把 payload 瘦身 36.6%，并补上「升级 / 修复 / 维护 / 清理」四个入口。

### 新增

| # | 新增 | 落点 | 说明 |
|---|---|---|---|
| 1 | 升级模式 D | `install.ps1 -Action upgrade` / `UPGRADE.cmd` | 读出 profile 里现有的 `link:` 指向 → 备份 → 逐条重指向本包载荷 → `fs.realpathSync` 逐条核对（33 个插件全指对才算过）。**这是 v2.1.0 的核心增量**：v2.0.x 升级要人记命令，现在一条命令。 |
| 2 | 修复模式 E | `install.ps1 -Action repair` | 只重挂本包已声明的插件，不新增、不动其它。对应"插件装过但目录丢了"这种情况。 |
| 3 | 维护引擎 `maintain.ps1` | 包根 + `MAINTAIN.cmd` | 429 行、8 步：包自检 → 定位 → **AGENTS 附录块** → CL-001 → CL-002/003/004 → CL-005 → CL-006 → CL-007。不加 `-CheckOnly` 才写文件；每次写入先备份。 |
| 4 | 对齐协议附录 | `appendix/AGENTS.appendix.md` | ALIGNMENT_PROTOCOL v1.0 全文（D0–D3 难度分级、卡片问档位、方案清单、收束、回执）。`maintain.ps1` 用**替换式标记块**写入 `~/.dsh/AGENTS.md`，写后断言 START/END 各 1 个。 |
| 5 | 场景记忆工具箱 | `templates/workbench-toolkit/`（7 文件） | `场景记忆.mjs`（44,191 B）+ `发消息.mjs`（4,250 B）+ 例外清单（340 B）+ 4 份规格文档。**只放进 templates，不自动写**——它落到「工作台目录」才有意义。 |
| 6 | 旧载荷清理 | `install-helper.cjs --prune-old` / `PRUNE.cmd` | 扫 `%LOCALAPPDATA%\DSHPluginsPack\v*-windows`，默认保留 7 天；**仍被任何 profile `link:` 引用的永不删**；不带 `--yes` 只预演。 |
| 7 | 离线优先的挂载回退 | `install-helper.cjs` | ① `add --offline` ② `add --offline --config.lockfile=false` ③ 仍失败则**默认不联网**、记 `warned` 继续，末尾汇总补挂办法。要联网必须显式 `--allow-network`。 |
| 8 | `--skills-root` | `install-helper.cjs` | 让技能灌装写到指定目录（`<root>/dsh` 与 `<root>/agents`），演练/测试不碰真身。 |
| 9 | 安装后断链检查 | `--doctor` | 逐个检查 profile 里所有 `link:` 目标是否存在。**断链时 DSH 会静默跳过插件、照常启动**，只看 GUI 发现不了。另加"持久目录里有多个载荷版本"告警与日志目录 >100MB 巡检。 |
| 10 | 内核门禁二选 | `migration.json` | `kernel.required` 从 `>=0.2.0 <0.3.0` 放宽到 **`>=0.2.0 <0.4.0`**；0.2.x / 0.3.x 均放行，与本包基准不同**只提示不阻断**。 |

### 变更

| # | 项 | 前（v2.0.0） | 后（v2.1.0） |
|---|---|---|---|
| 1 | payload 体积 | 502.41 MB / 23,071 文件 | **318.79 MB / 10,670 文件（−36.6%）** |
| 2 | `dsh-skill-fusion` 载荷 | 91.8 MB（含 5,047 个 node_modules 文件，其中 86 MB 是 devDependencies） | **3.0 MB**（只带 runtime 依赖 `js-yaml`；peer 由内核 asar 提供） |
| 3 | 全局开发件裁剪 | 无 | `tests / test / examples / .github / coverage / benchmark / *.map / tsconfig* / CHANGELOG.md` 等**在复制时即过滤**，并计入 inventory 的 `trimmed` |
| 4 | `config/package.json` 的 link 段 | 本机绝对路径 | 占位 `link:__PACK_STORE__/payload/node_modules/<name>`，由安装器算绝对路径 |
| 5 | `inventory.json` schema | v2 | **v3**：新增 `packVersion / maintainedAt / counts.trimmed* / trimmed{rules,droppedFiles,droppedBytes,perPlugin} / assertions` |
| 6 | `migration.json` schema | 2 | **3**：新增 `supportedModes`（含 `upgrade`/`repair`）、`storeLayout` |
| 7 | 安装器核心 | 44,644 B | 58,772 B（+14,128 B，23 处改造） |
| 8 | 入口 | 6 个 `.cmd` | **9 个**（+`MAINTAIN.cmd` / `UPGRADE.cmd` / `PRUNE.cmd`） |
| 9 | 能力手册 | 47 篇 + 索引 | 48 篇（本机重生成） |
| 10 | 服务包 | `DSH-Plugins-v2.0.0-Services.zip` | **不重出**，沿用 v2.0.0 的那个（服务本体无变化） |

### 修复

| # | 问题 | 现象 | 根因 | 修法 |
|---|---|---|---|---|
| 1 | 启停状态 bundle 缺失 | 升级时报 `dsh-migration-plugin-state（payload 里没有这个包）` | v2.1.0 装配器漏了生成 `payload/migration-state/` | 按 `rows.json` 的 256 条 `pluginRows` 生成 `package.json` + `icon.svg` + `cordis.patch.yml`（10,345 B，与 v2.0.0 字节一致） |
| 2 | 离线挂载误判失败 | 首个包报 `ERR_PNPM_NO_OFFLINE_TARBALL`（`treg-dsh` 的 git tarball 不在离线 store），pnpm 解析整张依赖图把 link 包连带判失败 | 旧逻辑"离线失败就联网重试"——**联网会把 200+ 实体包装进 profile，破坏"全部 link 到载荷"的离线语义** | 三级回退 + 默认不联网（见新增第 7 项） |
| 3 | 技能灌装偶发 EPERM | `EPERM: operation not permitted, mkdir ~/.agents/skills/...`，单个技能失败拖垮整个安装 | Electron 子进程下 mkdir 偶发失败 | 每技能 `try/catch` + 3 次重试（300/600/900ms 退避），失败只告警 |
| 4 | 预演提示与实际矛盾 | `upgrade` 预演说「本模式下跳过」，随后又实际重指向 | 文案没按模式区分 | `upgrade/repair` 打「将重指向载荷」，`merge` 打「本模式下跳过」 |
| 5 | `VERIFY.cmd` 在纯净机卡死 | 找不到 DSH 时卡在「请粘贴安装目录」 | v2.0.0 已修（`Invoke-PureVerify`），本版继承并保持 `counts.files` / `counts.bytes` 字段对齐 | 无改动，回归验证通过 |

### 行为变更（装完即生效，不需要手动跑任何命令）

- **对齐协议与深度档位改为安装器自动写入**：`INSTALL.cmd` / `UPGRADE.cmd` / `-Action repair` 装完自动写 `~/.dsh/AGENTS.md` 的标记块，并打印路径 / 行数 / `DEPTH_MODE` 值。v2.0.x 需要用户自己跑 `MAINTAIN.cmd`，实测大多数人不会跑，等于没有。
- **`DEPTH_MODE` 段并入标记块内**，替换时**保留用户改过的值**（读到旧值就用旧值），默认 `ask`；老机器块外那段旧档位段会并入块内，全文只保留一份。
- **写入实现收敛为一处**：`install-helper.cjs` 的 `writeAgentsAppendix()`；`maintain.ps1` 第 3 步改为转发；macOS `install.command` 复用同一函数。新增 `-Action appendix` / `--write-appendix` 单独入口。
- **新增安全清理**（默认开）：`*.tmp`（>1 天）、轮转日志（>10 MB 且 >1 天）、空目录（跳过 `node_modules` / `skills` / `sessions` 等）→ 删；`.log` 超 100 MB **只报告不删**（留作排障证据）。逃生开关 `-SkipCleanup` / `-SkipAppendix`。
- **文档校正 35 处**：持久目录 `v2.0.0-windows` → `v2.1.0-windows`（讲旧载荷的 5 行有意保留）、`migration.json` 的 `features` 指向修正、作者本机路径换成占位符、规模数字改成实测值（10,763 文件 / payload 318.45 MB）。

### 验证证据（可复跑）

| 项 | 结果 |
|---|---|
| R1 `link:` 语义 | 二次 add 就地覆盖、remove 留残留链接、缺失路径 exit 1、断链时 `--dump-config` 静默跳过（exit 0）→ 全部实测 |
| R2 瘦身可加载 | 裁剪版与原始版 host 入口逐字段 `diffCount=0`；throwaway profile 的 `--dump-config` **字节数完全相同** |
| R3 junction | 裁剪用 `dereference:true` 实体化，实测 `isSymlink=false` |
| R10 升级端到端 | 真实升级路径（32 条依赖全 link 到旧载荷）→ 33 个插件全部指到新载荷、256 条目 / 37 bundle、10 项断言全过、二次执行幂等 |
| R11 升级后真实加载 | `dsh --profile <副本> --dump-config` → exit 0、1,906 行、`skipping profile bundle` = **0** |
| R12 其余动作 | `--check-only` / `--doctor` / `--prune-old` 全部 exit 0 |
| 凭据卫生 | config 52 文件 + 6 个自研插件源码 + payload 全文扫描，命中 **0** |

---

## v2.0.2-patch.1 —— 2026-10-28（已被 v2.1.0 吸收）

- 环境维护补丁：CL-001…CL-007 七项动作从"派单给人"改成"跑一个脚本"。
- `apply.ps1`（429 行）+ `CHECK.cmd` / `APPLY.cmd` / `ROLLBACK.cmd` + `docs/环境维护与自检.md`。
- **v2.1.0 起不需要单独装这个补丁**：同样的动作已在 `maintain.ps1` 里。

## v2.0.1-patch.1 —— 2026-10-28（已被 v2.1.0 吸收）

- 首个补丁：ReMe 日志轮转（`rotation="00:00"` → `100 MB`）与巨型日志清理。
- **v2.1.0 起不需要单独装这个补丁**：CL-001 / CL-006 已在 `maintain.ps1` 里。

## v2.0.0 —— 2026-10-28

首个 v2 大版本：32 个插件包（26 npm + 6 自研）、36 个 bundle、256 个插件条目、6 个技能、47 份能力手册、A/B/C 三模式安装器、服务本体包、macOS 通道、体检/回滚/卸载入口。payload 502.41 MB。

## v1.0.0 —— 2026-10（存档）

首个可装机版本，内容见 `stable/`。不再维护。
