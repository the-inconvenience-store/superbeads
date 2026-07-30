# Codex Mode

Read this reference only when the controller is Claude Code and the user explicitly invokes `subagent-driven-development` in `codex` mode. The Claude controller remains the orchestrator; Codex CLI processes replace ordinary task workers without changing the SDD task graph, Context Manifest, review, integration, or acceptance contracts. A request made on another host does not activate this mode.

## Invariants

- The controller owns Beads, scheduling, worktree lifecycle, manifests, prompts, result validation, merges, reviews, corrections, and closure. Codex workers may use read-only Beads commands only where the role contract permits.
- One Codex process owns one task identity. It receives the same task bead, Context Manifest, worktree, and role contract that a default-mode worker would receive.
- Codex workers are leaf workers. Every initial and resumed launch disables Codex multi-agent tools with `--disable multi_agent`, and every prompt states that the worker must not spawn, delegate to, or launch another agent or `codex exec` process. If the assigned slice cannot be completed by that leaf, it returns `NEEDS_CONTEXT` or `BLOCKED`.
- Detecting a nested-agent attempt is a contract breach: stop the process, discard its result, preserve the evidence, and diagnose the task or prompt before redispatch. Never accept recursively produced work.
- The Production-Grade Doctrine and the skill's existing security, identity, correction, verification, and acceptance gates remain authoritative. Codex mode adds worker capacity; it does not add an alternate workflow or weaken a gate.

## Controller Preparation

Use the normal execution spine through manifest validation. For each selected task:

1. Claim the task bead and have the controller create its isolated worktree with `bd worktree create .worktrees/<task-id> --branch <branch>`. The controller later removes an approved and integrated worktree with `bd worktree remove <task-id>`; the Codex worker never runs either command.
2. Generate and validate `.internal/sdd/<task-id>-manifest.json` exactly as described by the main skill. Record truthful `model_requested`, `model_effective`, `model_control`, `capability_tier`, and `context_mode` values.
3. Create a controller-owned transport root at `.internal/sdd/<task-id>-codex/`, with one role directory such as `implementer/`, `task-review/`, or `outcome-review/`. These transport artifacts are not authoritative contracts and do not replace or extend the task bead, Context Manifest, role prompt, manifest-declared report, or commit diff. Each role directory contains only:
   - `prompt.md`: an stdin-ready rendering of the existing role contract;
   - `events.jsonl`: Codex transport evidence, including the session ID; and
   - `last-message.md`: the CLI-captured final response.
4. Build the role directory's `prompt.md` from `../implementer-prompt.md`, the manifest path, task ID, and worktree for implementation. Use `../task-reviewer-prompt.md` or `../outcome-reviewer-prompt.md` for the corresponding read-only review role. Do not paste the raw graph, planning history, controller transcript, or unrelated artifacts.
5. Append this leaf-worker clause to every role prompt:

```text
You are a leaf worker for exactly this role and task identity. Do not spawn,
delegate to, or invoke any agent, subagent, collaboration tool, or codex process.
Complete the assigned contract yourself. If it cannot be completed in this one
leaf context, return NEEDS_CONTEXT or BLOCKED with the exact reason.
```

Resolve the manifest, worktree, prompt, event, and output locations to absolute paths before launch so `--cd` and shell redirection cannot split one task's artifacts across directories. Preparation is complete when the manifest validates, the worktree and transport paths are task-specific, the prompt contains the leaf-worker clause, and the manifest records the effective model and task identity.

## Model and Launch Contract

| Model | Tier | SDD roles |
|---|---|---|
| `gpt-5.6-luna` | fast | mechanical, well-scoped read-only checks and per-file smoke checks |
| `gpt-5.6-terra` | workhorse — **default** | straightforward implementers, task reviewers, and routine outcome reviewers |
| `gpt-5.6-sol` | flagship | complex or security-sensitive implementers and complementary high-risk reviewers |

Pin the model and reasoning effort rather than inheriting mutable user defaults. Default to `gpt-5.6-terra` with `medium` effort unless the user or the table's task-risk boundary selects another model. Valid GPT-5.6 effort values are `low | medium | high | xhigh | max`; use the lowest adequate value, raise an individual worker to `high` or `xhigh` for genuinely difficult work, and reserve `max` for the single hardest worker rather than a fleet. Record the requested and effective model in the Context Manifest. Reasoning effort remains an explicit launch setting, not a second contract field.

