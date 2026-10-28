# 技能目录 (skills)

发现任务适用技能，按需读取技能正文。

加载方式：feature_profiles(action="load", id="skills")；返回 nextOffset 时继续读取。读完后本会话显示该功能原始工具。

常开处理：后台服务保持运行；最小检索/读取入口常驻。以下完整调用规范按需读取。

以下规范保留原插件要求，包括确认、权限、来源校验、部分结果与错误语义。具体可用工具以当前运行时为准。

## 工具：skill

Load the full instructions for a skill. Call it before acting on a task that names or clearly matches a skill in the session skill catalog.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "name": {
      "type": "string",
      "description": "The exact skill name from the available skills list."
    }
  },
  "required": [
    "name"
  ]
}
```
