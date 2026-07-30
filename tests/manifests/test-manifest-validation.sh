#!/usr/bin/env bash
# Deterministic manifest validation: every shipped manifest is valid JSON,
# has required keys, and version-keyed manifests match package.json.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit
VER=$(jq -r .version package.json)
EXPECTED_NAME="superbeads"
EXPECTED_MARKETPLACE="superbeads-marketplace"
EXPECTED_REPO="https://github.com/the-inconvenience-store/superbeads"
fail=0
valid_json() {
  if python3 -m json.tool < "$1" >/dev/null 2>&1; then
    echo "JSON OK: $1"
  else
    echo "BAD JSON: $1"; fail=1
  fi
}
ver_match() {
  local v; v=$(jq -r "$2" "$1")
  if [ "$v" = "$VER" ]; then
    echo "VER OK: $1"
  else
    echo "VER MISMATCH: $1 ($v != $VER)"; fail=1
  fi
}
for f in .claude-plugin/plugin.json .codex-plugin/plugin.json .cursor-plugin/plugin.json \
         .kimi-plugin/plugin.json; do
  if [ -f "$f" ]; then
    valid_json "$f"
  else
    echo "MISSING: $f"; fail=1
  fi
done
ver_match .cursor-plugin/plugin.json '.version'
ver_match .kimi-plugin/plugin.json '.version'
jq -e --arg name "$EXPECTED_NAME" '.name==$name' package.json >/dev/null && echo "package name OK" || fail=1
jq -e --arg name "$EXPECTED_NAME" '.name==$name' .claude-plugin/plugin.json >/dev/null && echo "claude name OK" || fail=1
jq -e --arg name "$EXPECTED_NAME" '.name==$name' .codex-plugin/plugin.json >/dev/null && echo "codex name OK" || fail=1
jq -e --arg name "$EXPECTED_NAME" '.name==$name' .cursor-plugin/plugin.json >/dev/null && echo "cursor name OK" || fail=1
jq -e --arg name "$EXPECTED_NAME" '.name==$name' .kimi-plugin/plugin.json >/dev/null && echo "kimi name OK" || fail=1
jq -e --arg repo "$EXPECTED_REPO" '.repository==$repo and .homepage==$repo' .claude-plugin/plugin.json >/dev/null && echo "claude repo OK" || fail=1
jq -e --arg repo "$EXPECTED_REPO" '.repository==$repo and .homepage==$repo' .codex-plugin/plugin.json >/dev/null && echo "codex repo OK" || fail=1
jq -e --arg repo "$EXPECTED_REPO" '.repository==$repo and .homepage==$repo' .cursor-plugin/plugin.json >/dev/null && echo "cursor repo OK" || fail=1
jq -e --arg repo "$EXPECTED_REPO" '.homepage==$repo and .interface.websiteURL==$repo' .kimi-plugin/plugin.json >/dev/null && echo "kimi repo OK" || fail=1
jq -e --arg market "$EXPECTED_MARKETPLACE" --arg name "$EXPECTED_NAME" '.name==$market and .plugins[0].name==$name' .claude-plugin/marketplace.json >/dev/null && echo "claude marketplace name OK" || fail=1
jq -e --arg market "$EXPECTED_MARKETPLACE" --arg name "$EXPECTED_NAME" '.name==$market and .plugins[0].name==$name' .codex-plugin/marketplace.json >/dev/null && echo "codex marketplace name OK" || fail=1
jq -e --arg name "$EXPECTED_NAME" '.name==$name and .plugins[0].name==$name and .interface.displayName==$name' .agents/plugins/marketplace.json >/dev/null && echo "agents marketplace name OK" || fail=1
jq -e '.skills=="./skills/"' .cursor-plugin/plugin.json >/dev/null && echo "cursor skills OK" || fail=1
jq -e 'has("hooks") | not' .cursor-plugin/plugin.json >/dev/null && echo "cursor global hooks absent" || fail=1
jq -e 'has("sessionStart") | not' .kimi-plugin/plugin.json >/dev/null && echo "kimi global sessionStart absent" || fail=1

for f in hooks/hooks.json hooks/codex-hooks.json hooks/hooks-cursor.json; do
  if [ -e "$f" ]; then
    echo "GLOBAL HOOK MANIFEST PRESENT: $f"; fail=1
  else
    echo "GLOBAL HOOK MANIFEST ABSENT: $f"
  fi
done
if grep -qE 'pi\.on\("(session_start|context|session_compact)"' .pi/extensions/superpowers.ts; then
  echo "GLOBAL PI SESSION INJECTION PRESENT"; fail=1
else
  echo "GLOBAL PI SESSION INJECTION ABSENT"
fi
exit $fail
