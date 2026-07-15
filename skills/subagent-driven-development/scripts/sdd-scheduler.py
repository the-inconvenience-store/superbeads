#!/usr/bin/env python3
"""Return pure, deterministic rolling SDD scheduling decisions."""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import defaultdict
from pathlib import Path, PurePosixPath
from typing import Any


HEX40 = re.compile(r"[0-9a-f]{40}")
HEX64 = re.compile(r"[0-9a-f]{64}")
PHASES = {
    "pending", "implementing", "implemented", "reviewing",
    "reviewed", "merging", "merged",
}
STATUSES = {"open", "blocked", "human-gated", "closed"}
ACTIVE_RESOURCE_PHASES = {
    "implementing", "implemented", "reviewing", "reviewed", "merging",
}
TASK_FIELDS = {
    "id", "status", "dependencies", "dependency_commits", "contract_hash",
    "current_contract_hash", "write_set", "exclusive_resources",
    "capacity_resources", "phase", "review_result", "speculation", "commit",
}
SPECULATION_FIELDS = {
    "enabled", "frozen_interface", "disjoint_resources",
    "discard_files", "rebase_commits",
}


class SchedulerError(ValueError):
    pass


def read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise SchedulerError(f"state: invalid JSON: {exc}") from exc
    if not isinstance(value, dict):
        raise SchedulerError("state: expected a JSON object")
    return value


def string_array(value: Any, field: str) -> list[str]:
    if not isinstance(value, list):
        raise SchedulerError(f"{field}: expected array")
    if any(not isinstance(item, str) or not item for item in value):
        raise SchedulerError(f"{field}: values must be non-empty strings")
    if len(set(value)) != len(value):
        raise SchedulerError(f"{field}: values must be unique")
    return value


def resource_map(value: Any, field: str, *, allow_zero: bool = False) -> dict[str, int]:
    if not isinstance(value, dict):
        raise SchedulerError(f"{field}: expected object")
    minimum = 0 if allow_zero else 1
    for name, amount in value.items():
        if (
            not isinstance(name, str)
            or not name
            or not isinstance(amount, int)
            or isinstance(amount, bool)
            or amount < minimum
        ):
            qualifier = "non-negative" if allow_zero else "positive"
            raise SchedulerError(f"{field}: values must be {qualifier} integers")
    return value


def validate_path(value: str, field: str) -> None:
    path = PurePosixPath(value)
    if path.is_absolute() or ".." in path.parts or value in {"", "."}:
        raise SchedulerError(f"{field}: expected trusted repo-relative path")


