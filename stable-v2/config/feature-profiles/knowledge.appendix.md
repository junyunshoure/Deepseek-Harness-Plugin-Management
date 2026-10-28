# 知识库与笔记 (knowledge) 附录

本文件是精确参数与原始规范，只在需要具体字段时读取。

## 工具：knowledge_base_create

Create a knowledge base only when the user explicitly asks. By default do NOT fill provider/model: write-back follows this client's configured override or the current session at execution time, even with remote knowledge storage. Never copy another machine's model route from existing bases. A dedicated model requires the user to request it and useCurrentSessionModel=false. The tool uses the active knowledge storage provider and reports local or remote storage; it never copies or synchronizes. Creating a base does not mount it.

参数 JSON Schema：

```json
{
  "type": "object",
  "additionalProperties": false,
  "properties": {
    "name": {
      "type": "string",
      "description": "Knowledge-base name, 1-100 characters."
    },
    "description": {
      "type": "string",
      "description": "Routing description used to decide whether conversations belong in this base, at most 2000 characters."
    },
    "defaultTags": {
      "type": "array",
      "items": {
        "type": "string"
      },
      "maxItems": 32
    },
    "extractionInstructions": {
      "type": "string",
      "description": "Additional write-back rules, at most 4000 characters."
    },
    "writebackPolicy": {
      "type": "string",
      "enum": [
        "conservative",
        "proactive"
      ],
      "description": "Write-back strictness; defaults to conservative."
    },
    "useCurrentSessionModel": {
      "type": "boolean",
      "default": true,
      "description": "Default true: leave the dedicated route unset and follow this client override, otherwise the current session. Set false ONLY when the user explicitly requests a dedicated write-back model."
    },
    "writebackProvider": {
      "type": "string",
      "description": "Only used when useCurrentSessionModel=false. A provider registered in THIS DSH client, never a copied remote-storage provider. Supply with writebackModel."
    },
    "writebackModel": {
      "type": "string",
      "description": "Only used when useCurrentSessionModel=false. Supply together with writebackProvider; otherwise omit both."
    }
  },
  "required": [
    "name"
  ]
}
```

## 工具：knowledge_base_search

First-stage knowledge discovery and the preferred first lookup for the user's projects, preferences, prior decisions, workflows, installed tools, or mounted topics. Search only knowledge bases mounted for recall in THIS session by their name, routing description, and tags. Call this before workspace-file or web discovery when durable user-managed knowledge may apply, then use knowledge_search. It returns metadata only, never knowledge document content. If nothing matches, continue to the next appropriate source.

参数 JSON Schema：

```json
{
  "type": "object",
  "additionalProperties": false,
  "properties": {
    "query": {
      "type": "string",
      "description": "A concise description of the current topic or information need."
    },
    "limit": {
      "type": "integer",
      "description": "Maximum matching knowledge bases, default 5 and maximum 10."
    }
  },
  "required": [
    "query"
  ]
}
```

## 工具：knowledge_base_update

Modify an existing knowledge base only when the user explicitly asks. Identify it by exact id or name. The tool always updates the currently active local or remote provider and reports the actual destination; it never moves or synchronizes the base and does not change project/session mounts.

参数 JSON Schema：

```json
{
  "type": "object",
  "additionalProperties": false,
  "properties": {
    "base": {
      "type": "string",
      "description": "Exact knowledge-base id or name."
    },
    "name": {
      "type": "string",
      "description": "New name, 1-100 characters."
    },
    "description": {
      "type": "string",
      "description": "New routing description; an empty string clears it."
    },
    "defaultTags": {
      "type": "array",
      "items": {
        "type": "string"
      },
      "maxItems": 32,
      "description": "Replacement default-tag list."
    },
    "extractionInstructions": {
      "type": "string",
      "description": "New write-back rules; an empty string clears them."
    },
    "writebackPolicy": {
      "type": "string",
      "enum": [
        "conservative",
        "proactive"
      ],
      "description": "Replacement write-back strictness."
    },
    "writebackProvider": {
      "type": "string",
      "description": "Replacement dedicated provider. Must be supplied together with writebackModel."
    },
    "writebackModel": {
      "type": "string",
      "description": "Replacement dedicated model. Must be supplied together with writebackProvider."
    },
    "useCurrentSessionModel": {
      "type": "boolean",
      "description": "Set true to clear the dedicated model and follow this client override, otherwise each current conversation model."
    }
  },
  "required": [
    "base"
  ]
}
```

