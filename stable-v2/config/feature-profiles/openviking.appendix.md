# OpenViking (openviking) 附录

本文件是精确参数与原始规范，只在需要具体字段时读取。

## 工具：mcp__openviking__add_resource

Add a resource to OpenViking. Asynchronous — processing happens in the background.

    For an agent skill, use add_skill instead: a skill added here is stored as an ordinary
    resource and never becomes an installed skill. Copying a source's text into a file with
    write instead skips parsing and stores a plain file.

    Preserve the existing Resource layout and account policy. Resource directory rules do not
    apply to Memory, which is organized by the memory extraction system. Keep one stable root
    per source; use ``parent`` for a new source and exact ``to`` for an in-place refresh.
    Inspect the target space with ``list``/``tree`` before adding when practical and reuse its
    existing directories; never create a synonymous category (e.g. ``documents/``, ``pdfs/``)
    when one already fits. For a new category prefer the conventional names ``repos/``,
    ``docs/``, ``sites/``, ``datasets/``, ``media/``, ``artifacts/``,
    ``projects/<name>/`` for a multi-category project, or another plural domain noun for entity
    collections (``items/``, ``people/``).

    Where it goes: ``viking://resources/`` is shared with the whole account and is the
    default when ``to`` and ``parent`` are empty (unless a default add target is
    configured). ``viking://~/resources/`` is the caller's own resources, visible only to
    them. If visibility cannot be inferred, prefer the current identity's
    ``parent="viking://~/resources/inbox"`` and report that choice; never silently put
    identity-private material in the shared root.

    Remote URL: pass ``path`` as an http(s)://, git@, ssh://, or git:// URL. A sitemap /
    RSS / Atom URL ingests the WHOLE site as one resource tree; pass ``args={"site": true}``
    to force whole-site ingestion from a bare domain.

    Local file: pass ``path`` as a filesystem path (e.g. ``/tmp/foo.pdf``). The response is an
    upload instruction — HTTP POST the file to the returned URL and the server ingests it
    automatically; you do NOT need to call this tool again.

    Args:
        path: Remote URL or local filesystem path. Required unless ``temp_file_id`` is set.
        temp_file_id: Server-minted upload id from a prior signed local-file upload.
        add_type: Explicit Connector source type (e.g. "tos", "git"). When set, the
            request routes through the Connector integration (must be enabled
            server-side) and ``path`` is sent verbatim — never treated as a local
            file. Requires an exact ``to`` target and cannot be combined with
            ``temp_file_id`` or ``parent``. Leave empty for the default path-probing
            behavior.
        description: Optional human-readable reason for adding the resource.
        watch_interval: Auto-refresh cadence in minutes. 0 = no watch. Prefer >=1440 (24h)
            unless the source changes faster — every refresh re-embeds the whole resource.
            Only applies to remote-URL invocations.
        processing_mode: "semantic_and_vectors" for normal semantic processing, or
            "vectors_only" to skip semantic understanding and only build vector indexes.
        to: Exact final URI including the leaf name (e.g.
            "viking://resources/volcengine/OpenViking", or
            "viking://~/resources/OpenViking" for an identity-private copy). Written verbatim; an existing
            target is synced to match the new source, so visible entries it does not
            contain are deleted. Required when ``add_type`` is set.
        parent: Directory to store the resource under, for remote or
            local-file imports (e.g. "viking://~/resources" or "viking://resources");
            missing directories are created automatically. The leaf name comes from the source.
            Never overwrites
            — a collision reserves the next free name ("name_1", "name_2", ...) and
            returns a warning. Mutually exclusive with ``to``; not supported when
            ``add_type`` is set. Leaving both empty derives the directory and the name
            from the source and handles collisions like ``parent``.
        tags: Optional explicit k=v retrieval tags to apply after ingestion.
        tag_mode: Tag update mode: "replace", "append", or "clear". Clear removes
            existing tags without requiring ``tags``. Defaults to "replace".
        acl: Optional ACL on the final import root. Uses acl_mode (inherit/restricted)
            and entries with principal (user:<id>, group:<id>, user:*) and level
            (read/write/manage). Requires manage on the existing target or parent
            for a new target. Omit to preserve existing ACL or inherit on creation.
        args: Parser-specific options, e.g. {"auth_config": {"token": "..."}}
            for native HTTPS Git imports and watches, {"feishu_access_token": "..."}
            for Feishu imports, {"site": true} for whole-site ingestion, or
            {"parse_mode": "no_split"} to keep each parsed document body in one file.
    

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "path": {
      "default": "",
      "title": "Path",
      "type": "string"
    },
    "temp_file_id": {
      "default": "",
      "title": "Temp File Id",
      "type": "string"
    },
    "add_type": {
      "default": "",
      "title": "Add Type",
      "type": "string"
    },
    "description": {
      "default": "",
      "title": "Description",
      "type": "string"
    },
    "watch_interval": {
      "default": 0,
      "title": "Watch Interval",
      "type": "number"
    },
    "processing_mode": {
      "default": "semantic_and_vectors",
      "enum": [
        "semantic_and_vectors",
        "vectors_only"
      ],
      "title": "Processing Mode",
      "type": "string"
    },
    "to": {
      "default": "",
      "title": "To",
      "type": "string"
    },
    "parent": {
      "default": "",
      "title": "Parent",
      "type": "string"
    },
    "tags": {
      "items": {
        "type": "string"
      },
      "type": "array",
      "title": "Tags"
    },
    "tag_mode": {
      "default": "replace",
      "title": "Tag Mode",
      "type": "string"
    },
    "args": {
      "additionalProperties": true,
      "type": "object",
      "title": "Args"
    },
    "acl": {
      "additionalProperties": false,
      "description": "Explicit changes to a node's own permissions, never inherited grants.",
      "properties": {
        "entries": {
          "items": {
            "additionalProperties": false,
            "properties": {
              "principal": {
                "title": "Principal",
                "type": "string"
              },
              "level": {
                "enum": [
                  "read",
                  "write",
                  "manage"
                ],
                "title": "AclLevel",
                "type": "string"
              }
            },
            "required": [
              "principal",
              "level"
            ],
            "title": "AclEntry",
            "type": "object"
          },
          "type": "array",
          "title": "Entries"
        },
        "acl_mode": {
          "enum": [
            "inherit",
            "restricted"
          ],
          "type": "string",
          "title": "Acl Mode"
        }
      },
      "title": "AclSpec",
      "type": "object"
    }
  },
  "title": "add_resourceArguments"
}
```

## 工具：mcp__openviking__add_skill

Create, install, or replace an agent skill in OpenViking.

    New skill: pass the full SKILL.md text (YAML frontmatter with ``name`` and
    ``description``, then the Markdown body) as ``data``.

    Git source: pass a repository URL or a GitHub ``.../tree/<ref>/<dir>`` URL as ``path``.
    Every skill in the source is installed unless ``skills`` names some; ``list_only=true``
    lists them without installing.

    Local skill: pass the path of a SKILL.md, a skill directory, or a .zip as ``path``. The
    response is an upload instruction — zip a directory first, then HTTP POST the file to the
    returned URL and the server installs it; you do NOT need to call this tool again.

    Installing under an existing name replaces that skill's SKILL.md and adds the new files;
    files the new version no longer has are kept. Ask the user before installing from a
    source they did not name.

    This is the only MCP tool that creates or changes a skill. To update one, read its
    SKILL.md, revise the whole text, and call add_skill again with the same name and the same
    ``target_uri``; do not use the write or edit tools on files inside a skill package, and do
    not use forget or a directory move to delete or rename one -- remove a skill with
    ``ov skills remove <name>`` or ``DELETE /api/v1/skills/{name}``, and rename it by
    installing it under the new name and removing the old one.

    Args:
        data: Full SKILL.md text of a skill to create or replace.
        path: Git URL, or a local path to a SKILL.md, a skill directory, or a .zip.
        skills: Names of the skill directories to install from a multi-skill source.
        target_uri: Skill root to install under. Empty installs into the caller's own
            skills; "viking://agent/skills" shares the skill with the whole account.
        list_only: Describe the skills in a Git or local source without installing them.
    

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "data": {
      "default": "",
      "title": "Data",
      "type": "string"
    },
    "path": {
      "default": "",
      "title": "Path",
      "type": "string"
    },
    "skills": {
      "items": {
        "type": "string"
      },
      "type": "array",
      "title": "Skills"
    },
    "target_uri": {
      "default": "",
      "title": "Target Uri",
      "type": "string"
    },
    "list_only": {
      "default": false,
      "title": "List Only",
      "type": "boolean"
    }
  },
  "title": "add_skillArguments"
}
```

