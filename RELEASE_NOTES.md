# 整合包 v2.1.3 — 只修 bug：四条外部反馈，插件包与服务包一起重出

**版本类型**：bugfix（Latest）· **发布日**：2026-10-30 · **基线**：v2.1.2 · **适用内核** `0.2.x` / `0.3.x`（按 `0.2.1-rc.2` 构建，门禁 `>=0.2.0 <0.4.0`，版本不同只提示不阻断）· **Windows 10/11 x64**，macOS 通道同步版本号

只修 bug，不新增功能。四条改动全部来自一位外部用户对 v2.1.2 的实测反馈（带完整复现步骤和自更新证据），逐条核过源码才动手。**插件包与服务包本次一起重出，版本号统一到 2.1.3**——服务包此前一直停在 `v2.0.0-Services`，这次同步；服务包只改了 `payload/services/manifest.json` 的 `version`，服务本体文件没动，装过的机器**不需要重装服务**。

## 附件

| 文件 | 体积 | 说明 |
|---|---|---|
| `DSH-Plugins-v2.1.3-Windows-x64.zip` | 190,898,289 B（约 182.05 MB） | 插件包本体，SHA-256 `cd37892f5674a0a67ba479e7b191d068dc0d7e6cfd36420449c39432e227f25b` |
| `DSH-Plugins-v2.1.3-Windows-x64.zip.sha256` | 约 100 B | 校验文件（`<hash>  <文件名>`） |
| `DSH-Plugins-v2.1.3-Services.zip` | 723,168,512 B（约 689.67 MB） | 服务本体包（可选）：ReMe / OpenViking / Hindsight / WeKnora，SHA-256 `605207607c8ad6bdcdbb9dc6e69bebb262eed3dbd1ae4edd4eca6fbef2173200`（v2.1.3 起与插件包一起重出，内容与 v2.0.0 那份逐字节相同） |
| `DSH-Plugins-v2.1.3-Services.zip.sha256` | 约 100 B | 校验文件 |
| `release-validation.json` | 3,265 B | 发布前自检结果，**21 项全过** |

**服务包口径（已逐条核对）**：解压后 77,564 个文件条目与 `v2.0.0-Services.zip` 一一对应、大小全同；唯一的字节差异是 `payload/services/manifest.json` 的 `version` 字段（`2.0.0` → `2.1.3`，同长度）。zip 比旧包大 10 MB（713,168,758 → 723,168,512 B）**不是内容变了**，而是打包工具不同：旧包保留了 5,790 个目录条目、本次用 .NET `ZipFile.CreateFromDirectory`（只写文件条目、Deflate Optimal）。
插件载荷 23,172 个文件 / 503.24 MB，与 v2.1.2 同口径；载荷里只动了两个第三方包的两个文件（`payload/node_modules/@wxg-prc-cpg/dsh-weknora/dist/index.js`、`payload/node_modules/dsh-purge/lib/core.js`），其余改动在安装器（`install-helper.cjs`，79,428 → 91,000 B）、配置与文档。

## 用户看到的现象

1. **`VERIFY.cmd` 永远 exit 1**：upgrade 当次 exit 0，之后每次跑都报
   `✗ 安装未完成：文件内容与校验清单不符（下载或解压损坏）：payload/node_modules/billion-context/CONFIGURATION.md`，
   并提示重下 191 MB。重下重解压照样报错，而 `DOCTOR.cmd` 全绿。手动把 billion-context 降级回 `0.1.208` 能好 80–85 秒，随后又被打回 `0.1.209`。
2. **`UPGRADE.cmd` exit 1，但插件其实全装好了**：33 个插件全挂载、界面正常打开，最后一行照样 `✗ 挂载后的校验没通过：dsh-whale-widget（bundle 未启用）`。手工往 profile 的 `dsh.profile.bundles` 补一个 `"dsh-whale-widget"` 再跑就 exit 0。
3. **没装 WeKnora 也注册 4 个工具**：Windows 上没有 WSL、服务没起，`list_knowledge_bases` / `search` / `read_document` / `ask` 照样在工具列表里；`ask` 最坏干等 300 秒。
4. **改过的提示词被静默回滚**：在插件默认注入稿上改几行，过一阵又变回原样，没有任何日志。

## 根因

