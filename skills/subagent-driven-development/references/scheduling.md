# Scheduling

Load this reference only when the controller has more than one ready task. Task 6 owns deeper resource-aware scheduling refinements; this file preserves the current safe execution behavior.

## Select a Mode

Run `bd swarm validate <epic-id>`, then obtain the bounded ready set. Dependencies determine readiness.

- zero ready: tasks are complete or blocked; inspect the graph rather than inventing work;
- one ready: use sequential mode in the selected epic/task worktree;
- two to five ready: use a parallel batch;
- more than five: dispatch at most five and reconsider after integration.

Resource conflicts are an additional scheduling constraint, not dependency edges. Tasks that write the same file, consume the same exclusive resource, or exceed declared capacity cannot share a batch even when the graph says both are ready.

## Before Fan-Out

Worktrees isolate files, not assumptions. Before dispatching a batch:

1. identify every interface, schema, naming rule, or invariant shared by two workers;
2. resolve it once in the governing contract;
3. ensure each task manifest points to the same immutable revision;
4. reserve exclusive and capacity resources;
5. create one `bd worktree` per task and record its absolute path in that task's manifest.

Do not ask workers to coordinate directly. Do not paste a controller summary in place of the governing revision.

## Batch Flow

1. Validate every task manifest before dispatch.
2. Dispatch fresh workers concurrently, one task identity per worktree.
3. As each worker finishes, persist its report and start its read-only task review. Reviews need not wait for unrelated implementers.
4. Do not merge work with open review findings.
5. Merge approved task branches into the integration worktree one at a time.
6. Run the integration checkpoint after the approved merge set.
7. Release worktrees/resources only after evidence is durable.
8. Close approved tasks with commit ranges and recompute the ready set.

One failed task does not invalidate independent approved tasks. Keep its worktree for a same-identity correction or discard the branch and leave its bead open. Never quietly descope a required outcome.

If multiple controllers can merge into the same base concurrently, use the repository's merge-slot mechanism. A single controller already serializes merges and needs no extra coordination layer.

## Safety Rules

- Maximum five workers in one batch.
- Every concurrent implementer has its own Beads-aware worktree; do not substitute a host's generic worktree isolation when that would bypass shared tracker state.
- Never merge a branch merely because its tests passed; task review must approve it.
- Never start a dependent task against an unreviewed dependency commit unless its manifest explicitly records that reviewed dependency.
- Run an integration check after merges and diagnose unexpected failures before opening another wave.
- Recompute readiness after every merge set; do not execute a stale schedule.

The scheduler controls start time only. The Context Manifest, task review, outcome review, and closure gates remain unchanged.
