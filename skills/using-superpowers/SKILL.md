---
name: using-superpowers
description: Use when starting any conversation - establishes how to find and use skills, requiring Skill tool invocation before ANY response including clarifying questions
---

<SUBAGENT-STOP>
If you were dispatched as a subagent to execute a specific task, skip this skill.
</SUBAGENT-STOP>

<EXTREMELY-IMPORTANT>
If you think there is even a 1% chance a skill might apply to what you are doing, you ABSOLUTELY MUST invoke the skill.

IF A SKILL APPLIES TO YOUR TASK, YOU DO NOT HAVE A CHOICE. YOU MUST USE IT.

This is not negotiable. This is not optional. You cannot rationalize your way out of this.
</EXTREMELY-IMPORTANT>

## Instruction Priority

Superpowers skills override default system prompt behavior, but **user instructions always take precedence**:

1. **User's explicit instructions** (CLAUDE.md, GEMINI.md, AGENTS.md, direct requests) — highest priority
2. **Superpowers skills** — override default system behavior where they conflict
3. **Default system prompt** — lowest priority

If CLAUDE.md, GEMINI.md, or AGENTS.md says "don't use TDD" and a skill says "always use TDD," follow the user's instructions. The user is in control.

## Production-Grade Doctrine

Treat every project as a production-facing system with a large user base, where
defects cause real, consequential harm — financial loss, data loss, security
breach, broken trust. This holds **no matter how small, internal, or simple the
task looks.** "It's just a script / a demo / an internal tool" is the exact
rationalization that ships the worst defects.

So in all reasoning and judgment — most of all in **brainstorming** and
**stress-test**, where these choices are first made — you MUST NOT, on your own
initiative:

- **Take shortcuts** — the quick path that leaves work incomplete, fragile, or unverified.
- **Descope** — silently drop, defer, or trim a required behavior, edge case, or requirement to save effort or hit a deadline.
- **Accept a large / material-risk trade-off** — pick an approach whose downside, if it happens, is consequential.

These three are a **strong default you never override on your own.** If one is
genuinely warranted, you do not take it silently: **surface it — name it, state
the cost, and let the user decide.** A user may explicitly direct one; when they
do, name this doctrine and acknowledge the override before proceeding (see User
Instructions).

Above all three, one **hard floor**:

- **Never accept a security regression.** Never weaken, remove, or bypass a
  security control — auth, validation, sanitization, secrets handling,
  permissions, isolation — and never introduce a new vulnerability. (A regression
  *weakens* the existing posture or adds a new hole; merely touching
  security-relevant code, or a pre-existing issue your change doesn't worsen, is
  not a regression.) You never introduce one **on your own judgment** and **never
  silently** — not for convenience, a deadline, or "minimal changes," and never
  rationalized as "minor" or "temporary." If you spot one, stop and escalate. If
  a user explicitly directs it, do not just comply: state the risk plainly,
  recommend against it, and proceed only on their informed, explicit confirmation
  — recorded as a security decision the user owns. Your default and recommendation
  are always no.

This is a **floor, not a ceiling** — clearing it is the baseline for every piece
of work, not going above and beyond.

## Capturing Decisions

When an architecturally-significant decision is made — about approach, architecture, technology choice, or design pattern — capture it as an ADR (Architecture Decision Record). This is a norm, like the doctrine above: it applies wherever a decision or a pivot happens, not just at the design gates.

You MUST offer to record an ADR — don't let the rationale evaporate. A decision is significant when it is **hard to reverse** (meaningful cost to change course later), **surprising without context** (a future reader will ask "why this way?" — read generously: "would a competent future reader be puzzled," not "is it novel"), and **the result of a genuine trade-off**. Treat these as recognition marks, not a checklist to wriggle out of: when a decision plausibly fits, offer it. Recording is only an offer the user confirms (never auto-created), so **bias toward offering rather than skipping**, and never rationalize it away ("it's obvious", "I'll remember"). Routine clarifications and scope questions that don't clear the marks are not ADR-worthy.

