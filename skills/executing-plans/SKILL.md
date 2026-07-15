---
name: executing-plans
description: Use when you have a written implementation plan to execute in a separate session with review checkpoints
---

# Executing Plans

## Overview

Load plan, review critically, execute all tasks, report when complete.

**Announce at start:** "I'm using the executing-plans skill to implement this plan."

**Note:** Tell your human partner that Superpowers works much better with access to subagents. The quality of its work will be significantly higher if run on a platform with subagent support (such as Claude Code or Codex). If subagents are available, use superbeads:subagent-driven-development instead of this skill.

## The Process

### Step 1: Load and Review Plan
1. Read the accepted graph once; do not recreate or reinterpret its beads.
2. Validate it with the writing-plans graph validator, `bd lint`, and `bd swarm validate <epic-id>`.
3. Confirm graph nodes, dependency edges, outcome IDs, and task descriptions match the existing epic/task beads. A mismatch is a stale-contract blocker, not permission to rewrite the graph during execution.
4. Review critically for security conflicts or decisions that prevent implementation. Batch genuine user-owned questions before starting.
5. Build the current scheduler state from the validated graph, Beads status, contract hashes, reviewed commits, declared resources, and available capacity.

The accepted graph is execution input. Graph creation belongs to `superbeads:writing-plans`, before this skill begins.

### Step 2: Execute Tasks

Use the same scheduling owner as SDD:

```bash
python3 "$PWD/skills/subagent-driven-development/scripts/sdd-scheduler.py" decide STATE.json
```

In a session without isolated subagents, set capability to `host-limited` and execute the resulting serial decision. For each selected task:

1. Confirm the task has a complete Slice Contract, then claim that exact bead.
2. Follow its task-specific skills and acceptance criteria.
3. Run named verification and independent review; update state with the reviewed commit.
4. Merge/close only when the scheduler and evidence gates allow it.
5. Rebuild state after every implementation, review, merge, blocker, or human decision. Never execute a stale decision.

An empty dispatch list is not completion: inspect `reasons.completion` for `complete`, `blocked`, `in-progress`, `human-gated`, or `cyclic`.

> **bd frugality: bounded output, one round trip.** Cap reads: `bd ready -n 10`,
> `bd show --short <id>` to skim (full `bd show` only when the body is needed),
> `bd memories <keyword>` (NEVER bare `bd memories` — it dumps the whole store).
> Batch writes: several creates/updates/closes = one `bd batch` or `bd create --graph`
> call, not a loop. Filter big outputs before they hit context
> (`... | grep -E "PATTERN" | head -20`). Keep write confirmations — they are evidence.
> **`--claim` boundary:** `bd ready --claim` ONLY in autonomous take-next-task flows
> (this skill's batch/wave dispatch). FORBIDDEN wherever the user picks the work —
> orientation, brainstorming, session close. Efficiency never erodes a consent gate.

### Step 3: Complete Development

After all tasks complete and verified:
- Announce: "I'm using the finishing-a-development-branch skill to complete this work."
- **REQUIRED SUB-SKILL:** Use superbeads:finishing-a-development-branch
- The finishing skill includes the **Land the Plane** session close protocol (`bd close` → `bd dolt push` → `git pull --rebase && git push` → `git status`)
- Follow that skill to verify tests, present options, execute choice

## When to Stop and Ask for Help

**STOP executing immediately when:**
- Hit a blocker (missing dependency, test fails, instruction unclear)
- Plan has critical gaps preventing starting
- You don't understand an instruction
- Verification fails repeatedly

**Structured blocker handling:** When you hit a blocker, classify it and use the appropriate response:

| Blocker type | Action | Command |
|---|---|---|
| **Time-based** (waiting on deploy, external process) | Defer the task for later | `bd defer <task-id> --until="<date>"` |
| **Missing work** (prerequisite not built yet) | Create the missing task and wire dependency | `bd create "Missing: <title>" -t task --parent <epic-id>` then `bd dep add <blocked-id> <new-id>` |
| **Human decision needed** (architecture choice, ambiguous requirement) | Flag for human input | `bd update <task-id> --add-label human` |

> **Discovered-work bead stamp:** `bd create "[spec] <title>" -t task --parent <epic-id> --notes "Severity:/Confidence:/Evidence:"` — see `verification-before-completion` → Agent-Filed Bead Discipline.

**Ask for clarification rather than guessing.**

## When to Revisit Earlier Steps

**Return to Review (Step 1) when:**
- Partner updates the plan based on your feedback
- Fundamental approach needs rethinking

**Don't force through blockers** - stop and ask.

## Remember
- Review plan critically first
- Follow plan steps exactly
- Don't skip verifications
- Reference skills when plan says to
- Stop when blocked, don't guess
- Never start implementation on main/master branch without explicit user consent
- **Production-Grade Doctrine:** never skip a verification or drop a task to make progress — `bd defer`/`bd human` are for genuine blockers, never a quiet way to descope required work. Never weaken, bypass, or remove a security control — a security regression is never acceptable.

**Capture what you learned.** At close, record every durable, evidence-backed insight from this work — anything still true next month, tied to a file, test, or command. Don't skip because it feels minor: if it would save a future session time or stop a repeated mistake, record it. Never record guesses, one-offs, or secrets (tokens, keys, PII — every memory is injected into all future sessions). Update an existing memory in place (`bd remember --key <key>`) rather than adding a near-duplicate.

```bash
bd remember "<kind>: <durable, evidence-backed insight>"   # kind: lesson / pattern / design / root-cause / research
```

## Integration

**Required workflow skills:**
- **superbeads:using-git-worktrees** - REQUIRED: Set up isolated workspace before starting
- **superbeads:writing-plans** - Creates the plan this skill executes
- **superbeads:finishing-a-development-branch** - Complete development after all tasks

**Each execution step should use:**
- **superbeads:test-driven-development** - RED-GREEN-REFACTOR for each task's implementation
