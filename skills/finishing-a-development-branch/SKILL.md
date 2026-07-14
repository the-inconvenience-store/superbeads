---
name: finishing-a-development-branch
description: Use when implementation is complete, all tests pass, and you need to decide how to integrate the work - guides completion of development work by presenting structured options for merge, PR, or cleanup
---

# Finishing a Development Branch

## Overview

Guide completion of development work by presenting clear options and handling chosen workflow.

**Core principle:** Verify code and required outcomes → state readiness precisely → present safe integration options → execute the user's choice.

**Announce at start:** "I'm using the finishing-a-development-branch skill to complete this work."

## The Process

### Step 1: Verify Code and Acceptance

**Before presenting options, verify tests pass:**

```bash
# Run project's test suite
npm test / cargo test / pytest / go test ./...
```

**If tests fail:**
```
Tests failing (<N> failures). Must fix before completing:

[Show failures]

Cannot proceed with merge/PR until tests pass.
```

Stop. Don't proceed to Step 2.

**If tests pass:** Run pre-merge checklist:

```bash
# Check for duplicate beads (clean up before merge)
bd find-duplicates
```

If `bd find-duplicates` reports issues, fix them before proceeding. Then continue to Step 2.

A green suite is necessary but not sufficient. Discover the spec/epic's outcome
trace and acceptance gate, then use `verification-before-completion` to verify
every required acceptance ID on the final relevant commit/environment.

Classify readiness precisely:

| Status | Meaning | Allowed next action |
|---|---|---|
| `READY_FOR_CODE_REVIEW` | Build/tests/reviews green; required product acceptance is blocked or not run | Draft PR or keep branch; no merge/epic close |
| `READY_FOR_ACCEPTANCE` | Code checks green and environment ready; outcome suite still needs to run | Run acceptance; draft PR only if requested |
| `ACCEPTANCE_PASSED` | Every required acceptance ID has matching fresh PASS evidence | Merge/PR options may be presented |

If no formal outcome trace exists, re-read the user request/spec line by line
and build the requirement checklist now. Do not equate its absence with no
acceptance obligations.

Do not merge if a requirement was dropped, a required evidence class is
`FAIL`, `BLOCKED`, or `NOT_RUN`, or a security regression remains. CI, static
review, conformance, direct API checks, and browser/live evidence are not
interchangeable.

### Step 2: Detect Environment

Run the following to determine the git context:

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
IS_WORKTREE=$( [ "$GIT_DIR" != "$GIT_COMMON" ] && echo "yes" || echo "no" )
IS_DETACHED=$( git symbolic-ref HEAD >/dev/null 2>&1 && echo "no" || echo "yes" )
```

| Context | Detection | Menu |
|---------|-----------|------|
| Normal repo | `git rev-parse --git-dir` equals `git rev-parse --git-common-dir`, and `git symbolic-ref HEAD` succeeds | Full 4 options |
| Named-branch worktree | `git rev-parse --git-dir` differs from `git rev-parse --git-common-dir`, and `git symbolic-ref HEAD` succeeds | Full 4 options |
| Detached HEAD | `git symbolic-ref HEAD` fails (exit code 128) | Reduced 3 options (no "Merge locally") |

### Step 3: Determine Base Branch

```bash
# Try common base branches
git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null
```

Or ask: "This branch split from main - is that correct?"

### Step 4: Present Options

**Use your structured question tool** to present options. Do NOT present choices as plain prose when your harness has a question tool; without one, numbered list + STOP. A skipped, dismissed, or auto-resolved answer is not consent — stop and ask in plain text.

If status is `READY_FOR_CODE_REVIEW` or `READY_FOR_ACCEPTANCE`, do not offer
local merge. Offer Draft PR, Keep as-is, or Discard, and state the unsatisfied
acceptance IDs. A user may request a draft PR before acceptance; that does not
close the acceptance gate or epic.

```json
{
  "questions": [{
    "question": "Code checks passed, but product acceptance is <STATUS>. Unmet IDs: <IDS>. What should I do with the branch?",
    "header": "Branch action",
    "options": [
      {"label": "Open draft PR", "description": "Push and open a draft PR labelled with the blocked/not-run acceptance; do not merge or close the gate"},
      {"label": "Keep as-is", "description": "Leave the branch/worktree in place for acceptance or follow-up work"},
      {"label": "Discard", "description": "Delete this work after a separate typed confirmation"}
    ],
    "multiSelect": false
  }]
}
```

**When status is `ACCEPTANCE_PASSED`, for normal repo or named-branch worktree** (`IS_DETACHED=no`), present all 4 options:

```json
{
  "questions": [{
    "question": "Implementation complete. How would you like to finish this branch?",
    "header": "Branch",
    "options": [
      {
        "label": "Merge locally",
        "description": "Merge back to <base-branch>, run tests on result, delete feature branch"
      },
      {
        "label": "Create Pull Request",
        "description": "Push branch to origin and open a PR via gh cli"
      },
      {
        "label": "Keep as-is",
        "description": "Leave the branch and worktree intact — handle it later"
      },
      {
        "label": "Discard work",
        "description": "Permanently delete this branch and all its commits (requires confirmation)"
      }
    ],
    "multiSelect": false
  }]
}
```

**For detached HEAD** (`IS_DETACHED=yes`), present 3 options (omit "Merge locally"):

```json
{
  "questions": [{
    "question": "Implementation complete. How would you like to finish this work?",
    "header": "Branch",
    "options": [
      {
        "label": "Create Pull Request",
        "description": "Push branch to origin and open a PR via gh cli"
      },
      {
        "label": "Keep as-is",
        "description": "Leave the worktree intact — handle it later"
      },
      {
        "label": "Discard work",
        "description": "Permanently delete all commits in this worktree (requires confirmation)"
      }
    ],
    "multiSelect": false
  }]
}
```

Note: Merge is unavailable because HEAD is detached — there is no branch to merge.

**Don't add explanation** — the tool options are self-describing. Map the user's selection to the corresponding option in Step 5.

### Step 5: Execute Choice

#### Option 1: Merge Locally

```bash
# Switch to base branch
git checkout <base-branch>

