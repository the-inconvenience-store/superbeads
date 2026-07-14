---
name: writing-plans
description: Use when you have a spec or requirements for a multi-step task, before touching code
---

# Writing Plans

## Overview

Write comprehensive implementation plans assuming the engineer has zero context for our codebase and questionable taste. Document everything they need to know: which files to touch for each task, code, testing, docs they might need to check, how to test it. Give them the whole plan as bite-sized tasks. DRY. YAGNI. TDD. Frequent commits.

Assume they are a skilled developer, but know almost nothing about our toolset or problem domain. Assume they don't know good test design very well.

**Announce at start:** "I'm using the writing-plans skill to create the implementation plan."

**Production-Grade Doctrine:** every spec requirement MUST map to a task — a deliberate cut is surfaced as a tracked decision, never a silent omission. Never weaken, bypass, or remove a security control — a security regression is never acceptable.

**Context:** This should be run in a dedicated worktree (created by brainstorming skill).

**Save graph plans to:** `docs/plans/YYYY-MM-DD-<feature-name>.graph.json`

- (User preferences for graph location override this default)

## Scope Check

If the spec covers multiple independent subsystems, it should have been broken into sub-project specs during brainstorming. If it wasn't, suggest breaking this into separate plans — one per subsystem. Each plan should produce working, testable software on its own.

## Outcome Trace

Before decomposing tasks, copy the spec's stable acceptance IDs into an outcome
trace. For each ID record:

`persona | starting route/interface | action | durable result | find-again/use path | failure/denied state | required evidence class | owning task/gate`

If the spec has user-facing or durable behavior but no outcome contract, stop
and return to brainstorming. Do not invent a task graph that can be locally green
while the product journey is undefined.

Rules:

- Every acceptance ID MUST have an owning task and a final acceptance gate.
- Every task `## Context` MUST list the acceptance IDs it enables or protects.
- Unit tests, CI, conformance, static review, direct API calls, browser/live,
  persistence, security, and rollback are distinct evidence classes. One does
  not substitute for another named by the spec.
- Decompose by vertical outcome where practical. Foundation tasks are allowed,
  but the plan MUST reach a live vertical seam early, before building breadth.
- Do not postpone first integration contact until the last task after a long run
  of locally verified components. Add outcome checkpoints after seam-changing
  batches and a final independent outcome review.
- A scope cut names the affected acceptance IDs and requires explicit user
  approval. A request to open a PR, run CI, or start follow-up work is not
  approval to remove unfinished IDs.

## Verify Before You Write

Every path, command, signature, and data shape in a task description must have
been OBSERVED this session, not recalled from the spec or memory. Before writing
task descriptions:

- Run the actual test/build targets (`project.json`, `package.json`, justfile) —
  never guess command syntax.
- Open the files each task modifies; confirm line numbers, exported names, and
  the shapes tasks consume/produce.
- Read the most recent prior graph plan and match its conventions.
- Re-verify any spec claim about landed prerequisites that execution depends on.

A plan step citing a command that was never run, or a type never read, is a
placeholder wearing a costume — same failure class as "TBD".

## File Structure

Before defining tasks, map out which files will be created or modified and what each one is responsible for. This is where decomposition decisions get locked in.

Search for prior decisions, designs, or plan memories touching the feature area before locking in decomposition: `bd memories <keyword>`.

- Design units with clear boundaries and well-defined interfaces. Each file should have one clear responsibility.
- You reason best about code you can hold in context at once, and your edits are more reliable when files are focused. Prefer smaller, focused files over large ones that do too much.
- Files that change together should live together. Split by responsibility, not by technical layer.
- In existing codebases, follow established patterns. If the codebase uses large files, don't unilaterally restructure - but if a file you're modifying has grown unwieldy, including a split in the plan is reasonable.

This structure informs the task decomposition. Each task should produce self-contained changes that make sense independently.

## Task Right-Sizing

A task is the smallest unit that carries its own test cycle and is worth a
fresh reviewer's gate. When drawing task boundaries: fold setup,
configuration, scaffolding, and documentation steps into the task whose
deliverable needs them; split only where a reviewer could meaningfully
reject one task while approving its neighbor. Each task ends with an
independently testable deliverable.

In beads terms, a right-sized task is one bead (`bd create -t task --parent <epic-id>`): claimable, verifiable, and closeable on its own.

## Bite-Sized Task Granularity

**Each step is one action (2-5 minutes):**

- "Write the failing test" - step
- "Run it to make sure it fails" - step
- "Implement the minimal code to make the test pass" - step
- "Run the tests and make sure they pass" - step
- "Commit" - step

## Graph Plan Structure

