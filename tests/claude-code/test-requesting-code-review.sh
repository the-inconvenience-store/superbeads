#!/usr/bin/env bash
# Test: requesting-code-review skill — security bug detection
# Verifies that the code-reviewer template catches Critical security issues
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=test-helpers.sh
source "$SCRIPT_DIR/test-helpers.sh"

echo "=== Test: requesting-code-review — Security Bug Detection ==="
echo ""

# Create isolated temp directory for the test repo
TEST_REPO=$(mktemp -d)
trap 'rm -rf "$TEST_REPO"' EXIT

# Plant security bugs in test files
cat > "$TEST_REPO/db.py" <<'EOF'
import sqlite3

def get_user(username):
    """Bug 1: SQL injection via string concatenation."""
    conn = sqlite3.connect("app.db")
    cursor = conn.cursor()
    query = "SELECT * FROM users WHERE username = '" + username + "'"
    cursor.execute(query)
    return cursor.fetchone()
EOF

cat > "$TEST_REPO/auth.py" <<'EOF'
import json

def register_user(username, password):
    """Bug 2: Plaintext password storage — no hashing."""
    user = {"username": username, "password": password}
    with open("users.json", "a") as f:
        f.write(json.dumps(user) + "\n")
    return True
EOF

cat > "$TEST_REPO/api_client.py" <<'EOF'
import requests

def fetch_data(api_key, endpoint):
    """Bug 3: API key logged to stdout."""
    print(f"Calling {endpoint} with api_key={api_key}")
    response = requests.get(endpoint, headers={"Authorization": api_key})
    return response.json()
EOF

# Initialize a real git repo with the planted bugs.
# Use an empty initial commit so the planted files form a real second commit,
# giving git diff a non-empty range to analyze.
cd "$TEST_REPO"
git init --quiet
git config user.email "test@test.com"
git config user.name "Test User"
git commit --allow-empty -m "Initial commit" --quiet
git add .
git commit -m "Add database, auth, and API client modules" --quiet

BASE_SHA=$(git rev-parse HEAD~1)
HEAD_SHA=$(git rev-parse HEAD)

echo "Test repo: $TEST_REPO"
echo "Planted 3 security bugs: SQL injection, plaintext passwords, credential logging"
echo ""
echo "Running code reviewer..."
echo ""

# Return to the plugin repo so Claude can find the code-reviewer.md template
cd "$SCRIPT_DIR/../.."

PROMPT="You are performing a code security review.

Read the code reviewer template at skills/requesting-code-review/code-reviewer.md.

Then review the following code changes using that template:

WHAT_WAS_IMPLEMENTED: Database, authentication, and API client modules
PLAN_OR_REQUIREMENTS: Implement user lookup, registration, and API access with secure coding practices
BASE_SHA: $BASE_SHA
HEAD_SHA: $HEAD_SHA

The git repo to review is at: $TEST_REPO

Run: cd $TEST_REPO && git diff $BASE_SHA..$HEAD_SHA

Apply the code-reviewer.md template to identify Critical security issues in the diff."

OUTPUT=$(timeout 120 claude -p "$PROMPT" --permission-mode bypassPermissions 2>&1)

echo "Analyzing reviewer output..."
echo ""

# Test 1: SQL injection detected
if assert_contains "$OUTPUT" "[Ss][Qq][Ll].*[Ii]njection\|[Ii]njection.*[Ss][Qq][Ll]\|string.*concat\|concat.*query\|parameteriz" \
    "Reviewer detected SQL injection"; then
    : # pass
else
    exit 1
fi

# Test 2: Plaintext password issue detected
if assert_contains "$OUTPUT" "[Pp]laintext\|plain.text\|[Uu]nhash\|[Nn]o.*hash\|[Ww]ithout.*hash\|[Pp]assword.*stored\|bcrypt\|hash.*password" \
    "Reviewer detected plaintext password storage"; then
    : # pass
else
    exit 1
fi

# Test 3: Credential logging issue detected
if assert_contains "$OUTPUT" "[Aa][Pp][Ii].key\|[Cc]redential.*log\|[Ll]og.*credential\|[Tt]oken.*log\|[Ll]og.*token\|[Ss]ecret.*log\|[Pp]rint.*api_key\|sensitive.*log" \
    "Reviewer detected credential logging"; then
    : # pass
else
    exit 1
fi

# Test 4: Output uses Critical severity label (from the template's output format)
if assert_contains "$OUTPUT" "[Cc]ritical" \
    "Reviewer categorized issues as Critical severity"; then
    : # pass
else
    exit 1
fi

echo ""
echo "=== All requesting-code-review security tests passed ==="