# Pull latest
git pull

# Merge feature branch
git merge <feature-branch>

# Verify tests on merged result
<test command>

# If tests pass
git branch -d <feature-branch>
```

Then: Cleanup worktree (Step 6)

#### Option 2: Push and Create PR

```bash
# Push branch
git push -u origin <feature-branch>

# Create PR/MR via the forge's CLI (detected from the origin remote)
REMOTE_URL=$(git remote get-url origin)
case "$REMOTE_URL" in
  *github.com*)
    gh pr create --title "<title>" --body "$(cat <<'EOF'
## Summary
<2-3 bullets of what changed>

## Test Plan
- [ ] <verification steps>

## Acceptance Status
- Status: <READY_FOR_CODE_REVIEW | READY_FOR_ACCEPTANCE | ACCEPTANCE_PASSED>
- Passed IDs: <ids + evidence links>
- Unmet IDs: <FAIL/BLOCKED/NOT_RUN ids, or None>
EOF
)" ;;
  *gitlab*)
    glab mr create --title "<title>" --description "$(cat <<'EOF'
## Summary
<2-3 bullets of what changed>

## Test Plan
- [ ] <verification steps>
EOF
)" ;;
  *)
    echo "Branch pushed to origin. Open a PR/MR via your forge's web UI or CLI." ;;
esac
```

Then: Cleanup worktree (Step 6)

#### Option 3: Keep As-Is

Report: "Keeping branch <name>. Worktree preserved at <path>."

**Don't cleanup worktree.**

#### Option 4: Discard

**Confirm first:**
```
This will permanently delete:
- Branch <name>
- All commits: <commit-list>
- Worktree at <path>

