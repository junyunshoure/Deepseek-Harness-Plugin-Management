# 独立浏览器 (ego-browser) 附录

本文件是精确参数与原始规范，只在需要具体字段时读取。

## 工具：ego_auth_flush

Force all persistent login cookies in the agent browser to be written to the on-disk profile. Call this after login (or before ending a browsing task) so the login survives a later DSH/browser restart — Chrome only flushes cookies to disk on graceful close, this nudges it to persist them now.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {}
}
```

## 工具：ego_captcha

Check the current page for a human-verification (CAPTCHA) challenge — reCAPTCHA / hCaptcha / Cloudflare / Turnstile — and return { detected, kind }. If detected=true, ALERT THE USER that they must complete the verification in the 'ego lite - agent' browser window (it is the same live session shown in the watch panel), then continue after they have.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "space": {
      "type": "string",
      "description": "Task-space name or numeric id; defaults to the configured defaultSpace."
    }
  }
}
```

## 工具：ego_cdp

Issue a raw CDP command on the page target, e.g. cdp("Page.handleJavaScriptDialog", { accept: true }).

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "method": {
      "type": "string",
      "description": "CDP method name, e.g. Page.handleJavaScriptDialog."
    },
    "params": {
      "type": "object",
      "description": "CDP method parameters object.",
      "additionalProperties": true
    },
    "space": {
      "type": "string",
      "description": "Task-space name or numeric id; defaults to the most recently opened or explicitly selected space."
    }
  },
  "required": [
    "method"
  ]
}
```

## 工具：ego_check

Check (tick) or uncheck a checkbox/radio element. Does nothing if already in the desired state.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "selector": {
      "type": "string",
      "description": "CSS selector of the checkbox/radio."
    },
    "checked": {
      "type": "boolean",
      "description": "true=check (default), false=uncheck."
    },
    "space": {
      "type": "string",
      "description": "Task-space name or numeric id; defaults to the most recently opened or explicitly selected space."
    }
  },
  "required": [
    "selector"
  ]
}
```

## 工具：ego_cli

Escape hatch: run an arbitrary `ego-browser nodejs` heredoc script verbatim (facades page/browser/taskSpaces/site/fetch and the raw cdp() are preloaded). Use when the structured ego_* tools do not cover the task. Returns raw stdout plus the parsed console.log payload when present.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "script": {
      "type": "string",
      "description": "Full JS script body for the heredoc; ego-browser helpers are preloaded. End with console.log(JSON.stringify(...)) for a parseable sentinel payload."
    }
  },
  "required": [
    "script"
  ]
}
```

## 工具：ego_click

Click an element in the current page. Target with a CSS selector, an xpath=.../loc=.../ref=N value from ego_snapshot, or viewport coordinates.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "selector": {
      "type": "string",
      "description": "CSS selector, xpath=..., loc=..., or ref=N from the snapshot. Required unless x/y are given."
    },
    "x": {
      "type": "number",
      "description": "Viewport x coordinate for a coordinate click."
    },
    "y": {
      "type": "number",
      "description": "Viewport y coordinate for a coordinate click."
    },
    "label": {
      "type": "string",
      "description": "Short human label for the action, e.g. \"click submit button\"."
    },
    "double": {
      "type": "boolean",
      "description": "Double-click instead of single-click. Useful for opening files/rows or triggering dblclick handlers."
    },
    "space": {
      "type": "string",
      "description": "Task-space name or numeric id; defaults to the most recently opened or explicitly selected space."
    }
  }
}
```

## 工具：ego_dialog

Accept or dismiss a native browser dialog (alert/confirm/prompt), optionally supplying text for a prompt. Use right after the action that triggers the dialog.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "accept": {
      "type": "boolean",
      "description": "true=Accept/OK (default), false=Dismiss/Cancel."
    },
    "text": {
      "type": "string",
      "description": "Text to type into a prompt dialog."
    },
    "space": {
      "type": "string",
      "description": "Task-space name or numeric id; defaults to the most recently opened or explicitly selected space."
    }
  }
}
```

## 工具：ego_doctor

Preflight the ego-browser environment: vendored runtime present, Chrome/Edge/Brave candidates, state dir, CDP/browser.json, ego-cast worker, task spaces. Run first when the browser fails to start (update, reboot, port conflict) or before a long session.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {}
}
```