## 工具：mcp__openviking__cancel_watch

Cancel a watch task by its target URI (e.g. "viking://resources/volcengine/OpenViking").

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "to_uri": {
      "title": "To Uri",
      "type": "string"
    }
  },
  "required": [
    "to_uri"
  ],
  "title": "cancel_watchArguments"
}
```

## 工具：mcp__openviking__download

Get a short-lived URL for downloading the original bytes of one file (any type, including PDF, images, archives, audio and video). It does not return the content; use `read` to read text. Fetch the URL with `curl -fL -o <local path> <url>`; no OpenViking API key is needed. The link works once and expires in about 10 minutes; call download again for a new link. Directories are not supported: use `list` or `tree` and download files one at a time.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "uri": {
      "title": "Uri",
      "type": "string"
    }
  },
  "required": [
    "uri"
  ],
  "title": "downloadArguments"
}
```

## 工具：mcp__openviking__edit

Replace an exact string with new text in an existing viking:// file. Use this for targeted changes instead of rewriting the whole file with the write tool. old_string must match the file's current content exactly, including indentation and newlines; use the read tool first to see it. The edit fails and the file is left unchanged if old_string is not found, or if it matches more than once and replace_all is false (pass more surrounding context to make it unique, or set replace_all=true to replace every occurrence). Pass new_string="" to delete old_string.

    Editing a memory file preserves its metadata; after an edit, search indexes refresh in the background (pass wait=true to block until search reflects the change).

    Do not edit files inside a skill package (.../skills/<name>/): read the skill's SKILL.md, revise the whole text, and install it again with the add_skill tool.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "uri": {
      "title": "Uri",
      "type": "string"
    },
    "old_string": {
      "title": "Old String",
      "type": "string"
    },
    "new_string": {
      "title": "New String",
      "type": "string"
    },
    "replace_all": {
      "default": false,
      "title": "Replace All",
      "type": "boolean"
    },
    "wait": {
      "default": false,
      "title": "Wait",
      "type": "boolean"
    }
  },
  "required": [
    "uri",
    "old_string",
    "new_string"
  ],
  "title": "editArguments"
}
```

## 工具：mcp__openviking__find

Fast semantic retrieval without session context. Returns ranked memories, resources, and skills with URI, abstract, and score. context_type="skill" returns one hit per skill package, pointing at its SKILL.md, and without target_uri searches both the user's own and the account-shared skills.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "query": {
      "title": "Query",
      "type": "string"
    },
    "target_uri": {
      "default": "",
      "title": "Target Uri",
      "type": "string"
    },
    "limit": {
      "default": 10,
      "title": "Limit",
      "type": "integer"
    },
    "min_score": {
      "default": 0.35,
      "title": "Min Score",
      "type": "number"
    },
    "level": {
      "items": {
        "type": "integer"
      },
      "type": "array",
      "title": "Level"
    },
    "context_type": {
      "items": {
        "type": "string"
      },
      "type": "array",
      "title": "Context Type"
    },
    "read_content": {
      "default": false,
      "title": "Read Content",
      "type": "boolean"
    },
    "events_time_decay_protection": {
      "type": "string",
      "title": "Events Time Decay Protection"
    }
  },
  "required": [
    "query"
  ],
  "title": "findArguments"
}
```

