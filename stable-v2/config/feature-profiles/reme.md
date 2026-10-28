# ReMe 记忆 (reme)

检索个人历史、偏好、决定与待办；后台自动整理记忆。

加载方式：feature_profiles(action="load", id="reme")；返回 nextOffset 时继续读取。读完后本会话显示该功能原始工具。

常开处理：后台服务保持运行；最小检索/读取入口常驻。以下完整调用规范按需读取。

以下规范保留原插件要求，包括确认、权限、来源校验、部分结果与错误语义。具体可用工具以当前运行时为准。

## 工具：reme_search

Compatibility lookup for ReMe personal memory only. For combined memory retrieval use memory_search. Backend failures are explicit.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "query": {
      "type": "string"
    },
    "limit": {
      "type": "integer"
    },
    "min_score": {
      "type": "number"
    }
  },
  "required": [
    "query"
  ]
}
```
