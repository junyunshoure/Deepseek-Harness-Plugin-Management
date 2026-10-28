# DrawAI 画布 (drawai)

读取和编辑当前 drawio 画布、布局及导出。

加载方式：feature_profiles(action="load", id="drawai")；返回 nextOffset 时继续读取。读完后本会话显示该功能原始工具。

按需处理：先判断项目需要此功能，再读取本手册。

以下规范保留原插件要求，包括确认、权限、来源校验、部分结果与错误语义。具体可用工具以当前运行时为准。

## 工具：diagram_apply

对工作区里的 DrawAI 画布文档施加一组结构化编辑（加节点/连边/改标签/改样式/移动/删除/高亮），然后自动布局并写回文件。布局默认由这里算；ops 里一旦自带几何（addNode 给了 x/y，或有 move）就不再重排，想重排请显式给 layout。ops 的每一项形如 {op:"addNode", label?, as?, shape?, svg?, style?, keys?, w?, h?, x?, y?, fontColor?} / {op:"addEdge", from?, to?, fromPoint?, toPoint?, as?, label?, style?, dash?, arrow?, color?, exit?, entry?, jettySize?, edgeStyle?, line?, avoid?, fontSize?, fontColor?, keys?} / {op:"setLabel", id|ids, label} / {op:"setLabelPos", id, x?, y?, dx?, dy?, center?} / {op:"setStyle", id|ids, shape?, svg?, style?, keys?, w?, h?, dash?, arrow?, color?, exit?, entry?, jettySize?, edgeStyle?, line?, avoid?, fontSize?, fontColor?, clearPoints?} / {op:"setEdge", id, from?, to?, fromPoint?, toPoint?} / {op:"order", id|ids, to:"front"|"back"|"up"|"down"} / {op:"duplicate", id|ids, dx?, dy?, withEdges?, layer?, as?} / {op:"addLayer", name?, as?} / {op:"setLayer", id|ids, layer} / {op:"setLayerProps", layer, name?, visible?, locked?} / {op:"export", format?:"svg"|"png", name?} / {op:"traceImage", image, preset?, w?, h?, x?, y?, colors?, colorsDark?, colorsFill?, grid?, gridH?, scale?, epsilon?, minArea?, minRegionArea?, protectLuma?, majorityContrast?, bgColor?, as?, layer?} / {op:"move", id|ids, dx?, dy?, x?, y?} / {op:"remove", id|ids} / {op:"highlight", ids:[...]}；节点 id 省略时自动分配。**改接一条边**用 setEdge（换 from/to 或某一端改成自由点）—— id、标签、标签位置、折点、端点约束全都留着；不要 remove + addEdge 重画（那会把这些丢掉）。**边上的文字压住线**时用 setLabelPos {id, center:true} 放回弧长中点，或用 {id, dy:12} 把它往上/下挪 12px（x 是沿边比例 -1..1，0 = 中点；diagram_read 回 labelX/labelY 告诉你它现在在哪）。**顺序**用 order（front 到最上面 / back / up / down，与画布右键同一套；它改的是文件里单元的先后）。**再复制一份**用 duplicate（新 id + 整体平移两格，折点/端点约束/标签位置都带过去；默认连"两端都在复制范围内的边"一起复制）。**图层**用 addLayer/setLayer/setLayerProps（加层、把单元移到别的层、改名/显示/隐藏/锁定；隐藏≠删除）。**导出**用 export：format:"svg" 会让画布渲染一张 SVG 落在 .drawio 旁边、format:"png" 是浏览器下载；这一步由画布执行，返回值里的 export.status 是 pending/done/downloaded/failed（pending = 画布还没刷新）。**照着一张位图描矢量图**用 traceImage：{op:"traceImage", image:"ref.png", x, y} 会真的读像素建成 svg 节点，**不是凭印象重画**。默认 w/h = 原图像素尺寸（1:1）。**调参**：先选 preset（default|lineart|photo|simple；lineart=插画线稿、photo=照片、simple=省字符、default=默认），再按需覆盖 colors/colorsDark/scale/epsilon/grid/gridH/minArea/minRegionArea/protectLuma/majorityContrast/bgColor 等。合并顺序：默认 ← preset ← 显式字段。返回值里的 **trace[]** 是结构化指标（svgChars/protectPixels/options/hint 等）；质量不够就根据 hint remove 旧节点再 trace（改 preset 或字段）。字符紧→scale:2/加大epsilon/preset:simple；线糊断→preset:lineart 或提高 protectLuma/colorsDark。**一次改一组**就写 ids:[...]（setStyle/setLabel/move/remove 都收，move 的批量只收 dx/dy 相对位移）—— 用户说"把这几个换成绿色"时不要逐个发 op。**引用刚建的那个**用 as:"名字"：{op:"addNode", label:"开始", as:"start"} 之后同一个 ops 数组里 from/to/id 可以直接写 "start"，不必猜自动分配的 n7。**画图形（图标/logo/示意图）用 svg**：addNode {shape:"svg", svg:"<svg viewBox=…>…</svg>", w, h} 让节点的内容就是那段 SVG 标记（不带字时可以不给 label）；setStyle {id, svg:"<svg…>"} 换图、{id, svg:null} 清掉回到矩形。标记**必须带 viewBox**（否则放大缩小时图形不跟着变）、默认拉伸铺满节点框（要等比就用 keys:{imageAspect:1}）。落盘是 drawio 原生的图片形状（shape=image + data:image/svg+xml），drawio 桌面版打开同样看得见图。返回值里的 created/changed/removed 是结构化 id（含自动分配的那些），不用去解析 summary 文本。expectRevision：把上一次 diagram_read 返回的 revision 传进来当乐观锁 —— 对不上（用户同时在 drawio 里改过）就**直接报错、一个字节都不写**，重读一次再改。addEdge 的两端各自可以给**节点 id** 或**绝对点**（fromPoint/toPoint）—— 两端都给点就是一条**独立线**（drawio 里边的两端都可以是自由点，线可以完全不接节点）。move 改已有元素的位置：节点可以给 dx/dy（相对）或 x/y（绝对），连线只能给 dx/dy（平移它自己的折点与自由端点）。以前没有 move，只能删掉重画 —— 那会丢 id、丢边上的端点约束与折点。highlight 只让客户端选中那几个（不改文档，也不重排）。文档里存的是 **drawio 的 style 键**（dashed/dashPattern/edgeStyle/jettySize/libavoidRouting/exitX·exitY·entryX·entryY/endArrow·startArrow/strokeColor/fillColor/shape=/rounded=/arcSize=…），默认值一律省略、认不出的键原样保留；上面这些 shape/style/dash/arrow/color/exit/entry 是给模型用的**糖**，由宿主翻译成 style 键，绝不落盘。style 既可以是调色板名（plain/blue/green/orange/yellow/red/purple/grey），也可以直接是一段 style 串；keys 用来写任意 drawio 键（值给 null = 删键回默认）。setStyle 的 id 可以是节点也可以是连线：节点用 shape/style/keys/w/h/fontColor，连线用 dash（solid|dashed|dotted）、arrow（end 单向|both 双向|none 无箭头|start 反向）、color（**线本身**的颜色）、exit/entry（n|e|s|w 进出侧）、jettySize（引出段长度，数字或 auto）、edgeStyle（orthogonalEdgeStyle|none）、line（straight 直线|sharp 直角折线|rounded 圆角折线|curved 曲线）、avoid（是否参与避让路由）、fontSize（字号）、fontColor（**文字**颜色）、clearPoints（清掉折点）。fontColor 给调色板名（plain/blue/green/orange/yellow/red/purple/grey）就按画布上"文字换色"那一支取色，给 #b85450 这类色值就原样写；fontColor:null 删键回缺省（黑字）。文档若带 meta.pinned（人手工摆过位置），不加 layout 就不会重排；显式重排会清掉端点已移动的那些边上的过期折点。边引用了不存在的节点会直接报错，且失败发生在写盘之前。自环写成 from === to（与 drawio 一致）；自动布局会忽略自环，只摆节点。不传 path 时改的是**用户当前打开的那张画布**（没打开才退回 demo.drawio）—— 用户说"这张图"时不用传 path。多页文件用 page（0 起）指定要改哪一页；不传 = 用户正在看的那一页。其它页字节原样保留。

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "path": {
      "type": "string",
      "description": "工作区相对路径或绝对路径。**不传 = 用户当前打开的那张画布**（没打开任何画布时才退回 demo.drawio）—— 想知道用户在看哪张，直接不传 path 调一次，返回里的 path 就是它。"
    },
    "page": {
      "type": "number",
      "description": "多页文件里要改的页下标（从 0 起）。不传 = 用户画布当前页；写回只动这一页，其它页原样保留。"
    },
    "ops": {
      "type": "array",
      "description": "结构化编辑数组，见工具描述里的 ops 语法",
      "items": {}
    },
    "layout": {
      "type": "string",
      "description": "自动布局：dagre-tb 上到下（默认，贴合右栏窄高形状）、dagre-lr 左到右、grid 网格、none 保留现有坐标（只给无坐标的新节点补位）",
      "enum": [
        "dagre-lr",
        "dagre-tb",
        "grid",
        "none"
      ]
    },
    "expectRevision": {
      "type": "string",
      "description": "乐观锁：上一次 diagram_read 返回的 revision（文件内容指纹）。对不上说明这份文件在你会话中途被别人改过（用户同时在 drawio 里编辑），本次调用**直接失败且不写盘**，重新读一次再改。不传 = 不检查。"
    }
  },
  "required": [
    "ops"
  ]
}
```

## 工具：diagram_read

读回工作区里的 DrawAI 画布（.drawio，就是 drawio 自己的 mxfile 格式）：节点 id/标签/形状/style 键，边 id/起点/终点/标签/画法/折点。做任何修改前先用它确认当前图。文档存的是 drawio 的 style 键（dashed/dashPattern/edgeStyle/jettySize/libavoidRouting/exitX…/endArrow/strokeColor/shape=…），默认值省略；返回体的 shape/dash/arrow/color/exit/entry/fontColor 是**从 style 串推导出来的便于阅读的名字**，改图请改 style 或对应 op 参数；shape 为 svg 的节点（内容是一段内嵌 SVG 图形）额外带 svg 字段 = 那段标记，而它 style 里的 image= 被省略成 «svg N 字符»（**别把省略后的 style 原样写回**，会被拦下；改内容用 diagram_apply 的 svg 参数）。shape 为 image 的节点是用户粘贴/拖入的位图（png/jpeg/gif/webp），带 image:true，style 里的 image= 省略成 «image N 字符»。notes 是这个文件里画布表示不了、但会原样保留的东西（多页、分组层级、外链图片…）。layers 是图层表（顺序 = 叠放顺序；visible:false 的层在画布上不画，但里面的单元照旧读得到它们带 layer 字段）；加层/移层/改名/显示隐藏用 addLayer、setLayer、setLayerProps。节点带 parent 说明它在某个容器（分组）里 —— 画布按绝对位置显示，所以移动容器不会带走子单元，要整组动就把它们一起写进 ids。selection 是**用户此刻在画布上选中的单元 id**（按文件配对、按存在过滤；没人选就是空数组）—— 用户说"把这几个挪一下/换个颜色"时，"这几个"就是它们，别靠坐标猜。返回的 revision 可以直接当 diagram_apply 的 expectRevision 用（读→改之间被别人动过就会被拦下）。不传 path 时读的是**用户当前打开的那张画布**（返回里的 path 就是它）。多页文件用 page（0 起）指定页；不传 = 用户正在看的那一页（没上报过则 0）。返回里的 pageIndex / pageCount / pageNames 说明当前读到哪一页；page 字段仍是纸张尺寸 {w,h}（有写才有）。

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "path": {
      "type": "string",
      "description": "工作区相对路径或绝对路径。**不传 = 用户当前打开的那张画布**（没打开任何画布时才退回 demo.drawio）—— 想知道用户在看哪张，直接不传 path 调一次，返回里的 path 就是它。"
    },
    "page": {
      "type": "number",
      "description": "多页文件里要读的页下标（从 0 起）。不传 = 用户画布当前页（聚焦上报）；越界会夹到合法范围。单页文件忽略。"
    },
    "layer": {
      "type": "string",
      "description": "只看某一层（层 id 或层名）：大图上先看一层能省掉一大段上下文。层表照旧整份回。不传 = 全部层。"
    },
    "ids": {
      "type": "array",
      "description": "只看这几个单元（节点/连线 id）：想确认\"刚改的那几个现在什么样\"时用它，别把整张图再读一遍。",
      "items": {
        "type": "string"
      }
    },
    "render": {
      "type": "boolean",
      "description": "**看一眼这张画布的渲染结果**（正交路由、避让、圆角、文字断线这些只有看图才知道的东西）。渲染在画布那一半做，所以第一次调用通常回 look.status=\"pending\"（已请求，画布几秒内渲染完），**再调一次**就会带上图片块。图片经附件通道直接进上下文 —— **不会在你的工作区里生成任何文件**。只在确实需要\"看\"的时候用（判断重叠/压线/观感），纯粹改图不需要它。"
    }
  }
}
```
