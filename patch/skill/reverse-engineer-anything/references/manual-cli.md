# REA CLI 手册（按需加载）

本文件是 `reverse-engineer-anything` 技能的正文手册：**只有真的要动逆向任务时才读**。
内容按 2026-10-22 在整合包 v1.0.0 上实测的 `--help` 校准，对应 rea-agents 6.7.0。

## 1. 解析 CLI 入口（按顺序）

1. 环境变量 `REA_ENTRY` 指向的 `rea.mjs`（或 `rea` 可执行文件）。
2. 整合包/迁移包自带的 `REA/node_modules/rea-agents/scripts/rea.mjs`。
3. 已 `npm i -g rea-agents` 的 `rea`。

```powershell
# 本项目机器上的实际路径
$rea = 'D:\AI work space\DeepSeek Harness\插件下载与管理\REA\node_modules\rea-agents\scripts\rea.mjs'
$node = 'C:\Program Files\nodejs\node.exe'
& $node $rea --version    # rea@6.7.0
```

Node 要求：`^22.19.0 || ^24.11.0 || >=26.0.0`（本机 24.21.0）。
**不要**用 `npx -y rea-agents@latest` 代替：那会下载其它版本、写 npm 缓存，结论就不再对应本机安装。

## 2. 只读体检（不碰目标）

```powershell
& $node $rea providers                 # 已配置的分析 provider
& $node $rea capabilities              # 每个 provider 的能力与副作用
& $node $rea doctor                    # 就绪检查（--target <path> 可带目标）
& $node $rea doctor --skill            # 技能身份与安装是否对齐（本整合包会报不一致，见 §7）
```

## 3. 输出控制（先学会再跑分析）

| 参数 | 作用 |
| --- | --- |
| `--format toon\|json\|yaml\|md\|jsonl` | 输出格式；`json` 最适合再加工 |
| `--filter-output foo,bar.baz,a[0,3]` | 按 key 路径裁剪，避免整份 Evidence 进上下文 |
| `--token-count` | 只打印输出 token 数（先估体积） |
| `--token-limit n` / `--token-offset n` | 分页读取大结果 |
| `--full-output` | 显示完整信封（默认是精简信封） |

推荐流程：先 `--token-count` → 再 `--filter-output` 或 `--token-limit` 取需要的部分。
大结果不要整份倒进对话。

## 4. 原生二进制（EXE/DLL/ELF/Mach-O）

前提：需要一个可用的深度分析 provider（Ghidra / Hopper / IDA / Kuna / objdump / Rizin）。
Ghidra 相关环境变量（本机已具备）：

```
GHIDRA_INSTALL_DIR = D:\tools\ghidra_12.1.4_PUBLIC
JAVA_HOME          = D:\tools\jdk-21.0.12.1+1
```

```powershell
# 概览（相当于 MCP 的 open_binary + binary_overview）
& $node $rea analyze <path> --provider ghidra --format json
& $node $rea analyze <path> --snapshot .\target.rea.json      # 复用/增量分析快照

# 单个函数 / 伪代码 / 交叉引用 / 搜索
& $node $rea function   <path> --procedure 0x140001070 --provider ghidra
& $node $rea decompile  <path> --procedure <name|addr> --provider ghidra
& $node $rea decompile  <path> --file-offset <hex>            # 只有 Ghidra 支持
& $node $rea xrefs      <path> --address <name|addr> --provider ghidra
& $node $rea search     <path> "http://" --kind strings --mode literal
& $node $rea search     <path> "^do_opt" --kind procedures --mode regex
```

无人头 / 裸镜像：`--target-format raw-binary --architecture x86_64 --entry-point 0x401000`；
DOS COM：`--target-format dos-com`。
CLI 没有 `binary_session` / `close_binary` 概念，进程退出即结束会话。

## 5. JS / Electron / ASAR

```powershell
& $node $rea analyze-javascript-application <app-dir-or-asar> --format json
& $node $rea analyze-javascript-application <path> --artifact-format asar `
    --max-heap-mb 1024 --analysis-timeout-ms 300000 `
    --max-semantic-nodes 100000 --max-semantic-unknowns 100000
& $node $rea compare-application-versions <a.bundle.json> <b.bundle.json>
& $node $rea trace-application-feature <evidence.json> --seed <node_id>
```

静态重建不需要 Ghidra/Hopper。源码可读时优先读源码，不要为了「多一层证据」跑一遍。

## 6. 无 provider 的静态命令（Windows 上最稳的一类）

```powershell
& $node $rea inspect-go-binary        <exe>          # Go 版本/模块/build settings
& $node $rea inspect-rust-binary      <exe>          # cargo-auditable 依赖清单
& $node $rea inspect-pe-resources     <exe>          # PE 资源/图标组/载荷哈希
& $node $rea inspect-managed-artifact <dll>          # .NET 程序集身份（静态）
& $node $rea inspect-managed-members  <dll>          # 类型/成员/CIL/字符串字面量
& $node $rea inspect-sqlite-database  <db>           # 表结构；--columns 取行
& $node $rea inspect-artifact         <zip|apk|ipa|msix|dmg>   # 成员清单
& $node $rea extract-artifact         <archive> --output <空目录>
& $node $rea inspect-wasm-artifact    <wasm>         # 需 WABT 1.0.42（REA_WABT_BIN_DIRECTORY）
& $node $rea inspect-evm-interface    <bin> --encoding raw|hex
```

`inspect-plist` / `inspect-macho` / `inspect-signature` / `list-architectures` / `demangle-swift`
是 Apple 侧命令，Windows 上通常不可用。

## 7. 平台与能力限制（必须如实转述）

- **Windows 原生分析**：Ghidra 路径在本机实测可用；Hopper 仅 macOS；IDA 需要本机安装并配置。
  Linux 专属能力（pwntools 布局、core 崩溃、Binwalk/Unblob 固件、TShark 抓包、sigrok 信号）在 Windows 不可用。
- **只有 MCP 才提供的能力**：`open_binary`/`binary_session`/`close_binary`、`inspect_analysis_view`
  的分页视图、部分 retained-evidence 视图。CLI 拿到的是一次性完整 Evidence，因此务必配合
  `--filter-output` / `--token-limit`，或先把结果写文件再按需读。
- **`doctor --skill`** 会因本整合包改写了技能正文而报不一致：这是设计结果，不是故障；
  不要执行 `rea setup` 去「修复」，那会重新注册 MCP。
- 运行时类命令（`capture-browser-scenario`、`capture-electron-scenario`、`capture-process`、
  `observe-web-*`）会真实启动/操作目标；只在用户授权的目标与范围内使用，并说明副作用。

## 8. 证据纪律

- 每条结论标注来源类型：静态观察 / 推断 / 未知，并保留 Evidence 摘要或输出文件路径。
- 分页或 `--filter-output` 之后不得声称「完整扫描过」。
- 空结果只证明在该搜索边界内没找到，不等于不存在。
- 分析快照（`--snapshot`）是本地文件，属于用户数据，不要提交进仓库。
