# 整合包 v2.1.2 — 只修 bug：升级/修复完成也被判失败的那处收尾断言

**版本类型**：bugfix（Latest）· **发布日**：2026-10-30 · **基线**：v2.1.1 · **适用内核** `0.2.x` / `0.3.x`（按 `0.2.1-rc.2` 构建，门禁 `>=0.2.0 <0.4.0`，版本不同只提示不阻断）· **Windows 10/11 x64**，macOS 通道同步版本号

## 附件

| 文件 | 体积 | 说明 |
|---|---|---|
| `DSH-Plugins-v2.1.2-Windows-x64.zip` | 191,074,507 B（约 182.22 MB） | 插件包本体，SHA-256 `07f6f74724fc1eaad7c389613a6513b17efd3b0da9b1d0fdd84bf05689d64188` |
| `DSH-Plugins-v2.1.2-Windows-x64.zip.sha256` | 约 100 B | 校验文件（`<hash>  <文件名>`） |
| `release-validation.json` | 2,920 B | 发布前自检结果，**19 项全过** |

服务包不重出：继续用 `v2.0.0` 的 `DSH-Plugins-v2.0.0-Services.zip`（680.1 MB，`106fce67b33b3c9548132839e1c1ad1972cb76dcddf5379251616c307f2397a6`），插件包与它互不依赖。仓库内 `stable-v2/` 为可读源码与文档（27 项 / 93 文件，不含 `payload/`）。

**插件载荷与 v2.1.1 逐文件相同** —— 23,172 个文件 / 503.24 MB，唯一被改动的载荷内文件是根目录的 `install-helper.cjs`。所以从 v2.1.1 上来不需要重装、不需要删旧载荷，跑一次 `UPGRADE.cmd` 即可。

---

## 用户看到的现象

装完 v2.1.1 的机器上：

```
================ 安装完成 ================
插件包：已挂载 33 个，跳过 0 个
...
✗ 安装未完成：挂载后的校验没通过：dsh-migration-plugin-state（bundle 未启用）
```

- 33 条依赖确实全部 `link:` 到位、版本也对；
- `profile/package.json` 的 `dsh.profile.bundles` 里也确实没有 `dsh-migration-plugin-state`；
- 但安装器仍然以**退出码 1** 结束，`UPGRADE.cmd` / `MAINTAIN.cmd` / `VERIFY.cmd` 三个入口全中招；
- 另外「原地修复」（把 `--store` 指到自己所在的持久目录，例如从 `%LOCALAPPDATA%\DSHPluginsPack\v2.1.1-windows` 里跑修复）会直接死在「持久安装目录不能与解压目录重叠，请换一个目录。」

## 根因

v2.1.0 引入 `dsh-migration-plugin-state` 时，把它和 32 个真插件混进了同一个 `targets` 数组，只在这一行写了个 `kind: 'state'` 标记 —— **全文件仅此一处赋值、下游零处读取**。于是两处收尾断言都拿它当插件去比 `profile.bundles`：

| 位置 | 原写法 | 后果 |
|---|---|---|
| 挂载后校验 | `if (!finalBundles.includes(p.name)) failed.push(p.name + '（bundle 未启用）')` | upgrade 必报 1 条 |
| upgrade/repair 后核对 | `const missingB = targets.map(t => t.name).filter(n => !afterBundles.includes(n))` | repair 必报 1 条 |

状态快照按设计**不进** `profile.bundles`（它由内置 loader 认领，不参与 bundle 启停），所以这条断言永远为真 —— **33/33 全挂好也必失败**。

顺带发现同一段里还有一处 v2.1.0 起就失效的死代码：`if (!p.name.startsWith('@junyunshoure/')) continue;`。本地插件从 v2.1.0 起改名成 `@local/dsh-client-ui-workbench`、`dsh-ollama`、`dsh-skill-fusion` 这类，**32 个包里没有一个还带 `@junyunshoure/` 前缀**，也就是说这段「必须存在」的校验实际上**一个包都没检查**，断言形同虚设。

## 修了什么（6 处）