## 工具：knowledge_document_group_assign

Assign 1-50 knowledge documents to a group when organizing documents for the user. First browse knowledge_document_groups or search/read documents; use exact handles and versions. Prefer an existing suitable group. Modifies only group metadata, never body, tags, paths or completion state. Read-only mounts reject changes; audit mounts create pending review; direct mounts apply immediately. Batch is per-document, not atomic: inspect every result, retry only failed documents after re-reading. Never claim pending-review as applied. Available to ordinary and companion sessions alike.

参数 JSON Schema：

```json
{
  "type": "object",
  "additionalProperties": false,
  "properties": {
    "group": {
      "type": "string",
      "minLength": 1,
      "maxLength": 64
    },
    "documents": {
      "type": "array",
      "minItems": 1,
      "maxItems": 50,
      "items": {
        "type": "object",
        "additionalProperties": false,
        "properties": {
          "handle": {
            "type": "string"
          },
          "expectedVersion": {
            "type": "integer",
            "minimum": 1
          }
        },
        "required": [
          "handle",
          "expectedVersion"
        ]
      }
    }
  },
  "required": [
    "group",
    "documents"
  ]
}
```

## 工具：knowledge_document_groups

Browse knowledge-document groups and document metadata in one knowledge base mounted for recall in THIS session. Returns session-bound handles and versions for knowledge_document_group_assign. Results and group counts are for this page only; follow nextCursor until absent to discover all accessible groups, including when a filtered page is empty. Reuse a suitable existing group before creating another. This is not note folders, tags or knowledge-base grouping.

参数 JSON Schema：

```json
{
  "type": "object",
  "additionalProperties": false,
  "properties": {
    "knowledgeBaseId": {
      "type": "string"
    },
    "cursor": {
      "type": "string"
    },
    "limit": {
      "type": "integer",
      "minimum": 1,
      "maximum": 100
    }
  },
  "required": [
    "knowledgeBaseId"
  ]
}
```

## 工具：knowledge_document_status

When the current user explicitly confirms a problem resolved or collection complete, update the corresponding mounted knowledge document. First search/read the exact document and version. wholeDocument=true freezes the ENTIRE document without changing its body; use only when its whole subject is closed. For one issue in a broader document use wholeDocument=false with a unique exact oldText/newText replacement containing status and conclusion, leaving the document open. Never infer closure from an assistant claim, a question or a casual acknowledgement. Obeys read-only/audit/direct mount policy. Report pending review honestly; never claim pending status is applied.

参数 JSON Schema：

```json
{
  "type": "object",
  "additionalProperties": false,
  "properties": {
    "handle": {
      "type": "string",
      "description": "Exact short session reference from knowledge_search; never reconstruct. If unavailable, search and read again before retrying."
    },
    "expectedVersion": {
      "type": "integer",
      "minimum": 1
    },
    "state": {
      "type": "string",
      "enum": [
        "resolved",
        "complete"
      ]
    },
    "confirmation": {
      "type": "string",
      "description": "Exact complete clause from the current direct user confirmation; do not omit negations or question suffixes."
    },
    "note": {
      "type": "string",
      "description": "Verified resolution or completion conclusion, up to 2000 characters."
    },
    "wholeDocument": {
      "type": "boolean",
      "description": "Explicitly distinguish whole-document closure from a local section update."
    },
    "oldText": {
      "type": "string"
    },
    "newText": {
      "type": "string"
    }
  },
  "required": [
    "handle",
    "expectedVersion",
    "state",
    "confirmation",
    "note",
    "wholeDocument"
  ]
}
```

