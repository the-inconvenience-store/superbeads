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