Write a bd graph JSON file with one epic node, one task node per task, and dependency edges between tasks.

```json
{
  "nodes": [
    {
      "key": "epic1",
      "title": "Epic: <feature name>",
      "type": "epic",
      "priority": 2,
      "description": "<goal, architecture, tech stack, global constraints>\n\n## Outcome Trace\n- <acceptance-id>: <journey and required evidence class>\n\n## Success Criteria\n- <measurable outcome copied from the goal>"
    },
    {
      "key": "t1",
      "title": "Task 1: <component name>",
      "type": "task",
      "priority": 2,
      "parent_key": "epic1",
      "description": "<summary>\n\n## Context\n- Spec: `docs/specs/<spec-file>.md`\n- Outcome IDs: <stable acceptance IDs>\n- External ref: <GitHub/Jira/Linear/URL or \"None\">\n- Why this task exists: <requirement, user need, or risk it resolves>\n- Relevant constraints: <compatibility, security, performance, migration, repo conventions>\n\n## Files\n- Create: `exact/path/to/file.py`\n- Modify: `exact/path/to/existing.py:123`\n- Test: `tests/exact/path/to/test.py`\n\n## Interfaces\n- Consumes: <exact signatures and types>\n- Produces: <exact signatures and types>\n\n## Acceptance Criteria\n- <observable, testable outcome and evidence class>\n\n## Skills\n- <skill-name>: use when <trigger>; helps because <task-specific reason>\n\n## Steps\n1. Write the failing test: <exact test code or command>\n2. Run it to verify it fails: `<command>`; expected: <failure>\n3. Implement the minimal code: <exact code or file edits>\n4. Run it to verify it passes: `<command>`; expected: PASS\n5. Commit: `git add ... && git commit -m \"...\"`"
    },
    {
      "key": "t2",
      "title": "Task 2: <next component>",
      "type": "task",
      "priority": 2,
      "parent_key": "epic1",
      "description": "<summary>\n\n## Context\n- Spec: `docs/specs/<spec-file>.md`\n- External ref: <GitHub/Jira/Linear/URL or \"None\">\n- Why this task exists: <requirement, user need, or risk it resolves>\n- Relevant constraints: <compatibility, security, performance, migration, repo conventions>\n\n## Files\n- Modify: `exact/path/to/file.py`\n- Test: `tests/exact/path/to/test.py`\n\n## Interfaces\n- Consumes: <outputs from Task 1>\n- Produces: <exact signatures and types>\n\n## Acceptance Criteria\n- <observable, testable outcome>\n\n## Skills\n- <skill-name>: use when <trigger>; helps because <task-specific reason>\n\n## Steps\n1. Write the failing test: <exact test code or command>\n2. Run it to verify it fails: `<command>`; expected: <failure>\n3. Implement the minimal code: <exact code or file edits>\n4. Run it to verify it passes: `<command>`; expected: PASS\n5. Commit: `git add ... && git commit -m \"...\"`"
    }
  ],
  "edges": [{ "from_key": "t2", "to_key": "t1", "type": "blocks" }]
}
```

**Graph contract:**

- `key` values are stable within the file (`epic1`, `t1`, `t2`, ...).
- Every task node has `parent_key: "epic1"`.
- Edge direction: `from_key` is the dependent task; `to_key` is the prerequisite task. `{"from_key":"t2","to_key":"t1","type":"blocks"}` means Task 2 waits for Task 1.
- The graph schema has no separate criteria field. `bd lint` requires `## Success Criteria` in the epic's `description` and `## Acceptance Criteria` in each task's `description`.
- The graph schema does not import separate `acceptance`, `context`, `skills`, `spec-id`, or `external-ref` fields. Put them in markdown sections inside `description`.
- The graph JSON is the plan of record. Put the complete task plan in each task node's `description`; do not rely on a separate markdown plan body to carry implementation details.
- Put all implementation detail in task descriptions. A task's implementer sees only that bead via `bd show <task-id>`; include context, files, interfaces, exact test commands, exact expected outputs, skills to use, and concrete steps.

## Task Description Contract

Each task description MUST contain the full implementation plan for that task, in this order:

1. Opening summary: what this task changes and the user-visible or system-visible outcome.
2. `## Context`: spec path, stable outcome IDs, external reference, why this task exists, and constraints the implementer must preserve.
3. `## Files`: exact files to create, modify, and test.
4. `## Interfaces`: exact functions, commands, schemas, types, flags, data shapes, or contracts consumed and produced.
5. `## Acceptance Criteria`: externally observable done conditions.
6. `## Skills`: task-specific skills to invoke, when, and why. Omit this section only when no task-specific skill applies.
7. `## Steps`: bite-sized RED-GREEN-REFACTOR implementation steps with exact code, exact commands, and expected output.

