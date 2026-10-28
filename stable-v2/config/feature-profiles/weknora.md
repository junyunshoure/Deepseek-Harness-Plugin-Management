# WeKnora 检索 (weknora)

查询组织资料的原文片段及带引用综合回答。

加载方式：feature_profiles(action="load", id="weknora")；返回 nextOffset 时继续读取。读完后本会话显示该功能原始工具。

按需处理：先判断项目需要此功能，再读取本手册。

以下规范保留原插件要求，包括确认、权限、来源校验、部分结果与错误语义。具体可用工具以当前运行时为准。

## 工具：weknora_ask

Ask WeKnora a question and get its own composed answer with citations (RAG pipeline runs server-side: query rewriting, retrieval, reranking and summarization). Reserve it for broad or synthesis questions whose answer spans many documents, where retrieving passages yourself would take several rounds. For anything you can answer from specific passages, prefer weknora_search: it is far faster and leaves you the evidence to reason over rather than another model's conclusion.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "query": {
      "type": "string",
      "description": "The question to answer."
    },
    "knowledge_base_ids": {
      "type": "array",
      "items": {
        "type": "string"
      },
      "description": "Restrict retrieval to these knowledge base ids."
    },
    "agent_id": {
      "type": "string",
      "description": "Custom agent id; selects the server-side ReAct pipeline."
    },
    "session_id": {
      "type": "string",
      "description": "Continue an earlier WeKnora session instead of starting one."
    },
    "web_search": {
      "type": "boolean",
      "description": "Let WeKnora also search the web, when its deployment allows it."
    }
  },
  "required": [
    "query"
  ],
  "additionalProperties": false
}
```

## 工具：weknora_list_knowledge_bases

List the WeKnora knowledge bases this deployment can retrieve from, with their ids. weknora_search already spans them all, so reach for this only to report what is available or to narrow a later search to one of them.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {},
  "additionalProperties": false
}
```

## 工具：weknora_read_document

Read a WeKnora document's stored passages in order, reassembled into text. Use it after weknora_search when one passage is not enough context; page through long documents.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "knowledge_id": {
      "type": "string",
      "description": "Document id, as returned in a search hit."
    },
    "page": {
      "type": "integer",
      "description": "Page of passages, starting at 1."
    },
    "page_size": {
      "type": "integer",
      "description": "Passages per page (max 100)."
    }
  },
  "required": [
    "knowledge_id"
  ],
  "additionalProperties": false
}
```

## 工具：weknora_search

Search WeKnora knowledge bases and return the matching passages verbatim (hybrid vector + keyword retrieval, no model summarization). Use this to ground an answer in the organization's own documents, and also to locate a document by name — a query that reads like a title additionally returns the documents it names. Searches every knowledge base this credential can see unless you narrow it with knowledge_base_ids. Every hit carries a knowledge_id you can pass to weknora_read_document for the full document.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "query": {
      "type": "string",
      "description": "Natural-language query; a full question retrieves better than keywords."
    },
    "knowledge_base_ids": {
      "type": "array",
      "items": {
        "type": "string"
      },
      "description": "Restrict the search to these knowledge base ids."
    },
    "knowledge_ids": {
      "type": "array",
      "items": {
        "type": "string"
      },
      "description": "Restrict the search to these document ids."
    },
    "max_results": {
      "type": "integer",
      "description": "Maximum passages to return (default 8)."
    }
  },
  "required": [
    "query"
  ],
  "additionalProperties": false
}
```
