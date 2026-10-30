#!/bin/bash
# ============================================================================
#  DeepSeek Harness 插件整合包 v2.1.3 —— 在这台 Mac 上重建离线 payload
#
#  先说结论：在 Mac 上装插件不需要这个脚本。
#    · macos/install.command 走的是「网络安装」：用 DSH 自带 Electron 当 node，
#      调 dsh plugin add 从 npm 源装，装出来的依赖天然就是 arm64 / x86_64 的。
#    · 包内的 payload/node_modules 是在作者 Windows x64 机器上装的，里面的原生模块
#      （*.node：sharp / cpu-features / lightningcss / ssh2 …）是 PE 格式的 Windows 二进制，
#      拿到 macOS 上 dlopen 会直接报错，所以 mac 安装器根本不碰它。
#
#  什么时候才需要本脚本：
#    · 目标机器长期无外网，想先在一台 Mac 上把依赖「烘」成 payload 再拷过去；
#    · 想复刻 Windows 包里 payload/ 的目录形状做对照实验。
#
#  用法：
#    ./build-payload-on-mac.command --explain          # 只讲原理与限制（默认）
#    ./build-payload-on-mac.command --build <输出目录>  # 真的构建（需要网络）
#    ./build-payload-on-mac.command --build <输出目录> --app "/Applications/DeepSeek Harness.app"
#
#  限制（重要）：
#    1) *.node 原生模块只能在同平台、同架构使用。Mac 上构建的 payload 只能给 Mac 用；
#       Apple Silicon 与 Intel 之间也不通用（arm64 vs x86_64）。
#    2) 作者本机的 6 个 local-link 插件（dsh-feature-profiles / dsh-memory-fusion /
#       dsh-skill-fusion / dsh-ollama / dsh-purge / @local/dsh-client-ui-workbench）
#       没有 npm 实体，构建时会被剔除；需要它们请按 docs/AI-agent-适配指南.md 在本机重建。
#    3) 构建过程需要网络（pnpm 要下载 tarball）；构建完成后拷到离网机器才不需要网络。
# ============================================================================
set -euo pipefail

SELF="${BASH_SOURCE[0]}"
SELF_DIR="$(cd "$(dirname "$SELF")" && pwd)"
PACK_ROOT="$(cd "$SELF_DIR/.." && pwd)"
CONFIG_DIR="$PACK_ROOT/config"

MODE="explain"
OUT_DIR=""
APP=""

if [ -t 1 ]; then
  C_DIM=$'\033[2m'; C_RED=$'\033[31m'; C_GRN=$'\033[32m'
  C_YEL=$'\033[33m'; C_CYA=$'\033[36m'; C_BLD=$'\033[1m'; C_OFF=$'\033[0m'
else
  C_DIM=''; C_RED=''; C_GRN=''; C_YEL=''; C_CYA=''; C_BLD=''; C_OFF=''
fi
title() { printf '\n%s\n%s  %s\n%s\n' "${C_CYA}──────────────────────────────────────────────────────────────────────${C_OFF}" "${C_BLD}" "$1" "${C_CYA}──────────────────────────────────────────────────────────────────────${C_OFF}"; }
ok()   { printf '  %s✔%s %s\n' "$C_GRN" "$C_OFF" "$1"; }
info() { printf '  %s·%s %s\n' "$C_DIM" "$C_OFF" "$1"; }
warn() { printf '  %s!%s %s\n' "$C_YEL" "$C_OFF" "$1"; }
bad()  { printf '  %s✘%s %s\n' "$C_RED" "$C_OFF" "$1"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --explain) MODE="explain"; shift ;;
    --build) MODE="build"; OUT_DIR="${2:-}"; shift 2 ;;
    --build=*) MODE="build"; OUT_DIR="${1#*=}"; shift ;;
    --app) APP="${2:-}"; shift 2 ;;
    --app=*) APP="${1#*=}"; shift ;;
    -h|--help) sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) warn "忽略未知参数：$1"; shift ;;
  esac
