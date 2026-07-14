---
name: verification-before-completion
description: Use when about to claim work is complete, fixed, or passing, before committing or creating PRs - requires running verification commands and confirming output before making any success claims; evidence before assertions always
---

# Verification Before Completion

## Overview

Claiming work is complete without verification is dishonesty, not efficiency.

**Core principle:** Evidence before claims, always.

**Violating the letter of this rule is violating the spirit of this rule.**

## The Iron Law

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
NO REQUIRED VERIFICATION MAY BE SUBSTITUTED BY A DIFFERENT EVIDENCE CLASS
```

If you haven't run the verification command in this message, you cannot claim it passes.

Every required check has exactly one state: `PASS`, `FAIL`, `BLOCKED`, or
`NOT_RUN`. Only `PASS` satisfies it. Honest caveats improve reporting; they do
not turn another state into completion.

Evidence must match the named claim, commit/build, environment, and evidence
class. Green unit tests cannot prove a browser journey; a direct API call cannot
prove route wiring; CI cannot prove agent-off live behavior; conformance cannot
prove the user-facing adapter unless the requirement explicitly names it.

## The Gate Function

```
BEFORE claiming any status or expressing satisfaction:

1. IDENTIFY: What command proves this claim?
2. RUN: Execute the FULL command (fresh, complete)
3. READ: Full output, check exit code, count failures
4. VERIFY: Does output confirm the claim?
   - If NO: State actual status with evidence
   - If YES: State claim WITH evidence
5. ONLY THEN: Make the claim
6. CLASSIFY: Record PASS / FAIL / BLOCKED / NOT_RUN for every required acceptance ID
7. CLOSE: Only if every required ID is PASS, run `bd close <id> --reason "description with evidence from step 4"`

