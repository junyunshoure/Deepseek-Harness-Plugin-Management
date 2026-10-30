# AI agent 适配指南 —— 内核对不上、插件报错、想加功能时怎么让 agent 接手

面向三种人：装完发现**内核版本和包里记录的不一样**、**某个插件加载就报错**、**想要包里没有的功能**。

核心思路只有一句：**别自己猜，把包和现场一起交给 DSH 里的 AI agent，让它自己读、自己改、自己验证。**

原因很实际——这个包记录的是 `0.2.1-rc.2` 那一刻的现场：依赖清单、`cordis.patch.yml` 条目、256 条 `pluginRows`、47 篇功能 profile。你的机器上这些大概率已经漂移。漂移点在哪、要不要改、改成什么样，靠人眼看 yml 猜不出来，靠 agent 一条命令一条命令核对出来。

---

## 0. 三十秒版本

1. **报错先别卸**：跑 `VERIFY.cmd` → `DOCTOR.cmd`，两份输出留着。
2. 打开 DSH 新建会话，把第 2 节的提示词模板 + 第 2.1 节的文件清单丢给 agent。
3. agent 第一轮**只读**（核对入口、核对函数、核对条目），第二轮才动手改。
4. 崩了按第 4 节三级走：`ROLLBACK.cmd` → `deps-before.json` 手工回滚 → 删 `node_modules` + `package.json` 用 C 模式重装。

---

## 1. 什么时候该找 agent

| 症状 | 自己硬扛的典型结局 | agent 能做的事 |
| --- | --- | --- |
| 内核不是 `0.2.x`（升到 0.3、或退回 0.1） | 盲目重装，反复失败 | 按第 3 节三件事核对，定位是入口没了、函数改名了，还是条目对不上 |
| `INSTALL.cmd` 报「没有找到官方插件安装器」 | 以为包坏了 | 确认 `dsh-desktop-host\lib\cli.js` 在不在；不在说明内核换了目录结构 |
| 装完 DSH 起不来 / 白屏 | 手动删 node_modules，越删越乱 | 读 `%USERPROFILE%\.dsh\logs` 的报错栈，定位到具体包 |
| 某个插件加载失败（GUI 红字） | 关掉不用 | 比对 `inventory.json` 的 `pluginRows` 与 `cordis.patch.yml`，判断条目缺了还是 config 形状变了 |
| 想换成自己的中转站 / 换模型 | 手改 yml 改错缩进 | 改 `cordis.patch.yml` + `.credentials.yaml`，改完自检 |
| 想加包里没有的插件 | 直接 `pnpm add`，把 workspace 弄坏 | 走官方 CLI `add`，再补 `cordis.patch.yml` 条目 |
| 服务包起不来（ReMe / OpenViking / Hindsight） | 反复双击 `SETUP-SERVICES.cmd` | 读 `services-install-result.json` + `logs\err.log`，判断缺库、端口还是模型凭据 |

**判断标准**：只要需要「先看一眼现场才能决定下一步」，就该交给 agent —— 它的强项是批量读文件、批量跑命令、把结论写成一句人话。

---

## 2. 怎么把上下文喂给 agent

### 2.1 该给它的文件

| 路径 | 里面有什么 | 为什么需要 |
| --- | --- | --- |
| `%LOCALAPPDATA%\DSHPluginsPack\v2.1.3-windows\installation-result.json` | 上次安装的完整结果（`ok`、失败项、错误原文） | 判断「装到哪一步断的」 |
| `%LOCALAPPDATA%\DSHPluginsPack\last-result.json` | 最近一次任意动作（install / verify / doctor / rollback）的结果 | 最新现场，比上一份新 |
| `…\v2.1.3-windows\backups\<时间戳>\deps-before.json` | 安装前 `{at, mode, dependencies, bundles}` 快照 | 回滚的唯一事实依据 |
| `%USERPROFILE%\.dsh\profiles\desktop\cordis.patch.yml` | 真正生效的插件条目（`id` / `name` / `config`） | 条目对不上就是这里对不上 |
| `%USERPROFILE%\.dsh\profiles\desktop\package.json` | 当前 profile 的 dependencies | 与 `deps-before.json` 对比即知包动了什么 |
| `%USERPROFILE%\.dsh\logs` | 运行日志，报错栈都在这 | 定位到具体包 / 具体行 |
| 包自带 `inventory.json` / `migration.json` | `pluginRows` 共 256 条、`kernel.recorded`、packages、skills | 核对基准 |
| `VERIFY.cmd` / `DOCTOR.cmd` 输出 | 人可读体检结果 | 省掉 agent 自己跑一遍的来回 |

