# Brainstorming Question Coverage

Read this reference only after an approved product contract or validated bypass exists. It selects solution questions; it does not repeat product discovery.

## Decision Inventory

| Cell | Apply when | Resolve from evidence before asking | High-risk when |
|---|---|---|---|
| Entry and route | A user or system initiates behavior | Existing routes, commands, events, and ownership | The entry can bypass policy or strand a durable object |
| Authority boundary | Any actor can view, mutate, approve, or delegate | Contract grants plus server-side enforcement | Authority is inferred from client input or ambient identity |
| Domain ownership | State has a durable owner | Existing entities, transactions, and invariants | Two systems can become competing sources of truth |
| Lifecycle and recovery | State changes or side effects occur | Contract lifecycle and existing recovery patterns | Partial failure, retry, undo, or archive is ambiguous |
| Interfaces and dependencies | Components or external systems interact | Existing APIs, schemas, queues, and version contracts | Failure or evolution crosses a trust/transaction boundary |
| Security and privacy | Data, identity, input, secrets, or destructive actions exist | Current controls and threat boundaries | A required control is absent, weakened, or client-enforced |
| Evidence and observability | Outcomes must be proven or operated | Existing tests, logs, metrics, and live seams | The result can pass tests without proving product behavior |
| Rollout and compatibility | Existing state or users are affected | Migration/version/feature-flag conventions | Rollback loses data or mixed versions violate invariants |
| Accessibility and presentation | A human-facing state exists | Design system and supported surfaces | Denied/error/narrow-screen states block the journey |

Mark genuinely inapplicable cells `N/A` with observed evidence. Do not manufacture concerns.

## Question Selection

Classify each candidate question:

- **Known product fact:** already approved in the contract. Never ask it again.
- **Derivable:** answerable from repository evidence. Investigate and record it.
- **Independent unresolved:** its answer does not alter another question's choices. Batch up to three.
- **Dependency-changing unresolved:** its answer changes architecture, authority, ordering, or later choices. Ask it serially.

Every user question contains:

1. **Observed evidence:** the concrete contract/code fact that creates the decision.
2. **Consequence:** what differs based on the answer.
3. **Recommendation:** the preferred answer and why.
4. **Affected outcome IDs:** the stable product outcomes changed by the choice.

Bad: “Who is allowed to approve?” when the approved contract already says administrators.

Good: “The contract grants approval to administrators, but `approve.ts` currently trusts a client `isAdmin` flag. I recommend server-side role resolution because it preserves `APPROVAL-AUTHORITY`. Should the existing endpoint be replaced or wrapped during migration?”

## Coverage Summary

Before design presentation, emit:

| Cell | Applicable | Observed evidence | Resolution / open decision | Risk | Affected outcome IDs |
|---|---|---|---|---|---|

A high-risk row cannot be `unknown`, omitted, or silently deferred. Record the named decision owner and approval for any explicit deferral.

## Implementation Topology

For each implementation seam, record the following ledger after solution decisions are resolved. This is technical design evidence for planning; it does not schedule tasks.

| Seam ID | State / data owner | Entry / integration interface | Produces | Consumes | Security / authority boundary | Failure / recovery owner | Likely write zones | Semantic prerequisites | Resource conflicts |
|---|---|---|---|---|---|---|---|---|---|

Use stable seam/interface IDs. A semantic prerequisite means the consumed behavior or artifact does not exist before its producer. Shared paths, fixtures, generated clients, or exclusive resources belong under resource conflicts unless they also create a real produced/consumed dependency.
