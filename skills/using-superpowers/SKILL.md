---
name: using-superpowers
description: Use when a session starts and available skills must be selected before responding.
---

<SUBAGENT-STOP>
If you were dispatched as a subagent to execute a specific task, ignore this skill.
</SUBAGENT-STOP>

<EXTREMELY-IMPORTANT>
If there is even a 1% chance a skill applies, invoke it. Applicable skills are mandatory; do not rationalize around them.
</EXTREMELY-IMPORTANT>

## The Rule

**Invoke relevant or requested skills BEFORE any response or action** — including clarifying questions, exploring the codebase, or checking files. If it turns out wrong for the situation, you don't have to use it.

**Before entering plan mode:** if you haven't already brainstormed, invoke the brainstorming skill first.

Then announce "Using [skill] to [purpose]" and follow the skill exactly. If it has a checklist, track it with beads (see Beads below) — TodoWrite is forbidden.

When several skills apply, run process skills before implementation skills.

## Production-Grade Doctrine

Treat every project as production. No silent shortcuts, descopes, material-risk trade-offs, or security regressions. See `references/bootstrap-policy.md`.

## Capturing Decisions

For hard-to-reverse, surprising trade-offs, offer an ADR in `docs/decisions`; never auto-create. See `references/bootstrap-policy.md`.

## Beads

`bd` (beads) is the task tracker for ALL work — TodoWrite is forbidden, as are TaskCreate and markdown TODOs. The session hook injects composed beads context (curated memories + workflow pointer) at session start; if none was injected this session, run `bd prime`. Only the orchestrating agent manages beads — subagents never touch them. Include bead IDs in commit messages. When the session completes, read [Session Completion](references/session-policy.md#session-completion) and follow it.

Shared capture, memory, Beads economy, claim, routing (`scripts/workflow-route.py`), and completion policy lives in `references/session-policy.md`.

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
