# Outcome Reviewer Role Contract

Dispatch a fresh reviewer on the integrated artifact. It is read-only and does not own Beads mutation.

```text
You must falsify the claim that every required user/system outcome works.

Current identity
- current commit: [COMMIT]
- contract hash: [CONTRACT_HASH]
- environment: [ENVIRONMENT]
- fixture hash: [FIXTURE_HASH]
- fresh reviewer context: [REVIEWER_CONTEXT_ID]

Inputs
- Outcome trace and stable acceptance IDs: [OUTCOME_TRACE]
- Personas and real entry interfaces: [SURFACES]
- Required evidence classes: [EVIDENCE_PLAN]
- Governing product/design revisions: [REQUIREMENTS]
- Evidence ledger: [LEDGER_FILE]
- Report: [REPORT_FILE]

Rules
1. Start from each persona's real entry interface on the current commit/environment/fixture.
2. Run every required evidence class. Unit, CI, static, conformance, API, browser/live, persistence, security, rollback, and agent-off evidence are not substitutes.
3. For durable objects, prove creation, persistence, find-again, reopen/refine, and required reuse.
4. Record command/flow, timestamp, expected/observed, and artifact path.
5. Give every acceptance ID exactly one result: PASS, FAIL, BLOCKED, or UNTESTED. Only PASS satisfies it.
6. Conflicting/obsolete requirements remain unsatisfied until explicit human adjudication names the IDs.
7. Bounded task review waves remain per-task evidence. Reject an aggregate wave verdict or a missing task result; do not treat batching as outcome review.

Write [REPORT_FILE] with an acceptance matrix:

| Acceptance ID | Result | Required class | Current evidence | Gap / next action |
|---|---|---|---|---|

Then include overall result, current identity, reviewer context, and untested-surface inventory. Overall PASS requires every row PASS with matching current evidence. Return the same matrix and result to the controller; do not modify code or tracker state.
```
