#!/bin/bash
# ============================================================================
#  DeepSeek Harness 插件整合包 v2.1.0 —— macOS 一键安装器（网络安装路线）
#
#  用法：
#    ./install.command                     # 自动找 /Applications/DeepSeek Harness.app
#    ./install.command --app "/路径/DeepSeek Harness.app"
#    DSH_APP="/路径/DeepSeek Harness.app" ./install.command
#    ./install.command --offline           # 用同目录 payload/node_modules（需本机自建）
#    ./install.command --dry-run           # 只做检查，不写任何文件
#    ./install.command --skip-kernel-check # 跳内核版本校验（仅在明确知道原因时用）
#
#  为什么 mac 上走网络安装：
#    包内 payload/node_modules 是 Windows x64 下装出来的，里面的原生模块（.node）
#    在 macOS 上不能加载。所以 mac 走「用 DSH 自带 Electron 当 node 运行时，
#    调官方 dsh plugin 命令从 npm 源逐个安装」，装出来的依赖与本机平台匹配。
#
#  只写 ~/.dsh 与 ~/.agents 下的内容，不改 App 本体，不动系统设置。
# ============================================================================
set -euo pipefail

PACK_ID="dsh-plugins-pack-v2"
PACK_VERSION="2.1.0"
PROFILE_NAME="desktop"
PROFILE_DIR="$HOME/.dsh/profiles/$PROFILE_NAME"
SKILLS_DSH="$HOME/.dsh/skills"
SKILLS_AGENTS="$HOME/.agents/skills"

SELF="${BASH_SOURCE[0]}"
SELF_DIR="$(cd "$(dirname "$SELF")" && pwd)"
PACK_ROOT="$(cd "$SELF_DIR/.." && pwd)"
MIGRATION="$PACK_ROOT/migration.json"
CONFIG_DIR="$PACK_ROOT/config"
PAYLOAD_DIR="$PACK_ROOT/payload"

APP=""
PAYLOAD_OVERRIDE=""
OFFLINE=0
DRY_RUN=0
SKIP_KERNEL=0
STARTED="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR=""
STEP_NO=0
STEP_TOTAL=8
STEP_NAME="初始化"

if [ -t 1 ]; then
  C_DIM=$'\033[2m'; C_RED=$'\033[31m'; C_GRN=$'\033[32m'
  C_YEL=$'\033[33m'; C_CYA=$'\033[36m'; C_BLD=$'\033[1m'; C_OFF=$'\033[0m'
else
  C_DIM=''; C_RED=''; C_GRN=''; C_YEL=''; C_CYA=''; C_BLD=''; C_OFF=''
fi

title() { printf '\n%s\n%s  %s\n%s\n' "${C_CYA}──────────────────────────────────────────────────────────────────────${C_OFF}" "${C_BLD}" "$1" "${C_CYA}──────────────────────────────────────────────────────────────────────${C_OFF}"; }
step()  { STEP_NO=$((STEP_NO + 1)); STEP_NAME="$1"; printf '\n%s[%s/%s] %s%s\n' "$C_CYA" "$STEP_NO" "$STEP_TOTAL" "$1" "$C_OFF"; }
ok()    { printf '  %s✔%s %s\n' "$C_GRN" "$C_OFF" "$1"; }
info()  { printf '  %s·%s %s\n' "$C_DIM" "$C_OFF" "$1"; }
warn()  { printf '  %s!%s %s\n' "$C_YEL" "$C_OFF" "$1"; }
bad()   { printf '  %s✘%s %s\n' "$C_RED" "$C_OFF" "$1"; }

die() {
  printf '\n%s[失败] %s%s\n' "$C_RED" "$1" "$C_OFF"
  if [ -n "${2:-}" ]; then printf '补救：%s\n' "$2"; fi
  printf '现场：第 %s/%s 步「%s」；备份目录：%s\n' "$STEP_NO" "$STEP_TOTAL" "$STEP_NAME" "${BACKUP_DIR:-尚未创建}"
  exit 1
}

