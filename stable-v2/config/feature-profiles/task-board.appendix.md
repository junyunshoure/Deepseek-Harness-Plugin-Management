# 任务看板 (task-board) 附录

本文件是精确参数与原始规范，只在需要具体字段时读取。

## 工具：task_board_create

Create a task on the DSH task board, or a subtask by passing parentId. A subtask inherits every execution target it does not override (workspace, agent preset, permission, model) from its parent, and inherits the parent human permission confirmation together with an inherited binding. The deployment caps subtask depth (default one level, maximum three): a subtask of a subtask is refused unless the board is configured deeper. The task lands in the todo column and does NOT run; call task_board_run to execute it.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "title": {
      "type": "string",
      "description": "Short display title (one line)."
    },
    "description": {
      "type": "string",
      "description": "Longer human description shown in the detail view."
    },
    "prompt": {
      "type": "string",
      "description": "The instruction sent to the execution agent; the title is used when blank."
    },
    "parentId": {
      "type": "string",
      "description": "Parent task id, making this a subtask. Omit for a root task."
    },
    "workspaceId": {
      "type": "string",
      "description": "Workspace id the execution must run in; omit to inherit the workspace this session is in (root task) or the parent value (subtask)."
    },
    "mode": {
      "type": "string",
      "description": "Agent preset id the execution session is composed from; omit for the deployment default or the parent value."
    },
    "permission": {
      "type": "string",
      "description": "Permission preset for the execution session. Omit to inherit the parent binding; a value above the session default needs a human confirmation in the board UI before the card can run.",
      "enum": [
        "read-only",
        "workspace-write",
        "danger-full-access"
      ]
    },
    "model": {
      "type": "string",
      "description": "Pinned model as provider/model (or a model id); omit for the host default or the parent value."
    },
    "reuseSession": {
      "type": "boolean",
      "description": "Continue later runs in the previous execution session instead of a fresh conversation."
    },
    "teamRun": {
      "type": "boolean",
      "description": "Run this task as an Agent Team: running it starts one Team Lead session and the Host spawns a teammate per subtask inside it. Omit or false for one independent session per member. Refused when the deployment serves no Agent Teams service."
    },
    "goalRun": {
      "type": "boolean",
      "description": "Start each run with dsh built-in /goal so the session keeps working continuation rounds until the goal completes. Off by default: omit (or pass false) for a single plain turn, and pass true to opt this card in. It only takes effect while the deployment global native /goal switch is on."
    },
    "skipVerification": {
      "type": "boolean",
      "description": "Run this task without the board acceptance gate: update_goal may mark the goal complete without a passing acceptance, and the execution record is marked skipped. Default false (omit to inherit the board-wide acceptance switch). Only affects executions started afterwards."
    },
    "tags": {
      "type": "array",
      "description": "Labels: the name renders as a badge and drives the board filter; promptPrefix is injected ahead of the execution prompt on every run.",
      "items": {
        "type": "object",
        "additionalProperties": false,
        "properties": {
          "name": {
            "type": "string",
            "description": "Label name (unique within the task, at most 32 characters)."
          },
          "promptPrefix": {
            "type": "string",
            "description": "Optional prompt line injected before the task prompt (at most 200 characters)."
          }
        },
        "required": [
          "name"
        ]
      }
    },
    "schedule": {
      "type": "object",
      "description": "Arm a schedule at creation time. Use mode \"once\" with at for a single future run, or mode \"cron\" (or omit mode) with a 5-field cron expression, optionally capped by maxRuns.",
      "additionalProperties": false,
      "properties": {
        "enabled": {
          "type": "boolean",
          "description": "Whether the schedule is armed."
        },
        "mode": {
          "type": "string",
          "description": "The kind of plan: \"cron\" for a recurring rule, \"once\" for a single future instant.",
          "enum": [
            "cron",
            "once"
          ]
        },
        "cron": {
          "type": "string",
          "description": "5-field cron of a recurring rule: minute hour day-of-month month day-of-week."
        },
        "at": {
          "type": "integer",
          "description": "Planned instant of a one-shot, in milliseconds since the Unix epoch (UTC). Must be in the future."
        },
        "maxRuns": {
          "type": "integer",
          "description": "Maximum scheduled executions of a recurring rule (positive whole number); omit for unlimited."
        }
      },
      "required": [
        "enabled"
      ]
    }
  },
  "required": [
    "title"
  ]
}
```

## 工具：task_board_get

Read one task board card in full: prompt, description, labels, column, parent link, direct subtasks, execution targets, schedule, permission gate state, and the last ten execution attempts with their session ids and outcomes. Use it before running or editing a card, and after a run to read the settled outcome.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "taskId": {
      "type": "string",
      "description": "Task id, as reported by task_board_list or task_board_create."
    }
  },
  "required": [
    "taskId"
  ]
}
```

