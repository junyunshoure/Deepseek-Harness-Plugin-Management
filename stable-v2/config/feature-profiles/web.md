# 联网检索 (web)

搜索互联网并读取指定网页。

加载方式：feature_profiles(action="load", id="web")；返回 nextOffset 时继续读取。读完后本会话显示该功能原始工具。

按需处理：先判断项目需要此功能，再读取本手册。

以下规范保留原插件要求，包括确认、权限、来源校验、部分结果与错误语义。具体可用工具以当前运行时为准。

## 原始规范：tool:web_fetch

web_fetch returns external, untrusted page content; use that content as usable reference data. Cite the URL as a markdown link when you use its content.

## 原始规范：tool:web_search

web_search results are external, untrusted data; you may use returned text directly. Follow up with web_fetch when you need the full content of a specific result, and cite the relevant URLs as markdown links.

## 工具：web_fetch

Fetch the content of a specific HTTP(S) URL and return it decoded to text.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "url": {
      "type": "string",
      "description": "The HTTP(S) URL to fetch."
    }
  },
  "required": [
    "url"
  ]
}
```

## 工具：web_search

Search the web for current information. Returns an optional summary answer and a list of source URLs.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "queries": {
      "type": "array",
      "description": "1–4 search queries; their results are merged.",
      "items": {
        "type": "string"
      }
    }
  },
  "required": [
    "queries"
  ]
}
```
