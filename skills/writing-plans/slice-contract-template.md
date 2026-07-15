# Slice Contract Graph Template

The graph JSON has exactly `nodes` and `edges`. It contains one epic and one task per independently reviewable slice. Edge direction is dependent → prerequisite.

## Epic Node

Required fields: `key`, `title`, `type: epic`, integer `priority`, and `description`.

The description contains:

- `## Outcome Trace`: one stable ID per line with actor, entry, action, durable result, find-again path, failure/denied state, evidence class, implementation owner, earliest seam, and final gate.
- `## Success Criteria`: measurable product closure; non-PASS evidence leaves outcomes open.

## Task Node

Required fields: `key`, `title`, `type: task`, integer `priority`, the epic `parent_key`, and `description` with these sections in order.

## Context

Record Product contract path+revision, Spec path, Outcome IDs, External ref, Why this slice exists, and constraints that must not be rediscovered. Repository artifacts are evidence, not permission.

## Outcome

Record:

- Actor / entry interface
- Observable result
- Durable result / find-again path
- Denied/failure/recovery result

The result must be product behavior or an independently operable capability, not files existing.

## Domain Contract

Record vocabulary, ownership, authority, invariants, transitions, transaction/side-effect boundaries, and counterexamples relevant to this slice. Reference product IDs rather than restating product truth.

For a justified enabling exception, include both `Integration-risk exception:` and `Downstream acceptance link:`. For speculative execution include `Speculative execution: yes`, `Frozen interface:`, `Disjoint resources:`, and `Bounded discard/rebase cost:`.

## Files

Use observed `Create:`, `Modify:`, and `Test:` paths. State purpose when it is not obvious. Do not claim broad directories when the write set is narrower.

## Resources

Record `Allowed write set:`, `Exclusive resources:`, and `Capacity resources:`. Use `None` explicitly. Resource declarations do not manufacture dependency edges.

## Interfaces

Record exact consumed/produced commands, flags, signatures, schemas, events, or public shapes. Define new names once.

## Acceptance Criteria

Use observable results with named evidence classes. Cover success plus material denied/failure/recovery cases. State when non-PASS evidence keeps the slice open.

## Integration Checkpoint

Name the real seam, command or user flow exercised in this task. “Later,” “downstream,” and “final integration” are not checkpoints.

## Implementation Notes

Give concise RED/GREEN guidance: failing behavior, exact command and expected failure, minimal change boundary, passing command, and final verification. Include code only for a novel public contract or non-obvious shape.

## Edges

Each edge is `{"from_key":"dependent", "to_key":"prerequisite", "type":"blocks"}`. Use edges only for semantic prerequisites; keep resource conflicts in Resources.
