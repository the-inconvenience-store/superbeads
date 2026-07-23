---
name: finishing-a-development-branch
description: Use when implementation work has reached a terminal branch state and the user must choose merge, PR, keep, or discard
---

# Finishing a Development Branch

**Announce:** “I’m using finishing-a-development-branch to verify acceptance and handle the branch.”

## 1. Prove Readiness

Run the repository's full code checks and duplicate-bead check. Stop on failures.

The controller—not this skill invocation, CI, or an agent report—supplies the evidence ledger for the final relevant identity. Run both gates:

```bash
python3 "$PWD/skills/subagent-driven-development/scripts/sdd-evidence.py" check-task LEDGER.json
python3 "$PWD/skills/subagent-driven-development/scripts/sdd-evidence.py" check-epic LEDGER.json
python3 "$PWD/skills/subagent-driven-development/scripts/sdd-evidence.py" \
  check-human LEDGER.json --review .internal/sdd/human-review.json \
  --head "$HEAD_SHA"
```

The task gate proves implementation/review evidence. The epic gate proves every product outcome on the current commit, contract, environment, and fixture. A whole-branch agent code review remains separate. The human gate binds an approved review or approved mechanical bypass to the exact base..head range. Never substitute one gate for another.

Classify readiness:

| State | Condition | Allowed disposition |
|---|---|---|
| `READY_FOR_CODE_REVIEW` | Code may be reviewed, but task or outcome evidence is missing/failed/blocked/untested | Open draft PR, keep, or discard; never merge/close epic |
| `READY_FOR_ACCEPTANCE` | Code and task gate pass; epic outcome evidence still must run | Run acceptance; draft PR only if requested |
| `READY_FOR_HUMAN_REVIEW` | Code checks, task gate, whole-branch review, and epic gate pass; required human review or approved bypass is missing/stale | Open draft PR, keep, or discard; never merge |
| `ACCEPTANCE_PASSED` | Code checks, task gate, whole-branch review, epic gate, and current human-review gate all pass | Merge or ready PR options allowed |

Checker failure output names every unsatisfied ID. Do not offer merge while any required evidence is stale, substituted, `FAIL`, `BLOCKED`, or `UNTESTED`, while a security regression remains, or while human review is missing or stale.

The approved design records whether human review is required and why. Establish the ledger's base commit from the confirmed branch/worktree base before review, and resolve `HEAD_SHA` from Git immediately before the human check. The record names the reviewer and exact base..head range; a changed ledger base or current head invalidates it. “Merge it” is not review attestation. The agent may prepare a review map of behavior, interfaces, high-risk files, findings, and verification evidence, but may not approve on the human's behalf.

## 2. Inspect Git Context

Determine worktree/detached state, current branch, base branch, and exact base..head range. Confirm the inferred base if ambiguous. Detect whether cleanup provenance is inside `.worktrees/`; externally created worktrees are never removed automatically.

## 3. Ask for Disposition

Use the structured question tool when available; otherwise provide a numbered list and stop. A dismissed/auto-resolved answer is not consent.

For `READY_FOR_CODE_REVIEW`, `READY_FOR_ACCEPTANCE`, or `READY_FOR_HUMAN_REVIEW`, state unmet IDs and offer only:

1. **Open draft PR** — label the exact acceptance state; no merge or gate/epic closure.
2. **Keep as-is** — preserve branch/worktree for evidence or corrections.
3. **Discard** — requires a second exact typed confirmation.

For `ACCEPTANCE_PASSED`, offer:

1. **Merge locally** — named branches only.
2. **Create Pull Request** — ready PR with ledger identity/evidence links.
3. **Keep as-is**.
4. **Discard work** — requires exact typed confirmation.

Detached HEAD omits local merge. Never interpret “open a PR” as acceptance or push permission beyond the selected branch action.

## 4. Execute the Choice

**Merge locally:** switch to the base, update it safely, merge the feature branch, then rerun code checks. If the resulting commit differs from the ledger identity, regenerate affected evidence and rerun both gates before calling the merge accepted. Delete the branch/worktree only after those checks pass.

**Create PR:** push only with user authorization. Include summary, test plan, readiness state, passed IDs/evidence, and unmet IDs. Non-passing acceptance always creates a draft PR. Preserve its worktree for follow-up; a ready PR may be cleaned up only if the chosen workflow calls for it.

**Keep:** report branch, worktree, commit range, readiness, ledger path, and unmet IDs. Do not clean up.

**Discard:** show the branch, worktree, and commits that will be destroyed, then require the user to type `discard`. Only then delete. Do not infer confirmation.

For automated cleanup, remove only a worktree proven to live below `.worktrees/`. Use non-destructive branch deletion after merge; force deletion is limited to the explicitly confirmed discard path.

## Agent-Filed Bead Discipline

File any remaining/discovered work using the severity, confidence, and evidence stamp from `verification-before-completion`. Confirmed work has no `[spec]` prefix; speculative work does. Keep acceptance blockers wired and open.

When this workflow closes after producing durable insights, read [Durable Memory](../using-superpowers/references/session-policy.md#durable-memory) and apply it; otherwise do not load it.

## 5. Land the Plane

After the selected disposition:

1. Close only tasks whose `check-task` evidence passes.
2. Close the acceptance gate/epic only when `check-epic` passes on the final relevant identity.
3. File and wire remaining work using Agent-Filed Bead Discipline.
4. Offer memory curation only after roughly three or more new memories; never auto-run it.
5. Sync Beads, then code, then verify clean/up-to-date state:

```bash
bd dolt push
git pull --rebase
git push
git status
```

Push failure is not completion; resolve and retry within the user's authorized disposition. A successful push never upgrades acceptance state.

## Red Flags

Never merge or close acceptance because tests/CI are green, a reviewer/agent said done, a requirement was dropped, or the user requested a PR. Never delete without typed confirmation. Never force-push without explicit authorization. Never present merge options until controller evidence passes.

## Integration

Called by SDD/executing-plans after task execution. Pair with `verification-before-completion` and `document-release` before final disposition.
