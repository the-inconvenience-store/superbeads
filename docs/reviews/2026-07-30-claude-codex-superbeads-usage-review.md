# Superbeads usage review: Claude and Codex, 2026-07-23 through 2026-07-30

> Date: 2026-07-30  
> Review ID: `2026-07-30-claude-codex-superbeads-8d`  
> Decision: identify repetitive workflow failures worth changing in Superbeads and establish the first durable comparison baseline.

## Metadata and corpus scope

The discovery superset was every non-symlink JSONL file under `/Users/samstevens/.claude/projects` and `/Users/samstevens/.codex/sessions` whose modification date was 2026-07-23 through 2026-07-30 inclusive. Analysis then retained only events timestamped inside the same UTC date window.

A conversation entered the Superbeads usage corpus only when it contained direct executable evidence: a `bd` lifecycle command or a command invoking or reading a Superbeads skill/cache path. Injected skill catalogs and mere textual mentions did not qualify. No project, bead, or topic selector was applied after that usage selector.

| Platform | Agent role | Reviewed conversations | Normalized events | Unavailable content |
|---|---|---:|---:|---:|
| Claude | Main | 10 | 28,427 | 0 |
| Claude | Subagent | 51 | 11,489 | 0 |
| Codex | Main | 206 | 216,081 | 0 |
| Codex | Subagent | 170 | 248,317 | 0 |
| **Total** |  | **437** | **504,314** | **0** |

Discovery found 1,340 files: 108 Claude and 1,232 Codex. Of 1,339 files with in-window events, 437 met the Superbeads usage selector. The 902 other in-window conversations remain outside the denominator.

## Verdict

Five repetitive failure modes were confirmed in fourteen source-addressable instances. Excessive controller polling was the dominant corpus-wide operational problem. Four Codex controller sessions contained dense runs of 20–58 `wait_agent` calls while work was healthy, and four Juno Gateway Claude controllers used 457 shell commands that slept and then inspected worker, event, output, or process state. The latter requested 66,953 seconds of sleep in aggregate; requested sleep can overlap external work and is not elapsed waste.

The Juno Gateway investigation found a more consequential phase-transition failure. Planning was extensive, but the approved technical design was not operationally closed at authority, production-composition, ownership, and recovery seams. Implementation review consequently became architecture discovery: the design received 19 amendment commits, the original graph grew from 12 to 22 tasks, and a further four-slice re-plan was needed. Recursive task parenting and task-identity resets then amplified the failure after `beads-superpowers-ghi` was closed as enforcing persistent outcome lineage. One ordinary one-file correction also owned repository-wide unit and integration gates.

No subagent-owned Beads lifecycle mutations were observed. Lifecycle ownership stayed with main agents, which is a useful behavior to preserve.

## Juno Gateway planning-to-execution postmortem

### Scope and conclusion

This focused extension covers attributable Juno Gateway conversations and repository artifacts from the first product-contract work on 2026-07-24 through the audit cutoff on 2026-07-30. The focused conversation corpus contains 300 source files and 134,594 in-window events: 7 Claude main files (24,519 events), 5 Claude subagent files (607), 257 Codex files normalized as main (84,819), and 31 Codex subagent files (24,649). Codex CLI leaf workers often lack `parent_thread_id`, so the Codex main/subagent split undercounts leaf workers; host attribution and the aggregate are reliable, but role attribution is conservative.

The failure was not absence of planning, a scheduler deadlock, or reviewers being too strict. The product contract was stable and the initial design and graph were unusually detailed. The failure was **false closure**: procedural approval was granted while load-bearing technical decisions still lacked an executable authority source, proof-bearing caller, production composition root, cross-process identity binding, or implementable recovery fact. Once execution exposed those omissions, the controller kept treating design amendments and replacement slices as forward implementation instead of invalidating the approved execution epoch and returning the affected outcome to design.

Repository evidence is decisive:

