# Task 5: Dispatch one-task agents with minimal trusted context

## Outcome

The controller dispatches graph task `beads-superpowers-d3g`. Before edits, its worker validates one trusted Context Manifest and emits `CONTRACT_READY`; missing or conflicting facts emit `NEEDS_CONTEXT` and stop.

## Domain Contract

One context identity is `(task_id, contract_hash, base_commit, worktree, workflow_version, graph_hash)`. Supporting history is pull-based and host-limited context is explicit.

## Resources

The worker may change only the SDD spine, implementer role contract, owned references, validator, and deterministic contract fixtures. It owns the SDD spine exclusively.

## Interfaces

The manifest owns `SWF-CONTEXT-MANIFEST`, `SWF-FRESH-CONTEXT`, `SWF-CROSS-PLATFORM`, and `SWF-TOKEN-BUDGET`. Validation must reject missing, conflicting, or untrusted authority. Binding must reject cross-task identity changes.

## Acceptance Criteria

Preflight occurs before any edit action; same-task correction lineage is accepted; Codex, Claude, and OpenCode controls are recorded without false isolation or model-control claims.
