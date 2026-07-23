#!/usr/bin/env python3
"""Validate a Superbeads graph plan and its vertical Slice Contracts."""

from __future__ import annotations

import json
import re
import sys
from collections import deque
from itertools import combinations
from pathlib import Path
from typing import Any


TASK_SECTIONS = (
    "Context",
    "Outcome",
    "Domain Contract",
    "Files",
    "Resources",
    "Interfaces",
    "Acceptance Criteria",
    "Integration Checkpoint",
    "Implementation Notes",
)
OUTCOME_ID = re.compile(r"\b[A-Z][A-Z0-9]*(?:-[A-Z0-9]+){1,}\b")
PLACEHOLDER = re.compile(
    r"(?i)\b(TBD|TODO|fill in|implement later|similar to task)\b|"
    r"<(?:topic|feature|path|file|name|value|id|command|reason)>"
)
DEFERRED_SEAM = re.compile(
    r"(?i)(integration (?:is )?deferred|later downstream task|later task|"
    r"downstream task|final task only|no consumer|scaffolding only|schema-only)"
)
COMPLEXITY_BOUNDARIES = {
    "authority", "parsing", "persistence", "concurrency", "recovery",
    "protocol", "security", "evidence",
}
MAX_ACCEPTANCE_CRITERIA = 6


class GraphError(ValueError):
    pass


def sections(text: str) -> tuple[list[str], dict[str, str]]:
    order: list[str] = []
    bodies: dict[str, list[str]] = {}
    current: str | None = None
    for line in text.splitlines():
        match = re.fullmatch(r"##\s+(.+?)\s*", line)
        if match:
            current = match.group(1)
            order.append(current)
            bodies.setdefault(current, [])
        elif current is not None:
            bodies[current].append(line)
    return order, {key: "\n".join(value).strip() for key, value in bodies.items()}


def error(errors: list[str], key: str, section: str, reason: str) -> None:
    errors.append(f"{key}: {section}: {reason}")