| # | 位置 | 改动 |
|---|---|---|
| 1 | 收尾断言 | 真插件与状态快照拆成 `pluginTargets` / `stateTargets` 两个数组，挂载仍全挂，断言各看各的（`:643-646`、`:726-738`、`:755`） |
| 2 | 死代码过滤 | 去掉 `@junyunshoure/` 前缀过滤，改为遍历全部真插件；是否该进 `bundles` 由包**自己声明**的 `dsh.bundle.patch` 决定（新增 `declaresBundle()`） |
| 3 | 原地 repair | 重叠检查加 `ROOT !== store &&` 快速通道 —— 从持久目录自身跑修复不再被挡（`:543`） |
| 4 | 启停差异提示 | 两边都取 `exp.disabled` 导致输出「期望 停用，实际 停用」这类自相矛盾文案；改为各自取实际值 + 统一 `normalizeDisabled`（`:773-782`） |
| 5 | 启动等待 | 从 120 秒空等改成「先探活已在运行的实例 → 最多等 20 秒」，并在 `waitForPort` 轮询里加第二条通道（`:989-996`、`:1024`） |
| 6 | 技能写入 EPERM | 保留已有 3 次退避重试，补上占用原因与处置提示（"先完全退出 DSH 再重跑"） |

## 实测证据（真内核 0.2.1-rc.2，隔离 `DSH_HOME`，全程 `--no-launch`）

| 场景 | v2.1.1 | v2.1.2 |
|---|---|---|
| 全新安装（`--mode new`） | — | **exit 0**，33/33 挂载、跳过 0、256 条目 / 37 bundle，186 s |
| 升级（复刻外部用户 profile：33 条 link + 36 bundle 不含 state） | **exit 1**，`挂载后的校验没通过：dsh-migration-plugin-state（bundle 未启用）`，354 s | **exit 0**，33/33、36 bundle，193.6 s |
| 原地修复（`--store` 指向自身目录） | **exit 1**，`持久安装目录不能与解压目录重叠`，1.7 s | **exit 0**，2.4 s |
| 反向：从载荷里藏掉一个真插件 | — | **exit 1**，`有 1 个插件挂载失败：dsh-cost-meter（payload 里没有这个包）` |
| `--check-only`（从发布 zip 解压后回验证） | — | **exit 0**，23,263 个文件 SHA-256 全对 |

- 安装后 profile 实测：`deps 33 / bundles 36 / 断链 0 / 非 link 依赖 0 / 全部指向新载荷`；`dsh-migration-plugin-state` 不在 `bundles` 里 —— 新断言零误报。
- `declaresBundle` 口径实测：**32/32** 个包都声明了 `dsh.bundle.patch`，真实 profile 的 36 个 bundle 正是「32 个本包 + 4 个内核自带」，不会误报，也不会把纯依赖包硬算成缺 bundle。
- 发布前自检 **19/19**；另加一份纯 Node 回归测试 `tools`→`tests/state-bundle-guard.test.mjs`（不进包）**14/14**，含反向用例（旧口径必报、删插件必报、纯依赖不误报）。

## 顺手修的显示类问题

- `install.ps1` 里 `$PackVersion` 与 `maintain.ps1` 里 `$patchVersion` 还写着 `2.1.0` / `v2.1.0`（v2.1.1 漏同步），9 个 `.cmd` 的窗口标题也停在 `v2.1.0` —— 全部改成 `2.1.2` / `v2.1.2`。
- `README` 的「文件规模」行还写着 v2.1.0 的 `10,763 个文件 / payload 318.45 MB`，改回实测的 `23,263 个文件 / payload 503.24 MB`。

## 新增的防回退断言

`tools/validate-release.mjs` 多了第 19 项：只要产物里的 `install-helper.cjs` 再次出现 `const missingB = targets.map(t => t.name)` 或 `p.name.startsWith('@junyunshoure/')`，或者缺了「两数组 / 合并列表 / `declaresBundle(p.dir)` / `ROOT !== store`」中任意一个结构串，**发布前自检直接 FAIL**。以后改安装器不会又悄悄退回旧写法。

## 未验证 / 遗留

- 真 macOS 未跑：本次只同步版本号，`macos/install.command` 逻辑未动（该文件自包含，无 `stateBundle`/`bundles` 断言，不含同一 bug）。
- 内核 `0.3.x` 未实测（门禁放行）。
- 完整 GUI 观感未在外部那台机器上复现验证；本轮验证止于「隔离环境全量安装 + 三次模式实跑 + 从 zip 回验证」。

## 回滚

- 安装侧：`ROLLBACK.cmd` → `%LOCALAPPDATA%\DSHPluginsPack\v2.1.2-windows\backups\<时间戳>`；`AGENTS.md.bak-<时间戳>`。
- 仓库侧：`git revert <v2.1.2 提交>` + `gh release delete v2.1.2`。
- 退回旧版：直接装 v2.1.1 并跑 `UPGRADE.cmd`（载荷逐文件相同，来回切换只动 `link:` 指向）。