## 工具：mcp__openviking__forget

Permanently delete a viking:// URI from OpenViking. Irreversible — confirm with user before calling.

    Deleting a skill directory this way leaves the skill's stored privacy values behind:
    remove a skill with ``ov skills remove <name>`` or ``DELETE /api/v1/skills/{name}``.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "uri": {
      "title": "Uri",
      "type": "string"
    },
    "recursive": {
      "default": false,
      "title": "Recursive",
      "type": "boolean"
    }
  },
  "required": [
    "uri"
  ],
  "title": "forgetArguments"
}
```

## 工具：mcp__openviking__get_acl

Read a shared resource's full ACL (direct, inherited, effective grants).
    Requires manage permission on that resource, or account ADMIN role.
    

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "uri": {
      "title": "Uri",
      "type": "string"
    }
  },
  "required": [
    "uri"
  ],
  "title": "get_aclArguments"
}
```

## 工具：mcp__openviking__glob

Find viking:// files matching a glob pattern (e.g. **/*.md, *.py). Use this for filename matching; use the search tool for content-based retrieval.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "pattern": {
      "title": "Pattern",
      "type": "string"
    },
    "uri": {
      "default": "viking://",
      "title": "Uri",
      "type": "string"
    },
    "node_limit": {
      "default": 100,
      "title": "Node Limit",
      "type": "integer"
    }
  },
  "required": [
    "pattern"
  ],
  "title": "globArguments"
}
```

## 工具：mcp__openviking__grep

Search content in viking:// files using regex patterns (like grep). Supports multiple patterns searched concurrently. Use this for exact text matching; use the search tool for semantic retrieval.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "uri": {
      "title": "Uri",
      "type": "string"
    },
    "pattern": {
      "items": {
        "type": "string"
      },
      "type": "array",
      "title": "Pattern"
    },
    "case_insensitive": {
      "default": false,
      "title": "Case Insensitive",
      "type": "boolean"
    },
    "node_limit": {
      "default": 10,
      "title": "Node Limit",
      "type": "integer"
    }
  },
  "required": [
    "uri",
    "pattern"
  ],
  "title": "grepArguments"
}
```

