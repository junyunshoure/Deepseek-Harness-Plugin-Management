# 提醒 (schedule)

设置、查询、修改和删除定时提醒。

加载方式：feature_profiles(action="load", id="schedule")；返回 nextOffset 时继续读取。读完后本会话显示该功能原始工具。

按需处理：先判断项目需要此功能，再读取本手册。

## 可用工具

- schedule_create：Create a reminder in the current session that delivers pro…
- schedule_delete：Delete a reminder in the current session, active or inacti…
- schedule_list：List the active reminders in the current session.
- schedule_update：Change a reminder in place, keeping its id.

## 完整参数与规范

附录：feature_profiles(action="load", id="schedule.appendix")。参数逐项、JSON Schema 与完整原始规范都在附录，需要精确参数时读它。
