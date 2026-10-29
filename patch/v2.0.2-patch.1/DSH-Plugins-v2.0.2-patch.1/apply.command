#!/usr/bin/env bash
# DSH-Plugins v2.0.2-patch.1 maintenance engine (CL-001 .. CL-007) for macOS / Linux.
# Parity notes:
#   - CL-001/002/003/004/005/006 are implemented.
#   - package.json reference stripping (part of CL-002/003) is Windows-only; on macOS
#     the empty residue directories are removed and you are told what to strip.
#   - CL-007 reports status and prints the export lines; it never writes shell profiles.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_VERSION="v2.0.2-patch.1"
CHECK_ONLY=0
PURGE_LOGS=0
PURGE_DEPRECATED=0
REPAIR_EMPTY=0
LOG_SIZE_MB=100
DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
DEPRECATED=(dsh-my-skill-manager dsh-shared dsh-skill-hub)
LLM_VARS=(LLM_BACKEND LLM_MODEL_NAME LLM_BASE_URL LLM_API_KEY)
STORE="${LOCALAPPDATA:-$HOME/.local/share}/DSHPluginMigration/maintenance-20261029"
BACKUP_DIR=""

for arg in "$@"; do
  case "$arg" in
    --check-only) CHECK_ONLY=1 ;;
    --purge-logs) PURGE_LOGS=1 ;;
    --purge-deprecated) PURGE_DEPRECATED=1 ;;
    --repair-empty) REPAIR_EMPTY=1 ;;
    --dsh-home=*) DSH_HOME="${arg#*=}" ;;
    --log-size-mb=*) LOG_SIZE_MB="${arg#*=}" ;;
    -h|--help)
      cat <<'USAGE'
Usage: ./apply.command [options]
  --check-only        report only, nothing is written
  --purge-logs        delete giant logs of dead processes (CL-006)
  --purge-deprecated  also delete deprecated dirs that still contain files
  --repair-empty      reinstall empty declared dependencies with pnpm (CL-004)
  --dsh-home=PATH     DSH home (default $DSH_HOME or ~/.dsh)
  --log-size-mb=N     CL-006 threshold (default 100)
USAGE
      exit 0 ;;
    *) echo "unknown option: $arg (try --help)"; exit 2 ;;
  esac
done

step() { printf '\n\033[36m%s\033[0m\n' "$1"; }
ok()   { printf '  \033[32m[ok]\033[0m   %s\n' "$1"; }
info() { printf '  [info] %s\n' "$1"; }
warn() { printf '  \033[33m[warn]\033[0m %s\n' "$1"; }
fail() { printf 'FAILED: %s\n' "$1"; exit 1; }
count_files() { find "$1" -type f 2>/dev/null | wc -l | tr -d ' '; }
ensure_backup() {
  [ -n "$BACKUP_DIR" ] && return 0
  BACKUP_DIR="$STORE/backup-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$BACKUP_DIR" || fail "cannot create $BACKUP_DIR"
}

step "[1/7] Package self-check ($PATCH_VERSION)"
[ -f "$HERE/checksums.json" ] || fail "checksums.json missing"
if command -v shasum >/dev/null 2>&1; then SHA="shasum -a 256"; elif command -v sha256sum >/dev/null 2>&1; then SHA="sha256sum"; else fail "no sha256 tool found"; fi
node_bin="$(command -v node || true)"
[ -n "$node_bin" ] || fail "node is required to read checksums.json"
verified=0
while IFS=$'\t' read -r rel want; do
  [ -z "$rel" ] && continue
  f="$HERE/$rel"
  [ -f "$f" ] || fail "missing file: $rel"
  got=$($SHA "$f" | awk '{print $1}')
  [ "$got" = "$want" ] || fail "checksum mismatch: $rel"
  verified=$((verified+1))