The sections below define how to write the parts that are easy to under-specify. They add to the full task plan; they do not replace `## Files`, `## Interfaces`, or `## Steps`.

### Files

Name every file path the implementer needs before they start.

- `Create:` new files, with purpose.
- `Modify:` existing files, with line numbers when known.
- `Test:` exact test files or fixtures.
- `Reference:` files to read for local patterns, only when they materially help.

### Interfaces

Write the contracts the task must preserve or create.

- Include exact function signatures, CLI flags, config keys, JSON shapes, database fields, events, or component props.
- State what comes from earlier tasks and what later tasks will consume.
- If a name is invented by this task, define it here once and reuse it consistently in later tasks.

### Acceptance Criteria

Write acceptance criteria as externally observable outcomes, not implementation chores.

- Start each bullet with a verifiable result: "Given/When/Then", "The command returns...", "The UI shows...", "The API rejects...".
- Include success and important failure cases from the spec.
- Tie each criterion to a test, command, lint check, or user-visible behavior.
- Avoid vague criteria such as "works correctly", "handles edge cases", "is robust", or "tests are added".

### Context

Use `## Context` to preserve the fields the graph importer cannot store separately.

- `Spec:` exact path to the spec or requirements document.
- `Outcome IDs:` stable acceptance IDs this task enables or protects; use `None — internal-only` only with a reason.
- `External ref:` issue URL, ticket ID, design doc URL, upstream PR, or `None`.
- `Why this task exists:` the requirement, user need, bug, risk, or dependency this bead satisfies.
- `Relevant constraints:` security rules, compatibility requirements, migrations, performance budgets, feature flags, repo conventions, and upstream decisions the implementer must not rediscover.

Context should explain why the task exists and what boundaries matter. Put instructions for changing code in `## Steps`, not here.

### Skills

Before writing task descriptions, inspect the skills available in the current agent environment. For each task, include a `## Skills` section listing every skill that would materially help that task.

Use skill names only; do not use `@` links or file paths that force-load skill bodies. Each bullet states when to invoke the skill and why it matters for this task:

```markdown
## Skills

- superbeads:test-driven-development: use before implementation; this task changes behavior and needs a failing test first.
- superbeads:systematic-debugging: use if the regression test fails for an unexpected reason; this task touches flaky initialization code.
```

If no task-specific skill applies, do not include the Skills section.

### Steps

Steps are the executable plan. They must be specific enough that a fresh implementer can follow them without reopening the original spec.

- Start with the failing test or verification that proves the missing behavior.
- Include exact commands and expected failure/pass output.
- Include code snippets for non-trivial edits; do not say "implement X" without showing the intended shape.
- End with verification and a commit command.

## Create Beads

After writing the graph JSON file, create the beads before asking for review:

```bash
bd create --graph docs/plans/YYYY-MM-DD-<feature-name>.graph.json
```

Record the created epic ID and child task IDs from the command output. If `--graph` is unavailable, fall back to sequential `bd create` for the epic and each task, then wire dependencies with `bd dep add`; keep the same descriptions and criteria sections.