| Milestone | Evidence |
|---|---|
| Product draft | `781d0baeb`, 2026-07-24 15:01 +10 |
| Product stress test / revision 3 | `7bbfba367`, 15:14 |
| Design approval and stress test | `3cfd12f2c`, 17:14 |
| Graph approval and stress test | `98698835a`, 19:17 |
| First implementation commit | `1b94ba253`, 21:06 — 1 hour 49 minutes after graph approval |
| First post-execution design amendment | `ca5ee4af2`, 2026-07-25 04:51 |
| State at cutoff | 19 design-amendment commits; 15 later graph commits; 12 original tasks grown to 22, plus an A/B/C/D install re-slice |

The product contract did not change after execution began. The churn was in the technical translation. Eight initial slices merged, so this was not total execution failure; accepted code should be preserved. The unfinished critical path at the cutoff was `C, D → t9 → t10 ∥ t11 → t12`: server-side issuer composition, standalone genuine-owner authority, extension installation, WebUI/Remote integration, and terminal evidence were still open.

### What went wrong

1. **The design described desired properties without closing their trusted producers.** “Revalidate authority,” “explicitly authorized,” “opaque admission,” and “standalone owner” existed as requirements, but the initial design did not always identify who could mint the value, what proof the producer possessed, which current source was authoritative, how the value survived the Unix/process boundary, or which production component initiated the call. Late investigation found no durable authoritative local owner identity for non-bootstrap profiles and no production path that could mint the required admitted session.

2. **The graph understated semantic width.** Each original task declared no more than two complexity boundaries, satisfying the validator, but several slices actually crossed four to seven independently rejectable seams. For example, t3 combined identity, admission, media scanning, hook containment, event publication, and recovery; t20 later combined worker authority, server issuer, production entry, cross-process transport, and standalone authority. The validator trusted declared labels rather than verifying the task's consumed design seams.

3. **Stress testing produced confidence without an execution-readiness proof.** The design recorded 11 applicable high-risk rows, 12 novel complications, 11 user-resolved choices, and high confidence. It tested broad invariants, but did not trace each sensitive journey from a real production entry through proof, authority source, state owner, process crossing, restart/recovery, and observable evidence. This is why implementation could start less than two hours after approval while fundamental caller and identity-root questions remained.

4. **Governing artifacts were mutable during execution without invalidating approval.** The design received 19 amendment commits and the graph 15 later commits. The current accumulated graph also fails the current validator: t23 lacks required integration, implementation, and contract references, and t13 has invalid ordering/edge metadata. The written rule that any graph edit invalidates approval did not become a live scheduler gate.

5. **Controllers converted contract gaps into more execution.** Authority defects relocated across caller owner, principal, work-session carrier, mint precondition, credential resolution, transport reconstruction, and standalone issuer. The design records three, six, then seven relocations of the same impersonation class. `amend-contract`, `split-slice`, new task IDs, and a second graph let the campaign continue after the governing outcome should have returned to design.

6. **Context exhaustion and polling amplified rather than caused the failure.** Claude explicitly stopped at a working-context limit while the epic was unfinished, and later handoffs declared slices “ready” before their own investigations found genuine user-owned design decisions and a fundamental composition contradiction. Across four Gateway controller sessions, 457 shell calls combined `sleep` with state inspection and requested about 18.6 hours of sleep. Five handoff files and at least two automatic context-exhaustion continuations accumulated. Long controllers, repeated polling, and handoffs made state harder to reason about, but a fresh context would still have encountered the same missing authority roots.

7. **Verification evidence was sometimes vacuous and execution mode drifted.** Reversion analysis found 13 tests across four slices that still passed when the production change was reverted. In the final session, two design investigations also ran as Claude subagents despite Codex mode until the user noticed; the controller stopped and relaunched them. Neither caused the governing defect, but both weakened confidence that declared execution controls were actually binding.

