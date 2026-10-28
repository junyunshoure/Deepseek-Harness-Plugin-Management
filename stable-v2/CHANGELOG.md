# 更新日志

本文件记录「DSH 插件整合包」每个版本的差异。格式：版本 → 新增 / 变更 / 修复 / 已知限制。
每个版本的详细改造说明见 `docs/新功能说明.md`，v1 的历史说明见仓库 `UPDATE-v1.0.0-NOTES.md`。

---

## v2.0.0 — 2026-10-28（大版本）

**一句话**：从「只能照着 v1 手动搬配置」升级为「空壳机器双击装完就能用」，并把本机六个自研插件、四个本地记忆服务、47 篇能力手册、macOS 通道一起纳入。

### 新增

| # | 新增能力 | 位置 |
|---|---|---|
| 1 | 六个本地自研插件实例化入包（见下表） | `payload/node_modules/` |
| 2 | 安装器三模式菜单（新建 / 补缺 / 备份覆盖），目标已有插件时不再直接失败 | `install.ps1`、`install-helper.cjs` |
| 3 | 配置层自动套用：只补缺不覆盖，写前备份（`config/` 从「只读参考」变为「可选用」） | 安装器 `--apply-config` |
| 4 | 本地记忆服务本体包（ReMe / OpenViking / Hindsight / WeKnora），独立压缩包 | `DSH-Plugins-v2.0.0-Services.zip` |
| 5 | macOS 通道：`macos/install.command` + 在 Mac 上自行生成 payload 的脚本 + 服务安装脚本 | `macos/` |
| 6 | 47 篇功能档位手册随包装载（插件的 `featureProfiles` 目录） | `config/feature-profiles/` |
| 7 | 6 个技能包（hindsight-coding-agent、reverse-engineer-anything、cli-anything、cli-hub-meta-skill、solidworks-automation、writing-for-agents） | `payload/skills/` |
| 8 | `DOCTOR.cmd` 体检、`ROLLBACK.cmd` 回滚、`UNINSTALL.cmd` 卸载三个入口 | 包根 |
| 9 | `inventory.json` / `checksums.json` / `installation-result.json` 三份可机读凭据 | 包根 / `%LOCALAPPDATA%\DSHPluginsPack` |
| 10 | 文档：使用说明书、新功能说明、配置参考、服务部署指南、AI-agent 适配指南、常见问题 | `docs/` |

### 变更

- **技能管理换代**：v1 里的 `dsh-skill-hub`、`dsh-my-skill-manager` 由 `dsh-skill-fusion`（技能融合中心）取代；旧包仍随包分发但默认 `disabled: true`，需要时可在 GUI 里单条启用。
- **配置快照脱敏**：`config/cordis.patch.yml` 内 9 处中转站地址统一替换为占位符 `https://YOUR-ENDPOINT.example.com`，密钥一律不进包（只保留 `apiKeyEnv` 的键名）。
- **安装器不再只看版本相等**：内核是 `0.2.x` 且官方插件 CLI 入口仍在时允许继续安装并给出降级提示；`--force` 可强装任意版本。
- **payload 收集规则**：引用型目录（junction / symlink）不再复制实体，改为记录到 `inventory.json.skippedSymlinks`（506 条），再由 6 个本地插件实体覆盖，避免体积翻倍与死链。
- **校验范围扩大**：逐文件 SHA-256 从 v1 的 17,453 个提升到 23,249 个；发布前跑 `release-validation.json` 断链检查。

### 修复

- 修掉 v1 安装器在「profile 里已经有第三方插件」时直接中止的问题（现在走三模式菜单）。
- 修掉 v1 的 `cordis.patch.yml` 全量复制会覆盖用户已有模型配置的问题（现在逐条补缺，已有条目不动）。
- 修掉 workbench 面板 `config.root` 写死本机绝对路径、换机后页面空白的问题（改为 `%USERPROFILE%` 下的约定目录 + 安装时询问）。
- 修掉服务包 venv 不可搬迁的问题：不再复制 `.venv`，改为「独立 CPython + site-packages 快照 + 现场建 venv」。

### 已知限制

- 服务本体包按 **Windows x64** 构建；macOS 用 `macos/setup-services.command` 现装（需要本机 python3.12+ 与网络）。
- WeKnora 是 Linux (Go) 服务，Windows 上通过 WSL 运行，需要系统装 WSL2；不装则只影响 WeKnora 一档功能。
- 包记录的内核为 `0.2.1-rc.2`。换内核版本时插件不保证二进制兼容，需按 `docs/AI-agent-适配指南.md` 让 agent 复核一遍。
- 本地插件是 `link:` 形态装进 profile 的，链接指向持久目录 `%LOCALAPPDATA%\DSHPluginsPack\v2.0.0-windows`。解压目录装完可删，持久目录删了插件就失效（用 `UNINSTALL.cmd` 才是正规卸载）。

---

## v1.0.0 — 2026-10-27

首个公开包：36 个 bundle、32 个第三方插件、配置快照只读、`install.ps1` 用官方 CLI 以 `link:` 注册，17,453 个文件逐文件校验。
当时不含任何本地自研插件、不含服务本体、不含 macOS 通道，配置需要用户照文档手动搬。
详见仓库 `UPDATE-v1.0.0-NOTES.md`。
