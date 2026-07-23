#!/usr/bin/env python3
"""Render a compact, non-authoritative human review digest from a graph plan."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any


class DigestError(ValueError):
    pass


def sections(text: str) -> dict[str, str]:
    matches = list(re.finditer(r"(?m)^## ([^\n]+)\n", text))
    return {
        match.group(1): text[
            match.end() : matches[index + 1].start()
            if index + 1 < len(matches)
            else len(text)
        ].strip()
        for index, match in enumerate(matches)
    }


def field(body: str, name: str, default: str = "None declared") -> str:
    match = re.search(rf"(?im)^\s*-\s*{re.escape(name)}:\s*(.+)$", body)
    return match.group(1).strip() if match else default


def first_paragraph(text: str) -> str:
    prefix = text.split("\n## ", 1)[0].strip()
    return " ".join(prefix.splitlines()) or "No destination summary supplied."


def cell(value: str) -> str:
    return " ".join(value.replace("|", r"\|").splitlines())


def load(path: Path) -> tuple[dict[str, Any], bytes]:
    try:
        raw = path.read_bytes()
        value = json.loads(raw)
    except (OSError, json.JSONDecodeError) as exc:
        raise DigestError(f"invalid graph: {exc}") from exc
    if not isinstance(value, dict) or set(value) != {"nodes", "edges"}:
        raise DigestError("invalid graph: expected nodes and edges")
    if not isinstance(value["nodes"], list):
        raise DigestError("invalid graph: nodes must be an array")
    return value, raw


def render(path: Path) -> str:
    graph, raw = load(path)
    epics = [
        node
        for node in graph["nodes"]
        if isinstance(node, dict) and node.get("type") == "epic"
    ]
    tasks = [
        node
        for node in graph["nodes"]
        if isinstance(node, dict) and node.get("type") == "task"
    ]
    if len(epics) != 1 or not tasks:
        raise DigestError("invalid graph: expected one epic and at least one task")

    lines = [
        "# Plan Review Digest",
        "",
        f"> Graph: `{path.as_posix()}`",
        f"> Graph SHA-256: `{hashlib.sha256(raw).hexdigest()}`",
        "> This digest is generated; the graph remains the plan of record.",
        "",
        "## Destination",
        "",
        first_paragraph(str(epics[0].get("description", ""))),
        "",
        "## Execution Outline",
        "",
        "| Slice | Demonstrable result | Interfaces | Checkpoint | Principal risk |",
        "|---|---|---|---|---|",
    ]
    risks: set[str] = set()
    for task in tasks:
        body = sections(str(task.get("description", "")))
        context = body.get("Context", "")
        risk = field(context, "Complexity boundaries")
        risks.add(risk)
        interfaces = body.get("Interfaces", "")
        seam = (
            f"produces {field(interfaces, 'Produces')}; "
            f"consumes {field(interfaces, 'Consumes')}"
        )
        lines.append(
            "| "
            + " | ".join(
                cell(value)
                for value in (
                    str(task.get("title", task.get("key", "Unnamed slice"))),
                    field(body.get("Outcome", ""), "Observable result"),
                    seam,
                    body.get("Integration Checkpoint", "None declared"),
                    risk,
                )
            )
            + " |"
        )
    lines.extend(
        [
            "",
            "## Review Hotspots",
            "",
            *[f"- {risk}" for risk in sorted(risks)],
            "",
            "## Open Items",
            "",
            "- None recorded in the validated graph.",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("graph", type=Path)
    args = parser.parse_args()
    try:
        print(render(args.graph), end="")
    except DigestError as exc:
        print(f"review digest error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
