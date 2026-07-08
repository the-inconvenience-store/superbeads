---
name: using-superpowers
description: Use when starting any conversation - establishes how to find and use skills, requiring Skill tool invocation before ANY response including clarifying questions
---

<SUBAGENT-STOP>
If you were dispatched as a subagent to execute a specific task, ignore this skill.
</SUBAGENT-STOP>

<EXTREMELY-IMPORTANT>
If you think there is even a 1% chance a skill might apply to what you are doing, you ABSOLUTELY MUST invoke the skill.

IF A SKILL APPLIES TO YOUR TASK, YOU DO NOT HAVE A CHOICE. YOU MUST USE IT.

This is not negotiable. You cannot rationalize your way out of this.
</EXTREMELY-IMPORTANT>

## The Rule

**Invoke relevant or requested skills BEFORE any response or action** — including clarifying questions, exploring the codebase, or checking files. If it turns out wrong for the situation, you don't have to use it.

**Before entering plan mode:** if you haven't already brainstormed, invoke the brainstorming skill first.

Then announce "Using [skill] to [purpose]" and follow the skill exactly. If it has a checklist, track it with beads (see Beads below) — TodoWrite is forbidden.

## Skill Priority

When multiple skills apply, process skills come first — they set the approach, then implementation skills carry it out.

- "Let's build X" → superbeads:brainstorming first, then implementation skills.
- "Fix this bug" → superbeads:systematic-debugging first, then domain skills.

## Red Flags

These thoughts mean STOP — you're rationalizing:

| Thought | Reality |
|---------|---------|
| "Simple question / need context / quick file check first" | Action = task. Check skills first. |
| "This doesn't need a formal skill" | If a skill exists, use it. |
| "The skill is overkill" | Simple things become complex. Use it. |
| "I remember it / know what it means" | Skills evolve. Read current version. |

## Production-Grade Doctrine

Treat every project as production. No silent shortcuts, descopes, material-risk trade-offs, or security regressions. See `references/bootstrap-policy.md`.

## Capturing Decisions

For hard-to-reverse, surprising trade-offs, offer an ADR in `docs/decisions`; never auto-create. See `references/bootstrap-policy.md`.

## Beads

`bd` (beads) is the task tracker for ALL work — TodoWrite is forbidden, as are TaskCreate and markdown TODOs. The session hook injects composed beads context (curated memories + workflow pointer) at session start; if none was injected this session, run `bd prime`. Only the orchestrating agent manages beads — subagents never touch them. Include bead IDs in commit messages. Session close = land the plane: `bd close` → `bd dolt push` → `git pull --rebase && git push` → `git status`.

## Platform Adaptation

If your harness appears here, read its reference file for special instructions:

- Codex: `references/codex-tools.md`
- OpenCode: `references/opencode-tools.md`
- Copilot CLI: `references/copilot-tools.md`
- Pi: `references/pi-tools.md`
- Antigravity: `references/antigravity-tools.md`

## Asking the User

When a skill says to ask or present options, use the harness's structured question tool if available; otherwise print numbered options and STOP. Tool errors, skips, dismissals, or auto-resolutions are not consent. See `references/bootstrap-policy.md`.

## User Instructions

User instructions (CLAUDE.md, AGENTS.md, etc, direct requests) take precedence over skills, which in turn override default behavior. Only skip skill workflows or instructions when your human partner has explicitly told you to.
