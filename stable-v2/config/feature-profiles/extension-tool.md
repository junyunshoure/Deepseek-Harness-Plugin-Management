# extension-tool (extension-tool)

当前运行时扩展提供的功能。

加载方式：feature_profiles(action="load", id="extension-tool")；返回 nextOffset 时继续读取。读完后本会话显示该功能原始工具。

按需处理：先判断项目需要此功能，再读取本手册。

以下规范保留原插件要求，包括确认、权限、来源校验、部分结果与错误语义。具体可用工具以当前运行时为准。

## 工具：tool_activate

Load one paged tool namespace back into this session's reach — onto the wire, and the generated SDK along with it. The session catalog summarizes the paged namespaces; activating one makes its tools callable from the next request on.
At most 3 namespaces stay active at once: activating beyond the cap evicts the least recently used namespace back to the catalog summary.
The target must be a paged, currently inactive namespace exactly as the catalog names it.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "namespace": {
      "type": "string",
      "description": "The paged namespace to activate, exactly as the catalog names it (for example \"codegraph\" for mcp__codegraph__* tools)."
    }
  },
  "required": [
    "namespace"
  ],
  "additionalProperties": false
}
```
