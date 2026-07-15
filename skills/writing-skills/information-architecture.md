# Skill Information Architecture

This local reference adopts the relevant principles from Matt Pocock's [Writing Great Skills](https://raw.githubusercontent.com/mattpocock/skills/refs/heads/main/skills/productivity/writing-great-skills/SKILL.md) and [Glossary](https://raw.githubusercontent.com/mattpocock/skills/refs/heads/main/skills/productivity/writing-great-skills/GLOSSARY.md). It summarizes the concepts used by Superbeads rather than duplicating those documents.

## Predictability

The target is **predictability of process**, not identical output. A strong skill makes the agent take the same evidence-bearing path while leaving judgment and creative output free to vary.

## Invocation and Description

A model-visible description is the catalogue's first context pointer. In this repository it states invocation conditions, begins `Use when` or `Use before`, and keeps one trigger per genuinely distinct branch. A skill with `disable-model-invocation: true` instead uses a short human-facing, trigger-free label. Workflow steps stay in the body because a process summary in frontmatter can become a shortcut around the skill.

Use leading words that users and repository artifacts naturally use. Remove synonym lists that rename one trigger. Splitting a skill adds catalogue context load, so split for an independently useful trigger or a real context boundary, not merely because a file is long.

## Information Hierarchy

Rank content by when it is needed:

1. **In-skill steps** — ordered actions on the primary path.
2. **In-skill reference** — rules or definitions every run may need.
3. **Disclosed reference** — branch-only material in a co-located file.

Progressive disclosure protects the primary path. Inline what every branch needs. Move branch-only details behind a **Context pointer** whose wording names the observable load condition. A target filename alone is not a condition; "read X when selecting repository-only mode" is.

Keep a concept's definition, constraints, and caveats together at its chosen rung. If must-have material is missed behind a pointer, sharpen the condition first; inline it only when behavioral evidence shows the pointer remains unreliable.

## Completion and Legwork

Every step needs a **Completion criterion** that distinguishes done from not-done. Demand enough evidence to force the required legwork: "every load-bearing claim cites decisive evidence" is stronger than "write findings." Sharp criteria resist premature completion without adding reminders.

Split by sequence only when an irreducibly fuzzy step is observably rushed because later steps remain visible. A heading in the same context does not hide later work; a genuine handoff or worker boundary does.

## Single Ownership and Pruning

Give each behavior a **Single source of truth**. A shared rule belongs to one semantic owner; callers retain only their local condition and pointer.

Audit retained prose with three tests:

- **Relevance:** does this still affect the skill's current behavior?
- **No-op:** does this sentence change behavior versus the model's default?
- **Duplication:** is this meaning already owned elsewhere?

Delete failed lines rather than polishing them. **Sediment** is stale content preserved because removal feels risky; protect quality with tests and ownership, not repetition.

## Steering

Use a **Positive target** for output shape and ordinary behavior: name the parts, order, and evidence the result contains. Negation makes the unwanted pattern salient. A prohibition earns space for a demonstrated discipline failure or non-negotiable safety boundary, and it should point immediately to the correct action.

Match form to failure:

| Failure | Binding form |
|---|---|
| Skill not invoked | Trigger description |
| Required element omitted | Required field/template slot |
| Output has wrong shape | Positive recipe or contract |
| Rule broken under pressure | Guardrail plus observed rationalization counter |
| Branch-only detail bloats main path | Conditional context pointer |
| Meaning drifts across files | Single owner plus enforcement |

## Architecture Check

Before GREEN, verify:

- the primary spine is trigger/non-trigger, inputs, ordered steps, completion, routing, and conditional references;
- every step ends in a checkable criterion;
- every branch-only reference has a condition-bearing pointer;
- every meaning has one owner;
- every retained sentence changes behavior or supplies necessary reference; and
- descriptions spend bytes on invocation, not execution.