def validate_state(state: dict[str, Any]) -> dict[str, dict[str, Any]]:
    required = {
        "graph_revision", "capability_tier", "capacity", "acceptance_gates",
        "speculation_limits", "tasks",
    }
    if set(state) != required:
        raise SchedulerError(
            f"state: fields differ: missing={sorted(required - set(state))}, "
            f"extra={sorted(set(state) - required)}"
        )
    if not isinstance(state["graph_revision"], str) or not HEX64.fullmatch(state["graph_revision"]):
        raise SchedulerError("graph_revision: expected lowercase SHA-256")
    if state["capability_tier"] not in {"isolated", "host-limited"}:
        raise SchedulerError("capability_tier: expected isolated or host-limited")
    if state["acceptance_gates"] not in {"pending", "passing", "blocked", "human-gated"}:
        raise SchedulerError("acceptance_gates: invalid state")

    capacity = state["capacity"]
    if not isinstance(capacity, dict) or set(capacity) != {"workers", "reviews", "merges", "resources"}:
        raise SchedulerError("capacity: requires workers, reviews, merges, and resources")
    for name in ("workers", "reviews", "merges"):
        value = capacity[name]
        minimum = 1 if name == "workers" else 0
        if not isinstance(value, int) or isinstance(value, bool) or value < minimum:
            raise SchedulerError(f"capacity.{name}: invalid limit")
    resource_map(capacity["resources"], "capacity.resources")

    limits = state["speculation_limits"]
    if not isinstance(limits, dict) or set(limits) != {"max_discard_files", "max_rebase_commits"}:
        raise SchedulerError("speculation_limits: invalid shape")
    for name, value in limits.items():
        if not isinstance(value, int) or isinstance(value, bool) or value < 0:
            raise SchedulerError(f"speculation_limits.{name}: expected non-negative integer")

    tasks = state["tasks"]
    if not isinstance(tasks, list):
        raise SchedulerError("tasks: expected array")
    by_id: dict[str, dict[str, Any]] = {}
    for index, task in enumerate(tasks):
        prefix = f"tasks[{index}]"
        if not isinstance(task, dict) or set(task) != TASK_FIELDS:
            raise SchedulerError(f"{prefix}: fields differ")
        task_id = task["id"]
        if not isinstance(task_id, str) or not task_id or task_id in by_id:
            raise SchedulerError(f"{prefix}.id: expected unique non-empty identity")
        if task["status"] not in STATUSES or task["phase"] not in PHASES:
            raise SchedulerError(f"{task_id}: invalid status or phase")
        dependencies = string_array(task["dependencies"], f"{task_id}.dependencies")
        if task_id in dependencies:
            raise SchedulerError(f"{task_id}.dependencies: self-dependency")
        commits = task["dependency_commits"]
        if not isinstance(commits, dict) or any(
            not isinstance(dep, str)
            or not isinstance(commit, str)
            or not HEX40.fullmatch(commit)
            for dep, commit in commits.items()
        ):
            raise SchedulerError(f"{task_id}.dependency_commits: invalid commit map")
        if not set(commits).issubset(dependencies):
            raise SchedulerError(f"{task_id}.dependency_commits: key is not a dependency")
        for field in ("contract_hash", "current_contract_hash"):
            value = task[field]
            if not isinstance(value, str) or not HEX64.fullmatch(value):
                raise SchedulerError(f"{task_id}.{field}: expected lowercase SHA-256")
        for path in string_array(task["write_set"], f"{task_id}.write_set"):
            validate_path(path, f"{task_id}.write_set")
        string_array(task["exclusive_resources"], f"{task_id}.exclusive_resources")
        resource_map(task["capacity_resources"], f"{task_id}.capacity_resources")
        if not set(task["capacity_resources"]).issubset(capacity["resources"]):
            raise SchedulerError(f"{task_id}.capacity_resources: undeclared capacity resource")
        if task["review_result"] not in {None, "pass", "fail", "blocked", "untested"}:
            raise SchedulerError(f"{task_id}.review_result: invalid result")
        commit = task["commit"]
        if commit is not None and (not isinstance(commit, str) or not HEX40.fullmatch(commit)):
            raise SchedulerError(f"{task_id}.commit: expected full Git SHA or null")
        if task["phase"] in {"implemented", "reviewing", "reviewed", "merging", "merged"} and commit is None:
            raise SchedulerError(f"{task_id}.commit: required after implementation")
        if task["phase"] in {"merging", "merged"} and task["review_result"] != "pass":
            raise SchedulerError(f"{task_id}: merge requires a passing review result")
        if task["status"] == "closed" and not (
            task["phase"] == "merged" and task["review_result"] == "pass"
        ):
            raise SchedulerError(f"{task_id}: closed task must have a passing merged commit")
        speculation = task["speculation"]
        if speculation is not None:
            if not isinstance(speculation, dict) or set(speculation) != SPECULATION_FIELDS:
                raise SchedulerError(f"{task_id}.speculation: invalid shape")
            for field in ("enabled", "frozen_interface", "disjoint_resources"):
                if not isinstance(speculation[field], bool):
                    raise SchedulerError(f"{task_id}.speculation.{field}: expected boolean")
            for field in ("discard_files", "rebase_commits"):
                value = speculation[field]
                if not isinstance(value, int) or isinstance(value, bool) or value < 0:
                    raise SchedulerError(f"{task_id}.speculation.{field}: expected non-negative integer")
        by_id[task_id] = task

    for task in tasks:
        unknown = set(task["dependencies"]) - set(by_id)
        if unknown:
            raise SchedulerError(f"{task['id']}.dependencies: unknown tasks {sorted(unknown)}")
    return by_id


