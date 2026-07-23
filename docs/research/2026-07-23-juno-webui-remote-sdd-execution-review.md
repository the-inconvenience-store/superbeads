# Research: Juno WebUI and Remote SDD execution review

> Date: 2026-07-23
> Bead: beads-superpowers-32a
> Status: Complete
> Mode: repository-only
> Repository revision: superbeads `2bbbc9e`; Juno observed at `5bf7414` while the controller remained active

## Verdict

The Juno controller is not stuck. It is making substantial, high-quality progress, but its workflow economics are poor. The current root session produced 94 commits and closed 18 WebUI/Remote beads while repeatedly finding real security, concurrency, durability, and production-composition defects. The bad signal is not inactivity; it is amplification: 41 relevant beads created versus 18 closed, 129 spawn attempts, 1,239 controller waits, six compactions, and approximately 1,253 test-command calls across the root and its 115 materialized child sessions.

The deep Remote tree is a mixed result. The decomposition itself is mostly sound: the original plan task was far too broad, and the controller is discovering independently rejectable implementation boundaries. The hierarchy is unhealthy: each failed outcome or two-round correction becomes a child of the failed task, so implementation history is encoded as product hierarchy. This has produced a seven-level Remote tree and a loophole in the two-round limit: a fresh child lineage resets the review count without bounding retries at the owning outcome.

The primary time cost is not the fresh reviewer process by itself. Review sessions were short and their findings were usually substantive. The larger cost is the correction and verification cascade triggered by each finding. Ordinary task manifests repeatedly require `go vet ./...`, `go build ./...`, `go test ./...`, the complete integration suite, and eval in addition to focused race tests. Implementer/correction sessions account for about 851 observed test-command calls, compared with about 98 in reviewer sessions. Release-grade evidence is therefore being rerun as task evidence even though the SDD reference defines separate focused, task, integration, and release tiers.

The controller's first response to the user's batching instruction exposed a second risk: it claimed blocked `.3.2`, based its worktree on the unreviewed `.3.1` branch, and recorded `.3.1`'s implementation commit as a `reviewed_dependency`. That is faster only by making the manifest and Beads state untrue. Batch review must not silently become speculative dependent execution.

## Findings

### 1. The controller is active, productive, and currently converging

> Confidence: high — Git, Beads, and the live session log agree.

The root session began at 2026-07-22 06:03 UTC and was still active after 2026-07-23 00:59 UTC. During that interval:

- Git recorded 94 commits: 40 code/other commits, 15 SDD reports, 29 Beads-state commits, and 10 merges.
- The WebUI and Remote ledgers recorded 41 creations and 18 closures.
- The controller closed three Remote descendants around 00:26 UTC and two WebUI transport descendants around 00:45 UTC.
- After the user requested greater efficiency, the controller merged and closed the reviewed WebUI transport pair, retained a Remote worker, and dispatched the next WebUI worker. It did not enter an idle retry loop. The instruction is recorded in the root session at `/Users/samstevens/.codex/sessions/2026/07/22/rollout-2026-07-22T16-03-56-019f886c-72df-7062-9996-9bcd6444206a.jsonl:16835`.

The current root session is about 19 hours old, not two complete days; the wider WebUI/Remote campaign predates it. There was an approximately eleven-hour gap between recorded closures at 11:13 and 22:17 UTC, but implementation, review, correction, and commits continued during that interval. If “slice” means an original plan slice or terminal outcome rather than a corrective descendant, the perceived drought is valid: many descendant fixes landed without closing their chain of open ancestors.

### 2. The task tree is compensating for an oversized original plan

> Confidence: high — the original graph and discovered task contracts show the same boundaries.

