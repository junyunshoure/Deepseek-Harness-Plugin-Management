# macOS 安装说明 —— DeepSeek Harness 插件整合包 v2.1.3

这份文档只讲 Mac。Windows 用户看包根的 `README.md` 与 `INSTALL.cmd`。

---

## 1. 适用人群

你符合下面全部条件，就按本文装：

- 已经装了 **DeepSeek Harness 桌面版**（`/Applications/DeepSeek Harness.app`），内核是 **0.2.x**；
- 这台 Mac 上**还没有**这一整包插件（也就是「空壳」状态：侧边栏只有 DSH 自带的那几个）；
- 能访问 npm 源（官方源或公司/镜像源都行）。

不符合也不用急：

| 你的情况 | 该怎么走 |
| --- | --- |
| 想装完插件、但只在 Mac 上用 | 本文的「三步安装」，走网络安装 |
| 已经在 Windows 上装好这套包，只想在 Mac 复刻 | 同样走网络安装；Windows 的 `payload/` 在 Mac 上**不可用**（原因见第 5 节） |
| 目标机长期离网 | 先在一台同平台同架构的 Mac 上跑 `build-payload-on-mac.command --build`，再 `install.command --offline --payload <目录>` |
| 只是想要本地记忆服务（ReMe / OpenViking / Hindsight） | 跑 `setup-services.command` |
| 内核不是 0.2.x | 先升级/降级 App，或把 `installation-result-mac.json` 之类的现场信息交给 DSH 里的 AI agent 适配 |

---

## 2. 前置条件

1. **macOS 12 (Monterey) 或更高**。Apple Silicon 与 Intel 都支持。
2. **DeepSeek Harness.app 已启动过至少一次**，这样 `~/.dsh/profiles/desktop/` 才会生成。检查：
   ```bash
   ls ~/.dsh/profiles/desktop
   # 期望看到 package.json / cordis.yml / pnpm-lock.yaml
   ```
   没有就先打开 App，登录/关掉，再看一次。
3. **能访问 npm 源**。公司网络常见要镜像，安装时加参数即可：
   ```bash
   ./install.command --registry https://registry.npmmirror.com
   ```
   或者先导出环境变量：`export DSH_NPM_REGISTRY=https://registry.npmmirror.com`
4. **磁盘 ≥ 2 GB**（插件本体 + pnpm 的硬链接缓存）。
5. **不需要装 Node.js**。安装器把 App 自带的 Electron 当 node 运行时用：
   ```bash
   ELECTRON_RUN_AS_NODE=1 "/Applications/DeepSeek Harness.app/Contents/MacOS/DeepSeek Harness" ...
   ```
   这也是 mac 版不依赖 `brew install node` 的原因。

---

## 3. 三步安装

### 第 1 步：解压

用系统「归档实用工具」或 Keka / The Unarchiver 解压 `DSH-Plugins-v2.1.3.zip`，得到：

```
DSH-Plugins-v2.1.3/
├── config/                 # 配置与 47 篇功能说明
├── payload/                # Windows 版离线依赖（Mac 上用不到，见第 5 节）
├── macos/
│   ├── install.command
│   ├── setup-services.command
│   ├── build-payload-on-mac.command
│   └── INSTALL-MAC.md      # 本文
└── migration.json          # 33 个包的清单：32 个 registry + 6 个 local-link
```

**不要在压缩包里直接双击运行脚本**，先完整解压到本地磁盘（例如 `~/Downloads/DSH-Plugins-v2.1.3/`）。

### 第 2 步：右键打开 install.command

第一次必须右键 →「打开」，不要直接双击（macOS 会给下载来的脚本加隔离标记，直接双击会被拦）。

如果还是被拦，或者提示「无法验证开发者」，在终端里去掉隔离标记并补执行权限：

```bash
cd ~/Downloads/DSH-Plugins-v2.1.3/macos
xattr -d com.apple.quarantine install.command setup-services.command build-payload-on-mac.command
chmod +x install.command setup-services.command build-payload-on-mac.command
./install.command
```

> `xattr -d` 只删这一个文件的「来自互联网」标记，不改任何系统安全设置。
> 不想动 xattr 也可以：右键 →「打开」→ 弹窗里再点「打开」。

### 第 3 步：按提示操作

脚本会做 8 步，全程中文，每一步都打印结果：

