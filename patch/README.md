# v1.0.0-patch.1 — 逆向能力按需加载补丁

适用于：**DeepSeek Harness 配置包 正式版 v1.0.0（Windows x64）**
不改动插件本体、不改 `cordis.patch.yml`、不动任何已发布附件。

## 这个补丁解决什么

v1.0.0 之前，REA 逆向能力以 MCP 服务方式注册，一次注册 207 个工具。工具描述属于
**不可压缩的固定开销**，全部工具合计把上下文窗口撑爆，DSH 在发请求前就会以
`413 preflight_compress_failed` 拦下——换任何模型都一样失败。

现在的状态是「REA 程序还在、MCP 注册停用」。但原技能 `reverse-engineer-anything`
的正文仍是按 MCP 存在写的：它会让 agent 去跑 `rea setup` 把 MCP 重新装回来，
等于把已修好的问题再触发一次。

本补丁把技能改成两段式：

| 层 | 内容 | 何时进入上下文 |
| --- | --- | --- |
| 常驻入口 | `SKILL.md`（约 2 KB）：什么时候该用逆向、下一步读哪个文件、入口命令、边界 | 只有一段 description 常驻；正文仅在技能被触发时加载 |
| 按需手册 | `references/manual-cli.md`：CLI 语法、输出裁剪、provider 前置条件、各格式入口、平台限制、证据纪律 | 真正动手前才读 |

同时明确写死：**调用方式是本地 CLI，不是 MCP 工具**；不要执行 `rea setup` /
`rea mcp add` / 改 `cordis.patch.yml` 去「让工具出现」。

## 安装

前提：装过 v1.0.0（或本机已有 `reverse-engineer-anything` 技能）；Node 22.19+ / 24.11+ / 26+。

```powershell
# 自检（只校验文件，不写入）
powershell -ExecutionPolicy Bypass -File .\install.ps1 -CheckOnly

# 应用
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

也可双击 `INSTALL.cmd`。参数：

- `-CheckOnly`：只校验补丁包自身的 SHA-256。
- `-SkillDir <路径>`：改写到别处的技能目录（默认 `%USERPROFILE%\.agents\skills\reverse-engineer-anything`）。

写入前会把原技能整目录备份到
`%LOCALAPPDATA%\DSHPluginMigration\plugins-20261022-patch1\backup-<时间戳>\`，
结果记录在同目录的 `patch-result.json`。**技能描述会即时刷新，无需重启 Desktop**，
新会话就能看到短入口。

## 回滚

把备份目录里的 `reverse-engineer-anything` 覆盖回
`%USERPROFILE%\.agents\skills\reverse-engineer-anything` 即可，新会话生效。
本补丁没有修改 DSH 配置，所以不存在需要恢复的 `cordis.patch.yml`。

## 验证预期

应用后 `patch-result.json` 会给出：

- 技能正文字节数：23,523 → 2,781（**减少 88%**）
- 常驻 description：300 → 141 字符
- `references/` 下原有 6 个专题文件保持不变，新增 `manual-cli.md`（6,290 字节）
- `reaMcpInsertActive: false`（REA 的 MCP 注册仍处于禁用）

## 已知限制

- 补丁只改技能文件，**不会**让 REA 变成 MCP 工具；想让工具重新出现需要另建独立 profile，
  不建议在本整合包上做。
- `rea doctor --skill` 会因正文被改写而报身份不一致，这是预期结果，不要用 `rea setup` 去修。
- Windows 上 Linux 专属能力（pwntools、TShark 抓包、固件解包、信号解码）不可用；
  Apple 侧命令（Hopper/plist/macho）也不可用。
- 只有 MCP 才提供的能力（`open_binary`/`binary_session`/`close_binary`、分页 Evidence 视图）
  在 CLI 下没有等价物：CLI 返回一次性完整 Evidence，必须配合 `--filter-output` / `--token-limit`
  或先落盘再读。
- 改写后的技能**没有上游来源跟踪记录**，但技能市场若重新安装/更新同名技能，会用上游版本
  覆盖本补丁；覆盖后重跑一次 `install.ps1` 即可恢复。
