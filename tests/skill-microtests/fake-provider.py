#!/usr/bin/env python3
"""Slow deterministic provider for concurrency, variance, and redaction tests."""

import argparse
import json
import os
import time
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--variant", choices=("control", "candidate"), required=True)
    parser.add_argument("--sample-index", type=int, required=True)
    args = parser.parse_args()
    time.sleep(0.08)
    if args.variant == "candidate":
        vertical = 0.75 if args.sample_index % 2 else 1.0
        scores = {"vertical_slice": vertical, "outcome_trace": 1.0}
    else:
        scores = {"vertical_slice": 0.0, "outcome_trace": 0.5}
    summary = f"FAKE_TOKEN=fake-secret-marker cwd={os.getcwd()}"
    args.output.write_text(
        json.dumps({"rubric_scores": scores, "summary": summary}),
        encoding="utf-8",
    )
    print(summary)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