Skip any step = lying, not verifying
```

## Agent-Filed Bead Discipline

When a skill **files a bead for discovered/follow-up work** (not planned work), stamp it so a human can triage risk at a glance.

- **Title:** prefix `[spec]` ONLY if speculative. Confirmed beads keep clean titles.
- **Body/notes — always include this 3-field stamp:**
  ```
  Severity: Critical | Important | Minor
  Confidence: Confirmed | Speculative
  Evidence: <file:line / failing test / repro>   (or: none)
  ```
- **Mechanical rule:** evidence cited → `Confidence: Confirmed`; no evidence → `Confidence: Speculative`. Applies at all severities. **Never blocks filing** (surface-and-mark — Production-Grade Doctrine).
- **What counts as evidence** (claim-substantiating AND checkable, not "a string exists"):
  - ✅ `parser.ts:142 — returns null on empty input (fails t_parse_empty)`
  - ❌ `parser.ts — looks wrong`
- **High-severity nudge:** a `Critical`/`Important` bead filed without evidence MUST add one line: `Why this severity w/o evidence: <reason>`.
- **Priority (`-p`) stays human-owned** — do not infer priority from severity.
- **Honest limit:** this disciplines the instruction surface, not every runtime bead. `Confidence: Confirmed` is a falsifiable triage hint that lowers verification cost, not proof. The convention is forward-only — pre-existing beads stay unstamped.

## Common Failures

| Claim | Requires | Not Sufficient |
|-------|----------|----------------|
| Tests pass | Test command output: 0 failures | Previous run, "should pass" |
| Linter clean | Linter output: 0 errors | Partial check, extrapolation |
| Build succeeds | Build command: exit 0 | Linter passing, logs look good |
| Bug fixed | Test original symptom: passes | Code changed, assumed fixed |
| Regression test works | Red-green cycle verified | Test passes once |
| Agent completed | VCS diff shows changes | Agent reports "success" |
| Requirements met | Line-by-line checklist | Tests passing |
| No security regression | SAST/audit tool if one exists (semgrep, bandit, npm/pip audit) → 0 new findings, AND diff review: no control weakened/removed/bypassed, no new sink. No tool? Use the "If Verification Cannot Run" path: record the manual diff-review as evidence, note no SAST available. | Tests pass (tests rarely cover security) |

## If Verification Cannot Run

When no verification command exists (no test suite, CI down, external dependency unavailable):

1. **Record the gap:** `bd note <id> "verification blocked: <reason>"`
2. **Create a blocker:** `bd create "Set up verification for <feature>" -t task` and `bd dep add <current-task> <new-task>`
3. **Document partial verification:** Note what WAS verifiable (e.g., "linter passes, manual smoke test done, but no automated test suite exists")
4. **Never silently skip:** A bead closed without verification evidence AND without a documented gap is worse than a bead left open
5. **Leave the gate open:** `BLOCKED` and `NOT_RUN` are valid honest results, but neither permits acceptance-gate or epic closure

Opening a draft PR may still be useful when the user asks, but label it
`READY_FOR_CODE_REVIEW — ACCEPTANCE_BLOCKED/NOT_RUN`; do not call it complete,
merge-ready, or accepted.

## Scope Cuts and Substitution

A scope cut is valid only when the user explicitly approves the named
acceptance IDs being removed or changed. Operational requests such as “open the
PR”, “babysit CI”, “continue”, or “do not merge” are not waivers.

When a required check cannot run:

- never replace it with “equivalent confidence” from another check;
- never close with an “honest note” that it was skipped;
- keep the gate open and report the exact blocker;
- rerun on the final relevant commit/environment after remediation.

## Red Flags - STOP

- Using "should", "probably", "seems to"
- Expressing satisfaction before verification ("Great!", "Perfect!", "Done!", etc.)
- About to commit/push/PR without verification
- Trusting agent success reports
- Relying on partial verification
- Treating a different evidence class as an acceptable substitute
- Closing with a caveat that a required check failed, was blocked, or was not run
- Inferring a scope waiver from a request to open a PR or proceed to follow-up work
- Thinking "just this once"
- About to claim done while a requirement was quietly dropped, or a security regression remains unverified (tests passing ≠ security verified)
- Tired and wanting work over
- **ANY wording implying success without having run verification**

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "Should work now" | RUN the verification |
| "I'm confident" | Confidence ≠ evidence |
| "Just this once" | No exceptions |
| "Linter passed" | Linter ≠ compiler |
| "Agent said success" | Verify independently |
| "I'm tired" | Exhaustion ≠ excuse |
| "Partial check is enough" | Partial proves nothing |
| "It's good enough to ship" | Production system, real users — no shortcut, no dropped requirement, no accepted security regression |
| "Different words so rule doesn't apply" | Spirit over letter |
| "CI is green, so live acceptance is redundant" | CI proves only the checks it ran; required live evidence remains NOT_RUN |
| "I'll close it honestly and recommend manual QA" | Honest reporting does not satisfy acceptance; leave the gate open |
| "The user redirected me to the PR" | A sequencing request is not explicit consent to remove named acceptance IDs |

## Key Patterns

**Tests:**
```
✅ [Run test command] [See: 34/34 pass] "All tests pass"
❌ "Should pass now" / "Looks correct"
```

**Regression tests (TDD Red-Green):**
```
✅ Write → Run (pass) → Revert fix → Run (MUST FAIL) → Restore → Run (pass)
❌ "I've written a regression test" (without red-green verification)
```

**Build:**
```
✅ [Run build] [See: exit 0] "Build passes"
❌ "Linter passed" (linter doesn't check compilation)
```

**Requirements:**
```
✅ Re-read plan → Create checklist → Verify each → Report gaps or completion
❌ "Tests pass, phase complete"
```

**Agent delegation:**
```
✅ Agent reports success → Check VCS diff → Verify changes → Report actual state
❌ Trust agent report
```

## Why This Matters

From 24 failure memories:
- your human partner said "I don't believe you" - trust broken
- Undefined functions shipped - would crash
- Missing requirements shipped - incomplete features
- Time wasted on false completion → redirect → rework
- Violates: "Honesty is a core value. If you lie, you'll be replaced."

## When To Apply

**ALWAYS before:**
- ANY variation of success/completion claims
- ANY expression of satisfaction
- ANY positive statement about work state
- Committing, PR creation, task completion
- Moving to next task
- Delegating to agents

**Rule applies to:**
- Exact phrases
- Paraphrases and synonyms
- Implications of success
- ANY communication suggesting completion/correctness

## Beads Completion

`bd close` without fresh verification evidence is lying. Before closing any bead:
1. Run the verification command that proves the work is done
2. If it is an acceptance gate, enumerate every required acceptance ID and its evidence class
3. Annotate the bead with evidence: `bd note <id> "test output: 14 passed, 0 failed"`
4. Confirm every required ID is PASS on the final relevant commit/environment
5. Include the summary in the `--reason` flag
6. Only then execute `bd close`

Use `bd note` to attach detailed evidence (test output, diff stats, verification logs) to the bead before closing. The `--reason` flag is the summary; `bd note` is the full evidence trail.

A bead closed without evidence is worse than a bead left open — it corrupts the ledger.

**Capture what you learned.** At close, record every durable, evidence-backed insight from this work — anything still true next month, tied to a file, test, or command. Don't skip because it feels minor: if it would save a future session time or stop a repeated mistake, record it. Never record guesses, one-offs, or secrets (tokens, keys, PII — every memory is injected into all future sessions). Update an existing memory in place (`bd remember --key <key>`) rather than adding a near-duplicate.

```bash
bd remember "<kind>: <durable, evidence-backed insight>"   # kind: lesson / pattern / design / root-cause / research
```

## The Bottom Line

**No shortcuts for verification.**

Run the command. Read the output. THEN claim the result.

This is non-negotiable.

## Integration

**Invoked by:** Any task claiming completion — mandatory before `bd close`, commits, or PRs.

**Pairs with:**
- **systematic-debugging** — verify the fix worked before claiming success.
- **document-release** — docs audit is part of completion evidence.
- **write-documentation** — prose quality checks are completion evidence.
- **stress-test** — stress-test validates designs; this skill validates implementations.