def read_graph(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise GraphError(str(exc)) from exc
    if not isinstance(value, dict):
        raise GraphError("graph must be a JSON object")
    return value


def graph_shape(document: dict[str, Any], errors: list[str]) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    if set(document) != {"nodes", "edges"}:
        error(errors, "graph", "Structure", "top-level keys must be nodes and edges")
    nodes = document.get("nodes")
    edges = document.get("edges")
    if not isinstance(nodes, list) or not isinstance(edges, list):
        error(errors, "graph", "Structure", "nodes and edges must be arrays")
        return [], []
    return nodes, edges


def validate_nodes(nodes: list[dict[str, Any]], errors: list[str]) -> tuple[dict[str, dict[str, Any]], dict[str, dict[str, str]]]:
    by_key: dict[str, dict[str, Any]] = {}
    parsed: dict[str, dict[str, str]] = {}
    epics: list[str] = []
    for raw in nodes:
        if not isinstance(raw, dict):
            error(errors, "graph", "Nodes", "every node must be an object")
            continue
        key = raw.get("key")
        if not isinstance(key, str) or not key:
            error(errors, "graph", "Nodes", "every node needs a non-empty key")
            continue
        if key in by_key:
            error(errors, key, "Structure", "duplicate node key")
            continue
        by_key[key] = raw
        node_type = raw.get("type")
        allowed = {"key", "title", "type", "priority", "description"}
        if node_type == "task":
            allowed.add("parent_key")
        if set(raw) != allowed:
            error(errors, key, "Structure", f"node keys must be {sorted(allowed)}")
        if node_type not in {"epic", "task"}:
            error(errors, key, "Structure", "type must be epic or task")
            continue
        if not isinstance(raw.get("title"), str) or not raw["title"]:
            error(errors, key, "Structure", "title is required")
        if isinstance(raw.get("priority"), bool) or not isinstance(raw.get("priority"), int):
            error(errors, key, "Structure", "integer priority is required")
        description = raw.get("description")
        if not isinstance(description, str) or not description.strip():
            error(errors, key, "Structure", "description is required")
            continue
        order, body = sections(description)
        parsed[key] = body
        if PLACEHOLDER.search(description):
            error(errors, key, "Description", "placeholder text is forbidden")
        if node_type == "epic":
            epics.append(key)
            for section in ("Outcome Trace", "Success Criteria"):
                if not body.get(section):
                    error(errors, key, section, "required epic section is missing or empty")
        else:
            for section in TASK_SECTIONS:
                count = order.count(section)
                if count != 1 or not body.get(section):
                    error(errors, key, section, "required task section must appear once and be non-empty")
            present = [item for item in order if item in TASK_SECTIONS]
            if present != [item for item in TASK_SECTIONS if item in body]:
                error(errors, key, "Structure", "task sections are out of canonical order")
    if len(epics) != 1:
        error(errors, "graph", "Structure", "graph must contain exactly one epic")
    epic_key = epics[0] if len(epics) == 1 else None
    if epic_key:
        for key, node in by_key.items():
            if node.get("type") == "task" and node.get("parent_key") != epic_key:
                error(errors, key, "Structure", f"parent_key must be {epic_key}")
    return by_key, parsed


def validate_edges(edges: list[dict[str, Any]], tasks: set[str], errors: list[str]) -> dict[str, set[str]]:
    prerequisites = {key: set() for key in tasks}
    seen: set[tuple[str, str]] = set()
    for raw in edges:
        if not isinstance(raw, dict) or set(raw) != {"from_key", "to_key", "type"}:
            error(errors, "graph", "Edges", "each edge requires from_key, to_key, and type")
            continue
        source, target = raw.get("from_key"), raw.get("to_key")
        if raw.get("type") != "blocks" or source not in tasks or target not in tasks:
            error(errors, "graph", "Edges", "blocks edges must reference task keys")
            continue
        if source == target or (source, target) in seen:
            error(errors, str(source), "Edges", "self or duplicate dependency")
            continue
        seen.add((source, target))
        prerequisites[source].add(target)
    indegree = {key: len(value) for key, value in prerequisites.items()}
    dependents = {key: set() for key in tasks}
    for dependent, prereqs in prerequisites.items():
        for prereq in prereqs:
            dependents[prereq].add(dependent)
    queue = deque(key for key, degree in indegree.items() if degree == 0)
    visited = 0
    while queue:
        key = queue.popleft()
        visited += 1
        for dependent in dependents[key]:
            indegree[dependent] -= 1
            if indegree[dependent] == 0:
                queue.append(dependent)
    if visited != len(tasks):
        error(errors, "graph", "Edges", "dependency graph contains a cycle")
    for source, target in seen:
        prerequisites[source].remove(target)
        if reaches(source, target, prerequisites):
            error(errors, source, "Edges", f"transitively redundant blocks edge to {target}")
        prerequisites[source].add(target)
    return prerequisites


def outcome_ids(text: str) -> set[str]:
    return set(OUTCOME_ID.findall(text))


def validate_contracts(by_key: dict[str, dict[str, Any]], parsed: dict[str, dict[str, str]], prerequisites: dict[str, set[str]], errors: list[str]) -> set[str]:
    epic_key = next((key for key, node in by_key.items() if node.get("type") == "epic"), "epic")
    epic_outcomes = {
        match.group(1)
        for line in parsed.get(epic_key, {}).get("Outcome Trace", "").splitlines()
        if (match := re.match(r"\s*-\s*([A-Z][A-Z0-9]*(?:-[A-Z0-9]+)+)\s*:", line))
    }
    tasks = {key for key, node in by_key.items() if node.get("type") == "task"}
    task_outcomes: dict[str, set[str]] = {}
    for key in tasks:
        body = parsed.get(key, {})
        context = body.get("Context", "")
        match = re.search(r"(?im)^\s*-\s*Outcome IDs:\s*(.+)$", context)
        ids = outcome_ids(match.group(1)) if match else set()
        task_outcomes[key] = ids
        if not ids:
            error(errors, key, "Context", "Outcome IDs must name at least one stable ID")
        for field in ("Product contract:", "Spec:", "Outcome IDs:", "External ref:", "Why this slice exists:"):
            if field.lower() not in context.lower():
                error(errors, key, "Context", f"missing field {field}")
        complexity = re.search(r"(?im)^\s*-\s*Complexity boundaries:\s*(.+)$", context)
        if complexity:
            values = {
                value.strip().lower().rstrip(".")
                for value in complexity.group(1).split(",")
                if value.strip() and value.strip().lower().rstrip(".") != "none"
            }
            unknown = values - COMPLEXITY_BOUNDARIES
            if unknown:
                error(errors, key, "Context", f"unknown complexity boundaries: {', '.join(sorted(unknown))}")
            if len(values) > 2:
                error(
                    errors,
                    key,
                    "Context",
                    "slice complexity spans more than two high-risk boundaries; split the slice before SDD",
                )
        outcome = body.get("Outcome", "")
        for field in (
            "Actor / entry interface:",
            "Observable result:",
            "Durable result / find-again path:",
            "Denied/failure/recovery result:",
        ):
            if field.lower() not in outcome.lower():
                error(errors, key, "Outcome", f"missing field {field}")
        acceptance = body.get("Acceptance Criteria", "")
        acceptance_count = sum(
            1 for line in acceptance.splitlines() if re.match(r"^\s*-\s+\S", line)
        )
        if acceptance_count > MAX_ACCEPTANCE_CRITERIA:
            error(
                errors,
                key,
                "Acceptance Criteria",
                f"acceptance density exceeds {MAX_ACCEPTANCE_CRITERIA} independently reviewable results; split the slice",
            )
        resources = body.get("Resources", "")
        for field in ("Exclusive resources:", "Capacity resources:"):
            if field.lower() not in resources.lower():
                error(errors, key, "Resources", f"missing field {field}")
        integration = body.get("Integration Checkpoint", "")
        if DEFERRED_SEAM.search(integration) or DEFERRED_SEAM.search(outcome):
            exception = "Integration-risk exception:" in body.get("Domain Contract", "")
            link = "Downstream acceptance link:" in body.get("Domain Contract", "")
            if not (exception and link):
                error(errors, key, "Integration Checkpoint", "horizontal or deferred first-consumer seam")
        all_text = by_key[key].get("description", "")
        if re.search(r"(?i)Speculative execution:\s*yes", all_text):
            for phrase in ("Frozen interface:", "Disjoint resources:", "Bounded discard/rebase cost:"):
                if phrase not in all_text:
                    error(errors, key, "Resources", f"speculative execution missing {phrase}")

    if not epic_outcomes:
        error(errors, epic_key, "Outcome Trace", "at least one stable outcome ID is required")
    for outcome in sorted(epic_outcomes):
        owners = {key for key, ids in task_outcomes.items() if outcome in ids}
        if not owners:
            error(errors, epic_key, "Outcome Trace", f"orphan outcome without implementation owner: {outcome}")
            continue
        terminals = {key for key in tasks if not any(key in prereqs for prereqs in prerequisites.values())}
        if not owners.intersection(terminals):
            error(errors, epic_key, "Outcome Trace", f"outcome lacks a final terminal gate: {outcome}")
    undocumented = sorted(set().union(*task_outcomes.values()) - epic_outcomes) if task_outcomes else []
    for outcome in undocumented:
        error(errors, epic_key, "Outcome Trace", f"task references undocumented outcome: {outcome}")
    return epic_outcomes


def paths_for(body: str) -> set[str]:
    paths: set[str] = set()
    for line in body.splitlines():
        if re.match(r"\s*-\s*(Create|Modify|Test):", line, re.I):
            paths.update(
                re.sub(r":\d+(?:-\d+)?$", "", path)
                for path in re.findall(r"`([^`]+)`", line)
            )
    return paths


def named_values(body: str, field: str) -> set[str] | None:
    match = re.search(rf"(?im)^\s*-\s*{re.escape(field)}:\s*(.+)$", body)
    if not match:
        return None
    value = match.group(1).strip().rstrip(".")
    if value.lower() == "none":
        return set()
    return set(OUTCOME_ID.findall(value))


def hard_ordering(body: str, tasks: set[str], key: str, errors: list[str]) -> dict[str, str]:
    match = re.search(r"(?im)^\s*-\s*Hard ordering constraints:\s*(.+)$", body)
    if not match:
        error(errors, key, "Interfaces", "missing field Hard ordering constraints:")
        return {}
    value = match.group(1).strip().rstrip(".")
    if value.lower() == "none":
        return {}
    result: dict[str, str] = {}
    for item in value.split(";"):
        parts = re.split(r"\s*(?::|—)\s*", item.strip(), maxsplit=1)
        if len(parts) != 2 or parts[0] not in tasks or len(parts[1].split()) < 3:
            error(errors, key, "Interfaces", "hard ordering requires '<task>: <concrete irreversible reason>'")
            continue
        if not re.search(r"(?i)irrevers|one-way|migration|rollout|destructive", parts[1]):
            error(errors, key, "Interfaces", f"hard ordering for {parts[0]} lacks an irreversible rollout reason")
            continue
        result[parts[0]] = parts[1]
    return result


def validate_edge_semantics(
    tasks: set[str],
    parsed: dict[str, dict[str, str]],
    prerequisites: dict[str, set[str]],
    errors: list[str],
) -> None:
    produced: dict[str, set[str]] = {}
    consumed: dict[str, set[str]] = {}
    hard: dict[str, dict[str, str]] = {}
    for key in tasks:
        interfaces = parsed.get(key, {}).get("Interfaces", "")
        produced_values = named_values(interfaces, "Produces")
        consumed_values = named_values(interfaces, "Consumes")
        if produced_values is None:
            error(errors, key, "Interfaces", "missing field Produces:")
        if consumed_values is None:
            error(errors, key, "Interfaces", "missing field Consumes:")
        produced[key] = produced_values or set()
        consumed[key] = consumed_values or set()
        hard[key] = hard_ordering(interfaces, tasks, key, errors)
    for dependent, prereqs in prerequisites.items():
        for prerequisite in prereqs:
            shared = consumed[dependent] & produced[prerequisite]
            if not shared and prerequisite not in hard[dependent]:
                error(
                    errors,
                    dependent,
                    "Edges",
                    f"unjustified blocks edge to {prerequisite}: name a produced/consumed interface or irreversible hard ordering",
                )


def reaches(start: str, target: str, prerequisites: dict[str, set[str]]) -> bool:
    stack = list(prerequisites.get(start, ()))
    seen: set[str] = set()
    while stack:
        key = stack.pop()
        if key == target:
            return True
        if key not in seen:
            seen.add(key)
            stack.extend(prerequisites.get(key, ()))
    return False


def exclusive_values(body: str) -> set[str]:
    match = re.search(r"(?im)^\s*-\s*Exclusive resources:\s*(.+)$", body)
    if not match:
        return set()
    value = match.group(1).strip().rstrip(".")
    if value.lower() == "none":
        return set()
    return {item.strip().strip("`").lower() for item in value.split(",") if item.strip()}


def paths_overlap(left: set[str], right: set[str]) -> bool:
    return any(
        left_path == right_path
        or left_path.startswith(right_path.rstrip("/") + "/")
        or right_path.startswith(left_path.rstrip("/") + "/")
        for left_path in left
        for right_path in right
    )


def resource_conflicts(tasks: set[str], parsed: dict[str, dict[str, str]], prerequisites: dict[str, set[str]]) -> set[frozenset[str]]:
    files = {key: paths_for(parsed.get(key, {}).get("Files", "")) for key in tasks}
    exclusive = {key: exclusive_values(parsed.get(key, {}).get("Resources", "")) for key in tasks}
    conflicts: set[frozenset[str]] = set()
    ordered = sorted(tasks)
    for index, left in enumerate(ordered):
        for right in ordered[index + 1 :]:
            if reaches(left, right, prerequisites) or reaches(right, left, prerequisites):
                continue
            if paths_overlap(files[left], files[right]) or exclusive[left] & exclusive[right]:
                conflicts.add(frozenset((left, right)))
    return conflicts


def ready_fronts(tasks: set[str], prerequisites: dict[str, set[str]]) -> list[list[str]]:
    remaining = set(tasks)
    done: set[str] = set()
    fronts: list[list[str]] = []
    while remaining:
        front = sorted(key for key in remaining if prerequisites[key] <= done)
        if not front:
            break
        fronts.append(front)
        done.update(front)
        remaining.difference_update(front)
    return fronts


def constrained_width(fronts: list[list[str]], conflicts: set[frozenset[str]]) -> int:
    widest = 0
    for front in fronts:
        for size in range(len(front), 0, -1):
            if any(
                all(frozenset(pair) not in conflicts for pair in combinations(group, 2))
                for group in combinations(front, size)
            ):
                widest = max(widest, size)
                break
    return widest


def validate(document: dict[str, Any]) -> tuple[list[str], int, int, int, int, int]:
    errors: list[str] = []
    nodes, edges = graph_shape(document, errors)
    by_key, parsed = validate_nodes(nodes, errors)
    tasks = {key for key, node in by_key.items() if node.get("type") == "task"}
    prerequisites = validate_edges(edges, tasks, errors)
    outcomes = validate_contracts(by_key, parsed, prerequisites, errors)
    validate_edge_semantics(tasks, parsed, prerequisites, errors)
    conflicts = resource_conflicts(tasks, parsed, prerequisites)
    fronts = ready_fronts(tasks, prerequisites)
    semantic_width = max((len(front) for front in fronts), default=0)
    return errors, len(tasks), len(outcomes), len(fronts), semantic_width, constrained_width(fronts, conflicts)


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: validate-graph-plan.py GRAPH", file=sys.stderr)
        return 2
    path = Path(sys.argv[1])
    try:
        document = read_graph(path)
    except GraphError as exc:
        print(f"graph: File: {exc}")
        return 1
    errors, tasks, outcomes, fronts, semantic_width, resource_width = validate(document)
    if errors:
        print("\n".join(errors))
        return 1
    print(
        f"valid graph: {tasks} tasks, {outcomes} outcomes, {fronts} ready fronts, "
        f"semantic width {semantic_width}, resource-constrained width {resource_width}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
