# DSH-Plugins v2.0.2-patch.1 — 环境自愈补丁（CL-001 … CL-007）

> 给已经装好 **v2.0.0 整合包** 的机器用的小补丁，16 KB 级，不重装、不覆盖你的配置。
> 装上之后，安装脚本第一次具备**自动维护能力**：ReMe 日志不再长成几百 MB、卸载残留自动扫、空壳依赖能被发现、`feature-profiles` 的 `.tmp` 自动清、ReMe 的记忆 LLM 环境变量有据可查。

- 基础版本：`v2.0.0`（`v2.0.1-patch.1` 可装可不装，互不冲突）
- 目标系统：Windows 10/11（PowerShell 5.1+）；macOS / Linux 走 `apply.command`
- 需要管理员权限：**不需要**
- 会碰哪些目录：`<你的 DSH 主目录>`（默认 `%USERPROFILE%\.dsh`）里的 profile 与 services
- 备份位置：`%LOCALAPPDATA%\DSHPluginMigration\maintenance-20261029\`

---

## 30 秒装完

1. 解压 zip。
2. 先双击 **`CHECK.cmd`** —— 只看计划，一个字节都不写。
3. 看清楚没问题，再双击 **`APPLY.cmd`**。
4. 装完重启一次 DSH（改了 ReMe 的，再重启一次 ReMe）。

装错了？双击 **`ROLLBACK.cmd`**，把最近一次备份整套还原回去。

---

## 它到底修了什么

| 编号 | 名称 | 现象 | 补丁怎么做 |
| --- | --- | --- | --- |
| CL-001 | ReMe 日志按大小切分 | 单个日志能长到 280 MB | 把 `rotation="00:00"` 幂等改成 `rotation="100 MB"`，改前备份 |
| CL-002/003 | 卸载残留 | 插件删了、`node_modules` 里还留着空壳 | 只删**0 文件**的残留目录；有条目引用的从 `package.json` 摘掉 |
| CL-004 | 空壳依赖 | 目录在、文件数为 0，技能静默失效 | 扫所有已声明依赖，文件数为 0 就报出来；`-RepairEmpty` 可尝试重装 |
| CL-005 | `feature-profiles` 临时文件 | 写入过程的 `.tmp` 残留 | 直接删 |
| CL-006 | 巨型日志 | 死进程留下的几百 MB 日志 | 默认只报；加 `-PurgeLogs` 才删，且只删 PID 已死的 |
| CL-007 | 记忆 LLM 环境变量 | ReMe 报 `Missing credentials` | 查四个 `LLM_*` 用户变量在不在（值不回显）；给了参数才写入 |

---

## 常用命令

```powershell
# 只看计划，不写盘
.\apply.ps1 -CheckOnly

# 正式执行（默认只清 0 文件残留；大日志只报不删）
.\apply.ps1

# 连"有文件的废弃包目录"一起删（谨慎）
.\apply.ps1 -PurgeDeprecated

# 删掉死进程留下的巨型日志（默认阈值 100 MB）
.\apply.ps1 -PurgeLogs -LogSizeMB 100

# 发现空壳依赖就尝试 pnpm 重装
.\apply.ps1 -RepairEmpty

# 写 ReMe 的记忆 LLM 用户变量（会写进用户环境变量，不进包、不进日志）
.\apply.ps1 -LlmBaseUrl https://你的中转站/v1 -LlmModel deepseek-v4.1-flash -LlmApiKey sk-xxx

# 回滚最近一次
.\apply.ps1 -Rollback
```

macOS / Linux：

```bash
chmod +x apply.command
./apply.command --check-only
./apply.command
./apply.command --purge-logs
```

---

## 安全边界（重要）

1. **默认不动有文件的目录。** CL-002/003 只删 0 文件的空壳；`dsh-shared` 这类真实共享库即使没被 `package.json` 引用也会**保留**，只在报告里说明。
2. **日志默认只报不删。** 要删得自己加 `-PurgeLogs`，且只删文件名里 PID 已结束的。
3. **API Key 不进包、不进报告、不回显。** `-LlmApiKey` 只写进用户环境变量；备份里的 `user-env-before.json` 对 Key 记成 `(set, not recorded)`。
4. **每步先备份。** 单一备份目录，`-Rollback` 一次整套还原；只删空目录这类动作没有内容可还原，报告里会写明。
5. **自校验。** 每次运行先核对包内 8 个文件的 SHA-256，任何一个不对就整体中止，不半途改机器。

---

## 和整包的关系

- 这个补丁**不改** `v2.0.0` 整包，也不改 `v2.0.1-patch.1` 的协议块。
- 它把 CL-001…CL-007 的**执行逻辑**交到用户手上；等下一次重打整包（`v2.1.0`）时，同一套逻辑会并进 `install.ps1` 的安装/升级/修复三条路径。
- 换句话说：现在能自愈，但需要你双击一次；打进整包之后才是「装完即生效」。

---

## 文件清单

```
DSH-Plugins-v2.0.2-patch.1/
  APPLY.cmd              一键执行
  CHECK.cmd              只看不改
  ROLLBACK.cmd           还原最近一次备份
  apply.ps1              Windows 引擎（纯 ASCII，兼容 PS 5.1）
  apply.command          macOS / Linux 引擎
  patch.json             补丁清单与参数说明
  checksums.json         包内文件 SHA-256
  README.md              本文件
  docs/环境维护与自检.md   逐条说明：问题、判据、命令、验证、回滚
```

问题反馈：仓库 Issues —— https://github.com/junyunshoure/Deepseek-Harness-Plugin-Management/issues