## 工具：ego_download

Wait for a file download triggered by the current action, then return its saved path. Provide `triggerSelector` (a download button/link to click) or `triggerScript` (arbitrary JS that triggers the download). The file is captured into a temp dir and (optionally) copied to `savePath`. Returns { path, suggestedFilename, url }.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "triggerSelector": {
      "type": "string",
      "description": "CSS selector of the element (button/link) whose click starts the download."
    },
    "triggerScript": {
      "type": "string",
      "description": "Full JS snippet that triggers the download (e.g. window.open() or a fetch-to-blob download); runs in the page before waiting for the download."
    },
    "savePath": {
      "type": "string",
      "description": "Optional absolute destination path to also copy the downloaded file to. Otherwise only the temp-captured path is returned."
    },
    "timeout": {
      "type": "number",
      "description": "How long to wait for the download in ms (default 30000)."
    },
    "space": {
      "type": "string",
      "description": "Task-space name or numeric id; defaults to the most recently opened or explicitly selected space."
    }
  }
}
```

## 工具：ego_drag

Drag an element to a target (Playwright dragTo) or drag the pointer through coordinates. Use for sliders, sortable rows, and drag-drop zones.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "from": {
      "type": "string",
      "description": "CSS selector of the element to drag from."
    },
    "to": {
      "type": "string",
      "description": "CSS selector of the drop target (used with from)."
    },
    "points": {
      "type": "array",
      "description": "Alternative: a flat list of [x1,y1,x2,y2,...] viewport coordinates to drag the mouse through.",
      "items": {
        "type": "number"
      }
    },
    "space": {
      "type": "string",
      "description": "Task-space name or numeric id; defaults to the most recently opened or explicitly selected space."
    }
  }
}
```

## 工具：ego_fill

Type text into an input field. Target with a CSS selector, xpath=..., loc=..., or ref=N from ego_snapshot.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "selector": {
      "type": "string",
      "description": "CSS selector, xpath=..., loc=..., or ref=N for the input."
    },
    "text": {
      "type": "string",
      "description": "Text to type into the field."
    },
    "space": {
      "type": "string",
      "description": "Task-space name or numeric id; defaults to the most recently opened or explicitly selected space."
    }
  },
  "required": [
    "selector",
    "text"
  ]
}
```

## 工具：ego_help

Query the built-in ego-browser tool guide. `topic` may be a category (overview/tools/navigate/observe/input/keyboard-mouse/form/wait/network/login/script/doctor) or a specific tool name (e.g. ego_click). Returns the matching usage notes. Call this when unsure which eyebrow tool to use.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "topic": {
      "type": "string",
      "description": "Category or tool name to look up; omitted/all returns the overview index."
    }
  }
}
```

## 工具：ego_hover

Move the pointer over an element (CSS selector / ref) or to viewport coordinates. Triggers CSS :hover, dropdowns and mouseenter handlers.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "selector": {
      "type": "string",
      "description": "CSS selector, xpath=..., loc=..., or ref=N for the element."
    },
    "x": {
      "type": "number",
      "description": "Viewport x (only with y)."
    },
    "y": {
      "type": "number",
      "description": "Viewport y (only with x)."
    },
    "space": {
      "type": "string",
      "description": "Task-space name or numeric id; defaults to the most recently opened or explicitly selected space."
    }
  }
}
```

## 工具：ego_http

Make an HTTP request and return status + body. Default runs in the agent page's browser context (cross-origin allowed when the server's CORS permits); set `mode: server` to use Node-side fetch.server. Use to scrape an API, POST data, or hit a service. (Note: on the vendored ego-linux Windows runtime, fetch.server can hit a libuv crash, so prefer the default browser mode there.)

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "url": {
      "type": "string",
      "description": "Absolute URL to request."
    },
    "method": {
      "type": "string",
      "description": "HTTP method, default GET."
    },
    "headers": {
      "type": "object",
      "description": "Request headers, e.g. { 'Content-Type': 'application/json' }.",
      "additionalProperties": true
    },
    "body": {
      "type": "string",
      "description": "Request body (for POST/PUT)."
    },
    "timeout": {
      "type": "number",
      "description": "Timeout in ms (default 20000)."
    },
    "mode": {
      "type": "string",
      "description": "'browser' (default) runs via the page context; 'server' uses Node-side fetch.server."
    },
    "space": {
      "type": "string",
      "description": "Task-space name or numeric id; defaults to the most recently opened or explicitly selected space."
    }
  },
  "required": [
    "url"
  ]
}
```