done < <("$node_bin" -e '
const j = JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
for (const f of j.files) console.log(f.path + "\t" + f.sha256.toLowerCase());
' "$HERE/checksums.json")
ok "$verified file(s) SHA-256 verified"

step "[2/7] Resolve DSH home and profiles"
[ -d "$DSH_HOME" ] || fail "DSH home not found: $DSH_HOME"
ok "DSH home: $DSH_HOME"
profiles=()
if [ -d "$DSH_HOME/profiles" ]; then
  while IFS= read -r d; do profiles+=("$d"); done < <(find "$DSH_HOME/profiles" -mindepth 1 -maxdepth 1 -type d ! -name '.*' | sort)
fi
if [ ${#profiles[@]} -eq 0 ]; then ok "profiles: (none)"; else ok "profiles: $(basename -a "${profiles[@]}" 2>/dev/null | tr '\n' ' ')"; fi
[ "$CHECK_ONLY" = 1 ] && info "check-only mode: nothing will be written"

step "[3/7] CL-001  ReMe log rotation (00:00 -> 100 MB)"
targets=()
while IFS= read -r f; do targets+=("$f"); done < <(find "$DSH_HOME" -type f -path '*reme/utils/logger_utils.py' 2>/dev/null | sort -u)
if [ ${#targets[@]} -eq 0 ]; then warn "no reme/utils/logger_utils.py found under the DSH home"; fi
for t in "${targets[@]}"; do
  if grep -q 'rotation="100 MB"' "$t"; then ok "already sized-rotation: $t"
  elif grep -q 'rotation="00:00"' "$t"; then
    if [ "$CHECK_ONLY" = 1 ]; then warn "would patch rotation in: $t"
    else
      ensure_backup
      cp -p "$t" "$BACKUP_DIR/logger__$(basename "$t")"
      tmpf="$(mktemp)"
      sed 's/rotation="00:00"/rotation="100 MB"/g' "$t" > "$tmpf" && cat "$tmpf" > "$t" && rm -f "$tmpf"
      grep -q 'rotation="100 MB"' "$t" || fail "post-write check failed: $t"
      ok "patched: $t"
    fi
  else warn "rotation setting not recognised (upstream changed?): $t"; fi
done

step "[4/7] CL-002/003  deprecated residue  +  CL-004  empty bundle directories"
for p in "${profiles[@]}"; do
  pname="$(basename "$p")"
  nm="$p/node_modules"
  [ -d "$nm" ] || continue
  for name in "${DEPRECATED[@]}"; do
    dir="$nm/$name"
    [ -d "$dir" ] || continue
    files=$(count_files "$dir")
    if [ "$files" -le 0 ]; then
      if [ "$CHECK_ONLY" = 1 ]; then warn "would remove empty residue: $dir"
      else rm -rf "$dir" && ok "removed empty residue: $dir"; fi
    elif [ "$PURGE_DEPRECATED" = 1 ]; then
      if [ "$CHECK_ONLY" = 1 ]; then warn "would purge (has files): $dir"
      else rm -rf "$dir" && ok "purged deprecated dir: $dir ($files files)"; fi
    else
      info "kept (has $files files): $dir"
      if grep -q "\"$name\"" "$p/package.json" 2>/dev/null; then
        warn "  $pname/package.json still references $name - remove that dependency line by hand"
      fi
    fi
  done
  if [ -f "$p/package.json" ] && [ -n "$node_bin" ]; then
    while IFS= read -r name; do
      [ -z "$name" ] && continue
      dir="$nm/$name"
      [ -d "$dir" ] || continue
      files=$(count_files "$dir")
      [ "$files" -eq 0 ] || continue
      warn "empty bundle directory: $dir"
      if [ "$REPAIR_EMPTY" = 1 ]; then
        if [ "$CHECK_ONLY" = 1 ]; then warn "would reinstall: $name"
        elif command -v pnpm >/dev/null 2>&1; then
          ( cd "$p" && pnpm add "$name" --prefer-offline ) && ok "reinstall attempted: $name"
        else warn "pnpm not on PATH; run manually: cd $p && pnpm add $name"; fi
      else info "  (pass --repair-empty to reinstall it)"; fi
    done < <("$node_bin" -e '
const fs=require("fs");
try{
  const j=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const out=new Set();
  for (const s of ["dependencies","devDependencies","optionalDependencies"]) {
    if (j[s]) for (const k of Object.keys(j[s])) out.add(k);
  }
  if (j.dsh && Array.isArray(j.dsh.bundles)) for (const b of j.dsh.bundles) out.add(b);
  for (const n of out) console.log(n);
}catch(e){}
' "$p/package.json")
  fi
done

step "[5/7] CL-005  feature-profiles temp files"
tmpcount=0
while IFS= read -r t; do
  [ -z "$t" ] && continue
  tmpcount=$((tmpcount+1))
  if [ "$CHECK_ONLY" = 1 ]; then warn "would delete temp file: $t"
  else rm -f "$t" && ok "deleted temp file: $t"; fi
done < <(find "$DSH_HOME/profiles" -mindepth 3 -maxdepth 3 -type f -path '*/feature-profiles/*.tmp' 2>/dev/null)
[ "$tmpcount" -eq 0 ] && ok "no *.tmp leftovers"

step "[6/7] CL-006  giant logs (threshold ${LOG_SIZE_MB} MB, dead PID only)"
bigcount=0
while IFS= read -r l; do
  [ -z "$l" ] && continue
  bigcount=$((bigcount+1))
  mb=$(( $(wc -c < "$l") / 1048576 ))
  base="$(basename "$l" .log)"
  pidnum=""
  case "$base" in *_[0-9]*) pidnum="${base##*_}" ;; esac
  alive=0
  if [ -n "$pidnum" ] && kill -0 "$pidnum" 2>/dev/null; then alive=1; fi
  if [ "$alive" = 1 ]; then info "live process, kept: $l (${mb} MB, pid $pidnum)"
  elif [ "$PURGE_LOGS" = 1 ]; then
    if [ "$CHECK_ONLY" = 1 ]; then warn "would delete: $l (${mb} MB)"
    else rm -f "$l" && ok "deleted: $l (${mb} MB)"; fi
  else warn "large dead-process log: $l (${mb} MB) -> pass --purge-logs to delete"; fi
done < <(find "$DSH_HOME/services" -type f -name '*.log' -size "+${LOG_SIZE_MB}M" 2>/dev/null)
[ "$bigcount" -eq 0 ] && ok "no log above the threshold"

step "[7/7] CL-007  ReMe memory LLM environment (user scope, values never printed)"
missing=()
for v in "${LLM_VARS[@]}"; do [ -z "${!v:-}" ] && missing+=("$v"); done
if [ ${#missing[@]} -eq 0 ]; then ok "all four LLM_* variables are set in this shell"
else
  warn "not set in this shell: ${missing[*]}"
  info "Add to your shell profile (~/.zshrc or ~/.bashrc), then restart ReMe:"
  info '  export LLM_BACKEND=openai'
  info '  export LLM_MODEL_NAME=<model>'
  info '  export LLM_BASE_URL=https://<your-endpoint>/v1'
  info '  export LLM_API_KEY=<key>'
fi

echo
if [ "$CHECK_ONLY" = 1 ]; then
  printf '\033[33mCHANGE PLAN above - nothing was written.\033[0m\n'
  printf '\033[32mRe-run without --check-only to apply.\033[0m\n'
  exit 0
fi

if [ -n "$BACKUP_DIR" ]; then
  printf '{\n  "capturedAt": "%s",\n  "patch": "%s",\n  "backupDir": "%s"\n}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$PATCH_VERSION" "$BACKUP_DIR" > "$BACKUP_DIR/manifest.json"
fi
mkdir -p "$STORE/runs"
printf '{"completedAt":"%s","patch":"%s","dshHome":"%s","backupDir":"%s"}\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$PATCH_VERSION" "$DSH_HOME" "$BACKUP_DIR" \
  > "$STORE/runs/$(date +%Y%m%d-%H%M%S).json"

echo
printf '\033[32mDONE\033[0m\n'
[ -n "$BACKUP_DIR" ] && echo "Backup store : $BACKUP_DIR"
echo "Report       : $STORE/runs/"
echo "Restart ReMe / DSH after applying CL-001 or CL-007."