The most important conversation evidence is source line 2710 of Claude session `091c7594…`: six days after approval, the controller says the remaining standalone slice has no durable authoritative owner identity for non-bootstrap profiles and requires user decisions on enrollment, migration, storage, capability lifecycle, clone/restore semantics, and the OS-identity threat model. The sibling server-side investigation found that configuration names a target user but not a proof-bearing installer, `juno serve` and the daemon are separate processes, and no production composition path mints the admitted session. Those are governing design decisions, not implementation details.

### Where the Superbeads controls failed

| Intended control | What happened | Required enforcement |
|---|---|---|
| Maximum two high-risk boundaries per slice | Tasks declared two labels while their acceptance surfaces crossed many seams | Derive task risk from referenced design-seam IDs; reject a manifest whose consumed seam union exceeds the limit |
| No implementation-changing decision open at `CONTRACT_READY` | Workers asserted readiness over incomplete production and authority context | Require a machine-backed approved artifact epoch and resolved seam ledger; a worker assertion alone is insufficient |
| Any graph edit invalidates approval | Approved design/graph changed repeatedly while scheduling continued | Mark the epoch `DESIGN_DIRTY`; block prepare, dispatch, and check-dispatch until revalidation, stress test, and approval |
| Outcome lineage survives task replacement | Fresh slices and graphs continued the same unresolved outcome | Make outcome/finding lineage global across graph and task identities; diagnostic successors inherit amendment and review budgets |
| Two failed rounds force diagnosis | Diagnosis often produced another implementation slice | A contract-gap diagnosis must return the whole outcome to design; after two design amendments in one outcome, scheduling cannot resume without a new epoch |

These controls already exist substantially in the written brainstorming, planning, and SDD skills. The remedy is not a longer prompt. It is transition authority that the scheduler and review dispatcher cannot bypass.

### How to right the Juno Gateway work

1. **Freeze the accepted baseline.** Preserve merged Gateway slices and record the exact green Juno commit. Stop dispatching C, D, t9–t12, or new Gateway corrections against the accumulated 2026-07-24 graph.
2. **Reopen only the unfinished outcome family as design work.** Produce a closure delta covering: server and standalone principals; proof source and mint authority; authority-profile to local-profile binding; production process topology; cross-process transport; durable grant/revocation owner; restart, clone, restore, and migration semantics; and the exact built-daemon journeys.
3. **Resolve user-owned choices before re-planning.** In particular, decide profile-enrollment scope, handling of existing unbound profiles, the standalone durable store, capability lifecycle, clone/restore identity semantics, and the OS-identity threat model. Fail closed or explicitly defer unsupported standalone cases rather than inventing authority in implementation.
4. **Replace, do not append to, the remaining graph.** Supersede the old unfinished path with a new graph rooted at the frozen commit and approved design hash. Give each task one acceptance surface and no more than two independently verified high-risk seams. C and D should not be marked ready until the closure delta removes their open architectural decisions.
5. **Run one production-journey readiness review before import.** For each remaining outcome, trace real entry → authenticated principal/proof → mint/authority source → profile mapping/process crossing → durable state owner → restart/recovery → evidence. A missing link blocks import.
6. **Execute from a fresh controller against the new epoch.** Every manifest must carry the product, design, and graph hashes. Any governing amendment pauses all unstarted work and invalidates their manifests. Final t12 evidence must exercise built daemon/server and standalone entry routes, not only internal APIs.

Recovery is complete only when:

- C and D have no unresolved user-owned decisions and each production journey passes the readiness trace;
- the replacement graph validates and every task's derived risk seam count is at most two;
- no governing design or graph change occurs after the new execution epoch begins;
- server install and supported standalone install pass built-binary end-to-end tests, including restart/revocation behavior;
- t9–t12 close without task-identity or graph resets for the same finding lineage; and
- the epic closes with source-addressable terminal evidence.

### What this does not mean

- **Not “there was no planning.”** The artifacts were large, traceable, and serious; the problem was unverified closure.
- **Not “Claude merely ran out of context.”** Context exhaustion was downstream of six days of architecture discovery during execution.
- **Not “the reviewers blocked delivery.”** Reviews found real impersonation, cross-user disclosure, impossible exact-once recovery, and missing production composition defects.
- **Not “discard all Gateway work.”** Eight original slices and several corrections merged. Preserve verified code and re-plan only the unfinished outcome.
- **Not “write a still larger initial spec.”** The design already grew from roughly 1,656 to 2,503 lines. The missing ingredient was enforceable seam closure and artifact immutability, not prose volume.