## 工具：mcp__openviking__health

Check whether the OpenViking server is healthy.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {},
  "title": "healthArguments"
}
```

## 工具：mcp__openviking__list

List one sorted page under a viking:// directory URI.

    Args:
        uri: Directory URI to list; defaults to "viking://" like tree and glob.
        recursive: Whether to recursively list descendants.
        offset: Number of visible entries to skip.
        limit: Optional maximum number of entries.
        sort_by: Optional name or modification-time ordering.
        sort_order: Ascending or descending order.

    Returns:
        A line-oriented directory listing.
    

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "uri": {
      "default": "viking://",
      "title": "Uri",
      "type": "string"
    },
    "recursive": {
      "default": false,
      "title": "Recursive",
      "type": "boolean"
    },
    "offset": {
      "default": 0,
      "title": "Offset",
      "type": "integer"
    },
    "limit": {
      "type": "integer",
      "title": "Limit"
    },
    "sort_by": {
      "enum": [
        "name",
        "mtime"
      ],
      "type": "string",
      "title": "Sort By"
    },
    "sort_order": {
      "default": "asc",
      "enum": [
        "asc",
        "desc"
      ],
      "title": "Sort Order",
      "type": "string"
    }
  },
  "title": "lsArguments"
}
```

## 工具：mcp__openviking__list_groups

List group IDs that can be granted resource access in the caller's account.
    Available to all account users; does not disclose group membership.
    

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {},
  "title": "list_groupsArguments"
}
```

## 工具：mcp__openviking__list_users

Find users to grant access to in the caller's account. Returns user_id and
    matching total by default, including for administrators. query matches a
    substring of user_id. include_credentials=true requires ADMIN or ROOT and
    returns available credentials; it is forbidden in trusted auth mode.
    Resource manage permission does not grant account administrator privileges.
    

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "query": {
      "default": "",
      "title": "Query",
      "type": "string"
    },
    "limit": {
      "default": 100,
      "minimum": 1,
      "title": "Limit",
      "type": "integer"
    },
    "page": {
      "default": 1,
      "minimum": 1,
      "title": "Page",
      "type": "integer"
    },
    "include_credentials": {
      "default": false,
      "title": "Include Credentials",
      "type": "boolean"
    }
  },
  "title": "list_usersArguments"
}
```

## 工具：mcp__openviking__list_watches

