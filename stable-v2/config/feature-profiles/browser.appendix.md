# 已登录浏览器 (browser) 附录

本文件是精确参数与原始规范，只在需要具体字段时读取。

## 工具：bsk_assist

Display and human-assistance operations. Actions: resize, emulate, request-help. resize requires width/height; emulate accepts device or width/height/mobile, or off alone; request-help requires prompt and can wait for explicit completion criteria.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "action": {
      "type": "string",
      "description": "Operation to perform. Other arguments are action-dependent and are validated by that operation.",
      "enum": [
        "resize",
        "emulate",
        "request-help"
      ]
    },
    "session": {
      "type": "string",
      "description": "bsk session id to act on; must be one created by bsk_session with action=start. Omit to use the current session (the one most recently started or used)."
    },
    "tabId": {
      "type": "integer",
      "description": "Target tab id. Omit to use the Agent Window's active tab."
    },
    "width": {
      "type": "integer",
      "description": "Window/viewport width."
    },
    "height": {
      "type": "integer",
      "description": "Window/viewport height."
    },
    "device": {
      "type": "string",
      "description": "Emulation device preset.",
      "enum": [
        "iphone-14",
        "iphone-14-pro-max",
        "iphone-se",
        "pixel-7",
        "galaxy-s23",
        "ipad-mini",
        "galaxy-tab-s8"
      ]
    },
    "mobile": {
      "type": "boolean",
      "description": "Enable a mobile viewport with width/height."
    },
    "off": {
      "type": "boolean",
      "description": "Clear emulation; use alone."
    },
    "prompt": {
      "type": "string",
      "description": "Instructions shown to the user for request-help."
    },
    "title": {
      "type": "string",
      "description": "Optional request-help title."
    },
    "targets": {
      "type": "array",
      "description": "Refs/selectors highlighted for request-help.",
      "items": {
        "type": "string"
      }
    },
    "timeoutMs": {
      "type": "integer",
      "description": "Command timeout in milliseconds; must be greater than zero."
    },
    "completionCriteria": {
      "type": "object",
      "description": "Automatic completion detector for request-help (at most 8 conditions across any and all).",
      "additionalProperties": false,
      "properties": {
        "any": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "properties": {
              "urlContains": {
                "type": "string"
              },
              "urlMatches": {
                "type": "string",
                "description": "RE2-compatible URL regex (max 128 characters; compiled program max 4096 instructions)."
              },
              "selectorExists": {
                "type": "string"
              },
              "selectorMissing": {
                "type": "string"
              },
              "textExists": {
                "type": "string"
              },
              "textMissing": {
                "type": "string"
              }
            }
          }
        },
        "all": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "properties": {
              "urlContains": {
                "type": "string"
              },
              "urlMatches": {
                "type": "string",
                "description": "RE2-compatible URL regex (max 128 characters; compiled program max 4096 instructions)."
              },
              "selectorExists": {
                "type": "string"
              },
              "selectorMissing": {
                "type": "string"
              },
              "textExists": {
                "type": "string"
              },
              "textMissing": {
                "type": "string"
              }
            }
          }
        },
        "stableForMs": {
          "type": "integer"
        }
      }
    }
  },
  "required": [
    "action"
  ]
}
```

## 工具：bsk_inspect

Inspect page state and explicitly control task-scoped debugging. Actions: observe, snapshot, html, screenshot, console, network, video, extract. video with videoAction starts/stops a requested recording, checks status, lists, saves or discards MP4 artifacts. Start video before task operations and stop before session teardown. extract reads loaded table/list rows with columns and sources, without scrolling or paging: discover first, then pass extractTarget; check coverage and warnings before calling the data complete. Prefer observe, then snapshot, then bounded html; use screenshot for visual evidence. console/network support cursor fields since/limit/maxTextChars. debug with debugAction starts/stops capture, reads/exports evidence, or explicitly controls network traffic. rule_add/rule_enable can block, modify or mock live requests; replay sends a new request and may change server data. Start capture before visiting the page.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "action": {
      "type": "string",
      "description": "Operation to perform. Other arguments are action-dependent and are validated by that operation.",
      "enum": [
        "observe",
        "snapshot",
        "html",
        "screenshot",
        "console",
        "network",
        "debug",
        "video",
        "extract"
      ]
    },
    "session": {
      "type": "string",
      "description": "bsk session id to act on; must be one created by bsk_session with action=start. Omit to use the current session (the one most recently started or used)."
    },
    "tabId": {
      "type": "integer",
      "description": "Target tab id. Omit to use the Agent Window's active tab."
    },
    "debugAction": {
      "type": "string",
      "description": "Start capture before visiting the page; read/export evidence. rule_add/rule_enable can block, modify or mock live traffic; replay sends a new request and may change server data.",
      "enum": [
        "performance",
        "aggregate",
        "duplicates",
        "capabilities",
        "activity",
        "wait",
        "pin",
        "unpin",
        "start",
        "stop",
        "status",
        "requests",
        "request",
        "operations",
        "operation",
        "console",
        "pages",
        "export",
        "rules",
        "rule_add",
        "rule_enable",
        "rule_disable",
        "rule_remove",
        "replay"
      ]
    },
    "rule": {
      "type": "string",
      "description": "JSON for rule_add: {match:{url,method?,resource_type?},effect:{type,...},times?:1}. URL is absolute; * matches path/query. Default scope Fetch/XHR; optional Document. Effects: block; modify with same-origin url?,method?,headers? (null removes),body? or json?:{set?,remove?,rename?} for top-level JSON fields; mock with status,body,headers?,delay_ms? (0..10000). Text bodies only. times=0 lasts until disabled/capture ends. Rules run locally; first match wins."
    },
    "replay": {
      "type": "string",
      "description": "JSON for replay: {key:\"unique-attempt\",url?,method?,headers?,body?}. Sends once; reuse key on retry. Same-origin only; changed, truncated or unverified URL/body require complete replacements. URL up to 16384 characters; captured URL up to 2048. A replay may write server data."
    },
    "slowMs": {
      "type": "integer",
      "description": "aggregate only: slow threshold 0..60000 ms, default 1000."
    },
    "windowMs": {
      "type": "integer",
      "description": "duplicates only: fixed burst window 100..10000 ms, default 1000."
    },
    "includeControlled": {
      "type": "boolean",
      "description": "Analysis only: include rule/replay experiments (excluded by default)."
    },
    "budget": {
      "type": "integer",
      "description": "Total JSON output bytes: 4096..262144, default 65536; export exempt. Inspect output.omitted and follow next_since/next_offset."
    },
    "url": {
      "type": "string",
      "description": "requests/analysis: case-sensitive URL substring."
    },
    "method": {
      "type": "string",
      "description": "requests/analysis: exact HTTP method."
    },
    "resourceType": {
      "type": "string",
      "description": "requests/analysis: exact resource type, e.g. Fetch or XHR."
    },
    "status": {
      "type": "integer",
      "description": "requests/analysis: exact HTTP status, 100..599."
    },
    "state": {
      "type": "string",
      "description": "requests/analysis: capture state.",
      "enum": [
        "pending",
        "complete",
        "failed",
        "redirected",
        "interrupted"
      ]
    },
    "kind": {
      "type": "string",
      "description": "requests/analysis: traffic category.",
      "enum": [
        "all",
        "business",
        "resource",
        "extension"
      ]
    },
    "fields": {
      "type": "string",
      "description": "Comma-separated optional request fields; identity and body availability always remain. Discover allowed fields with capabilities."
    },
    "waitMs": {
      "type": "integer",
      "description": "wait only: 0..60000 ms, default 10000; observes execution, never resends it."
    },
    "commandId": {
      "type": "string",
      "description": "wait only: command ID from activity or session_busy. Omit to wait for idle. Completion is not proof of success."
    },
    "runId": {
      "type": "string",
      "description": "Capture ID; defaults to the latest capture."
    },
    "id": {
      "type": "string",
      "description": "Request/operation/rule ID; required for detail, rule updates or replay."
    },
    "name": {
      "type": "string",
      "description": "Short capture name for start."
    },
    "part": {
      "type": "string",
      "description": "Request detail projection; defaults to metadata without body text.",
      "enum": [
        "metadata",
        "request",
        "response",
        "headers",
        "timing"
      ]
    },
    "offset": {
      "type": "integer",
      "description": "Body character or pages/console/performance/analysis entry offset, 0..65536."
    },
    "maxChars": {
      "type": "integer",
      "description": "Body slice size, 1..16384; default 4096."
    },
    "pointer": {
      "type": "string",
      "description": "RFC 6901 pointer into a complete redacted request/response JSON body."
    },
    "videoAction": {
      "type": "string",
      "description": "Record only when requested. Start before task operations; wait for state=recording, then work. Stop before session teardown. A failed start must be reported before proceeding without video.",
      "enum": [
        "start",
        "status",
        "stop",
        "save",
        "list",
        "discard"
      ]
    },
    "recordingId": {
      "type": "string",
      "description": "Video ID returned by start; required for status/stop/save/discard. Remains usable after session stop. list shows only recordings started by this plugin instance."
    },
    "durationMs": {
      "type": "integer",
      "description": "Video start: duration limit, 1000..600000 ms; default 60000. Not a task timeout."
    },
    "quality": {
      "type": "string",
      "description": "Video start: standard (1280 / 15 fps) or clear (1920 / 30 fps). Silent MP4.",
      "enum": [
        "standard",
        "clear"
      ]
    },
    "requestId": {
      "type": "string",
      "description": "Video start: stable retry ID (8..80 letters, digits, _ or -); reuse after a lost reply."
    },
    "overwrite": {
      "type": "boolean",
      "description": "Video save only: replace an existing output file when explicitly authorized."
    },
    "extractKind": {
      "type": "string",
      "description": "Discover containers, or extract the loaded rows of a table/list.",
      "enum": [
        "discover",
        "table",
        "list"
      ]
    },
    "extractTarget": {
      "type": "string",
      "description": "Document-bound target_id returned by extraction discovery; valid for five minutes."
    },
    "selector": {
      "type": "string",
      "description": "Unique container CSS selector in the main document; exclusive with extractTarget/ref."
    },
    "itemSelector": {
      "type": "string",
      "description": "List item selector relative to the container."
    },
    "extractFields": {
      "type": "string",
      "description": "List field JSON: {\"fields\":[{\"key\":\"title\",\"name\":\"Title\",\"selector\":\"h3\",\"read\":\"text\"}]}. Reads: text, href, attribute (requires attribute)."
    },
    "maxRows": {
      "type": "integer",
      "description": "Maximum complete data rows, 1..5000; default 500."
    },
    "maxColumns": {
      "type": "integer",
      "description": "Maximum logical columns, 1..200; default 100."
    },
    "extractTimeoutMs": {
      "type": "integer",
      "description": "Extraction time budget, 100..15000 milliseconds; default 5000."
    },
    "extractFormat": {
      "type": "string",
      "description": "JSON by default. CSV requires output and also writes a metadata sidecar.",
      "enum": [
        "json",
        "csv"
      ]
    },
    "csvSafe": {
      "type": "boolean",
      "description": "CSV only: prefix formula-like values with an apostrophe; retain originals in metadata."
    },
    "output": {
      "type": "string",
      "description": "Debug export: new local JSON path. Video save: explicit MP4 destination chosen by the user; omit to preview and Save As in the extension. Video replacement requires overwrite=true. Extract: new JSON/CSV file on the CLI host; required for CSV."
    },
    "maxDepth": {
      "type": "integer",
      "description": "Tree depth cap for observe/snapshot."
    },
    "maxTokens": {
      "type": "integer",
      "description": "Token cap for observe/snapshot."
    },
    "cursor": {
      "type": "string",
      "description": "Observe continuation cursor; use current refs before continuing."
    },
    "ref": {
      "type": "string",
      "description": "Fresh ref for scoped html or cropped screenshot."
    },
    "maxBytes": {
      "type": "integer",
      "description": "HTML/extraction byte cap."
    },
    "since": {
      "type": "integer",
      "description": "Console/network sequence cursor."
    },
    "limit": {
      "type": "integer",
      "description": "Console/network entry cap; debug lists: 1..100, default 30."
    },
    "maxTextChars": {
      "type": "integer",
      "description": "Console/network per-entry text cap."
    },
    "includeStack": {
      "type": "boolean",
      "description": "Include console stack frames."
    }
  },
  "required": [
    "action"
  ]
}
```