| # | 位置 | 根因 |
|---|---|---|
| 1 | `config/package.json` 的 `"billion-context": "^0.1.208"` + `install-helper.cjs:130` `verifyFiles()` | caret 允许自更新到 0.1.209；`checksums.json` 按 0.1.208 封存（该包 691 条目），自更新后磁盘 695 条（24 改 + 4 新增）；校验器无排除名单 → 逐条比对必然不符 |
| 2 | 收尾断言（原 `:736` `failed.push(p.name + '（bundle 未启用）')`、`:759 die('升级后这些 bundle 没启用：'…)`） | 把「声明了 `dsh.bundle.patch` 但用户 profile 的 `dsh.profile.bundles` 没列」判成安装失败。这是 profile 的历史缺口、不是安装失败，而此时载荷其实已经换好了（半完成态） |
| 3 | `payload/node_modules/@wxg-prc-cpg/dsh-weknora/dist/index.js` | 4 个工具在 `apply()` 里按 `config.tools.*`（默认全 true）注册，零存活探测；`config.js` 的 `chatTimeoutMs: 300_000` → 服务不在时 `ask` 干等 5 分钟 |
| 4 | `payload/node_modules/dsh-purge/lib/core.js`（原 `:7674` 早于 `:7675-7678` 读 state） | 先跑 `looksLikePluginDefault(text)`：含 `PLUGIN_DEFAULT_MARKS` 三条（`<\|im_start\|>system:`、`<project_instructions>`、`Little Code Sauce`）即判「插件默认稿」→ 直接 `return false`，读 `customized:true` 排在后面永远不生效；随后 `atomicWriteSync(fp, bundled)` 覆盖 + state 重置 `customized:false`，全程无日志 |

## 修法

### ISSUE-1：自更新包与校验清单永久打架（三方治本 + 校验器豁免）

1. **掐源头（三重）**：`config/cordis.patch.yml` 给 `bili-native` 注入 `env: ACP_AUTO_UPDATE: "0"`；安装时写 `~/.config/billion-context/billion-context.json` 的 `"autoUpdate": false`（先备份 `.bak-<时间戳>`、已关闭则跳过、失败只 warn，实现在 `install-helper.cjs:1176 disableBillionContextAutoUpdate()`）；`config/package.json` 把 caret 改成精确 `"0.1.208"`。
2. **校验器常量豁免**：`install-helper.cjs:63 const SELF_UPDATING_PREFIXES = ['payload/node_modules/billion-context/']` + `isSelfUpdating()`，`verifyFiles()` 里命中即跳过并计数，成功日志明说「另有 N 个自更新包文件按约定跳过」——不是静默放过。
3. **失败报告改人话**：不再第一处不符就 die，改为收集后分组输出「缺 N 个 / 内容变了 N 个」+ 前 5 个路径 + 三步「下一步（按顺序试，别急着重下 191 MB）」，删掉误导的「（下载或解压损坏）」。
4. **`DOCTOR.cmd` 加哈希抽查**：新增 `--hash-sample 32`，随机挑 32 个非豁免文件比对，不一致只 warn + 提示跑 `VERIFY.cmd`（约 10 s），消掉「DOCTOR 全绿但 VERIFY 报错」的割裂感。

### ISSUE-2：配置缺口不再当安装失败

1. 挂载后校验阶段（`install-helper.cjs:780` 起）先自动补入：凡 `declaresBundle(p.dir)` 为真而 `dsh.profile.bundles` 缺失的，直接补进并 `boot.writeProfileBundles(profile, mf, next)`（`:798`）落盘，打印「✓ 自动补启用 bundle：…」。
2. 收尾断言降级：`bundleWarn.push(p.name)`（`:818`）只提醒、不进 `failed`，并给可复制的手工补法。**保留硬失败**：缺链接、挂载失败、挂载后校验不过、条目缺失。
3. 任何 `die` 之前先打三行状态：现在处于哪一步（别急着重装）／载荷通常已换到新目录（半完成）／想退就跑 `ROLLBACK.cmd`。

### ISSUE-3：没装服务就别注册工具（vendor patch）

`payload/node_modules/@wxg-prc-cpg/dsh-weknora/dist/index.js` 的 `apply()` 前加 500 ms 存活探测（`fetch(baseUrl, {method:'HEAD'})` + AbortSignal）：不可达只注册 `list_knowledge_bases`（本地静态数据）并写日志「没有探测到 WeKnora 服务（…），只注册本地列表工具」；可达则 4 个全注册。探测不抛错，网络异常按不可达处理。

### ISSUE-4：自定义稿优先于「默认稿血统」（vendor patch）

`payload/node_modules/dsh-purge/lib/core.js`：

- `isKeepableUserOverride()` 加前置判断：`state.customized === true && state.hash === hashOverride(text)` 直接 `return true`，不再看文本像不像默认稿。
- 覆盖前落备份 `.pack-bak-<时间戳>`、`process.emitWarning` 发告警、state 记 `lastRestore: {at, from, backup}`。
- `looksLikePluginDefault` 保留作兜底（真·默认稿不会被误当自定义）。

