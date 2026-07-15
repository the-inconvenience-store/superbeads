# Rolling Scheduling

Load this reference when a validated task graph has more than one unfinished task. The scheduler is a pure decision function: the controller still owns dispatch, Beads, worktrees, reviews, merges, and closure.

## Decision Interface

Create a state snapshot containing the graph revision, capability tier, worker/review/merge capacity, named capacity resources, acceptance-gate state, speculation limits, and current tasks. Each task records:

- status and phase;
- dependencies plus the exact reviewed dependency commits it consumes;
- manifest contract hash and current contract hash;
- write set, exclusive resources, and capacity-resource demand;
- review result and implementation commit;
- optional speculation proof.

Then run:

```bash
python3 "$PWD/skills/subagent-driven-development/scripts/sdd-scheduler.py" decide STATE.json
```

The deterministic result has `dispatch`, `reviews`, `merges`, `blocked`, `mode`, and structured `reasons`. Persist that result with the graph revision, manifest/report evidence, capability tier, and reviewed commits. The script never spawns agents, mutates Beads, creates worktrees, merges, or pushes.

## Rolling Controller Loop

1. Snapshot current graph/runtime state; never reuse a decision after state changes.
2. Run `decide`.
3. Start every selected review immediately. Reviews may overlap unrelated implementers because review capacity is separately reserved and measured.
4. Perform each selected immediate merge one at a time. After a passing task merges, persist its reviewed commit, release its write/resource reservations, and recompute—do not wait for a batch barrier.
5. Dispatch selected implementations in fresh task worktrees using their Context Manifests.
6. Persist blocked reasons instead of retrying unsafe work.
7. After any implementation, review, merge, correction, contract revision, capacity change, or human decision, rebuild state and recompute readiness.

The output is a decision over the supplied snapshot, not permission to act on stale state. Before executing a decision, confirm the graph revision and task contract hash still match.

## Resource Safety

Dependency-free does not mean parallel-safe. A pending task stays blocked when it would:

- overlap an active or selected write path (directory prefixes count);
- share an exclusive resource;
- exceed a named capacity resource;
- consume a worker slot needed beyond the declared limit;
- start review or integration without reserved capacity;
- use a stale contract or unrecorded reviewed dependency commit.

Resources remain held through implementation and review. A passing task's immediate merge releases them; the next decision may then dispatch work that was previously in conflict.

## Dependency and Speculation Rule

True dependents wait for reviewed merged commits by default. `dependency_commits` must equal the dependency task's current passing merged commit.

Safe speculation is exceptional and explicit. It requires all of:

- speculation enabled for this task;
- frozen dependency interface;
- declared and computed disjoint write, exclusive, and capacity resources;
- discard-file and rebase-commit cost within configured bounds;
- available worker capacity.

If any proof is absent, the scheduler reports why speculation is denied. A merged dependency with a stale or missing commit record is a context error, not a speculation opportunity.

## Capability Fallback

`isolated` capability uses rolling mode: unrelated implementation, review, and merge decisions can coexist within their separate capacities.

`host-limited` capability produces explicit serial mode. It chooses at most one new action, with merge before review before implementation, and retains every contract, review, verification, and outcome gate. Never claim rolling isolation on a host that cannot provide it.

## Empty-Ready Classification

An empty dispatch list is not automatically done. The decision reasons classify state as:

- `complete`: every required task is merged/closed and acceptance gates pass;
- `in-progress`: implementation, review, merge, or an actionable decision remains;
- `human-gated`: a named human decision owns the stop;
- `cyclic`: unfinished dependencies form a cycle;
- `blocked`: capacity, resource, contract, evidence, dependency, or acceptance prevents progress.

Only `complete` may flow to final branch completion. Every other state preserves its blockers and leaves required work open.