## 工具：bsk_interact

Interact with the active Agent Window tab. Actions: click, hover, wheel, scroll-to, focus, blur, fill, select, press. click/hover/scroll-to/focus/blur/fill/select require target; fill also requires value; select requires values; press requires key and may optionally focus target first. wheel requires a nonzero deltaX or deltaY and optionally accepts target; observe afterwards to check the response.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "action": {
      "type": "string",
      "description": "Operation to perform. Other arguments are action-dependent and are validated by that operation.",
      "enum": [
        "click",
        "hover",
        "wheel",
        "scroll-to",
        "focus",
        "blur",
        "fill",
        "select",
        "press"
      ]
    },
    "session": {
      "type": "string",
      "description": "bsk session id to act on; must be one created by bsk_session with action=start. Omit to use the current session (the one most recently started or used)."
    },
    "tabId": {
      "type": "integer",
      "description": "Target tab id. Omit to use the Agent Window's active tab."
    },
    "target": {
      "type": "string",
      "description": "Snapshot ref such as @e3, or a CSS selector."
    },
    "button": {
      "type": "string",
      "description": "Click button.",
      "enum": [
        "left",
        "middle",
        "right"
      ]
    },
    "clickCount": {
      "type": "integer",
      "description": "Click count; Canvas accepts 1 or 2."
    },
    "captureId": {
      "type": "string",
      "description": "Single-use Canvas screenshot capture for click."
    },
    "imageX": {
      "type": "number",
      "description": "Click X in original PNG pixels; requires captureId/imageY."
    },
    "imageY": {
      "type": "number",
      "description": "Click Y in original PNG pixels; requires captureId/imageX."
    },
    "value": {
      "type": "string",
      "description": "Text for fill."
    },
    "noClear": {
      "type": "boolean",
      "description": "Append instead of clearing for fill."
    },
    "modifiers": {
      "type": "array",
      "description": "Modifiers held during hover or wheel input.",
      "items": {
        "type": "string",
        "enum": [
          "alt",
          "ctrl",
          "meta",
          "shift"
        ]
      }
    },
    "settleMs": {
      "type": "integer",
      "description": "Hover settle delay."
    },
    "deltaX": {
      "type": "number",
      "description": "Horizontal wheel input in CSS pixels; defaults to 0."
    },
    "deltaY": {
      "type": "number",
      "description": "Vertical wheel input in CSS pixels; defaults to 0."
    },
    "timeoutMs": {
      "type": "integer",
      "description": "Command timeout in milliseconds; must be greater than zero."
    },
    "values": {
      "type": "array",
      "description": "Option values for select; at least one is required.",
      "items": {
        "type": "string"
      }
    },
    "key": {
      "type": "string",
      "description": "Key or combo for press."
    },
    "holdMs": {
      "type": "integer",
      "description": "Key hold duration for press."
    }
  },
  "required": [
    "action"
  ]
}
```

## 工具：bsk_page

Navigate and wait on the active Agent Window tab. Actions: navigate, back, forward, reload, wait, wait-for-element. navigate requires url; reload optionally accepts hard; navigation actions and wait accept waitUntil/timeoutMs. wait-for-element requires target and accepts state/pollMs; its timeoutMs defaults to 10000 (max 300000). Check satisfied: false means timeout, not success. Observe again after a meaningful page change before reusing refs.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "action": {
      "type": "string",
      "description": "Operation to perform. Other arguments are action-dependent and are validated by that operation.",
      "enum": [
        "navigate",
        "back",
        "forward",
        "reload",
        "wait",
        "wait-for-element"
      ]
    },
    "session": {
      "type": "string",
      "description": "bsk session id to act on; must be one created by bsk_session with action=start. Omit to use the current session (the one most recently started or used)."
    },
    "tabId": {
      "type": "integer",
      "description": "Target tab id. Omit to use the Agent Window's active tab."
    },
    "url": {
      "type": "string",
      "description": "Destination URL; required for navigate."
    },
    "waitUntil": {
      "type": "string",
      "description": "Page lifecycle phase to wait for (default: load).",
      "enum": [
        "load",
        "domcontentloaded",
        "networkidle",
        "commit"
      ]
    },
    "timeoutMs": {
      "type": "integer",
      "description": "Command timeout in milliseconds; must be greater than zero."
    },
    "hard": {
      "type": "boolean",
      "description": "Bypass cache for reload."
    },
    "target": {
      "type": "string",
      "description": "wait-for-element: fresh @eN ref or observed main-document CSS selector; no text=, XPath or Playwright locators."
    },
    "state": {
      "type": "string",
      "description": "wait-for-element (default: visible). hidden includes absence; visible does not mean enabled.",
      "enum": [
        "visible",
        "hidden",
        "attached",
        "detached"
      ]
    },
    "pollMs": {
      "type": "integer",
      "description": "wait-for-element poll interval, 16..2000 ms (default: 100)."
    }
  },
  "required": [
    "action"
  ]
}
```