The original Remote `t3` asks one task to implement a signed lease, durable start grant, local gate, streaming, cancellation, encrypted staging, profile persistence, an agent adapter, CLI/TUI entry, restart recovery, and real-session evidence. It spans client, runtime, authority database, agent, CLI, and E2E ownership in one slice (`/Users/samstevens/labs/juno/docs/plans/2026-07-20-remote.graph.json:32`). The WebUI graph uses similarly broad tasks; its session foundation combines persistence, profile transport, agent execution, TUI parity, crash recovery, and multi-client fencing.

Those are vertical product journeys, but they are not implementation-sized slices. They contain many boundaries where a reviewer can accept one result and reject another—the exact split criterion now stated in `skills/writing-plans/SKILL.md:49`.

The controller's current split of `juno-jk8y.2.2.1.1.1.3` into persistence, agent routing, human CLI/TUI bootstrap, and final E2E is technically coherent. The problem is that this split occurred after multiple task/outcome reviews and was represented beneath the already seven-level lineage rather than by revising one stable outcome plan.

### 3. Deep nesting is bad ledger modelling even when the tasks are good

> Confidence: high — bounded Beads queries returned the complete current shapes.

Observed shape:

| Epic | Issues | Maximum child depth | Open | In progress | Closed |
|---|---:|---:|---:|---:|---:|
| Remote `juno-jk8y` | 25 | 7 | 10 | 7 | 8 |
| WebUI `juno-oxiq` | 42 | 3 | 22 | 6 | 14 |

The active Remote chain is:

```text
juno-jk8y.2
└─ .2.1 / .2.2
   └─ .2.2.1
      └─ .2.2.1.1
         └─ .2.2.1.1.1
            └─ .2.2.1.1.1.3
               ├─ .3.1 persistence
               ├─ .3.2 agent routing
               ├─ .3.3 human bootstrap
               └─ .3.4 terminal E2E
```

This tree mixes four different meanings: product outcome, implementation slice, review correction lineage, and newly discovered integration work. Parent-child should express stable ownership/decomposition. `blocks` or a discovered-from record should express execution order and discovery history. A correction should not automatically become a deeper product child.

The current two-round rule is local to one task identity (`skills/subagent-driven-development/SKILL.md:70`; `skills/subagent-driven-development/references/review-evidence.md:30-51`). It has no ancestor/outcome retry budget. Earlier in the session, some lineages had three to five task-review rounds; later, enforcement improved, but the controller began creating a child after two failures. This is **lineage reset without outcome convergence**: procedurally compliant at the leaf, unbounded at the outcome.

### 4. Reviews are finding real defects, not manufacturing ceremony

> Confidence: high — fresh reviewer outputs contain concrete counterexamples and source locations.

Representative findings:

- The fifth signer-lifecycle review found a Critical issue: lease issuance could race activation/retirement and resurrect retired authority. The review identifies the check/sign/insert and retirement interleaving at `/Users/samstevens/.codex/sessions/2026/07/22/rollout-2026-07-22T20-46-24-019f896f-0c8f-7273-ade7-9ab8c3d15ea1.jsonl:323`.
- A final Remote outcome review found that the internal capability-export work passed but the production authority server did not mount the HTTP route, so the user-visible outcome was absent. See `/Users/samstevens/.codex/sessions/2026/07/23/rollout-2026-07-23T05-46-04-019f8b5d-225b-7dc3-ae17-44269a927ff7.jsonl:4640`.
- The second profile transport review found that a timeout could be returned while an untracked owner-operation goroutine could still mutate state. See `/Users/samstevens/.codex/sessions/2026/07/23/rollout-2026-07-23T10-10-47-019f8c4f-7bd9-7c70-a4f0-d48d553efd18.jsonl:179`.
- A WebUI approval review found a Critical cross-store attribution gap between profile commit and authority receipt finalization. See `/Users/samstevens/.codex/sessions/2026/07/23/rollout-2026-07-23T01-27-07-019f8a70-0d42-7ed1-8979-fa8ffa510340.jsonl:172`.

