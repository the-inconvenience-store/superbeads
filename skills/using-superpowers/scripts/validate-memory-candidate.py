#!/usr/bin/env python3
"""Validate a proposed durable-memory body before it is offered or stored."""

from __future__ import annotations

import re
import sys
from pathlib import Path


FIELDS = (
    "Future decision",
    "Durable insight",
    "Evidence",
    "Invalidated when",
    "Rediscovery cost",
)


class CandidateError(ValueError):
    pass


def parse(text: str) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in text.splitlines():
        match = re.match(r"^([A-Za-z ]+):\s*(.+)$", line)
        if match and match.group(1) in FIELDS:
            if match.group(1) in values:
                raise CandidateError(f"{match.group(1)}: duplicate field")
            values[match.group(1)] = match.group(2).strip()
    missing = [field for field in FIELDS if field not in values]
    if missing:
        raise CandidateError(f"missing required fields: {', '.join(missing)}")
    return values


def validate(values: dict[str, str], text: str) -> None:
    decision_text = f"{values['Future decision']} {values['Durable insight']}"
    if re.search(r"(?i)\b(approved|accepted|completed?|done|ready for (?:sdd|implementation))\b", decision_text):
        raise CandidateError("approval or completion episode is not durable memory")
    if re.search(
        r"(?i)\b(run|execute|invoke|type|use)\s+(git|bd|pytest|bash|npm|node|python|go|cargo|just)\b",
        decision_text,
    ):
        raise CandidateError("procedural recipe belongs in a skill or project instruction")
    if len(re.findall(r"(?i)\b(?:FAIL|Traceback|panic|ERROR)\b", text)) >= 3:
        raise CandidateError("raw failure log must be reduced to a durable root cause")
    if re.search(r"(?i)\b(current branch|HEAD is|next task|resume (?:the|on)|working tree is)\b", decision_text):
        raise CandidateError("current execution state belongs in one expiring continuation, not durable memory")
    if re.search(r"(?i)\b(?:documentation|docs?)\s+(?:lives?|is|are)\s+(?:in|at)\b|\bsee\s+docs?/", decision_text):
        raise CandidateError("artifact pointer is directly searchable and not a durable insight")
    if re.search(r"(?i)\b(password|secret|access token|api key|private key|credential)\s*[:=]", text):
        raise CandidateError("sensitive data must never enter memory")
    evidence = values["Evidence"]
    if not re.search(r"(?:[A-Za-z0-9_.\/-]+:\d+|\bPASS\b|\bclosed bead\b|\bbeads-[A-Za-z0-9.-]+\b)", evidence):
        raise CandidateError("Evidence must cite file:line, passing evidence, or a durable bead")
    if len(values["Future decision"].split()) < 4:
        raise CandidateError("Future decision must name how a later choice changes")
    if len(values["Invalidated when"].split()) < 3:
        raise CandidateError("Invalidated when must name an expiry or superseding event")
    if len(values["Rediscovery cost"].split()) < 4:
        raise CandidateError("Rediscovery cost must explain why ordinary search is insufficient")


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: validate-memory-candidate.py CANDIDATE", file=sys.stderr)
        return 2
    try:
        text = Path(sys.argv[1]).read_text(encoding="utf-8")
        validate(parse(text), text)
    except (OSError, CandidateError) as exc:
        print(f"memory candidate error: {exc}", file=sys.stderr)
        return 1
    print("valid memory candidate")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