## Coverage and limitations

- The date filter used normalized event timestamps after modification-date discovery. This excluded 67,458 out-of-window events and 2,280 events without timestamps.
- No normalized event was marked unavailable. This does not prove that every host surface or encrypted representation was captured.
- The command-evidence selector may miss semantic Superbeads use that never produced a `bd` or skill-path command.
- The full scanner stalled in `corpus_metrics` on 1.65 million in-window events. Detection therefore used a signal-preserving 14,065-event projection containing one event per conversation plus every registered command/wait signal. Exact totals above came from the full 504,314-event selected corpus. Follow-up: `beads-superpowers-gkw`.
- At review time, RU-AP-005's deterministic detector saw normalized wait tools, not Claude Bash commands that combined `sleep` with state inspection. The four Gateway Claude instances were counted manually. The implemented detector now recognizes that command shape and reports requested sleep separately. Requested sleep does not prove that every wait was avoidable or that sleeps ran serially to completion.
- There is no prior completed JSON companion under `docs/reviews/`. Rates are a baseline, not evidence of rising or falling frequency.
- Failure counts are per confirmed behavior instance, not raw regex match. All deterministic leads were context-vetted.

## Failure summary

| Pattern ID | Title | Status | Count | Per 100 sessions | Previous rate | Trend | Confidence |
|---|---|---|---:|---:|---:|---|---|
| RU-AP-001 | Recursive correction parenting | active | 2 | 0.4577 | — | new | high |
| RU-AP-002 | Outcome-lineage retry reset | active | 2 | 0.4577 | — | new | high |
| RU-AP-003 | Release verification in ordinary task work | active | 1 | 0.2288 | — | new | high |
| RU-AP-004 | Unreviewed dependency represented as reviewed | active | 0 | 0.0000 | — | new | none |
| RU-AP-005 | Excessive controller polling | active | 8 | 1.8307 | — | new | high |
| RU-AP-006 | Episodic memory capture | active | 0 | 0.0000 | — | new | none |
| RU-AP-007 | Editor opened for finished artifact | active | 0 | 0.0000 | — | new | none |
| RU-AP-008 | Long interval without stable slice closure | active | 0 | 0.0000 | — | new | none |
| RU-AP-009 | Execution over an unclosed governing design | active | 1 | 0.2288 | — | new | high |

## Failure instances

