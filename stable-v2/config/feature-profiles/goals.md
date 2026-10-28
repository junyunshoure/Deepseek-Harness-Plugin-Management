# 持久目标 (goals)

持续执行较长任务并记录完成条件。

加载方式：feature_profiles(action="load", id="goals")；返回 nextOffset 时继续读取。读完后本会话显示该功能原始工具。

常开处理：后台服务保持运行；最小检索/读取入口常驻。以下完整调用规范按需读取。

以下规范保留原插件要求，包括确认、权限、来源校验、部分结果与错误语义。具体可用工具以当前运行时为准。

## 工具：create_goal

Create a persisted goal that keeps this session working across automatic continuation rounds. Use it when the direct human request is a long-running objective, even if the user did not say "goal"; not for single-turn work.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "objective": {
      "type": "string",
      "description": "The concrete completion objective inferred from the direct human request."
    },
    "max_goal_rounds": {
      "type": "number",
      "description": "Optional positive safe-integer limit on automatic continuation rounds."
    }
  },
  "required": [
    "objective"
  ]
}
```

## 工具：get_goal

Read the current session goal, including the id and revision that update_goal requires.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {}
}
```

## 工具：update_goal

Update the current goal.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "goal_id": {
      "type": "string",
      "description": "Exact id returned by get_goal."
    },
    "revision": {
      "type": "number",
      "description": "Exact positive revision returned by get_goal."
    },
    "action": {
      "type": "string",
      "description": "edit, pause, and resume require a direct top-level human request. complete and blocked are also allowed during an automatic continuation of this goal; blocked is rejected before the configured minimum round count.",
      "enum": [
        "edit",
        "pause",
        "resume",
        "complete",
        "blocked"
      ]
    },
    "objective": {
      "type": "string",
      "description": "Replacement objective; valid only with action edit."
    },
    "max_goal_rounds": {
      "type": "number",
      "description": "Replacement cap; valid only with action edit."
    },
    "blocked_reason": {
      "type": "string",
      "description": "Required only with action blocked: the concrete condition that persisted across rounds and blocks progress."
    }
  },
  "required": [
    "goal_id",
    "revision",
    "action"
  ]
}
```
