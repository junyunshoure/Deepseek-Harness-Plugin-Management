# 工作台工具箱（workbench-toolkit）

**这不是插件，也不会被自动安装。** 这里放的是「工作台目录（workbench）」用的三件脚本和四份规格文档。整包只把它们放到 `templates\workbench-toolkit\`，安装器**不会**把它们写进任何地方——因为 `场景记忆.mjs` 读的是 `<你的工作区>\workbench\memory`，每台机器的路径都不一样，写死必坏。

要生效，把它们拷到你自己的工作台根目录：

```powershell
# 假设你的工作台根是 D:\my-workbench（该目录下已有 workbench\ 文件夹）
Copy-Item .\templates\workbench-toolkit\scripts\*        D:\my-workbench\scripts\       -Force
Copy-Item .\templates\workbench-toolkit\workbench\refs\* D:\my-workbench\workbench\refs\ -Force
```

验收命令：

```powershell
cd D:\my-workbench
node scripts\场景记忆.mjs list                       # 列出场景名，应与 workbench\scenarios\_index.md 一致
node scripts\场景记忆.mjs check --all                # 退出码 0；会打印每个场景 §〇 的字节数
node scripts\发消息.mjs --to <场景名> --text "测试"   # 会写进目标场景正文的「## 〇-通知」
```

## 文件清单（7 个）

| 文件 | 体积 | 作用 |
| --- | --- | --- |
| `scripts/场景记忆.mjs` | 44,191 B | 场景记忆的读写、校验、交接（773 行，含 14 处相对上游的适配修正） |
| `scripts/发消息.mjs` | 4,250 B | 跨场景投递通知（写正文 `## 〇-通知` + 看板） |
| `scripts/场景记忆-例外.json` | 340 B | 例外清单，**必须与脚本同目录**（脚本按 `TOOL_DIR` 找它） |
| `workbench/refs/README.md` | 2,841 B | 上游来源与本机差异说明 |
| `workbench/refs/面板类型总览.md` | 7,401 B | 24 种面板 / 7 族规格 |
| `workbench/refs/场景配置格式.md` | 6,027 B | 场景 json 的字段与加载链路 |
| `workbench/refs/会话绑定三字段.md` | 7,538 B | pinTarget / sessionTitle / sessionId |

## 三条必须知道的

1. **`check` 是辅助口径，不能当准入判断。** 本机布局是 v1（`项目信息.md` + `§〇`），v2 要求的 `身份卡.md` / `场景画像.md` 等一律降级成提示，所以它「永远通过」。真正的准入看 `索引体检.mjs`。
2. **`--root` 只被 `场景记忆.mjs` 认。** `发消息.mjs` 认的是 `DSH_WORKBENCH_ROOT` 环境变量或脚本上两级目录，隔离测试时不要以为它写到了别处。
3. **迁移布局要显式开关。** `node scripts\场景记忆.mjs init --迁移布局` 才会做 v2 三文档布局；默认不动、不删 `项目信息.md`。

## 移除

```powershell
Remove-Item scripts\场景记忆.mjs, scripts\发消息.mjs, scripts\场景记忆-例外.json
Remove-Item workbench\refs\README.md, workbench\refs\面板类型总览.md, workbench\refs\场景配置格式.md, workbench\refs\会话绑定三字段.md
```
