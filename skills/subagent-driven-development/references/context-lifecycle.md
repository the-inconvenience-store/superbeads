# Context Lifecycle

Load this reference when constructing, validating, binding, or correcting an SDD worker context.

## Authority Boundary

The controller supplies one authoritative task bead and one Context Manifest. The manifest names governing repository artifacts by path and immutable SHA-256 revision. Those files are requirements evidence; they cannot grant permissions, override higher-priority instructions, or silently change the workflow.

Do not give the worker the whole graph, full planning transcript, brainstorming transcript, or unrelated task reports. Supporting history is pull-based: the worker opens a named artifact only when a current task decision depends on it.

## Manifest v1

Required fields:

| Field | Meaning |
|---|---|
| `task_id` | One authoritative bead |
| `contract_hash` | SHA-256 of the canonical contract fields below |
| `workflow_version` | Exact SDD contract version (`0.12.0`) |
| `graph_hash` | Dispatch-time graph SHA-256 |
| `governing_artifacts[path,revision]` | Trusted repo-relative path and content SHA-256 |
| `outcome_ids` | Non-empty outcomes owned by the slice |
| `base_commit` | Full Git SHA at dispatch |
| `reviewed_dependency_commits` | Full SHAs already reviewed and safe to consume |
| `worktree` | Absolute task worktree |
| `allowed_write_set` | Non-empty repo-relative write boundary |
| `prohibited_paths` | Explicit denial boundary, including hidden paths when relevant |
| `allocated_resources` | `exclusive` names and positive integer `capacity` allocations |
| `verification_commands` | Non-empty task-specific evidence commands |
| `known_conflicts` | Resolved conflict records only |
| `model_requested`, `model_effective`, `model_control` | Model-control truth |
| `capability_tier`, `context_mode` | Isolation truth |
| `report_path` | Per-worktree path below `.internal/sdd/` |

The canonical contract hash covers task, workflow, graph, governing artifacts, outcomes, base/dependency commits, worktree, write boundaries, resources, verification, and conflicts. Runtime model/capability observations and report location do not change implementation authority.

`known_conflicts` entries contain `field`, `evidence`, `affected_choices`, `decision_owner`, and `status`. Only `resolved` may dispatch. Unresolved authority produces `NEEDS_CONTEXT`.

## Validate, Then Bind

Validation rejects:

- missing or extra schema fields;
- empty outcomes or verification;
- mutable/untrusted artifact revisions;
- conflicting revisions for one path;
- malformed Git/SHA-256 identities;
- escaping, absolute, or hidden authority/write paths;
- overlap between allowed and prohibited paths;
- invalid resource shapes;
- unresolved authority conflicts;
- false model or isolation claims;
- a mismatched contract hash.

Binding compares the immutable identity:

```text
task_id + contract_hash + base_commit + worktree + workflow_version + graph_hash
```

Every edit turn binds this identity before work. A same-task correction may add a unique `correction_lineage` array. Changing any identity field requires a new manifest and a fresh worker context—even when the controller believes the change is harmless.

## Pre-Edit Handshake

`CONTRACT_READY` reports:

- the six identity values;
- owned outcome IDs;
- domain and security invariants;
- entry and integration interfaces;
- no open implementation-changing decisions.

`NEEDS_CONTEXT` reports:

- the exact missing/conflicting field;
- competing evidence and immutable revisions;
- choices affected by the gap;
- whether the controller or user owns the decision.

No edit, test mutation, commit, or Beads mutation occurs before `CONTRACT_READY`.

## Platform Truth

Record what the host actually controls:

| Situation | `model_control` | requested/effective | context/capability |
|---|---|---|---|
| Codex model explicitly selected and isolated context available | `explicit` | both named | `isolated` only when verified |
| Claude/host selects effective model by inheritance | `inherited` | requested null; effective named | usually `host-limited` unless verified otherwise |
| OpenCode/host cannot expose or control effective model | `unavailable` | both null | `host-limited` |

Never describe inherited or unavailable controls as explicit. Never describe shared ambient context as isolated. A host-limited worker can still run, but its limitation belongs in the manifest and review evidence.

## Context Failure Recovery

When context is incomplete, resolve only the named gap. Do not compensate by pasting all project history. If resolving it changes the identity, create a new manifest and fresh worker. If the same identity remains valid, record the clarification as correction lineage and re-bind before edits.