Type 'discard' to confirm.
```

Wait for exact confirmation.

If confirmed:
```bash
git checkout <base-branch>
git branch -D <feature-branch>
```

Then: Cleanup worktree (Step 6)

### Step 6: Cleanup Worktree

**For Options 1, 2, 4:**

Check if in worktree:
```bash
bd worktree info
```

If yes, check provenance before removing:

```bash
# Only remove worktrees inside .worktrees/ (created by our tooling)
WORKTREE_PATH=$(bd worktree info --path 2>/dev/null)
case "$WORKTREE_PATH" in
  */.worktrees/*) bd worktree remove <worktree-name> ;;
  *) echo "WARNING: This worktree is not inside .worktrees/ — it may have been created externally. Skipping automatic removal." ;;
esac
```

**For Option 3:** Keep worktree.

**Capture what you learned.** At close, record every durable, evidence-backed insight from this work — anything still true next month, tied to a file, test, or command. Don't skip because it feels minor: if it would save a future session time or stop a repeated mistake, record it. Never record guesses, one-offs, or secrets (tokens, keys, PII — every memory is injected into all future sessions). Update an existing memory in place (`bd remember --key <key>`) rather than adding a near-duplicate.

```bash
bd remember "<kind>: <durable, evidence-backed insight>"   # kind: lesson / pattern / design / root-cause / research
```

### Step 7: Land the Plane

**After executing the chosen option (Steps 1-6), complete the session close ritual. This is MANDATORY.**

The session-close sync is not complete until `git push` succeeds. A successful
push does not upgrade `READY_FOR_CODE_REVIEW` or `READY_FOR_ACCEPTANCE` to
product acceptance.

```bash
# 1. Close completed task beads with reasons; do not close acceptance gates here unless every required ID is PASS
bd close <task-id-1> <task-id-2> ... --reason "Completed: description of what was done"
```

> **Tip — atomic batch close + follow-up creation:** If you need to close multiple tasks and create a follow-up bead in one atomic operation (all succeed or none do), use `bd batch`:
> ```bash
> printf 'close <task-id-1> Completed: description\nclose <task-id-2> Completed: description\ncreate task 2 Follow-up: remaining work\n' | bd batch
> ```
> Note: `bd batch create` is simplified — no `--description`, `--parent`, or `--acceptance` flags. Use regular `bd create` when those are needed.

```bash
# 2. Close the epic bead only when all children are done AND every required acceptance ID is PASS
bd epic status <epic-id>                    # Summary view of completion
# Do not use child-count-only auto-close for epics with an outcome contract.
bd close <epic-id> --reason "Epic accepted: all tasks reviewed; acceptance IDs <ids> PASS on <commit/environment>"
```

**3. File remaining work as new beads (if any)**

File remaining work per the **Agent-Filed Bead Discipline** (see `verification-before-completion`):

```bash
bd create "[spec] Remaining: <title>" -t task -p <priority> \
  --notes "Severity: <Critical|Important|Minor>
Confidence: <Confirmed|Speculative>
Evidence: <file:line / failing test / repro | none>"
```

Drop the `[spec]` prefix when the item is Confirmed (evidence cited).

**3.5. Offer memory curation (conditional) — before the push.** If this session produced curation-worthy volume — roughly **3+ new `bd remember` calls** — OFFER (do not auto-run) a capture-enrichment pass now, so curated memories are included in the `bd dolt push` below. Ask via your structured question tool:

```json
{
  "questions": [{
    "question": "This session captured several new memories. Run a memory-curation pass (consolidate/dedup/structure) before closing?",
    "header": "Curate memory",
    "options": [
      {"label": "Yes, curate", "description": "Invoke memory-curator to enrich + dedup this session's memories (you review the command list before anything is written)"},
      {"label": "Skip", "description": "Leave memories as-is; the on-demand sweep is always available later"}
    ],
    "multiSelect": false
  }]
}
```

If selected, invoke `Skill(memory-curator)` (it proposes a reviewed command list; you approve before any write). Below the ~3-memory threshold, stay silent — do NOT prompt every close (offer fatigue retired a similar over-firing hook). Applies to ALL session closes, branch and non-branch.

```bash
# 4. Push beads to Dolt remote
bd dolt push

# 5. Push code to git remote
git pull --rebase && git push

# 6. Verify clean state
git status    # MUST show "up to date with origin"
```

**If `git push` fails:** Resolve and retry until it succeeds. NEVER stop before pushing — that leaves work stranded locally. NEVER say "ready to push when you are" — YOU must push.

## Quick Reference

| Option | Merge | Push | Keep Worktree | Cleanup Branch |
|--------|-------|------|---------------|----------------|
| 1. Merge locally | ✓ | - | - | ✓ |
| 2. Create PR | - | ✓ | ✓ | - |
| 3. Keep as-is | - | - | ✓ | - |
| 4. Discard | - | - | - | ✓ (force) |

**Step 7 (Land the Plane) applies to ALL options.** After executing any option above, complete the session close ritual: close beads, `bd dolt push`, `git push`, `git status`.

## Common Mistakes

**Skipping test verification**
- **Problem:** Merge broken code, create failing PR
- **Fix:** Always verify tests before offering options

**Open-ended questions**
- **Problem:** "What should I do next?" → ambiguous
- **Fix:** Use your structured question tool (4 options for normal/worktree context, 3 for detached HEAD)

**Automatic worktree cleanup**
- **Problem:** Remove worktree when might need it (Option 2, 3)
- **Fix:** Only cleanup for Options 1 and 4

**No confirmation for discard**
- **Problem:** Accidentally delete work
- **Fix:** Require typed "discard" confirmation

## Red Flags

**Never:**
- Proceed with failing tests
- Merge without verifying tests on result
- Delete work without confirmation
- Force-push without explicit request
- Merge a dropped requirement or a security regression behind a green test suite
- Merge, close an acceptance gate, or close an epic while a required acceptance ID is FAIL, BLOCKED, NOT_RUN, SKIPPED, or evidenced on stale code
- Describe `READY_FOR_CODE_REVIEW` as implementation complete, accepted, or merge-ready
- Infer that “open a PR” waives unfinished acceptance

**Always:**
- Verify tests before offering options
- Detect environment before presenting options (Step 2)
- Present 4 options for normal/worktree context, 3 for detached HEAD, via your structured question tool
- Get typed confirmation for discard option
- Clean up worktree for merge/PR/discard options only (not keep-as-is)
- Check worktree provenance before automatic removal

- Work is NOT complete until both syncs succeed

## Integration

**Called by:**
- **subagent-driven-development** — terminal state after all tasks pass review.
- **executing-plans** — terminal state after all tasks complete.

**Pairs with:**
- **document-release** — run docs audit before merge/PR.
- **verification-before-completion** — tests must pass before merge options are presented.
