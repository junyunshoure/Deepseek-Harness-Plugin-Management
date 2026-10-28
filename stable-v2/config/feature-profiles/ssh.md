# SSH 远程执行 (ssh)

连接已配置主机，执行命令、传文件与建立隧道。

加载方式：feature_profiles(action="load", id="ssh")；返回 nextOffset 时继续读取。读完后本会话显示该功能原始工具。

按需处理：先判断项目需要此功能，再读取本手册。

以下规范保留原插件要求，包括确认、权限、来源校验、部分结果与错误语义。具体可用工具以当前运行时为准。

## 工具：ssh_cluster

Run one command concurrently across selected SSH hosts; at least one aliases, environment, or tags filter is required.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "command": {
      "type": "string",
      "description": "The shell command to run on every matched host."
    },
    "aliases": {
      "type": "array",
      "description": "Optional alias filter; at least one of aliases, environment, or tags is required.",
      "items": {
        "type": "string"
      }
    },
    "environment": {
      "type": "string",
      "description": "Optional environment filter; at least one selector is required."
    },
    "tags": {
      "type": "array",
      "description": "Optional ALL-tags filter; at least one selector is required.",
      "items": {
        "type": "string"
      }
    },
    "timeoutMs": {
      "type": "integer",
      "description": "Per-host timeout in milliseconds."
    },
    "maxWorkers": {
      "type": "integer",
      "description": "Concurrency cap (default 8)."
    }
  },
  "required": [
    "command"
  ]
}
```

## 工具：ssh_download

Copy a remote FILE from a configured SSH host to this machine (the dsh host). Use this only when the source is on the remote host; files already on this machine are read with the local file tools (read / write / edit), not ssh_download. Directory download is not supported — download files individually.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "alias": {
      "type": "string",
      "description": "Host alias from ssh_list."
    },
    "remotePath": {
      "type": "string",
      "description": "Absolute path of the source file on the remote SSH host."
    },
    "localPath": {
      "type": "string",
      "description": "Absolute destination path on THIS machine (the dsh host)."
    }
  },
  "required": [
    "alias",
    "remotePath",
    "localPath"
  ]
}
```

## 工具：ssh_exec

Execute a shell command on a REMOTE SSH host by alias; the command runs on the remote host, never on this machine. For commands on this machine, use the local bash tool. Prefer combining independent read-only queries into one command.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "alias": {
      "type": "string",
      "description": "Host alias from ssh_list."
    },
    "command": {
      "type": "string",
      "description": "The shell command to run remotely."
    },
    "timeoutMs": {
      "type": "integer",
      "description": "Timeout in milliseconds (default 60000)."
    }
  },
  "required": [
    "alias",
    "command"
  ]
}
```

## 工具：ssh_list

List configured SSH hosts (alias, host, user, auth, environment, tags, description). Use ssh_exec etc. with the alias.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "query": {
      "type": "string",
      "description": "Optional fuzzy match against alias, description, host, and tags."
    }
  }
}
```

## 工具：ssh_tunnel

Manage local port-forward tunnels to a configured SSH host. Start a tunnel to reach a remote internal service (database, web UI, API) through 127.0.0.1 on this machine.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "action": {
      "type": "string",
      "description": "start / list / stop / stop-all.",
      "enum": [
        "start",
        "list",
        "stop",
        "stop-all"
      ]
    },
    "alias": {
      "type": "string",
      "description": "Host alias (required for start, optional for stop-all)."
    },
    "remotePort": {
      "type": "integer",
      "description": "Port on the remote side (required for start)."
    },
    "remoteHost": {
      "type": "string",
      "description": "Remote host to forward to (default 127.0.0.1 — the server itself)."
    },
    "localPort": {
      "type": "integer",
      "description": "Local listening port (default: auto-assigned)."
    },
    "tunnelId": {
      "type": "string",
      "description": "Tunnel id (required for stop)."
    }
  },
  "required": [
    "action"
  ]
}
```

## 工具：ssh_upload

Transfer a file FROM this machine (the dsh host) TO a remote SSH host. Use this only when the file must be copied to the remote host. Files that stay on this machine are handled with the local file tools (read / write / edit), not ssh_upload.

参数 JSON Schema：

```json
{
  "type": "object",
  "properties": {
    "alias": {
      "type": "string",
      "description": "Host alias from ssh_list."
    },
    "localPath": {
      "type": "string",
      "description": "Absolute path of the source file on THIS machine (the dsh host) — not a path on the remote host."
    },
    "remotePath": {
      "type": "string",
      "description": "Absolute destination path on the remote SSH host (parent dirs are created)."
    }
  },
  "required": [
    "alias",
    "localPath",
    "remotePath"
  ]
}
```
