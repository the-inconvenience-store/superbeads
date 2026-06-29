#!/usr/bin/env bash
# build-docs.sh — Full docs build: mkdocs build (skill count is computed by the {{ skill_count }} macro)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo "=== Building MkDocs site ==="
mkdocs build --strict

echo "=== Done ==="
echo "Site built to site/"
echo "To serve locally: mkdocs serve"
echo "To deploy: mkdocs gh-deploy --force"