> **bd frugality: bounded output, one round trip.** Cap reads: `bd ready -n 10`,
> `bd show --short <id>` to skim (full `bd show` only when the body is needed),
> `bd memories <keyword>` (NEVER bare `bd memories` — it dumps the whole store).
> Batch writes: several creates/updates/closes = one `bd batch` or `bd create --graph`
> call, not a loop. Filter big outputs before they hit context
> (`... | grep -E "PATTERN" | head -20`). Keep write confirmations — they are evidence.
> **`--claim` boundary:** `bd ready --claim` ONLY in autonomous take-next-task flows
> (this skill's batch/wave dispatch). FORBIDDEN wherever the user picks the work —
> orientation, brainstorming, session close. Efficiency never erodes a consent gate.

## No Placeholders

Every step must contain the actual content an engineer needs. These are **plan failures** — never write them:

- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" / "add validation" / "handle edge cases"
- "Write tests for the above" (without actual test code)
- "Similar to Task N" (repeat the code — the engineer may be reading tasks out of order)
- Steps that describe what to do without showing how (code blocks required for code steps)
- References to types, functions, or methods not defined in any task

## Remember

- Exact file paths always
- Complete code in every step — if a step changes code, show the code
- Exact commands with expected output
- DRY, YAGNI, TDD, frequent commits

## Self-Review

After creating the beads, look at the spec with fresh eyes and check the bead graph against it. This is a checklist you run yourself — not a subagent dispatch.

**0. Deterministic checks:** Run these commands and fix anything they flag before proceeding to the judgment checks below:

```bash
bd lint <epic-id>                                                      # required-section check on the epic
bd list --parent <epic-id> --json | jq -r '.[].id' | xargs -n1 bd lint # same check on each child task
bd ready --parent <epic-id> --explain                                  # confirm dependency ordering
```

**1. Spec coverage:** Skim each requirement in the spec. Every one MUST map to a task bead — point to it. A requirement with no task bead is either added as a task bead or surfaced to the user as an explicit, acknowledged cut. Silent omission is a plan failure.

**2. Full-plan payload:** Check every child task bead description contains `## Context`, `## Files`, `## Interfaces`, `## Acceptance Criteria`, and `## Steps`. If a task needs task-specific skills, it also contains `## Skills`. Missing sections mean the plan was not written into the bead graph; fix the graph JSON and bead descriptions before review.

**3. Placeholder scan:** Search the graph JSON and created bead descriptions for red flags — any of the patterns from the "No Placeholders" section above. Fix them.

**4. Type consistency:** Do the types, method signatures, and property names you used in later tasks match what you defined in earlier tasks? A function called `clearLayers()` in Task 3 but `clearFullLayers()` in Task 7 is a bug.

**5. Outcome coverage:** For every acceptance ID in the epic's `## Outcome Trace`, point to its implementation task, earliest integrated seam check, and final evidence gate. No orphaned IDs. Check that durable objects have create, find, view, refine/edit, use, permission/error, and archive/undo coverage or an explicitly approved scope cut.

**6. Integration latency:** Identify the first task that proves each cross-service or user-facing seam in its real environment. If decisive integration is deferred until the final task after substantial breadth, restructure the graph to prove a thin vertical slice earlier.

**7. Non-substitution:** Confirm each final gate names the exact required evidence classes and states that `FAIL`, `BLOCKED`, `SKIPPED`, or `NOT_RUN` keeps the gate open. CI or lower-level tests cannot replace required live evidence.

If you find issues, fix the graph JSON and the created beads. No need to re-review — just fix and move on. If you find a spec requirement with no task, add the task bead.

## User Review Gate

After self-review passes, summarize the created epic and task beads, then gate progression with your structured question tool (content below; shape shown in Claude Code schema — adapt to your tool):

```json
{
  "questions": [
    {
      "question": "Plan beads created under `<epic-id>`. Review the task breakdown and let me know how to proceed.",
      "header": "Plan review",
      "options": [
        {
          "label": "Approved + stress-test (Recommended)",
          "description": "Plan looks good — run an adversarial stress-test before execution"
        },
        {
          "label": "Approved",
          "description": "Plan looks good — skip stress-test and proceed to choose execution method"
        },
        {
          "label": "Needs changes",
          "description": "I want to revise the plan before proceeding"
        }
      ],
      "multiSelect": false
    }
  ]
}
```

Route on the answer:

- **Approved + stress-test** → invoke the `stress-test` skill with the epic bead ID and graph JSON path as the target; when it completes, proceed to **Execution Handoff**.
- **Approved** → proceed to **Execution Handoff** directly.
- **Needs changes** → update the graph JSON and beads, then re-run the self-review. Only proceed once approved.

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

## Execution Handoff

After the plan is approved, **use your structured question tool** to offer the execution choice:

```json
{
  "questions": [
    {
      "question": "Plan beads are ready. How would you like to execute them?",
      "header": "Execution",
      "options": [
        {
          "label": "Subagent-Driven (Recommended)",
          "description": "Fresh subagent per task with a single task review between tasks — fast iteration, high quality"
        },
        {
          "label": "Inline Execution",
          "description": "Execute tasks in this session using executing-plans — batch execution with checkpoints"
        }
      ],
      "multiSelect": false
    }
  ]
}
```

**If Subagent-Driven chosen:**

- **REQUIRED SUB-SKILL:** Use superbeads:subagent-driven-development
- Pass the epic bead ID and graph JSON path forward
- Fresh subagent per task + single task review (spec + quality verdicts)

**If Inline Execution chosen:**

- **REQUIRED SUB-SKILL:** Use superbeads:executing-plans
- Pass the epic bead ID and graph JSON path forward
- Batch execution with checkpoints for review

## Integration

**Called by:** **brainstorming** — this is brainstorming's terminal state. After design approval, brainstorming invokes writing-plans.

**Invokes:**

- **subagent-driven-development** — execution handoff (user choice).
- **executing-plans** — execution handoff (user choice).

**Pairs with:** **stress-test** — offered at the plan-review gate every time (the "Approved + stress-test" option), before execution.
