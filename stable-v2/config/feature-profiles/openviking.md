# OpenViking (openviking)

持久资料、经验记忆、共享技能与资源检索。

加载方式：feature_profiles(action="load", id="openviking")；返回 nextOffset 时继续读取。读完后本会话显示该功能原始工具。

常开处理：后台服务保持运行；最小检索/读取入口常驻。

## 可用工具

- mcp__openviking__add_resource：Add a resource to OpenViking.
- mcp__openviking__add_skill：Create, install, or replace an agent skill in OpenViking.
- mcp__openviking__cancel_watch：Cancel a watch task by its target URI (e.g.
- mcp__openviking__download：Get a short-lived URL for downloading the original bytes o…
- mcp__openviking__edit：Replace an exact string with new text in an existing vikin…
- mcp__openviking__find：Fast semantic retrieval without session context.
- mcp__openviking__forget：Permanently delete a viking:// URI from OpenViking.
- mcp__openviking__get_acl：Read a shared resource's full ACL (direct, inherited, effe…
- mcp__openviking__glob：Find viking:// files matching a glob pattern (e.g.
- mcp__openviking__grep：Search content in viking:// files using regex patterns (li…
- mcp__openviking__health：Check whether the OpenViking server is healthy.
- mcp__openviking__list：List one sorted page under a viking:// directory URI.
- mcp__openviking__list_groups：List group IDs that can be granted resource access in the…
- mcp__openviking__list_users：Find users to grant access to in the caller's account.
- mcp__openviking__list_watches：List watch tasks (auto-refresh subscriptions) visible to t…
- mcp__openviking__privacy_resolve：Turn an {{ov_privacy:...}} placeholder into its actual API…
- mcp__openviking__privacy_tree：Find saved API keys, tokens and other private fields for t…
- mcp__openviking__privacy_upsert：Save a credential the user supplies, e.g.
- mcp__openviking__read：Read one or more viking:// file URIs.
- mcp__openviking__remember：Submit information for OpenViking long-term memory extract…
- mcp__openviking__search：Retrieval with optional session context and intent analysis.
- mcp__openviking__set_acl：Set a shared resource's ACL…
- mcp__openviking__tree：Show one visible page from a recursive directory tree.
- mcp__openviking__write：Write text to a viking:// file.

## 完整参数与规范

附录：feature_profiles(action="load", id="openviking.appendix")。参数逐项、JSON Schema 与完整原始规范都在附录，需要精确参数时读它。
