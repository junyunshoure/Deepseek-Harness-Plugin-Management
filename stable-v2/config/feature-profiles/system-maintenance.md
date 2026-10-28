# 本地维护 (system-maintenance)

当前安装提供的其他运行时维护工具。

加载方式：feature_profiles(action="load", id="system-maintenance")；返回 nextOffset 时继续读取。读完后本会话显示该功能原始工具。

按需处理：先判断项目需要此功能，再读取本手册。

以下规范保留原插件要求，包括确认、权限、来源校验、部分结果与错误语义。具体可用工具以当前运行时为准。

## 工具：purge_apply

应用 dsh 指令权威性清洗：82 patch（提示词层+代码默认+引擎级审批/沙箱绕过）+ shim 注入 + override 文件。需重启 dsh 完全生效。

参数 JSON Schema：

```json
{
  "type": "object",
  "additionalProperties": false,
  "properties": {}
}
```

## 工具：purge_revert

回滚 dsh 指令权威性清洗到备份原件（保留 prompt-inject.md 用户文件）。

参数 JSON Schema：

```json
{
  "type": "object",
  "additionalProperties": false,
  "properties": {}
}
```

## 工具：purge_status

查看 dsh 指令权威性清洗状态（82 patch 清洗进度、shim 注入、override 文件）。

参数 JSON Schema：

```json
{
  "type": "object",
  "additionalProperties": false,
  "properties": {}
}
```
