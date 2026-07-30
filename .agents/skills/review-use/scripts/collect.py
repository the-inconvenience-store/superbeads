#!/usr/bin/env python3
"""Discover and normalize Claude and Codex conversation JSONL."""

from __future__ import annotations

import argparse
import json
import sys
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any, Iterable


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def parse_date(value: str | None) -> date | None:
    return date.fromisoformat(value) if value else None


def discover(args: argparse.Namespace) -> None:
    since, until = parse_date(args.since), parse_date(args.until)
    roots = (("claude", args.claude_root), ("codex", args.codex_root))
    files: list[dict[str, str]] = []
    for platform, root in roots:
        if root is None or not root.exists():
            continue
        resolved_root = root.resolve()
        for path in sorted(root.rglob("*.jsonl")):
            if path.is_symlink() or not path.is_file():
                continue
            resolved = path.resolve()
            if resolved_root not in resolved.parents:
                continue
            if args.path_contains and args.path_contains not in str(path):
                continue
            modified = datetime.fromtimestamp(path.stat().st_mtime, timezone.utc).date()
            if since and modified < since:
                continue
            if until and modified > until:
                continue
            files.append({"platform": platform, "path": str(resolved)})
    write_json(args.output, {"schema_version": 1, "files": files})
    print(f"discovered {len(files)} conversation files")


def content_parts(content: Any) -> tuple[str | None, str | None, str | None, bool]:
    if content == "encrypted":
        return None, None, None, False
    if isinstance(content, str):
        return content, None, None, True
    if not isinstance(content, list):
        return None, None, None, content is not None
    texts: list[str] = []
    tool_name: str | None = None
    command: str | None = None
    for item in content:
        if not isinstance(item, dict):
            continue
        if isinstance(item.get("text"), str):
            texts.append(item["text"])
        if item.get("type") in {"tool_use", "function_call", "custom_tool_call"}:
            tool_name = str(item.get("name") or tool_name or "") or None
            raw_input = item.get("input", item.get("arguments"))
            if isinstance(raw_input, dict):
                candidate = raw_input.get("command", raw_input.get("cmd"))
                if isinstance(candidate, str):
                    command = candidate
            elif isinstance(raw_input, str):
                try:
                    parsed = json.loads(raw_input)
                except json.JSONDecodeError:
                    parsed = {}
                candidate = parsed.get("command", parsed.get("cmd")) if isinstance(parsed, dict) else None
                if isinstance(candidate, str):
                    command = candidate
    return "\n".join(texts) or None, tool_name, command, True


def claude_event(record: dict[str, Any], path: Path, line: int) -> dict[str, Any]:
    message = record.get("message") if isinstance(record.get("message"), dict) else {}
    text, tool_name, command, available = content_parts(message.get("content"))
    if not message:
        available = True
    subagent = "subagents" in path.parts or bool(record.get("isSidechain")) or bool(record.get("agentId"))
    return {
        "schema_version": 1,
        "platform": "claude",
        "session_id": str(record.get("sessionId") or path.stem),
        "parent_session_id": str(record.get("sessionId")) if subagent and record.get("sessionId") else None,
        "agent_id": str(record.get("agentId")) if record.get("agentId") else None,
        "agent_role": "subagent" if subagent else "main",
        "source_path": str(path),
        "source_line": line,
        "timestamp": record.get("timestamp"),
        "event_type": str(record.get("type") or "unknown"),
        "actor": str(message.get("role") or record.get("type") or "unknown"),
        "tool_name": tool_name,
        "command": command,
        "text": text,
        "content_available": available,
    }


