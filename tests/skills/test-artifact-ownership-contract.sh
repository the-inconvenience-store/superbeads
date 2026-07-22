#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PRODUCT="$ROOT/skills/product-definition/SKILL.md"
PRODUCT_TEMPLATE="$ROOT/skills/product-definition/product-contract-template.md"
DESIGN="$ROOT/skills/brainstorming/SKILL.md"
DESIGN_COVERAGE="$ROOT/skills/brainstorming/question-coverage.md"
PLAN="$ROOT/skills/writing-plans/SKILL.md"
SLICE="$ROOT/skills/writing-plans/slice-contract-template.md"

for file in "$PRODUCT" "$DESIGN" "$PLAN"; do
  grep -Fq "## Artifact Ownership" "$file" || {
    echo "FAIL: ${file#$ROOT/} lacks the shared artifact ownership contract" >&2
    exit 1
  }
done

grep -Fqi "observable atomicity and consistency invariants" "$PRODUCT_TEMPLATE"
if grep -Fqi "transaction boundaries" "$PRODUCT_TEMPLATE"; then
  echo "FAIL: product contract still requests implementation transaction boundaries" >&2
  exit 1
fi

for phrase in \
  "Implementation Topology" \
  "State / data owner" \
  "Produces" \
  "Consumes" \
  "Security / authority boundary" \
  "Failure / recovery owner" \
  "Likely write zones" \
  "Semantic prerequisites" \
  "Resource conflicts"; do
  grep -Fqi "$phrase" "$DESIGN_COVERAGE" || {
    echo "FAIL: technical design coverage lacks: $phrase" >&2
    exit 1
  }
done

grep -Fqi "return to product-definition" "$PLAN"
grep -Fqi "return to brainstorming" "$PLAN"
grep -Fqi "must not introduce" "$PLAN"
for phrase in "Outcome IDs" "Produces" "Consumes"; do
  grep -Fqi "$phrase" "$SLICE" || {
    echo "FAIL: slice contract does not reference stable $phrase" >&2
    exit 1
  }
done

echo "PASS: product contract, technical spec, and plan have distinct ownership"
