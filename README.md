# DeepSeek Harness 插件整合包（配置包 · 装机盘）

给 **只装了一个 DeepSeek Harness 空壳**、别的什么都没有的机器用的一键装机盘：解压 → 双击 `INSTALL.cmd` → 选一个模式 → 装完自动启动 DSH。不用装 Node.js，不用手改 YAML。

当前版本：**v2.0.0**（大版本）· 适用内核 `0.2.x`（按 `0.2.1-rc.2` 构建）· Windows 10/11 x64，另附 macOS 通道

---

## 下载哪个

| 文件 | 用途 | 大小 |
|---|---|---|
| `DSH-Plugins-v2.0.0-Windows-x64.zip` | **插件包（必装）**：32 个插件 + 6 个技能 + 配置骨架 + 安装器 + 文档 | 约 182 MB |
| `DSH-Plugins-v2.0.0-Services.zip` | 服务本体包（可选）：ReMe / OpenViking / Hindsight / WeKnora 四个本地服务 | 约 680 MB |

只装插件包，DSH 一切正常，只是本地记忆/知识库入口显示「未连接」；要那四个能力再装服务包。两个包各自独立，互不依赖。

到 [Releases](../../releases/latest) 下这两个文件，同页附 `.sha256`。GitHub 自动生成的 Source code 压缩包不含插件载荷，**不能用来安装**。

---

## 三分钟装完

1. 把 `DSH-Plugins-v2.0.0-Windows-x64.zip` **完整解压**到短路径，例如 `D:\DSH-Plugins-v2.0.0`（别在压缩包里双击，别放带空格/中文的长路径）。
2. 双击 `INSTALL.cmd`，选模式：

   | 模式 | 什么时候选 | 行为 |
   |---|---|---|
   | **A 全新安装** | 机器上没装过第三方插件 | 目标 profile 必须干净，否则中止（最安全） |
   | **B 智能合并**（默认） | 已装了一些插件 | 只补缺的，已有版本与配置一律不动 |
   | **C 备份覆盖** | 想用本包版本统一覆盖 | 先整份备份，再覆盖 |

3. 等它跑完：校验 23,249 个文件 → 复制载荷到 `%LOCALAPPDATA%\DSHPluginsPack\v2.0.0-windows` → 备份 → 挂 32 个插件 → 校验 256 个条目 → 合并配置 → 装技能 → 装能力手册 → 出安装结果 → 启动 DSH。
4. **唯一需要手填的东西**：打开 DSH → 设置 → 模型，把 provider 的 `baseURL` 从 `https://YOUR-ENDPOINT.example.com` 换成你自己的中转站/官方地址并填密钥。填法见 [`stable-v2/docs/配置参考.md`](stable-v2/docs/配置参考.md)。
5. 确认没毛病：`VERIFY.cmd`（逐文件哈希）+ `DOCTOR.cmd`（环境体检）。

---

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

逐项细节与边界：[`stable-v2/docs/新功能说明.md`](stable-v2/docs/新功能说明.md)。完整变更见 [`stable-v2/CHANGELOG.md`](stable-v2/CHANGELOG.md)。

---

## 仓库结构

```
├── stable-v2/          ← v2.0.0 当前版本（源码/清单/安装器/文档，不含插件载荷）
├── stable/             ← v1.0.0 存档（不再变动，仅供回退与对照）
├── patch/              ← v1.0.0-patch.1 存档
├── demo/               ← v0.1.0-demo.1 存档
├── README.md           ← 本文件
├── RELEASE_NOTES.md    ← 当前版本发布说明
├── release-validation.json  ← 发布前自检结果（14 项）
└── LICENSE
```

`stable-v2/` 里有什么：`install.ps1` + `install-helper.cjs`（安装器）、`migration.json` / `inventory.json` / `checksums.json` / `release-validation.json`（清单与凭据）、`config/`（配置骨架 + 47 篇能力手册）、`docs/`（6 份文档）、`macos/`、`README.md`、`CHANGELOG.md`。插件载荷（`payload/`，约 503 MB）不打进仓库，只随 Release 压缩包分发。

---

## 文档导航

| 文件 | 内容 |
|---|---|
| [`stable-v2/docs/使用说明书.md`](stable-v2/docs/使用说明书.md) | 从装机到日常使用的完整手册（先读这个） |
| [`stable-v2/docs/新功能说明.md`](stable-v2/docs/新功能说明.md) | v2 相对 v1 的 10 类新增，逐项讲用途与边界 |
| [`stable-v2/docs/配置参考.md`](stable-v2/docs/配置参考.md) | 配置三层结构、每个文件能不能手改、模型接入怎么填 |
| [`stable-v2/docs/服务部署指南.md`](stable-v2/docs/服务部署指南.md) | 四个本地服务的安装、启停、排障 |
| [`stable-v2/docs/AI-agent-适配指南.md`](stable-v2/docs/AI-agent-适配指南.md) | 换内核版本 / 装崩了 / 想加功能时，怎么让 agent 自己改 |
| [`stable-v2/docs/常见问题.md`](stable-v2/docs/常见问题.md) | 按症状查的故障手册 |
| [`stable-v2/macos/INSTALL-MAC.md`](stable-v2/macos/INSTALL-MAC.md) | macOS 安装路线 |
| [`stable-v2/CHANGELOG.md`](stable-v2/CHANGELOG.md) | 版本差异与已知限制 |

---

## 出问题怎么办

1. `DOCTOR.cmd` —— 内核版本、CLI 入口、依赖完整性、链接是否断、服务端口、配置条目命中数全列出来。
2. 按症状查 [`stable-v2/docs/常见问题.md`](stable-v2/docs/常见问题.md)。
3. 装坏了：`ROLLBACK.cmd` 选一个备份退回去。
4. 还不行：把 `installation-result.json`、`DOCTOR.cmd` 输出、`%USERPROFILE%\.dsh\profiles\desktop\cordis.patch.yml` 一起丢给 DSH 里的 AI agent，让它按 [`stable-v2/docs/AI-agent-适配指南.md`](stable-v2/docs/AI-agent-适配指南.md) 处理。

## 已知边界

- **本地插件是 `link:` 形态**：载荷会被复制到 `%LOCALAPPDATA%\DSHPluginsPack\v2.0.0-windows`，链接指向那里——解压目录装完可以删，但那个持久目录不能动。彻底移除请用 `UNINSTALL.cmd`。
- **改动要重启**：改代码或改配置后需完全退出 DSH 再打开。
- **配置骨架带占位符**：不换成你自己的模型地址，只有 DSH 账号自带那档能直接对话。
- **服务包是 Windows 构建**：macOS 用 `macos/setup-services.command` 现装。
- **内核换代不保证兼容**：换到 0.3.x 先走 AI-agent 适配流程。

## 许可

MIT，见 [`LICENSE`](LICENSE)。第三方插件版权归各自作者，包内保留其原始 LICENSE 与 NOTICE；仅供个人使用，请勿用于商业倒卖。