cleanup_on_exit() {
  local code=$?
  if [ "$code" -ne 0 ]; then
    printf '\n%s[中断] 第 %s/%s 步「%s」出错，退出码 %s。%s\n' "$C_RED" "$STEP_NO" "$STEP_TOTAL" "$STEP_NAME" "$code" "$C_OFF"
    printf '补救：把上面最后 15 行（含报错行）连同 %s 交给 DSH 里的 AI agent，它能按 docs/AI-agent-适配指南.md 接着修。\n' "$PROFILE_DIR/installation-result-mac.json"
    if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
      printf '回滚：cp -R "%s"/. "%s"/ （只覆盖备份里有的文件），详见 macos/INSTALL-MAC.md。\n' "$BACKUP_DIR" "$PROFILE_DIR"
    fi
  fi
  if [ -n "${TMP_DIR:-}" ] && [ -d "${TMP_DIR:-}" ]; then rm -rf "$TMP_DIR" 2>/dev/null || true; fi
}
trap cleanup_on_exit EXIT

usage() {
  cat <<'USAGE'
DeepSeek Harness 插件整合包 v2.1.0 —— macOS 安装器

  --app <path>           指定 DeepSeek Harness.app（也可用环境变量 DSH_APP）
  --offline              不联网：把同目录 payload/node_modules 复制进 profile（需在本机自建）
  --payload <dir>        指定离线 payload 目录（默认包内 payload/；配合 --offline 用）
  --dry-run              只做检查并列出将要安装的包，不写任何文件
  --skip-kernel-check    跳过 0.2.x 内核版本校验
  --registry <url>       安装时指定 npm 源（也可用环境变量 DSH_NPM_REGISTRY；默认跟随本机/官方配置）
  -h, --help             显示本帮助
USAGE
}

REGISTRY="${DSH_NPM_REGISTRY:-}"
while [ $# -gt 0 ]; do
  case "$1" in
    --app) APP="${2:-}"; shift 2 ;;
    --app=*) APP="${1#*=}"; shift ;;
    --offline) OFFLINE=1; shift ;;
    --payload) PAYLOAD_OVERRIDE="${2:-}"; shift 2 ;;
    --payload=*) PAYLOAD_OVERRIDE="${1#*=}"; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --skip-kernel-check) SKIP_KERNEL=1; shift ;;
    --registry) REGISTRY="${2:-}"; shift 2 ;;
    --registry=*) REGISTRY="${1#*=}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) warn "忽略未知参数：$1"; shift ;;
  esac
done
if [ -n "${DSH_APP:-}" ] && [ -z "$APP" ]; then APP="$DSH_APP"; fi
if [ -n "$PAYLOAD_OVERRIDE" ]; then
  case "$PAYLOAD_OVERRIDE" in
    "~"/*) PAYLOAD_OVERRIDE="$HOME/${PAYLOAD_OVERRIDE#\~/}" ;;
  esac
  [ -d "$PAYLOAD_OVERRIDE" ] || die "指定的 --payload 目录不存在：$PAYLOAD_OVERRIDE" \
    "确认离线 payload 路径；或用 macos/build-payload-on-mac.command --build <目录> 生成一份。"
  PAYLOAD_DIR="$(cd "$PAYLOAD_OVERRIDE" && pwd)"
fi

chmod +x "$SELF" 2>/dev/null || true
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dsh-mac-install.XXXXXX")"
: > "$TMP_DIR/ok.txt"; : > "$TMP_DIR/fail.txt"; : > "$TMP_DIR/skipped.txt"
: > "$TMP_DIR/cfg-copied.txt"; : > "$TMP_DIR/cfg-kept.txt"; : > "$TMP_DIR/cfg-sample.txt"
: > "$TMP_DIR/skills-dsh.txt"; : > "$TMP_DIR/skills-agents.txt"; : > "$TMP_DIR/fp-copied.txt"

title "DeepSeek Harness 插件整合包 v${PACK_VERSION} —— macOS 安装（网络安装路线）"
info "整合包目录：$PACK_ROOT"
info "profile 目录：$PROFILE_DIR"
info "时间：$STARTED"

# ============================================================================
step "定位 DeepSeek Harness.app"
# ============================================================================
if [ -z "$APP" ]; then
  for cand in "/Applications/DeepSeek Harness.app" "$HOME/Applications/DeepSeek Harness.app"; do
    if [ -d "$cand" ]; then APP="$cand"; break; fi
  done
fi

if [ -z "$APP" ] && [ -t 0 ]; then
  warn "没有在 /Applications 里找到 DeepSeek Harness.app"
  printf '请把 App 路径粘贴进来（直接回车 = 放弃）：'
  read -r typed || true
  typed="${typed%\"}"; typed="${typed#\"}"
  typed="${typed% }"
  [ -n "$typed" ] && APP="$typed"
fi

if [ -z "$APP" ] || [ ! -d "$APP" ]; then
  die "找不到 DeepSeek Harness.app（当前值：${APP:-空}）" \
      "先装好 DeepSeek Harness 并启动一次，让它生成 profile；或用 --app \"/Applications/DeepSeek Harness.app\" 指定路径。"
fi

# 允许用户传 App 内部目录
case "$APP" in
  */Contents) APP="$(cd "$APP/.." && pwd)" ;;