**How:** write `decisions/ADR-NNNN-<kebab-title>.md` (next number = highest existing + 1) in the existing format (`# ADR-NNNN: Title`; bold `**Date:** / **Status:** / **Deciders:**`; then `## Context`, `## Decision`, `## Rationale`, `## Consequences`; optional `## Related`), then update `decisions/INDEX.md` (the `| ADR | Date | Status | Title |` table). The home is `decisions/` at the repo root — not a `docs/` subdirectory. ADRs are gitignored local working docs; do not `git add -f` them. A dispatched single-task subagent does not write ADRs — it surfaces the decision in its report, and the dispatching agent applies the gate and records it.

## How to Access Skills

**In Claude Code:** Use the `Skill` tool. When you invoke a skill, its content is loaded and presented to you—follow it directly. Never use the Read tool on skill files.

**In Copilot CLI:** Use the `skill` tool. Skills are auto-discovered from installed plugins. The `skill` tool works the same as Claude Code's `Skill` tool.

**In Gemini CLI:** Skills activate via the `activate_skill` tool. Gemini loads skill metadata at session start and activates the full content on demand.

**In other environments:** Check your platform's documentation for how skills are loaded.

## Platform Adaptation

Skills use Claude Code tool names. Non-CC platforms: see `references/codex-tools.md` (Codex), `references/copilot-tools.md` (Copilot CLI), `references/gemini-tools.md` (Gemini CLI), `references/opencode-tools.md` (OpenCode), `references/antigravity-tools.md` (Antigravity), and `references/pi-tools.md` (Pi) for tool equivalents. Gemini CLI users get the tool mapping loaded automatically via GEMINI.md.

# Using Skills

## The Rule

**Invoke relevant or requested skills BEFORE any response or action.** Even a 1% chance a skill might apply means that you should invoke the skill to check. If an invoked skill turns out to be wrong for the situation, you don't need to use it.

```dot
digraph skill_flow {
    "User message received" [shape=doublecircle];
    "About to EnterPlanMode?" [shape=doublecircle];
    "Already brainstormed?" [shape=diamond];
    "Invoke brainstorming skill" [shape=box];
    "Might any skill apply?" [shape=diamond];
    "Invoke Skill tool" [shape=box];
    "Announce: 'Using [skill] to [purpose]'" [shape=box];
    "Has checklist?" [shape=diamond];
    "Create beads (bd create) per item" [shape=box];
    "Follow skill exactly" [shape=box];
    "Respond (including clarifications)" [shape=doublecircle];

    "About to EnterPlanMode?" -> "Already brainstormed?";
    "Already brainstormed?" -> "Invoke brainstorming skill" [label="no"];
    "Already brainstormed?" -> "Might any skill apply?" [label="yes"];
    "Invoke brainstorming skill" -> "Might any skill apply?";

    "User message received" -> "Might any skill apply?";
    "Might any skill apply?" -> "Invoke Skill tool" [label="yes, even 1%"];
    "Might any skill apply?" -> "Respond (including clarifications)" [label="definitely not"];
    "Invoke Skill tool" -> "Announce: 'Using [skill] to [purpose]'";
    "Announce: 'Using [skill] to [purpose]'" -> "Has checklist?";
    "Has checklist?" -> "Create beads (bd create) per item" [label="yes"];
    "Has checklist?" -> "Follow skill exactly" [label="no"];
    "Create beads (bd create) per item" -> "Follow skill exactly";
}
```

## Red Flags

These thoughts mean STOP—you're rationalizing:

| Thought | Reality |
|---------|---------|
| "This is just a simple question" | Questions are tasks. Check for skills. |
| "I need more context first" | Skill check comes BEFORE clarifying questions. |
| "Let me explore the codebase first" | Skills tell you HOW to explore. Check first. |
| "I can check git/files quickly" | Files lack conversation context. Check for skills. |
| "Let me gather information first" | Skills tell you HOW to gather information. |
| "This doesn't need a formal skill" | If a skill exists, use it. |
| "I remember this skill" | Skills evolve. Read current version. |
| "This doesn't count as a task" | Action = task. Check for skills. |
| "The skill is overkill" | Simple things become complex. Use it. |
| "I'll just do this one thing first" | Check BEFORE doing anything. |
| "This feels productive" | Undisciplined action wastes time. Skills prevent this. |
| "I know what that means" | Knowing the concept ≠ using the skill. Invoke it. |

## Skill Priority