def path_overlap(left: str, right: str) -> bool:
    left_parts = PurePosixPath(left).parts
    right_parts = PurePosixPath(right).parts
    width = min(len(left_parts), len(right_parts))
    return left_parts[:width] == right_parts[:width]


def conflict_reasons(
    task: dict[str, Any],
    held: list[dict[str, Any]],
    capacity_limits: dict[str, int],
) -> list[str]:
    reasons: list[str] = []
    for other in held:
        overlaps = sorted(
            f"{left} <> {right}"
            for left in task["write_set"]
            for right in other["write_set"]
            if path_overlap(left, right)
        )
        if overlaps:
            reasons.append(f"write set conflicts with {other['id']}: {', '.join(overlaps)}")
        exclusive = sorted(set(task["exclusive_resources"]) & set(other["exclusive_resources"]))
        if exclusive:
            reasons.append(f"exclusive resource conflicts with {other['id']}: {', '.join(exclusive)}")
    usage: dict[str, int] = defaultdict(int)
    for other in held:
        for name, amount in other["capacity_resources"].items():
            usage[name] += amount
    for name, amount in sorted(task["capacity_resources"].items()):
        if usage[name] + amount > capacity_limits[name]:
            reasons.append(
                f"capacity resource {name} exceeds {capacity_limits[name]} "
                f"({usage[name]} held + {amount} requested)"
            )
    return reasons


def speculation_decision(
    task: dict[str, Any],
    unresolved: list[dict[str, Any]],
    limits: dict[str, int],
) -> tuple[bool, list[str]]:
    speculation = task["speculation"]
    reasons: list[str] = []
    if speculation is None or not speculation["enabled"]:
        return False, ["speculation not enabled"]
    if any(dep["phase"] == "merged" for dep in unresolved):
        reasons.append("merged dependency commit is not recorded")
    if not speculation["frozen_interface"]:
        reasons.append("interface is not frozen")
    if not speculation["disjoint_resources"]:
        reasons.append("resources are not declared disjoint")
    for dependency in unresolved:
        if any(
            path_overlap(left, right)
            for left in task["write_set"]
            for right in dependency["write_set"]
        ):
            reasons.append(f"write set overlaps dependency {dependency['id']}")
        if set(task["exclusive_resources"]) & set(dependency["exclusive_resources"]):
            reasons.append(f"exclusive resource overlaps dependency {dependency['id']}")
        if set(task["capacity_resources"]) & set(dependency["capacity_resources"]):
            reasons.append(f"capacity resource overlaps dependency {dependency['id']}")
    if speculation["discard_files"] > limits["max_discard_files"]:
        reasons.append("discard cost exceeds configured bound")
    if speculation["rebase_commits"] > limits["max_rebase_commits"]:
        reasons.append("rebase cost exceeds configured bound")
    return not reasons, reasons


def dependency_decision(
    task: dict[str, Any],
    by_id: dict[str, dict[str, Any]],
    limits: dict[str, int],
) -> tuple[bool, bool, list[str]]:
    unresolved: list[dict[str, Any]] = []
    reasons: list[str] = []
    for dependency_id in task["dependencies"]:
        dependency = by_id[dependency_id]
        recorded = task["dependency_commits"].get(dependency_id)
        if (
            dependency["phase"] == "merged"
            and dependency["review_result"] == "pass"
            and dependency["commit"] == recorded
        ):
            continue
        unresolved.append(dependency)
        if dependency["phase"] == "merged":
            reasons.append(f"dependency {dependency_id} reviewed merge commit is stale or absent")
        else:
            reasons.append(f"dependency {dependency_id} is not reviewed and merged")
    if not unresolved:
        return True, False, ["dependencies are reviewed, merged, and current"]
    safe, speculation_reasons = speculation_decision(task, unresolved, limits)
    if safe:
        return True, True, ["safe speculation: frozen interface, disjoint resources, bounded discard/rebase cost"]
    return False, False, reasons + [f"speculation denied: {reason}" for reason in speculation_reasons]


