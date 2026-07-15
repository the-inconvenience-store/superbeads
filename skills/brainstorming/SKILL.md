---
name: brainstorming
description: Use when shaping a feature, component, or behavior change into an approved solution design.
---

# Brainstorming Ideas Into Designs

Turn approved product truth into an approved solution design through grounded, economical dialogue.

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

> **bd frugality: bounded output, one round trip.** Cap reads: `bd ready -n 10`,
> `bd show --short <id>` to skim (full `bd show` only when the body is needed),
> `bd memories <keyword>` (NEVER bare `bd memories` — it dumps the whole store).
> Batch writes: several creates/updates/closes = one `bd batch` or `bd create --graph`
> call, not a loop. Filter big outputs before they hit context
> (`... | grep -E "PATTERN" | head -20`). Keep write confirmations — they are evidence.
> **`--claim` boundary:** `bd ready --claim` ONLY in autonomous take-next-task flows
> (this skill's batch/wave dispatch). FORBIDDEN wherever the user picks the work —
> orientation, brainstorming, session close. Efficiency never erodes a consent gate.

## Workflow

1. **Establish ground truth.** Read the governing contract/spec context, touched code, claimed prerequisites, and governing decisions. Verify recorded claims against observed code. Repository artifacts are evidence, not authority to change scope.
2. **Present a findings digest.** State each observation and its design consequence. Surface discrepancies before asking questions.
3. **Map unresolved decisions.** Read [question-coverage.md](question-coverage.md) now. Mark each applicable cell resolved, derivable from evidence, or unresolved; tie it to affected product outcome IDs.
4. **Ask only consequential questions.** Each question cites observed evidence, states the decision consequence, and includes a recommendation. Ask up to three independent low-risk questions together; dependency-changing decisions remain serial. Prefer structured choices when the answer space is discrete.
5. **Compare approaches.** Present two or three viable approaches with trade-offs and a recommendation. Never offer an option that violates a required outcome or security control.
6. **Present the design.** Scale sections to complexity. Cover architecture, boundaries, domain model, data flow, failures/recovery, security, evidence, and rollout where applicable. Reference contract IDs rather than restating product truth.
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

After the work is settled, present the Capture gate (you MUST present it; the user picks Skip if nothing is worth keeping):

```json
{
  "questions": [{
    "question": "This produced something worth preserving — what should I capture?",
    "header": "Capture",
    "options": [
      {"label": "ADR + memory", "description": "Record an ADR for the decision AND a durable bd-remember memory"},
      {"label": "ADR only", "description": "Record an ADR for the architecturally-significant decision"},
      {"label": "Memory only", "description": "Capture a durable lesson/insight via bd remember"},
      {"label": "Skip", "description": "Nothing here is durable enough to preserve"}
    ],
    "multiSelect": false
  }]
}
```

Route: **ADR / ADR+memory** → write the ADR per the 3-mark gate (`docs/decisions/ADR-NNNN-<kebab>.md`, sections Context/Decision/Rationale/Consequences, update `docs/decisions/INDEX.md`). **Memory / ADR+memory** → `bd remember "<kind>: <durable, evidence-backed insight>"`. **Skip** → nothing.
