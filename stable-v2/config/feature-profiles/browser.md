# 已登录浏览器 (browser)

操作已连接 Chromium、检查网页、录屏与网络调试。

加载方式：feature_profiles(action="load", id="browser")；返回 nextOffset 时继续读取。读完后本会话显示该功能原始工具。

按需处理：先判断项目需要此功能，再读取本手册。

## 可用工具

- bsk_assist：Display and human-assistance operations.
- bsk_inspect：Inspect page state and explicitly control task-scoped debu…
- bsk_interact：Interact with the active Agent Window tab.
- bsk_page：Navigate and wait on the active Agent Window tab.
- bsk_session：Manage plugin-owned browser sessions.
- bsk_tabs：Manage tabs visible to an owned session.

## 完整参数与规范

附录：feature_profiles(action="load", id="browser.appendix")。参数逐项、JSON Schema 与完整原始规范都在附录，需要精确参数时读它。