List watch tasks (auto-refresh subscriptions) visible to the current user.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {},
  "title": "list_watchesArguments"
}
```

## 工具：mcp__openviking__privacy_resolve

Turn an {{ov_privacy:...}} placeholder into its actual API key or token.
    When a SKILL.md, document or tool result contains, for example,
    {{ov_privacy:alice:viking://~/privacy/credential/github#/values/pat}},
    and the task needs that credential, pass the whole placeholder as reference.
    Use the returned value in the API's Authorization header or credential field;
    do not send the placeholder itself as a key. Returns one current field owned
    by the caller. Keep references in saved documents and do not echo the secret
    in chat. If you do not know the reference, use privacy_tree first.
    

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "reference": {
      "description": "Copy the entire {{ov_privacy:...}} placeholder unchanged, or supply one field-level Privacy URI. Omit surrounding text such as Authorization: Bearer.",
      "maxLength": 2048,
      "minLength": 1,
      "title": "Reference",
      "type": "string"
    }
  },
  "required": [
    "reference"
  ],
  "title": "privacy_resolveArguments"
}
```

## 工具：mcp__openviking__privacy_tree

Find saved API keys, tokens and other private fields for the current user.
    Use when you need to check whether a GitHub PAT or a skill's api_key is saved.
    Returns categories, targets, active versions, configured flags and complete
    {{ov_privacy:...}} references, never secret values or history. Pass a returned
    reference to privacy_resolve when you need the actual value for a task.
    

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "category": {
      "type": "string",
      "description": "Only list this category, e.g. credential or skill",
      "title": "Category"
    }
  },
  "title": "privacy_treeArguments"
}
```

## 工具：mcp__openviking__privacy_upsert

Save a credential the user supplies, e.g. a GitHub PAT or a skill's api_key.
    For a GitHub PAT use category="credential", target_key="github", values={"pat":
    "<user-provided-token>"}. Creates the target or merges the supplied fields;
    updating pat preserves other fields such as username. Changed values create
    and activate a version; this does not rotate keys at GitHub or other providers.
    Returns updated-field metadata and {{ov_privacy:...}} references, never values.
    Use those references instead of embedding the key in saved documents or memory.
    

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "category": {
      "description": "Credential category, e.g. credential or skill",
      "title": "Category",
      "type": "string"
    },
    "target_key": {
      "description": "Credential target, e.g. github or the skill name",
      "title": "Target Key",
      "type": "string"
    },
    "values": {
      "additionalProperties": true,
      "description": "Fields to save, e.g. {\"pat\": \"user-provided-token\"}. Unspecified fields are preserved.",
      "title": "Values",
      "type": "object"
    }
  },
  "required": [
    "category",
    "target_key",
    "values"
  ],
  "title": "privacy_upsertArguments"
}
```

## 工具：mcp__openviking__read

Read one or more viking:// file URIs. Text reads accept line-based offset/limit. Raster images and supported audio return native MCP content blocks. For directory listing, use the list tool instead.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "uris": {
      "items": {
        "type": "string"
      },
      "type": "array",
      "title": "Uris"
    },
    "offset": {
      "default": 0,
      "title": "Offset",
      "type": "integer"
    },
    "limit": {
      "default": -1,
      "title": "Limit",
      "type": "integer"
    }
  },
  "required": [
    "uris"
  ],
  "title": "readArguments"
}
```

## 工具：mcp__openviking__remember

Submit information for OpenViking long-term memory extraction. Use when the user says 'remember this', shares preferences, important facts, or decisions worth persisting. Extraction runs in the background and decides which memories to create or update.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "messages": {
      "items": {
        "properties": {
          "role": {
            "description": "Message role",
            "enum": [
              "user",
              "assistant"
            ],
            "title": "Role",
            "type": "string"
          },
          "content": {
            "description": "Message text content",
            "title": "Content",
            "type": "string"
          }
        },
        "required": [
          "role",
          "content"
        ],
        "title": "StoreMessage",
        "type": "object"
      },
      "title": "Messages",
      "type": "array"
    }
  },
  "required": [
    "messages"
  ],
  "title": "rememberArguments"
}
```

## 工具：mcp__openviking__search

