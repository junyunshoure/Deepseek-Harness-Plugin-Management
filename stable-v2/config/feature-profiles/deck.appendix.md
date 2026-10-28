# ISSUE 与地图 (deck) 附录

本文件是精确参数与原始规范，只在需要具体字段时读取。

## 工具：deck_context

这是 dsh-mattpocock-skills-deck 插件提供的 ISSUE 与 map 管理能力，只处理当前 workspace 对应的 repo。你要创建、查看、更新 ISSUE，查看 map 与 progress 时，先调用 deck_context 一次，确认 workspace 与 backend；如果 repo 里的说法和这里写的不一样，以这里写的为准。如果 deck_context 返回这个 workspace 还没有选 backend，或拿不到 workspace，就说明本插件不适用这个 workspace，直接停下，不再调用其余 deck 开头的工具，后续怎么做由用户决定。

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {},
  "additionalProperties": false
}
```

## 工具：deck_issue_create

同属 dsh-mattpocock-skills-deck 插件的 ISSUE 与 map 管理能力，只处理当前 workspace 对应的 repo；动 ISSUE 前先调用 deck_context 确认 workspace 与 backend，若它说没 backend 就停下。建一个 ISSUE（map / task / bug / spec / ticket），自动补必备 label 与进度区（规格与实施票不补进度区、改在票面写对象类型标记），带 originalWords 时把维护者原话一字不改写进正文的「## 维护者原话」区，重复调用按锚复用同一张。带了 blockedBy 会在票建成后写成它的原生依赖边（边没写成时票照建，回执逐条说明）。

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "title": {
      "type": "string",
      "description": "票的标题"
    },
    "body": {
      "type": "string",
      "description": "正文；缺省时按种类补最小骨架"
    },
    "originalWords": {
      "type": "object",
      "description": "建票时顺便追加一条维护者原话到正文的「## 维护者原话」区（紧跟「## 目的」，没有目的区就放正文最前）：{text, source}，source 必填。原话一字不改（不润色、不改标点、不翻译、不摘要），只追加、不编辑不删除不排序。三个后端都写进票的正文，不进评论；正文超过 60KB 时拒绝建票、一个字节不动。",
      "properties": {
        "text": {
          "type": "string",
          "description": "维护者的原话正文，一字不改；可以多行，空行原样保留"
        },
        "source": {
          "type": "string",
          "description": "出处，必填：票面写完整链接，本会话答复写「本会话（时间）」，文件写「路径:行号」，提交写短哈希"
        }
      },
      "required": [
        "text",
        "source"
      ],
      "additionalProperties": false
    },
    "kind": {
      "type": "string",
      "enum": [
        "task",
        "bug",
        "map",
        "spec",
        "ticket"
      ],
      "description": "票的种类，缺省 task"
    },
    "parentKey": {
      "type": "string",
      "description": "父票：规格票挂探索地图、实施票挂规格票（kind=ticket 时必填，父必须是规格票）"
    },
    "blockedBy": {
      "type": "array",
      "items": {
        "type": "string"
      },
      "description": "这张票建成后被哪些票阻塞（票号或 key 的数组，整批替换；只认本仓库的票，不许写别的仓库的票号）"
    },
    "labels": {
      "type": "array",
      "items": {
        "type": "string"
      },
      "description": "要带的标签，会在必备标签之外追加"
    },
    "assignees": {
      "type": "array",
      "items": {
        "type": "string"
      },
      "description": "认领人"
    },
    "idempotencyKey": {
      "type": "string",
      "description": "这一批写的幂等锚，重试时带同一个值"
    },
    "workRouteDetail": {
      "type": "string",
      "enum": [
        "core",
        "standard"
      ],
      "description": "成功后回执里在办表（data.workRoute）带多细：core 只带票号、会话、时间（缺省，最多 20 条），standard 再加标题与动作（全部条目）"
    },
    "effortId": {
      "type": "string",
      "description": "只有本地后端需要填，填票所在的目录名，根目录的不填"
    }
  },
  "required": [
    "title"
  ],
  "additionalProperties": false
}
```

## 工具：deck_issue_get