| Instance ID | Pattern ID | Platform | Session / agent | Timestamp | Source line | Confidence | Evidence hash | Note |
|---|---|---|---|---|---|---|---|---|
| RU-AP-001-2f9eae6e6cf8 | RU-AP-001 | Codex | `019f8d57…` / main | 2026-07-23T06:46:53.468Z | `/Users/samstevens/.codex/sessions/2026/07/23/rollout-2026-07-23T14-59-16-019f8d57-99d8-7e52-960a-104b054bf262.jsonl:1458` | high | `2f9eae6e6cf8a3b1…` | A split-slice successor was attached beneath the corrective child rather than to a stable outcome/root. |
| RU-AP-001-d175f01d63ba | RU-AP-001 | Codex | `019f8d57…` / main | 2026-07-23T06:30:21.502Z | `/Users/samstevens/.codex/sessions/2026/07/23/rollout-2026-07-23T14-59-16-019f8d57-99d8-7e52-960a-104b054bf262.jsonl:1211` | high | `d175f01d63ba4f3d…` | A separate one-file dependency repair was parented beneath an already seven-level-deep implementation lineage. |
| RU-AP-002-34b2dc443a5f | RU-AP-002 | Codex | `019f92b2…` / main | 2026-07-27T14:58:21.317Z | `/Users/samstevens/.codex/sessions/2026/07/24/rollout-2026-07-24T15-56-40-019f92b2-8581-7812-885c-25967a7072f8.jsonl:11075` | high | `34b2dc443a5f7cba…` | After six failed review rounds, a fresh bead and immutable review identity re-baselined the same unresolved outcome. |
| RU-AP-002-dcdae99be9ff | RU-AP-002 | Claude | `7a32b082…` / main | 2026-07-29T14:37:27.844Z | `/Users/samstevens/.claude/projects/-Users-samstevens-labs-juno/7a32b082-77dc-4baa-af73-18a81b102580.jsonl:906` | high | `dcdae99be9ff39bb…` | After the original slice exhausted its correction budget, a new slice identity carried forward the same user-only admission outcome. |
| RU-AP-003-f61012eb992c | RU-AP-003 | Codex | `019f8d57…` / main | 2026-07-23T07:13:11.929Z | `/Users/samstevens/.codex/sessions/2026/07/23/rollout-2026-07-23T14-59-16-019f8d57-99d8-7e52-960a-104b054bf262.jsonl:1735` | high | `f61012eb992ca07e…` | A one-file restore-enumeration correction ran the repository-wide unit gate and then the repository-wide integration gate. |
| RU-AP-005-1c9aa6c615c3 | RU-AP-005 | Codex | `019fab77…` / main | 2026-07-29T16:22:35.377Z | `/Users/samstevens/.codex/sessions/2026/07/29/rollout-2026-07-29T11-22-50-019fab77-9a09-7b12-bdab-98cd772b8c66.jsonl:21536` | high | `1c9aa6c615c3f743…` | 25 dense waits over about 14 minutes during an active acceptance run. |
| RU-AP-005-25bcf3577504 | RU-AP-005 | Codex | `019f919b…` / main | 2026-07-28T02:40:21.320Z | `/Users/samstevens/.codex/sessions/2026/07/24/rollout-2026-07-24T10-51-53-019f919b-79eb-73f2-b9d8-faf3142d7ba2.jsonl:50249` | high | `25bcf3577504c61e…` | 20 dense waits over about 11 minutes while the worker remained active. |
| RU-AP-005-54633592517b | RU-AP-005 | Codex | `019f92b2…` / main | 2026-07-24T13:08:35.668Z | `/Users/samstevens/.codex/sessions/2026/07/24/rollout-2026-07-24T15-56-40-019f92b2-8581-7812-885c-25967a7072f8.jsonl:5468` | high | `54633592517bf7d6…` | 37 dense waits over about 36 minutes while workers and test gates remained active. |
| RU-AP-005-b31a5aa1d6bc | RU-AP-005 | Codex | `019f9784…` / main | 2026-07-26T15:07:37.256Z | `/Users/samstevens/.codex/sessions/2026/07/25/rollout-2026-07-25T14-25-03-019f9784-fe79-79e0-a7a2-2e009e9b9fa7.jsonl:4679` | high | `b31a5aa1d6bc78c9…` | 58 dense waits over about 38 minutes while implementation and tests were progressing. |
| RU-AP-005-18489206d208 | RU-AP-005 | Claude | `32175a3a…` / main | 2026-07-24T10:09:42.429Z | `/Users/samstevens/.claude/projects/-Users-samstevens-labs-juno/32175a3a-f3ee-4039-82ff-c57b069adfb8.jsonl:261` | high | `18489206d208f440…` | Gateway controller issued 378 shell sleep-and-inspect polls, requesting 44,975 seconds. |
| RU-AP-005-3ddefddcd4ea | RU-AP-005 | Claude | `f5b42cf8…` / main | 2026-07-29T06:14:28.870Z | `/Users/samstevens/.claude/projects/-Users-samstevens-labs-juno/f5b42cf8-c212-415a-a247-2fb16ecd606a.jsonl:387` | high | `3ddefddcd4ea043a…` | Gateway controller issued 47 shell sleep-and-inspect polls, requesting 12,101 seconds. |
| RU-AP-005-f3c0f3da8256 | RU-AP-005 | Claude | `7a32b082…` / main | 2026-07-29T12:10:00.534Z | `/Users/samstevens/.claude/projects/-Users-samstevens-labs-juno/7a32b082-77dc-4baa-af73-18a81b102580.jsonl:326` | high | `f3c0f3da825699e3…` | Gateway controller issued 20 shell sleep-and-inspect polls, requesting 8,770 seconds. |
| RU-AP-005-0743f22d6d20 | RU-AP-005 | Claude | `091c7594…` / main | 2026-07-30T00:56:59.909Z | `/Users/samstevens/.claude/projects/-Users-samstevens-labs-juno/091c7594-4386-4db6-abe6-7d956b9bb5d3.jsonl:632` | high | `0743f22d6d204be8…` | Gateway controller issued 12 shell sleep-and-inspect polls, requesting 1,107 seconds. |
| RU-AP-009-a37774c5671c | RU-AP-009 | Claude | `091c7594…` / main | 2026-07-30T08:27:30.376Z | `/Users/samstevens/.claude/projects/-Users-samstevens-labs-juno/091c7594-4386-4db6-abe6-7d956b9bb5d3.jsonl:2710` | high | `a37774c5671ca3e8…` | Six days after formal approval, the unfinished standalone slice still required fundamental user-owned authority-root and lifecycle decisions. |