## 工具：knowledge_note_confirm

Execute the exact pending note change only after the user replies in a later turn confirming the previously summarized plan (for example 确认、可以、按这个改). Never call in the proposing turn. Do not regenerate or alter the proposed content. A changed request needs a new proposal. Restart or expiry requires proposing again.

参数 JSON Schema：

```json
{
  "type": "object",
  "additionalProperties": false,
  "properties": {
    "confirmationId": {
      "type": "string"
    }
  },
  "required": [
    "confirmationId"
  ]
}
```

## 工具：knowledge_note_create

Propose creating a note or folder from natural user intent. This tool asks the user for one-shot approval before writing; no prescribed user wording is needed. Omit parentFolderHandle for root. Do not repeatedly ask after rejection. Confirmation is conversational, NOT a popup. Collect ALL edits requested for this note into ONE proposal, not one proposal per paragraph/chapter. The first call returns pending_confirmation without writing. Read all preview pages, show affected sections and concrete before/after changes (clearly label any abbreviated excerpts), then ask for ONE confirmation and end the turn. Never just say "please confirm". After next-turn agreement call knowledge_note_confirm with confirmationId, not this tool again.

参数 JSON Schema：

```json
{
  "type": "object",
  "additionalProperties": false,
  "properties": {
    "kind": {
      "type": "string",
      "enum": [
        "document",
        "folder"
      ]
    },
    "name": {
      "type": "string",
      "description": "Document title/filename or folder name."
    },
    "parentFolderHandle": {
      "type": "string",
      "description": "Exact signed folder handle returned by knowledge_note_list. Omit for root."
    },
    "content": {
      "type": "string",
      "description": "Initial Markdown content for a document. Omit for a folder."
    }
  },
  "required": [
    "kind",
    "name"
  ]
}
```

## 工具：knowledge_note_delete

Permanently delete one note or folder only when the current user explicitly asks. Requires an exact signed handle. Referenced notes are protected; remote deletion also requires an admin-capable token.

参数 JSON Schema：

```json
{
  "type": "object",
  "additionalProperties": false,
  "properties": {
    "noteHandle": {
      "type": "string",
      "description": "Exact signed handle returned by knowledge_note_list or knowledge_note_search."
    }
  },
  "required": [
    "noteHandle"
  ]
}
```

## 工具：knowledge_note_list

Browse or search the independent note workspace without an extra user authorization request. Read access does not authorize mutations. Omit folderHandle to browse the root. Handles are session-bound; pass exact returned handles to other knowledge_note tools.

参数 JSON Schema：

```json
{
  "type": "object",
  "additionalProperties": false,
  "properties": {
    "folderHandle": {
      "type": "string",
      "description": "Exact signed folder handle returned by this tool. Omit for the note-workspace root."
    },
    "query": {
      "type": "string",
      "description": "Optional name search across the whole note workspace. Cannot be combined with folderHandle."
    },
    "limit": {
      "type": "integer",
      "description": "Maximum results, default 50 and maximum 100."
    }
  }
}
```

## 工具：knowledge_note_move

Propose moving a note or folder; this tool requests one-shot user approval showing the item and destination, without prescribed user wording. Use exact signed handles. Omit targetFolderHandle for root. Do not retry after rejection. Confirmation is conversational, NOT a popup. Collect ALL edits requested for this note into ONE proposal, not one proposal per paragraph/chapter. The first call returns pending_confirmation without writing. Read all preview pages, show affected sections and concrete before/after changes (clearly label any abbreviated excerpts), then ask for ONE confirmation and end the turn. Never just say "please confirm". After next-turn agreement call knowledge_note_confirm with confirmationId, not this tool again.

参数 JSON Schema：

```json
{
  "type": "object",
  "additionalProperties": false,
  "properties": {
    "noteHandle": {
      "type": "string"
    },
    "targetFolderHandle": {
      "type": "string",
      "description": "Exact destination-folder handle; omit for root."
    }
  },
  "required": [
    "noteHandle"
  ]
}
```

## 工具：knowledge_note_preview

