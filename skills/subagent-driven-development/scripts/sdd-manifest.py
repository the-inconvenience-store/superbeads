#!/usr/bin/env python3
"""Validate and bind an SDD Context Manifest without orchestrating work."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any


WORKFLOW_VERSION = "0.12.0"
FIELDS = {
    "task_id", "contract_hash", "workflow_version", "graph_hash",
    "governing_artifacts", "outcome_ids", "base_commit",
    "reviewed_dependency_commits", "worktree", "allowed_write_set",
    "prohibited_paths", "allocated_resources", "verification_commands",
    "known_conflicts", "model_requested", "model_effective", "model_control",
    "capability_tier", "context_mode", "report_path",
}
CONTRACT_FIELDS = (
    "task_id", "workflow_version", "graph_hash", "governing_artifacts",
    "outcome_ids", "base_commit", "reviewed_dependency_commits", "worktree",
    "allowed_write_set", "prohibited_paths", "allocated_resources",
    "verification_commands", "known_conflicts",
)
IDENTITY_FIELDS = (
    "task_id", "contract_hash", "base_commit", "worktree",
    "workflow_version", "graph_hash",
)
HEX40 = re.compile(r"[0-9a-f]{40}")
HEX64 = re.compile(r"[0-9a-f]{64}")


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
    prohibited = require_string_array(manifest, "prohibited_paths", nonempty=False)
    for path in allowed:
        safe_repo_path(path, "allowed_write_set")
    for path in prohibited:
        safe_repo_path(path, "prohibited_paths", allow_hidden=True)
    if set(allowed).intersection(prohibited):
        raise ManifestError("allowed_write_set: overlaps prohibited_paths")

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


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description=__doc__)
    commands = root.add_subparsers(dest="command", required=True)
    validate_parser = commands.add_parser("validate")
    validate_parser.add_argument("manifest", type=Path)
    bind_parser = commands.add_parser("bind")
    bind_parser.add_argument("--identity", type=Path, required=True)
    bind_parser.add_argument("--manifest", type=Path, required=True)
    return root


def main() -> int:
    args = parser().parse_args()
    try:
        manifest = read_json(args.manifest)
        if args.command == "validate":
            validate(manifest)
            print(f"valid manifest: {manifest['task_id']} {manifest['contract_hash']}")
        else:
            bind(read_json(args.identity), manifest)
            print(f"identity bound: {manifest['task_id']} {manifest['contract_hash']}")
    except ManifestError as exc:
        print(f"sdd manifest error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