## 工具：ego_js

Evaluate a JavaScript expression in the current page and return its JSON-serializable value (e.g. "document.title", "document.querySelectorAll('a').length").

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "expression": {
      "type": "string",
      "description": "JavaScript expression string to evaluate in the page."
    },
    "space": {
      "type": "string",
      "description": "Task-space name or numeric id; defaults to the most recently opened or explicitly selected space."
    }
  },
  "required": [
    "expression"
  ]
}
```

## 工具：ego_key

Press a keyboard key or shortcut combination on the current page, e.g. 'Enter', 'Tab', 'Control+a', 'Escape', 'ArrowDown'. Useful for forms, shortcuts and navigation. Pass `text` to type a string of characters instead (keyboard.type).

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "key": {
      "type": "string",
      "description": "Key or combo: 'Enter', 'Tab', 'Control+c', 'Meta+v', 'ArrowDown', 'Escape', 'F5', etc. (ignored when `text` is given)."
    },
    "text": {
      "type": "string",
      "description": "Type this text character-by-character (keyboard.type). Use instead of `key` for typing words into the focused element."
    },
    "space": {
      "type": "string",
      "description": "Task-space name or numeric id; defaults to the most recently opened or explicitly selected space."
    }
  }
}
```

## 工具：ego_login_import

Import login cookies from the system browser (Chrome/Edge/Brave) into the agent browser, so sites open already logged in. Works via a throwaway headless instance of the REAL system browser (CDP passthrough — no offline decryption; survives Chrome App-Bound Encryption). Run with dryRun=true first to see what is importable, then import with an explicit domains list (e.g. ["bilibili.com"]). The agent browser must be running (call ego_status first). Imported logins persist in the on-disk profile across restarts. Cookie values are never shown — only domain names and counts.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "source": {
      "type": "string",
      "description": "chrome | edge | brave | auto (default: auto = first detected browser)."
    },
    "domains": {
      "description": "Optional array of domains to import, e.g. [\"bilibili.com\",\"zhihu.com\"] (subdomains included). Omit = ALL cookies — prefer an explicit list."
    },
    "profile": {
      "type": "string",
      "description": "Source browser profile directory name, e.g. \"Default\" or \"Profile 1\" (default: the first profile)."
    },
    "closeSource": {
      "type": "boolean",
      "description": "A running source browser holds an exclusive lock on its cookie store (Windows). true = gracefully close it first (its windows/tabs restore on next launch). false (default) = return an actionable error instead."
    },
    "dryRun": {
      "type": "boolean",
      "description": "true = only report what would be imported (domains + cookie counts), write nothing."
    }
  }
}
```

## 工具：ego_navigate

Open a URL in the task space, or switch to the existing tab for it. Always prefer reusing existing open tabs before opening duplicate URLs. Waits for document load. Returns resulting page info.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "url": {
      "type": "string",
      "description": "Absolute URL to open, e.g. https://example.com/path."
    },
    "wait": {
      "type": "boolean",
      "description": "Wait for document load (default true)."
    },
    "timeout": {
      "type": "number",
      "description": "Load wait timeout in ms (default 20000)."
    },
    "space": {
      "type": "string",
      "description": "Task-space name or numeric id; defaults to the most recently opened or explicitly selected space."
    }
  },
  "required": [
    "url"
  ]
}
```

