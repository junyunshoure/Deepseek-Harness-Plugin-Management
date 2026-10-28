# IG5 逆向 (reverse) 附录

本文件是精确参数与原始规范，只在需要具体字段时读取。

## 工具：ig5_close

Close one open target and recycle its worker process. The analysis database stays on disk next to the target; reopening with ig5_open reuses it.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "target": {
      "type": "string",
      "description": "Target path to close"
    },
    "engine": {
      "type": "string",
      "enum": [
        "reverse",
        "ghidra"
      ],
      "description": "Explicit backend. Omit to use the configured primary static engine; results identify their source."
    }
  },
  "required": [
    "target"
  ]
}
```

## 工具：ig5_decompile

Decompile one function by EA or exact name. style=dossier aggregates pseudocode, CFG, callers, callees and stack under one database revision, with explicit section status, response limits and provenance. Optional task_id records a system observation in an existing investigation task. style=llm returns provider-specific supporting metadata when available. Plain results over ~12KB spill to an artifact file with a preview. Read-only; does not execute the sample or verify hypotheses.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "target": {
      "type": "string",
      "description": "Target path previously opened with ig5_open"
    },
    "ea": {
      "type": "string",
      "description": "Function address, hex string like 0x140001070"
    },
    "name": {
      "type": "string",
      "description": "Exact function name (used when ea is absent)"
    },
    "style": {
      "type": "string",
      "enum": [
        "",
        "llm",
        "dossier"
      ],
      "description": "Omit for plain pseudocode; llm metadata depends on the provider; dossier aggregates real function context"
    },
    "dossier_max_bytes": {
      "type": "number",
      "description": "Dossier body UTF-8 response budget, 4000..64000 bytes, default 16000; not a total backend computation budget"
    },
    "dossier_max_rows": {
      "type": "number",
      "description": "Dossier per-array row cap, 1..128, default 32"
    },
    "task_id": {
      "type": "string",
      "description": "Existing workspace task UUID; requires style=dossier and records only system-produced observations"
    },
    "engine": {
      "type": "string",
      "enum": [
        "reverse",
        "ghidra"
      ],
      "description": "Explicit backend. Omit to use the configured primary static engine; results identify their source."
    }
  },
  "required": [
    "target"
  ]
}
```

## 工具：ig5_doctor

Self-check the selected IG5 engine/provider. Default Reverse and Ghidra use the bundled Ghidra runtime; only explicitly selected commercial Reverse requires a licensed local installation. x64dbg reads file layout and retained launch-policy blocks without launching its debugger. not-probed is unknown; known blocks deny native launch before process creation. File presence is not startup verification; no OS policy changes.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "engine": {
      "type": "string",
      "enum": [
        "reverse",
        "ghidra",
        "x64dbg"
      ],
      "description": "Explicit backend. Omit to use the configured primary static engine; results identify their source."
    }
  },
  "additionalProperties": false
}
```

## 工具：ig5_funcs

List functions of an open target, paged: address (EA), name, size. Use filter for a name substring. EA is the stable handle for every other ig5 tool.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "target": {
      "type": "string",
      "description": "Target path previously opened with ig5_open"
    },
    "offset": {
      "type": "number",
      "description": "Skip first N functions (cursor paging)"
    },
    "limit": {
      "type": "number",
      "description": "Max rows (default 30, max 200)"
    },
    "filter": {
      "type": "string",
      "description": "Case-insensitive name substring filter"
    },
    "user_only": {
      "type": "boolean",
      "description": "Exclude functions classified as library-related by the active provider. The bundled core excludes external/thunk functions only; remaining functions are not proof of user-authored logic."
    },
    "engine": {
      "type": "string",
      "enum": [
        "reverse",
        "ghidra"
      ],
      "description": "Explicit backend. Omit to use the configured primary static engine; results identify their source."
    }
  },
  "required": [
    "target"
  ]
}
```

## 工具：ig5_open

