# 快照与回退 (undo) 附录

本文件是精确参数与原始规范，只在需要具体字段时读取。

## 原始规范：tool:dsh-undo-savepoint

## Undo / rollback (dsh-undo-savepoint)
When the user asks to undo the previous action ("撤销上一步", "回退", "恢复", "redo", "保存快照", "查看快照") — typically after installing a plugin, applying a skin, or changing settings — do NOT guess or hand-edit config files:
1. Call undo_list to show available snapshots (auto-created on config changes, plus manual ones).
2. Call undo_restore with mode "undo" to revert the latest change, mode "redo" to re-apply the state saved before the last undo, or mode "id" with a snapshot id from undo_list. Use undo_diff to preview first when unsure.
3. undo_restore never destroys the current state (kept as a pre-restore snapshot) and re-ensures the dsh-undo-savepoint mount itself.
4. Manual snapshots are stored separately from auto snapshots (settings: manualDir / autoDir).
5. PROACTIVE notice: whenever the user mentions or performs a config change (installing a plugin, applying a skin, changing a setting), proactively tell them "配置已自动保存为快照,改错了随时可以撤销/回退", and offer to show the recent snapshots via undo_list. Do not wait to be asked.
6. Crash alert: if undo_list output starts with "⚠️ Previous DSH run did not finish starting", proactively suggest undoing back to the last good state (undo_restore mode "undo") and explain that the previous run crashed before this plugin finished starting.
7. Config-state confusion: when the user is confused about the current config (a plugin/skin/setting suddenly missing or different, or a long futile debugging loop), FIRST call undo_recent to check whether a recent rollback explains it; if so, tell the user exactly which files were rolled back and when. Rollbacks may have happened in another session or via the offline tools, so the user/AI may not have seen them happen.
8. Plugin code: snapshots also include user-plugin CODE files (junction targets under node_modules, e.g. D:\dsh\plugins\*, plus profile-local files like router-global.mjs). A broken plugin EDIT (e.g. "yield* (intermediate value) is not async iterable") can be rolled back even when no config file changed — undo_list rows show the plugin file count.
9. SAFE MODE: when DSH cannot boot at all or a plugin breaks startup, use undo_safe_mode action "on" to disable every user plugin except undo itself, then restart DSH and diagnose; action "off" restores the previous plugin set (restart again). undo_list crash alerts name a concrete last-known-good snapshot to restore (undo_restore mode "id").
10. Dependency sync: when a restore touches package.json / pnpm-lock.yaml, the result reports that node_modules may be out of sync. Re-run undo_restore with sync_deps=true only when the user confirms, because it runs pnpm install --frozen-lockfile.
Note: this system only reverts DSH config/plugin/skin state, not chat history.

## 工具：undo_compact

Garbage-collect orphan blob files (blobs not referenced by any snapshot or message batch) and leftover .tmp files. Frees disk space without touching any live snapshot data.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "dry_run": {
      "type": "boolean",
      "description": "Only report what would be removed without deleting anything (default false)."
    }
  }
}
```

## 工具：undo_diff

Preview the difference between the current config and a snapshot, before restoring it.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "snapshot_id": {
      "type": "string",
      "description": "Snapshot id from undo_list, or \"latest\" for the newest one."
    }
  },
  "required": [
    "snapshot_id"
  ]
}
```

## 工具：undo_doctor

Run a one-click diagnostic of the snapshot store AND the boot preflight (store dirs writable, blob integrity, settings file, snapshot counts, plus the things that stop DSH from booting before any plugin mounts: profile manifest BOM/JSON/shape, dsh.profile.bundles, link: junctions, duplicate loader entry ids, last unfinished boot). With fix=true it repairs what it can (pre-fix manual snapshot first, re-checked afterwards). Use when the user asks to diagnose, check health, or "is my undo snapshots okay", or when DSH failed to start.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "include_fix_hints": {
      "type": "boolean",
      "description": "Include actionable fix hints for any warn/error checks (default true)."
    },
    "fix": {
      "type": "boolean",
      "description": "Repair the fixable problems found by the preflight check (default false). Takes a pre-fix manual snapshot and re-checks the result."
    }
  }
}
```

## 工具：undo_export

Export ALL snapshots (manual + auto) into a portable ZIP archive (default: <snapshot root>/../undo-exports). Use for backup or moving to another machine. Returns the archive path.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {}
}
```

## 工具：undo_import

Import snapshots from a dsh-undo-savepoint export ZIP. Snapshots are restored into the matching store by kind; same-id snapshots are skipped. The user can give you the zip path, or you can ask them to click Import in the snapshot panel.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "path": {
      "type": "string",
      "description": "Absolute path of the export zip file."
    }
  },
  "required": [
    "path"
  ]
}
```

## 工具：undo_list

List all undo snapshots (newest first): id, time, kind (auto/manual/baseline/pre-restore), store (manual/auto), reason, file count, markers (stepped/consumed). Use before undo_restore to pick a target.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {}
}
```

