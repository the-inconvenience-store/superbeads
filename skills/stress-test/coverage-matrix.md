# Stress-Test Coverage Matrix

Read this reference only after the target and its governing product contract are loaded.

## Required Record

| Cell | Applicable | Evidence | Question / recommendation | Falsifying example | Resolution | Affected outcome IDs |
|---|---|---|---|---|---|---|

Every row below appears in the record. `N/A` requires observed evidence.

## Rows

| Cell | Attack focus | Example falsification |
|---|---|---|
| Product trace | Design behavior contradicts or orphans an approved outcome | The implementation can ship while a stable outcome has no observable seam |
| Actor and authority | Impersonation, delegation, tenancy, least privilege, server/client trust | A non-authorized actor sends a client-controlled role flag and succeeds |
| Domain invariants | Ownership, uniqueness, transaction boundaries, competing truth | Two writers accept incompatible terminal states |
| Lifecycle and recovery | Partial failure, retry, idempotency, undo/archive, find-again path | The UI shows success before persistence fails and cannot reconcile |
| States and concurrency | Empty/invalid/denied/conflict/offline, races, duplicate delivery | Two approvals race and both trigger a non-idempotent side effect |
| Interfaces and dependencies | Version drift, timeouts, schema evolution, external outage | An older consumer silently drops a new required field |
| Security and privacy | Authn/authz, injection, secrets, destructive paths, data exposure | A forged identifier crosses a tenant boundary |
| Scale and performance | 10x/100x load, unbounded work, hot keys, backpressure | Retry amplification exhausts the downstream service |
| Compatibility and rollout | Migration, mixed versions, rollback, data reversibility | Rollback reads state written only by the new version and corrupts it |
| Operability and evidence | Logs, metrics, alerting, acceptance seam, false-green tests | Unit tests pass while the durable user result is never produced |
| Accessibility and UX | Keyboard/screen reader/narrow screen/error recovery, when applicable | A denied state traps focus or hides the recovery action |
| Plan resources and scheduling | Write-set collisions, dependency direction, speculative discard cost, for plans | Parallel tasks edit the same contract and neither owns reconciliation |

## Novelty Test

A candidate finding is novel only if the target does not already state the complication and its consequence. Strengthening a vague risk into a concrete actor/state/action/consequence case is novel; restating “authorization matters” is not.

For each high-risk invariant, write the falsifying case as:

`Given <actor/state>, when <action or failure>, then <observable consequence> violates <invariant/outcome ID>.`

If no plausible falsifying case exists after evidence review, record why and downgrade applicability rather than inventing one.
