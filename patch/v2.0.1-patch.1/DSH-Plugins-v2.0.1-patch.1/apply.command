#!/usr/bin/env bash
# DSH-Plugins v2.0.1-patch.1 :: Alignment Protocol v1.0 (macOS / Linux)
# Usage:  bash apply.command [--check|--uninstall] [--target PATH]
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
PAYLOAD="$DIR/ALIGNMENT-PROTOCOL.md"
TARGET="${DSH_AGENTS_FILE:-$HOME/.dsh/AGENTS.md}"
STORE="$HOME/.dsh/migration/align-protocol-20261029"
MODE="apply"

while [ $# -gt 0 ]; do
  case "$1" in
    --check) MODE="check"; shift ;;
    --uninstall) MODE="uninstall"; shift ;;
    --target) TARGET="$2"; shift 2 ;;
    *) echo "unknown arg: $1"; exit 2 ;;
  esac
done

[ -f "$PAYLOAD" ] || { echo "FAILED: ALIGNMENT-PROTOCOL.md missing"; exit 1; }

TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
BLOCK="$TMPD/block.md"

awk '/<!-- ALIGNMENT_PROTOCOL v1\.0 START/{f=1} f{print} f && /ALIGNMENT_PROTOCOL v1\.0 END -->/{exit}' "$PAYLOAD" > "$TMPD/raw.md"
# strip trailing blank lines
awk 'BEGIN{n=0} /^[[:space:]]*$/{n++; next} {for(i=0;i<n;i++) print ""; n=0; print}' "$TMPD/raw.md" > "$BLOCK"

if [ ! -s "$BLOCK" ]; then echo "FAILED: protocol markers not found"; exit 1; fi
echo "[1/4] protocol block: $(wc -l < "$BLOCK" | tr -d ' ') lines"

mkdir -p "$(dirname "$TARGET")" "$STORE"
[ -f "$TARGET" ] || : > "$TARGET"
BACKUP="$STORE/backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP"
cp "$TARGET" "$BACKUP/AGENTS.md"
echo "[2/4] target: $TARGET (backup: $BACKUP)"

HAS_BLOCK=0
grep -q '<!-- ALIGNMENT_PROTOCOL v1\.0 START' "$TARGET" && HAS_BLOCK=1

if [ "$MODE" = "check" ]; then
  if [ "$HAS_BLOCK" = "1" ]; then echo "[3/4] check: would REPLACE existing block"; else echo "[3/4] check: would APPEND block"; fi
  echo "[4/4] dry run - nothing written."
  exit 0
fi

if [ "$MODE" = "uninstall" ]; then
  if [ "$HAS_BLOCK" = "0" ]; then echo "[3/4] no block present; nothing to remove"; exit 0; fi
  awk '/<!-- ALIGNMENT_PROTOCOL v1\.0 START/{skip=1; next} skip==1{if (index($0,"ALIGNMENT_PROTOCOL v1.0 END -->")>0) skip=0; next} {print}' "$TARGET" > "$TMPD/out.md"
  cp "$TMPD/out.md" "$TARGET"
  echo "[3/4] block removed"
  echo "[4/4] done (backup kept at $BACKUP)"
  exit 0
fi

awk -v blockfile="$BLOCK" '
  BEGIN { while ((getline l < blockfile) > 0) blk[++nb]=l; close(blockfile) }
  /<!-- ALIGNMENT_PROTOCOL v1\.0 START/ {
    skip=1; found=1; for (i=1;i<=nb;i++) print blk[i]; next
  }
  skip==1 { if (index($0,"ALIGNMENT_PROTOCOL v1.0 END -->") > 0) skip=0; next }
  { print }
  END { if (!found) { print ""; for (i=1;i<=nb;i++) print blk[i] } }
' "$TARGET" > "$TMPD/out.md"

cp "$TMPD/out.md" "$TARGET"
if ! grep -q '<!-- ALIGNMENT_PROTOCOL v1\.0 START' "$TARGET"; then echo "FAILED: post-write verification"; exit 1; fi
echo "[3/4] applied (block present, size $(wc -c < "$TARGET" | tr -d ' ') bytes)"
echo "[4/4] done. Takes effect in the NEXT DSH session. Backup: $BACKUP"