def codex_events(path: Path, records: Iterable[tuple[int, dict[str, Any]]]) -> Iterable[dict[str, Any]]:
    session_id, parent_id, role = path.stem, None, "main"
    buffered = list(records)
    for _, record in buffered:
        if record.get("type") != "session_meta":
            continue
        payload = record.get("payload") if isinstance(record.get("payload"), dict) else {}
        session_id = str(payload.get("session_id") or payload.get("id") or session_id)
        parent_id = str(payload.get("parent_thread_id")) if payload.get("parent_thread_id") else None
        codex_leaf = (
            payload.get("source") == "exec"
            or payload.get("originator") == "codex_exec"
        )
        role = "subagent" if (
            parent_id
            or codex_leaf
            or payload.get("agent_role") not in {None, "controller", "main"}
        ) else "main"
        break
    for line, record in buffered:
        payload = record.get("payload") if isinstance(record.get("payload"), dict) else {}
        text, tool_name, command, available = content_parts(payload.get("content"))
        if record.get("type") != "response_item" or payload.get("type") != "message":
            available = True
        if payload.get("type") in {"function_call", "custom_tool_call"}:
            tool_name = str(payload.get("name") or tool_name or "") or None
            raw = payload.get("arguments")
            if isinstance(raw, str):
                try:
                    parsed = json.loads(raw)
                except json.JSONDecodeError:
                    parsed = {}
                candidate = parsed.get("command", parsed.get("cmd")) if isinstance(parsed, dict) else None
                command = candidate if isinstance(candidate, str) else command
        yield {
            "schema_version": 1,
            "platform": "codex",
            "session_id": session_id,
            "parent_session_id": parent_id,
            "agent_id": session_id if role == "subagent" else None,
            "agent_role": role,
            "source_path": str(path),
            "source_line": line,
            "timestamp": record.get("timestamp"),
            "event_type": str(record.get("type") or payload.get("type") or "unknown"),
            "actor": str(payload.get("role") or "unknown"),
            "tool_name": tool_name,
            "command": command,
            "text": text,
            "content_available": available,
        }


def read_records(path: Path) -> tuple[list[tuple[int, dict[str, Any]]], int]:
    records: list[tuple[int, dict[str, Any]]] = []
    malformed = 0
    with path.open(encoding="utf-8") as handle:
        for line_number, raw in enumerate(handle, 1):
            try:
                value = json.loads(raw)
            except json.JSONDecodeError:
                malformed += 1
                continue
            if isinstance(value, dict):
                records.append((line_number, value))
    return records, malformed


def normalize(args: argparse.Namespace) -> None:
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    if not isinstance(manifest, dict) or manifest.get("schema_version") != 1 or not isinstance(manifest.get("files"), list):
        raise ValueError("manifest must contain schema_version 1 and files")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    event_count = malformed = 0
    with args.output.open("w", encoding="utf-8") as output:
        for item in manifest["files"]:
            platform, path = item.get("platform"), Path(str(item.get("path")))
            records, bad = read_records(path)
            malformed += bad
            events = (
                (claude_event(record, path, line) for line, record in records)
                if platform == "claude"
                else codex_events(path, records)
            )
            for event in events:
                output.write(json.dumps(event, sort_keys=True) + "\n")
                event_count += 1
    print(f"normalized {event_count} events; malformed={malformed}")


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description=__doc__)
    commands = root.add_subparsers(dest="command", required=True)
    discover_parser = commands.add_parser("discover")
    discover_parser.add_argument("--claude-root", type=Path, default=Path.home() / ".claude/projects")
    discover_parser.add_argument("--codex-root", type=Path, default=Path.home() / ".codex/sessions")
    discover_parser.add_argument("--since")
    discover_parser.add_argument("--until")
    discover_parser.add_argument("--path-contains")
    discover_parser.add_argument("--output", type=Path, required=True)
    normalize_parser = commands.add_parser("normalize")
    normalize_parser.add_argument("--manifest", type=Path, required=True)
    normalize_parser.add_argument("--output", type=Path, required=True)
    return root


def main() -> int:
    args = parser().parse_args()
    try:
        discover(args) if args.command == "discover" else normalize(args)
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as exc:
        print(f"review-use collect error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
