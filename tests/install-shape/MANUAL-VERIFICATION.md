# Manual verification — what install-shape can NOT prove

`just shape` proves artifacts land where each harness expects. It does NOT prove hooks
fire. These checks are manual, by design (auth-gated or interactive):

| Check | Harness | How |
|---|---|---|
| SessionStart fires + `bd prime` injects | Claude Code | new session in a bd repo → context shows "Beads Workflow Context" |
| SessionStart fires (needs `codex_hooks = true`) | Codex | new session → bootstrap injected |
| Plugin bootstrap + compaction re-injection | OpenCode | new session; then compact → re-injection |
| Native plugin install works at all | Antigravity, Droid | auth-gated — run the hint command from a logged-in CLI |
| Native install hints are still correct | all Tier B | run the printed command against the live harness |
| Windows polyglot hook (`hooks/run-hook.cmd`) | Claude Code on Windows | out of suite scope — see `.internal/windows/` |

## Capability and evidence record

Installation shape, hook rendering, and live agent behavior are separate evidence classes.
Do not promote a shape or adapter result into behavioral acceptance. Every host campaign
records `model_requested`, `model_effective`, `model_control`, `capability_tier`,
`context_mode`, and `fallback_reason`.

| Host | Deterministic evidence | Live behavior evidence | Required fallback |
|---|---|---|---|
| Claude Code | Adapter output and hook fixtures | Not run in the 0.12.0 campaign; live Claude usage was forbidden | Record the model control as unavailable; never infer live product, review, or evidence-gate behavior |
| Codex | Codex install shape passes and hook output is covered by fixtures | Cost-gated; remains `UNTESTED` without separate authorization | Record inherited/effective model control and leave behavior outcomes open |
| OpenCode | Bootstrap and compaction hook fixtures | No isolated-worker behavior campaign is verified | Record `host-limited` capability/context and use serial execution |

The stable campaign record is `tests/fixtures/integration/workflow-outcomes.json`.
`bash tests/skills/test-workflow-outcomes.sh` validates its structure; adding
`--require-pass` is the release outcome gate and fails while any outcome is not `PASS`.
