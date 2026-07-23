---
name: writing-plans
description: Use when an approved product contract and solution design need a validated multi-task implementation graph.
---

# Writing Plans

Compile approved product outcomes into one graph producer whose tasks are independently rejectable vertical Slice Contracts.

## Artifact Ownership

The plan owns **how approved product and technical decisions are executed and proven**: vertical slices, outcome ownership, exact write zones, produced and consumed interface IDs, semantic prerequisites, resource constraints, and task-specific evidence. It must not introduce product behavior or architecture. A newly required product decision returns to product-definition; a newly required solution decision returns to brainstorming before planning resumes.

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

1. **Verify inputs.** Read the contract, design, relevant code, test/build targets, and recent plan conventions. Run or inspect every command, path, signature, and schema named in the graph; recalled detail is not plan evidence. Stop if a slice would have to invent product behavior or architecture and route to the artifact owner.
2. **Build the outcome ledger.** For every stable ID record actor/entry, action, durable result, find-again path, failure/denied state, evidence class, implementation owner, earliest real seam, and final gate.
3. **Choose vertical boundaries.** Start with the thinnest end-to-end behavior. Fold horizontal setup into its first consuming slice. Consume the design's technical risk capsule: keep at most two high-risk boundaries and one coherent acceptance surface per task. Split where a reviewer could reject one result while accepting its neighbor.
4. **Declare dependencies and resources.** Add `blocks` only when the dependent consumes a stable interface produced by the prerequisite, or when it names a concrete irreversible migration/rollout constraint. Apply the **edge deletion test**: remove the candidate edge; if both tasks remain implementable against stable interfaces, leave it out. Record allowed writes, exclusivity, capacity, and any safe speculative contract independently.
5. **Write the graph.** Read [slice-contract-template.md](slice-contract-template.md) now. Save `docs/plans/YYYY-MM-DD-<feature>.graph.json`; this JSON is the sole plan of record.
6. **Validate before import.** Run `./skills/writing-plans/scripts/validate.sh <graph>`. Do **not** run `bd create --graph <graph> --dry-run`: its dry run creates issues, including duplicate epics. Fix every structural, verticality, outcome, DAG, or resource error before the single approved import.
7. **Review.** Self-review outcome ownership, earliest seams, final gates, evidence non-substitution, placeholders, interface consistency, write conflicts, and speculative cost. Offer stress-test at the plan review gate; revalidate after any edit.
8. **Import once.** After approval, run `bd create --graph <graph>` once. Record the epic/task IDs and confirm imported descriptions match the graph.
9. **Hand off execution.** Offer subagent-driven or inline execution and pass only the epic ID, graph path, and governing revisions.

Before this workflow's first Beads read/write or claim decision, read [Beads Read/Write Economy and Claim Boundary](../using-superpowers/references/session-policy.md#beads-readwrite-economy); do not load it when no tracker operation is needed.

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
- parallel-ready tasks declare write/exclusive-resource conflicts for scheduler serialization rather than converting them to dependency edges;
- required evidence classes are not substituted by lower-level checks;
- `FAIL`, `BLOCKED`, `UNTESTED`, `SKIPPED`, or stale evidence leaves its outcome open; and
- validator and user review pass.

Use the standard three-option plan review: Approved + stress-test, Approved, or Needs changes. Stress-test edits the graph artifact before revalidation; it does not import beads.

> When filing a bead for discovered/follow-up work, stamp it per **Agent-Filed Bead Discipline** (`verification-before-completion`).

When this workflow reaches its settled capture decision, read [Capture Gate](../using-superpowers/references/session-policy.md#capture-gate) and present it; do not load it on unrelated steps.

## Execution Handoff

- **Subagent-Driven:** invoke `superbeads:subagent-driven-development` with the epic ID and graph path.
- **Inline Execution:** invoke `superbeads:executing-plans` with the epic ID and graph path.

The user chooses. Planning never starts implementation itself.
