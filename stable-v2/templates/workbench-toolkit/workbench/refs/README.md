# refs · 外部参考与规格（只读）

本目录存放从外部仓库搬来的**规格文档**，只作查阅依据，不参与运行时、不被任何脚本读取。

## 来源

- 仓库：<https://github.com/mashanglinyu/luanyujia-workbench>（MIT）
- 提交：`a33cfae5bb32b1d563ace309f227ea709dbd5477`（2026-10-28）
- 本地克隆：`_ref/luanyujia-workbench/`（浅克隆，可随时删）

## 文件

| 本目录文件 | 原路径 | 用途 |
|---|---|---|
| [面板类型总览.md](面板类型总览.md) | `01-场景模式/面板类型总览.md` | 24 种面板分 7 族；三种最常用面板（`harness` / `view` / `file`）的最小实现要点。给 `workbench-panel` 补面板类型用 |
| [场景配置格式.md](场景配置格式.md) | `01-场景模式/场景配置格式.md` | 场景 json 顶层与面板字段、加载链路、四条硬规矩、症状对照 |
| [会话绑定三字段.md](会话绑定三字段.md) | `02-会话定位与跟随/二-会话绑定三字段.md` | `pinTarget` / `sessionTitle` / `sessionId` 分工、绑定四步、一板一分区、判据只能是画面 |

**没有搬的**：`05-协作与规矩/`（三份共 187 KB，与本机 `AGENTS.md` 的 ALIGNMENT_PROTOCOL v1.0 语义重复，同时注入会互相打断）、`04-工作台搭建/踩坑总表.md`（26 条经验，按需再取）、`12-源码照搬/外壳/`（独立 Electron 应用，与本机 `workbench-panel` 插件路线互斥）。

## 与本机实现的差异（读文档时注意）

这几份文档描述的是**上游那套 Electron 外壳 + 24 种面板**。本机是 **DSH 官方 Web GUI + `@local/dsh-client-ui-workbench` 插件**，所以：

1. 本机 `workbench/scenarios/_index.md` 是 **7 列**（场景 id / 名称 / 定位卡 / 场景记忆 / 主面板 id / 会话 id / 状态），上游是 7 列但字段序与含义不同 —— 以本机 `_index.md` 为准。
2. 本机面板类型目前注册 5 种（`session` / `files` / `web` / `ledger` / `checkup`，见 [scripts/_workbench.mjs](../../scripts/_workbench.mjs) 的 `PANEL_TYPES`），不是 24 种。上游文档是**扩展候选清单**，不是现状。
3. 上游的 `pinTarget` 三字段在本机降为两字段（`sessionId` 权威 + `expectTitle` 校验）—— 依据见 [workbench/memory/plugin-eco/项目信息.md](../memory/plugin-eco/项目信息.md) §五 2026-10-21 那条决策。

## 配套脚本（已适配本机路径，不在本目录）

- [scripts/场景记忆.mjs](../../scripts/场景记忆.mjs) —— `list` / `init` / `stamp` / `交接` / `check [--all]`
- [scripts/发消息.mjs](../../scripts/发消息.mjs) —— `--to <场景> "内容"` / `--list`

适配点见两个脚本头部的「本机适配」注释块。默认读 `workbench/memory/<场景>/`，正文文件 `项目信息.md` 与 `场景私有记忆.md` 都认。