## 工具：undo_message

Roll back the file changes made by a message batch (reverse order): restore files to their before-content, or delete newly-created files. Use after undo_message_list to pick a batch id. Does NOT touch the DSH session store (no public delete API); it only restores the workspace files.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "message_id": {
      "type": "string",
      "description": "Batch id from undo_message_list, or \"latest\" (default) for the most recent batch."
    }
  }
}
```

## 工具：undo_message_list

List recorded message-level file-change batches (most recent first). Each batch = a group of file writes by one AI message or a 60s window. Use before undo_message to pick a batch id.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {}
}
```

## 工具：undo_note

Set or clear a snapshot's note/tags. Useful to annotate a snapshot after creation. Pass note (or note: '' to clear) and/or tags.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "string",
      "description": "Snapshot id."
    },
    "note": {
      "type": "string",
      "description": "New note; empty string clears the note."
    },
    "tags": {
      "type": "array",
      "description": "New tags list; empty array clears the tags.",
      "items": {
        "type": "string"
      }
    }
  }
}
```

## 工具：undo_prune

Delete expired snapshots right now: auto/baseline beyond keepAuto and pre-restore beyond keepPre (respects the autoCleanup setting; manual snapshots are never touched). Use when the user asks to clean up snapshots.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {}
}
```

## 工具：undo_recent

List the most recent rollback operations (undo/redo/restore): time, mode, target snapshot, and WHICH config files were rolled back. Use this when the user is confused about the current config state (e.g. a plugin or setting suddenly missing or different, or a long futile debugging loop) to check whether a recent rollback explains it. Rollbacks may have happened in another session or via the offline tools.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "limit": {
      "type": "string",
      "description": "How many entries to show (default 5, max 20)."
    }
  }
}
```

## 工具：undo_restore

Roll back DSH config to a snapshot. mode "undo" reverts the latest change (undo last action; repeats walk further back); mode "redo" re-applies the state saved before the last undo (only when nothing changed since); mode "id" restores an explicit snapshot from undo_list (restore to a fixed version). The current state is always preserved as a pre-restore snapshot first, and the dsh-undo-savepoint mount itself is re-ensured.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "mode": {
      "type": "string",
      "description": "\"undo\" | \"redo\" | \"id\""
    },
    "snapshot_id": {
      "type": "string",
      "description": "Required when mode is \"id\"."
    },
    "sync_deps": {
      "type": "boolean",
      "description": "After restoring package.json/pnpm-lock.yaml, run pnpm install --frozen-lockfile so node_modules matches the snapshot. Default false: only reports that dependencies may be out of sync."
    }
  },
  "required": [
    "mode"
  ]
}
```

## 工具：undo_safe_mode

Toggle SAFE MODE (v0.3.8): disable ALL user plugins except dsh-undo-savepoint so DSH can always boot even when a plugin broke startup. Entering also neutralizes profile bundles that would fail the boot loader hard check (unresolvable / no dsh.bundle.patch / missing patch file) — the original profile package.json is backed up and fully restored on exit. action "on" enters (auto-snapshots first, backs up cordis.patch.yml), "off" restores the previous plugin set, "status" reports. A DSH restart is required for on/off to take effect.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "action": {
      "type": "string",
      "description": "\"on\" | \"off\" | \"status\""
    }
  },
  "required": [
    "action"
  ]
}
```

## 工具：undo_scan

Scan DSH session files (<home>/sessions/**/session.jsonl.zstd) for health: "ok" (compliant multi-frame layout), "fixable" (single-frame layout violation — the 8/18 crash root cause — or synthetic-closer seq overlap), or "corrupt" (undecodable / invalid header / bad JSON lines). With quarantine=true, fixable files are repaired in place: original is copied to <undo root>/corrupt-quarantine/ and kept as <file>.bak, then recoded to header frame + event frames with triple verification (round-trip text, per-line JSON, re-analysis); corrupt files are only isolated (copied, never touched). Read-only by default.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "quarantine": {
      "type": "boolean",
      "description": "Repair fixable files (backup + recode + verify + replace); corrupt files are isolated only. Default false = read-only scan."
    }
  }
}
```

## 工具：undo_snapshot

Create a MANUAL config snapshot (stored in the manual store, never auto-pruned; e.g. "before installing X", "known-good baseline"). Snapshots are also auto-created on config changes (auto store).

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "reason": {
      "type": "string",
      "description": "Why this snapshot is taken."
    },
    "note": {
      "type": "string",
      "description": "Snapshots have a note (optional)."
    },
    "tags": {
      "type": "array",
      "description": "Tags on this snapshot (optional list).",
      "items": {
        "type": "string"
      }
    }
  }
}
```
