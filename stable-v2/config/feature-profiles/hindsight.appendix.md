# Hindsight 项目记忆 (hindsight) 附录

本文件是精确参数与原始规范，只在需要具体字段时读取。

## 原始规范：hindsight:TOOL_GUIDE

- hindsight_search_knowledge_pages(query) — FIRST STOP, and the way IN to everything below. The code shows what is true today but not what was decided or why; memory shows what was decided or said back then but not whether it still holds. Work built from either alone goes wrong: from code alone it quietly re-litigates settled questions, from memory alone it acts on stale claims. Search BEFORE you act whenever the turn is one of these — they are the ones that go wrong silently:
    • the user reports a bug or a wrong response (the intended behaviour, and the status code or value it should return, may already have been decided);
    • you are about to write or change a test (what this project expects a change to ship with, and how it asserts, is a convention, not a preference);
    • you are implementing something new, or two parts have to fit together;
    • the user asks why something is the way it is, or what is left to do;
    • you are about to commit, and need to know what the change was supposed to honour.
  It ranks the pages by relevance and returns the matching passage, which a page title cannot tell you. What it returns is a past record, not a live reading: a claim that something was fixed, passes, or works is what someone said then — check it against the code before you rely on it, and say so when the two disagree.
  CREDITING IS NOT OPTIONAL AND NOT A JUDGEMENT CALL. If you called this tool and anything it returned reached your reply — quoted, paraphrased, or merely confirming what you were about to say — open that part with a markdown blockquote, exactly: "> 🧠 **From Hindsight memory (<page>)** — <the specific facts you drew on>". Rewriting a snippet in your own words does not make it yours. A search that turned up nothing useful needs no mention at all — just carry on.
- hindsight_list_knowledge_pages / hindsight_read_knowledge_page — BEFORE substantial work, list the pages and read the relevant ones to ground yourself in this repo's architecture, conventions, and past decisions instead of re-deriving them from the code; follow any [[page:<id>]] links you see.
- hindsight_reflect(query) — when pages are too shallow and you need the WHY: deep reasoning over the repo's full memory for the past decision and exact values that explain a behavior or bug (slower — use deliberately, and credit results with a blockquote header "> 🧠 **From Hindsight memory** — <summary>").
- hindsight_capture_initiative(title, summary) — right after the user approves a plan or finishes brainstorming a new feature/capability and you are about to start implementing (BEFORE you write any code), call this to record it as a tracked page; then call it AGAIN with relates_to_page_id set to that page whenever the goal, scope, or rationale materially changes mid-work, so the page tracks the current plan and not the opening one. Skip bug fixes, small tweaks, chores, and trivial course-corrections.
- hindsight_ingest_document(title, content) — save an external document or durable notes/findings you want remembered (not the current conversation — that is captured automatically at session end).

## 工具：hindsight_capture_initiative

Record a new feature or initiative as a tracked knowledge page, so future sessions know it exists and can build on it — and keep that page tracking the plan as it moves.

WHEN TO CALL:
- Starting one: right after the user approves a plan or finishes brainstorming a new feature/capability and you are about to start implementing — BEFORE you write any code. Leave relates_to_page_id empty.
- Plan changed: call it AGAIN — mid-implementation is fine and expected — whenever the goal, scope, or rationale of an initiative you already captured materially changes (an approach is dropped, scope grows or shrinks, the why is rewritten). Pass relates_to_page_id = that initiative's page id so the change lands on the existing page. Never mint a second page for the same initiative.

WHEN TO SKIP: bug fixes, small tweaks, refactors, chores, and trivial course-corrections that leave the goal intact are not initiatives — skip them.

- title: short, specific name (e.g. 'Newsletter refinement chat'). On a recapture, reuse the initiative's existing title.
- summary: 2-3 sentences on what you're building and why — the CURRENT intent, not the originally approved plan (on a recapture, say what changed and why).
- relates_to_page_id: leave empty for a new initiative. Set it to an existing initiative's page id — from hindsight_list_knowledge_pages, or the id this tool returned earlier — to record a plan change or an enhancement to it.

