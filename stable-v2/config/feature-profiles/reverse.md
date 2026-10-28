# IG5 逆向 (reverse)

二进制静态分析、反编译及证据驱动的样本研究。

加载方式：feature_profiles(action="load", id="reverse")；返回 nextOffset 时继续读取。读完后本会话显示该功能原始工具。

按需处理：先判断项目需要此功能，再读取本手册。

## 可用工具

- ig5_close：Close one open target and recycle its worker process.
- ig5_decompile：Decompile one function by EA or exact name.
- ig5_doctor：Self-check the selected IG5 engine/provider.
- ig5_funcs：List functions of an open target, paged…
- ig5_open：Open a binary in the selected static engine and run auto-a…
- ig5_profile：Return IG5 engines, projects, active tools and skills, plu…
- ig5_status：List open IG5 workers and pending remoteExecutions.
- ig5_strings：List strings of an open target with addresses, paged.

## 完整参数与规范

附录：feature_profiles(action="load", id="reverse.appendix")。参数逐项、JSON Schema 与完整原始规范都在附录，需要精确参数时读它。