done

explain() {
  title "为什么 Mac 不需要离线 payload"
  cat <<'TXT'
  1) Windows 包里的 payload/node_modules 是用 Windows x64 的 pnpm 装出来的。
     其中带原生二进制的包（sharp、cpu-features、lightningcss-win32-x64-msvc、ssh2 的
     cpu-features 依赖等）是 PE 文件，macOS 的 dyld 无法加载，硬拷过去只会在启动插件时
     报 "mach-o, but wrong architecture" 或 "cannot open shared object"。

  2) macos/install.command 的做法是「现场装」：
       ELECTRON_RUN_AS_NODE=1 "<App>/Contents/MacOS/DeepSeek Harness" \
         --expose-internals "<App>/Contents/Resources/app.asar/dsh/node_modules/\
@deepseek-ai/dsh-desktop-host/lib/cli.js" \
         plugin --profile desktop add --save-exact <包>@<版本>
     dsh 内部用 App 自带的 pnpm 与 Node 运行时下载并链接依赖，平台天然正确，
     而且不需要用户机器上有 Node.js。

  3) 只有在「构建机与目标机都离网」时才值得做离线 payload，
     而这时也必须保证构建机与目标机是同一平台+同一架构。
TXT

  title "可选：离线 payload 构建流程（在 Mac 上执行）"
  cat <<'TXT'
  步骤 1  找 App 与它自带的 pnpm
          APP="/Applications/DeepSeek Harness.app"
          PNPM="$APP/Contents/Resources/runtime/primary-runtime/dependencies/pnpm/bin/pnpm.mjs"

  步骤 2  准备构建目录，剔除 mac 上没有实体的依赖
          BUILD="$HOME/.dsh/build/payload-mac"
          mkdir -p "$BUILD"
          cp <包目录>/config/package.json       "$BUILD/package.json"
          cp <包目录>/config/pnpm-workspace.yaml "$BUILD/pnpm-workspace.yaml"
          # 手工或用编辑器把 package.json 里 link: / file: / git+ / github: 的依赖删掉，
          # 同时删掉 dsh.profile.bundles 里对应的 6 个 local-link 名字。

  步骤 3  用 App 自带 pnpm 装（需要网络）
          cd "$BUILD"
          ELECTRON_RUN_AS_NODE=1 "$APP/Contents/MacOS/DeepSeek Harness" \
            --expose-internals "$PNPM" install --prod

  步骤 4  把结果摆成 payload 形状
          mkdir -p "$BUILD/payload"
          cp -R "$BUILD/node_modules" "$BUILD/payload/node_modules"

  步骤 5  在目标机上使用这份 payload
          ./install.command --offline --payload "$BUILD/payload"

  步骤 6  自检原生模块架构（应该只看到 arm64 或 x86_64，不该出现 PE）
          find "$BUILD/payload/node_modules" -name '*.node' | head -n 20 | \
            xargs -I{} sh -c 'printf "%s  " "{}"; file "{}" | cut -d: -f2-'
TXT

  title "限制清单"
  printf '  · 原生模块（*.node）只在同平台同架构可用：mac 产物不能给 Windows，arm64 不能给 Intel。\n'
  printf '  · 6 个 local-link 插件没有 npm 实体，离线 payload 里必然缺失；要它们请让 AI agent 按\n'
  printf '    docs/AI-agent-适配指南.md 在本机重建。\n'
  printf '  · 构建期必须联网下载 tarball；离线 payload 只是把「装的时候联网」推迟到「构建时联网」。\n'
  printf '  · 用 --offline 装完后仍然要跑一次 App，让 dsh 重新解析 profile 的 bundles 树。\n'
}

# ----------------------------------------------------------------------------
# 构建模式
# ----------------------------------------------------------------------------
if [ "$MODE" = "explain" ]; then
  explain
  printf '\n  想真的构建：%s./build-payload-on-mac.command --build <输出目录>%s\n' "$C_BLD" "$C_OFF"
  exit 0
