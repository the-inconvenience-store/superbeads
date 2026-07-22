# Review and Evidence

Load this reference after an implementer reports, when a reviewer returns findings, or before task/epic closure.

## Bounded Inputs

The controller gives a fresh reviewer:

- immutable Context Manifest and domain capsule;
- implementer report (claims, not truth);
- exact `BASE..HEAD` review package;
- acceptance IDs and required evidence classes;
- review round and fresh reviewer-context ID.

The reviewer is read-only. It does not mutate source, Git, reports, or Beads. Use files for bulky handoffs and comments for durable verdicts; never paste the controller transcript.

## Typed Task Review

`./task-reviewer-prompt.md` returns one acceptance matrix plus spec-compliance and code-quality verdicts. Every finding has:

```text
finding_id, severity, acceptance_ids, classification, evidence,
invalidated_assumption, correction, counterexample, contract_hash, review_round
```

Classification is one of `contract-gap`, `implementation-defect`, `evidence-gap`, `integration-defect`, or `reviewer-disagreement`. Security regressions are Critical. Evidence names the exact line, artifact, command result, or reproducible observation; a rationale in the implementer report never lowers severity.

Each review round uses a fresh reviewer context. The implementer may retain the same task identity only while the six-field Context Manifest identity remains unchanged.

## Two-Round Correction Limit

After two failed review rounds, ordinary correction stops and diagnosis is mandatory.

Round 1 failure: technically evaluate findings, send one consolidated correction to the same-task implementer lineage, gather fresh evidence, then use a fresh reviewer.

Before every correction dispatch, run:

```bash
python3 "$PWD/skills/subagent-driven-development/scripts/sdd-evidence.py" check-dispatch LEDGER.json
```

A nonzero result forbids another ordinary correction in that lineage; checking only at closure is too late.

Round 2 failure: stop normal correction. Record exactly one diagnostic before any new dispatch:

- `amend-contract` — governing acceptance or interface is incomplete/wrong;
- `split-slice` — the task is too broad or combines distinct outcomes;
- `resolve-product-decision` — a user-owned behavior is undecided;
- `adjudicate-reviewer` — evidence supports a concrete reviewer disagreement.

The diagnostic names a new task or contract strategy and sets dispatch disallowed for the old lineage. A third ordinary “try again” round is forbidden. A new task/contract starts with a new manifest and fresh implementer context.

## Evidence Ledger

The controller maintains one JSON ledger with:

- current commit, contract hash, environment, and fixture hash;
- task and epic acceptance-ID-to-evidence-class maps;
- fresh task/outcome review identities and reports;
- evidence records with command/flow, timestamp, artifact, result, and full identity;
- typed review rounds and any required diagnostic.

Run the pure gate:

```bash
python3 "$PWD/skills/subagent-driven-development/scripts/sdd-evidence.py" check-task LEDGER.json
python3 "$PWD/skills/subagent-driven-development/scripts/sdd-evidence.py" check-epic LEDGER.json
```

Only a current `PASS` in the required evidence class satisfies an ID. Missing, stale, substituted, `FAIL`, `BLOCKED`, or `UNTESTED` evidence is named and leaves the gate open. The checker never runs ledger commands or mutates state.

## Verification Tiers and Reuse

- **Focused:** the smallest check for the changed behavior; owned by the worker and rerun after each correction.
- **Task:** the package/slice contract and its security/static checks; required before task review.
- **Integration:** cross-task seams on the integrated commit; owned by the controller after merge.
- **Release:** graph-wide guards and outcome flows; run once on the assembled release identity.

Reuse evidence only when commit, contract hash, environment, fixture hash, command/flow, and required evidence class are unchanged. A correction reruns invalidated focused/task evidence; integration and release evidence are never substituted by a lower tier.

## Phase Telemetry

Record elapsed time and retry count separately for `prepare`, `implement`, `review`, `correction`, `merge`, and `release`. Store concise phase records with the task report/evidence ledger; never infer agent latency from the whole controller session. Telemetry observes the workflow and cannot waive evidence or security gates.

## Separate Owners

- Task review: one task diff, Slice Contract, code quality, and task evidence.
- Whole-branch code review: integrated implementation risks across task boundaries.
- Outcome review: user/system entry routes and every epic outcome ID on the integrated commit/environment/fixture.

One gate cannot impersonate another. CI, unit tests, conformance, static review, direct API, browser/live, persistence, rollback, security, and agent-off evidence are distinct unless the product contract explicitly equates them.

## Closure

Persist report, typed findings, exact commit range, ledger path/hash, and checker output. A task may close only after `check-task` passes. Acceptance gate and epic may close only after `check-epic` passes. Draft PR or branch-disposition requests never waive unsatisfied IDs.
