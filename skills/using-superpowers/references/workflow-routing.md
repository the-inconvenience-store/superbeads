# Workflow Routing

Read this reference when resuming or advancing substantial work that already has durable workflow artifacts. The router validates phase order; it does not replace artifact approval, tracker evidence, or the user's execution-mode choice.

Build `.internal/workflow-state.json` from current artifact revisions and bounded Beads reads, never from recalled chat. It has schema version 1 and exactly these statuses:

- `research`: `missing | complete | not_required | blocked`
- `product_contract`, `design`, `stress_test`, `plan`: `missing | approved | not_required | blocked`
- `execution`: `not_started | in_progress | complete | blocked`
- `acceptance`: `not_started | pass | fail | blocked`
- `human_review`: `missing | approved | not_required | blocked`; `not_required` is the current gate result for an approved bypass, not an early policy guess

Run:

```bash
python3 "$PWD/skills/using-superpowers/scripts/workflow-route.py" .internal/workflow-state.json
```

Use only the returned `next_skill`. A nonzero result means the snapshot claims an impossible phase order; reconcile the governing artifacts instead of choosing a phase conversationally. When execution has not started, the returned subagent route is the preferred capable-host default; honor an explicit user choice of inline execution.
