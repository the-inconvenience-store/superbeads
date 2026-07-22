#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VALIDATOR="$ROOT/skills/using-superpowers/scripts/validate-memory-candidate.py"
POLICY="$ROOT/skills/using-superpowers/references/session-policy.md"
CURATOR="$ROOT/skills/memory-curator/SKILL.md"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP"
cat >"$TMP/valid.txt" <<'EOF'
Future decision: Preserve resource conflicts as scheduler constraints when reviewing graph edges.
Durable insight: The graph validator previously rewarded fake dependency edges by rejecting independent resource overlap.
Evidence: skills/writing-plans/scripts/validate-graph-plan.py:340 and PASS test-graph-plan-contract.sh.
Invalidated when: The validator and scheduler adopt a different shared conflict model.
Rediscovery cost: Requires reconstructing historical graphs and validator behavior across sessions.
EOF
python3 "$VALIDATOR" "$TMP/valid.txt" | grep -Fq "valid memory candidate"

expect_rejected() {
  local name="$1" reason="$2"
  if python3 "$VALIDATOR" "$TMP/$name.txt" >"$TMP/$name.out" 2>&1; then
    echo "FAIL: $name memory unexpectedly passed" >&2
    exit 1
  fi
  grep -Fqi "$reason" "$TMP/$name.out" || { cat "$TMP/$name.out" >&2; exit 1; }
}

cat >"$TMP/approved.txt" <<'EOF'
Future decision: Continue with implementation.
Durable insight: Design plan accepted and ready for SDD.
Evidence: closed bead beads-superpowers-example.
Invalidated when: Implementation starts.
Rediscovery cost: Read the plan.
EOF
expect_rejected approved "approval or completion episode"

cat >"$TMP/procedure.txt" <<'EOF'
Future decision: Run the same command next time.
Durable insight: Run git pull --rebase before bd close.
Evidence: scripts/example.sh:12.
Invalidated when: The command changes.
Rediscovery cost: Look up the command.
EOF
expect_rejected procedure "procedural recipe"

cat >"$TMP/raw-log.txt" <<'EOF'
Future decision: Investigate later.
Durable insight: FAIL test_one; FAIL test_two; Traceback; panic: failure.
Evidence: PASS reproduction in tests/example.sh.
Invalidated when: Tests pass.
Rediscovery cost: Rerun tests.
EOF
expect_rejected raw-log "raw failure log"

cat >"$TMP/branch.txt" <<'EOF'
Future decision: Resume the next task.
Durable insight: Current branch is feat/example and HEAD is abcdef1; next task is task-2.
Evidence: closed bead beads-superpowers-example.
Invalidated when: The branch changes.
Rediscovery cost: Run git status.
EOF
expect_rejected branch "current execution state"

cat >"$TMP/pointer.txt" <<'EOF'
Future decision: Find the documentation.
Durable insight: The TUI documentation lives in docs/tui.md.
Evidence: docs/tui.md:1.
Invalidated when: The file moves.
Rediscovery cost: Search docs.
EOF
expect_rejected pointer "artifact pointer"

for phrase in "Future decision" "Rediscovery cost" "Invalidated when" \
  "approval" "raw failure" "current branch" "artifact pointer" \
  "validate-memory-candidate.py" "explicit non-mutating offer"; do
  grep -Fqi "$phrase" "$POLICY" "$CURATOR" || {
    echo "FAIL: memory policy lacks $phrase" >&2
    exit 1
  }
done

if grep -Eiq 'juno|seraphim' "$POLICY" "$CURATOR" "$VALIDATOR"; then
  echo "FAIL: project-specific memory mutation leaked into shared capture policy" >&2
  exit 1
fi

echo "PASS: durable-memory capture rejects episodic and procedural noise"
