# DeepSeek Harness 配置包 正式版 v1.0.0（Windows x64）

本包把一台已经配置完成的 DSH Desktop 的插件与配置，离线搬到一个全新的 DSH Desktop 上：
32 个第三方插件包 + 4 个内置 bundle，共 36 个 bundle、247 条插件组合行，
插件启用/禁用状态、界面偏好、模型提供方清单等设置一并保留。

- 版本：`1.0.0`（正式版第一版）
- 打包时间：2026-10-22
- 内核要求：DSH `0.2.1-rc.2`
- 平台：Windows x64

## 一、安装前

1. 先安装**同版本**（`0.2.1-rc.2`）的 DSH Desktop，并**打开一次**让它初始化 profile，然后**从托盘完全退出**（不是最小化）。
2. 把 ZIP 解压到较短路径，例如 `D:\DSH-Plugins-v1.0.0`（路径过长可能失败）。
3. 目标必须是**刚初始化、没有装过任何第三方插件**的 Desktop。安装器发现已有第三方插件会**停止**，不会删除你的东西。
4. 可选：先双击 `VERIFY.cmd` 只做文件校验，不改动任何东西。

## 二、安装

双击 `INSTALL.cmd`。它会：

1. 定位本机的 Desktop 安装目录（找不到会让你选 `DeepSeek Harness.exe`）；
2. 校验包内每个文件的 SHA-256；
3. 核对内核版本与目标 profile 状态；
4. 把包复制到持久目录 `%LOCALAPPDATA%\DSHPluginMigration\plugins-20261022-stable`；
5. 备份目标 profile 的配置文件；
6. 用 Desktop 自带的官方 CLI 离线逐个安装插件（`--offline --ignore-scripts --save-exact`）；
7. 逐条比对插件组合结果（247 行）后写出 `installation-result.json`。

安装完成后再启动 Desktop。首次启动加载 32 个插件会明显变慢，属正常现象。

## 三、安装后

- **不要删除** `%LOCALAPPDATA%\DSHPluginMigration\plugins-20261022-stable`：插件是以本地链接方式装进去的，删了插件就没了。安装成功后原 ZIP 和解压目录可以移走。
- 想恢复本机原来的状态：安装器在持久目录的 `backups\<时间戳>\` 里保存了安装前的 `package.json`、`cordis.patch.yml` 等文件。

## 四、包内包含什么

| 内容 | 说明 |
| --- | --- |
| `payload/node_modules/` | 32 个插件包及其依赖（17,000+ 文件，解压约 400MB） |
| `payload/migration-state/` | 247 条插件组合行的启用/禁用状态（作为辅助 bundle 安装） |
| `config/` | 打包时的完整配置快照：`cordis.patch.yml`、`package.json`、`cordis.yml`、`pnpm-workspace.yaml`，以及还原说明 |
| `checksums.json` | 包内每个文件的 SHA-256 |
| `inventory.json` / `migration.json` | bundle、包、插件行的结构化清单 |
| `plugins.csv` / `bundles.csv` / `插件完整清单.txt` | 同样的清单，便于直接查看 |
| `release.json` | 版本与发布元数据 |

## 五、不包含什么（重要）

- 账号、登录状态、API Key、`.credentials.yaml`
- 聊天记录、任务、会话存档
- 浏览器用户数据、Zotero 文献库、个人壁纸与媒体文件

`config/cordis.patch.yml` 里只有模型提供方的地址与 `apiKeyEnv` 变量名（如 `OPENAI_API_KEY`），**没有密钥值**。想沿用同样的模型设置，需自行设置同名环境变量；不想沿用就别覆盖该文件（详见 `config/README.md`）。

## 六、已知限制

- 仅支持 Windows x64 与内核 `0.2.1-rc.2`；其他版本会被拒绝。
- 安装过程**不是原子操作**：中途失败会留下已装好的部分包，可重跑同一份包继续；失败时会给出备份路径。
- 未在第二台物理电脑上验证 GUI 表现；插件的外部功能（联网、账号、外部程序）仍需各自配置。
- 第三方插件各自的版权与许可证随包保留，本包不改变其授权。

## 七、校验

```
certutil -hashfile DSH-Plugins-v1.0.0-Windows-x64.zip SHA256
```

与发布页提供的 `.sha256` 文本比对即可。