Read the server-saved before/after preview of the current pending note change. If nextPreviewOffset is not null, continue with that offset BEFORE asking the user for one confirmation. This never writes or changes the proposal. Show every affected section and concrete before/after differences; do not merely ask for confirmation.

参数 JSON Schema：

```json
{
  "type": "object",
  "additionalProperties": false,
  "properties": {
    "confirmationId": {
      "type": "string"
    },
    "offset": {
      "type": "integer",
      "minimum": 0
    },
    "maxChars": {
      "type": "integer",
      "minimum": 1,
      "maximum": 40000
    }
  },
  "required": [
    "confirmationId"
  ]
}
```

## 工具：knowledge_note_read

Read a bounded chunk from an editable text or Markdown note using its exact session-bound handle from knowledge_note_list/search or an explicit @ note-document reference in the user message. An @ reference already identifies the selected note; do not replace it with a same-title search result. This never reads folders or binary attachments and does not authorize mutations. Use offset and maxChars to continue long notes.

参数 JSON Schema：

```json
{
  "type": "object",
  "additionalProperties": false,
  "properties": {
    "noteHandle": {
      "type": "string",
      "description": "Exact signed note handle returned by knowledge_note_list, knowledge_note_search, or an explicit @ note-document reference."
    },
    "knowledgeHandle": {
      "type": "string",
      "description": "Optional legacy reference metadata. Reading requires only a valid session-bound noteHandle, not a knowledge mount or user authorization."
    },
    "offset": {
      "type": "integer",
      "description": "Character offset, default 0."
    },
    "maxChars": {
      "type": "integer",
      "description": "Maximum returned characters, default 20000 and maximum 80000."
    }
  },
  "required": [
    "noteHandle"
  ]
}
```

## 工具：knowledge_note_references

List structured note references of a mounted knowledge document. Referenced notes may be read without extra user authorization, but updating them still requires an explicit current user instruction. Partner heartbeat uses its explicitly selected recording target instead. Adding/removing references requires an explicit current user request and a writable mounted knowledge base. Never modify the knowledge body through note tools.

参数 JSON Schema：

```json
{
  "type": "object",
  "additionalProperties": false,
  "properties": {
    "knowledgeHandle": {
      "type": "string",
      "description": "Exact signed knowledge handle returned by knowledge_search."
    },
    "operation": {
      "type": "string",
      "enum": [
        "list",
        "add",
        "remove"
      ]
    },
    "noteHandles": {
      "type": "array",
      "items": {
        "type": "string"
      },
      "maxItems": 16,
      "description": "Exact note handles. Required for add/remove; omitted for list."
    }
  },
  "required": [
    "knowledgeHandle",
    "operation"
  ]
}
```

## 工具：knowledge_note_search

Search note-document and editable-file metadata without an extra user authorization request. This never reads note content or authorizes modifications. Pass exact returned handles to knowledge_note_read/update/move/delete or knowledge_note_references; never invent a handle.

参数 JSON Schema：

```json
{
  "type": "object",
  "additionalProperties": false,
  "properties": {
    "query": {
      "type": "string",
      "description": "A focused note filename or title query."
    },
    "limit": {
      "type": "integer",
      "description": "Maximum results, default 10 and maximum 20."
    }
  },
  "required": [
    "query"
  ]
}
```

## 工具：knowledge_note_update

Propose ALL requested changes to one note together, with one before/after preview and ONE user confirmation. Read needed pages first and pass expectedVersion. Use batch_edit for multiple sections: all edits use the same original snapshot and are saved atomically. Use replace_content when the user requests a whole-document rewrite; do not split that request into chapter-by-chapter confirmations. Use replace_range for a single local change and append_content only for genuine additions. Show returned locations and before/after differences, not a bare confirmation request. Do not retry after rejection or write unchanged observations. Confirmation is conversational, NOT a popup. Collect ALL edits requested for this note into ONE proposal, not one proposal per paragraph/chapter. The first call returns pending_confirmation without writing. Read all preview pages, show affected sections and concrete before/after changes (clearly label any abbreviated excerpts), then ask for ONE confirmation and end the turn. Never just say "please confirm". After next-turn agreement call knowledge_note_confirm with confirmationId, not this tool again.