Retrieval with optional session context and intent analysis.

    ``mode="list"`` returns ranked memories, resources, and skills with URI,
    abstract, and score. ``mode="context"`` returns an injection-ready,
    token-budgeted context block and supports category quotas, purpose presets,
    detail tiers, cross-turn deduplication, peer scoping, and optional rewriting.
    ``target_uri`` is only supported in list mode.
    

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "query": {
      "title": "Query",
      "type": "string"
    },
    "search_type": {
      "default": "semantic",
      "enum": [
        "semantic",
        "keywords"
      ],
      "title": "Search Type",
      "type": "string"
    },
    "target_uri": {
      "default": "",
      "title": "Target Uri",
      "type": "string"
    },
    "session_id": {
      "type": "string",
      "title": "Session Id"
    },
    "limit": {
      "default": 10,
      "title": "Limit",
      "type": "integer"
    },
    "min_score": {
      "type": "number",
      "title": "Min Score"
    },
    "level": {
      "items": {
        "type": "integer"
      },
      "type": "array",
      "title": "Level"
    },
    "context_type": {
      "items": {
        "type": "string"
      },
      "type": "array",
      "title": "Context Type"
    },
    "mode": {
      "default": "list",
      "enum": [
        "list",
        "context"
      ],
      "title": "Mode",
      "type": "string"
    },
    "query_expansion": {
      "default": "auto",
      "enum": [
        "off",
        "auto"
      ],
      "title": "Query Expansion",
      "type": "string"
    },
    "max_tokens": {
      "default": 1600,
      "maximum": 32000,
      "minimum": 64,
      "title": "Max Tokens",
      "type": "integer"
    },
    "quotas": {
      "additionalProperties": {
        "type": "integer"
      },
      "type": "object",
      "title": "Quotas"
    },
    "purpose": {
      "enum": [
        "chat",
        "coding"
      ],
      "type": "string",
      "title": "Purpose"
    },
    "detail": {
      "default": "auto",
      "enum": [
        "auto",
        "abstract",
        "overview",
        "full"
      ],
      "title": "Detail",
      "type": "string"
    },
    "detail_by_category": {
      "additionalProperties": {
        "type": "string"
      },
      "type": "object",
      "title": "Detail By Category"
    },
    "dedup_turns": {
      "default": 0,
      "maximum": 100,
      "minimum": 0,
      "title": "Dedup Turns",
      "type": "integer"
    },
    "exclude_uris": {
      "items": {
        "type": "string"
      },
      "maxItems": 200,
      "type": "array",
      "title": "Exclude Uris"
    },
    "peer_scope": {
      "default": "all",
      "enum": [
        "actor",
        "all"
      ],
      "title": "Peer Scope",
      "type": "string"
    },
    "other_peer_penalty": {
      "type": "number",
      "title": "Other Peer Penalty"
    },
    "other_peer_penalties": {
      "additionalProperties": {
        "type": "number"
      },
      "type": "object",
      "title": "Other Peer Penalties"
    },
    "rewrite": {
      "default": "off",
      "enum": [
        "off",
        "auto"
      ],
      "title": "Rewrite",
      "type": "string"
    },
    "rewrite_max_bullets": {
      "default": 6,
      "maximum": 20,
      "minimum": 1,
      "title": "Rewrite Max Bullets",
      "type": "integer"
    },
    "read_content": {
      "default": false,
      "title": "Read Content",
      "type": "boolean"
    },
    "events_time_decay_protection": {
      "type": "string",
      "title": "Events Time Decay Protection"
    }
  },
  "required": [
    "query"
  ],
  "title": "searchArguments"
}
```

## 工具：mcp__openviking__set_acl

Set a shared resource's ACL; requires manage permission before the change.
    entries replaces direct grants; omitted entries preserves them. Each entry
    has principal (user:<id>, group:<id>, or user:*) and level (read/write/manage).
    acl_mode=inherit adds parent grants; restricted uses only direct grants.
    Reset with acl={"acl_mode":"inherit","entries":[]}. A restricted ACL can
    remove your own access. Account ADMIN retains implicit management access.
    

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "uri": {
      "title": "Uri",
      "type": "string"
    },
    "acl": {
      "additionalProperties": false,
      "description": "Explicit changes to a node's own permissions, never inherited grants.",
      "properties": {
        "entries": {
          "items": {
            "additionalProperties": false,
            "properties": {
              "principal": {
                "title": "Principal",
                "type": "string"
              },
              "level": {
                "enum": [
                  "read",
                  "write",
                  "manage"
                ],
                "title": "AclLevel",
                "type": "string"
              }
            },
            "required": [
              "principal",
              "level"
            ],
            "title": "AclEntry",
            "type": "object"
          },
          "type": "array",
          "title": "Entries"
        },
        "acl_mode": {
          "enum": [
            "inherit",
            "restricted"
          ],
          "type": "string",
          "title": "Acl Mode"
        }
      },
      "title": "AclSpec",
      "type": "object"
    }
  },
  "required": [
    "uri",
    "acl"
  ],
  "title": "set_aclArguments"
}
```