一次抓成一份目录丢给 agent 更省事：

```powershell
$out = "$env:TEMP\dsh-context"; New-Item -ItemType Directory -Force $out | Out-Null
$store = "$env:LOCALAPPDATA\DSHPluginsPack"; $prof = "$env:USERPROFILE\.dsh\profiles\desktop"
$b = Get-ChildItem "$store\v2.1.3-windows\backups" -Directory | Sort-Object Name -Desc | Select -First 1
Copy-Item "$store\v2.1.3-windows\installation-result.json","$store\last-result.json",`
          "$prof\cordis.patch.yml","$prof\package.json",`
          "$($b.FullName)\deps-before.json","$env:USERPROFILE\.dsh\logs\*.log" $out -ErrorAction SilentlyContinue
Get-ChildItem $out | Select-Object Name, Length
```

### 2.2 提示词模板（直接复制改占位）

```text
背景：我装了「DeepSeek Harness 插件整合包 v2.0.0」，它记录的内核版本是 0.2.1-rc.2。
现在的问题是：【一句话写症状，例：GUI 里 dsh-memory-fusion 加载失败，红字如下……】

现场材料都在这个目录，请先全部读一遍，不要动任何文件：
- %TEMP%\dsh-context\            （安装结果、cordis.patch.yml、package.json、deps-before.json、日志）
- 【包路径】\inventory.json       （pluginRows 基准，256 条）
- 【包路径】\migration.json       （kernel.recorded / packages / skills / modes）

DSH 安装目录（Desktop 根）：【`%LOCALAPPDATA%\Programs\DeepSeek Harness`】。内核版本请你自己核对，不要用我说的。

请分两轮做，不要一轮做完：
第一轮（只读诊断）：跑核对脚本，回答三个问题——
  1) node_modules\@deepseek-ai\dsh-desktop-host\lib\cli.js 还在吗；
  2) @deepseek-ai/dsh-app-boot 的 loadProfileDirectory / writeProfileBundles / composeEntries
     三个导出还在吗、还是不是 function；
  3) cordis.patch.yml 的条目 id 有多少条在 inventory.json 的 pluginRows 里命中，列出没命中的。
把结论写成表格，指出根因，给 2 个以内可选方案（含风险与回滚办法）。这一轮不要改文件。

第二轮（动手）：等我确认方案再改。改之前：
  - 把要改的每个文件先复制成 <文件名>.bak-<时间戳>；
  - 只改必要行，不重排整个 yml、不顺手升级无关依赖；
  - 不要碰 cordis.yml（它必须保持 []）；不要把 .credentials.yaml 的内容打印出来或写进文档；
  - 不删 %LOCALAPPDATA%\DSHPluginsPack\ 下的 backups。
改完自己自检：重跑核对脚本 + 启动 DSH 确认能进 GUI，把改动前后 diff 与自检结果一起发我。

如果判断根因是内核结构变化导致包本身没法适配，直接说清楚是哪个入口/哪个导出变了，不要凑方案硬改。
```

模板里刻意留的三条纪律值得单独记住：**先只读**（读不清就改等于同时变动两个变量，出问题就无从归因）、**改前备份**（`<文件名>.bak-<时间戳>` 比任何工具都可靠）、**改后自检**（只看「好像不报错了」不算验证）。

---

## 3. 内核版本适配（这一节写给 agent 看）

### 3.1 基准是什么

`migration.json`：`{"kernel":{"required":">=0.2.0 <0.3.0","recorded":"0.2.1-rc.2"}}`。

- `recorded` 是打包那一刻的实测版本，**依赖形状、条目 id、函数签名都以它为准**。
- `required` 是作者声明的可用区间；安装器本身只读 `recorded` 做提示，不会按区间拦你（推断）。
- 实际内核版本以 exe 为准：`node_modules\@deepseek-ai\dsh-app-boot\package.json` 的 `version`。