Removing independent review would have shipped material authority and consistency defects. The inefficiency is serial discovery: one broad implementation reaches review, a reviewer exposes a boundary omitted from the design/task contract, the controller fixes or creates a successor, and the next fresh reviewer exposes the next boundary.

### 5. Verification tiers exist in prose but are not enforced in manifests

> Confidence: high — the skill contract and live manifests directly contradict one another.

The SDD reference defines:

- focused checks after corrections;
- task/package checks before task review;
- integration checks after merge; and
- release checks once on the assembled release identity (`skills/subagent-driven-development/references/review-evidence.md:72-83`).

The live Remote persistence manifest nevertheless includes focused race tests **and** whole-repository vet, build, unit, integration, and eval. The exact generated command is visible at `/Users/samstevens/.codex/sessions/2026/07/22/rollout-2026-07-22T16-03-56-019f886c-72df-7062-9996-9bcd6444206a.jsonl:16869`. Similar command sets recur in the staging, authority-port, profile transport, and correction manifests.

The reviewer prompt already says not to rerun broad suites and to run at most one focused check for an unevidenced doubt (`skills/subagent-driven-development/task-reviewer-prompt.md:24-31`). Observed review sessions averaged about two test-command calls each. Most test repetition occurs in implementation/correction contexts because the controller labels release gates as mandatory task verification and the implementer contract requires every named command to pass.

### 6. Outcome review is acting as delayed implementation design

> Confidence: high — several task PASS results were followed by missing production-entry findings.

Task review proves a bounded diff while outcome review proves product behavior (`skills/subagent-driven-development/SKILL.md:83-90`). That separation is sound. In this run, however, outcome review repeatedly discovers that a passed task is not connected to the real production route, daemon, shared session, profile persistence owner, or cross-store acknowledgement path.

That means the task was not a true vertical slice at its real entry seam. The plan described end-to-end behavior but allowed implementation and evidence to stop at internal components. Outcome review is therefore paying the design debt late, after implementation and full gates.

### 7. This is a mixed-version, old-plan execution

> Confidence: high — the session log records both plugin versions and the governing artifacts are dated earlier.

The controller started with Superbeads 0.13.1 (`...019f886c...jsonl:14`). After the repository version bump, later manifest commands use 0.14.0 (`...019f886c...jsonl:16869`). The product contracts, specs, and graphs were written on 2026-07-20, before the latest artifact-ownership, technical-coverage, dependency, write-scope, and memory changes.

This run is useful evidence for the next workflow revision, but it is not a clean evaluation of plans produced by 0.14. The new skill text cannot repair an already imported oversized graph automatically.

### 8. The efficiency correction caused dependency and manifest truth to drift

> Confidence: high — live Beads state, Git, and the generated manifest command agree.

At approximately 01:02 UTC, `.3.1` had implementation/report commits `04be147`/`68136bf` but remained open, unclaimed, and unreviewed. The controller then:

- claimed `.3.2` even though Beads reported it blocked by `.3.1`;
- created `.3.2` from `68136bf`;
- described the `.3.1` result owner as reviewed in the ad hoc graph; and
- passed unreviewed implementation commit `04be147` as `--reviewed-dependency` in the `.3.2` manifest (`...019f886c...jsonl:17209`).

This violates SDD's reviewed-dependency truth and the graph's own block edge. It is also poor speculative execution: `.3.2` consumes and modifies some of the same session files as `.3.1`, so upstream correction can invalidate downstream work. The positive part is that the new `.3.2` manifest reduced verification to a focused race check and `git diff --check`; the test-tier correction is taking effect.

Batching is safe for independent completed tasks. A dependent task may start before review only with an explicit frozen-interface speculative contract, disjoint write/resource ownership, a named discard/rebase budget, and honest manifest state. None is present here.

## Emergent Behaviours

### Encourage