Returns the page id. The page is generated for you — you never format one yourself.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "title": {
      "type": "string"
    },
    "summary": {
      "type": "string"
    },
    "relates_to_page_id": {
      "type": "string"
    }
  },
  "required": [
    "title",
    "summary"
  ]
}
```

## 工具：hindsight_diagnose

Report safe Hindsight runtime diagnostics for this coding-agent session: resolved bank, workspace, harness, config location, API endpoint, and non-secret environment overrides. Use this when memory, hooks, MCP tools, or configuration appear not to work. Tokens and other secret values are never returned.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {}
}
```

## 工具：hindsight_ingest_document

Save an external document or a block of durable notes/findings into this repository's memory so it informs future recall and pages. Use for design notes, research, or reference material you want remembered — not for the conversation you're already in (that's captured automatically at session end). This is ALSO the correction mechanism: when you verify that a retrieved memory is wrong or outdated, ingest a document titled 'Correction: <topic>' stating what memory claimed, what is actually true, and the evidence — the newer fact supersedes the stale one in future retrieval.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "title": {
      "type": "string"
    },
    "content": {
      "type": "string"
    }
  },
  "required": [
    "title",
    "content"
  ]
}
```

## 工具：hindsight_list_knowledge_pages

List this repository's Hindsight knowledge pages — curated, continuously-updated summaries of the project's durable knowledge (architecture, components, conventions, key decisions, and in-flight initiatives). Returns each page's id, title, and a one-line description of what it covers. Call this at the start of any non-trivial task, and again periodically in long sessions, to see what the project already knows before you read code or ask the user. The list changes as work is captured, so re-check it occasionally.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {}
}
```

## 工具：hindsight_read_knowledge_page

Read the full content of one knowledge page by its id (from hindsight_list_knowledge_pages). Call this whenever a listed page is relevant to what you're about to do — e.g. read Conventions before writing new code, Component map before changing a subsystem, or an initiative's page before continuing that feature. A page may contain [[page:<id>]] links to related pages; follow one by calling this tool again with that id. Prefer reading a page over re-deriving the same understanding from source.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "page_id": {
      "type": "string"
    }
  },
  "required": [
    "page_id"
  ]
}
```

## 工具：hindsight_reflect

Deep memory reasoning: an agentic synthesis over this repository's FULL memory (git decisions, past sessions, ingested knowledge) that answers WHY questions — the past decision and exact rule/values that explain a behavior, bug, or convention. Slower than hindsight_search_knowledge_pages (several seconds): reach for it when pages are too shallow and you need the root cause or the decided literals. When the answer informs your reply, credit it visibly with a blockquote header: "> 🧠 **From Hindsight memory** — <summary>".

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "query": {
      "type": "string",
      "description": "the question to reason over memory about"
    }
  },
  "required": [
    "query"
  ]
}
```

## 工具：hindsight_search_knowledge_pages

Search this repository's Hindsight knowledge pages for content relevant to a query — hybrid full-text + semantic search, server-side. Call this when the user's question may be answered by the project's accumulated knowledge (architecture, conventions, decisions, initiatives) rather than by reading code. Returns ranked pages with a relevance snippet; read a full page with hindsight_read_knowledge_page. Crediting is mandatory, not a judgement call: if anything these results contribute reaches your reply — quoted, paraphrased, or merely confirming what you were going to say — open that part with "> 🧠 **From Hindsight memory (<page>)** — <the specific facts you drew on>". Rewriting a snippet in your own words does not make it yours. If none of them bear on the turn, ignore them silently — an unhelpful search needs no mention. These are past records: check a claim that something was fixed or works against the code before relying on it.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "query": {
      "type": "string",
      "description": "what to look for"
    }
  },
  "required": [
    "query"
  ]
}
```

## 工具：hindsight_sync_status

Report whether this repo's memory bank is in sync: gitlog seed present, how much recent history has been deepened with full diffs, conversations ingested, knowledge pages created, and extractions still running. `synced: true` means the seeded memory is fully queryable. Ingestion is automatic and background — if not synced, it is in progress; nothing to run.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {}
}
```
