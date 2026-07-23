#!/usr/bin/env python3
"""Validate current task or epic acceptance evidence without side effects."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path, PurePosixPath
from typing import Any


HEX40 = re.compile(r"[0-9a-f]{40}")
HEX64 = re.compile(r"[0-9a-f]{64}")
RESULTS = {"PASS", "FAIL", "BLOCKED", "UNTESTED"}
IDENTITY_FIELDS = ("commit", "contract_hash", "environment", "fixture_hash")
CURRENT_FIELDS = {"base_commit", *IDENTITY_FIELDS}
GATE_FIELDS = {"required_acceptance", "review"}
REVIEW_FIELDS = {
    "kind", "result", "reviewer_context_id", "report_path", *IDENTITY_FIELDS,
}
EVIDENCE_FIELDS = {
    "acceptance_id", "evidence_class", "result", "command_or_flow",
    "observed_at", "artifact", *IDENTITY_FIELDS,
}
ROUND_FIELDS = {"round", "result", "reviewer_context_id", "findings"}
FINDING_FIELDS = {
    "finding_id", "finding_ancestry", "severity", "acceptance_ids", "classification", "evidence",
    "invalidated_assumption", "correction", "counterexample", "contract_hash",
    "review_round",
}
LINEAGE_FIELDS = {
    "schema_version", "lineage_id", "outcome_ids", "finding_ancestry",
    "task_ids", "failed_rounds",
}
DIAGNOSTIC_FIELDS = {
    "result", "strategy", "next_task_id", "next_contract_hash", "dispatch_allowed",
}
CLASSIFICATIONS = {
    "contract-gap", "implementation-defect", "evidence-gap",
    "integration-defect", "reviewer-disagreement",
}
DIAGNOSTICS = {
    "amend-contract", "split-slice", "resolve-product-decision",
    "adjudicate-reviewer",
}
WAVE_FIELDS = {"schema_version", "reviewer_context_id", "expected_task_ids", "tasks"}
WAVE_TASK_FIELDS = {
    "task_id", "contract_hash", "risk_boundaries", "result",
    "acceptance_results", "findings", "complementary_reviewer_context_id",
}
COMPLEMENTARY_RISKS = {"authority", "protocol", "security", "recovery"}
HUMAN_REVIEW_FIELDS = {
    "schema_version", "required", "reason", "base", "head", "reviewer",
    "verdict", "recorded_at",
}


class EvidenceError(ValueError):
    pass


def read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise EvidenceError(f"ledger: invalid JSON: {exc}") from exc
    if not isinstance(value, dict):
        raise EvidenceError("ledger: expected JSON object")
    return value


def require_fields(value: Any, fields: set[str], name: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise EvidenceError(f"{name}: expected object")
    if set(value) != fields:
        raise EvidenceError(
            f"{name}: fields differ: missing={sorted(fields - set(value))}, "
            f"extra={sorted(set(value) - fields)}"
        )
    return value


def nonempty_string(value: Any, name: str) -> str:
    if not isinstance(value, str) or not value:
        raise EvidenceError(f"{name}: expected non-empty string")
    return value


def trusted_path(value: Any, name: str) -> str:
    text = nonempty_string(value, name)
    path = PurePosixPath(text)
    if path.is_absolute() or ".." in path.parts or text == ".":
        raise EvidenceError(f"{name}: expected trusted repo-relative path")
    return text


def validate_identity(identity: dict[str, Any], name: str) -> None:
    if not HEX40.fullmatch(str(identity["commit"])):
        raise EvidenceError(f"{name}.commit: expected full Git SHA")
    if not HEX64.fullmatch(str(identity["contract_hash"])):
        raise EvidenceError(f"{name}.contract_hash: expected SHA-256")
    nonempty_string(identity["environment"], f"{name}.environment")
    if not HEX64.fullmatch(str(identity["fixture_hash"])):
        raise EvidenceError(f"{name}.fixture_hash: expected SHA-256")


def validate_required(value: Any, name: str) -> dict[str, str]:
    if not isinstance(value, dict) or not value:
        raise EvidenceError(f"{name}: expected non-empty acceptance-to-evidence map")
    for acceptance_id, evidence_class in value.items():
        nonempty_string(acceptance_id, f"{name}.acceptance_id")
        nonempty_string(evidence_class, f"{name}.{acceptance_id}")
    return value


def validate_review(review: Any, expected_kind: str, name: str) -> dict[str, Any]:
    record = require_fields(review, REVIEW_FIELDS, name)
    if record["kind"] != expected_kind:
        raise EvidenceError(f"{name}.kind: expected {expected_kind}")
    if record["result"] not in RESULTS:
        raise EvidenceError(f"{name}.result: invalid result")
    nonempty_string(record["reviewer_context_id"], f"{name}.reviewer_context_id")
    report = trusted_path(record["report_path"], f"{name}.report_path")
    if not report.startswith(".internal/sdd/"):
        raise EvidenceError(f"{name}.report_path: must be beneath .internal/sdd/")
    validate_identity(record, name)
    return record


def validate_evidence(record: Any, index: int) -> dict[str, Any]:
    name = f"evidence[{index}]"
    value = require_fields(record, EVIDENCE_FIELDS, name)
    for field in ("acceptance_id", "evidence_class", "command_or_flow", "observed_at"):
        nonempty_string(value[field], f"{name}.{field}")
    trusted_path(value["artifact"], f"{name}.artifact")
    if value["result"] not in RESULTS:
        raise EvidenceError(f"{name}.result: invalid result")
    validate_identity(value, name)
    return value


def validate_finding(
    finding: Any,
    round_number: int,
    known_acceptance: set[str],
    name: str,
) -> None:
    value = require_fields(finding, FINDING_FIELDS, name)
    for field in (
        "finding_id", "evidence", "invalidated_assumption", "correction",
        "counterexample",
    ):
        nonempty_string(value[field], f"{name}.{field}")
    ancestry = value["finding_ancestry"]
    if (
        not isinstance(ancestry, list)
        or not ancestry
        or any(not isinstance(item, str) or not item for item in ancestry)
        or len(set(ancestry)) != len(ancestry)
        or ancestry[-1] != value["finding_id"]
    ):
        raise EvidenceError(f"{name}.finding_ancestry: expected unique ancestry ending in finding_id")
    if value["severity"] not in {"Critical", "Important", "Minor"}:
        raise EvidenceError(f"{name}.severity: invalid severity")
    if value["classification"] not in CLASSIFICATIONS:
        raise EvidenceError(f"{name}.classification: invalid classification")
    acceptance_ids = value["acceptance_ids"]
    if (
        not isinstance(acceptance_ids, list)
        or not acceptance_ids
        or any(not isinstance(item, str) or not item for item in acceptance_ids)
        or len(set(acceptance_ids)) != len(acceptance_ids)
    ):
        raise EvidenceError(f"{name}.acceptance_ids: expected unique non-empty IDs")
    unknown = set(acceptance_ids) - known_acceptance
    if unknown:
        raise EvidenceError(f"{name}.acceptance_ids: unknown IDs {sorted(unknown)}")
    if not isinstance(value["contract_hash"], str) or not HEX64.fullmatch(value["contract_hash"]):
        raise EvidenceError(f"{name}.contract_hash: expected SHA-256")
    if value["review_round"] != round_number:
        raise EvidenceError(f"{name}.review_round: does not match owning round")


def validate_diagnostic(value: Any, current: dict[str, Any]) -> None:
    diagnostic = require_fields(value, DIAGNOSTIC_FIELDS, "diagnostic")
    if diagnostic["result"] not in DIAGNOSTICS:
        raise EvidenceError("diagnostic.result: invalid diagnostic")
    nonempty_string(diagnostic["strategy"], "diagnostic.strategy")
    task_id = diagnostic["next_task_id"]
    contract_hash = diagnostic["next_contract_hash"]
    if task_id is not None:
        nonempty_string(task_id, "diagnostic.next_task_id")
    if contract_hash is not None:
        if not isinstance(contract_hash, str) or not HEX64.fullmatch(contract_hash):
            raise EvidenceError("diagnostic.next_contract_hash: expected SHA-256 or null")
        if contract_hash == current["contract_hash"]:
            raise EvidenceError("diagnostic.next_contract_hash: must be a new contract")
    if task_id is None and contract_hash is None:
        raise EvidenceError("diagnostic: new task or contract strategy is required")
    if diagnostic["dispatch_allowed"] is not False:
        raise EvidenceError("diagnostic.dispatch_allowed: must remain false in this lineage")


def validate_ledger(ledger: dict[str, Any]) -> tuple[dict[str, Any], list[str]]:
    fields = {
        "schema_version", "current", "task_gate", "epic_gate", "evidence",
        "review_rounds", "diagnostic",
    }
    require_fields(ledger, fields, "ledger")
    if ledger["schema_version"] != 1:
        raise EvidenceError("schema_version: expected 1")
    current = require_fields(ledger["current"], CURRENT_FIELDS, "current")
    validate_identity(current, "current")
    if not HEX40.fullmatch(str(current["base_commit"])):
        raise EvidenceError("current.base_commit: expected full Git SHA")

    gates: dict[str, dict[str, Any]] = {}
    review_contexts: list[str] = []
    known_acceptance: set[str] = set()
    for gate_name, kind in (("task_gate", "task"), ("epic_gate", "outcome")):
        gate = require_fields(ledger[gate_name], GATE_FIELDS, gate_name)
        required = validate_required(gate["required_acceptance"], f"{gate_name}.required_acceptance")
        review = validate_review(gate["review"], kind, f"{gate_name}.review")
        gate["required_acceptance"] = required
        gate["review"] = review
        gates[gate_name] = gate
        known_acceptance.update(required)
        review_contexts.append(review["reviewer_context_id"])
    if len(set(review_contexts)) != len(review_contexts):
        raise EvidenceError("gate reviews: fresh reviewer context required")

    if not isinstance(ledger["evidence"], list):
        raise EvidenceError("evidence: expected array")
    ledger["evidence"] = [
        validate_evidence(record, index) for index, record in enumerate(ledger["evidence"])
    ]

    rounds = ledger["review_rounds"]
    if not isinstance(rounds, list):
        raise EvidenceError("review_rounds: expected array")
    round_contexts: list[str] = []
    failed_rounds = 0
    for index, round_record in enumerate(rounds):
        name = f"review_rounds[{index}]"
        record = require_fields(round_record, ROUND_FIELDS, name)
        if record["round"] != index + 1:
            raise EvidenceError(f"{name}.round: rounds must be contiguous from 1")
        if record["result"] not in RESULTS:
            raise EvidenceError(f"{name}.result: invalid result")
        context = nonempty_string(record["reviewer_context_id"], f"{name}.reviewer_context_id")
        round_contexts.append(context)
        if not isinstance(record["findings"], list):
            raise EvidenceError(f"{name}.findings: expected array")
        if record["result"] == "FAIL" and not record["findings"]:
            raise EvidenceError(f"{name}.findings: failed round requires typed findings")
        for finding_index, finding in enumerate(record["findings"]):
            validate_finding(
                finding,
                record["round"],
                known_acceptance,
                f"{name}.findings[{finding_index}]",
            )
        if record["result"] == "FAIL":
            failed_rounds += 1
    all_contexts = review_contexts + round_contexts
    if len(set(all_contexts)) != len(all_contexts):
        raise EvidenceError("review_rounds: every round requires a fresh reviewer context")

    diagnostic_errors: list[str] = []
    if failed_rounds >= 2:
        if ledger["diagnostic"] is None:
            choices = ", ".join(sorted(DIAGNOSTICS))
            diagnostic_errors.append(
                f"review_rounds: diagnostic required after two failed rounds ({choices})"
            )
        else:
            validate_diagnostic(ledger["diagnostic"], current)
    elif ledger["diagnostic"] is not None:
        validate_diagnostic(ledger["diagnostic"], current)
    if failed_rounds > 2:
        diagnostic_errors.append("review_rounds: normal correction is limited to two failed rounds")
    return gates, diagnostic_errors


def identity_differences(record: dict[str, Any], current: dict[str, Any]) -> list[str]:
    return [field for field in IDENTITY_FIELDS if record[field] != current[field]]


def gate_errors(
    ledger: dict[str, Any],
    gate_name: str,
    diagnostic_errors: list[str],
) -> list[tuple[str, str]]:
    current = ledger["current"]
    gate = ledger[gate_name]
    errors: list[tuple[str, str]] = [("review_rounds", error) for error in diagnostic_errors]
    review = gate["review"]
    if review["result"] != "PASS":
        errors.append(("review", f"review result is {review['result']}"))
    differences = identity_differences(review, current)
    if differences:
        errors.append(("review", f"stale review identity: {', '.join(differences)}"))

    evidence = ledger["evidence"]
    for acceptance_id, required_class in gate["required_acceptance"].items():
        records = [record for record in evidence if record["acceptance_id"] == acceptance_id]
        exact_identity = [record for record in records if not identity_differences(record, current)]
        exact_class = [record for record in exact_identity if record["evidence_class"] == required_class]
        exact_results = {record["result"] for record in exact_class}
        if len(exact_results) > 1:
            errors.append(
                (acceptance_id, f"conflicting current results for {required_class}: {', '.join(sorted(exact_results))}")
            )
            continue
        if exact_results == {"PASS"}:
            continue
        if exact_class:
            states = ", ".join(sorted({record["result"] for record in exact_class}))
            errors.append((acceptance_id, f"required {required_class} evidence is {states}"))
            continue
        if exact_identity:
            supplied = ", ".join(sorted({record["evidence_class"] for record in exact_identity}))
            errors.append(
                (acceptance_id, f"substituted evidence class {supplied} for required {required_class}")
            )
            continue
        matching_class = [record for record in records if record["evidence_class"] == required_class]
        if matching_class:
            stale = sorted({field for record in matching_class for field in identity_differences(record, current)})
            errors.append((acceptance_id, f"stale {', '.join(stale)} for required {required_class} evidence"))
            continue
        errors.append((acceptance_id, f"missing required {required_class} evidence"))
    return errors


def check(ledger: dict[str, Any], gate_name: str, label: str) -> tuple[bool, list[str]]:
    _, diagnostic_errors = validate_ledger(ledger)
    errors = gate_errors(ledger, gate_name, diagnostic_errors)
    if errors:
        return False, [f"FAIL {label}"] + [f"- {acceptance_id}: {reason}" for acceptance_id, reason in errors]
    ids = ", ".join(ledger[gate_name]["required_acceptance"])
    return True, [f"PASS {label}: {ids}"]


def validate_lineage(value: dict[str, Any]) -> dict[str, Any]:
    lineage = require_fields(value, LINEAGE_FIELDS, "outcome_lineage")
    if lineage["schema_version"] != 1:
        raise EvidenceError("outcome_lineage.schema_version: expected 1")
    nonempty_string(lineage["lineage_id"], "outcome_lineage.lineage_id")
    for field in ("outcome_ids", "task_ids"):
        items = lineage[field]
        if (
            not isinstance(items, list)
            or not items
            or any(not isinstance(item, str) or not item for item in items)
            or len(set(items)) != len(items)
        ):
            raise EvidenceError(f"outcome_lineage.{field}: expected unique non-empty strings")
    ancestry = lineage["finding_ancestry"]
    if (
        not isinstance(ancestry, list)
        or any(not isinstance(item, str) or not item for item in ancestry)
        or len(set(ancestry)) != len(ancestry)
    ):
        raise EvidenceError("outcome_lineage.finding_ancestry: expected unique strings")
    if isinstance(lineage["failed_rounds"], bool) or not isinstance(lineage["failed_rounds"], int) or lineage["failed_rounds"] < 0:
        raise EvidenceError("outcome_lineage.failed_rounds: expected non-negative integer")
    return lineage


def check_dispatch(ledger: dict[str, Any], lineage: dict[str, Any]) -> tuple[bool, list[str]]:
    validate_ledger(ledger)
    lineage = validate_lineage(lineage)
    failed_rounds = lineage["failed_rounds"]
    if failed_rounds >= 2:
        return False, [
            "FAIL dispatch",
            f"- outcome lineage {lineage['lineage_id']} is exhausted after two failed review rounds across tasks {', '.join(lineage['task_ids'])}; diagnose instead of resetting the budget with a replacement task",
        ]
    return True, [f"PASS dispatch: outcome lineage {lineage['lineage_id']} remains within the two-round limit"]


def check_wave(document: dict[str, Any]) -> tuple[bool, list[str]]:
    wave = require_fields(document, WAVE_FIELDS, "review_wave")
    if wave["schema_version"] != 1:
        raise EvidenceError("review_wave.schema_version: expected 1")
    reviewer = nonempty_string(wave["reviewer_context_id"], "review_wave.reviewer_context_id")
    expected = wave["expected_task_ids"]
    if not isinstance(expected, list) or not 1 <= len(expected) <= 3 or len(set(expected)) != len(expected) or any(not isinstance(item, str) or not item for item in expected):
        raise EvidenceError("review_wave.expected_task_ids: expected one to three unique IDs")
    tasks = wave["tasks"]
    if not isinstance(tasks, list):
        raise EvidenceError("review_wave.tasks: expected array")
    actual = [task.get("task_id") for task in tasks if isinstance(task, dict)]
    if set(actual) != set(expected) or len(actual) != len(expected):
        return False, ["FAIL wave", "- missing task results or unexpected task identities"]
    errors: list[str] = []
    for index, raw in enumerate(tasks):
        task = require_fields(raw, WAVE_TASK_FIELDS, f"review_wave.tasks[{index}]")
        task_id = nonempty_string(task["task_id"], f"review_wave.tasks[{index}].task_id")
        if not HEX64.fullmatch(str(task["contract_hash"])):
            raise EvidenceError(f"review_wave.tasks[{index}].contract_hash: expected SHA-256")
        risks = task["risk_boundaries"]
        if not isinstance(risks, list) or len(set(risks)) != len(risks) or any(not isinstance(item, str) or not item for item in risks):
            raise EvidenceError(f"review_wave.tasks[{index}].risk_boundaries: expected unique strings")
        if task["result"] not in RESULTS:
            raise EvidenceError(f"review_wave.tasks[{index}].result: invalid result")
        acceptance = task["acceptance_results"]
        if not isinstance(acceptance, dict) or not acceptance or any(not isinstance(key, str) or not key or value not in RESULTS for key, value in acceptance.items()):
            raise EvidenceError(f"review_wave.tasks[{index}].acceptance_results: invalid result map")
        findings = task["findings"]
        if not isinstance(findings, list):
            raise EvidenceError(f"review_wave.tasks[{index}].findings: expected array")
        for finding_index, finding in enumerate(findings):
            validate_finding(finding, 1, set(acceptance), f"review_wave.tasks[{index}].findings[{finding_index}]")
        complementary = task["complementary_reviewer_context_id"]
        if COMPLEMENTARY_RISKS & set(risks):
            if not isinstance(complementary, str) or not complementary or complementary == reviewer:
                errors.append(f"- {task_id}: complementary review required for high-risk boundaries")
        elif complementary is not None:
            nonempty_string(complementary, f"review_wave.tasks[{index}].complementary_reviewer_context_id")
        nonpass = sorted(key for key, value in acceptance.items() if value != "PASS")
        if task["result"] != "PASS" or nonpass:
            errors.append(f"- {task_id}: result {task['result']}; non-PASS acceptance {', '.join(nonpass) if nonpass else 'none'}")
    if errors:
        return False, ["FAIL wave", *errors]
    return True, [f"PASS wave: {', '.join(expected)}"]


def check_reuse(
    ledger: dict[str, Any], acceptance_id: str, evidence_class: str, command_or_flow: str
) -> tuple[bool, list[str]]:
    validate_ledger(ledger)
    current = ledger["current"]
    candidates = [
        record for record in ledger["evidence"]
        if record["acceptance_id"] == acceptance_id
        and record["evidence_class"] == evidence_class
        and record["command_or_flow"] == command_or_flow
        and record["result"] == "PASS"
    ]
    exact = [record for record in candidates if not identity_differences(record, current)]
    if exact:
        return True, [f"PASS reuse: {acceptance_id} {evidence_class} exact identity"]
    changed = sorted({field for record in candidates for field in identity_differences(record, current)})
    reason = f"stale identity: {', '.join(changed)}" if changed else "no matching PASS record"
    return False, [f"FAIL reuse: rerun required for {acceptance_id} {evidence_class} ({reason})"]


def check_human_review(
    ledger: dict[str, Any],
    review_document: dict[str, Any],
    expected_head: str,
) -> tuple[bool, list[str]]:
    validate_ledger(ledger)
    if not HEX40.fullmatch(expected_head):
        raise EvidenceError("human_review.expected_head: expected full Git SHA")
    if expected_head != ledger["current"]["commit"]:
        return False, [
            "FAIL human review",
            "- stale current head: supplied Git head does not match the evidence ledger",
        ]
    review = require_fields(review_document, HUMAN_REVIEW_FIELDS, "human_review")
    if review["schema_version"] != 1:
        raise EvidenceError("human_review.schema_version: expected 1")
    if not isinstance(review["required"], bool):
        raise EvidenceError("human_review.required: expected boolean")
    for field in ("reason", "reviewer", "recorded_at"):
        nonempty_string(review[field], f"human_review.{field}")
    for field in ("base", "head"):
        if not HEX40.fullmatch(str(review[field])):
            raise EvidenceError(f"human_review.{field}: expected full Git SHA")
    if review["base"] == review["head"]:
        raise EvidenceError("human_review: base and head must identify an exact diff range")
    expected_verdict = "APPROVED" if review["required"] else "NOT_REQUIRED"
    if review["verdict"] != expected_verdict:
        raise EvidenceError(
            f"human_review.verdict: expected {expected_verdict} for required={review['required']}"
        )
    if review["base"] != ledger["current"]["base_commit"]:
        return False, [
            "FAIL human review",
            "- stale base: approval does not match the evidence ledger base",
        ]
    if review["head"] != expected_head:
        return False, [
            "FAIL human review",
            "- stale head: approval does not match the current commit",
        ]
    if review["required"]:
        return True, [
            f"PASS human review: {review['reviewer']} approved {review['base']}..{review['head']}"
        ]
    return True, [
        f"PASS human review bypass: {review['reviewer']} approved NOT_REQUIRED for {review['base']}..{review['head']}"
    ]


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description=__doc__)
    commands = root.add_subparsers(dest="command", required=True)
    for command in ("check-task", "check-epic", "check-wave"):
        child = commands.add_parser(command)
        child.add_argument("ledger", type=Path)
    human = commands.add_parser("check-human")
    human.add_argument("ledger", type=Path)
    human.add_argument("--review", type=Path, required=True)
    human.add_argument("--head", required=True)
    dispatch = commands.add_parser("check-dispatch")
    dispatch.add_argument("ledger", type=Path)
    dispatch.add_argument("--lineage", type=Path, required=True)
    reuse = commands.add_parser("check-reuse")
    reuse.add_argument("ledger", type=Path)
    reuse.add_argument("--acceptance-id", required=True)
    reuse.add_argument("--evidence-class", required=True)
    reuse.add_argument("--command-or-flow", required=True)
    return root


def main() -> int:
    args = parser().parse_args()
    try:
        ledger = read_json(args.ledger)
        if args.command == "check-task":
            passed, lines = check(ledger, "task_gate", "task")
        elif args.command == "check-epic":
            passed, lines = check(ledger, "epic_gate", "epic")
        elif args.command == "check-wave":
            passed, lines = check_wave(ledger)
        elif args.command == "check-reuse":
            passed, lines = check_reuse(
                ledger, args.acceptance_id, args.evidence_class, args.command_or_flow
            )
        elif args.command == "check-human":
            passed, lines = check_human_review(
                ledger, read_json(args.review), args.head
            )
        else:
            passed, lines = check_dispatch(ledger, read_json(args.lineage))
    except EvidenceError as exc:
        print(f"sdd evidence error: {exc}", file=sys.stderr)
        return 1
    print("\n".join(lines))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