def has_cycle(by_id: dict[str, dict[str, Any]]) -> bool:
    incomplete = {task_id for task_id, task in by_id.items() if task["phase"] != "merged"}
    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(task_id: str) -> bool:
        if task_id in visiting:
            return True
        if task_id in visited:
            return False
        visiting.add(task_id)
        for dependency in by_id[task_id]["dependencies"]:
            if dependency in incomplete and visit(dependency):
                return True
        visiting.remove(task_id)
        visited.add(task_id)
        return False

    return any(visit(task_id) for task_id in sorted(incomplete))


def completion_state(
    state: dict[str, Any],
    by_id: dict[str, dict[str, Any]],
    actions: bool,
    blocked: list[str],
) -> str:
    tasks = list(by_id.values())
    if all(task["phase"] == "merged" or task["status"] == "closed" for task in tasks):
        if state["acceptance_gates"] == "passing":
            return "complete"
        if state["acceptance_gates"] == "human-gated":
            return "human-gated"
        return "blocked"
    if any(task["phase"] in {"implementing", "reviewing", "merging"} for task in tasks):
        return "in-progress"
    if any(task["status"] == "human-gated" for task in tasks):
        return "human-gated"
    if has_cycle(by_id):
        return "cyclic"
    if actions:
        return "in-progress"
    if blocked or any(task["status"] == "blocked" for task in tasks):
        return "blocked"
    return "blocked"


