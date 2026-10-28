# 图像理解 (vision)

读取模型当前看不到的图片并提取文字与布局证据。

加载方式：feature_profiles(action="load", id="vision")；返回 nextOffset 时继续读取。读完后本会话显示该功能原始工具。

按需处理：先判断项目需要此功能，再读取本手册。

以下规范保留原插件要求，包括确认、权限、来源校验、部分结果与错误语义。具体可用工具以当前运行时为准。

## 工具：modlens_read_image

Read an image through the modlens vision bridge. Use whenever a message references an image the current model cannot see: a local file path or an http(s) URL to a screenshot, photo, chart, diagram, or document scan. Returns structured evidence with every word transcribed (ocr.full_text), layout regions in reading order, semantics, and an uncertainty list. Quote the evidence instead of guessing. For the same image and focus, call this tool once and reuse its returned evidence instead of calling again. Requires a configured modlens engine (run `npx @liustack/modlens doctor` in a terminal to check).

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "path": {
      "type": "string",
      "description": "Absolute local file path or http(s) URL of the image"
    },
    "prompt": {
      "type": "string",
      "description": "Optional extra focus for the reading (e.g. \"focus on the axis labels\")"
    }
  },
  "required": [
    "path"
  ]
}
```