### 3.2 换版本后必须核对的三件事

| # | 核对对象 | 通过标准 | 不通过意味着 |
| --- | --- | --- | --- |
| A | `<Desktop>\resources\app.asar\dsh\node_modules\@deepseek-ai\dsh-desktop-host\lib\cli.js` | 文件存在 | 官方 plugin CLI 入口没了。`install-helper.cjs` 的 `locate()` 靠它挂载插件，会直接退出 |
| B | `@deepseek-ai/dsh-app-boot` 的 `loadProfileDirectory` / `writeProfileBundles` / `composeEntries` | 三个都存在且 `typeof === 'function'` | 安装器「装完自校验」那步会失败（它拿这三个函数读 profile、写 bundle、核对条目）。改名/挪包是最常见的破坏方式 |
| C | `cordis.patch.yml` 的条目 `id` | 全部能在 `inventory.json` 的 `pluginRows` 里找到 | 死条目：插件装了没启用，或启用了一个不存在的 id |

三条全过 → 按原流程装；任一条不过 → 按 3.5 定方案，先别装。

### 3.3 核对脚本（可直接跑）

**陷阱先说**：`app.asar` 是单个归档（本机实测 182,794,869 字节），里面的 JS 只有 Electron 的 `fs` 认。纯 PowerShell 的 `Test-Path "…\app.asar\dsh\node_modules\…"` 会返回 `False`，**别把它当作「文件不存在」的证据**。核对必须经 exe，用 `ELECTRON_RUN_AS_NODE` 模式跑。

**A + B 一次查完**

```powershell
$Desktop = "$env:LOCALAPPDATA\Programs\DeepSeek Harness"   # 换成你的安装目录
$Exe = Join-Path $Desktop "DeepSeek Harness.exe"
$env:ELECTRON_RUN_AS_NODE = "1"
$env:DSH_NM = Join-Path $Desktop "resources\app.asar\dsh\node_modules"
& $Exe -e @'
const fs = require("fs"), path = require("path"), nm = process.env.DSH_NM;
const boot = path.join(nm, "@deepseek-ai/dsh-app-boot");
const say = (k, v) => console.log(k.padEnd(30), v);
say("kernel version", fs.existsSync(path.join(boot, "package.json"))
  ? JSON.parse(fs.readFileSync(path.join(boot, "package.json"), "utf8")).version : "N/A");
say("app-boot index.js", fs.existsSync(path.join(boot, "lib/index.js")));
say("desktop-host cli.js", fs.existsSync(path.join(nm, "@deepseek-ai/dsh-desktop-host/lib/cli.js")));
if (fs.existsSync(boot)) {
  const m = require(boot);
  for (const k of ["loadProfileDirectory", "writeProfileBundles", "composeEntries"]) say("export " + k, typeof m[k]);
  say("export count", Object.keys(m).length);
}
'@
```

本机 `0.2.1-rc.2` 实测形态：版本 `0.2.1-rc.2`、`cli.js` 存在、`export count 59`、三个关键导出均为 `function`。

**C 条目命中比对**

```powershell
$pack  = "<包目录>"
$rows  = (Get-Content "$pack\inventory.json" -Raw | ConvertFrom-Json).pluginRows.id
$ids   = Select-String -Path "$env:USERPROFILE\.dsh\profiles\desktop\cordis.patch.yml" `
           -Pattern '^\s*-\s*id:\s*(\S+)' | ForEach-Object { $_.Matches[0].Groups[1].Value.Trim('"',"'") }
"patch: $($ids.Count)  inventory: $($rows.Count)  未命中:"; $ids | Where-Object { $rows -notcontains $_ }
```

未命中列表为空 = 全部命中。有输出就把那些 id 抄给 agent，让它决定是删条目、改 id、还是补装对应包。

**官方 CLI 自身能不能跑**（最能说明内核是否兼容）：

```powershell
$env:ELECTRON_RUN_AS_NODE = "1"
& "$Desktop\DeepSeek Harness.exe" --expose-internals `
  "$Desktop\resources\app.asar\dsh\node_modules\@deepseek-ai\dsh-desktop-host\lib\cli.js" `
  plugin --profile desktop list
