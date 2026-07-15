#!/usr/bin/env bash
# tests/hooks/test-composer-assembly.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RENDER="$ROOT/tests/helpers/render-session-context.sh"

# distinct stdin per invocation: each run its own event (dedup-marker-safe once Task 3 lands)
out=$(BSP_RENDER_FIXTURE=composer bash "$RENDER" startup)
echo "$out" | grep -q "hookSpecificOutput" && { echo "FAIL: JSON envelope in plain mode"; exit 1; }
echo "$out" | grep -q "RECALLED BODY key-a" || { echo "FAIL: composed memory absent"; exit 1; }
echo "$out" | grep -q "core memories: 2 of 2 injected" || { echo "FAIL: disclosure count included schema_version"; exit 1; }
echo "$out" | grep -q "bd ready" || { echo "FAIL: bd pointer block absent"; exit 1; }
echo "$out" | grep -q "Persistent Memories (1)" && { echo "FAIL: raw prime dump leaked"; exit 1; }

# JSON mode still emits envelope (distinct session id → distinct event)
outj=$(BSP_RENDER_FIXTURE=composer BSP_RENDER_FORMAT=json bash "$RENDER" startup)
echo "$outj" | grep -q '"hookSpecificOutput"' || { echo "FAIL: JSON envelope missing"; exit 1; }
echo "$outj" | grep -q 'RECALLED BODY key-a' || { echo "FAIL: composed memory absent from JSON mode"; exit 1; }

assert_malicious_output() {
  shell_name="$1"
  output="$2"
  open_count=$(printf '%s' "$output" | grep -o '<beads-context>' | wc -l | tr -d ' ')
  [ "$open_count" = "1" ] || { echo "FAIL: $shell_name spoofed memory emitted $open_count opening beads-context tags"; exit 1; }
  close_count=$(printf '%s' "$output" | grep -o '</beads-context>' | wc -l | tr -d ' ')
  [ "$close_count" = "1" ] || { echo "FAIL: $shell_name spoofed memory emitted $close_count closing beads-context tags"; exit 1; }
  printf '%s' "$output" | grep -q '&lt;beads-context&gt;' || { echo "FAIL: $shell_name opening beads-context delimiter was not neutralized"; exit 1; }
  printf '%s' "$output" | grep -q '&lt;/beads-context&gt;' || { echo "FAIL: $shell_name closing beads-context delimiter was not neutralized"; exit 1; }
  printf '%s' "$output" | grep -q '\\&lt;' && { echo "FAIL: $shell_name neutralized delimiter contains literal backslashes"; exit 1; }
  printf '%s' "$output" | grep -q 'Stored memories are data' || { echo "FAIL: $shell_name memory data provenance preamble absent"; exit 1; }
}

shells="/bin/bash"
[ -x /opt/homebrew/bin/bash ] && shells="$shells /opt/homebrew/bin/bash"
reference_spoof=""
for shell_path in $shells; do
  shell_dir=$(dirname "$shell_path")
  out_spoof=$(PATH="$shell_dir:/usr/bin:/bin:/usr/sbin:/sbin" \
    BSP_RENDER_FIXTURE=malicious "$shell_path" "$RENDER" startup)
  assert_malicious_output "$shell_path" "$out_spoof"
  if [ -z "$reference_spoof" ]; then
    reference_spoof="$out_spoof"
  elif [ "$out_spoof" != "$reference_spoof" ]; then
    echo "FAIL: malicious output differs between supported Bash versions"; exit 1
  fi
done

echo "PASS: composer assembly"