## 工具：task_board_github_close_issue

Close the GitHub issue behind a task board card, once the work has actually landed. Refused unless the card has a linked pull request that is MERGED: a passing local run is not a reviewed change. Does not run shell commands.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "taskId": {
      "type": "string",
      "description": "Task ID linked to a GitHub issue."
    }
  },
  "required": [
    "taskId"
  ]
}
```

## 工具：task_board_github_comment

Post one comment on the GitHub issue behind a task board card. Use it to report what was done, link the pull request, or state why the task was closed without a fix. The body is Markdown and must stay under the length limit. Does not run shell commands.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "taskId": {
      "type": "string",
      "description": "Task ID linked to a GitHub issue."
    },
    "body": {
      "type": "string",
      "description": "Markdown comment body to post. Must be non-empty and under the length limit; a transcript belongs in the card, not in a comment."
    }
  },
  "required": [
    "taskId",
    "body"
  ]
}
```

## 工具：task_board_github_create_pr

Create a GitHub Pull Request for a task board card linked to a GitHub issue. Verifies that the head branch exists on remote, creates the PR, records PR metadata, and adds the PR phase label to the issue. Does not run shell commands.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "taskId": {
      "type": "string",
      "description": "Task ID linked to a GitHub issue."
    },
    "headBranch": {
      "type": "string",
      "description": "Remote head branch containing the changes (must already exist on remote)."
    },
    "baseBranch": {
      "type": "string",
      "description": "Target base branch (default: repository default, e.g. main)."
    },
    "title": {
      "type": "string",
      "description": "PR title (default: task title)."
    },
    "body": {
      "type": "string",
      "description": "PR body text (default includes \"Fixes #<issue>\" and task description)."
    },
    "draft": {
      "type": "boolean",
      "description": "Whether to create the PR as draft."
    }
  },
  "required": [
    "taskId",
    "headBranch"
  ]
}
```

## 工具：task_board_github_get

Get full GitHub integration details for a task board card, including remote issue title, body, labels, pull request details, and synchronization state.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "taskId": {
      "type": "string",
      "description": "Task ID on the board."
    },
    "owner": {
      "type": "string",
      "description": "Repository owner (used with repository and issueNumber)."
    },
    "repository": {
      "type": "string",
      "description": "Repository name (used with owner and issueNumber)."
    },
    "issueNumber": {
      "type": "number",
      "description": "GitHub issue number."
    }
  }
}
```

## 工具：task_board_github_link_pr

Link an existing GitHub Pull Request to a task board card linked to a GitHub issue, updating PR metadata and managed phase labels.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "taskId": {
      "type": "string",
      "description": "Task ID linked to a GitHub issue."
    },
    "pullRequestNumber": {
      "type": "number",
      "description": "Pull request number on GitHub."
    }
  },
  "required": [
    "taskId",
    "pullRequestNumber"
  ]
}
```

## 工具：task_board_github_list

List task board cards associated with GitHub issues, with their remote issue state, remote labels, and pull request metadata.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "owner": {
      "type": "string",
      "description": "Filter by repository owner."
    },
    "repository": {
      "type": "string",
      "description": "Filter by repository name."
    },
    "state": {
      "type": "string",
      "description": "Filter by remote issue state (open, closed, or all; default: all).",
      "enum": [
        "open",
        "closed",
        "all"
      ]
    },
    "hasPr": {
      "type": "boolean",
      "description": "Filter by whether a pull request is linked."
    }
  }
}
```

## 工具：task_board_github_refresh