## 工具：bsk_session

Manage plugin-owned browser sessions. Actions: start opens an Agent Window; stop closes an owned session; list returns owned sessions. For start, url/device/width/height/noFocus are optional. When a specific profile is required, always set browser to its verified instance ID or unique label, even with one connected browser; stop if the target is unknown or unavailable instead of omitting or changing browser. For stop, specify session or requestId (not both), or omit both to retry an unacknowledged stop before selecting the current owned session. If several stops await acknowledgement, specify a target. Once accepted, cleanup continues if the call is aborted.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "action": {
      "type": "string",
      "description": "Operation to perform. Other arguments are action-dependent and are validated by that operation.",
      "enum": [
        "start",
        "stop",
        "list"
      ]
    },
    "session": {
      "type": "string",
      "description": "For stop: owned session ID; mutually exclusive with requestId. Omit both targets to retry an unacknowledged stop before using the current session."
    },
    "requestId": {
      "type": "string",
      "description": "For stop: owned lifecycle request ID to stop or acknowledge; mutually exclusive with session. Targets the original start even if its short session ID is reused or was never received."
    },
    "url": {
      "type": "string",
      "description": "Initial URL for start."
    },
    "width": {
      "type": "integer",
      "description": "Agent Window width; start requires height too."
    },
    "height": {
      "type": "integer",
      "description": "Agent Window height; start requires width too."
    },
    "noFocus": {
      "type": "boolean",
      "description": "Background by default. Set false to explicitly open the Agent Window in front."
    },
    "browser": {
      "type": "string",
      "description": "Target browser instance ID or verified unique label for start. Always set this when a specific profile is required, even if only one browser is connected. Confirm the mapping with the user if unknown; never omit or substitute the selector to recover from an unavailable target."
    },
    "device": {
      "type": "string",
      "description": "Device preset for start.",
      "enum": [
        "iphone-14",
        "iphone-14-pro-max",
        "iphone-se",
        "pixel-7",
        "galaxy-s23",
        "ipad-mini",
        "galaxy-tab-s8"
      ]
    }
  },
  "required": [
    "action"
  ]
}
```

## 工具：bsk_tabs

Manage tabs visible to an owned session. Actions: list, create, select, close, borrow, return. select/close/borrow/return require tabId from list/create. Borrow moves a user tab into the Agent Window; return it as soon as the task finishes.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "action": {
      "type": "string",
      "description": "Operation to perform. Other arguments are action-dependent and are validated by that operation.",
      "enum": [
        "list",
        "create",
        "select",
        "close",
        "borrow",
        "return"
      ]
    },
    "session": {
      "type": "string",
      "description": "bsk session id to act on; must be one created by bsk_session with action=start. Omit to use the current session (the one most recently started or used)."
    },
    "tabId": {
      "type": "integer",
      "description": "Target tab id. Omit to use the Agent Window's active tab."
    },
    "scope": {
      "type": "string",
      "description": "Tab scope for list.",
      "enum": [
        "user",
        "agent",
        "all"
      ]
    },
    "url": {
      "type": "string",
      "description": "Initial URL for create."
    },
    "active": {
      "type": "boolean",
      "description": "Focus the created tab (default true)."
    },
    "index": {
      "type": "integer",
      "description": "Insertion index for create."
    }
  },
  "required": [
    "action"
  ]
}
```
