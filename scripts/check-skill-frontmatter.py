#!/usr/bin/env python3
"""Validate skill frontmatter, trigger descriptions, and catalogue budget."""

import argparse
import re
import sys
from pathlib import Path

DEFAULT_DESCRIPTION_BYTES = 3253
NAME = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
PROCESS_SUMMARY = re.compile(
    r"\b(?:this skill|the skill|workflow|process)\b.*\b"
    r"(?:creates?|dispatches?|runs?|writes?|produces?|ensures?|handles?|covers?|establishes?|requires?)\b",
    re.IGNORECASE,
)


def parse_frontmatter(path: Path) -> tuple[dict[str, str], str]:
    text = path.read_text(encoding="utf-8")
    match = re.match(r"^---\n(.*?)\n---", text, re.DOTALL)
    if not match:
        raise ValueError("missing YAML frontmatter")
    values: dict[str, str] = {}
    raw_description = ""
    for line in match.group(1).strip().splitlines():
        field = re.match(r"^(\w[\w-]*):\s*(.*)", line)
        if not field:
            continue
        key, raw = field.groups()
        values[key] = raw.strip().strip("'\"")
        if key == "description":
            raw_description = raw.strip()
    return values, raw_description


def validate(root: Path, max_description_bytes: int) -> list[str]:
    errors: list[str] = []
    skills = sorted((root / "skills").glob("*/SKILL.md"))
    descriptions: list[str] = []
    if not skills:
        return [f"{root}: no skills/*/SKILL.md files found"]

    for path in skills:
        relative = path.relative_to(root)
        try:
            frontmatter, raw_description = parse_frontmatter(path)
        except ValueError as error:
            errors.append(f"{relative}: {error}")
            continue
        for key in ("name", "description"):
            if not frontmatter.get(key):
                errors.append(f"{relative}: missing required field '{key}'")
        name = frontmatter.get("name", "")
        description = frontmatter.get("description", "")
        if name and not NAME.fullmatch(name):
            errors.append(f"{relative}: name must use lowercase letters, numbers, and hyphens")
        user_invoked = frontmatter.get("disable-model-invocation", "").lower() == "true"
        trigger_prefixes = ("Use when ", "Use before ")
        if description and not user_invoked and not description.startswith(trigger_prefixes):
            errors.append(
                f"{relative}: model-invoked description must start with "
                "'Use when ' or 'Use before '"
            )
        if description and user_invoked and description.startswith(trigger_prefixes):
            errors.append(f"{relative}: user-invoked description must be trigger-free")
        if description and PROCESS_SUMMARY.search(description):
            errors.append(f"{relative}: description summarizes process instead of invocation conditions")
        if len(raw_description.encode("utf-8")) > 1024:
            errors.append(f"{relative}: description exceeds 1024 bytes")
        if raw_description:
            descriptions.append(raw_description)

    catalogue = "## Skills\n\n" + "".join(f"- {value}\n" for value in descriptions)
    description_bytes = len(catalogue.encode("utf-8"))
    if description_bytes > max_description_bytes:
        errors.append(
            f"description catalogue is {description_bytes} bytes; "
            f"maximum is {max_description_bytes}"
        )
    if not errors:
        print(
            f"All {len(skills)} skills have valid trigger frontmatter "
            f"({description_bytes}/{max_description_bytes} description bytes)"
        )
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument(
        "--max-description-bytes", type=int, default=DEFAULT_DESCRIPTION_BYTES
    )
    args = parser.parse_args()
    errors = validate(args.root.resolve(), args.max_description_bytes)
    for error in errors:
        print(error, file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