Trigger synchronization between GitHub issues/pull requests and the task board for a task, a repository, or all configured repositories.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "taskId": {
      "type": "string",
      "description": "Specific task ID to refresh."
    },
    "owner": {
      "type": "string",
      "description": "Repository owner to refresh."
    },
    "repository": {
      "type": "string",
      "description": "Repository name to refresh."
    }
  }
}
```

## 工具：task_board_github_repositories

Read and edit the repositories the GitHub Issues integration synchronizes with the task board. An issue is included when it carries the inclusion label or is assigned to the configured assignee. A repository is written to the plugin configuration as soon as the call returns, so no restart is needed.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "action": {
      "type": "string",
      "description": "list reads the configured repositories; add, remove and update rewrite the list.",
      "enum": [
        "list",
        "add",
        "remove",
        "update"
      ]
    },
    "repository": {
      "type": "string",
      "description": "Repository to act on: owner/repo, a GitHub URL, or an SSH remote. Required by add, remove and update."
    },
    "inclusionLabel": {
      "type": "string",
      "description": "Issue label that opts an issue into the board (default dsh)."
    },
    "assignee": {
      "type": "string",
      "description": "Login whose assigned issues are included too; use @me for the account the host is authenticated as, or an empty string to turn the channel off. Trivial filters such as \"assigned to me\" belong here."
    },
    "includeUnassigned": {
      "type": "boolean",
      "description": "Whether issues assigned to nobody are included too; set it on repositories whose issues are never assigned. It never pulls in issues assigned to other people."
    },
    "baseBranch": {
      "type": "string",
      "description": "Base branch pull requests target (default main)."
    },
    "prCreationEnabled": {
      "type": "boolean",
      "description": "Whether the extension may open pull requests for completed cards."
    },
    "pollingIntervalMs": {
      "type": "number",
      "description": "Background polling interval in milliseconds (default 300000; 0 disables polling)."
    },
    "analysisModel": {
      "type": "string",
      "description": "Qualified provider/model the AI issue analysis uses for this repository's cards; an empty string falls back to the card's pinned model, then the host default."
    }
  },
  "required": [
    "action"
  ]
}
```

## 工具：task_board_github_setup

Configure the task board GitHub Issues integration: read the setup status, store or clear the GitHub token, and run a live connection test against GitHub. The token is stored host-side in the harness credential store and is never returned by any tool. Because a token passed as an argument becomes part of this conversation, prefer asking the user to paste it in the extension settings card when they can reach it.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "action": {
      "type": "string",
      "description": "status reads the current configuration; set-token stores the token; clear-token removes it; test calls GitHub.",
      "enum": [
        "status",
        "set-token",
        "clear-token",
        "test"
      ]
    },
    "token": {
      "type": "string",
      "description": "GitHub token to store; required by set-token. It becomes part of this conversation."
    },
    "owner": {
      "type": "string",
      "description": "Repository owner to test only that repository."
    },
    "repository": {
      "type": "string",
      "description": "Repository name to test only that repository."
    }
  },
  "required": [
    "action"
  ]
}
```

## 工具：task_board_list

List tasks on the DSH task board (the Host-authoritative ledger behind the Web GUI task board). Filters: status column, parentId (direct subtasks), rootsOnly, tag, free-text query, and archived inclusion. Returns each task id, title, column, parent/subtask link, execution targets, schedule and latest run outcome, plus the board summary (revision, time zone, subtask depth limit, session-default permission). Use task_board_get for one task in full, task_board_create to add work, and task_board_run to execute it.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "status": {
      "type": "string",
      "description": "Only cards in this column.",
      "enum": [
        "backlog",
        "todo",
        "running",
        "done",
        "failed"
      ]
    },
    "parentId": {
      "type": "string",
      "description": "Only the direct subtasks of this task id."
    },
    "rootsOnly": {
      "type": "boolean",
      "description": "Only tasks that have no parent (default false)."
    },
    "includeArchived": {
      "type": "boolean",
      "description": "Include archived tasks (default false)."
    },
    "tag": {
      "type": "string",
      "description": "Only tasks carrying this label name."
    },
    "query": {
      "type": "string",
      "description": "Case-insensitive match against title, description, prompt, and label names."
    },
    "limit": {
      "type": "integer",
      "description": "Maximum rows to return (default 50, maximum 200)."
    }
  }
}
```

## 工具：task_board_manage

