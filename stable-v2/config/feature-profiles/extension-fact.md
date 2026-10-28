# extension-fact (extension-fact)

当前运行时扩展提供的功能。

加载方式：feature_profiles(action="load", id="extension-fact")；返回 nextOffset 时继续读取。读完后本会话显示该功能原始工具。

按需处理：先判断项目需要此功能，再读取本手册。

以下规范保留原插件要求，包括确认、权限、来源校验、部分结果与错误语义。具体可用工具以当前运行时为准。

## 工具：fact_register

Pin one key fact into this session working context — the line the runtime projects next to the newest message every step. Use it for the facts a long session must not lose: a hard user constraint, a confirmed architecture decision, a path that already failed.
A fact is one short line (<= 160 chars); at most 12 stay pinned, the oldest dropping off. Pass the same text again to no-op; pass the revoke field with a fact tag (or its exact text) to unpin everything under it.
Pin sparingly: the register rides the guaranteed-attention window, and flooding it dilutes every other fact.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "fact": {
      "type": "string",
      "description": "The single-line fact to pin (for example \"User requires TypeScript strict mode, no any\"). Omit when revoking."
    },
    "tag": {
      "type": "string",
      "description": "An optional short tag naming the fact's topic (for example \"constraints\", \"auth-decision\") so it can be revoked by tag later."
    },
    "revoke": {
      "type": "string",
      "description": "Revoke every pinned fact under this tag (or matching this exact text). When set, the fact field is ignored."
    }
  },
  "additionalProperties": false
}
```