Open a binary in the selected static engine and run auto-analysis. Returns project/artifact identity, engine, database revision, architecture, segments, function count and entries. One worker per target and engine. Analysis defaults to a native background job; pass background:false for inline results. A runtime pack is required for the selected engine.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "path": {
      "type": "string",
      "description": "Absolute path of the target binary"
    },
    "auto_analysis": {
      "type": "boolean",
      "description": "Run automatic analysis using the selected profile (default true)"
    },
    "analysis_timeout": {
      "type": "number",
      "description": "Ghidra analysis budget in seconds, 1..600; returns explicitly partial evidence if exhausted"
    },
    "analysis_profile": {
      "type": "string",
      "enum": [
        "interactive",
        "full"
      ],
      "description": "Ghidra: interactive (default) skips batch Decompiler Parameter ID; full enables that batch analyzer. Function decompilation is available in both."
    },
    "background": {
      "type": "boolean",
      "description": "Run the analysis as a background job (default true). false = block this call until analysis finishes."
    },
    "fresh": {
      "type": "boolean",
      "description": "Ignore and back up an adjacent existing .i64/.idb so the database is re-analyzed from scratch (default false = reuse)"
    },
    "engine": {
      "type": "string",
      "enum": [
        "reverse",
        "ghidra"
      ],
      "description": "Explicit backend. Omit to use the configured primary static engine; results identify their source."
    }
  },
  "required": [
    "path"
  ]
}
```

## 工具：ig5_profile

Return IG5 engines, projects, active tools and skills, plus the calling agent's host Goal availability/state. recovery={case_ref:{path,sha256}} separately reads a bounded recovery case and returns a failure/dependency plan. Alternatively recovery={observations:{recordings:[{id,sha256}],target_sha256,offset,limit}} imports committed debug-trace reports into ordered, source-bound observation pages; no native execution, invented intermediate state or VM/business proof. Alternatively recovery={roles:{recordings:[{id,sha256}],target_sha256}} samples recorded addressing/load/control observations using an owned disassembly-only job; candidates retain ordinary-program ambiguity and do not prove VM roles. Alternatively recovery={flow:{roles_ref:{id,sha256},target}} revalidates a committed role report and recordings, selects a contiguous candidate-to-indirect window, verifies exact raw-file mapping, and uses Java full-state plus source-prefix projections for structural load/index/target dependencies. All stores and ordinary-program ambiguity remain; no VM, semantic-nonconstancy or business proof. All recovery modes save immutable reports and reject other profile options. For sustained reverse engineering use ig5-reverse-agent and native Goal tools. Optionally switch core (8 tools) or full (40) for the calling agent. workspace manages caller notes and separate system dossier evidence for an explicitly opened target; updates require expected_task_revision. History stats/archive/restore retain report IDs and refs.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "recovery": {
      "type": "object",
      "properties": {
        "case_ref": {
          "type": "object",
          "properties": {
            "path": {
              "type": "string",
              "description": "Explicit absolute local recovery-case JSON path, at most 256 KiB"
            },
            "sha256": {
              "type": "string",
              "pattern": "^[a-f0-9]{64}$",
              "description": "SHA-256 of the exact case bytes; verified before reading its references"
            }
          },
          "required": [
            "path",
            "sha256"
          ],
          "additionalProperties": false
        },
        "observations": {
          "type": "object",
          "properties": {
            "recordings": {
              "type": "array",
              "minItems": 1,
              "maxItems": 256,
              "items": {
                "type": "object",
                "properties": {
                  "id": {
                    "type": "string",
                    "description": "debug-trace report UUID in this configured artifact store"
                  },
                  "sha256": {
                    "type": "string",
                    "pattern": "^[a-f0-9]{64}$",
                    "description": "Exact report SHA-256, not the trace blob SHA"
                  }
                },
                "required": [
                  "id",
                  "sha256"
                ],
                "additionalProperties": false
              }
            },
            "target_sha256": {
              "type": "string",
              "pattern": "^[a-f0-9]{64}$"
            },
            "max_instructions": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100000,
              "description": "Default 50000, checked over every supplied window even for a small output page"
            },
            "offset": {
              "type": "integer",
              "minimum": 0,
              "maximum": 100000
            },
            "limit": {
              "type": "integer",
              "minimum": 1,
              "maximum": 64,
              "description": "Observed stop groups, default 32; a CPUID group may include a continuation without intermediate state"
            }
          },
          "required": [
            "recordings",
            "target_sha256"
          ],
          "additionalProperties": false
        },
        "roles": {
          "type": "object",
          "properties": {
            "recordings": {
              "type": "array",
              "minItems": 1,
              "maxItems": 256,
              "items": {
                "type": "object",
                "properties": {
                  "id": {
                    "type": "string",
                    "description": "debug-trace report UUID in this configured artifact store"
                  },
                  "sha256": {
                    "type": "string",
                    "pattern": "^[a-f0-9]{64}$",
                    "description": "Exact report SHA-256, not the trace blob SHA"
                  }
                },
                "required": [
                  "id",
                  "sha256"
                ],
                "additionalProperties": false
              }
            },
            "target_sha256": {
              "type": "string",
              "pattern": "^[a-f0-9]{64}$"
            },
            "max_instructions": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100000,
              "description": "Default 50000, checked over every supplied window even for a small output page"
            }
          },
          "required": [
            "recordings",
            "target_sha256"
          ],
          "additionalProperties": false
        },
        "flow": {
          "type": "object",
          "properties": {
            "roles_ref": {
              "type": "object",
              "properties": {
                "id": {
                  "type": "string"
                },
                "sha256": {
                  "type": "string",
                  "pattern": "^[a-f0-9]{64}$"
                }
              },
              "required": [
                "id",
                "sha256"
              ],
              "additionalProperties": false
            },
            "target": {
              "type": "string",
              "description": "Explicit existing same-SHA raw AMD64 PE; static snapshot only, never restore missing/quarantined files"
            },
            "max_instructions": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100000,
              "description": "Default 50000 over every original recording window"
            },
            "semantic_check": {
              "type": "boolean",
              "description": "Optional paired ordinary-IR states with pinned bounded SMT and independent finite witness replay; not CPU/VM/business recovery"
            }
          },
          "required": [
            "roles_ref",
            "target"
          ],
          "additionalProperties": false
        },
        "recurrences": {
          "type": "object",
          "properties": {
            "flow_ref": {
              "type": "object",
              "properties": {
                "id": {
                  "type": "string"
                },
                "sha256": {
                  "type": "string",
                  "pattern": "^[a-f0-9]{64}$"
                }
              },
              "required": [
                "id",
                "sha256"
              ],
              "additionalProperties": false
            },
            "max_instructions": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100000,
              "description": "Default 50000 over all original recording windows"
            },
            "sample_strategy": {
              "type": "string",
              "enum": [
                "first4-last4",
                "distinct-source-targets"
              ],
              "description": "Default first4-last4; optional first occurrence per observed source/target pair, eight pairs per page"
            },
            "pair_offset": {
              "type": "integer",
              "minimum": 0,
              "maximum": 255,
              "description": "Only with distinct-source-targets; first-appearance pair ordinal, default 0"
            }
          },
          "required": [
            "flow_ref"
          ],
          "additionalProperties": false
        },
        "handlers": {
          "type": "object",
          "properties": {
            "recurrences_ref": {
              "type": "object",
              "properties": {
                "id": {
                  "type": "string"
                },
                "sha256": {
                  "type": "string",
                  "pattern": "^[a-f0-9]{64}$"
                }
              },
              "required": [
                "id",
                "sha256"
              ],
              "additionalProperties": false
            },
            "target": {
              "type": "string",
              "description": "Explicit existing same-SHA raw AMD64 PE for static body projection only"
            },
            "max_instructions": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100000,
              "description": "Default 50000 over every original recording window"
            }
          },
          "required": [
            "recurrences_ref",
            "target"
          ],
          "additionalProperties": false
        },
        "context": {
          "type": "object",
          "properties": {
            "handler_refs": {
              "type": "array",
              "minItems": 1,
              "maxItems": 16,
              "items": {
                "type": "object",
                "properties": {
                  "id": {
                    "type": "string"
                  },
                  "sha256": {
                    "type": "string",
                    "pattern": "^[a-f0-9]{64}$"
                  }
                },
                "required": [
                  "id",
                  "sha256"
                ],
                "additionalProperties": false
              }
            }
          },
          "required": [
            "handler_refs"
          ],
          "additionalProperties": false
        }
      },
      "oneOf": [
        {
          "required": [
            "case_ref"
          ]
        },
        {
          "required": [
            "observations"
          ]
        },
        {
          "required": [
            "roles"
          ]
        },
        {
          "required": [
            "flow"
          ]
        },
        {
          "required": [
            "recurrences"
          ]
        },
        {
          "required": [
            "handlers"
          ]
        },
        {
          "required": [
            "context"
          ]
        }
      ],
      "additionalProperties": false
    },
    "target": {
      "type": "string",
      "description": "Explicit opened static target, required for workspace"
    },
    "guest_debug": {
      "type": "string",
      "description": "Inspect a configured VMCI guest profile and obtain its bindingSha256 before an approved debugger call; reads files only"
    },
    "workspace": {
      "description": "Static investigation notes and evidence. Before DSH delegation, read the task then use handoff with current expected_task_revision, question, acceptance and constraints. Send its packet to the child. Child checks target/engine/revision, relevant architecture and complete evidence, then returns candidates and snapshot IDs. Parent uses review to verify 1..8 task snapshots; semantic acceptance remains independent. No agent spawning, permission grants or automatic completion.",
      "type": "object",
      "properties": {
        "action": {
          "type": "string",
          "enum": [
            "create",
            "get",
            "list",
            "update",
            "evidence",
            "handoff",
            "claim",
            "submit",
            "review"
          ]
        },
        "handoff_id": {
          "type": "string",
          "description": "Child claim/submit, parent post-return review: tracked handoffId. Review without it is integrity precheck only, never delegation acceptance."
        },
        "question": {
          "type": "string",
          "maxLength": 2048,
          "description": "handoff: bounded delegated question; caller statement"
        },
        "acceptance": {
          "type": "string",
          "maxLength": 2048,
          "description": "handoff: explicit acceptance criteria; text only, never executed"
        },
        "constraints": {
          "type": "string",
          "maxLength": 2048,
          "description": "handoff: responsibility and limits; advisory, not an access-control policy"
        },
        "snapshot_ids": {
          "type": "array",
          "minItems": 1,
          "maxItems": 8,
          "uniqueItems": true,
          "items": {
            "type": "string"
          },
          "description": "review: task-bound system snapshots to revalidate; not a semantic completion verdict"
        },
        "id": {
          "type": "string",
          "description": "Task UUID returned by create or list"
        },
        "snapshot_id": {
          "type": "string",
          "description": "System snapshot UUID from this task; evidence action only"
        },
        "expected_task_revision": {
          "type": "number",
          "description": "Required for update: use the returned taskRevision, independent of the database revision"
        },
        "goal": {
          "type": "string",
          "maxLength": 4096
        },
        "hypothesis": {
          "type": "string",
          "maxLength": 4096,
          "description": "Caller statement, not verified evidence; do not include secrets"
        },
        "next_step": {
          "type": "string",
          "maxLength": 4096
        },
        "conclusion": {
          "type": "string",
          "maxLength": 4096,
          "description": "Caller interpretation, not automatic verification"
        },
        "status": {
          "type": "string",
          "enum": [
            "active",
            "paused",
            "completed"
          ],
          "description": "Caller-declared work progress"
        }
      },
      "required": [
        "action"
      ],
      "additionalProperties": false
    },
    "toolset": {
      "type": "string",
      "enum": [
        "core",
        "full"
      ]
    },
    "history": {
      "type": "object",
      "properties": {
        "action": {
          "type": "string",
          "enum": [
            "stats",
            "archive",
            "restore"
          ]
        },
        "ids": {
          "type": "array",
          "minItems": 1,
          "maxItems": 1000,
          "items": {
            "type": "string"
          }
        }
      },
      "required": [
        "action"
      ],
      "additionalProperties": false
    },
    "engine": {
      "type": "string",
      "enum": [
        "reverse",
        "ghidra"
      ],
      "description": "Explicit backend. Omit to use the configured primary static engine; results identify their source."
    },
    "collaboration": {
      "type": "object",
      "properties": {
        "action": {
          "type": "string",
          "enum": [
            "start",
            "status"
          ]
        },
        "max_calls": {
          "type": "integer",
          "minimum": 1,
          "maximum": 1000,
          "description": "start only: persistent shared cap for parent + all descendant IG5 dispatches; cannot be reset/enlarged"
        }
      },
      "required": [
        "action"
      ],
      "additionalProperties": false,
      "description": "Use separately BEFORE work: start shared budget, or status (exempt control-plane query). Counts all IG5 calls incl. child profile/open/evidence/errors, not just parent calls. No token/non-IG5 limit."
    }
  },
  "additionalProperties": false
}
```

## 工具：ig5_status

List open IG5 workers and pending remoteExecutions. Separately remoteCleanupEvidence revalidates at most eight stored terminal receipts against original bindings and byte hashes; missing/corrupt evidence stays unknown. An empty pending list is not proof of cleanup. Stored receipt validation is not a new HMAC exchange or authority for newer processes.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "engine": {
      "type": "string",
      "enum": [
        "reverse",
        "ghidra"
      ],
      "description": "Explicit backend. Omit to use the configured primary static engine; results identify their source."
    }
  },
  "additionalProperties": false
}
```

## 工具：ig5_strings

List strings of an open target with addresses, paged. First hop for locating license checks, messages, URLs, and crypto constants.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "target": {
      "type": "string",
      "description": "Target path previously opened with ig5_open"
    },
    "offset": {
      "type": "number"
    },
    "limit": {
      "type": "number",
      "description": "Max rows (default 30, max 200)"
    },
    "engine": {
      "type": "string",
      "enum": [
        "reverse",
        "ghidra"
      ],
      "description": "Explicit backend. Omit to use the configured primary static engine; results identify their source."
    }
  },
  "required": [
    "target"
  ]
}
```