esac
APP="$(cd "$APP" && pwd)"

ELECTRON_NODE="$APP/Contents/MacOS/DeepSeek Harness"
DSH_ROOT="$APP/Contents/Resources/app.asar/dsh"
HOST_CLI="$DSH_ROOT/node_modules/@deepseek-ai/dsh-desktop-host/lib/cli.js"
BOOT_PKG="$DSH_ROOT/node_modules/@deepseek-ai/dsh-app-boot/package.json"

[ -x "$ELECTRON_NODE" ] || die "App 里没有可执行文件：$ELECTRON_NODE" \
  "确认 $APP 是完整的 DeepSeek Harness.app（右键显示包内容，Contents/MacOS/ 下应有 DeepSeek Harness）。"

if [ -d "$DSH_ROOT/node_modules" ]; then
  ok "App：$APP"
  info "内核目录：$DSH_ROOT"
else
  # 正常安装里 app.asar 是单个文件，Shell 看不到里面的目录；Electron 能读，交给下一步验证。
  ok "App：$APP"
  info "内核目录：$DSH_ROOT（在 app.asar 内，由 Electron 读取，Shell 看不到目录属正常）"
fi

# ============================================================================
step "读取内核版本（要求 0.2.x）"
# ============================================================================
READ_VERSION_JS='const fs=require("fs");try{const j=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));process.stdout.write(String(j.version||""))}catch(e){process.exit(3)}'
KERNEL_VERSION="$(ELECTRON_RUN_AS_NODE=1 "$ELECTRON_NODE" -e "$READ_VERSION_JS" "$BOOT_PKG" 2>/dev/null || true)"

if [ -z "$KERNEL_VERSION" ]; then
  if [ "$SKIP_KERNEL" -eq 1 ]; then
    warn "读不到内核版本（已按 --skip-kernel-check 继续）。"
    info "原因通常是 App 版本结构不同，或 app.asar 被改动过。"
  else
    die "读不到内核版本：$BOOT_PKG" \
        "1) 打开 App 看「关于」，确认是 0.2.x 桌面版；2) 更新/重装 DeepSeek Harness 后再跑；3) 确认确实要跳过校验时加 --skip-kernel-check。"
  fi
else
  case "$KERNEL_VERSION" in
    0.2.*) ok "内核版本：$KERNEL_VERSION（符合 0.2.x）" ;;
    *)
      die "内核版本是 $KERNEL_VERSION，本整合包只适配 0.2.x（major.minor = 0.2）。" \
          "1) 升级或降级 DeepSeek Harness 到 0.2.x 桌面版后重跑；2) 想强行在别的内核上装，交给 AI agent 按 docs/AI-agent-适配指南.md 适配。"
      ;;
  esac
fi

