---
name: research-driven-development
description: Use when a decision or plan needs persistent repository, external, or mixed research evidence.
---

# Research-Driven Development

Research produces a durable evidence artifact before a decision or plan. The process may run inline or through bounded workers; the evidence contract is the same.

**Announce at start:** "I'm using the research-driven-development skill to investigate this topic."

## Trigger / Non-trigger

Use this skill for comparisons, investigations, open questions, or unfamiliar topics whose answer will guide product, design, or implementation work.

Use a direct answer or ordinary repository inspection instead when the user explicitly wants a quick verbal answer, asks for one stable fact, or asks only what a named local file contains.

**Iron law:** research is complete only when `docs/research/` contains the evidence artifact. A chat synthesis is an interim result.

## Inputs

Establish:

- the research question and the decision it informs;
- known constraints and existing research;
- the evidence mode; and
- the expected depth: simple fact, comparison/decision, or open-ended.

Select exactly one mode:

- **repository-only** when every load-bearing claim can be decided from this repository;
- **external-only** when the answer is independent of the repository; or
- **mixed** when the recommendation depends on both current local behavior and external facts.

After selecting, read [research-modes.md](research-modes.md) for that mode's source, citation, and document contract. A mode change requires re-checking the evidence contract.

## Steps

1. **Bound the question.** If the decision, scope, or source class is unclear, ask only the questions needed to resolve it. Complete when the question, decision, boundaries, and mode are explicit.
2. **Open one research bead.** Create and claim a task named `Research: <topic>`. Search bounded memories and `docs/research/` for prior coverage. Complete when reusable evidence is identified or its absence is established.
3. **Plan evidence coverage.** Split comparison/open-ended work into complementary, non-overlapping sub-questions. For repository current-state research, read [question-planner-prompt.md](question-planner-prompt.md): the controller that knows the request produces solution-neutral questions, then a fresh context receives only those questions and repository boundaries. Decision-informing repository observation does not stay inline; if the host cannot create a fresh context, persist the neutral questions and stop for a fresh-session handoff. Inline work is limited to decision-aware synthesis or a direct-answer non-trigger. When isolated workers would reduce clock time, read [researcher-prompt.md](researcher-prompt.md), supply one bounded brief per worker, and cap a round at five workers. Complete when every load-bearing question has one owner and evidence class, and no repository-observer packet reveals proposed implementation details.
4. **Gather within the selected mode.** Repository observers report current-state facts, contradictions, and unresolved evidence without recommending an implementation. Repository work uses LSP where available plus targeted `rg`, tests, history, and executable checks. External work starts broad, then narrows to primary or authoritative sources. Mixed work keeps blinded repository observation separate from decision-aware external research and synthesis. Complete when each load-bearing claim has decisive evidence or is marked unresolved.
5. **Synthesize once.** Merge duplicates, test whether evidence entails each claim, resolve contradictions by authority and recency, assign confidence with a reason, and retain refuted claims when their removal affects the decision. Complete when findings answer every sub-question and recommendations follow from cited evidence.
6. **Close material gaps.** Run at most one narrow follow-up round of one or two briefs for unresolved load-bearing claims. A remaining gap becomes an explicit limitation or blocker, never an invented source. Complete when the gap is resolved or its decision consequence is recorded.
7. **Write the artifact.** Write `docs/research/YYYY-MM-DD-<topic>.md` or an existing matching category path. Use the mode's document contract and cite the current repository revision for repository evidence. Complete when a fresh reader can trace every load-bearing claim to evidence and understand the recommendation.
8. **Close the bead.** File only evidence-backed follow-up work, then close the research bead with the one-line verdict. Complete when tracker state and the artifact agree.

## Completion

Research is complete when all of these are true:

- the selected mode's evidence requirements pass;
- every load-bearing claim is cited, supported, and confidence-rated;
- repository current-state findings remain distinguishable from later interpretation and recommendations;
- contradictions, limitations, and refuted claims that affect the verdict are visible;
- recommendations name an actor and action;
- the research artifact records its date, bead, status, mode, and repository revision when applicable; and
- the research bead is closed against the artifact's verdict.

Repository-only completion requires decisive `path:line` or command/test evidence and requires no external URL. External-only completion requires direct authoritative URLs for the claims they support. Mixed completion requires both evidence classes where the verdict depends on both.

## Routing

- Product behavior discovered or changed → `superbeads:product-definition`.
- A solution decision is now ready → `superbeads:brainstorming`.
- Requirements and design are already approved → `superbeads:writing-plans`.
- Missing access or a user-owned decision → mark the bead blocked and state the exact recovery condition.

## Conditional References

- Read [research-modes.md](research-modes.md) after mode selection; read only the selected branch plus the shared evidence shape.
- Read [question-planner-prompt.md](question-planner-prompt.md) before repository current-state research that informs a decision or plan.
- Read [researcher-prompt.md](researcher-prompt.md) only when dispatching a research worker.
- Read the repository's LSP/tool guidance only when repository evidence is in scope.

When this workflow closes after producing durable insights, read [Durable Memory](../using-superpowers/references/session-policy.md#durable-memory) and apply it; otherwise do not load it.