Launch one background process per selected worker. Implementation uses its task worktree and `workspace-write`; task and outcome reviewers use `read-only`. Pass long prompts through stdin:

```bash
codex exec \
  --model <model> \
  --config model_reasoning_effort=<effort> \
  --config approval_policy=never \
  --disable multi_agent \
  --cd "<absolute-worktree>" \
  --sandbox workspace-write \
  --json \
  --output-last-message "<absolute-run-dir>/last-message.md" \
  - < "<absolute-run-dir>/prompt.md" \
  > "<absolute-run-dir>/events.jsonl"
```

For a read-only reviewer, change only `--sandbox read-only` and the role prompt/output directory. Do not use `--dangerously-bypass-approvals-and-sandbox`, `danger-full-access`, or raw Git worktree commands. Enable live web search only when the task contract requires external research and authorizes that source class.

Codex processes run concurrently only when [scheduling.md](scheduling.md) selects independent work and `superbeads:dispatching-parallel-agents` authorizes the wave. Use that skill's independence, prompt, and concurrency discipline, but replace its default Claude `Task(...)` examples with the Codex worker transport defined here. Preserve the repository's worktree cap for writing agents and the host's actual process limit; report bounded or failed coverage rather than silently dropping a selected worker. Codex mode does not add the upstream find/deduplicate/judge phases to an SDD implementation graph.


## Hard Limits

- Run at most 10 Codex agents concurrently. The repository's lower five-worktree cap still limits simultaneous writing agents.
- Before spawning, count live background processes and task worktrees. When either applicable limit is full, wait for completion and backfill the freed slot.

Wait for the process completion signal. Do not use shell sleep to poll the process,
event file, output file, or status. Record a phase budget before launch. A
`phase-overrun` permits one diagnostic inspection.

## Result and Correction Handling

Before using a result, the controller verifies all of the following:

- a launch receipt binds the task, contract hash, `codex_exec` transport, command-line
  model, context mode, Codex session, and `events.jsonl` SHA-256; run
  `sdd-manifest.py check-receipt --manifest MANIFEST --receipt RECEIPT --events
  EVENTS --expected-worker codex-cli`;
- the process exited successfully and `last-message.md` is non-empty;
- `events.jsonl` belongs to the recorded session and contains no nested-agent or nested-`codex exec` attempt;
- the worker emitted the required handshake before edits;
- the manifest report exists at its declared `.internal/sdd/` path;
- `sdd-manifest.py check-diff` passes for the exact task commit range; and
- the reported verification and changed files agree with observed evidence.

A failed launch may be retried once with the same identity and prompt after diagnosing the environmental failure. A correction may resume the recorded Codex session only when the six-part identity is unchanged and the main skill's correction gate permits reuse:

```bash
codex exec resume <session-id> \
  --model <model> \
  --config model_reasoning_effort=<effort> \
  --config approval_policy=never \
  --disable multi_agent \
  --json \
  --output-last-message "<absolute-run-dir>/last-message.md" \
  - < "<absolute-run-dir>/correction-prompt.md" \
  >> "<absolute-run-dir>/events.jsonl"
```

Append resumed events to that task's evidence bundle and record the correction lineage. Any identity change requires a fresh manifest, run directory, worktree binding, and Codex session. Review, integrate, close, and clean up through the main skill exactly as in default mode.

## Upstream Basis

This mode adapts the orchestration and non-interactive worker conventions from SouthLab AI's MIT-licensed [`ultracodex`](https://github.com/southlab-ai/Claude-Plugin-Marketplace/blob/bab2f78ba62e2d2f08598f18831474922a2af279/plugins/ultracodex/skills/ultracodex/SKILL.md) and [`codex-agent`](https://github.com/southlab-ai/Claude-Plugin-Marketplace/blob/bab2f78ba62e2d2f08598f18831474922a2af279/plugins/ultracodex/skills/codex-agent/SKILL.md) skills. Superbeads' graph, Beads, manifest, `bd worktree`, review-evidence, and non-recursive leaf-worker contracts take precedence here.
