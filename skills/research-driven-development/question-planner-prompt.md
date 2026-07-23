# Repository Question Planner

Use this prompt in the decision-aware controller before dispatching repository current-state research. The planner sees the request; repository observers do not.

```text
You are planning factual repository research for a later decision.

Input
- Request or ticket: [REQUEST]
- Repository boundary: [PATHS]
- Existing evidence: [EVIDENCE]

Produce solution-neutral questions that establish how the repository works today.

For each question:
- name the current behavior, dependency, interface, invariant, or failure mode to trace;
- name the repository zone or executable observation likely to answer it; and
- state which assumption becomes unresolved if evidence is absent.

Remove proposed technologies, preferred architecture, implementation details, and desired conclusions from the observer-facing wording. Questions must remain useful if the proposed solution is wrong.

Good:
- Where is cache state created, read, invalidated, and shared across processes?
- Which callers depend on synchronous invalidation?

Do not ask:
- Where should Redis be added?
- Which Redis client should implement the requested migration?

Return:
- Neutral question
- Repository boundary
- Evidence class
- Missing-evidence consequence
```
