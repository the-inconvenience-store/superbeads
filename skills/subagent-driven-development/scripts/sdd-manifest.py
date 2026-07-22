#!/usr/bin/env python3
"""Validate and bind an SDD Context Manifest without orchestrating work."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any


WORKFLOW_VERSION = "0.14.0"
FIELDS = {
    "task_id", "contract_hash", "workflow_version", "graph_hash",
    "governing_artifacts", "outcome_ids", "base_commit",
    "reviewed_dependency_commits", "worktree", "allowed_write_set",
    "generated_write_set", "write_scope_hash", "write_scope_amendments",
    "prohibited_paths", "allocated_resources", "verification_commands",
    "known_conflicts", "model_requested", "model_effective", "model_control",
    "capability_tier", "context_mode", "report_path",
}
CONTRACT_FIELDS = (
    "task_id", "workflow_version", "graph_hash", "governing_artifacts",
    "outcome_ids", "base_commit", "reviewed_dependency_commits", "worktree",
    "allowed_write_set", "generated_write_set", "write_scope_hash",
    "write_scope_amendments", "prohibited_paths", "allocated_resources",
    "verification_commands", "known_conflicts",
)
IDENTITY_FIELDS = (
    "task_id", "contract_hash", "base_commit", "worktree",
    "workflow_version", "graph_hash",
)
HEX40 = re.compile(r"[0-9a-f]{40}")
HEX64 = re.compile(r"[0-9a-f]{64}")
STABLE_ID = re.compile(r"\b[A-Z][A-Z0-9]*(?:-[A-Z0-9]+){1,}\b")


class ManifestError(ValueError):
    pass


def read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ManifestError(f"File: invalid JSON: {exc}") from exc
    if not isinstance(value, dict):
        raise ManifestError("File: expected a JSON object")
    return value


def contract_hash(manifest: dict[str, Any]) -> str:
    payload = {field: manifest.get(field) for field in CONTRACT_FIELDS}
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(encoded).hexdigest()


def write_scope_hash(manifest: dict[str, Any]) -> str:
    payload = {
        "allowed_write_set": sorted(manifest.get("allowed_write_set", [])),
        "generated_write_set": sorted(manifest.get("generated_write_set", [])),
    }
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(encoded).hexdigest()


def path_overlap(left: str, right: str) -> bool:
    return (
        left == right
        or left.startswith(right.rstrip("/") + "/")
        or right.startswith(left.rstrip("/") + "/")
    )


def safe_repo_path(
    value: Any,
    field: str,
    *,
    absolute: bool = False,
    allow_hidden: bool = False,
) -> str:
    if not isinstance(value, str) or not value:
        raise ManifestError(f"{field}: path must be a non-empty string")
    path = Path(value)
    if absolute:
        if not path.is_absolute() or ".." in path.parts:
            raise ManifestError(f"{field}: worktree must be absolute")
    elif (
        path.is_absolute()
        or ".." in path.parts
        or (not allow_hidden and any(part.startswith(".") for part in path.parts))
    ):
        raise ManifestError(f"{field}: path must be trusted, repo-relative, and non-hidden")
    return value


def require_string_array(manifest: dict[str, Any], field: str, *, nonempty: bool) -> list[str]:
    value = manifest.get(field)
    if not isinstance(value, list) or (nonempty and not value):
        raise ManifestError(f"{field}: expected {'non-empty ' if nonempty else ''}array")
    if any(not isinstance(item, str) or not item for item in value) or len(set(value)) != len(value):
        raise ManifestError(f"{field}: values must be unique non-empty strings")
    return value


def validate(manifest: dict[str, Any]) -> None:
    if set(manifest) != FIELDS:
        missing = sorted(FIELDS - set(manifest))
        extra = sorted(set(manifest) - FIELDS)
        raise ManifestError(f"Structure: fields differ: missing={missing}, extra={extra}")
    if not isinstance(manifest["task_id"], str) or not manifest["task_id"]:
        raise ManifestError("task_id: non-empty task identity is required")
    if manifest["workflow_version"] != WORKFLOW_VERSION:
        raise ManifestError(f"workflow_version: must be {WORKFLOW_VERSION}")
    if not isinstance(manifest["graph_hash"], str) or not HEX64.fullmatch(manifest["graph_hash"]):
        raise ManifestError("graph_hash: expected lowercase SHA-256")
    if not isinstance(manifest["base_commit"], str) or not HEX40.fullmatch(manifest["base_commit"]):
        raise ManifestError("base_commit: expected full Git commit SHA")
    if not isinstance(manifest["contract_hash"], str) or not HEX64.fullmatch(manifest["contract_hash"]):
        raise ManifestError("contract_hash: expected lowercase SHA-256")

    artifacts = manifest["governing_artifacts"]
    if not isinstance(artifacts, list) or not artifacts:
        raise ManifestError("governing_artifacts: at least one trusted artifact is required")
    seen: dict[str, str] = {}
    for artifact in artifacts:
        if not isinstance(artifact, dict) or set(artifact) != {"path", "revision"}:
            raise ManifestError("governing_artifacts: each artifact requires path and revision")
        path = safe_repo_path(artifact["path"], "governing_artifacts")
        revision = artifact["revision"]
        if not isinstance(revision, str) or not HEX64.fullmatch(revision):
            raise ManifestError(f"governing_artifacts: immutable SHA-256 revision required for {path}")
        if path in seen and seen[path] != revision:
            raise ManifestError(f"governing_artifacts: conflicting authority revisions for {path}")
        seen[path] = revision

    require_string_array(manifest, "outcome_ids", nonempty=True)
    dependencies = require_string_array(manifest, "reviewed_dependency_commits", nonempty=False)
    if any(not HEX40.fullmatch(item) for item in dependencies):
        raise ManifestError("reviewed_dependency_commits: expected full Git commit SHAs")
    safe_repo_path(manifest["worktree"], "worktree", absolute=True)
    allowed = require_string_array(manifest, "allowed_write_set", nonempty=True)
    generated = require_string_array(manifest, "generated_write_set", nonempty=True)
    prohibited = require_string_array(manifest, "prohibited_paths", nonempty=False)
    for path in allowed:
        safe_repo_path(path, "allowed_write_set")
    for path in prohibited:
        safe_repo_path(path, "prohibited_paths", allow_hidden=True)
    for path in generated:
        safe_repo_path(path, "generated_write_set", allow_hidden=True)
        if not path.startswith(".internal/sdd/"):
            raise ManifestError("generated_write_set: paths must be beneath .internal/sdd/")
    for write_path in allowed + generated:
        for prohibited_path in prohibited:
            if path_overlap(write_path, prohibited_path):
                raise ManifestError(
                    f"prohibited_paths: {prohibited_path} overlaps authorized path {write_path}"
                )
    if manifest["report_path"] not in generated:
        raise ManifestError("generated_write_set: must include report_path")
    if not isinstance(manifest["write_scope_hash"], str) or not HEX64.fullmatch(manifest["write_scope_hash"]):
        raise ManifestError("write_scope_hash: expected lowercase SHA-256")
    expected_scope_hash = write_scope_hash(manifest)
    if manifest["write_scope_hash"] != expected_scope_hash:
        raise ManifestError(f"write_scope_hash: mismatch; expected {expected_scope_hash}")
    amendments = manifest["write_scope_amendments"]
    if not isinstance(amendments, list):
        raise ManifestError("write_scope_amendments: expected array")
    for amendment in amendments:
        required = {"path", "rationale", "overlaps", "status"}
        if not isinstance(amendment, dict) or set(amendment) != required:
            raise ManifestError("write_scope_amendments: invalid amendment record")
        safe_repo_path(amendment["path"], "write_scope_amendments.path")
        if not isinstance(amendment["rationale"], str) or not amendment["rationale"].strip():
            raise ManifestError("write_scope_amendments.rationale: required")
        if not isinstance(amendment["overlaps"], list):
            raise ManifestError("write_scope_amendments.overlaps: expected array")
        if amendment["status"] != "resolved":
            raise ManifestError("write_scope_amendments.status: must be resolved")

    resources = manifest["allocated_resources"]
    if not isinstance(resources, dict) or set(resources) != {"exclusive", "capacity"}:
        raise ManifestError("allocated_resources: requires exclusive and capacity")
    if not isinstance(resources["exclusive"], list) or not isinstance(resources["capacity"], dict):
        raise ManifestError("allocated_resources: invalid resource shapes")
    exclusive = resources["exclusive"]
    if any(not isinstance(item, str) or not item for item in exclusive) or len(set(exclusive)) != len(exclusive):
        raise ManifestError("allocated_resources: exclusive values must be unique non-empty strings")
    if any(
        not isinstance(name, str)
        or not name
        or not isinstance(amount, int)
        or isinstance(amount, bool)
        or amount < 1
        for name, amount in resources["capacity"].items()
    ):
        raise ManifestError("allocated_resources: capacity values must be positive integers")
    require_string_array(manifest, "verification_commands", nonempty=True)
    conflicts = manifest["known_conflicts"]
    if not isinstance(conflicts, list):
        raise ManifestError("known_conflicts: expected array")
    for conflict in conflicts:
        required = {"field", "evidence", "affected_choices", "decision_owner", "status"}
        if not isinstance(conflict, dict) or set(conflict) != required:
            raise ManifestError("known_conflicts: invalid conflict record")
        for field in required - {"affected_choices"}:
            if not isinstance(conflict[field], str) or not conflict[field]:
                raise ManifestError(f"known_conflicts: {field} must be a non-empty string")
        if not isinstance(conflict["affected_choices"], list) or not conflict["affected_choices"]:
            raise ManifestError("known_conflicts: affected_choices must be a non-empty array")
        if conflict["status"] != "resolved":
            raise ManifestError(f"known_conflicts: unresolved authority for {conflict['field']}")

    control = manifest["model_control"]
    requested, effective = manifest["model_requested"], manifest["model_effective"]
    if control not in {"explicit", "inherited", "unavailable"}:
        raise ManifestError("model_control: expected explicit, inherited, or unavailable")
    if control == "explicit" and (
        not isinstance(requested, str) or not requested
        or not isinstance(effective, str) or not effective
    ):
        raise ManifestError("model_control: explicit requires requested and effective models")
    if control == "inherited" and (
        requested is not None or not isinstance(effective, str) or not effective
    ):
        raise ManifestError("model_control: inherited requires null requested and an effective model")
    if control == "unavailable" and (requested is not None or effective is not None):
        raise ManifestError("model_control: unavailable requires null requested and effective models")
    if manifest["capability_tier"] not in {"isolated", "host-limited"}:
        raise ManifestError("capability_tier: expected isolated or host-limited")
    if manifest["context_mode"] not in {"isolated", "host-limited"}:
        raise ManifestError("context_mode: expected isolated or host-limited")
    if manifest["context_mode"] == "isolated" and manifest["capability_tier"] != "isolated":
        raise ManifestError("context_mode: isolated cannot claim a host-limited capability tier")
    report = safe_repo_path(manifest["report_path"], "report_path", allow_hidden=True)
    if not report.startswith(".internal/sdd/"):
        raise ManifestError("report_path: must be beneath .internal/sdd/")
    expected = contract_hash(manifest)
    if manifest["contract_hash"] != expected:
        raise ManifestError(f"contract_hash: mismatch; expected {expected}")


def bind(identity: dict[str, Any], manifest: dict[str, Any]) -> None:
    validate(manifest)
    allowed = set(IDENTITY_FIELDS) | {"correction_lineage"}
    if not set(identity).issubset(allowed) or not set(IDENTITY_FIELDS).issubset(identity):
        raise ManifestError("identity: requires immutable context identity fields")
    if "correction_lineage" in identity:
        lineage = identity["correction_lineage"]
        if (
            not isinstance(lineage, list)
            or any(not isinstance(item, str) or not item for item in lineage)
            or len(set(lineage)) != len(lineage)
        ):
            raise ManifestError("identity: correction_lineage must be unique non-empty strings")
    for field in IDENTITY_FIELDS:
        if identity[field] != manifest[field]:
            raise ManifestError(f"identity:{field}: changed context identity; fresh dispatch required")


def section_bodies(text: str) -> dict[str, str]:
    result: dict[str, list[str]] = {}
    current: str | None = None
    for line in text.splitlines():
        match = re.fullmatch(r"##\s+(.+?)\s*", line)
        if match:
            current = match.group(1)
            result.setdefault(current, [])
        elif current is not None:
            result[current].append(line)
    return {key: "\n".join(lines).strip() for key, lines in result.items()}


def graph_task(graph_path: Path, task_key: str) -> tuple[dict[str, Any], dict[str, str]]:
    graph = read_json(graph_path)
    nodes = graph.get("nodes")
    if not isinstance(nodes, list):
        raise ManifestError("graph: nodes must be an array")
    matches = [node for node in nodes if isinstance(node, dict) and node.get("key") == task_key]
    if len(matches) != 1 or matches[0].get("type") != "task":
        raise ManifestError(f"graph: task key {task_key} must identify exactly one task")
    description = matches[0].get("description")
    if not isinstance(description, str):
        raise ManifestError(f"graph: task {task_key} lacks a description")
    return graph, section_bodies(description)


def task_paths(body: str) -> list[str]:
    paths: set[str] = set()
    for line in body.splitlines():
        if re.match(r"\s*-\s*(Create|Modify|Test):", line, re.I):
            paths.update(re.sub(r":\d+(?:-\d+)?$", "", path) for path in re.findall(r"`([^`]+)`", line))
    if not paths:
        raise ManifestError("graph: task Files must declare at least one Create/Modify/Test path")
    return sorted(paths)


def resource_values(body: str, field: str) -> str:
    match = re.search(rf"(?im)^\s*-\s*{re.escape(field)}:\s*(.+)$", body)
    if not match:
        raise ManifestError(f"graph: Resources missing {field}")
    return match.group(1).strip().rstrip(".")


def parse_capacity(value: str) -> dict[str, int]:
    if value.lower() == "none":
        return {}
    result: dict[str, int] = {}
    for item in value.split(","):
        parts = item.strip().split("=", 1)
        if len(parts) != 2 or not parts[0] or not parts[1].isdigit() or int(parts[1]) < 1:
            raise ManifestError("graph: Capacity resources must use name=positive-integer")
        result[parts[0].strip()] = int(parts[1])
    return result


def artifact_record(value: str) -> dict[str, str]:
    if "=" not in value:
        raise ManifestError("governing_artifact: expected path=sha256")
    path, revision = value.rsplit("=", 1)
    return {"path": path, "revision": revision}


def prepare(args: argparse.Namespace) -> dict[str, Any]:
    _, body = graph_task(args.graph, args.task_key)
    context = body.get("Context", "")
    outcome_match = re.search(r"(?im)^\s*-\s*Outcome IDs:\s*(.+)$", context)
    outcomes = sorted(set(STABLE_ID.findall(outcome_match.group(1)))) if outcome_match else []
    exclusive_text = resource_values(body.get("Resources", ""), "Exclusive resources")
    exclusive = [] if exclusive_text.lower() == "none" else [
        item.strip().strip("`") for item in exclusive_text.split(",") if item.strip()
    ]
    report_path = args.report_path
    manifest: dict[str, Any] = {
        "task_id": args.task_id,
        "contract_hash": "0" * 64,
        "workflow_version": WORKFLOW_VERSION,
        "graph_hash": hashlib.sha256(args.graph.read_bytes()).hexdigest(),
        "governing_artifacts": [artifact_record(value) for value in args.governing_artifact],
        "outcome_ids": outcomes,
        "base_commit": args.base_commit,
        "reviewed_dependency_commits": args.reviewed_dependency,
        "worktree": args.worktree,
        "allowed_write_set": task_paths(body.get("Files", "")),
        "generated_write_set": [report_path],
        "write_scope_hash": "0" * 64,
        "write_scope_amendments": [],
        "prohibited_paths": args.prohibited,
        "allocated_resources": {
            "exclusive": exclusive,
            "capacity": parse_capacity(resource_values(body.get("Resources", ""), "Capacity resources")),
        },
        "verification_commands": args.verify,
        "known_conflicts": [],
        "model_requested": args.model_requested,
        "model_effective": args.model_effective,
        "model_control": args.model_control,
        "capability_tier": args.capability_tier,
        "context_mode": args.context_mode,
        "report_path": report_path,
    }
    manifest["write_scope_hash"] = write_scope_hash(manifest)
    manifest["contract_hash"] = contract_hash(manifest)
    validate(manifest)
    return manifest


def write_manifest(path: Path, manifest: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def check_diff(manifest: dict[str, Any], repo: Path, base: str, head: str) -> list[str]:
    validate(manifest)
    result = subprocess.run(
        ["git", "-C", str(repo), "diff", "--name-only", f"{base}..{head}"],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise ManifestError(f"check-diff: git failed: {result.stderr.strip()}")
    changed = [line for line in result.stdout.splitlines() if line]
    undeclared = [
        path for path in changed
        if not any(path == allowed or path.startswith(allowed.rstrip("/") + "/") for allowed in manifest["allowed_write_set"])
    ]
    if undeclared:
        raise ManifestError(f"allowed_write_set: diff includes undeclared paths: {', '.join(undeclared)}")
    return changed


def amend(manifest: dict[str, Any], graph_path: Path, task_key: str, path: str, rationale: str) -> dict[str, Any]:
    validate(manifest)
    safe_repo_path(path, "amend.add_path")
    if not rationale.strip():
        raise ManifestError("amend.rationale: required")
    graph, _ = graph_task(graph_path, task_key)
    overlaps: list[str] = []
    for node in graph.get("nodes", []):
        if not isinstance(node, dict) or node.get("type") != "task" or node.get("key") == task_key:
            continue
        for other_path in task_paths(section_bodies(node["description"]).get("Files", "")):
            if path_overlap(path, other_path):
                overlaps.append(str(node["key"]))
    if overlaps:
        raise ManifestError(f"amend.add_path: {path} overlaps task {', '.join(sorted(set(overlaps)))}")
    amended = json.loads(json.dumps(manifest))
    amended["allowed_write_set"] = sorted(set(amended["allowed_write_set"]) | {path})
    amended["write_scope_amendments"].append({
        "path": path,
        "rationale": rationale,
        "overlaps": [],
        "status": "resolved",
    })
    amended["write_scope_hash"] = write_scope_hash(amended)
    amended["contract_hash"] = contract_hash(amended)
    validate(amended)
    return amended


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description=__doc__)
    commands = root.add_subparsers(dest="command", required=True)
    validate_parser = commands.add_parser("validate")
    validate_parser.add_argument("manifest", type=Path)
    bind_parser = commands.add_parser("bind")
    bind_parser.add_argument("--identity", type=Path, required=True)
    bind_parser.add_argument("--manifest", type=Path, required=True)
    prepare_parser = commands.add_parser("prepare")
    prepare_parser.add_argument("--graph", type=Path, required=True)
    prepare_parser.add_argument("--task-key", required=True)
    prepare_parser.add_argument("--task-id", required=True)
    prepare_parser.add_argument("--base-commit", required=True)
    prepare_parser.add_argument("--worktree", required=True)
    prepare_parser.add_argument("--governing-artifact", action="append", required=True)
    prepare_parser.add_argument("--reviewed-dependency", action="append", default=[])
    prepare_parser.add_argument("--prohibited", action="append", default=[])
    prepare_parser.add_argument("--verify", action="append", required=True)
    prepare_parser.add_argument("--model-requested")
    prepare_parser.add_argument("--model-effective")
    prepare_parser.add_argument("--model-control", choices=("explicit", "inherited", "unavailable"), required=True)
    prepare_parser.add_argument("--capability-tier", choices=("isolated", "host-limited"), required=True)
    prepare_parser.add_argument("--context-mode", choices=("isolated", "host-limited"), required=True)
    prepare_parser.add_argument("--report-path", required=True)
    prepare_parser.add_argument("--output", type=Path, required=True)
    diff_parser = commands.add_parser("check-diff")
    diff_parser.add_argument("--manifest", type=Path, required=True)
    diff_parser.add_argument("--repo", type=Path, required=True)
    diff_parser.add_argument("--base", required=True)
    diff_parser.add_argument("--head", required=True)
    amend_parser = commands.add_parser("amend")
    amend_parser.add_argument("--manifest", type=Path, required=True)
    amend_parser.add_argument("--graph", type=Path, required=True)
    amend_parser.add_argument("--task-key", required=True)
    amend_parser.add_argument("--add-path", required=True)
    amend_parser.add_argument("--rationale", required=True)
    amend_parser.add_argument("--output", type=Path, required=True)
    return root


def main() -> int:
    args = parser().parse_args()
    try:
        if args.command == "validate":
            manifest = read_json(args.manifest)
            validate(manifest)
            print(f"valid manifest: {manifest['task_id']} {manifest['contract_hash']}")
        elif args.command == "bind":
            manifest = read_json(args.manifest)
            bind(read_json(args.identity), manifest)
            print(f"identity bound: {manifest['task_id']} {manifest['contract_hash']}")
        elif args.command == "prepare":
            manifest = prepare(args)
            write_manifest(args.output, manifest)
            print(f"prepared manifest: {manifest['task_id']} {manifest['contract_hash']}")
        elif args.command == "check-diff":
            changed = check_diff(read_json(args.manifest), args.repo, args.base, args.head)
            print(f"valid diff: {len(changed)} authorized paths")
        else:
            manifest = amend(
                read_json(args.manifest), args.graph, args.task_key, args.add_path, args.rationale
            )
            write_manifest(args.output, manifest)
            print(f"amended manifest: {manifest['task_id']} {manifest['contract_hash']}")
    except ManifestError as exc:
        print(f"sdd manifest error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