参数 JSON Schema：

```json
{
  "type": "object",
  "additionalProperties": false,
  "properties": {
    "noteHandle": {
      "type": "string",
      "description": "Exact signed handle returned by knowledge_note_list or knowledge_note_search."
    },
    "knowledgeHandle": {
      "type": "string",
      "description": "Mounted knowledge document referencing this note. Checked against current mounts and references on every call; partner heartbeat uses its dedicated recording tool."
    },
    "operation": {
      "type": "string",
      "enum": [
        "rename",
        "batch_edit",
        "replace_range",
        "replace_content",
        "append_content"
      ],
      "description": "batch_edit: combine all requested local edits/merges/deletions in one proposal, preserving untouched text. replace_content: requested whole-document restructuring/rewrite. Never append replacement sections or ask for one confirmation per section."
    },
    "oldText": {
      "type": "string",
      "description": "For replace_range: exact existing text copied from knowledge_note_read. Must match exactly once. value replaces only this text; all other characters are preserved by the server."
    },
    "edits": {
      "type": "array",
      "minItems": 1,
      "maxItems": 100,
      "description": "For batch_edit only. Collect every requested section here before calling once. Anchors refer to the SAME original version, must be unique, and may not overlap. Empty newText deletes that range.",
      "items": {
        "type": "object",
        "additionalProperties": false,
        "properties": {
          "oldText": {
            "type": "string"
          },
          "newText": {
            "type": "string"
          }
        },
        "required": [
          "oldText",
          "newText"
        ]
      }
    },
    "summary": {
      "type": "string",
      "description": "Briefly describe how this complete set of changes addresses the user request; concrete before/after previews are generated by the server."
    },
    "expectedVersion": {
      "type": "integer",
      "minimum": 1,
      "description": "For content updates, pass note.version from knowledge_note_read. A stale version is rejected; reread and merge instead of overwriting."
    },
    "value": {
      "type": "string",
      "description": "Required for operations other than batch_edit: new name or content. Omit for batch_edit and supply edits instead."
    }
  },
  "required": [
    "noteHandle",
    "operation"
  ]
}
```

## 工具：knowledge_read

Read one approved knowledge document using the exact short handle returned by knowledge_search. Handles are session-bound and may expire after restart or a source switch; search again on REFERENCE_UNAVAILABLE, never repeat the stale reference. Long documents are paginated; when a result says it was truncated, call again with the reported offset. Body truncation is separate from reference validity.

参数 JSON Schema：

```json
{
  "type": "object",
  "additionalProperties": false,
  "properties": {
    "handle": {
      "type": "string",
      "description": "Exact opaque handle returned by knowledge_search. Do not reconstruct it."
    },
    "offset": {
      "type": "integer",
      "description": "Character offset for continuing a long section; default 0."
    },
    "maxChars": {
      "type": "integer",
      "description": "Characters to return, default 12000 and maximum 20000."
    }
  },
  "required": [
    "handle"
  ]
}
```

## 工具：knowledge_search

Second-stage knowledge retrieval. Search one exact knowledge base returned by knowledge_base_search. The base must still be mounted for recall in THIS session. Returns ranked snippets and short session-bound references in handle; call knowledge_read with that exact handle. Never invent or reconstruct references. If a reference is unavailable, search again and read before retrying a mutation.

参数 JSON Schema：

```json
{
  "type": "object",
  "additionalProperties": false,
  "properties": {
    "query": {
      "type": "string",
      "description": "What to find. Prefer focused words from the current user request."
    },
    "base": {
      "type": "string",
      "description": "Exact mounted knowledge-base id or name returned by knowledge_base_search."
    },
    "limit": {
      "type": "integer",
      "description": "Maximum ranked results, default 8 and maximum 20."
    }
  },
  "required": [
    "query",
    "base"
  ]
}
```
