---
name: writing-plans
description: Use when an approved product contract and solution design need a validated multi-task implementation graph.
---

# Writing Plans

Compile approved product outcomes into one graph producer whose tasks are independently rejectable vertical Slice Contracts.

**Announce at start:** "I'm using writing-plans to create and validate the implementation graph."

Do not touch implementation code. Do not silently cut required behavior or weaken security, review, or evidence controls.

## Required Inputs

- Approved product contract path and revision, or a validated internal bypass
- Approved design/spec path
- Stable outcome IDs and required evidence classes
- Observed repository paths, commands, interfaces, dependencies, and resource constraints

If substantial product-affecting work lacks adequate product truth, return to product-definition. If solution decisions remain unresolved, return to brainstorming. Do not reconstruct either artifact inside the plan.

## Outcome Trace and Slice Contract

A valid slice demonstrates product behavior or an operable platform capability. Setup, schema, scaffolding, tests, and documentation belong in the slice whose behavior needs them.

An enabling probe is valid only when it is independently operable and its **first consumer** is exercised in the same task. A schema/interface/scaffolding-only task otherwise fails unless it records an integration-risk exception and downstream acceptance link.

Each slice names:

- actor and real entry interface;
- observable result plus durable find-again/use path;
- denied/failure/recovery behavior;
- stable outcome IDs and evidence classes;
- exact write set, exclusive resources, and capacity resources;
- interfaces consumed and produced; and
- a real integration checkpoint.

Beads `blocks` edges express execution prerequisites; **resource conflicts are not dependency edges**. Declare them separately so scheduling can distinguish safety from ordering. Speculative dependency execution is opt-in and requires a frozen interface, disjoint resources, and bounded discard/rebase cost.

## Workflow

1. **Verify inputs.** Read the contract, design, relevant code, test/build targets, and recent plan conventions. Run or inspect every command, path, signature, and schema named in the graph; recalled detail is not plan evidence.
2. **Build the outcome ledger.** For every stable ID record actor/entry, action, durable result, find-again path, failure/denied state, evidence class, implementation owner, earliest real seam, and final gate.
3. **Choose vertical boundaries.** Start with the thinnest end-to-end behavior. Fold horizontal setup into its first consuming slice. Split only where a reviewer could reject one result while accepting its neighbor.
4. **Declare dependencies and resources.** Add `blocks` only for semantic prerequisites. Record allowed writes, exclusivity, capacity, and any safe speculative contract independently.
5. **Write the graph.** Read [slice-contract-template.md](slice-contract-template.md) now. Save `docs/plans/YYYY-MM-DD-<feature>.graph.json`; this JSON is the sole plan of record.
6. **Validate before import.** Run `python3 ./skills/writing-plans/scripts/validate-graph-plan.py <graph>` and `bd create --graph <graph> --dry-run`. Fix every structural, verticality, outcome, DAG, or resource error.
7. **Review.** Self-review outcome ownership, earliest seams, final gates, evidence non-substitution, placeholders, interface consistency, write conflicts, and speculative cost. Offer stress-test at the plan review gate; revalidate after any edit.
8. **Import once.** After approval, run `bd create --graph <graph>` once. Record the epic/task IDs and confirm imported descriptions match the graph.
9. **Hand off execution.** Offer subagent-driven or inline execution and pass only the epic ID, graph path, and governing revisions.

> **bd frugality: bounded output, one round trip.** Cap reads: `bd ready -n 10`,
> `bd show --short <id>` to skim (full `bd show` only when the body is needed),
> `bd memories <keyword>` (NEVER bare `bd memories` — it dumps the whole store).
> Batch writes: several creates/updates/closes = one `bd batch` or `bd create --graph`
> call, not a loop. Filter big outputs before they hit context
> (`... | grep -E "PATTERN" | head -20`). Keep write confirmations — they are evidence.
> **`--claim` boundary:** `bd ready --claim` ONLY in autonomous take-next-task flows
> (this skill's batch/wave dispatch). FORBIDDEN wherever the user picks the work —
> orientation, brainstorming, session close. Efficiency never erodes a consent gate.

## Precision Without Payload Bloat

- Include exact observed paths, public contracts, commands, expected evidence, and security constraints.
- Do not require routine **full-code snippets**, 2–5 minute actions, or a commit after every micro-step. Those duplicate implementation reasoning and inflate worker context.
- Use concise RED/GREEN implementation notes: failing behavior, command and expected failure, minimal change boundary, passing command, and final verification.
- Define novel public interfaces and non-obvious data shapes exactly once. Reference stable names in dependent tasks.
- A vague instruction such as “handle edge cases,” “add tests,” “similar to Task N,” `TBD`, or `TODO` is a validation failure.

## Completion Gate

The graph is ready only when:

- every epic outcome has an implementation owner, earliest integration seam, and terminal final gate;
- every task satisfies the canonical section schema and produces a demonstrable slice;
- the DAG is acyclic and edge direction is dependent → prerequisite;
- parallel-ready tasks have disjoint writes/exclusive resources or explicit scheduling constraints;
- required evidence classes are not substituted by lower-level checks;
- `FAIL`, `BLOCKED`, `UNTESTED`, `SKIPPED`, or stale evidence leaves its outcome open; and
- validator, dry-run import, and user review pass.

Use the standard three-option plan review: Approved + stress-test, Approved, or Needs changes. Stress-test edits the graph artifact before revalidation; it does not import beads.

> When filing a bead for discovered/follow-up work, stamp it per **Agent-Filed Bead Discipline** (`verification-before-completion`).

After the work is settled, present the Capture gate (you MUST present it; the user picks Skip if nothing is worth keeping):

```json
{
  "questions": [{
    "question": "This produced something worth preserving — what should I capture?",
    "header": "Capture",
    "options": [
      {"label": "ADR + memory", "description": "Record an ADR for the decision AND a durable bd-remember memory"},
      {"label": "ADR only", "description": "Record an ADR for the architecturally-significant decision"},
      {"label": "Memory only", "description": "Capture a durable lesson/insight via bd remember"},
      {"label": "Skip", "description": "Nothing here is durable enough to preserve"}
    ],
    "multiSelect": false
  }]
}
```

Route: **ADR / ADR+memory** → write the ADR per the 3-mark gate (`docs/decisions/ADR-NNNN-<kebab>.md`, sections Context/Decision/Rationale/Consequences, update `docs/decisions/INDEX.md`). **Memory / ADR+memory** → `bd remember "<kind>: <durable, evidence-backed insight>"`. **Skip** → nothing.

## Execution Handoff

- **Subagent-Driven:** invoke `superbeads:subagent-driven-development` with the epic ID and graph path.
- **Inline Execution:** invoke `superbeads:executing-plans` with the epic ID and graph path.

The user chooses. Planning never starts implementation itself.