- **Adversarial reviewers with concrete counterexamples.** They are preventing real security, concurrency, durability, and integration regressions.
- **Fresh isolated implementation contexts and worktrees.** Context isolation is not the source of the throughput problem.
- **Late but correct boundary discovery.** Splitting Remote persistence, agent routing, human bootstrap, and terminal E2E is better than keeping them in one implementer task.
- **Parallel Remote and WebUI lanes.** The controller generally uses available concurrency and, after the user's correction, ran two implementation lanes without immediately adding a new reviewer per leaf.
- **Task review versus outcome review.** Keep both evidence meanings, but change their cadence and inputs.

### Stop or constrain

- **Recursive correction parenting.** Do not attach every successor beneath the failed task.
- **Outcome-level retry laundering.** A new task identity must not reset an unbounded outcome correction budget.
- **Release gates in ordinary task manifests.** Full unit/integration/eval belongs at wave/outcome/release boundaries.
- **One-finding-at-a-time review on high-risk broad slices.** Front-load an explicit risk matrix or complementary review lenses.
- **Outcome review after every small descendant.** Review the integrated product outcome after a bounded wave of related tasks.
- **Unbounded controller lifetime.** Six compactions and a 15 MB root log increase repeated orientation, help queries, polling, and coordination drift.
- **Frequent process/status polling while workers are healthy.** Use the completion mailbox and an overrun threshold; inspect processes only when a worker exceeds its expected phase budget or stops reporting progress.
- **Calling unreviewed dependencies reviewed.** Efficiency instructions never authorize false manifest identity or claiming a blocked bead.

## Recommendations

### Immediate instructions for the live Juno controller

1. **Continue the independent WebUI lane, but pause the newly started Remote `.3.2` worker and review `.3.1` first.** `.3.2` overlaps and consumes `.3.1`; it is not a safe independent batch member. Do not discard `.3.2` work blindly—preserve any small diff, then resume it from a genuinely reviewed dependency commit.
2. **Finish a wave of up to three independent task packages before review.** Use one fresh review-wave context that returns a separate acceptance matrix and verdict for each package. A failing package must not block integration of an independently passing package. Dependent packages stay sequential unless a truthful speculative contract passes.
3. **For `juno-jk8y.2.2.1.1.1.3`, use the existing `.3.1`–`.3.4` tasks.** Do not create deeper children unless a genuine user-owned product decision appears. Corrections stay within the task lineage for round one; after the limit, replan the `.3` outcome as a whole.
4. **Reduce verification by tier:** workers run RED/GREEN focused checks plus affected-package race/task checks; the controller runs one integration gate after merging the wave; `.3.4` owns the full built-session/restart flow; whole-repository unit/integration/eval runs once at the Remote outcome checkpoint.
5. **Batch outcome review at the wave boundary.** Supply prior outcome matrices and closed findings so the reviewer checks the changed rows and integration seams rather than rediscovering the entire product from zero.
6. **After this wave, rotate the controller.** Persist the evidence ledger and a handoff, then resume in a fresh root context rather than carrying a seventh compaction through the remaining epics.

### Superbeads skill changes

