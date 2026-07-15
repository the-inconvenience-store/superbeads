#!/usr/bin/env python3
"""Deterministic provider used by the checked-in behavioral baseline."""

import argparse
import json
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--variant", choices=("control", "candidate"), required=True)
    parser.add_argument("--sample-index", type=int, required=True)
    args = parser.parse_args()
    if args.variant == "candidate":
        scores = {"vertical_slice": 1.0, "outcome_trace": 1.0}
        summary = "Candidate preserves outcome trace and vertical slices."
    else:
        scores = {"vertical_slice": 0.0, "outcome_trace": 0.5}
        summary = "Control decomposes work horizontally with partial outcome trace."
    result = {"rubric_scores": scores, "summary": summary}
    args.output.write_text(json.dumps(result), encoding="utf-8")
    print(json.dumps({"sample": args.sample_index, "variant": args.variant}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
