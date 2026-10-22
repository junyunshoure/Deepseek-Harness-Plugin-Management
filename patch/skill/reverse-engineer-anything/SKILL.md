---
name: reverse-engineer-anything
description: REA 逆向入口。仅当任务取决于已发布的二进制/安装包、ASAR 或 Electron 应用、运行时证据，或需要与现有源码对照时使用；普通源码仓库分析不要用。首次执行前先读 references/manual-cli.md，一律走本地 CLI，不要再注册 REA 的 MCP 服务。
metadata:
  version: "patch-1"
  distribution: cli-on-demand
---

# REA（按需逆向）

REA 6.7.0 已随整合包安装在本机，能力覆盖原生二进制、托管程序集、JS/Electron/ASAR、
包与归档、Go/Rust 元数据、SQLite、WASM、EVM 等静态分析。

本技能只承担「入口」：常驻的只有这段说明和上面的描述。真正的操作手册在
`references/manual-cli.md`，深度专题在 `references/*.md`。两者都只在需要时读。

## 何时适用

- 结论必须来自已发布产物（EXE/DLL/ELF/Mach-O/APK/IPA/PKG/ASAR），而不是可得源码。
- 用户要求反编译、伪代码、字符串/交叉引用、函数边界、程序集元数据。
- 需要把「上游宣称的行为」与「产物里实际存在的行为」对照。
- 需要被动运行时证据（已打开的页面/Electron 目标、已保存的抓包）。

普通源码仓库的结构分析、依赖梳理、代码搜索不要调用 REA，用常规工具即可。

## 第一步

执行任何 REA 命令前，先读 `references/manual-cli.md`：里面有经核对的命令语法、
输出控制、provider 前置条件、各目标格式的入口，以及哪些能力只有 MCP 才提供。
只有手册没有覆盖的深问题，才继续读对应的 `references/*.md` 专题。

## 入口

用本机 Node 直接调已安装的 CLI（不要在会话里 `npx` 拉新版本，不要跑 `setup`）：

```
node "D:\AI work space\DeepSeek Harness\插件下载与管理\REA\node_modules\rea-agents\scripts\rea.mjs" --version
```

路径以 `references/manual-cli.md` 里的解析顺序为准（`REA_ENTRY` 环境变量 → 整合包
自带的 `REA/` 目录），找不到就如实说明本机未安装 REA，不要自行下载。

## 边界

- 本整合包刻意不注册 REA 的 MCP 服务：207 个工具的描述属于不可压缩的固定开销，
  会把上下文窗口挤爆。**调用方式是 CLI，不是 MCP 工具**；不要为了「让工具出现」
  去执行 `rea setup`、`rea mcp add` 或修改 `cordis.patch.yml`。
- 静态分析不执行目标；运行时采集会真实启动或操作目标，按用户授权范围使用。
- 结论必须区分观察、推断与未知，并保留 Evidence 标识与覆盖范围；不要把静态结论
  说成「运行过」。
- Windows 下原生 provider 与抓包类能力有限，先看手册的「平台限制」，再向用户说明缺口。
