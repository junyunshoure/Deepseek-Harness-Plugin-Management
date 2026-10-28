# 即时消息文件交付 (im)

向当前已启用的即时消息交付通道登记文件。

加载方式：feature_profiles(action="load", id="im")；返回 nextOffset 时继续读取。读完后本会话显示该功能原始工具。

按需处理：先判断项目需要此功能，再读取本手册。

以下规范保留原插件要求，包括确认、权限、来源校验、部分结果与错误语义。具体可用工具以当前运行时为准。

## 工具：dsh_im_return_file

Register a readable file or generated image for delivery through the current IM conversation after this turn. Requires an active IM delivery consumer; in Web, Desktop, or CLI conversations use the host present tool if available. Existing and newly created files are both valid. Success means queued, not sent; do not claim the user has received the file.

参数 JSON Schema：

```json
{
  "type": "object",
  "additionalProperties": false,
  "properties": {
    "path": {
      "type": "string",
      "description": "Absolute path, or a path relative to the current workspace."
    }
  },
  "required": [
    "path"
  ]
}
```
