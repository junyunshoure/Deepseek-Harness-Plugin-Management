#!/bin/bash
# ============================================================================
#  DeepSeek Harness 插件整合包 v2.1.3 —— macOS 本地记忆服务安装向导
#
#  安装对象（都是可选组件，不装 DSH 也能正常用）：
#    ReMe       端口 2333   个人记忆（uv venv + reme-ai）
#    OpenViking 端口 1933   持久资料 / 共享技能（uv tool install openviking）
#    Hindsight  端口 8888   代码库记忆页（uv tool install hindsight-embed）
#    WeKnora    端口 8080   组织知识库（mac 上请用 Docker / 官方 release，本脚本不装）
#
#  用法：
#    ./setup-services.command                  # 交互式，逐个问要不要装
#    ./setup-services.command --yes            # 全部尝试安装（uv 缺失时自动装 uv）
#    ./setup-services.command --only reme      # 只装一个（reme|openviking|hindsight）
#    ./setup-services.command --check          # 只检查端口与已装状态
#
#  只写 ~/.dsh/services 与 uv 自己的目录，不改系统设置。
# ============================================================================
set -euo pipefail

SERVICES_ROOT="$HOME/.dsh/services"
REME_DIR="$SERVICES_ROOT/reme"
REME_PORT=2333
OV_PORT=1933
HS_PORT=8888
WK_PORT=8080

ASSUME_YES=0
CHECK_ONLY=0
ONLY=""

if [ -t 1 ]; then
  C_DIM=$'\033[2m'; C_RED=$'\033[31m'; C_GRN=$'\033[32m'
  C_YEL=$'\033[33m'; C_CYA=$'\033[36m'; C_BLD=$'\033[1m'; C_OFF=$'\033[0m'
else
  C_DIM=''; C_RED=''; C_GRN=''; C_YEL=''; C_CYA=''; C_BLD=''; C_OFF=''
fi

title() { printf '\n%s\n%s  %s\n%s\n' "${C_CYA}──────────────────────────────────────────────────────────────────────${C_OFF}" "${C_BLD}" "$1" "${C_CYA}──────────────────────────────────────────────────────────────────────${C_OFF}"; }
step()  { printf '\n%s▸ %s%s\n' "$C_CYA" "$1" "$C_OFF"; }
ok()    { printf '  %s✔%s %s\n' "$C_GRN" "$C_OFF" "$1"; }
info()  { printf '  %s·%s %s\n' "$C_DIM" "$C_OFF" "$1"; }
warn()  { printf '  %s!%s %s\n' "$C_YEL" "$C_OFF" "$1"; }
bad()   { printf '  %s✘%s %s\n' "$C_RED" "$C_OFF" "$1"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --yes|-y) ASSUME_YES=1; shift ;;
    --check) CHECK_ONLY=1; shift ;;
    --only) ONLY="${2:-}"; shift 2 ;;
    --only=*) ONLY="${1#*=}"; shift ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) warn "忽略未知参数：$1"; shift ;;
  esac
done

ask() {
  local prompt="$1" def="${2:-n}" ans
  if [ "$ASSUME_YES" -eq 1 ]; then printf '%s [自动=是]\n' "$prompt"; return 0; fi
  if [ ! -t 0 ]; then printf '%s [非交互，默认=否]\n' "$prompt"; return 1; fi
  printf '%s [y/N] ' "$prompt"
  read -r ans || true
  case "${ans:-$def}" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

port_code() {
  local port="$1" path="${2:-/}" code
  code="$(curl -s -o /dev/null -m 3 -w '%{http_code}' "http://127.0.0.1:${port}${path}" 2>/dev/null || true)"
  [ -n "$code" ] || code="000"
  printf '%s' "$code"
}

port_listen() {
  local port="$1"
  lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null | awk 'NR==2{print $1" pid="$2}' || true
}

title "DeepSeek Harness 插件整合包 v2.1.3 —— macOS 本地记忆服务"

# ----------------------------------------------------------------------------
step "环境检查"
# ----------------------------------------------------------------------------
info "安装根目录：$SERVICES_ROOT"
case "$(uname -m)" in
  arm64) info "CPU：Apple Silicon（arm64）" ;;
  x86_64) info "CPU：Intel（x86_64）" ;;
  *) info "CPU：$(uname -m)" ;;
esac

export PATH="$HOME/.local/bin:$PATH"
UV_BIN=""
if command -v uv >/dev/null 2>&1; then
  UV_BIN="$(command -v uv)"
  ok "uv：$UV_BIN（$("$UV_BIN" --version 2>/dev/null || echo 版本未知)）"
