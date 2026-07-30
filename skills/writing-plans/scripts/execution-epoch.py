#!/usr/bin/env python3
"""Create, check, and invalidate an approved execution epoch."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path, PurePosixPath
from typing import Any


class EpochError(ValueError):
    pass


def read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise EpochError(f"invalid JSON: {exc}") from exc
    if not isinstance(value, dict):
        raise EpochError("expected a JSON object")
    return value


def trusted_path(value: str) -> str:
    path = PurePosixPath(value)
    if not value or path.is_absolute() or ".." in path.parts:
        raise EpochError(f"untrusted repo-relative path: {value}")
    return value


def digest(path: Path) -> str:
    try:
        return hashlib.sha256(path.read_bytes()).hexdigest()
    except OSError as exc:
        raise EpochError(f"cannot read {path}: {exc}") from exc


def record(repo: Path, value: str) -> dict[str, str]:
    relative = trusted_path(value)
    return {"path": relative, "sha256": digest(repo / relative)}


def validate_seams(document: dict[str, Any]) -> list[dict[str, Any]]:
    if document.get("schema_version") != 1 or not isinstance(document.get("seams"), list):
        raise EpochError("seam catalog requires schema_version 1 and a seams array")
    ids: set[str] = set()
    result: list[dict[str, Any]] = []
    for index, seam in enumerate(document["seams"]):
        if not isinstance(seam, dict):
            raise EpochError(f"seams[{index}] must be an object")
        seam_id = seam.get("id")
        risks = seam.get("high_risk_boundaries")
        if not isinstance(seam_id, str) or not seam_id or seam_id in ids:
            raise EpochError(f"seams[{index}].id must be unique and non-empty")
        if (
            not isinstance(risks, list)
            or len(set(risks)) != len(risks)
            or any(not isinstance(item, str) or not item for item in risks)
        ):
            raise EpochError(f"seams[{index}].high_risk_boundaries is invalid")
        ids.add(seam_id)
        result.append({"id": seam_id, "high_risk_boundaries": sorted(risks)})
    return result


def approve(args: argparse.Namespace) -> dict[str, Any]:
    repo = args.repo.resolve()
    seam_path = trusted_path(args.seams)
    seams = validate_seams(read_json(repo / seam_path))
    paths = [args.graph, *args.artifact, seam_path]
    if len(set(paths)) != len(paths):
        raise EpochError("governing paths must be unique")
    value = {
        "schema_version": 1,
        "epoch_id": "",
        "status": "approved",
        "approved_at": args.approved_at,
        "dirty_reason": None,
        "graph": record(repo, args.graph),
        "artifacts": [record(repo, item) for item in args.artifact],
        "seam_catalog": record(repo, seam_path),
        "seams": seams,
        "unresolved_decisions": [],
    }
    encoded = json.dumps(
        {key: value[key] for key in value if key != "epoch_id"},
        sort_keys=True,
        separators=(",", ":"),
    ).encode()
    value["epoch_id"] = hashlib.sha256(encoded).hexdigest()
    return value


def check(repo: Path, epoch: dict[str, Any]) -> None:
    if epoch.get("schema_version") != 1:
        raise EpochError("DESIGN_DIRTY: unsupported execution epoch")
    if epoch.get("status") != "approved":
        raise EpochError(f"DESIGN_DIRTY: {epoch.get('dirty_reason') or 'epoch is not approved'}")
    if epoch.get("unresolved_decisions") != []:
        raise EpochError("DESIGN_DIRTY: unresolved decisions remain")
    records = [epoch.get("graph"), *(epoch.get("artifacts") or []), epoch.get("seam_catalog")]
    for item in records:
        if not isinstance(item, dict) or set(item) != {"path", "sha256"}:
            raise EpochError("DESIGN_DIRTY: malformed governing artifact record")
        actual = digest(repo / trusted_path(item["path"]))
        if actual != item["sha256"]:
            raise EpochError(f"DESIGN_DIRTY: governing artifact changed: {item['path']}")
    seam_document = read_json(repo / epoch["seam_catalog"]["path"])
    if validate_seams(seam_document) != epoch.get("seams"):
        raise EpochError("DESIGN_DIRTY: resolved seam ledger changed")


def write(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description=__doc__)
    commands = root.add_subparsers(dest="command", required=True)
    create = commands.add_parser("approve")
    create.add_argument("--repo", type=Path, required=True)
    create.add_argument("--graph", required=True)
    create.add_argument("--artifact", action="append", required=True)
    create.add_argument("--seams", required=True)
    create.add_argument("--approved-at", required=True)
    create.add_argument("--output", type=Path, required=True)
    verify = commands.add_parser("check")
    verify.add_argument("--repo", type=Path, required=True)
    verify.add_argument("epoch", type=Path)
    invalidate = commands.add_parser("invalidate")
    invalidate.add_argument("epoch", type=Path)
    invalidate.add_argument("--reason", required=True)
    invalidate.add_argument("--output", type=Path, required=True)
    return root


def main() -> int:
    args = parser().parse_args()
    try:
        if args.command == "approve":
            value = approve(args)
            write(args.output, value)
            print(f"approved execution epoch: {value['epoch_id']}")
        elif args.command == "check":
            value = read_json(args.epoch)
            check(args.repo.resolve(), value)
            print(f"PASS approved execution epoch: {value['epoch_id']}")
        else:
            value = read_json(args.epoch)
            value["status"] = "dirty"
            value["dirty_reason"] = args.reason
            write(args.output, value)
            print(f"DESIGN_DIRTY: {args.reason}")
    except EpochError as exc:
        print(f"execution epoch error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
