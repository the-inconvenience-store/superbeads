---
name: writing-skills
description: Use when creating, editing, pruning, or behaviorally testing an agent skill.
---

# Writing Skills

Skill authoring is test-driven process design: make agent behavior fail, change the smallest instruction that addresses the failure, then prove the behavior converges.

**Required background:** use `superbeads:test-driven-development` for the RED-GREEN-REFACTOR discipline.

## Trigger / Non-trigger

Use this skill for new skills, behavioral changes to existing skills, description/trigger changes, progressive disclosure, or pruning that could alter agent behavior.

Put one-project conventions in project instructions, enforce mechanical constraints in code or guards, and keep one-off solutions out of the skill catalogue.

**Iron law: NO SKILL WITHOUT A FAILING TEST FIRST.** For an edit, the failing test demonstrates the desired behavior is absent or the current structure violates a measurable contract.

## Inputs

Establish:

- target skill and actor;
- invocation conditions and non-triggers;
- observed baseline failure, pressure, or structural violation;
- required behavior and checkable completion criterion;
- host/tool constraints; and
- affected tests, references, and shared-policy owners.

## Steps

1. **RED — expose the failure.** Add the smallest realistic scenario or deterministic contract that fails for the intended reason. Include a no-guidance control for wording experiments and use fresh context for each behavioral sample. Complete when the failure and its evidence are reproducible.
2. **Classify the failure.** Distinguish invocation failure, omitted structure, wrong output shape, rule-breaking under pressure, missing reference, and stale/duplicated prose. Choose the matching intervention: trigger, required field, positive recipe, hard guardrail, context pointer, or deletion. Complete when one failure class and one target behavior are named.
3. **Design the information hierarchy.** Read [information-architecture.md](information-architecture.md) now. Keep ordered actions and must-have gates in `SKILL.md`; move branch-only reference behind a precise conditional pointer; assign every meaning one owner. Complete when every retained section has a rung, branch, and owner.
4. **GREEN — write the minimum binding change.** Model-invoked descriptions state invocation conditions and begin `Use when` or `Use before`; user-invoked descriptions are short, human-facing, and trigger-free. The body owns execution. Prefer a positive target and checkable shape. Keep prohibitions for demonstrated discipline failures or unavoidable safety boundaries, paired with the desired action. Complete when the RED test passes without unrelated guidance.
5. **REFACTOR — close observed variance.** Run multiple fresh samples for behavioral wording, inspect every result, and tighten the form before adding prose. Delete duplication, sediment, and no-ops; preserve quality-bearing caveats by co-locating or disclosing them. Complete when results converge and existing contracts remain green.
6. **Verify deployment.** Run the skill's named tests, frontmatter/description lint, repository guards, and relevant host fixtures. For design, discipline, or judgment skills, weave the Production-Grade Doctrine and security floor into domain language. Complete when current evidence covers triggers, execution, completion, and non-regression.

## Completion

A skill change is complete only when:

- RED evidence predates the behavior change;
- GREEN and regression tests pass in fresh context;
- a model-invoked description contains triggers rather than workflow instructions, or a user-invoked description is a trigger-free label;
- every step has a checkable completion criterion;
- conditional reference is reachable through a condition-bearing pointer;
- each meaning has one owner and moved content has no orphaned requirement;
- host/tool syntax is platform-correct; and
- verification evidence is current.

## Routing

- Skill behavior failure → create or extend a deterministic contract/microtest first.
- Pressure/rationalization testing → read `testing-skills-with-subagents.md`.
- Platform packaging or schema uncertainty → read `anthropic-best-practices.md` and the target host's official specification.
- Unexpected test behavior → `superbeads:systematic-debugging`.
- Completion claim → `superbeads:verification-before-completion`.

## Conditional References

- Read [information-architecture.md](information-architecture.md) before restructuring, splitting, pruning, or changing descriptions.
- Read `testing-skills-with-subagents.md` only when designing behavioral or pressure fixtures.
- Read `persuasion-principles.md` only when an observed discipline failure needs a rationalization counter.
- Read `graphviz-conventions.dot` only when a non-obvious decision or loop materially benefits from a diagram.
- Read `anthropic-best-practices.md` only for platform-specific authoring or packaging questions.

When this workflow closes after producing durable insights, read [Durable Memory](../using-superpowers/references/session-policy.md#durable-memory) and apply it; otherwise do not load it.