两处 vendor patch 都带 `/* pack-patch 2.1.3 (ISSUE-x) */` 注释，可在载荷里 `findstr /S /C:"pack-patch 2.1.3"` 定位；上游源 `Xsdsh-purge\lib\core.js` 已同步改，重跑 `assemble.mjs` 不会被冲掉。

## 实测对照

| 用例 | v2.1.2 | v2.1.3 |
|---|---|---|
| 复刻自更新（billion-context 24 改 + 4 新增）后 `--check-only` | **exit 1**，`…与校验清单不符（下载或解压损坏）：payload/node_modules/billion-context/CONFIGURATION.md` | **exit 0**，「另有 691 个自更新包文件按约定跳过」 |
| 反向：改非豁免包文件（`dsh-purge/package.json`） | exit 1（泛化报错） | **exit 1**，点名「改过：payload/node_modules/dsh-purge/package.json」 |
| 真包纯校验 `--check-only` | exit 0 | exit 0，7.4 s，`本包版本：2.1.3，插件包数：32，技能：6` |
| 无 WeKnora 服务 | 注册 4 个工具，`ask` 干等 300 s | 只注册 `list_knowledge_bases` + 一条日志 |
| 自定义稿（`customized:true` + 哈希一致） | 判为默认稿 → 覆盖 | 保留，不覆盖 |
| 测试 | 发布自检 19 项 | `state-bundle-guard` **14/14** + `issue-guard` **19/19** + 发布自检 **21/21** |

## 防回退

`release-validation.json` **21 项全过**，新增两项专盯这次修法：

- **第 20 项**：安装器必须还带 `SELF_UPDATING_PREFIXES`、`isSelfUpdating()` 跳过、`--hash-sample`、`disableBillionContextAutoUpdate()`、`bundleWarn.push`、`writeProfileBundles(profile, mf, next)`、「当前处于哪一步」；且**不得**再出现 `failed.push(p.name + '（bundle 未启用）')` 与 `文件内容与校验清单不符（下载或解压损坏）`。
- **第 21 项**：两个 vendor patch 的标记串（`pack-patch 2.1.3 (ISSUE-3/4)`、`lastRestore`、`没有探测到 WeKnora 服务`）与配置侧（`"billion-context": "0.1.208"` 不带 caret、`- id: bili-native` + `ACP_AUTO_UPDATE: "0"`）必须都在。

包内 `tests/issue-guard.test.mjs` 会直接 import 真包里的 `install-helper.cjs` 函数体与两个 patch 后的模块跑（不联网），`tests/state-bundle-guard.test.mjs` 守 v2.1.2 那批。

## 版本号同步清单（2.1.2 → 2.1.3）

`install.ps1`（`$PackVersion`）、`maintain.ps1`（`$patchVersion`）、9 个入口 `.cmd` 标题、`migration.json`、`inventory.json`、`payload/migration-state/package.json`、`macos/` 四件套、`README.md` / `CHANGELOG.md` / `docs/*`（含持久目录名 `v2.1.3-windows`）、`payload/services/manifest.json`（服务包 `2.0.0` → `2.1.3`）。

## 未验证 / 遗留

1. **真实 `install` / `upgrade` 端到端没跑**：本机装的是生产 asar，缺 `node_modules/@deepseek-ai/dsh-desktop-host/lib/cli.js`，helper 在内核探测这步就失败（v2.1.2 当时同样）。ISSUE-2 靠源码逐行核对 + 断言串检查 + 单元级构造用例验收。
2. **真 Mac 未跑**：`macos/` 只同步版本号。
3. **内核 0.3.x 未测**：只在 0.2.1-rc.2 上验过。
4. **反馈那台机器未复验**：四条按复刻形态验证，最终确认要等对方升上来跑一次。
5. ISSUE-1 的 `autoUpdate:false` 写入依赖 `~/.config/billion-context/billion-context.json`（`BILI_CONFIG_FILE` 可覆盖）；若上游改配置路径，这条会退化成只靠 `ACP_AUTO_UPDATE`。

## 与反馈不一致的两处（按源码为准）

- 反馈说 weknora「4 个工具无条件注册」：源码里 4 个 `register` 都包在 `if (config.tools.x)` 内，**准确说法是默认全 true + 无存活探测**。
- 反馈把 ISSUE-2 描述为「33 个插件全部挂载」：源码里 `failed` 只在该插件 `declaresBundle` 为真时 push，失败条目是单个插件，不是全部。

## 回滚

- 用户侧：`ROLLBACK.cmd`（回安装前快照），或把 store 目录换回上一份后重跑 `UPGRADE.cmd`。
- 本版可安全退回 v2.1.2：差异只在两个 vendor patch 文件 + 安装器 + 配置，不涉及数据迁移。