else
  warn "没找到 uv（本向导用它装 Python 服务，不污染系统 Python）"
  printf '  安装 uv 一条命令：\n'
  printf '    curl -LsSf https://astral.sh/uv/install.sh | sh\n'
  if [ "$CHECK_ONLY" -eq 0 ] && ask "现在就跑这条命令安装 uv 吗？"; then
    if curl -LsSf https://astral.sh/uv/install.sh | sh; then
      export PATH="$HOME/.local/bin:$PATH"
      hash -r 2>/dev/null || true
      UV_BIN="$(command -v uv || true)"
    fi
  fi
  if [ -z "$UV_BIN" ] || [ ! -x "$UV_BIN" ]; then
    bad "uv 仍不可用，服务安装无法继续。"
    printf '补救：手动执行 curl -LsSf https://astral.sh/uv/install.sh | sh，然后重开终端再跑本脚本。\n'
    printf '      已经装过但 PATH 没生效：export PATH="$HOME/.local/bin:$PATH"\n'
    if [ "$CHECK_ONLY" -eq 0 ]; then exit 1; fi
  fi
fi

if [ "$(uname -s)" = "Darwin" ] && ! xcode-select -p >/dev/null 2>&1; then
  warn "没装 Xcode Command Line Tools；个别 Python 包编译需要它"
  info "补装：xcode-select --install"
fi

mkdir -p "$SERVICES_ROOT"

write_start_sh() {
  local target="$1"; shift
  local body="$1"
  {
    printf '#!/bin/bash\n'
    printf '# 由 setup-services.command 生成；直接运行即可前台启动服务\n'
    printf 'set -euo pipefail\n'
    printf '%s\n' "$body"
  } > "$target"
  chmod +x "$target"
}

# 只检查模式：直接跳到端口检查
if [ "$CHECK_ONLY" -eq 1 ]; then
  title "检查结果"
  for pair in "ReMe:$REME_PORT" "OpenViking:$OV_PORT" "Hindsight:$HS_PORT" "WeKnora:$WK_PORT"; do
    name="${pair%%:*}"; port="${pair##*:}"
    listen="$(port_listen "$port")"
    if [ -n "$listen" ]; then
      ok "$name 端口 $port 已监听（$listen，HTTP $(port_code "$port" /)）"
    else
      info "$name 端口 $port 未监听"
    fi
  done
  exit 0
fi

# ----------------------------------------------------------------------------
# ReMe
# ----------------------------------------------------------------------------
if [ -z "$ONLY" ] || [ "$ONLY" = "reme" ]; then
  step "ReMe（个人记忆，端口 $REME_PORT）"
  if ask "安装 ReMe 到 $REME_DIR ？"; then
    mkdir -p "$REME_DIR"
    if [ ! -x "$REME_DIR/.venv/bin/python" ]; then
      info "创建 Python 3.12 虚拟环境：$REME_DIR/.venv"
      if ! "$UV_BIN" venv "$REME_DIR/.venv" --python 3.12; then
        bad "创建虚拟环境失败（第 1 步：uv venv）"
        printf '补救：1) 确认网络能下载 Python：uv python install 3.12；2) 换 Python 版本重试：uv venv "%s/.venv" --python 3.11；\n' "$REME_DIR"
        printf '      3) 仍然失败时用系统 pip：python3 -m pip install --user reme-ai\n'
      fi
    else
      ok "复用已有虚拟环境：$REME_DIR/.venv"
    fi
    if [ -x "$REME_DIR/.venv/bin/python" ]; then
      info "安装 reme-ai 到虚拟环境（第 2 步：uv pip install）"
      if ! "$UV_BIN" pip install --python "$REME_DIR/.venv/bin/python" "reme-ai"; then
        bad "reme-ai 安装失败（第 2 步：uv pip install）"
        printf '补救：1) 用 pip 直接装进同一个虚拟环境：\n'
        printf '        "%s/bin/python" -m pip install reme-ai\n' "$REME_DIR/.venv"
        printf '      2) 换个源再试：\n'
        printf '        "%s" pip install --python "%s/bin/python" -i https://pypi.tuna.tsinghua.edu.cn/simple "reme-ai"\n' "$UV_BIN" "$REME_DIR/.venv"
        printf '      3) 网络问题先确认：curl -sS -o /dev/null -w "%%{http_code}\\n" https://pypi.org/simple/\n'
      else
        ok "reme-ai 已装进 $REME_DIR/.venv"
      fi
    fi

    write_start_sh "$REME_DIR/start.sh" \
'DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$DIR/.venv/bin:$PATH"
if [ -x "$DIR/.venv/bin/reme" ]; then
  exec "$DIR/.venv/bin/reme" start workspace_dir="$DIR/workspace" service.host=127.0.0.1 service.port=2333
fi
exec "$DIR/.venv/bin/python" -m reme start workspace_dir="$DIR/workspace" service.host=127.0.0.1 service.port=2333'
    mkdir -p "$REME_DIR/workspace"
    ok "启动脚本：$REME_DIR/start.sh（前台运行：$REME_DIR/start.sh）"
  else
    info "跳过 ReMe"
  fi
fi