[ -x "$ELECTRON_NODE" ] || die "Electron 运行时不可用。" "重新安装 App。"
if [ "$SKIP_KERNEL" -eq 1 ]; then
  info "已确认可执行 CLI：$HOST_CLI"
fi

# 统计文件里的非空行数；文件不存在时输出 0。
# 不用 grep -c：文件缺失时它只往 stderr 抱怨、stdout 为空，汇总数字会变成空白。
count_lines() {
  if [ -f "$1" ]; then
    wc -l < "$1" | tr -d ' '
  else
    printf '0'
  fi
}

# ============================================================================
step "解析迁移清单 migration.json"
# ============================================================================
[ -f "$MIGRATION" ] || die "整合包里没有 migration.json：$MIGRATION" \
  "用 7-Zip 或系统「归档实用工具」完整解压压缩包后再跑（不要在压缩包内双击运行）。"

LIST_JS='const fs=require("fs");const j=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));const want=process.argv[2];for(const p of (j.packages||[])){if(p.install===false)continue;if(p.kind===want)console.log(p.name+"@"+p.version)}'
ELECTRON_RUN_AS_NODE=1 "$ELECTRON_NODE" -e "$LIST_JS" "$MIGRATION" registry > "$TMP_DIR/registry.txt" 2>/dev/null \
  || die "读不出 migration.json 里的 registry 包清单。" "确认文件完整；或把 migration.json 贴给 AI agent 重新生成清单。"
ELECTRON_RUN_AS_NODE=1 "$ELECTRON_NODE" -e "$LIST_JS" "$MIGRATION" local-link > "$TMP_DIR/locallink.txt" 2>/dev/null \
  || die "读不出 migration.json 里的 local-link 包清单。" "确认文件完整。"

REG_COUNT="$(count_lines "$TMP_DIR/registry.txt")"
LINK_COUNT="$(count_lines "$TMP_DIR/locallink.txt")"
ok "需要联网安装的 registry 包：${REG_COUNT} 个"
info "作者本机 local-link 包：${LINK_COUNT} 个（mac 上跳过，见第 5 步说明）"

if [ "$OFFLINE" -eq 1 ] && [ ! -d "$PAYLOAD_DIR/node_modules" ]; then
  die "指定了 --offline，但包里没有 payload/node_modules。" \
      "改用网络安装（去掉 --offline）；或用 macos/build-payload-on-mac.command 在这台 Mac 上先自建 payload。"
fi

if [ "$DRY_RUN" -eq 1 ]; then
  info "dry-run：以下包会被安装（不执行 pnpm，不写文件）"
  sed 's/^/    - /' "$TMP_DIR/registry.txt"
  printf '\n%s检查通过。去掉 --dry-run 即开始真正安装。%s\n' "$C_GRN" "$C_OFF"
  exit 0
fi

# ============================================================================
step "初始化 profile 并备份现有文件"
# ============================================================================
if [ ! -d "$PROFILE_DIR" ]; then
  warn "profile 还不存在：$PROFILE_DIR"
  info "先让 DSH 初始化一次（打开 App 一次即可）；安装器也会创建目录，随后由 dsh plugin 命令补齐。"
  mkdir -p "$PROFILE_DIR"
fi

BACKUP_DIR="$PROFILE_DIR/backups/mac-$TS"
mkdir -p "$BACKUP_DIR"
for f in package.json pnpm-lock.yaml pnpm-workspace.yaml cordis.yml cordis.patch.yml; do
  if [ -f "$PROFILE_DIR/$f" ]; then
    cp -p "$PROFILE_DIR/$f" "$BACKUP_DIR/$f"
    info "已备份 $f"
  fi
done
ok "备份目录：$BACKUP_DIR"

if [ "$OFFLINE" -eq 1 ]; then
  info "离线模式：把 payload/node_modules 复制进 profile（原生模块必须与本机平台一致）"
  mkdir -p "$PROFILE_DIR/node_modules"
  cp -R "$PAYLOAD_DIR/node_modules/." "$PROFILE_DIR/node_modules/" 2>/dev/null \
    || die "复制 payload/node_modules 失败。" "确认包已完整解压；磁盘空间是否够。"
  ok "离线 payload 已复制（如出现 dlopen / mach-o 架构错误，说明这份 payload 不是在本机构建的）"
