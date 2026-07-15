#!/usr/bin/env python3
"""Slow deterministic provider for concurrency, variance, and redaction tests."""

import argparse
import json
import os
import sys
import time
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--variant", choices=("control", "candidate"), required=True)
    parser.add_argument("--sample-index", type=int, required=True)
    args = parser.parse_args()
    prompt = sys.stdin.read()
    if "FAIL_PROVIDER" in prompt:
        print("deterministic provider failure")
        return 7
    time.sleep(0.08)
    if "writing-plans-vertical-v1" in prompt:
        if args.variant == "candidate":
            scores = {
                "vertical_slice": 1.0,
                "outcome_ownership": 1.0,
                "resource_declarations": 0.75 if args.sample_index % 2 else 1.0,
                "early_integration": 1.0,
            }
        else:
            scores = {
                "vertical_slice": 0.0,
                "outcome_ownership": 0.25,
                "resource_declarations": 0.0,
                "early_integration": 0.0,
            }
    elif "brainstorming-product-aware-v1" in prompt:
        if args.variant == "candidate":
            scores = {
                "no_repeat": 1.0,
                "evidence_questions": 1.0,
                "safe_batching": 0.75 if args.sample_index % 2 else 1.0,
                "narrow_product_route": 1.0,
            }
        else:
            scores = {
                "no_repeat": 0.0,
                "evidence_questions": 0.25,
                "safe_batching": 0.0,
                "narrow_product_route": 0.0,
            }
    elif "stress-test-novelty-v1" in prompt:
        if args.variant == "candidate":
            scores = {
                "applicability_matrix": 1.0,
                "novel_complication": 0.75 if args.sample_index % 2 else 1.0,
                "falsifying_case": 1.0,
                "outcome_trace": 1.0,
                "security_evidence": 1.0,
            }
        else:
            scores = {
                "applicability_matrix": 0.0,
                "novel_complication": 0.0,
                "falsifying_case": 0.0,
                "outcome_trace": 0.25,
                "security_evidence": 0.0,
            }
    elif args.variant == "candidate":
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