# ----------------------------------------------------------------------------
# OpenViking
# ----------------------------------------------------------------------------
if [ -z "$ONLY" ] || [ "$ONLY" = "openviking" ]; then
  step "OpenViking（持久资料 / 共享技能，端口 $OV_PORT）"
  if ask "安装 OpenViking（uv tool install openviking）？"; then
    if command -v openviking-server >/dev/null 2>&1; then
      ok "已存在：$(command -v openviking-server)"
    elif ! "$UV_BIN" tool install openviking; then
      bad "openviking 安装失败（uv tool install）"
      printf '补救：1) 升级 uv 后重试：uv self update && uv tool install openviking；\n'
      printf '      2) 换源：uv tool install openviking --index-url https://pypi.tuna.tsinghua.edu.cn/simple；\n'
      printf '      3) 看详细报错：uv tool install openviking -v\n'
    else
      ok "openviking 已安装（$("$UV_BIN" tool dir 2>/dev/null || echo "$HOME/.local/share/uv/tools")）"
    fi
    mkdir -p "$SERVICES_ROOT/openviking"
    write_start_sh "$SERVICES_ROOT/openviking/start.sh" \
'export PATH="$HOME/.local/bin:$PATH"
exec openviking-server --host 127.0.0.1 --port 1933'
    ok "启动脚本：$SERVICES_ROOT/openviking/start.sh"
  else
    info "跳过 OpenViking"
  fi
fi

# ----------------------------------------------------------------------------
# Hindsight
# ----------------------------------------------------------------------------
if [ -z "$ONLY" ] || [ "$ONLY" = "hindsight" ]; then
  step "Hindsight（代码库记忆页，端口 $HS_PORT）"
  if ask "安装 Hindsight（uv tool install hindsight-embed）？"; then
    if command -v hindsight-embed >/dev/null 2>&1; then
      ok "已存在：$(command -v hindsight-embed)"
    elif ! "$UV_BIN" tool install hindsight-embed; then
      bad "hindsight-embed 安装失败（uv tool install）"
      printf '补救：1) uv tool install hindsight-embed --verbose 看具体原因；\n'
      printf '      2) 需要编译工具时先装：xcode-select --install；\n'
      printf '      3) 换源：uv tool install hindsight-embed --index-url https://pypi.tuna.tsinghua.edu.cn/simple\n'
    else
      ok "hindsight-embed 已安装"
    fi
    mkdir -p "$SERVICES_ROOT/hindsight"
    write_start_sh "$SERVICES_ROOT/hindsight/start.sh" \
'export PATH="$HOME/.local/bin:$PATH"
exec hindsight-embed daemon start'
    ok "启动脚本：$SERVICES_ROOT/hindsight/start.sh"
  else
    info "跳过 Hindsight"
  fi
fi

# ----------------------------------------------------------------------------
# WeKnora
# ----------------------------------------------------------------------------
step "WeKnora（组织知识库）"
info "mac 上请用 Docker / 官方 release，参考 docs/服务部署指南.md"
printf '  Docker 起法示例：\n'
printf '    docker run -d --name weknora -p 8080:8080 -v weknora-data:/data <weknora 官方镜像>\n'
printf '  端口约定：%s（本脚本不安装、不启动）\n' "$WK_PORT"

# ----------------------------------------------------------------------------
title "端口检查方法（服务启动后执行）"
# ----------------------------------------------------------------------------
printf '  %s2333 ReMe%s\n' "$C_BLD" "$C_OFF"
printf '    curl -s -m 3 http://127.0.0.1:2333/health    # 返回 JSON 即在跑；返回 000 说明没起\n'
printf '    lsof -nP -iTCP:2333 -sTCP:LISTEN\n'
printf '  %s1933 OpenViking%s\n' "$C_BLD" "$C_OFF"
printf '    curl -s -m 3 http://127.0.0.1:1933/health\n'
printf '    lsof -nP -iTCP:1933 -sTCP:LISTEN\n'
printf '  %s8888 Hindsight%s\n' "$C_BLD" "$C_OFF"
printf '    curl -s -m 3 -o /dev/null -w "%%{http_code}\\n" http://127.0.0.1:8888/\n'
printf '    hindsight-embed daemon status\n'
printf '\n  一次看三个端口：\n'
printf '    for p in 2333 1933 8888; do printf "%%s -> " "$p"; curl -s -o /dev/null -m 2 -w "%%{http_code}\\n" "http://127.0.0.1:$p/"; done\n'

printf '\n  %s本次结果%s\n' "$C_BLD" "$C_OFF"
for pair in "ReMe:$REME_PORT" "OpenViking:$OV_PORT" "Hindsight:$HS_PORT"; do
  name="${pair%%:*}"; port="${pair##*:}"
  listen="$(port_listen "$port")"
  if [ -n "$listen" ]; then ok "$name 端口 $port 已在监听（$listen）"; else info "$name 端口 $port 未监听（启动对应 start.sh 后再检查）"; fi
done

printf '\n  %s下一步%s\n' "$C_BLD" "$C_OFF"
printf '    1) 前台启动某个服务：~/.dsh/services/reme/start.sh（Ctrl+C 停止）\n'
printf '    2) 常驻后台：nohup ~/.dsh/services/reme/start.sh > ~/.dsh/services/reme/reme.log 2>&1 &\n'
printf '    3) 回到 DSH：设置 → 记忆/知识库，填对应地址（ReMe 127.0.0.1:2333 / OpenViking 127.0.0.1:1933）\n'
printf '    4) 服务起不来：把本终端最后 20 行连同 ~/.dsh/services/ 对应目录的日志交给 DSH 里的 AI agent\n'
