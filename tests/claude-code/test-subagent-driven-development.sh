#!/usr/bin/env bash
# Test: subagent-driven-development skill
# Verifies that the skill is loaded and follows correct workflow
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=test-helpers.sh
source "$SCRIPT_DIR/test-helpers.sh"

echo "=== Test: subagent-driven-development skill ==="
echo ""

# Test 1: Verify skill can be loaded
echo "Test 1: Skill loading..."

output=$(run_claude "Describe the current subagent-driven-development skill concisely. Cover: its validated-graph and Context Manifest prerequisites; whether one task reviewer returns both spec-compliance and code-quality verdicts; the CONTRACT_READY/NEEDS_CONTEXT pre-edit handshake; how often the controller reads the graph; how the reviewer treats implementer claims and inspects the diff; what happens after the first and second failed review rounds and whether a third ordinary correction is allowed; task handoff through the task bead and bounded report/review files; required worktree/planning skills; and whether implementation may begin on main without explicit consent." 180)

if assert_contains "$output" "subagent-driven-development\|Subagent-Driven Development\|Subagent Driven" "Skill is recognized"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "validat.*graph\|validated.*graph\|graph plan" "Requires a validated graph"; then
    : # pass
else
    exit 1
fi
if assert_contains "$output" "manifest\|Context Manifest" "Mentions the task manifest"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 2: Verify skill describes the single-reviewer model
echo "Test 2: Single task-reviewer model..."

# Check that Claude identifies a single reviewer returning both verdicts
# Use multiple greps since assert_contains uses basic grep (no -E for alternation)
if echo "$output" | grep -iq "one\|single\|both\|same reviewer\|task reviewer"; then
    echo "  [PASS] Single task reviewer returns both verdicts"
else
    echo "  [FAIL] Single task reviewer returns both verdicts"
    echo "  Expected Claude to indicate one reviewer returns spec + quality verdicts"
    echo "  Output: $output"
    exit 1
fi

echo ""

# Test 3: Verify the pre-edit handshake
echo "Test 3: Pre-edit manifest handshake..."

if assert_contains "$output" "CONTRACT_READY" "Requires CONTRACT_READY before edits"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "NEEDS_CONTEXT\|must not edit\|no edit" "Missing context blocks edits"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 4: Verify plan is read once
echo "Test 4: Plan reading efficiency..."

if assert_contains "$output" "once\|one time\|single" "Read plan once"; then
    : # pass
else
    exit 1
fi

# Accept the range of vocabulary the model uses for "at the start, before the
# per-task loop" ("up front", "first step", "begins" all mean the same thing;
# assert_contains is case-insensitive). The concept is what matters, not the token.
if assert_contains "$output" "Step 1\|begin\|start\|Load Plan\|first\|up.\?front\|outset\|initial\|before dispatch\|dispatch preparation" "Read at beginning"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 5: Verify the task reviewer is skeptical
echo "Test 5: Task reviewer mindset..."

# Accept the range of vocabulary the model uses for an adversarial stance
# ("skeptic" matches skeptical/skepticism; assert_contains is case-insensitive).
if assert_contains "$output" "skeptic\|distrust\|not trust\|don't trust\|unverified\|adversarial\|verify.*independently\|suspicious" "Reviewer is skeptical"; then
    : # pass
else
    exit 1
fi

# The reviewer inspects the actual changes; the skill's task-reviewer-prompt uses
# "diff"/"ground truth" as the object, so accept that vocabulary as well as "code".
if assert_contains "$output" "read.*code\|inspect.*code\|verify.*code\|against.*diff\|the diff\|ground truth" "Reviewer inspects the code/diff"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 6: Verify review loops
echo "Test 6: Review loop requirements..."

if assert_contains "$output" "first\|round 1\|correction" "First failure permits a bounded correction"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "two\|second\|diagnos\|split\|amend" "Second failure requires diagnosis"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "forbid\|must not\|cannot\|disallow\|no third" "Third ordinary correction is forbidden"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 7: Verify the task is handed off via the task bead description
echo "Test 7: Task handoff via task bead..."

if assert_contains "$output" "bd show\|task bead\|bead description\|task description" "Hands off task via task bead description"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "report\|review package\|manifest" "Uses bounded file handoffs for reports/review"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 8: Verify worktree requirement
echo "Test 8: Worktree requirement..."

if assert_contains "$output" "using-git-worktrees\|worktree" "Mentions worktree requirement"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 9: Verify main branch warning
echo "Test 9: Main branch red flag..."

if assert_contains "$output" "worktree\|feature.*branch\|not.*main\|never.*main\|avoid.*main\|don't.*main\|consent\|permission" "Warns against main branch"; then
    : # pass
else
    exit 1
fi

echo ""

echo "=== All subagent-driven-development skill tests passed ==="