| 步骤 | 做什么 | 失败时的补救（脚本也会打印） |
| --- | --- | --- |
| 1/8 定位 App | 找 `/Applications/DeepSeek Harness.app`，支持 `--app` 与 `DSH_APP` | 用 `--app "/路径/DeepSeek Harness.app"` 指定 |
| 2/8 读内核版本 | 读 `app.asar/dsh/node_modules/@deepseek-ai/dsh-app-boot/package.json`，要求 `0.2.x` | 升级/降级 App；确知原因时加 `--skip-kernel-check` |
| 3/8 解析清单 | 从 `migration.json` 分出 32 个 registry 包、6 个 local-link 包 | 用 7-Zip/Keka 重新解压 |
| 4/8 备份 | `package.json`、`pnpm-lock.yaml`、`pnpm-workspace.yaml`、`cordis.yml`、`cordis.patch.yml` → `~/.dsh/profiles/desktop/backups/mac-<时间戳>/` | — |
| 5/8 写配置 | `config/*.yml` 拷进 profile；**已存在就保留原文件**，另存 `.pack-sample` | — |
| 6/8 装插件 | 逐个 `dsh plugin --profile desktop add --save-exact <包>@<版本>`（联网），单个失败不影响后续 | 换镜像 / 单独重试 / 看 `plugin-install.log` |
| 7/8 装技能 | `payload/skills/dsh/*` → `~/.dsh/skills/`；`payload/skills/agents/*` → `~/.agents/skills/`（旧的先备份再覆盖）；`config/feature-profiles/` → profile（已存在不覆盖） | — |
| 8/8 汇总 | 打印成功/失败/备份位置/下一步，并写 `~/.dsh/profiles/desktop/installation-result-mac.json` | — |

常用参数：

```bash
./install.command --dry-run                 # 只检查 + 列出要装的包，不写文件
./install.command --registry https://registry.npmmirror.com
./install.command --app "$HOME/Applications/DeepSeek Harness.app"
DSH_APP="/Applications/DeepSeek Harness.app" ./install.command
```

装完打开 App。第一次启动会慢一点（插件在加载、pnpm 在链接依赖）。然后到设置里填**中转站地址与密钥**。

---

## 4. 与 Windows 版的差异

| 维度 | Windows（`INSTALL.cmd` + `payload/`） | macOS（`install.command`） |
| --- | --- | --- |
| 依赖来源 | 包内 `payload/node_modules` 离线复制 | `dsh plugin add` 从 npm 源**当场装** |
| 网络 | 不需要 | **需要**（可用 `--registry` 换镜像） |
| Node 运行时 | App 自带 Electron（`ELECTRON_RUN_AS_NODE=1`） | 同左，用户机器不需要装 Node |
| 原生模块 | `.node` 是 PE（win32-x64） | 现场编译/下载 mach-o（arm64 / x86_64），平台天然正确 |
| 本地 6 插件 | 有实体（`link:` 目录/打包副本） | **缺失**：`dsh-feature-profiles`、`dsh-memory-fusion`、`dsh-skill-fusion`、`dsh-ollama`、`dsh-purge`、`@local/dsh-client-ui-workbench` |
| 服务本体 | `SETUP-SERVICES.cmd` 装 ReMe/OpenViking/Hindsight | `setup-services.command`，用 `uv`；WeKnora 用 Docker |
| 安装模式 | 全新 / 智能合并 / 备份覆盖（A/B/C 菜单） | 单一流程：已装即保留，失败逐个续装 |
| 回滚 | `ROLLBACK.cmd` | `backups/mac-<时间戳>/` 手动覆盖（见第 6 节） |
| 结果文件 | `installation-result.json` | `installation-result-mac.json` |

### 那 6 个本地插件为什么没有

它们是作者本机的开发目录（`link:` 到 `D:/AI work space/...`），没有发布到 npm，压缩包里也没有实体文件。Mac 上安装器会打印一行说明并跳过，不会报错。想真用，让 DSH 里的 AI agent 按 `docs/AI-agent-适配指南.md` 在本机重建（照着 `migration.json` 里对应条目的 `name`/`version` 做）。

---

## 5. 为什么 Mac 不能用包里的 payload

`payload/node_modules` 是在作者的 Windows x64 机器上 `pnpm install` 出来的。里面这些包带原生二进制：

```
sharp/                     # 图像处理
cpu-features/  ssh2/       # SSH 相关
lightningcss-win32-x64-msvc/
cloudflared/
```

它们的 `.node` 文件是 **PE/COFF（Windows）** 格式。macOS 的 dyld 只会加载 mach-o，硬拷过去会在插件启动时报：

```
dlopen(...): mach-o, but wrong architecture
cannot open shared object file
```

所以 mac 安装器**根本不碰** `payload/node_modules`，而是走网络安装。要离线也在 Mac 上重建一份（`build-payload-on-mac.command --build`），并且记住：**原生模块只在同平台同架构可用**，arm64 的产物不能给 Intel Mac，也不能给 Windows。

---

## 6. 常见问题

**Q1：双击没反应 / 提示「无法打开，因为无法验证开发者」**
右键 →「打开」；还不行就在终端里跑第 3 节那三条命令（`xattr -d` + `chmod +x` + `./install.command`）。

