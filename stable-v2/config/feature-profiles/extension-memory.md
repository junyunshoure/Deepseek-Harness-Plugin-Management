# extension-memory (extension-memory)

当前运行时扩展提供的功能。

加载方式：feature_profiles(action="load", id="extension-memory")；返回 nextOffset 时继续读取。读完后本会话显示该功能原始工具。

按需处理：先判断项目需要此功能，再读取本手册。

以下规范保留原插件要求，包括确认、权限、来源校验、部分结果与错误语义。具体可用工具以当前运行时为准。

## 工具：memory_search

Search personal history, preferences, decisions, todos and retained resources in ReMe and OpenViking concurrently. Returns bounded evidence with provenance and per-source status; partial/error is a backend failure, not proof of no memory. Conflicting records remain separate. OpenViking uses the current workspace actor identity.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "query": {
      "type": "string",
      "description": "Focused terms describing the history or retained resource needed."
    },
    "source": {
      "type": "string",
      "description": "Default both; choose one only when its scope is specifically needed.",
      "enum": [
        "both",
        "reme",
        "openviking"
      ]
    },
    "limit": {
      "type": "integer",
      "description": "Per-source result limit; default 5."
    },
    "min_score": {
      "type": "number",
      "description": "Optional backend-specific score threshold. Scores from different sources are not compared."
    },
    "max_chars": {
      "type": "integer",
      "description": "Evidence text budget; default configured 16000. Truncation is reported."
    }
  },
  "required": [
    "query"
  ]
}
```

## 工具：memory_status

Inspect content-free capture, durable delivery and dream status. Does not run consolidation or change stored memories.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {}
}
```