同属 dsh-mattpocock-skills-deck 插件的 ISSUE 与 map 管理能力，只处理当前 workspace 对应的 repo；动 ISSUE 前先调用 deck_context 确认 workspace 与 backend，若它说没 backend 就停下。读一个 ISSUE 的完整关系：正文、评论、label、assignee 与 parent 和 blockedBy 边，每条边标出落点。blocking=false 跳过反向边查询（快，见 blocking 参数）。

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "key": {
      "type": "string",
      "description": "票号，例如 713"
    },
    "comments": {
      "type": "number",
      "description": "最多带回几条评论，缺省 50"
    },
    "section": {
      "type": "string",
      "description": "只回正文里这一节（## 标题子串），缺省回全文前 2000 字"
    },
    "blocking": {
      "type": "boolean",
      "description": "要不要反向阻塞边（谁被这张票阻塞）。缺省要：读全量关系，一次查询就取回反向边，阻塞者的标题与状态随行回来。关掉只读单票本身，跳过一次反向边查询，快；反向边记空并注记，要就再调一次。"
    },
    "effortId": {
      "type": "string",
      "description": "只有本地后端需要填，填票所在的目录名，根目录的不填"
    }
  },
  "required": [
    "key"
  ],
  "additionalProperties": false
}
```

## 工具：deck_issue_list

同属 dsh-mattpocock-skills-deck 插件的 ISSUE 与 map 管理能力，只处理当前 workspace 对应的 repo；动 ISSUE 前先调用 deck_context 确认 workspace 与 backend，若它说没 backend 就停下。按状态、label、assignee 与关键词列出 ISSUE 薄行，不回正文与评论。

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "state": {
      "type": "string",
      "enum": [
        "open",
        "closed",
        "all"
      ],
      "description": "只列哪种状态，缺省 open"
    },
    "type": {
      "type": "string",
      "enum": [
        "issue",
        "map",
        "spec",
        "all"
      ],
      "description": "只列哪种类型，缺省 all"
    },
    "labels": {
      "type": "array",
      "items": {
        "type": "string"
      },
      "description": "必须同时带上这些 label（AND），缺省不过滤"
    },
    "assignee": {
      "type": "string",
      "description": "只留认领含此人的行，缺省不过滤"
    },
    "query": {
      "type": "string",
      "description": "标题与正文的子串过滤，缺省不过滤"
    },
    "limit": {
      "type": "number",
      "description": "最多回几行，缺省 50，上限 200"
    },
    "effortId": {
      "type": "string",
      "description": "只有本地后端需要填，填票所在的目录名，根目录的不填"
    }
  },
  "required": [],
  "additionalProperties": false
}
```

## 工具：deck_issue_patch