## 工具：ego_page_info

Return the current page info: url, title, viewport size (w, h), scroll offsets (sx, sy), device metrics (pw, ph), and whether a native dialog is open. Also reports `humanCheck` — whether a CAPTCHA / human-verification challenge is detected on the page (so the agent can alert the user to complete it).

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "space": {
      "type": "string",
      "description": "Task-space name or numeric id; defaults to the most recently opened or explicitly selected space."
    }
  }
}
```

## 工具：ego_read_element

Read a single element (by selector): its text, HTML, input value, an attribute, or visibility/enabled/count. Cheaper and more precise than a full-page snapshot.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "selector": {
      "type": "string",
      "description": "CSS selector of the target element."
    },
    "what": {
      "type": "string",
      "description": "What to read: 'text' (default) | 'html' | 'value' | 'attribute' | 'visible' | 'enabled' | 'count'."
    },
    "attribute": {
      "type": "string",
      "description": "Attribute name when what=attribute."
    },
    "space": {
      "type": "string",
      "description": "Task-space name or numeric id; defaults to the most recently opened or explicitly selected space."
    }
  },
  "required": [
    "selector"
  ]
}
```

## 工具：ego_screenshot

Capture a screenshot of the current page (or of a single element if selector is given). Returns the file path of the saved PNG, which you can then read with a vision/image tool.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "selector": {
      "type": "string",
      "description": "Optional CSS selector of an element to screenshot instead of the whole page."
    },
    "path": {
      "type": "string",
      "description": "Optional absolute output path for the PNG."
    },
    "space": {
      "type": "string",
      "description": "Task-space name or numeric id; defaults to the most recently opened or explicitly selected space."
    }
  }
}
```

## 工具：ego_script

Run an arbitrary `ego-browser nodejs` heredoc script in ONE invocation (same runtime/API as ego_cli: page/…locator/browser/taskSpaces/site/fetch/cdp preloaded), and return structured {ok, stdout, stderr, result, durationMs, timedOut}. Use for a full multi-step browser task as a single script.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "script": {
      "type": "string",
      "description": "Full JS script body; end with console.log(JSON.stringify(...)) for a parseable sentinel payload."
    },
    "timeoutMs": {
      "type": "integer",
      "description": "Per-run timeout in ms (default plugin grace)."
    }
  },
  "required": [
    "script"
  ]
}
```

## 工具：ego_scroll

Scroll the page: by pixel deltas (wheel), or bring an element into view (scrollIntoView).

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "deltaX": {
      "type": "number",
      "description": "Horizontal scroll delta (wheel) in px."
    },
    "deltaY": {
      "type": "number",
      "description": "Vertical scroll delta (wheel) in px."
    },
    "selector": {
      "type": "string",
      "description": "CSS selector to scroll into view (primary if given)."
    },
    "space": {
      "type": "string",
      "description": "Task-space name or numeric id; defaults to the most recently opened or explicitly selected space."
    }
  }
}
```

## 工具：ego_select

Choose an option in a <select> dropdown by value, label, or index (a single value or an array for multi-select).

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "selector": {
      "type": "string",
      "description": "CSS selector of the <select> element."
    },
    "value": {
      "description": "The option: a string value/label, or {value:'..'}, {label:'..'}, {index:n}, or an array of these for multi-select."
    },
    "space": {
      "type": "string",
      "description": "Task-space name or numeric id; defaults to the most recently opened or explicitly selected space."
    }
  },
  "required": [
    "selector"
  ]
}
```

## 工具：ego_snapshot

Read the current page as text: the full-page semantic tree annotated with [ref=N, loc=...] selectors that ego_click / ego_fill can target. This is the main observation tool for any browser task.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "space": {
      "type": "string",
      "description": "Task-space name or numeric id; defaults to the most recently opened or explicitly selected space."
    },
    "scope": {
      "type": "string",
      "description": "snapshot scope: 'full_page' (default) or 'only_within_viewport'."
    }
  }
}
```

## 工具：ego_space_close

Close an ego-lite task space. WARNING: In persistent profile mode, DO NOT call this tool when finishing tasks! Keep the space, tabs, and browser window alive so login sessions and streams remain intact. Conclude tasks by replying to the user directly without closing the space.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "name": {
      "type": "string",
      "description": "Task-space name or numeric id to close."
    },
    "keep": {
      "type": "boolean",
      "description": "Keep the live page open (default false: close it)."
    }
  },
  "required": [
    "name"
  ]
}
```

