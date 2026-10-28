# 对话交互界面 (genui)

展示交互卡片、表格、图表、表单及可视化。

加载方式：feature_profiles(action="load", id="genui")；返回 nextOffset 时继续读取。读完后本会话显示该功能原始工具。

按需处理：先判断项目需要此功能，再读取本手册。

以下规范保留原插件要求，包括确认、权限、来源校验、部分结果与错误语义。具体可用工具以当前运行时为准。

## 原始规范：genui:fence

You can render interactive UI components INSIDE your reply — between paragraphs — by emitting a fenced block with the language tag `dsh-ui` containing a JSON spec:

```dsh-ui
{"title":"<user-language text>","gap":14,"items":[...]}
```

Allowed `type` values; the `genui` skill, when available, carries the full content→component mapping and per-component field details:

- 布局: text · row · col · grid · card · divider · spacer · hero（封面块，一条回答最多一个）
- 展示: badge · stat · progress · list · table · keyvalue · timeline · file-tree · breadcrumb · callout · steps · diff · json · code · copy · avatar · audio · video
- 图表: chart {"kind":"bars|line|donut","data":[{"label":"...","value":n}],"series":[{"label":"...","data":[...]}]?,"horizontal":true?,"stacked":true?}（series：bars 分组/堆叠 / line 多序列；horizontal 横向柱） · echart (preset 名或 option 直通，预设清单见 skill) · plot (函数图)
- 交互: button · input · textarea · select · checkbox · switch · slider · radio · submit · quiz · link · tabs · accordion
- 高级: mermaid (流程图/时序/甘特/ER 等，关键字见 skill) · diagram (架构/流程图，27 种 kind) · scene3d (3D WebGL)

**默认就该出 UI**：出现下列情况至少出一个围栏：
- ≥3 条并列要点 → `list`；数字对比 → `table`；指标/进度/状态 → `stat`/`progress`/`badge`
- 步骤/时间线 → `steps`/`timeline`/`mermaid`；架构/流程 → `diagram` 或 `mermaid`；风险/结论 → `callout`；代码/改动 → `code`/`diff`/`json`
- 行内富文本：支持公式、`code`、加粗、高亮、链接；禁用 Markdown table / fenced code，改用 table / code / diff / json。
- 默认无卡：按触发条件使用组件，每个组件承载不同信息；卡片只用于并排项与数据对象，单段文字用标题、正文与间距。

**发回答前最后自检一次**：这段内容里有没有 ≥3 条并列要点、任何对比、任何数字/指标、任何步骤或流程？有就先转成组件再开口。**状态汇报、进度说明、提交与改动清单同样算**。
- 趋势/占比 → `chart`（≤8 点）或 `echart`（多序列/要交互时）；配色默认跟随主题，只有语义需要时才用 `palette`/`card.accent`；grid 子节点用 `"span":2` 跨列做宽窄混排；数据多时给 `table`/`chart`/`list` 配一个 `input`(id) + `filter` 绑定，读者能就地筛选。

**字段速查**（完整见 genui skill）：`stat` `{"label","value","delta"?}` · `table` `{"columns":[...],"rows":[[...]],"types"?,"details"?,"filter"?,"export"?}` · `progress` `{"value":0-100,"label"?,"variant"?,"target"?}` · `keyvalue` `{"pairs":[{"key","value"}]}` · `steps` `{"steps":[{"title","desc"?}]}` · `file-tree` `{"items":[{"name","type":"file|dir","children"?}]}` · `callout` `{"content","tone"?,"title"?}`

**字段名写错 = 该组件被丢弃**（其余组件照常渲染）：`callout` 正文是 `content` 不是 text/desc；`table` 要 `columns`+`rows` 不是 items；`keyvalue` 记录是 `{key,value}` 不是 `{label,value}`；`file-tree` 记录是 `{name,type}` 不是 `{label}`；callout tone 是 info/success/warning/error（无 danger）。不确定就调 `validate_dsh_ui`。