同属 dsh-mattpocock-skills-deck 插件的 ISSUE 与 map 管理能力，只处理当前 workspace 对应的 repo；动 ISSUE 前先调用 deck_context 确认 workspace 与 backend，若它说没 backend 就停下。改一个 ISSUE：评论、label、assignee、关闭、标题正文、progress 区、维护者原话区，一次只动点名的那些；重开不在这个工具上（只由人在后端做），关规格要先在这一次调用里带收口核对评论、且实施票已全关。

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "key": {
      "type": "string",
      "description": "要改的那张票"
    },
    "comment": {
      "type": "string",
      "description": "要发的评论正文"
    },
    "addLabels": {
      "type": "array",
      "items": {
        "type": "string"
      },
      "description": "要加的标签"
    },
    "removeLabels": {
      "type": "array",
      "items": {
        "type": "string"
      },
      "description": "要摘掉的标签"
    },
    "assignees": {
      "type": "array",
      "items": {
        "type": "string"
      },
      "description": "认领人（整批替换；给空数组就是取掉认领）"
    },
    "title": {
      "type": "string",
      "description": "新的标题"
    },
    "body": {
      "type": "string",
      "description": "新的正文"
    },
    "originalWords": {
      "type": "object",
      "description": "追加一条维护者原话到正文的「## 维护者原话」区（紧跟「## 目的」，没有目的区就放正文最前）：{text, source}，source 必填。原话一字不改（不润色、不改标点、不翻译、不摘要），只追加、不编辑不删除不排序；同一段原话 + 同一出处已经写过时幂等跳过。三个后端都写进票的正文，不进评论。正文超过 60KB 时拒绝写入、一个字节不动。",
      "properties": {
        "text": {
          "type": "string",
          "description": "维护者的原话正文，一字不改；可以多行，空行原样保留"
        },
        "source": {
          "type": "string",
          "description": "出处，必填：票面写完整链接，本会话答复写「本会话（时间）」，文件写「路径:行号」，提交写短哈希"
        }
      },
      "required": [
        "text",
        "source"
      ],
      "additionalProperties": false
    },
    "progress": {
      "type": "object",
      "description": "写一条进度记录：{percent, note}（#1090 起不再收一段自由文字）。工具自动盖当前时间、把这条加到「## 进度」区最上面，旧记录原样保留；正文超过 60KB 时拒绝写入、一个字节不动。",
      "properties": {
        "percent": {
          "type": "integer",
          "description": "进度百分比，0..100 的整数"
        },
        "note": {
          "type": "string",
          "description": "做到哪一步了的说明，必填，一句话（不能换行）"
        }
      },
      "required": [
        "percent",
        "note"
      ],
      "additionalProperties": false
    },
    "close": {
      "type": "boolean",
      "description": "true 关闭这张票；关规格时必须在同一次调用里带 comment（逐张核对结论），且实施票全关，否则关闭会被拒绝。重开只能由人在后端做，这个工具不支持 false"
    },
    "workRouteDetail": {
      "type": "string",
      "enum": [
        "core",
        "standard"
      ],
      "description": "成功后回执里在办表（data.workRoute）带多细：core 只带票号、会话、时间（缺省，最多 20 条），standard 再加标题与动作（全部条目）"
    },
    "effortId": {
      "type": "string",
      "description": "只有本地后端需要填，填票所在的目录名，根目录的不填"
    }
  },
  "required": [
    "key"
  ],
  "additionalProperties": false
}
```

## 工具：deck_issue_report

同属插件的 ISSUE 与 map 管理能力，只处理当前 workspace 对应的 repo；先调 deck_context 确认 workspace 与 backend。开始处理、切换或完成一个 ISSUE 时都必须调用：开始前报一次，关闭时再报一次，这条是必选。职责划分：deck_issue_patch 负责变更 issue 内容，deck_issue_report 负责上报处理关系；用前者关闭 issue 不等价于已完成上报。key 填你要上报的 ISSUE 编号；只有本地后端需要填 effortId，填票所在目录名，根目录不填。要撤销误报带 release=true（只删本会话那一行；建过、改过、关过、建过计划、挂过边的票不能释放，票不动）。有没有记上、记在哪里，看返回里的结果。

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "key": {
      "type": "string",
      "description": "你要上报的那个 ISSUE 的编号"
    },
    "note": {
      "type": "string",
      "description": "可选带一句备注（只回显，不进链）"
    },
    "workRouteDetail": {
      "type": "string",
      "enum": [
        "core",
        "standard"
      ],
      "description": "成功后回执里在办表（data.workRoute）带多细：core 只带票号、会话、时间（缺省，最多 20 条），standard 再加标题与动作（全部条目）"
    },
    "effortId": {
      "type": "string",
      "description": "只有本地后端需要填，填票所在的目录名，根目录的不填"
    },
    "release": {
      "type": "boolean",
      "description": "可选：传 true 表示尝试撤销本会话对这张票的一条误报（只在从没实际处理过这张票时删得掉；建过、改过、关过、建过计划或挂过边的票不能释放，路径保留；不是改票：票的状态与认领人都不动）；不传或传 false 就是正常上报"
    }
  },
  "required": [
    "key"
  ],
  "additionalProperties": false
}
```

## 工具：deck_map_link