```

能列出已装插件 → 入口和 profile 读取链路都通；报 `Cannot find module` 或参数不识别 → 内核的 CLI 契约变了，需要适配而不是重装。

### 3.4 安装器的定位逻辑（省得反复试错）

`install-helper.cjs` 的 `locate()` 找两样东西：`dsh-app-boot\package.json`（判内核在）和 `dsh-desktop-host\lib\cli.js`（判安装器在）。缺后者时报错原文是「没有找到官方插件安装器（dsh-desktop-host/lib/cli.js），内核版本可能不匹配」——看到这句就先确认 `--desktop-dir` 指对了目录（`$env:DSH_DESKTOP_DIR` 也认），别反复双击 `INSTALL.cmd`。常见位置：`%LOCALAPPDATA%\Programs\DeepSeek Harness\DeepSeek Harness.exe`、`%ProgramFiles%\DeepSeek Harness\DeepSeek Harness.exe`。

### 3.5 三条都过 / 有一条不过，分别怎么办

| 情况 | 做法 |
| --- | --- |
| 三条全过，只是版本号不是 `0.2.1-rc.2` | 直接装，装完 `VERIFY.cmd`。版本号差异本身不构成障碍 |
| A 不过 | 让 agent 在内核里找新的 CLI 入口（`dsh-desktop-host\lib\` 下还有没有 `cli.*`、`bin` 字段指向哪），改 `install-helper.cjs` 里 `locate()` 的路径；不熟悉就别改，改用 GUI 市场手工装 |
| B 不过 | 让 agent 用 `Object.keys(require('…/dsh-app-boot'))` 找出新函数名，改安装器校验段；这是**真正要改代码**的场景，改前 `Copy-Item install-helper.cjs install-helper.cjs.bak-<时间戳>` |
| C 不过 | 只改 yml，代价最小：删死条目或改 id，改完重启 App 验证 |

---

## 4. 装崩了的三级自救

按顺序走，一级不行再下一级。每级之前先确认备份目录还在。

### 一级：`ROLLBACK.cmd`

```powershell
cd "<包目录>"
.\ROLLBACK.cmd
```

`install-helper.cjs` 的 `rollbackMode` 做四件事：从最近的 `backups\<时间戳>` 还原配置文件（`cordis.yml`、`cordis.patch.yml`、`pnpm-lock.yaml`、`pnpm-workspace.yaml`，`package.json` 不整份覆盖）→ 按 `deps-before.json` 逐条恢复 `dependencies`（不会顺手删你自己加的包）→ 删掉本包新增的 `link:` 挂载 → 还原技能目录。结果写进 `installation-result.json` 与 `last-result.json`，先看 `ok`。`install.ps1` 里也有 rollback 动作（参数名以文件头 `param` 块为准）。

### 二级：按 `deps-before.json` 手工还原 `package.json`

一级没修好（配置回来了但依赖树还是坏的），就只动 `package.json`：

```powershell
$prof  = "$env:USERPROFILE\.dsh\profiles\desktop"
$store = "$env:LOCALAPPDATA\DSHPluginsPack\v2.1.3-windows"
$b = Get-ChildItem "$store\backups" -Directory | Sort-Object Name -Desc | Select-Object -First 1
$before = Get-Content "$($b.FullName)\deps-before.json" -Raw | ConvertFrom-Json
Copy-Item "$prof\package.json" "$prof\package.json.bak-$(Get-Date -f yyyyMMdd-HHmmss)" -Force
$pkg = Get-Content "$prof\package.json" -Raw | ConvertFrom-Json
$pkg.dependencies = $before.dependencies
$pkg | ConvertTo-Json -Depth 20 | Set-Content "$prof\package.json" -Encoding UTF8
# 对照：还原前后依赖名差异
Compare-Object $before.dependencies.PSObject.Properties.Name `
  (Get-Content "$prof\package.json" -Raw | ConvertFrom-Json).dependencies.PSObject.Properties.Name
```

`deps-before.json` 里还有 `bundles` 字段，还原条目时用它比对自己少没少。

### 三级：清空 profile 依赖，用 C 模式重装

前两级都失败（`node_modules` 已经被写坏），推倒重来。**用改名代替删除**，留退路：

