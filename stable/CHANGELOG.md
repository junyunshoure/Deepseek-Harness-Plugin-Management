# 更新记录

## v1.0.0 — 2026-10-22（正式版第一版）

首个正式版：以一台已配置完成的 DSH Desktop（`0.2.1-rc.2`，2026-10-22 状态）为准，重新打包完整插件与配置。

**内容规模**
- bundle：36 个（4 个 DSH 内置 + 32 个第三方包）
- 可安装第三方包：32 个，跳过 0 个（Demo 中两个不兼容包本次未再出现）
- 插件组合行：247 条（Demo 为 233 条）
- 载荷文件：17,425 个，解压后约 400MB

**相对 Demo v0.1.0-demo.1 的变化**
- 插件数量增加：新增 `dsh-skill-hub`、`dsh-ego-browser`、`browser-skill`、`@wxg-prc-cpg/dsh-weknora`、`@vectorize-io/hindsight-coding-agents`、`@openviking/dsh-memory-plugin`、`@agentscope-ai/reme-dsh-plugin`、`@lemoncat7/dsh-knowledge`、`@kenz1117/dsh-ui-usage-billing`、`@tt-a1i/archify-dsh`、`dsh-approval-gate`、`dsh-context`、`dsh-drawai`、`dsh-rewind-plugin`、`dsh-whale-widget`、`dsh-plugin-wallpaper-engine`、`dsh-mattpocock-skills-deck`、`dsh-my-skill-manager`、`@xmanrui/dsh-im`、`dsh-zotero`、`billion-context`、`dsh-cost-meter`、`@changfenhuang/dsh-genui`、`@linxin666/dsh-web-all` 等（以 `inventory.json` 为准）
- `web-ui-ssh`、`web-ui-skill-explorer` 恢复为启用
- 新增 `config/` 完整配置快照（界面偏好、模型提供方与模型清单、插件启停），**不含任何密钥**
- `@local/dsh-client-ui-workbench` 原本是指向本地开发目录的符号链接，本版已实例化为真实目录，离线可用

**兼容性**
- Windows x64 + DSH `0.2.1-rc.2`；面向全新初始化的 Desktop profile
- 安装器逻辑与 Demo 相同，未做改动

## v0.1.0-demo.1 — 2026-10-21（预发布）

初始 Demo：26 个 bundle（4 内置 + 22 第三方），233 条插件行，20 个兼容包可安装，2 个不兼容包仅保留文件。