def decide(state: dict[str, Any]) -> dict[str, Any]:
    by_id = validate_state(state)
    tasks = [by_id[task_id] for task_id in sorted(by_id)]
    mode = "serial" if state["capability_tier"] == "host-limited" else "rolling"
    task_reasons: dict[str, list[str]] = defaultdict(list)
    blocked: set[str] = set()

    active_resources = [task for task in tasks if task["phase"] in ACTIVE_RESOURCE_PHASES]
    active_workers = sum(task["phase"] == "implementing" for task in tasks)
    active_reviews = sum(task["phase"] == "reviewing" for task in tasks)
    active_merges = sum(task["phase"] == "merging" for task in tasks)
    capacity = state["capacity"]

    merge_candidates: list[dict[str, Any]] = []
    review_candidates: list[dict[str, Any]] = []
    dispatch_candidates: list[tuple[dict[str, Any], bool, list[str]]] = []

    for task in tasks:
        task_id = task["id"]
        if task["status"] in {"blocked", "human-gated"}:
            blocked.add(task_id)
            task_reasons[task_id].append(f"task status is {task['status']}")
            continue
        if task["contract_hash"] != task["current_contract_hash"] and task["phase"] != "merged":
            blocked.add(task_id)
            task_reasons[task_id].append("stale contract: current contract hash differs")
            continue
        if task["phase"] == "reviewed" and task["review_result"] == "pass":
            merge_candidates.append(task)
        elif task["phase"] == "reviewed":
            blocked.add(task_id)
            task_reasons[task_id].append(f"review result {task['review_result']} blocks merge")
        elif task["phase"] == "implemented":
            review_candidates.append(task)
        elif task["phase"] == "pending" and task["status"] == "open":
            ready, speculative, reasons = dependency_decision(task, by_id, state["speculation_limits"])
            if ready:
                dispatch_candidates.append((task, speculative, reasons))
            else:
                blocked.add(task_id)
                task_reasons[task_id].extend(reasons)

    merges: list[str] = []
    reviews: list[str] = []
    dispatch: list[str] = []
    serial_busy = mode == "serial" and any(
        task["phase"] in {"implementing", "reviewing", "merging"} for task in tasks
    )

    merge_slots = max(0, capacity["merges"] - active_merges)
    if not serial_busy:
        for task in merge_candidates:
            if merge_slots > 0 and (mode == "rolling" or not merges):
                merges.append(task["id"])
                merge_slots -= 1
                task_reasons[task["id"]].append("immediate merge: review passed")
            else:
                blocked.add(task["id"])
                reason = "host-limited serial: another action was selected" if mode == "serial" else "merge capacity exhausted"
                task_reasons[task["id"]].append(reason)
    else:
        for task in merge_candidates:
            blocked.add(task["id"])
            task_reasons[task["id"]].append("host-limited serial: another action is active")

    review_slots = max(0, capacity["reviews"] - active_reviews)
    may_review = not serial_busy and (mode == "rolling" or not merges)
    for task in review_candidates:
        if may_review and review_slots > 0 and (mode == "rolling" or not reviews):
            reviews.append(task["id"])
            review_slots -= 1
            task_reasons[task["id"]].append("review capacity reserved for completed implementation")
        else:
            blocked.add(task["id"])
            if mode == "serial" and (serial_busy or merges or reviews):
                reason = "host-limited serial: another action is active or selected"
            else:
                reason = "review capacity exhausted"
            task_reasons[task["id"]].append(reason)

    worker_slots = max(0, capacity["workers"] - active_workers)
    held = list(active_resources)
    may_dispatch = not serial_busy and (mode == "rolling" or not merges and not reviews)
    for task, speculative, readiness_reasons in dispatch_candidates:
        task_id = task["id"]
        conflicts = conflict_reasons(task, held, capacity["resources"])
        reasons: list[str] = []
        if not may_dispatch or (mode == "serial" and dispatch):
            reasons.append("host-limited serial: another action is active or selected")
        if worker_slots <= 0:
            reasons.append("worker capacity exhausted")
        reasons.extend(conflicts)
        if reasons:
            blocked.add(task_id)
            task_reasons[task_id].extend(readiness_reasons if speculative else [])
            task_reasons[task_id].extend(reasons)
            continue
        dispatch.append(task_id)
        worker_slots -= 1
        held.append(task)
        task_reasons[task_id].extend(readiness_reasons)

    actions = bool(dispatch or reviews or merges)
    completion = completion_state(state, by_id, actions, sorted(blocked))
    held_capacity: dict[str, int] = defaultdict(int)
    selected_capacity: dict[str, int] = defaultdict(int)
    for task in active_resources:
        for name, amount in task["capacity_resources"].items():
            held_capacity[name] += amount
    for task_id in dispatch:
        for name, amount in by_id[task_id]["capacity_resources"].items():
            selected_capacity[name] += amount

    return {
        "dispatch": dispatch,
        "reviews": reviews,
        "merges": merges,
        "blocked": sorted(blocked),
        "mode": mode,
        "reasons": {
            "completion": completion,
            "graph_revision": state["graph_revision"],
            "capacity": {
                "workers": {"used": active_workers, "selected": len(dispatch), "limit": capacity["workers"]},
                "reviews": {"used": active_reviews, "selected": len(reviews), "limit": capacity["reviews"]},
                "merges": {"used": active_merges, "selected": len(merges), "limit": capacity["merges"]},
                "resources": {
                    name: {
                        "used": held_capacity[name],
                        "selected": selected_capacity[name],
                        "limit": limit,
                    }
                    for name, limit in sorted(capacity["resources"].items())
                },
            },
            "tasks": {task_id: task_reasons[task_id] for task_id in sorted(task_reasons)},
        },
    }


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description=__doc__)
    commands = root.add_subparsers(dest="command", required=True)
    decide_parser = commands.add_parser("decide")
    decide_parser.add_argument("state", type=Path)
    return root


def main() -> int:
    args = parser().parse_args()
    try:
        result = decide(read_json(args.state))
    except SchedulerError as exc:
        print(f"sdd scheduler error: {exc}", file=sys.stderr)
        return 1
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