## Longitudinal trends

This is the first comparable durable review, so all rate trends are `new`.

There is still evidence of regression against intended behavior. `beads-superpowers-ghi`, closed on 2026-07-23, says task-ID replacement must not reset the outcome correction budget and normal correction depth should remain flat. Both RU-AP-001 and RU-AP-002 occurred after that implementation, including one Claude instance on 2026-07-29. The gap appears to be live controller adoption or enforcement rather than absence of a written contract.

Host distribution is also informative: eight retained failures occurred in Codex main-agent sessions, six in Claude main-agent sessions, and none in subagent sessions. Codex main agents contributed 12,302 of the corpus's 13,622 normalized wait events. The focused Gateway review additionally found that Claude expressed the same polling behavior through Bash `sleep` plus state-inspection commands, which the normalized wait detector does not classify.

## Emergent behaviors to encourage and constrain

Encourage:

- Main-agent lifecycle ownership held across both hosts. Main agents performed all observed create, update, close, remember, and sync commands; subagents only performed read-oriented `bd show` calls.
- The corpus contained 199 close commands against 144 create commands. This is not a unique-issue completion rate, but it is evidence that usage was not merely accumulating new work.
- Controllers often recorded explicit review ancestry, contract hashes, and diagnostic classifications. Those artifacts made the confirmed lineage failures diagnosable rather than invisible.

Constrain:

- Persistence should not become short-interval polling. Completion signaling and phase-overrun thresholds should replace repeated healthy-worker status checks.
- `amend-contract` and `split-slice` diagnostics must not become a new identity that silently refreshes the same outcome budget.
- Focused corrections should not inherit full repository or release verification unless their manifest explicitly owns that integration boundary.
- The RU-AP-007 detector needs command-position anchoring. All six in-scope leads were false positives caused by the word `open` in prose or command arguments; follow-up is `beads-superpowers-hpj`.

## Recommendations

1. The Codex controller workflow owner should make completion signaling or long waits the default and permit status intervention only after a defined phase-overrun threshold. Track in `beads-superpowers-4zk`.
2. The SDD evidence owner should reproduce the two live bypass shapes and enforce outcome/finding lineage on every dispatch route, including diagnostic successors. Track the regression in `beads-superpowers-wls`.
3. The verification contract owner should distinguish focused task gates from epic/release gates so ordinary corrections do not own repository-wide verification. Track in `beads-superpowers-bab`.
4. The review-use maintainer should make `corpus_metrics` linear before the next broad review and tighten RU-AP-007 command anchoring. Track in `beads-superpowers-gkw` and `beads-superpowers-hpj`.
5. Run the same selector and date-normalization method in the next review so rates remain comparable. A second review can show direction; retirement still requires three reviews spanning at least 21 days.
6. The planning/SDD workflow owner should add an immutable approved artifact epoch, machine-checked design-seam ledger, and contract-gap return-to-design gate. Track in `beads-superpowers-9cw`.