```powershell
$prof = "$env:USERPROFILE\.dsh\profiles\desktop"; $stamp = Get-Date -f yyyyMMdd-HHmmss
Rename-Item "$prof\node_modules"   "node_modules.broken-$stamp"
Rename-Item "$prof\package.json"   "package.json.broken-$stamp"
Rename-Item "$prof\pnpm-lock.yaml" "pnpm-lock.yaml.broken-$stamp" -ErrorAction SilentlyContinue
```

然后跑 `INSTALL.cmd`，菜单选 **C（备份后覆盖）**：C 模式会先给当前现场再做一份备份，再铺包装。装完 `VERIFY.cmd` + `DOCTOR.cmd` 双确认。确认稳定之后再删 `.broken-<时间戳>` 那几个目录——确认之前别动。

---

## 5. 扩展包：想加包里没有的插件

| 路径 | 命令 / 操作 | 适用 |
| --- | --- | --- |
| 官方 CLI | `plugin --profile desktop add <pkg>@<ver>` | 知道包名版本，想脚本化 |
| GUI 市场 | 设置 →「插件」→ 市场里搜装 | 不想记包名 |
| 本地插件 | `add "link:D:\path\to\your-plugin"` | 自己写的、或从别处拷来的源码目录 |

```powershell
$env:ELECTRON_RUN_AS_NODE = "1"
$Exe = "$env:LOCALAPPDATA\Programs\DeepSeek Harness\DeepSeek Harness.exe"
$Cli = Join-Path (Split-Path $Exe) "resources\app.asar\dsh\node_modules\@deepseek-ai\dsh-desktop-host\lib\cli.js"
& $Exe --expose-internals $Cli plugin --profile desktop add @scope/pkg-name@1.2.3      # registry 包，锁版本
& $Exe --expose-internals $Cli plugin --profile desktop add "link:D:\work\my-plugin"   # 本地目录，改代码即时生效
& $Exe --expose-internals $Cli plugin --profile desktop list                           # 看已装
```

`add` 只把包装进 `node_modules`，**不启用**。启用要往 `%USERPROFILE%\.dsh\profiles\desktop\cordis.patch.yml` 加一条：

```yaml
- id: my-plugin-entry          # 唯一 id，建议与包名对应，命名风格参照 tool-plugin-manager
  name: "@local/my-plugin"     # 包 package.json 里的 name，不是文件路径
  config: {}
```

加完**完全退出 App 再重开**（热改 yml 不生效），然后自检：

```powershell
Select-String -Path "$env:USERPROFILE\.dsh\profiles\desktop\cordis.patch.yml" -Pattern '^\s*-\s*id:' |
  ForEach-Object { $_.Line } | Group-Object | Where-Object Count -gt 1     # 1) id 是否重复
Get-ChildItem "$env:USERPROFILE\.dsh\logs" -Filter *.log |
  Select-String -Pattern 'my-plugin' | Select-Object -Last 20             # 2) 重启后有无加载记录
```

---

## 6. 禁止事项清单

| 别做 | 为什么 |
| --- | --- |
| 手改 `cordis.yml` | 它必须是 `[]`。文件里写着「Edit cordis.patch.yml, not this file.」——写进去的内容会被下一次写入覆盖，改动白做，还可能让 profile 加载失败 |
| 把 `.credentials.yaml` 提交到任何仓库 / 贴进对话 | 中转站密钥明文在 `%USERPROFILE%\.dsh\.credentials.yaml`，进了 git 历史等于公开 |
| 删 `%LOCALAPPDATA%\DSHPluginsPack\` 下的 `backups` | 那是三级自救唯一依据（`deps-before.json`），删了只剩重装 |
| 没有备份就跑 `pnpm install` | 会按当前（可能已坏的）`package.json` 重算整棵树，`link:` 依赖被替换成 registry 版本，插件大面积失效 |
| 只改 `package.json` 不重开 App | 依赖树改了但进程没重载，验证结果不可信 |
| 装完不复跑核对脚本就宣布成功 | 第 3 节三条核对是唯一客观判据 |

**收尾一句**：把 **包路径、Desktop 路径、第 2.2 节模板** 三样交给 agent，读文件、比对、改、自检它自己做。你要守的只有两条——**改前有备份，改后有核对**。