When multiple skills could apply, use this order:

1. **Process skills first** (brainstorming, debugging) - these determine HOW to approach the task
2. **Implementation skills second** (frontend-design, mcp-builder) - these guide execution

"Let's build X" → brainstorming first, then implementation skills.
"Fix this bug" → debugging first, then domain-specific skills.

## Skill Types

**Rigid** (TDD, debugging): Follow exactly. Don't adapt away discipline.

**Flexible** (patterns): Adapt principles to context.

The skill itself tells you which.

## User Instructions

Instructions say WHAT, not HOW. "Add X" or "Fix Y" doesn't mean skip workflows.

**Skill override acknowledgment:** If the user asks to skip a skill that would normally apply, name the skill being skipped and acknowledge the override before proceeding (e.g., "The brainstorming skill would normally apply here, but you've asked to skip design exploration").

## Beads Issue Tracking

This skills system uses **bd (beads)** for persistent task tracking across sessions. Beads replaces TodoWrite, TaskCreate, and markdown TODO lists.

### Key Concepts

- **Epic Bead**: Each plan or brainstorming session creates an epic bead. All tasks are children of the epic.
- **Bead Lifecycle**: `open` → `in_progress` (via `--claim`) → `closed` (via `bd close`)
- **The Ledger**: The beads database is the project ledger — persistent, auditable, version-controlled via Dolt.
- **Dependency Chain**: Tasks with dependencies use `bd dep add <child> <depends-on>`.
- **Memories**: Use `bd remember "lesson: <durable, evidence-backed insight>"` for persistent learnings — capture durable, evidence-backed facts only; never secrets/PII (every memory is injected into future sessions).

### Quick Reference

| Action | Command |
|--------|---------|
| Create epic bead | `bd create "Epic: feature name" -t epic -p 2` |
| Create task bead | `bd create "Task: title" -t task --parent <epic-id>` |
| Quick capture (scripting) | `bd q "title"` |
| Claim work | `bd update <id> --claim` |
| Complete work | `bd close <id> --reason "description"` |
| Check remaining work | `bd ready --parent <epic-id>` |
| Show blocked issues | `bd blocked` |
| Compound query (replaces list+jq) | `bd query "status=open AND priority<=1"` |
| Count, grouped | `bd count --by-status` (or `--by-priority`/`--by-type`) |
| Epic completion status | `bd epic status <id>` |
| Add dependency | `bd dep add <child-id> <depends-on-id>` |
| View dependency tree | `bd dep tree <epic-id>` |
| Store a learning | `bd remember "lesson: <durable insight>"` |
| Remove stale memory | `bd forget <id>` |
| Search memories | `bd memories <keyword>` |
| Recall specific memory | `bd recall <id>` |
| Append note to bead | `bd note <id> "context"` |
| Find duplicate beads | `bd find-duplicates` |
| Sync to remote | `bd dolt push` |

**Efficient bead creation:**

- Creating an epic with child tasks/deps → you SHOULD use `bd create --graph <plan.json>` (atomic; `--dry-run` first; prevents orphaned beads on mid-sequence failure). A standalone bead MAY use plain `bd create`.
- Every bead you create MUST carry an actionable description — *why it exists and what "done" looks like* — not a bare title. Use `--acceptance "<criteria>"` for done-criteria and `--validate` to check.
- Wire dependency chains atomically with `bd batch`; `--silent` returns just the ID (scripting); `--body-file`/`--design`/`--notes` carry rich context.

### Rules

- Use `bd` for ALL task tracking. Do NOT use TodoWrite, TaskCreate, or markdown TODO lists.
- Only the orchestrating agent manages beads. Subagents (implementer, spec-reviewer, code-quality-reviewer) do NOT touch beads.
- Every session ends with the Land the Plane protocol: `bd close` → `bd dolt push` → `git push` → `git status`.
- Include bead IDs in commit messages: `git commit -m "Add feature X (bd-a1b2)"`

## Integration

**Invoked by:** `session-start` hook — auto-injected at session start. All other skills depend on this one having loaded first.

**Invokes:** None explicitly. Routes to all skills via the "if even 1% chance a skill applies, invoke it" gate. The only skill explicitly named in the flowchart is **brainstorming** (checked before general skill matching).
