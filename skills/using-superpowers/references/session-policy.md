# Session Policy

This is the semantic owner for workflow-wide session policy. Skills keep only the smallest rule needed at their decision point and route branch procedure here.

## Capture Gate

After design, research, debugging, or planning work settles, offer one explicit capture decision. Present only candidates that pass:

```bash
python3 "$PWD/skills/using-superpowers/scripts/validate-memory-candidate.py" CANDIDATE
```

Each candidate has exactly one concise `Future decision`, `Durable insight`, `Evidence`, `Invalidated when`, and `Rediscovery cost`. The future decision states how this fact changes a later choice; evidence cites a file/line, passing test or command, or durable bead; the invalidator names its expiry/superseding event; and rediscovery cost explains why ordinary repository search is insufficient.

Reject approval/completion announcements, procedural recipes, raw failure logs, current branch/HEAD/next-task state, and directly searchable artifact pointers. Route a procedure to a proposed skill or project-instruction change. A continuation is the sole execution-state exception: keep one relevant continuation for the current project, require `@expires=YYYY-MM-DD`, and do not classify it as durable semantic memory.

The user chooses what to retain or skips. A dismissed, unavailable, or auto-resolved question is no consent. When the store crosses the curator's count/duplication threshold, make an explicit non-mutating offer to run a dry sweep; never start curation from capture.

## Durable Memory

Record an insight only when it passed the Capture Gate, remains useful beyond the current session, and changes a future decision. Update the existing keyed memory instead of creating a near-duplicate. The governing contract/spec/graph remains authoritative; memory stores only the surprising decision delta and evidence index. Never retain guesses, one-off state, secrets, credentials, tokens, keys, or personal data.

## Beads Read/Write Economy

Use bounded reads, filtered output, and a single batch for related mutations. Preserve write confirmations as evidence. Never dump the full memory store or perform repetitive tracker round trips when one bounded query or batch answers the question.

## Claim Boundary

Auto-claim only inside an explicitly authorized autonomous take-next-task flow. When the user chose the work, orientation and planning remain read-only until the user authorizes execution. Efficiency cannot widen consent.

## Workflow Routing

When resuming or advancing substantial work with durable product, design, plan, or acceptance artifacts, read [Workflow Routing](workflow-routing.md). Build its regenerable state snapshot from artifacts and bounded Beads reads, then use the validated next phase instead of chat memory.

## Session Completion

The completion sequence is exactly: `bd close` → `bd dolt push` → `git pull --rebase && git push` → `git status`. Close only verified work, honor explicit user limits on remote actions, and never describe unsynced authorized work as landed.