## Skill changes implemented from both reviews

The workflow now uses transition controls instead of longer prompts.

1. `writing-plans` creates an approved execution epoch. The epoch binds the product
   contract, technical design, graph, and resolved seam catalog by content hash.
   A governing change makes the epoch `DESIGN_DIRTY`.
2. Graph tasks name approved design-seam IDs. The validator derives each task's risk
   union from those seams. A task cannot hide semantic width with self-declared labels.
3. SDD manifests carry the epoch identity, consumed seam IDs, and derived risk.
   Manifest preparation rejects a dirty or mismatched epoch.
4. The scheduler checks the approved epoch before it selects work. It also records a
   phase budget. The controller waits for a completion signal until a
   `phase-overrun` permits one diagnostic inspection.
5. A contract-gap returns the complete affected outcome to design. A replacement task
   or graph cannot reset canonical outcome lineage.
6. Ordinary task manifests cannot own release verification. An integration command
   requires a graph-assigned task owner and a consumed seam ID. Authority, security,
   protocol, and recovery work requires a sensitivity check that proves the test can
   detect the targeted failure.
7. Codex mode requires a launch receipt. The receipt binds the task, contract hash,
   worker kind, model, context mode, and worker session.
8. `review-use` computes corpus metrics in one pass. It distinguishes completion waits
   from polling, detects shell sleep-and-inspect loops, and classifies `codex exec`
   sessions as leaf workers.
9. One shared technical-writing policy governs specifications, product contracts,
   plans, handoffs, reports, reviews, technical documentation, and user workflow
   updates. The policy derives from ASD-STE100 Issue 9. It uses active voice, explicit
   actors, short sentences, consistent terms, and condition-first instructions.
   Exact code, commands, identifiers, paths, quotes, raw evidence, and machine tokens
   remain unchanged. The project does not claim full ASD-STE100 compliance without a
   complete dictionary, grammar, and terminology review.

## Registry changes

Added RU-AP-009, **Execution over an unclosed governing design**, because this is a phase-transition defect distinct from recursive correction topology, retry-budget reset, and long intervals without closure. It requires a governing contract or graph to change materially after execution begins; ordinary implementation clarification does not qualify, and a campaign that pauses once, re-approves a new epoch, and then resumes is compliant. No pattern has the history required for retirement. RU-AP-007 remains active despite zero confirmed instances because its six detector matches were false positives, not retirement evidence.

## Evidence commands and source index

The review used:

- `collect.py discover` with explicit Claude/Codex roots and `--since 2026-07-23 --until 2026-07-30`;
- `collect.py normalize` on the bounded manifest;
- `registry.py validate` on `references/anti-patterns.json`;
- `analyze.py scan` with the vetted manual-instance companion and no prior review; and
- `analyze.py render`, followed by contextual verdict and recommendation edits.

The authoritative machine-readable companion is `docs/reviews/2026-07-30-claude-codex-superbeads-usage-review.json`. Its evidence hashes bind pattern ID, host/session identity, source path, source line, and matched evidence without reproducing raw prompts or responses.

Primary roots:

- Claude: `/Users/samstevens/.claude/projects`
- Codex: `/Users/samstevens/.codex/sessions`

Review and follow-up beads:

- Review: `beads-superpowers-wrn`
- Scanner scalability: `beads-superpowers-gkw`
- Editor detector precision: `beads-superpowers-hpj`
- Polling behavior: `beads-superpowers-4zk`
- Outcome-lineage regression: `beads-superpowers-wls`
- Verification ownership: `beads-superpowers-bab`
- Juno Gateway postmortem: `beads-superpowers-gg7`
- Immutable design-epoch enforcement: `beads-superpowers-9cw`