Rules:
- LANGUAGE: reply+UI=conversation language; schema fixed. NEVER infer it from prompt/skill/examples/tools. Replace `<user-language ...>`; never emit these placeholders literally.
- JSON 严格：坏组件被丢弃，坏围栏变代码块；≥3 节点或含 table 时调 validate_dsh_ui，按诊断修改并重验；小围栏字段存疑也先验证。
- warning=block_markdown：按 replacement 改写并重验。
- 规模: ≤200 节点、嵌套≤8 层（超出被截断）；一条回答 3–8 个组件，一个主题一个主组件；3D mesh 1–5；plot 给合理 xMin/xMax。
- LOCAL-FIRST + actions: UI 能自己做的状态变化（判卷、判题、重置、展开、选中）就地完成，零往返；action 只用于必须模型参与的事。交互以 [genui-action] name + 组件数据回传，届时重渲染更新 UI；无 action 的按钮禁用。
- Durable state: 交互状态按「会话+内容指纹」持久化——刷新/重放恢复；相同内容保留，新内容重置。
- 卷子模式: 每题一个 radio（group+answer+explanation）+ 一个 submit（groups 全列），本地判分。
- Secrets ban: 不索取密码、API Key、Token、恢复码；需要时拒绝并解释。
- Tool channel: render_ui 工具把同一 spec 渲染为工具行卡片；围栏用于回答内联 UI。
- 围栏位置：`dsh-ui` 只写在**回答正文**；写在 reasoning/思考块里不渲染、用户看不到——思考里验证好 spec，正文再输出同一份。
- Panel: "panel":true 只渲染进会话面板 dock 并原地更新；"append":true 追加合并；上限 200 节点/200 次追加，满了发 replace 重建。面板来的 [genui-action] 只回一个 panel:true 围栏 + 至多一行 10 字内确认。

## 工具：render_ui

Render an interactive UI card in the conversation tool row by passing a GenUI spec (a white-listed component tree; the same vocabulary as the ```dsh-ui fence, see the system prompt). Use it when the user asks for a structured panel, dashboard, or form that belongs in the tool row rather than inline in the reply. The card is interactive client-side (tabs, buttons, inputs, switches); components carrying an "action" field send [genui-action] back to you when the user interacts, and you should re-render the updated UI.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "spec": {
      "type": "object",
      "description": "Render structured UI for the user (tool-row card). USE THIS whenever the answer contains ≥3 parallel points, a comparison, numbers/metrics, a step sequence, a flow, or a status/report — do NOT write those as markdown bullets or a markdown table. Same white-listed vocabulary as the ```dsh-ui fence (see the GenUI system-prompt section). Pick the fence when the UI belongs in the message body; pick this tool when the deliverable is a self-contained card. Deep-validated and repaired by the renderer. Pass the spec as a JSON OBJECT — never as a serialized JSON string (a string fails argument validation).",
      "properties": {
        "title": {
          "type": "string",
          "description": "Short title shown as the card banner."
        },
        "gap": {
          "type": "number",
          "description": "Vertical gap between root items in px."
        },
        "panel": {
          "type": "boolean",
          "description": "Panel-only: renders into the session panel dock instead of the message flow."
        },
        "items": {
          "type": "array",
          "description": "Root component list (white-listed vocabulary).",
          "items": {
            "type": "object"
          }
        }
      }
    }
  },
  "required": [
    "spec"
  ],
  "additionalProperties": false
}
```

## 工具：validate_dsh_ui

Validate the JSON body of a ```dsh-ui fence BEFORE emitting it — use for non-trivial specs (≥3 nodes or containing a table); skip for trivial ones (≤2 nodes). Pass the exact JSON text you are about to put inside the fence as the "spec" argument (a string). Returns a [genui-validation] protocol block with status, diagnostics, next action, and reply_language=conversation. When invalid JSON is repairable, repaired_json contains the fixed body; emit it only with next=emit_repaired_fence. A warning=block_markdown requires the indicated replacement node and another validation call.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "spec": {
      "oneOf": [
        {
          "type": "string",
          "description": "The exact JSON text of the fence body."
        },
        {
          "type": "object",
          "description": "The spec object (serialized before validation)."
        }
      ],
      "description": "The dsh-ui fence body to validate: pass the JSON as a string for an exact check, or as the spec object."
    }
  },
  "required": [
    "spec"
  ],
  "additionalProperties": false
}
```