**Q2：`Permission denied`**
```bash
chmod +x install.command setup-services.command build-payload-on-mac.command
```

**Q3：npm 源太慢 / 一半包失败**
```bash
./install.command --registry https://registry.npmmirror.com
```
已经装成功的包 pnpm 不会重下；失败清单会打印，也可以单独重试一个：
```bash
ELECTRON_RUN_AS_NODE=1 "/Applications/DeepSeek Harness.app/Contents/MacOS/DeepSeek Harness" \
  --expose-internals "/Applications/DeepSeek Harness.app/Contents/Resources/app.asar/dsh/node_modules/@deepseek-ai/dsh-desktop-host/lib/cli.js" \
  plugin --profile desktop add --save-exact dsh-market@1.66.28
```

**Q4：装完插件没出现在侧边栏**
1. 完全退出 App（⌘Q，不是关窗口），再打开；
2. 看 `~/.dsh/profiles/desktop/package.json` 的 `dsh.profile.bundles` 里有没有那个包名；
3. 看 `~/.dsh/profiles/desktop/backups/mac-<时间戳>/plugin-install.log` 有没有报错；
4. 有些插件只在特定入口出现（例如 `dsh-skill-fusion` 在 设置 → 技能），先翻插件自己的说明。

**Q5：`内核版本是 0.2.5，本整合包只适配 0.2.x` 之类的提示**
0.2.x 都能装；只有 major.minor 不是 0.2 才会被拦。真要在别的内核上试：`--skip-kernel-check`，然后把结果交给 AI agent 复核。

**Q6：怎么回滚（把 profile 恢复到装之前）**
每次安装都会留一份完整备份。回滚 = 用备份覆盖回去：

```bash
ls ~/.dsh/profiles/desktop/backups/          # 找出 mac-<时间戳>
BK=~/.dsh/profiles/desktop/backups/mac-20261028-203000
cp -p "$BK"/package.json "$BK"/pnpm-lock.yaml "$BK"/cordis.yml "$BK"/cordis.patch.yml \
      ~/.dsh/profiles/desktop/
# 技能也回了：
cp -R "$BK/skills/dsh/." ~/.dsh/skills/ 2>/dev/null
cp -R "$BK/skills/agents/." ~/.agents/skills/ 2>/dev/null
```
然后重启 App。备份里没有的文件（例如新装的包目录）不会自动删除；要彻底干净可以 `rm -rf ~/.dsh/profiles/desktop/node_modules` 后重启 App，让 dsh 按 `package.json` 重装。

**Q7：想重装一遍**
直接再跑 `install.command` 即可：已装的包会被 pnpm 识别，配置已存在会保留原文件，脚本会再生成一份新备份。

**Q8：`setup-services.command` 说找不到 `uv`**
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"
```
重开终端再跑脚本，或加 `--yes` 让它自己装。

**Q9：服务起来了但 DSH 连不上**
```bash
for p in 2333 1933 8888; do printf "%s -> " "$p"; curl -s -o /dev/null -m 2 -w "%{http_code}\n" "http://127.0.0.1:$p/"; done
```
`000` = 没起；`200/401/404` = 进程在跑。再确认 DSH 设置里填的是 `127.0.0.1`（不是 `localhost`，某些代理会把 localhost 走 IPv6）。

---

## 7. 装崩了怎么办

**一句话：把下面这段连同 `~/.dsh/profiles/desktop/installation-result-mac.json` 一起发给 DSH 里的 AI agent。**

```
这台 Mac 装了 DSH 插件整合包 v2.1.3（macos/install.command，网络安装路线），出问题了。
现场信息：~/.dsh/profiles/desktop/installation-result-mac.json
备份目录：~/.dsh/profiles/desktop/backups/mac-<时间戳>/
App：/Applications/DeepSeek Harness.app
现象：（把报错原文 / 截图文字贴在这里）
请按 docs/AI-agent-适配指南.md 定位：
  1) 先读 installation-result-mac.json，看 failed 列表与 kernelVersion；
  2) 需要时用 backups 目录回滚，再逐个重装；
  3) 是那 6 个 local-link 插件缺失的话，在本机重建（该指南里有做法）。
```

AI agent 能拿到的现场包括：失败的包清单、日志尾部、内核版本、配置有没有被覆盖、技能装到哪、备份在哪。它不用你复述，读文件就行。

---

## 8. 文件清单

| 文件 | 用途 |
| --- | --- |
| `macos/install.command` | 一键安装（网络安装路线，双击可运行） |
| `macos/setup-services.command` | ReMe(2333) / OpenViking(1933) / Hindsight(8888) 安装向导，WeKnora 走 Docker |
| `macos/build-payload-on-mac.command` | 在这台 Mac 上重建离线 payload（多数人不需要） |
| `macos/INSTALL-MAC.md` | 本文 |