Move, archive, restore, delete, or settle one task board card. move-backlog, move-todo, move-running, move-done and move-failed are the manual column moves and cover every column; a card the runner is executing (one with an open execution) cannot be moved. A manual move writes the card column only and never fabricates an execution record, so the card reports a declaration rather than evidence of a run: done/failed declare work finished (or failed) outside a Host-run execution — human work, an external system, a decision made elsewhere — and running says the work is under way without a tracked session. Use task_board_run when the work should actually run in a session here. record-external-outcome is the record-backed version of move-done and move-failed: use it when YOU, or another agent outside this Host, actually finished or failed the card with your own model, so the terminal column and the run history both derive from one execution record. It takes result (succeeded or failed) and initiatedBy (who completed it, for example your own agent name) plus an optional summary, and it is refused while the card still has an open execution: the Host stays the only authority over a run it is executing. It cannot record running or cancelled — those remain Host-only. settle force-closes the open execution of a card the board can no longer observe (a stuck running card) and records it cancelled with the caller as the reason, so the card returns to the todo column and can be run again. reset-verification clears the acceptance anomalies (timeouts, authentication failures, an unresolvable judge route, or an attempt the time budget ended) recorded on a card open execution, so the next update_goal(action: complete) runs a fresh acceptance. It is refused unless that execution really carries such anomalies, it never clears a quality verdict, and a spent anomaly budget otherwise HOLDS the card open instead of failing it: tell the user the acceptance environment is unusable and that this action is how they clear it once they have fixed it. archive takes the whole subtask tree off the board and is refused while any member has an unsettled execution; restore brings the task, its ancestors and its subtree back; delete removes one card and is refused while it still has subtasks (detach or delete them first) or while it runs. It cannot confirm a permission binding: the confirmation gate is a human act performed in the board UI.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "taskId": {
      "type": "string",
      "description": "The task to act on."
    },
    "action": {
      "type": "string",
      "description": "The lifecycle operation to perform.",
      "enum": [
        "move-todo",
        "move-backlog",
        "move-running",
        "move-done",
        "move-failed",
        "archive",
        "restore",
        "delete",
        "settle",
        "reset-verification",
        "record-external-outcome"
      ]
    },
    "result": {
      "type": "string",
      "description": "record-external-outcome only: the verdict the outside agent actually reached.",
      "enum": [
        "succeeded",
        "failed"
      ]
    },
    "initiatedBy": {
      "type": "string",
      "description": "record-external-outcome only: who finished the work outside this Host (for example your own agent name)."
    },
    "summary": {
      "type": "string",
      "description": "record-external-outcome only: optional free-text note stored with the recorded outcome."
    }
  },
  "required": [
    "taskId",
    "action"
  ]
}
```

## 工具：task_board_run

Run a task on the board now, or re-run a settled one. Running a task also runs its whole subtask tree CONCURRENTLY: the Host opens one real DSH session per member under one run group, each replaying its card pinned workspace, agent preset, permission and model; a subtask that does not pin them inherits its nearest ancestor. The parent card stays in the running column until its own turn and every direct subtask have settled, and it fails when any member failed; one failing subtask never stops the others. A card whose effective permission is above the deployment session default is refused with confirmation-required until a HUMAN confirms the binding in the board UI; this tool cannot confirm it. A card whose task carries teamRun instead starts ONE Team Lead session and the Host spawns a teammate per subtask inside it, so those cards run as an Agent Team rather than as independent sessions; that mode needs the deployment Agent Teams service and is refused when it is missing. Executions consume real API quota. Sessions are created asynchronously, so read their ids and outcomes back with task_board_get.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "taskId": {
      "type": "string",
      "description": "The task to run; running a root task runs its whole subtree."
    },
    "rerun": {
      "type": "boolean",
      "description": "Re-run a settled task: reset its column to todo before starting (default false)."
    }
  },
  "required": [
    "taskId"
  ]
}
```

## 工具：task_board_schedule

