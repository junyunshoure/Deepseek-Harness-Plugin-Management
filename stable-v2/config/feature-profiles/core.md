# 基础执行 (core)

项目文件读写、搜索、命令执行、任务进度、交付与后台作业。

加载方式：feature_profiles(action="load", id="core")；返回 nextOffset 时继续读取。读完后本会话显示该功能原始工具。

常开处理：后台服务保持运行；最小检索/读取入口常驻。

## 可用工具

- ask_user_question：Ask the user a concise question when you need confirmation…
- edit：Edit an existing UTF-8 text file by replacing literal text.
- exit_plan_mode：Use only in plan mode.
- glob：Find files, not directories, whose paths match a glob patt…
- grep：Search file contents with a ripgrep regular expression.
- job_kill：Request cancellation of a running background job.
- job_list：List your background jobs (running and finished) with thei…
- job_output：Read a background job…
- load_workspace_dependencies：Get absolute paths to bundled Python and library directori…
- present：Declare existing files as final deliverables for the user.
- pwsh：Execute a PowerShell command (`pwsh -Command`) and return…
- read：Read a UTF-8 text file and return line-numbered content.
- read_image：Read a PNG/JPEG/WebP/GIF file and return the image itself.
- todo_write：Record and update a task list to plan multi-step work and…
- working_directory：Read the current working directory, or change it with cd.
- write：Create or fully replace a UTF-8 text file.

## 完整参数与规范

附录：feature_profiles(action="load", id="core.appendix")。参数逐项、JSON Schema 与完整原始规范都在附录，需要精确参数时读它。