fi

# ============================================================================
step "写入配置文件（已存在则保留原文件，另存 .pack-sample）"
# ============================================================================
copy_config() {
  local name="$1" src="$CONFIG_DIR/$1" dst="$PROFILE_DIR/$1"
  if [ ! -f "$src" ]; then
    warn "包内缺少 config/$name（跳过，不影响插件安装）"
    return 0
  fi
  if [ -f "$dst" ]; then
    cp "$src" "$dst.pack-sample"
    printf '%s\n' "$name" >> "$TMP_DIR/cfg-kept.txt"
    info "保留原 $name，样例存为 $name.pack-sample"
  else
    cp "$src" "$dst"
    printf '%s\n' "$name" >> "$TMP_DIR/cfg-copied.txt"
    info "已写入 $name"
  fi
}
copy_config cordis.yml
copy_config cordis.patch.yml
copy_config pnpm-workspace.yaml
ok "配置处理完成（已写入 $(count_lines "$TMP_DIR/cfg-copied.txt") 个，保留原有 $(count_lines "$TMP_DIR/cfg-kept.txt") 个）"

# ============================================================================
step "联网安装 registry 插件（dsh plugin add）"
# ============================================================================
if [ "$REG_COUNT" -eq 0 ]; then
  info "清单里没有 registry 包，跳过。"
else
  info "正在用 App 自带 Electron 当 node 运行时，逐个执行："
  printf '    %s\n' "dsh plugin --profile ${PROFILE_NAME} add --save-exact <包>@<版本>"
  if [ -n "$REGISTRY" ]; then info "npm 源：$REGISTRY"; else info "npm 源：跟随本机 pnpm / npm 配置"; fi
  info "日志：$BACKUP_DIR/plugin-install.log（单个包失败不影响后面的包）"
  : > "$BACKUP_DIR/plugin-install.log"

  OK_N=0; FAIL_N=0
  while IFS= read -r spec; do
    [ -z "$spec" ] && continue
    printf '  %s→%s %-52s ' "$C_DIM" "$C_OFF" "$spec"
    set +e
    if [ -n "$REGISTRY" ]; then
      ELECTRON_RUN_AS_NODE=1 "$ELECTRON_NODE" --expose-internals "$HOST_CLI" \
        plugin --profile "$PROFILE_NAME" add --save-exact "$spec" --registry "$REGISTRY" \
        >> "$BACKUP_DIR/plugin-install.log" 2>&1
    else
      ELECTRON_RUN_AS_NODE=1 "$ELECTRON_NODE" --expose-internals "$HOST_CLI" \
        plugin --profile "$PROFILE_NAME" add --save-exact "$spec" \
        >> "$BACKUP_DIR/plugin-install.log" 2>&1
    fi
    rc=$?
    set -e
    if [ $rc -eq 0 ]; then
      printf '%s✔%s\n' "$C_GRN" "$C_OFF"
      printf '%s\n' "$spec" >> "$TMP_DIR/ok.txt"
      OK_N=$((OK_N + 1))
    else
      printf '%s✘ (exit %s)%s\n' "$C_RED" "$rc" "$C_OFF"
      printf '%s\n' "$spec" >> "$TMP_DIR/fail.txt"
      FAIL_N=$((FAIL_N + 1))
    fi
  done < "$TMP_DIR/registry.txt"

  ok "装好 ${OK_N} 个，失败 ${FAIL_N} 个"
  if [ "$FAIL_N" -gt 0 ]; then
    warn "失败清单："
    sed 's/^/      - /' "$TMP_DIR/fail.txt"
    printf '    补救 1：确认能访问 npm 源（公司网络常见需要镜像）——\n'
    printf '            ./install.command --registry https://registry.npmmirror.com\n'
    printf '    补救 2：单个包单独重试（已装好的不会重复下载）：\n'
    printf '            ELECTRON_RUN_AS_NODE=1 "%s" --expose-internals "%s" plugin --profile %s add --save-exact <包>@<版本>\n' "$ELECTRON_NODE" "$HOST_CLI" "$PROFILE_NAME"
    printf '    补救 3：看日志最后几行定位原因：tail -n 40 "%s"\n' "$BACKUP_DIR/plugin-install.log"
  fi
