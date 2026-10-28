# Zotero 文献 (zotero)

按用户要求检索本地文献、注释、附件并导出引用。

加载方式：feature_profiles(action="load", id="zotero")；返回 nextOffset 时继续读取。读完后本会话显示该功能原始工具。

按需处理：先判断项目需要此功能，再读取本手册。

## 可用工具

- zotero_attachment：Resolve a Zotero ref to a usable attachment location…
- zotero_browse：Browse Zotero library structure.
- zotero_changes：See what changed in the Zotero library since a version…
- zotero_children：Explore the child-object graph of one Zotero item or attac…
- zotero_export：Export Zotero items as citations, a bibliography, or trans…
- zotero_get：Read the metadata of one Zotero library item referenced by…
- zotero_retrieve：Gather evidence passages for one Zotero item and rank them…
- zotero_search：Search the user's local Zotero research library for candid…

## 原始规范要点

- zotero:policy（详见附录）

## 完整参数与规范

附录：feature_profiles(action="load", id="zotero.appendix")。参数逐项、JSON Schema 与完整原始规范都在附录，需要精确参数时读它。
