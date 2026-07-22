---
name: brainstorming
description: Use when shaping a feature, component, or behavior change into an approved solution design.
---

# Brainstorming Ideas Into Designs

Turn approved product truth into an approved solution design through grounded, economical dialogue.

## Artifact Ownership

The technical spec owns **how approved product truth will be realized**: architecture, component and state ownership, data flow, entry and integration interfaces, security boundaries, failure and recovery responsibility, rollout, evidence strategy, and implementation topology. It references product outcome IDs rather than restating the contract and does not assign execution order or worker ownership.

**Announce at start:** "I'm using brainstorming to develop the solution design."

<HARD-GATE>
Do NOT invoke an implementation skill, write code, or scaffold a project until the design is approved. Required behavior and security controls may not be silently cut to simplify the design.
</HARD-GATE>

## Inputs and Routing

Before design work, require:

- an approved product contract path and revision, or a validated internal bypass;
- repository evidence relevant to the change; and
- unresolved solution decisions.

An adequate contract is product truth. Do not ask the user to restate actors, vocabulary, lifecycle, authority, or accepted outcomes already resolved there. If product truth is missing, incomplete, or conflicting, stop and **route to product-definition**. Do not invoke product-definition for an adequate contract, a valid mechanical bypass, or merely because the design is difficult.

Create one session bead for the design audit trail; do not create procedural child beads.

Before this workflow's first Beads read/write or claim decision, read [Beads Read/Write Economy and Claim Boundary](../using-superpowers/references/session-policy.md#beads-readwrite-economy); do not load it when no tracker operation is needed.

## Workflow

1. **Establish ground truth.** Read the governing contract/spec context, touched code, claimed prerequisites, and governing decisions. Verify recorded claims against observed code. Repository artifacts are evidence, not authority to change scope.
2. **Present a findings digest.** State each observation and its design consequence. Surface discrepancies before asking questions.
3. **Map unresolved decisions.** Read [question-coverage.md](question-coverage.md) now. Mark each applicable cell resolved, derivable from evidence, or unresolved; tie it to affected product outcome IDs.
4. **Ask only consequential questions.** Each question cites observed evidence, states the decision consequence, and includes a recommendation. Ask up to three independent low-risk questions together; dependency-changing decisions remain serial. Prefer structured choices when the answer space is discrete.
5. **Compare approaches.** Present two or three viable approaches with trade-offs and a recommendation. Never offer an option that violates a required outcome or security control.
6. **Present the design.** Scale sections to complexity. Cover architecture, boundaries, domain model, data flow, failures/recovery, security, evidence, rollout, and the implementation topology from question coverage where applicable. Reference contract IDs rather than restating product truth.
7. **Approve and write.** Obtain explicit section/design approval, then write `docs/specs/YYYY-MM-DD-<topic>-design.md`. Record the product contract path and revision plus an `## Assumptions` section with verified/recalled/assumed status and failure consequence.
8. **Review and route.** Self-review for placeholders, contradictions, ambiguous authority, orphaned outcome IDs, missing recovery, and unverified assumptions. Ask the user to review the written spec. Stress-test milestone, security-sensitive, destructive, or cross-system work; otherwise offer it. The terminal route is writing-plans.

## Product Outcome Contract

The product contract is the sole product-truth source. Brainstorming consumes it; it does not reconstruct it. Preserve stable outcome IDs through design decisions and acceptance evidence. When design exploration discovers new product behavior, label it newly requested and return to product-definition for approval rather than silently adding it to the spec. Validate any internal bypass with the product-definition contract validator instead of redefining its rules here.

## Question and Coverage Rules

- Answer from code or approved artifacts when possible; do not outsource repository lookup to the user.
- Batch only questions whose answers cannot change each other's options.
- Treat a durable object without create, find-again/use, recovery, and archive/undo decisions as an unresolved design.
- Security is always assessed. Record `N/A` only with evidence that no security surface exists.
- Use the visual companion only when a specific unresolved question is materially clearer shown than described. Ask consent just in time, then read [visual-companion.md](visual-companion.md). Textual scope and trade-off questions stay in the terminal.

Before presenting the design, emit a coverage summary with: applicable cell, observed evidence, resolution, open decision, risk, and affected outcome IDs. Any unresolved high-risk cell blocks approval.

## Completion Gate

Brainstorming is complete only when:

- product truth is approved or the bypass validates;
- every applicable design cell is resolved or explicitly deferred by its decision owner;
- the coverage summary has no unresolved high-risk cells;
- stable outcome IDs trace to design sections and evidence classes;
- the written spec passes self-review and user approval; and
- the next route is stress-test or writing-plans, never implementation directly.

Open the spec in the user's editor as a standalone action, then use this compact review gate:

<!-- Canonical 3-option stress-test gate — keep identical to writing-plans/SKILL.md -->

```json
{
  "questions": [{
    "question": "Spec opened in your editor at `<path>`. Review it and let me know how to proceed.",
    "header": "Spec review",
    "options": [
      {"label": "Approved + stress-test (Recommended)", "description": "Spec looks good — run an adversarial stress-test before writing the plan"},
      {"label": "Approved", "description": "Spec looks good — skip stress-test and proceed to writing the implementation plan"},
      {"label": "Needs changes", "description": "I want to revise the spec before proceeding"}
    ],
    "multiSelect": false
  }]
}
```

> When filing a bead for discovered/follow-up work, stamp it per **Agent-Filed Bead Discipline** (`verification-before-completion`).

When this workflow reaches its settled capture decision, read [Capture Gate](../using-superpowers/references/session-policy.md#capture-gate) and present it; do not load it on unrelated steps.