fi

[ -n "$OUT_DIR" ] || { bad "缺少输出目录"; printf '用法：./build-payload-on-mac.command --build <输出目录>\n'; exit 1; }
case "$OUT_DIR" in
  "~"/*) OUT_DIR="$HOME/${OUT_DIR#\~/}" ;;
esac
mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"

if [ -z "$APP" ]; then
  for cand in "/Applications/DeepSeek Harness.app" "$HOME/Applications/DeepSeek Harness.app"; do
    if [ -d "$cand" ]; then APP="$cand"; break; fi
  done
fi
[ -n "$APP" ] && [ -d "$APP" ] || { bad "找不到 DeepSeek Harness.app（用 --app 指定）"; exit 1; }
APP="$(cd "$APP" && pwd)"
ELECTRON_NODE="$APP/Contents/MacOS/DeepSeek Harness"
DSH_ROOT="$APP/Contents/Resources/app.asar/dsh"
PNPM=""
for cand in \
  "$APP/Contents/Resources/runtime/primary-runtime/dependencies/pnpm/bin/pnpm.mjs" \
  "$APP/Contents/Resources/app.asar.unpacked/runtime/primary-runtime/dependencies/pnpm/bin/pnpm.mjs"; do
  if [ -f "$cand" ]; then PNPM="$cand"; break; fi
done

title "在 Mac 上构建离线 payload"
info "App：$APP"
[ -x "$ELECTRON_NODE" ] || { bad "App 里没有可执行文件：$ELECTRON_NODE"; exit 1; }
if [ -z "$PNPM" ]; then
  bad "找不到 App 自带的 pnpm：$APP/Contents/Resources/runtime/primary-runtime/dependencies/pnpm/bin/pnpm.mjs"
  printf '补救：1) 确认 App 版本是 0.2.x 桌面版；2) 或者在构建机上装 Node 后用 npm/pnpm：\n'
  printf '        npm i -g pnpm && pnpm install --prod\n'
  exit 1
fi
ok "内置 pnpm：$PNPM"
info "输出目录：$OUT_DIR"

BUILD_TMP="$(mktemp -d "${TMPDIR:-/tmp}/dsh-payload-build.XXXXXX")"
cleanup() { rm -rf "$BUILD_TMP" 2>/dev/null || true; }
trap cleanup EXIT

[ -f "$CONFIG_DIR/package.json" ] || { bad "找不到 $CONFIG_DIR/package.json"; exit 1; }
cp "$CONFIG_DIR/package.json" "$BUILD_TMP/package.json"
if [ -f "$CONFIG_DIR/pnpm-workspace.yaml" ]; then
  cp "$CONFIG_DIR/pnpm-workspace.yaml" "$BUILD_TMP/pnpm-workspace.yaml"
fi

info "剔除 link: / file: / git+ / github: 依赖（mac 包内没有对应实体）"
STRIP_JS="$(cat <<'NODEJS'
const fs = require('fs');
const p = process.argv[1];
const j = JSON.parse(fs.readFileSync(p, 'utf8'));
const local = [];
const deps = j.dependencies || {};
for (const [name, spec] of Object.entries(deps)) {
  if (/^(link:|file:|git\+|github:|workspace:)/.test(String(spec))) {
    local.push(name);
    delete deps[name];
  }
}
if (j.dsh && j.dsh.profile && Array.isArray(j.dsh.profile.bundles)) {
  j.dsh.profile.bundles = j.dsh.profile.bundles.filter((n) => !local.includes(n));
}
fs.writeFileSync(p, JSON.stringify(j, null, 2) + '\n');
process.stdout.write(local.join('\n'));
NODEJS
)"
LOCAL_REMOVED="$(ELECTRON_RUN_AS_NODE=1 "$ELECTRON_NODE" -e "$STRIP_JS" "$BUILD_TMP/package.json" 2>/dev/null || true)"
if [ -n "$LOCAL_REMOVED" ]; then
  printf '%s\n' "$LOCAL_REMOVED" | sed 's/^/      - 去掉 /'
else
  info "没有需要剔除的本地依赖"
fi

info "开始安装（需要网络，可能要几分钟）"
set +e
( cd "$BUILD_TMP" && ELECTRON_RUN_AS_NODE=1 "$ELECTRON_NODE" --expose-internals "$PNPM" install --prod )
rc=$?
set -e
if [ $rc -ne 0 ]; then
  bad "pnpm install 失败（退出码 $rc）"
  printf '补救：1) 确认网络能到 npm 源，必要时换镜像：pnpm config set registry https://registry.npmmirror.com\n'
  printf '      2) 单独重跑看完整报错：cd "%s" && ELECTRON_RUN_AS_NODE=1 "%s" --expose-internals "%s" install --prod\n' "$BUILD_TMP" "$ELECTRON_NODE" "$PNPM"
  printf '      3) 只想在 Mac 上正常用插件，就别折腾 payload，直接跑 macos/install.command（网络安装）。\n'
  exit $rc
fi

[ -d "$BUILD_TMP/node_modules" ] || { bad "安装结束但没有 node_modules"; exit 1; }

info "复制到 $OUT_DIR/node_modules（保留符号链接结构）"
rm -rf "$OUT_DIR/node_modules"
cp -R "$BUILD_TMP/node_modules" "$OUT_DIR/node_modules" 2>/dev/null || {
  bad "复制 node_modules 失败（可能是路径过长或磁盘空间不足）"
  printf '补救：用 ditto 再试：ditto "%s/node_modules" "%s/node_modules"\n' "$BUILD_TMP" "$OUT_DIR"
  exit 1
}
cp "$BUILD_TMP/package.json" "$OUT_DIR/package.json"
if [ -f "$BUILD_TMP/pnpm-workspace.yaml" ]; then cp "$BUILD_TMP/pnpm-workspace.yaml" "$OUT_DIR/pnpm-workspace.yaml"; fi

NODE_COUNT="$(find "$OUT_DIR/node_modules" -name '*.node' 2>/dev/null | wc -l | tr -d ' ')"

META_JS="$(cat <<'NODEJS'
const fs = require('fs');
const path = require('path');
const [out, app, arch, count, excluded] = process.argv.slice(1);
const list = String(excluded || '').split('\n').map((s) => s.trim()).filter(Boolean);
const doc = {
  builtAt: new Date().toISOString(),
  builtOn: 'darwin',
  arch: arch,
  app: app,
  nodeModules: path.join(path.dirname(out), 'node_modules'),
  nativeModules: Number(count || 0),
  excludedLocalLink: list,
  note: '原生模块只能在同一平台与架构使用；本 payload 为 ' + arch + ' 构建，不能跨到 Windows 或另一架构。'
};
fs.writeFileSync(out, JSON.stringify(doc, null, 2) + '\n');
NODEJS
)"
ELECTRON_RUN_AS_NODE=1 "$ELECTRON_NODE" -e "$META_JS" \
  "$OUT_DIR/payload-meta.json" "$APP" "$(uname -m)" "${NODE_COUNT:-0}" "$LOCAL_REMOVED" \
  || warn "写 payload-meta.json 失败（不影响 node_modules 本身）"

ok "依赖已写入：$OUT_DIR/node_modules（*.node 共 ${NODE_COUNT:-0} 个）"
ok "元数据：$OUT_DIR/payload-meta.json"
printf '\n  在目标机上装：\n'
printf '    ./install.command --offline --payload "%s"\n' "$OUT_DIR"
printf '  自检原生模块架构：\n'
printf '    find "%s/node_modules" -name "*.node" | head -n 20 | xargs -I{} sh -c "printf \x27%%s  \x27 \x27{}\x27; file \x27{}\x27 | cut -d: -f2-"\n' "$OUT_DIR"
printf '\n  提醒：装完仍然要打开一次 App，让它重新解析 profile 的 bundles 树。\n'
