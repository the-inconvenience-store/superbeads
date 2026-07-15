#!/usr/bin/env python3
"""Snapshot and compare deterministic workflow context metrics."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
PATH_GROUPS = (
    "product_discovery",
    "accepted_contract",
    "internal_bypass",
    "matched_legacy",
)
LIFECYCLE_EVENTS = ("startup", "resume", "clear", "compact")


class MetricsError(ValueError):
    """A precise, user-correctable metrics input error."""


def read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise MetricsError(f"{path}: invalid JSON: {error}") from error
    if not isinstance(value, dict):
        raise MetricsError(f"{path}: expected a JSON object")
    return value


def repo_path(root: Path, raw_path: str, group: str) -> Path:
    if not isinstance(raw_path, str) or not raw_path:
        raise MetricsError(f"{group}: path must be a non-empty string: {raw_path!r}")
    path = Path(raw_path)
    if path.is_absolute():
        raise MetricsError(f"{group}: path must be repo-relative: {raw_path}")
    resolved = (root / path).resolve()
    try:
        resolved.relative_to(root.resolve())
    except ValueError as error:
        raise MetricsError(f"{group}: path escapes repository: {raw_path}") from error
    if not resolved.is_file():
        raise MetricsError(f"{group}: path does not exist: {raw_path}")
    return resolved


def load_path_manifest(root: Path, manifest_path: Path) -> dict[str, list[Path]]:
    manifest = read_json(manifest_path)
    if manifest.get("schema_version") != SCHEMA_VERSION:
        raise MetricsError(
            f"{manifest_path}: schema_version must be {SCHEMA_VERSION}"
        )
    groups: dict[str, list[Path]] = {}
    for group in PATH_GROUPS:
        entries = manifest.get(group)
        if not isinstance(entries, list) or not entries:
            raise MetricsError(f"{manifest_path}: {group} must be a non-empty array")
        seen: set[Path] = set()
        paths: list[Path] = []
        for raw_path in entries:
            path = repo_path(root, raw_path, group)
            if path in seen:
                raise MetricsError(f"{manifest_path}: duplicate path in {group}: {raw_path}")
            seen.add(path)
            paths.append(path)
        groups[group] = paths
    return groups


def count_words(paths: list[Path]) -> int:
    total = 0
    for path in paths:
        result = subprocess.run(
            ["wc", "-w", str(path)],
            check=True,
            capture_output=True,
            text=True,
        )
        total += int(result.stdout.split()[0])
    return total


def frontmatter_description(path: Path) -> str:
    lines = path.read_text(encoding="utf-8").splitlines()
    if not lines or lines[0] != "---":
        raise MetricsError(f"{path}: malformed frontmatter: missing opening delimiter")
    try:
        closing = lines.index("---", 1)
    except ValueError as error:
        raise MetricsError(f"{path}: malformed frontmatter: missing closing delimiter") from error
    descriptions = [
        line.removeprefix("description:").lstrip()
        for line in lines[1:closing]
        if line.startswith("description:")
    ]
    if len(descriptions) != 1 or not descriptions[0]:
        raise MetricsError(f"{path}: malformed frontmatter: expected one description")
    return descriptions[0]


def description_catalogue_bytes(skill_paths: list[Path]) -> int:
    catalogue = "## Skills\n\n" + "".join(
        f"- {frontmatter_description(path)}\n" for path in skill_paths
    )
    return len(catalogue.encode("utf-8"))


def rendered_bytes(root: Path) -> dict[str, int]:
    helper = root / "tests/helpers/render-session-context.sh"
    if not helper.is_file():
        raise MetricsError(f"render helper path does not exist: {helper}")
    rendered: dict[str, int] = {}
    for event in LIFECYCLE_EVENTS:
        result = subprocess.run(
            ["bash", str(helper), event],
            cwd=root,
            check=False,
            capture_output=True,
        )
        if result.returncode != 0:
            detail = result.stderr.decode("utf-8", errors="replace").strip()
            raise MetricsError(f"rendered_bytes.{event}: helper failed: {detail}")
        if result.stdout.count(b"</beads-context>") != 1:
            raise MetricsError(
                f"rendered_bytes.{event}: expected exactly one </beads-context> wrapper"
            )
        if b"\\&lt;" in result.stdout:
            raise MetricsError(
                f"rendered_bytes.{event}: unsafe memory delimiter contains literal backslashes"
            )
        rendered[event] = len(result.stdout)
    return rendered


def snapshot(root: Path, manifest_path: Path) -> dict[str, Any]:
    groups = load_path_manifest(root, manifest_path)
    skills = sorted((root / "skills").glob("*/SKILL.md"))
    if not skills:
        raise MetricsError(f"{root / 'skills'}: no SKILL.md files found")
    loaded = {group: count_words(groups[group]) for group in PATH_GROUPS[:3]}
    return {
        "schema_version": SCHEMA_VERSION,
        "generated_from": {
            "path_manifest": "tests/fixtures/workflow-metrics/paths.json",
            "render_helper": "tests/helpers/render-session-context.sh",
            "skills_glob": "skills/*/SKILL.md",
        },
        "skills_all_words": count_words(skills),
        "loaded_path_words": loaded,
        "matched_legacy_words": count_words(groups["matched_legacy"]),
        "description_bytes": description_catalogue_bytes(skills),
        "rendered_bytes": rendered_bytes(root),
    }


def metric_values(document: dict[str, Any], source: Path) -> dict[str, int]:
    if document.get("schema_version") != SCHEMA_VERSION:
        raise MetricsError(f"{source}: schema_version must be {SCHEMA_VERSION}")
    values: dict[str, int] = {}
    scalar_fields = ("skills_all_words", "matched_legacy_words", "description_bytes")
    for field in scalar_fields:
        values[field] = require_metric(document.get(field), source, field)
    for parent, names in (
        ("loaded_path_words", PATH_GROUPS[:3]),
        ("rendered_bytes", LIFECYCLE_EVENTS),
    ):
        nested = document.get(parent)
        if not isinstance(nested, dict):
            raise MetricsError(f"{source}: {parent} must be an object")
        for name in names:
            field = f"{parent}.{name}"
            values[field] = require_metric(nested.get(name), source, field)
    return values


def require_metric(value: Any, source: Path, field: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value < 0:
        raise MetricsError(f"{source}: {field} must be a non-negative integer")
    return value


def compare(baseline_path: Path, candidate_path: Path) -> int:
    baseline = metric_values(read_json(baseline_path), baseline_path)
    candidate = metric_values(read_json(candidate_path), candidate_path)
    failures = [
        f"{field}: candidate {candidate[field]} exceeds baseline {ceiling}"
        for field, ceiling in baseline.items()
        if candidate[field] > ceiling
    ]
    if failures:
        print("workflow metric ratchet failed:", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1
    print("PASS: workflow metric ratchets")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    snapshot_parser = subparsers.add_parser("snapshot")
    snapshot_parser.add_argument("--output", type=Path, required=True)
    snapshot_parser.add_argument("--root", type=Path)
    snapshot_parser.add_argument("--paths", type=Path)
    compare_parser = subparsers.add_parser("compare")
    compare_parser.add_argument("--baseline", type=Path, required=True)
    compare_parser.add_argument("--candidate", type=Path, required=True)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    try:
        if args.command == "compare":
            return compare(args.baseline, args.candidate)
        root = (args.root or Path(__file__).resolve().parent.parent).resolve()
        manifest_path = args.paths or root / "tests/fixtures/workflow-metrics/paths.json"
        document = snapshot(root, manifest_path)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
        print(f"wrote workflow metrics: {args.output}")
        return 0
    except (MetricsError, OSError, subprocess.SubprocessError, ValueError) as error:
        print(f"workflow metrics error: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
