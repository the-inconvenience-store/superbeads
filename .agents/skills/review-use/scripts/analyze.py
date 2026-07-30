#!/usr/bin/env python3
"""Detect registered conversation failures, compare reviews, and render tables."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from datetime import date
from pathlib import Path
from typing import Any


RESULT_FIELDS = {
    "pattern_id", "platform", "session_id", "agent_id", "timestamp",
    "source_path", "source_line", "confidence", "note",
}


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def load_events(path: Path) -> list[dict[str, Any]]:
    events: list[dict[str, Any]] = []
    with path.open(encoding="utf-8") as handle:
        for line_number, raw in enumerate(handle, 1):
            try:
                value = json.loads(raw)
            except json.JSONDecodeError as exc:
                raise ValueError(f"events line {line_number}: {exc}") from exc
            if not isinstance(value, dict) or value.get("schema_version") != 1:
                raise ValueError(f"events line {line_number}: invalid normalized event")
            events.append(value)
    return events


def evidence_hash(pattern_id: str, values: list[Any]) -> str:
    encoded = json.dumps([pattern_id, *values], sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(encoded).hexdigest()


def instance(
    pattern_id: str,
    event: dict[str, Any],
    confidence: str,
    note: str,
    matched_value: Any,
) -> dict[str, Any]:
    digest = evidence_hash(pattern_id, [
        event.get("platform"), event.get("session_id"), event.get("agent_id"),
        event.get("source_path"), event.get("source_line"), matched_value,
    ])
    return {
        "instance_id": f"{pattern_id}-{digest[:12]}",
        "pattern_id": pattern_id,
        "platform": event.get("platform", "unknown"),
        "session_id": event.get("session_id", "unknown"),
        "agent_id": event.get("agent_id"),
        "timestamp": event.get("timestamp"),
        "source_path": event.get("source_path", "unknown"),
        "source_line": event.get("source_line", 0),
        "confidence": confidence,
        "evidence_hash": digest,
        "note": note,
    }


def corpus_metrics(events: list[dict[str, Any]]) -> dict[str, Any]:
    session_roles: dict[tuple[Any, ...], str] = {}
    unavailable = 0
    wait_events = 0
    completion_wait_events = 0
    poll_events = 0
    requested_sleep_seconds = 0.0
    poll_session_keys: set[tuple[Any, ...]] = set()
    shell_poll = re.compile(
        r"(?is)\b(?:sleep|usleep)\b.*(?:\bps\b|\bpgrep\b|\btail\b|\bhead\b|"
        r"\bstatus\b|\bjobs\b|events?\.jsonl|last-message|output)"
    )
    for event in events:
        key = (
            event.get("platform"), event.get("source_path"),
            event.get("session_id"), event.get("agent_id"),
        )
        if event.get("agent_role") == "main":
            session_roles[key] = "main"
        else:
            session_roles.setdefault(key, "subagent")
        if event.get("content_available") is False:
            unavailable += 1
        tool_name = event.get("tool_name")
        command = event.get("command") or ""
        is_shell_poll = bool(shell_poll.search(command))
        is_write_poll = tool_name == "write_stdin" or bool(
            re.search(r"\bwrite_stdin\b", command)
        )
        is_completion_wait = tool_name in {"wait_agent", "wait"} or bool(
            re.search(r"\bwait_agent\b", command)
        )
        if is_shell_poll or is_write_poll:
            poll_events += 1
            poll_session_keys.add(key)
        if is_shell_poll:
            for amount, unit in re.findall(
                r"(?i)\bsleep\s+([0-9]+(?:\.[0-9]+)?)([smh]?)\b", command
            ):
                requested_sleep_seconds += float(amount) * {
                    "": 1.0, "s": 1.0, "m": 60.0, "h": 3600.0,
                }[unit.lower()]
        if is_completion_wait:
            completion_wait_events += 1
        if is_shell_poll or is_write_poll or is_completion_wait:
            wait_events += 1
    main = {key for key, role in session_roles.items() if role == "main"}
    subagents = set(session_roles) - main
    session_keys = set(session_roles)
    sessions = len(session_keys)
    return {
        "sessions": sessions,
        "main_sessions": len(main),
        "subagent_sessions": len(subagents),
        "events": len(events),
        "unavailable_content": unavailable,
        "wait_events": wait_events,
        "wait_events_per_session": wait_events / sessions if sessions else 0.0,
        "completion_wait_events": completion_wait_events,
        "poll_events": poll_events,
        "poll_sessions": len(poll_session_keys),
        "poll_events_per_session": poll_events / sessions if sessions else 0.0,
        "requested_sleep_seconds": requested_sleep_seconds,
    }


def compare_metric(value: float, operator: str, threshold: float) -> bool:
    operations = {
        ">": value > threshold,
        ">=": value >= threshold,
        "<": value < threshold,
        "<=": value <= threshold,
        "==": value == threshold,
    }
    if operator not in operations:
        raise ValueError(f"unsupported metric operator {operator}")
    return operations[operator]


def automatic_instances(
    pattern: dict[str, Any],
    events: list[dict[str, Any]],
    metrics: dict[str, Any],
) -> list[dict[str, Any]]:
    detector = pattern["detector"]
    kind, config = detector["kind"], detector["config"]
    if kind == "manual":
        return []
    if kind in {"event-regex", "command-regex"}:
        field = config.get("field", "text" if kind == "event-regex" else "command")
        expression = re.compile(config["pattern"])
        matches: list[dict[str, Any]] = []
        for event in events:
            value = event.get(field)
            if isinstance(value, str) and expression.search(value):
                matches.append(instance(
                    pattern["id"], event, "high",
                    f"Matched declarative {kind} on normalized {field}.", value,
                ))
        return matches
    if kind == "metric-threshold":
        metric = config["metric"]
        observed = float(metrics.get(metric, 0.0))
        threshold = float(config["value"])
        if not compare_metric(observed, config["operator"], threshold):
            return []
        synthetic = {
            "platform": "mixed",
            "session_id": "corpus",
            "agent_id": None,
            "timestamp": None,
            "source_path": "normalized-corpus",
            "source_line": 0,
        }
        return [instance(
            pattern["id"], synthetic, "medium",
            f"Metric {metric} crossed its registered threshold.", observed,
        )]
    raise ValueError(f"unsupported detector kind {kind}")


def manual_instances(path: Path | None, known_ids: set[str]) -> list[dict[str, Any]]:
    if path is None:
        return []
    document = load_json(path)
    if not isinstance(document, dict) or not isinstance(document.get("instances"), list):
        raise ValueError("manual instances require an instances array")
    result: list[dict[str, Any]] = []
    for index, raw in enumerate(document["instances"]):
        if not isinstance(raw, dict) or set(raw) != RESULT_FIELDS:
            raise ValueError(f"manual instances[{index}] fields differ")
        if raw["pattern_id"] not in known_ids:
            raise ValueError(f"manual instances[{index}] has unknown pattern")
        if raw["confidence"] not in {"high", "medium", "low"}:
            raise ValueError(f"manual instances[{index}] confidence is invalid")
        result.append(instance(
            raw["pattern_id"], raw, raw["confidence"], "Manually confirmed by reviewer.",
            [raw["note"], raw["source_path"], raw["source_line"]],
        ))
    return result


def latest_previous(paths: list[Path]) -> dict[str, Any] | None:
    candidates = []
    for path in paths:
        value = load_json(path)
        if isinstance(value, dict) and value.get("status") == "complete":
            candidates.append(value)
    return max(candidates, key=lambda value: value.get("date", "")) if candidates else None


def trend(current: float, previous: float | None) -> str:
    if previous is None:
        return "new"
    if abs(current - previous) < 1e-9:
        return "flat"
    return "rising" if current > previous else "falling"


def scan(args: argparse.Namespace) -> None:
    events = load_events(args.events)
    registry = load_json(args.registry)
    if not isinstance(registry, dict) or registry.get("schema_version") != 1 or not isinstance(registry.get("patterns"), list):
        raise ValueError("registry must contain schema_version 1 and patterns")
    metrics = corpus_metrics(events)
    patterns = registry["patterns"]
    known_ids = {pattern["id"] for pattern in patterns}
    found = [item for pattern in patterns for item in automatic_instances(pattern, events, metrics)]
    found.extend(manual_instances(args.manual, known_ids))
    deduplicated = {item["instance_id"]: item for item in found}
    instances = sorted(deduplicated.values(), key=lambda item: (item["pattern_id"], item["instance_id"]))
    previous = latest_previous(args.prior)
    previous_by_id = {
        item["pattern_id"]: item for item in (previous.get("failures", []) if previous else [])
    }
    sessions = metrics["sessions"]
    failures: list[dict[str, Any]] = []
    for pattern in patterns:
        matching = [item for item in instances if item["pattern_id"] == pattern["id"]]
        count = len(matching)
        rate = count * 100.0 / sessions if sessions else 0.0
        prior = previous_by_id.get(pattern["id"])
        previous_rate = prior.get("rate_per_100_sessions") if prior else None
        failures.append({
            "pattern_id": pattern["id"],
            "title": pattern["title"],
            "status": pattern["status"],
            "count": count,
            "rate_per_100_sessions": round(rate, 4),
            "previous_rate": previous_rate,
            "delta_previous": round(rate - previous_rate, 4) if isinstance(previous_rate, (int, float)) else None,
            "trend": trend(rate, previous_rate),
            "confidence": (
                "high" if matching and all(item["confidence"] == "high" for item in matching)
                else "mixed" if matching else "none"
            ),
        })
    output = {
        "schema_version": 1,
        "review_id": args.review_id,
        "date": args.date,
        "status": "complete",
        "scope": args.scope,
        "registry_revision": hashlib.sha256(args.registry.read_bytes()).hexdigest(),
        "corpus": metrics,
        "failures": failures,
        "instances": instances,
        "previous_review_id": previous.get("review_id") if previous else None,
        "limitations": [
            "Text-dependent findings may be undercounted where content_available is false.",
            "Declarative matches require reviewer vetting before recommendations or registry additions.",
        ],
        "registry_changes": [],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"wrote review data: {args.output}")


def cell(value: Any) -> str:
    return str(value if value is not None else "—").replace("|", "\\|").replace("\n", " ")


def render(args: argparse.Namespace) -> None:
    if args.output.exists() and not args.replace:
        raise ValueError(f"refusing to overwrite {args.output}; pass --replace for this exact path")
    data = load_json(args.data)
    corpus = data["corpus"]
    lines = [
        f"# Superbeads usage review: {data['scope']}",
        "",
        f"> Date: {data['date']}",
        f"> Review ID: {data['review_id']}",
        f"> Corpus: {corpus['sessions']} sessions ({corpus['main_sessions']} main, {corpus['subagent_sessions']} subagent)",
        "",
        "## Verdict", "", args.verdict, "",
        "## Coverage and limitations", "",
        f"- Normalized events: {corpus['events']}.",
        f"- Unavailable-content events: {corpus['unavailable_content']}.",
        f"- Shell polling requested {corpus.get('requested_sleep_seconds', 0):g} "
        "seconds of sleep. Requested sleep can overlap external work and is not "
        "elapsed waste.",
        *[f"- {item}" for item in data.get("limitations", [])], "",
        "## Failure summary", "",
        "| Pattern ID | Title | Status | Count | Per 100 sessions | Previous rate | Trend | Confidence |",
        "|---|---|---|---:|---:|---:|---|---|",
    ]
    for row in data["failures"]:
        lines.append("| " + " | ".join(cell(row[key]) for key in (
            "pattern_id", "title", "status", "count", "rate_per_100_sessions",
            "previous_rate", "trend", "confidence",
        )) + " |")
    lines.extend([
        "", "## Failure instances", "",
        "| Instance ID | Pattern ID | Platform | Session / agent | Timestamp | Source line | Confidence | Evidence hash | Note |",
        "|---|---|---|---|---|---|---|---|---|",
    ])
    for row in data["instances"]:
        session = f"{row['session_id']} / {row.get('agent_id') or 'main'}"
        lines.append("| " + " | ".join(cell(value) for value in (
            row["instance_id"], row["pattern_id"], row["platform"], session,
            row.get("timestamp"), f"{row['source_path']}:{row['source_line']}",
            row["confidence"], row["evidence_hash"], row["note"],
        )) + " |")
    lines.extend([
        "", "## Longitudinal trends", "",
        f"Compared with: {data.get('previous_review_id') or 'no prior comparable review'}.", "",
        "## Emergent behaviors to encourage and constrain", "",
        "Use the reviewed evidence above to record positive and harmful emergent behavior.", "",
        "## Recommendations", "",
        "Recommendations require reviewer-vetted evidence and an explicit actor/action.", "",
        "## Registry changes", "",
        "No registry change is implied by a detector match. Record confirmed additions, reactivations, retirements, or none.", "",
        "## Evidence commands and source index", "",
        f"- Registry revision: `{data['registry_revision']}`.",
        f"- Machine-readable companion: `{args.data}`.", "",
    ])
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote review document: {args.output}")


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description=__doc__)
    commands = root.add_subparsers(dest="command", required=True)
    scan_parser = commands.add_parser("scan")
    scan_parser.add_argument("--events", type=Path, required=True)
    scan_parser.add_argument("--registry", type=Path, required=True)
    scan_parser.add_argument("--manual", type=Path)
    scan_parser.add_argument("--prior", type=Path, action="append", default=[])
    scan_parser.add_argument("--review-id", required=True)
    scan_parser.add_argument("--date", required=True)
    scan_parser.add_argument("--scope", required=True)
    scan_parser.add_argument("--output", type=Path, required=True)
    render_parser = commands.add_parser("render")
    render_parser.add_argument("--data", type=Path, required=True)
    render_parser.add_argument("--output", type=Path, required=True)
    render_parser.add_argument("--verdict", required=True)
    render_parser.add_argument("--replace", action="store_true")
    return root


def main() -> int:
    args = parser().parse_args()
    try:
        date.fromisoformat(args.date) if args.command == "scan" else None
        scan(args) if args.command == "scan" else render(args)
    except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError, re.error) as exc:
        print(f"review-use analyze error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
