# Bootstrap Policy Details

## Production-Grade Doctrine

Treat every project as a production system with real users, no matter how small it looks. You MUST NOT silently take a shortcut, descope a required behavior/edge-case, or accept a material-risk trade-off — surface it and let your human partner decide. You MUST NOT weaken, bypass, or remove a security control or introduce a vulnerability; a security regression is never acceptable, even for a deadline.

## Capturing Decisions

When a decision is hard to reverse, surprising without context, and a genuine trade-off, you MUST offer to record an ADR in `docs/decisions` (the user confirms; never auto-create). Bias toward offering rather than skipping. Routine clarifications and scope questions don't qualify.

## Asking the User

When a skill says to ask the user or present options: use your harness's structured question tool if it has one (multiple-choice with an "Other" escape); if it doesn't, print the options as a numbered list in plain text and STOP for the user's reply. If the tool errors, or an answer comes back skipped, dismissed, or auto-resolved (headless and auto modes do this), treat it as NO answer — never as consent: fall back to numbered plain text and stop. JSON question blocks in skills show Claude Code's schema — render the same content through your tool's shape.
