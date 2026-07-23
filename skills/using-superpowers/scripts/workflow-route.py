#!/usr/bin/env python3
"""Validate a regenerable workflow-state snapshot and select its next phase."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


FIELDS = (
    "research",
    "product_contract",
    "design",
    "stress_test",
    "plan",
    "execution",
    "acceptance",
    "human_review",
)
ALLOWED = {
    "research": {"missing", "complete", "not_required", "blocked"},
    "product_contract": {"missing", "approved", "not_required", "blocked"},
    "design": {"missing", "approved", "not_required", "blocked"},
    "stress_test": {"missing", "approved", "not_required", "blocked"},
    "plan": {"missing", "approved", "not_required", "blocked"},
    "execution": {"not_started", "in_progress", "complete", "blocked"},
    "acceptance": {"not_started", "pass", "fail", "blocked"},
    "human_review": {"missing", "approved", "not_required", "blocked"},
}


class RouteError(ValueError):
    pass


def load(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise RouteError(f"invalid workflow state: {exc}") from exc
    expected = {"schema_version", *FIELDS}
    if not isinstance(value, dict) or set(value) != expected:
        raise RouteError("invalid workflow state: fields differ")
    if value["schema_version"] != 1:
        raise RouteError("invalid workflow state: schema_version must be 1")
    for name in FIELDS:
        if value[name] not in ALLOWED[name]:
            raise RouteError(f"invalid workflow state: {name} has unknown status")
    return value


def validate_order(state: dict[str, Any]) -> None:
    satisfied = {
        "research": state["research"] in {"complete", "not_required"},
        "product_contract": state["product_contract"] in {"approved", "not_required"},
        "design": state["design"] in {"approved", "not_required"},
        "stress_test": state["stress_test"] in {"approved", "not_required"},
        "plan": state["plan"] in {"approved", "not_required"},
        "execution": state["execution"] == "complete",
        "acceptance": state["acceptance"] == "pass",
    }
    advanced = {
        "product_contract": state["product_contract"] != "missing",
        "design": state["design"] != "missing",
        "stress_test": state["stress_test"] != "missing",
        "plan": state["plan"] != "missing",
        "execution": state["execution"] != "not_started",
        "acceptance": state["acceptance"] != "not_started",
        "human_review": state["human_review"] != "missing",
    }
    predecessors = (
        ("product_contract", "research"),
        ("design", "product_contract"),
        ("stress_test", "design"),
        ("plan", "stress_test"),
        ("execution", "plan"),
        ("acceptance", "execution"),
        ("human_review", "acceptance"),
    )
    for phase, predecessor in predecessors:
        if advanced[phase] and not satisfied[predecessor]:
            raise RouteError(f"{phase} cannot advance before {predecessor}")


def route(state: dict[str, Any]) -> dict[str, Any]:
    validate_order(state)
    blocked = [name for name in FIELDS if state[name] == "blocked"]
    if blocked:
        return {"state": "blocked", "next_skill": None, "blockers": blocked}
    checks = (
        ("research", "research-driven-development"),
        ("product_contract", "product-definition"),
        ("design", "brainstorming"),
        ("stress_test", "stress-test"),
        ("plan", "writing-plans"),
    )
    for field, skill in checks:
        if state[field] == "missing":
            return {
                "state": f"needs_{field}",
                "next_skill": skill,
                "blockers": [],
            }
    if state["execution"] in {"not_started", "in_progress"}:
        return {
            "state": "needs_execution",
            "next_skill": "subagent-driven-development",
            "blockers": [],
        }
    if state["acceptance"] != "pass":
        return {
            "state": "needs_acceptance",
            "next_skill": "verification-before-completion",
            "blockers": [],
        }
    if state["human_review"] == "missing":
        return {
            "state": "needs_human_review",
            "next_skill": "finishing-a-development-branch",
            "blockers": [],
        }
    return {
        "state": "complete",
        "next_skill": "finishing-a-development-branch",
        "blockers": [],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("state", type=Path)
    args = parser.parse_args()
    try:
        print(json.dumps(route(load(args.state)), indent=2, sort_keys=True))
    except RouteError as exc:
        print(f"workflow route error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