同属 dsh-mattpocock-skills-deck 插件的 ISSUE 与 map 管理能力，只处理当前 workspace 对应的 repo；动 ISSUE 前先调用 deck_context 确认 workspace 与 backend，若它说没 backend 就停下。给已存在的 ISSUE 补 parent 或 blockedBy 边，写完读回并逐条标出落点。

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "key": {
      "type": "string",
      "description": "要改的那张票（子票）"
    },
    "parentKey": {
      "type": "string",
      "description": "要挂到的父票；不传就不动父子"
    },
    "blockedBy": {
      "type": "array",
      "items": {
        "type": "string"
      },
      "description": "这张票被哪些票阻塞（整批替换）"
    },
    "edges": {
      "type": "array",
      "description": "一次改多张票的边；与 key/parentKey/blockedBy 二选一",
      "items": {
        "type": "object",
        "properties": {
          "key": {
            "type": "string"
          },
          "parentKey": {
            "type": "string"
          },
          "blockedBy": {
            "type": "array",
            "items": {
              "type": "string"
            }
          }
        },
        "required": [
          "key"
        ],
        "additionalProperties": false
      }
    },
    "workRouteDetail": {
      "type": "string",
      "enum": [
        "core",
        "standard"
      ],
      "description": "成功后回执里在办表（data.workRoute）带多细：core 只带票号、会话、时间（缺省，最多 20 条），standard 再加标题与动作（全部条目）"
    },
    "effortId": {
      "type": "string",
      "description": "只有本地后端需要填，填票所在的目录名，根目录的不填"
    }
  },
  "additionalProperties": false
}
```

## 工具：deck_map_plan_create

同属 dsh-mattpocock-skills-deck 插件的 ISSUE 与 map 管理能力，只处理当前 workspace 对应的 repo；动 ISSUE 前先调用 deck_context 确认 workspace 与 backend，若它说没 backend 就停下。一次建一整张 map 的骨架（map ISSUE + child ISSUE + 依赖边），带逐项校验与可续跑中间态。

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "title": {
      "type": "string",
      "description": "地图票的标题"
    },
    "body": {
      "type": "string",
      "description": "地图正文；缺省时自动补五个区块"
    },
    "planId": {
      "type": "string",
      "description": "这次计划的标识；重跑时带同一个值就能接着上次没做完的部分继续；想建第二张内容相同的计划时传一个不同的值"
    },
    "children": {
      "type": "array",
      "description": "要建的子票清单",
      "items": {
        "type": "object",
        "properties": {
          "key": {
            "type": "string",
            "description": "计划内的短标识，边用它来指代这张票"
          },
          "title": {
            "type": "string"
          },
          "body": {
            "type": "string"
          },
          "kind": {
            "type": "string",
            "enum": [
              "task",
              "bug",
              "map"
            ]
          },
          "labels": {
            "type": "array",
            "items": {
              "type": "string"
            }
          },
          "assignees": {
            "type": "array",
            "items": {
              "type": "string"
            }
          }
        },
        "required": [
          "key",
          "title"
        ],
        "additionalProperties": false
      }
    },
    "edges": {
      "type": "array",
      "description": "子票之间的边；from 是计划内的短标识（也可以是地图自己，写 @map）",
      "items": {
        "type": "object",
        "properties": {
          "from": {
            "type": "string"
          },
          "to": {
            "type": "string"
          },
          "type": {
            "type": "string",
            "enum": [
              "blocked-by",
              "parent"
            ]
          }
        },
        "required": [
          "from",
          "to"
        ],
        "additionalProperties": false
      }
    },
    "labels": {
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "workRouteDetail": {
      "type": "string",
      "enum": [
        "core",
        "standard"
      ],
      "description": "成功后回执里在办表（data.workRoute）带多细：core 只带票号、会话、时间（缺省，最多 20 条），standard 再加标题与动作（全部条目）"
    },
    "effortId": {
      "type": "string",
      "description": "只有本地后端需要填，填票所在的目录名，根目录的不填"
    }
  },
  "required": [
    "title",
    "children"
  ],
  "additionalProperties": false
}
```

## 工具：deck_map_snapshot

同属 dsh-mattpocock-skills-deck 插件的 ISSUE 与 map 管理能力，只处理当前 workspace 对应的 repo；动 ISSUE 前先调用 deck_context 确认 workspace 与 backend，若它说没 backend 就停下。看一个 map 的全部 child ISSUE、进度统计与五个区块，用来判断 map 做到哪一步。detail=thin 只要薄行不断（见 detail 参数）。

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "key": {
      "type": "string",
      "description": "地图那张票的票号"
    },
    "frontierOnly": {
      "type": "boolean",
      "description": "只回可接的子票（未关闭、未认领、阻塞已满足），缺省回全部"
    },
    "detail": {
      "type": "string",
      "enum": [
        "full",
        "thin"
      ],
      "description": "子票行要多细。缺省 full：每行带正文进度（回包大，票多时被截断）。thin：只要键、标题、状态、标签、认领、阻塞（回包小、清单不断；统计与进度表照算不变；要正文用 deck_issue_get 逐张取）。"
    },
    "effortId": {
      "type": "string",
      "description": "只有本地后端需要填，填票所在的目录名，根目录的不填"
    }
  },
  "required": [
    "key"
  ],
  "additionalProperties": false
}
```

## 工具：deck_probe

诊断探针：返回 agent 上下文里有哪些服务。查 deck 工具执行通道设计时用，通道接通即退役。

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {},
  "additionalProperties": false
}
```
