#!/usr/bin/env bash
#
# check-convention-sync.sh — assert duplicated cross-cutting convention blocks
# stay byte-identical across every declared site. To register a convention, add
# its site array plus stable start/end text that brackets the canonical span.
#
# Usage:
#   scripts/check-convention-sync.sh             # verify all sites
#   scripts/check-convention-sync.sh --self-test # prove non-signature drift fails
#
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

CB3_START='After the work is settled, present the Capture gate'
CB3_END='"multiSelect": false'
CB4_START='**Capture what you learned.**'
CB4_END='bd remember "<kind>: <durable, evidence-backed insight>"'
CB5_START='> **bd frugality: bounded output, one round trip.**'
CB5_END='> orientation, brainstorming, session close. Efficiency never erodes a consent gate.'
LTP_SEQ='`bd close` → `bd dolt push` → `git pull --rebase && git push` → `git status`'

CB3_SITES=(
  skills/brainstorming/SKILL.md
  skills/writing-plans/SKILL.md
  skills/stress-test/SKILL.md
  skills/systematic-debugging/SKILL.md
)
CB4_SITES=(
  skills/executing-plans/SKILL.md
  skills/test-driven-development/SKILL.md
  skills/project-init/SKILL.md
  skills/writing-skills/SKILL.md
  skills/subagent-driven-development/SKILL.md
  skills/using-git-worktrees/SKILL.md
  skills/requesting-code-review/SKILL.md
  skills/receiving-code-review/SKILL.md
  skills/research-driven-development/SKILL.md
  skills/getting-up-to-speed/SKILL.md
  skills/finishing-a-development-branch/SKILL.md
  skills/dispatching-parallel-agents/SKILL.md
  skills/document-release/SKILL.md
  skills/write-documentation/SKILL.md
  skills/verification-before-completion/SKILL.md
)
CB5_SITES=(
  skills/subagent-driven-development/SKILL.md
  skills/executing-plans/SKILL.md
  skills/using-git-worktrees/SKILL.md
  skills/project-init/SKILL.md
  skills/getting-up-to-speed/SKILL.md
  skills/writing-plans/SKILL.md
)
LTP_SITES=(
  skills/executing-plans/SKILL.md
  skills/using-superpowers/SKILL.md
  CLAUDE.md
)

FAIL=0

extract_block() {
  local file="$1" start="$2" end="$3"
  awk -v start="$start" -v end="$end" '
    index($0, start) { in_block = 1 }
    in_block { print }
    in_block && index($0, end) { found_end = 1; exit }
    END { if (!in_block || !found_end) exit 2 }
  ' "$file"
}

block_hash() {
  cksum | awk '{print $1 ":" $2}'
}

check_block() {
  local label="$1" start="$2" end="$3"; shift 3
  local canonical_file="$1" canonical canonical_hash file block hash

  if ! canonical=$(extract_block "$canonical_file" "$start" "$end"); then
    echo "DRIFT: [$label] missing canonical block in $canonical_file"
    FAIL=1
    return
  fi
  canonical_hash=$(printf '%s\n' "$canonical" | block_hash)

  for file in "$@"; do
    if [ ! -f "$file" ]; then echo "MISSING FILE: $file"; FAIL=1; continue; fi
    if ! block=$(extract_block "$file" "$start" "$end"); then
      echo "DRIFT: [$label] missing block in $file"
      FAIL=1
      continue
    fi
    hash=$(printf '%s\n' "$block" | block_hash)
    if [ "$hash" != "$canonical_hash" ]; then
      echo "DRIFT: [$label] block differs in $file"
      FAIL=1
    fi
  done
}

check_sequence() {
  local label="$1" seq="$2"; shift 2
  local file
  for file in "$@"; do
    if [ ! -f "$file" ]; then echo "MISSING FILE: $file"; FAIL=1; continue; fi
    if ! grep -qF -- "$seq" "$file"; then
      echo "DRIFT: [$label] missing sequence in $file"
      FAIL=1
    fi
  done
}

self_test() {
  local tmp ok=1
  tmp="$(mktemp -d)"
  cat > "$tmp/canonical.md" <<'EOF'
before
START convention
line one
line two
END convention
after
EOF
  cat > "$tmp/mutated.md" <<'EOF'
before
START convention
line one
line too
END convention
after
EOF
  local c m
  c=$(extract_block "$tmp/canonical.md" "START convention" "END convention" | block_hash) || ok=0
  m=$(extract_block "$tmp/mutated.md" "START convention" "END convention" | block_hash) || ok=0
  if [ "$c" = "$m" ]; then
    echo "self-test FAIL: non-signature line mutation was not detected"
    ok=0
  fi
  rm -rf "$tmp"
  if [ "$ok" -eq 1 ]; then echo "self-test OK: full-block hash catches non-signature drift"; return 0; else return 1; fi
}

if [ "${1:-}" = "--self-test" ]; then
  self_test; exit $?
fi

check_block "CB-3 Capture gate" "$CB3_START" "$CB3_END" "${CB3_SITES[@]}"
check_block "CB-4 memory convention" "$CB4_START" "$CB4_END" "${CB4_SITES[@]}"
check_block "CB-5 bd-frugality" "$CB5_START" "$CB5_END" "${CB5_SITES[@]}"
check_sequence "Land the Plane" "$LTP_SEQ" "${LTP_SITES[@]}"

if [ "$FAIL" -eq 0 ]; then
  echo "convention-sync: OK (canonical blocks hash-match at their sites)"
else
  echo "convention-sync: FAIL (drift above)"
fi
exit "$FAIL"