## 工具：ego_space_open

Open (or reuse) the ego-lite task space. In persistent profile mode (default), ALWAYS use or reuse the single 'default' space. Login credentials automatically persist on disk across restarts — if a page requires login, prompt user to log in manually in the opened window. DO NOT create numbered spaces like #4, #5.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "name": {
      "type": "string",
      "description": "Task-space name. In persistent mode, ALWAYS specify 'default'. Reuse this single space for all browsing tasks."
    }
  },
  "required": [
    "name"
  ]
}
```

## 工具：ego_status

Check whether the ego-browser CLI is usable (runs `ego-browser --status`). Use this first when other ego_* tools report "CLI not found".

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {}
}
```

## 工具：ego_upload

Set files on a file <input> element (path-driven). Use to upload a dataset/attachment from a local path.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "selector": {
      "type": "string",
      "description": "CSS selector of the <input type=file> element."
    },
    "path": {
      "type": "string",
      "description": "Absolute path of the file(s) to upload on this machine."
    },
    "space": {
      "type": "string",
      "description": "Task-space name or numeric id; defaults to the most recently opened or explicitly selected space."
    }
  },
  "required": [
    "selector",
    "path"
  ]
}
```

## 工具：ego_wait

Pause for a fixed number of milliseconds (e.g. for animations or partial loads). For load waits prefer ego_navigate's wait option.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "ms": {
      "type": "number",
      "description": "Milliseconds to wait."
    }
  },
  "required": [
    "ms"
  ]
}
```

## 工具：ego_wait_for_response

Wait for a network response matching a URL/glob/regex and return it. Optionally return the body (text or JSON) — ideal for scraping API responses or confirming a submission.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "url": {
      "type": "string",
      "description": "URL/glob/regex to match, e.g. '/api/search' or 'https://*.com/data'."
    },
    "timeout": {
      "type": "number",
      "description": "How long to wait in ms (default 10000)."
    },
    "body": {
      "type": "string",
      "description": "Return the response body: 'none' (default) | 'text' | 'json'."
    },
    "space": {
      "type": "string",
      "description": "Task-space name or numeric id; defaults to the most recently opened or explicitly selected space."
    }
  },
  "required": [
    "url"
  ]
}
```

## 工具：ego_wait_for_selector

Wait until an element matching a CSS selector appears (state=visible, default) or disappears (state=hidden). Use instead of a blind fixed wait when a page renders asynchronously.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "selector": {
      "type": "string",
      "description": "CSS selector of the element to wait for, e.g. '.results' or '[data-id=done]'."
    },
    "state": {
      "type": "string",
      "description": "Target state: 'visible' (default) | 'attached' | 'hidden' | 'detached'."
    },
    "timeout": {
      "type": "number",
      "description": "How long to wait in ms (default 10000)."
    },
    "space": {
      "type": "string",
      "description": "Task-space name or numeric id; defaults to the most recently opened or explicitly selected space."
    }
  },
  "required": [
    "selector"
  ]
}
```

## 工具：ego_wait_for_url

Wait until the page navigates to a URL matching a substring / glob / regex. Use to catch login redirects or pagination.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "pattern": {
      "type": "string",
      "description": "URL/glob to match (e.g. '/login?done', 'https://*/post/*', or a /regex/)."
    },
    "timeout": {
      "type": "number",
      "description": "How long to wait in ms (default 10000)."
    },
    "space": {
      "type": "string",
      "description": "Task-space name or numeric id; defaults to the most recently opened or explicitly selected space."
    }
  },
  "required": [
    "pattern"
  ]
}
```
