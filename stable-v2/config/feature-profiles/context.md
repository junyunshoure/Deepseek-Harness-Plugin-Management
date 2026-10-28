# 上下文管理 (context)

长对话压缩、恢复、上下文用量与缓存核对。

加载方式：feature_profiles(action="load", id="context")；返回 nextOffset 时继续读取。读完后本会话显示该功能原始工具。

常开处理：后台服务保持运行；最小检索/读取入口常驻。

## 可用工具

- acp_cache：Prompt-cache reconciliation…
- acp_read_original_image：Read the ORIGINAL full-resolution image of a message whose…
- acp_status：Show context usage and compressible ranges.
- compress：Replace consumed conversation ranges with self-contained s…
- decompress：Restores previously compressed content.
- search_context：Search through compressed block summaries by keyword.

## 完整参数与规范

附录：feature_profiles(action="load", id="context.appendix")。参数逐项、JSON Schema 与完整原始规范都在附录，需要精确参数时读它。