Arm, change, or disarm a task scheduled runs. Two kinds of plan exist: a recurring 5-field cron rule (day-of-month and day-of-week follow Vixie semantics: both restricted means OR, otherwise AND), and a one-shot that runs once at a future instant. For a one-shot pass mode "once" with at (the planned instant, ms since epoch UTC). For a recurring rule pass mode "cron" (or omit mode) with a cron expression, optionally capped by maxRuns (a positive whole number of scheduled executions; omit for unlimited, pass 0 to clear a cap). The wall clock is read in the rule stored IANA time zone; omit timeZone to use the Host zone reported by task_board_list/task_board_get. DST gaps are skipped and an ambiguous fall-back time fires once, at the earlier instant. A due scheduled task runs the same cascade a manual run does, so a root task runs its whole subtask tree. The scheduler counts executions it actually starts; once a rule reaches its run budget it stops itself in the ledger, and a manual run never consumes the budget. A schedule whose tree contains an unconfirmed above-default permission is refused and does not consume the budget; the reason is reported in the list board summary as schedulerError. Missed occurrences during Host downtime are skipped, never queued (a one-shot whose instant passed while the Host was down is stopped as missed); a task that is already running skips its occurrence without consuming the budget.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "taskId": {
      "type": "string",
      "description": "The task whose schedule changes."
    },
    "enabled": {
      "type": "boolean",
      "description": "Arm (true) or disarm (false) the schedule."
    },
    "mode": {
      "type": "string",
      "description": "The kind of plan: \"cron\" for a recurring rule, \"once\" for a single future instant. Omit to keep the stored kind.",
      "enum": [
        "cron",
        "once"
      ]
    },
    "cron": {
      "type": "string",
      "description": "5-field cron expression of a recurring rule: minute hour day-of-month month day-of-week."
    },
    "at": {
      "type": "integer",
      "description": "Planned instant of a one-shot, in milliseconds since the Unix epoch (UTC). Must be in the future."
    },
    "timeZone": {
      "type": "string",
      "description": "IANA zone the wall clock is read in (for example Asia/Shanghai). Omit to keep the stored zone, or pass an empty string to clear it back to the Host zone."
    },
    "maxRuns": {
      "type": "integer",
      "description": "Maximum scheduled executions of a recurring rule (positive whole number). Omit to keep the stored cap; pass 0 to clear it back to unlimited."
    }
  },
  "required": [
    "taskId"
  ]
}
```

## 工具：task_board_set_parent

Attach an existing task under a parent (making it a subtask) or detach it back to the root board by setting its parentId. Pass an empty parentId to detach. The Host refuses the link when the parent is unknown or archived, when the moved task is one of its own descendants, when the resulting depth exceeds the deployment subtask limit (default one level, maximum three), or while the task has an unsettled execution (its link may still be a running cascade parent pointer). Running a task runs its whole subtree concurrently; a parent card settles only after its own turn and every direct subtask settle.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "taskId": {
      "type": "string",
      "description": "The task whose parent link changes."
    },
    "parentId": {
      "type": "string",
      "description": "Parent task id, or an empty string to detach the task back to the root board."
    }
  },
  "required": [
    "taskId",
    "parentId"
  ]
}
```

## 工具：task_board_update

Edit a task board card: title, description, prompt, labels, and the execution targets (workspace, agent preset, permission, model, session reuse). Only the fields you pass change; pass an empty string to clear a target, or an empty labels array to clear the labels. Title, description and prompt freeze once the task has started executing; the execution targets stay editable because they only affect future runs. Changing the pinned permission re-arms the permission confirmation gate.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "taskId": {
      "type": "string",
      "description": "Task id to edit."
    },
    "title": {
      "type": "string",
      "description": "New title (a blank title is refused by the Host)."
    },
    "description": {
      "type": "string",
      "description": "New description."
    },
    "prompt": {
      "type": "string",
      "description": "New execution prompt."
    },
    "workspaceId": {
      "type": "string",
      "description": "New workspace id; an empty string clears it."
    },
    "mode": {
      "type": "string",
      "description": "New agent preset id; an empty string clears it."
    },
    "permission": {
      "oneOf": [
        {
          "type": "string",
          "enum": [
            "read-only",
            "workspace-write",
            "danger-full-access"
          ]
        },
        {
          "type": "string",
          "const": ""
        }
      ],
      "description": "New permission preset; an empty string clears it back to the session default."
    },
    "model": {
      "type": "string",
      "description": "New pinned model; an empty string clears it."
    },
    "reuseSession": {
      "type": "boolean",
      "description": "Continue later runs in the previous execution session."
    },
    "teamRun": {
      "type": "boolean",
      "description": "Switches this task between a plain cascade (one session per member) and an Agent Team run (Lead session plus a teammate per subtask)."
    },
    "goalRun": {
      "type": "boolean",
      "description": "Whether each run starts with dsh built-in /goal (default false, one plain turn). Pass true to opt this card in, or false to return it to the default."
    },
    "skipVerification": {
      "type": "boolean",
      "description": "Whether this task runs without the board acceptance gate (default false, inherit the board-wide switch). Pass true to opt out; pass false to opt back in. Only affects executions started afterwards."
    },
    "tags": {
      "type": "array",
      "description": "Replacement label set; an empty array clears all labels.",
      "items": {
        "type": "object",
        "additionalProperties": false,
        "properties": {
          "name": {
            "type": "string",
            "description": "Label name."
          },
          "promptPrefix": {
            "type": "string",
            "description": "Optional prompt line injected before the task prompt."
          }
        },
        "required": [
          "name"
        ]
      }
    }
  },
  "required": [
    "taskId"
  ]
}
```