## 工具：mcp__openviking__tree

Show one visible page from a recursive directory tree.

    Args:
        uri: Directory URI to traverse.
        level_limit: Maximum traversal depth.
        node_limit: Existing default result limit.
        include_abstract: Whether to include directory summaries (a skill directory's
            summary is its name and description).
        offset: Number of visible nodes to skip.
        limit: Optional result limit that overrides node_limit.

    Returns:
        An indented directory tree.
    

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "uri": {
      "default": "viking://",
      "title": "Uri",
      "type": "string"
    },
    "level_limit": {
      "default": 3,
      "title": "Level Limit",
      "type": "integer"
    },
    "node_limit": {
      "default": 1000,
      "title": "Node Limit",
      "type": "integer"
    },
    "include_abstract": {
      "default": false,
      "title": "Include Abstract",
      "type": "boolean"
    },
    "offset": {
      "default": 0,
      "title": "Offset",
      "type": "integer"
    },
    "limit": {
      "type": "integer",
      "title": "Limit"
    }
  },
  "title": "treeArguments"
}
```

## 工具：mcp__openviking__write

Write text to a viking:// file. Use this for files you author yourself (notes, profiles, state), the same way you would use a working directory. To change part of an existing file, prefer the edit tool over a full rewrite. To store a file, document, URL, or repo the user gives you, use add_resource; for a skill, use add_skill. Do not copy its text into a file here instead.

    - mode="replace" (default): overwrite the file; creates it and any missing parent directories if needed.
    - mode="create": compatibility alias for replace; overwrite an existing file or create it if missing.
    - Any new file (whether created by "replace", "append", or "create") must end in one of: .md .txt .json .yaml .yml .toml .py .js .ts
    - mode="append": append to the end of an existing file; use the supplied content as the initial body if it is missing.
    - acl: optional shared-resource ACL with acl_mode (inherit/restricted) and entries
      (principal=user:<id>/group:<id>/user:*, level=read/write/manage). Explicit ACL
      requires manage on the target, or its parent for a new file. Omit to preserve
      existing ACL or inherit on creation.

    Writable scopes: viking://resources/, viking://user/{user_id}/, viking://agent/. The viking://~ home alias expands to the caller's user root. The managed user subtrees skills/, peers/, privacy/ and sessions/ are read-only. Do not write inside a skill package under viking://agent/skills/ either: a plain write skips installation, so the skill's abstract, overview and source metadata go stale. Change a skill with the add_skill tool. After a write, semantic search indexes refresh in the background; pass wait=true to block until search reflects the change.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "uri": {
      "title": "Uri",
      "type": "string"
    },
    "content": {
      "title": "Content",
      "type": "string"
    },
    "mode": {
      "default": "replace",
      "enum": [
        "replace",
        "append",
        "create"
      ],
      "title": "Mode",
      "type": "string"
    },
    "wait": {
      "default": false,
      "title": "Wait",
      "type": "boolean"
    },
    "acl": {
      "additionalProperties": false,
      "description": "Explicit changes to a node's own permissions, never inherited grants.",
      "properties": {
        "entries": {
          "items": {
            "additionalProperties": false,
            "properties": {
              "principal": {
                "title": "Principal",
                "type": "string"
              },
              "level": {
                "enum": [
                  "read",
                  "write",
                  "manage"
                ],
                "title": "AclLevel",
                "type": "string"
              }
            },
            "required": [
              "principal",
              "level"
            ],
            "title": "AclEntry",
            "type": "object"
          },
          "type": "array",
          "title": "Entries"
        },
        "acl_mode": {
          "enum": [
            "inherit",
            "restricted"
          ],
          "type": "string",
          "title": "Acl Mode"
        }
      },
      "title": "AclSpec",
      "type": "object"
    }
  },
  "required": [
    "uri",
    "content"
  ],
  "title": "writeArguments"
}
```