fi

# local-link：作者本机插件，mac 包内没有实体
if [ "$LINK_COUNT" -gt 0 ]; then
  printf '\n'
  info "以下 ${LINK_COUNT} 个插件是作者本机插件，mac 包里没有实体文件，本次跳过："
  while IFS= read -r spec; do
    [ -z "$spec" ] && continue
    printf '%s\n' "$spec" >> "$TMP_DIR/skipped.txt"
  done < "$TMP_DIR/locallink.txt"
  sed 's/^/      - /' "$TMP_DIR/locallink.txt"
  printf '    说明：dsh-feature-profiles / dsh-memory-fusion / dsh-skill-fusion / dsh-ollama / dsh-purge / @local/dsh-client-ui-workbench\n'
  printf '    这些插件是作者本机插件，mac 上跳过；如需可用，请让 DSH 里的 AI agent 按 docs/AI-agent-适配指南.md 在本机重建。\n'
fi

# ============================================================================
step "安装技能与功能说明"
# ============================================================================
install_skills() {
  local src_root="$1" dst_root="$2" tier="$3"
  local n=0
  [ -d "$src_root" ] || { warn "包内没有 payload/skills/$tier，跳过"; return 0; }
  mkdir -p "$dst_root"
  for src in "$src_root"/*; do
    [ -e "$src" ] || continue
    local name; name="$(basename "$src")"
    if [ -e "$dst_root/$name" ]; then
      mkdir -p "$BACKUP_DIR/skills/$tier"
      rm -rf "$BACKUP_DIR/skills/$tier/$name"
      cp -R "$src" "$BACKUP_DIR/skills/$tier/$name"
      rm -rf "$dst_root/$name"
      info "$tier/$name：旧版已备份到 backups/mac-$TS/skills/$tier，随后覆盖"
    fi
    cp -R "$src" "$dst_root/$name"
    printf '%s\n' "$name" >> "$TMP_DIR/skills-$tier.txt"
    n=$((n + 1))
  done
  ok "$tier 技能：$dst_root（$n 个）"
}
install_skills "$PAYLOAD_DIR/skills/dsh" "$SKILLS_DSH" dsh
install_skills "$PAYLOAD_DIR/skills/agents" "$SKILLS_AGENTS" agents

FP_SRC="$CONFIG_DIR/feature-profiles"
FP_DST="$PROFILE_DIR/feature-profiles"
if [ -d "$FP_SRC" ]; then
  mkdir -p "$FP_DST"
  fp_new=0; fp_keep=0
  for src in "$FP_SRC"/*; do
    [ -e "$src" ] || continue
    name="$(basename "$src")"
    if [ -e "$FP_DST/$name" ]; then
      fp_keep=$((fp_keep + 1))
      continue
    fi
    cp -R "$src" "$FP_DST/$name"
    printf '%s\n' "$name" >> "$TMP_DIR/fp-copied.txt"
    fp_new=$((fp_new + 1))
  done
  ok "功能说明：新增 $fp_new 个，已存在保留 $fp_keep 个（$FP_DST）"
else
  warn "包内没有 config/feature-profiles，跳过"
fi

# ============================================================================
step "汇总并写入 installation-result-mac.json"
# ============================================================================
RESULT_JSON="$PROFILE_DIR/installation-result-mac.json"
JSON_GEN="$(cat <<'NODEJS'
const fs = require('fs');
const path = require('path');
const a = process.argv.slice(1);
const tmp = a[0], out = a[1], app = a[2], kernel = a[3], backup = a[4], started = a[5], okN = a[6], failN = a[7];
const list = (n) => { try { return fs.readFileSync(path.join(tmp, n), 'utf8').split('\n').map(s => s.trim()).filter(Boolean); } catch (e) { return []; } };
const doc = {
  pack: { id: 'dsh-plugins-pack-v2', version: '2.1.0', channel: 'stable-v2' },
  installer: 'macos/install.command',
  route: 'network',
  platform: 'darwin',
  appPath: app,
  kernelVersion: kernel,
  profileDir: path.join(process.env.HOME || '', '.dsh', 'profiles', 'desktop'),
  startedAt: started,
  finishedAt: new Date().toISOString(),
  backupDir: backup,
  packages: {
    requested: Number(okN) + Number(failN),
    installed: list('ok.txt'),
    failed: list('fail.txt'),
    skippedLocalLink: list('skipped.txt')
  },
  config: { copied: list('cfg-copied.txt'), keptOriginal: list('cfg-kept.txt') },
  skills: { dsh: list('skills-dsh.txt'), agents: list('skills-agents.txt'), backupDir: path.join(backup, 'skills') },
  featureProfiles: { copied: list('fp-copied.txt') },
  services: {
    installed: false,
    installer: 'macos/setup-services.command',
    note: 'ReMe 2333 / OpenViking 1933 / Hindsight 8888 需单独安装；WeKnora 用 Docker 或官方 release。'
  },
  nextSteps: [
    '打开 DeepSeek Harness（首次启动会加载新插件）',
    '在设置里填中转站地址与密钥',
    '需要本地记忆服务：跑 macos/setup-services.command',
    '插件没出现在侧边栏：见 macos/INSTALL-MAC.md 的常见问题',
    '要回滚：用 backupDir 覆盖回 profile'
  ]
};
fs.writeFileSync(out, JSON.stringify(doc, null, 2) + '\n');
process.stdout.write(out);
NODEJS
)"
ELECTRON_RUN_AS_NODE=1 "$ELECTRON_NODE" -e "$JSON_GEN" \
  "$TMP_DIR" "$RESULT_JSON" "$APP" "${KERNEL_VERSION:-unknown}" "$BACKUP_DIR" "$STARTED" \
  "$(count_lines "$TMP_DIR/ok.txt")" "$(count_lines "$TMP_DIR/fail.txt")" \
  >/dev/null 2>&1 || warn "写入 $RESULT_JSON 失败（可手动补一份，内容见本脚本第 8 步）"
if [ -f "$RESULT_JSON" ]; then ok "结果文件：$RESULT_JSON"; fi

OK_FINAL="$(count_lines "$TMP_DIR/ok.txt")"
FAIL_FINAL="$(count_lines "$TMP_DIR/fail.txt")"
SKIP_FINAL="$(count_lines "$TMP_DIR/skipped.txt")"

title "安装结束"
printf '  装好插件：%s 个\n' "$OK_FINAL"
printf '  失败插件：%s 个\n' "$FAIL_FINAL"
printf '  跳过插件：%s 个（作者本机 local-link）\n' "$SKIP_FINAL"
printf '  备份位置：%s\n' "$BACKUP_DIR"
printf '  结果文件：%s\n' "$RESULT_JSON"
printf '\n  %s下一步%s\n' "$C_BLD" "$C_OFF"
printf '    1) 打开 DeepSeek Harness.app（第一次启动稍慢，插件在加载）\n'
printf '    2) 设置里填中转站地址与密钥，然后重启一次 App\n'
printf '    3) 要本地记忆服务：./setup-services.command（ReMe 2333 / OpenViking 1933 / Hindsight 8888）\n'
printf '    4) 插件没出现 / 想回滚：看 macos/INSTALL-MAC.md\n'

if [ "$FAIL_FINAL" -gt 0 ]; then
  printf '\n  %s有 %s 个插件没装上%s：把 %s 连同上面失败清单交给 DSH 里的 AI agent，按 docs/AI-agent-适配指南.md 逐个补齐。\n' \
    "$C_YEL" "$FAIL_FINAL" "$C_OFF" "$RESULT_JSON"
  exit 2
fi

printf '\n  %s全部完成。%s\n' "$C_GRN" "$C_OFF"
exit 0
