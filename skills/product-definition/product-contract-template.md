# Product Contract: <topic>

Revision: <integer or content hash>

Use this template only when the route in `SKILL.md` requires a new or normalized contract. Delete instructional text from the finished artifact. Each applicable cell must be resolved, explicitly deferred with an approver, or assigned to a named decision owner.

## Goal

State the user/business result, measurable success signal, and current workaround.

## Source Ledger

Record source, status, precedence, and contribution. Status is one of original request, observed behavior, verified research, clarification, newly requested, assumed, or deferred.

## Actors and Authority

For each actor, record role, permissions, authority grants and limits, and decision owner.

## Vocabulary and Domain Model

Define canonical terms, rejected synonyms, entities, relationships, and owner.

## Lifecycle and Invariants

Define transitions, business invariants, observable atomicity and consistency invariants, actor-visible side effects, and recovery. State forbidden partial results; leave storage and service mechanisms to the technical spec.

## Journeys and States

Trace each journey from its real entry point to a durable result and find-again/use path. Cover applicable empty, loading, invalid, denied, conflict, offline, recovery, undo/archive, and narrow-screen states.

## Examples and Counterexamples

Give concrete examples and falsifying counterexamples, especially across actor, authority, lifecycle, and failure boundaries.

## Outcome Trace

For each stable outcome ID, record actor/entry, observable result, durable result/find-again path, denied/failure/recovery result, and evidence class.

## Non-Goals and Decisions

Record non-goals, decisions, approved deferrals, and named decision owners.

## Assumptions

Separate verified, recalled, and assumed claims. Do not present recalled or assumed claims as verified facts.

## Approval

Record status, approver, approved revision, date, and any superseded contract.

## Internal Bypass

When the route permits a bypass, use a one-line artifact instead of the headings above:

`Product contract: Not applicable — <observed mechanical reason>; changes no user-visible behavior, durable business rule, workflow, terminology, or external interface.`
