# Review and Evidence

Load this reference after an implementer reports or when correcting a finding. Reviews consume bounded artifacts, not the controller's transcript.

## File Handoffs

- Task requirements live in the bead description.
- The Context Manifest lives at `.internal/sdd/<task-id>-manifest.json` in the task worktree.
- The implementer writes its full report to the manifest's `report_path`.
- The controller persists the report as a task comment immediately after return.
- `scripts/review-package <BASE> <HEAD>` creates the bounded commit log, stat, and diff. `BASE` is the commit captured before implementation, never an assumed `HEAD~1`.
- The review package is regenerable scratch evidence; task comments retain the verdict and commit range.

The reviewer is read-only: it does not edit files, the index, HEAD, branch state, Beads, or the report.

## Task Review

Dispatch `./task-reviewer-prompt.md` with:

- task bead ID and owned outcome IDs;
- immutable manifest identity;
- implementer report path;
- review-package path and exact base/head;
- named acceptance and verification evidence.

The single reviewer returns both a spec-compliance verdict and a code-quality verdict. It treats the implementer's report as claims to verify, not truth. Persist the complete verdict. A failed verdict leaves the task open.

A `cannot verify from diff` warning does not automatically fail the task, but the controller must resolve it against named cross-task evidence. Record why it is satisfied or treat it as a finding.

## Corrections

When review finds an issue:

1. classify it against the task contract;
2. technically evaluate feedback using `superbeads:receiving-code-review`;
3. if identity is unchanged, append correction lineage and return the precise finding to the same worker context;
4. if any identity field changed, create a new manifest and fresh worker;
5. require fresh verification evidence and regenerate the review package;
6. re-review before merge or closure.

After two failed correction rounds on the same finding, stop repeating the loop. Diagnose whether authority is missing, acceptance is ambiguous, the implementation approach is invalid, or the model/host capability is insufficient. Escalate a user-owned decision rather than burning another identical turn.

## Outcome Review

Task completion is not product completion. At every plan checkpoint and before epic closure, dispatch a fresh `./outcome-reviewer-prompt.md` with the outcome trace, user entry interfaces, governing product/design revisions, required evidence classes, environment identity, and commit.

The outcome reviewer reports `PASS`, `FAIL`, `BLOCKED`, or `UNTESTED` for each ID. Only `PASS` satisfies it. Unit tests, CI, static review, direct API calls, or conformance do not substitute for a different evidence class named by the product contract.

Persist the outcome report on the acceptance-gate bead. Any non-PASS outcome leaves that gate and epic open. An explicit scope cut must name the affected IDs and be recorded in the trace.

## Closure Evidence

Close a task only after:

- implementer status and manifest identity are durable;
- named verification commands passed with fresh output;
- task review approved spec compliance and quality;
- integration checkpoint passed where required;
- commit base/head and concerns are recorded.

Close an acceptance gate or epic only after all required outcome IDs pass. A later request to open a PR, monitor CI, or continue follow-ups never waives unfinished acceptance.
