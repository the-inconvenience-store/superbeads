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

Four repetitive failure modes were confirmed in nine source-addressable instances. Excessive Codex controller polling was the dominant operational problem: four controller sessions contained dense runs of 20–58 `wait_agent` calls while work was still healthy and progressing. Those sessions account for 3,596 of the 3,930 `wait_agent` calls in the selected corpus, or 91.5%.

The next most important finding is a regression in correction convergence. Recursive task parenting and task-identity resets recurred after `beads-superpowers-ghi` was closed as enforcing persistent outcome lineage. One ordinary one-file correction also owned repository-wide unit and integration gates.

No subagent-owned Beads lifecycle mutations were observed. Lifecycle ownership stayed with main agents, which is a useful behavior to preserve.

## Coverage and limitations

- The date filter used normalized event timestamps after modification-date discovery. This excluded 67,458 out-of-window events and 2,280 events without timestamps.
- No normalized event was marked unavailable. This does not prove that every host surface or encrypted representation was captured.
- The command-evidence selector may miss semantic Superbeads use that never produced a `bd` or skill-path command.
- The full scanner stalled in `corpus_metrics` on 1.65 million in-window events. Detection therefore used a signal-preserving 14,065-event projection containing one event per conversation plus every registered command/wait signal. Exact totals above came from the full 504,314-event selected corpus. Follow-up: `beads-superpowers-gkw`.
- There is no prior completed JSON companion under `docs/reviews/`. Rates are a baseline, not evidence of rising or falling frequency.
- Failure counts are per confirmed behavior instance, not raw regex match. All deterministic leads were context-vetted.

## Failure summary

| Pattern ID | Title | Status | Count | Per 100 sessions | Previous rate | Trend | Confidence |
|---|---|---|---:|---:|---:|---|---|
| RU-AP-001 | Recursive correction parenting | active | 2 | 0.4577 | — | new | high |
| RU-AP-002 | Outcome-lineage retry reset | active | 2 | 0.4577 | — | new | high |
| RU-AP-003 | Release verification in ordinary task work | active | 1 | 0.2288 | — | new | high |
| RU-AP-004 | Unreviewed dependency represented as reviewed | active | 0 | 0.0000 | — | new | none |
| RU-AP-005 | Excessive controller polling | active | 4 | 0.9153 | — | new | high |
| RU-AP-006 | Episodic memory capture | active | 0 | 0.0000 | — | new | none |
| RU-AP-007 | Editor opened for finished artifact | active | 0 | 0.0000 | — | new | none |
| RU-AP-008 | Long interval without stable slice closure | active | 0 | 0.0000 | — | new | none |

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

## Longitudinal trends

This is the first comparable durable review, so all rate trends are `new`.

There is still evidence of regression against intended behavior. `beads-superpowers-ghi`, closed on 2026-07-23, says task-ID replacement must not reset the outcome correction budget and normal correction depth should remain flat. Both RU-AP-001 and RU-AP-002 occurred after that implementation, including one Claude instance on 2026-07-29. The gap appears to be live controller adoption or enforcement rather than absence of a written contract.

Host distribution is also informative: eight of nine retained failures occurred in Codex main-agent sessions, one in a Claude main-agent session, and none in subagent sessions. The largest difference is polling: Claude contributed no normalized wait events, while Codex main agents contributed 12,302 of the corpus's 13,622 wait events.

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

## Registry changes

None. Every confirmed failure fits an existing active pattern, and no pattern has the history required for retirement. RU-AP-007 remains active despite zero confirmed instances because its six detector matches were false positives, not retirement evidence.

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