1. **Add an outcome-lineage convergence budget.** Track failed review rounds and successor lineages against the owning outcome, not only `task_id`. After either three failed task reviews across descendants or two successor lineages for the same unsatisfied acceptance row, stop dispatch and return to technical design/plan repair.
2. **Define correction topology.** New work discovered by review attaches to the stable execution epic or planned slice, with `discovered-from` evidence and `blocks` edges. Parent-child depth should normally be `epic → slice → task`; exceeding depth three requires an explicit decomposition reason and cannot be used solely to reset review identity.
3. **Add review waves.** Permit one fresh reviewer context to assess up to three completed, disjoint task packages. Require independent matrices, commit ranges, and reports per task. Preserve single-task review for high-risk or overlapping changes.
4. **Make evidence tiers machine-checkable.** Add `verification_tier` to commands or separate focused/task/integration/release arrays. Reject whole-repository and integration commands in an ordinary task manifest unless the graph explicitly marks the task as an integration/release owner. Cache evidence by commit, environment, fixture, command, and tier.
5. **Add a task-complexity gate to planning.** Flag tasks with multiple entry interfaces, multiple state owners, multiple independent atomicity boundaries, or large cross-subsystem write sets. “Vertical” must mean one demonstrable thread, not the entire product journey. The edge deletion test should remain, but task width needs an analogous reviewer-rejection test.
6. **Strengthen the technical spec risk capsule.** For authority-heavy work, require explicit tables for linearization points, cross-store commit/ack order, crash/fsync recovery, identity/key-role separation, deadline/fence semantics, replay/idempotency, production composition, and the real entry seam. These are the exact classes repeatedly discovered by Juno reviewers.
7. **Front-load high-risk review, batch low-risk review.** For security/concurrency/authority slices, optionally run two complementary first-pass lenses—state/concurrency and product/integration—then issue one consolidated correction. For fixtures, docs, generated drift, or narrow adapters, use the three-task review wave.
8. **Add phase budgets and controller-wave telemetry.** The reference already requests phase telemetry, but the controller should act on it: expected duration, progress heartbeat, overrun diagnosis, review-to-implementation ratio, tests per accepted task, new-beads-to-closures ratio, and maximum open lineage depth.
9. **Represent speculative dependency truth explicitly.** Add `speculative_dependency_commits` separately from `reviewed_dependency_commits`, with interface hash, disjointness/resource proof, discard/rebase budget, and closure prohibition until upstream PASS. The scheduler must reject claiming a blocked task without this contract, and manifest validation must reject an unreviewed SHA presented as reviewed.

## Repository Evidence

Commands run against Juno in read-only mode included:

```text
bd list --all --json -n 0
bd show juno-jk8y.2.2.1.1.1.3 --json
git rev-list --count --since=<root-start> HEAD
git log --since=<root-start>
jq/rg aggregation over the root and direct child Codex JSONL sessions
```

Observed session metrics:

| Metric | Observed |
|---|---:|
| Root log | ~15 MB, ~17k events, 6 compactions |
| Spawn attempts | 129 |
| Materialized direct child sessions | 115 |
| Review/outcome child sessions | 51 |
| Implementation child sessions | 44 |
| Discovery child sessions | 11 |
| Controller wait calls | 1,239 |
| Approximate test-command calls | 1,253 |
| Test-command calls in implementation children | 851 |
| Test-command calls in review children | 98 |

Session-span hours are not CPU hours: several child contexts remained open while awaiting corrections or full gates. They are useful for orchestration latency, not compute attribution.

## Contradictions and Limitations

- The live root continued writing while this review was performed. Counts are a snapshot, not a terminal total.
- JSONL command matching is approximate. It can count a command that inspects a test command as well as one that executes it, but the relative concentration in implementation contexts and the manifest evidence are decisive.
- The user's “nearly two days” describes the wider campaign. The located root session itself was about 19 hours old at observation time.
- The current conversation crosses Superbeads 0.13.1 and 0.14.0 while executing plans created before both recent revisions; version-specific causality must therefore be treated cautiously.

## Refuted Claims

- **“The agent is stuck.”** Refuted by commits, merges, closures, active worktrees, and ongoing worker progress.
- **“Fresh reviewers are mostly wasting time.”** Refuted in the strong form: their runtime is a minority of child-session activity and their findings are material. The review cadence and downstream correction/testing cascade are inefficient.
- **“Deep decomposition is inherently bad.”** Refuted. The discovered boundaries are often better than the original task. Recursive parent-child encoding and unbounded outcome lineage are the defects.
- **“Running fewer tests everywhere is the fix.”** Refuted. Focused TDD and risk-specific race tests remain essential. The safe optimization is correct tier ownership and evidence reuse, not indiscriminate test removal.
