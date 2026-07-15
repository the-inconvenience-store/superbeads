#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCHEDULER="$ROOT/skills/subagent-driven-development/scripts/sdd-scheduler.py"
FIXTURES="$ROOT/tests/fixtures/sdd-scheduler"
REFERENCE="$ROOT/skills/subagent-driven-development/references/scheduling.md"
EXECUTING="$ROOT/skills/executing-plans/SKILL.md"
PARALLEL="$ROOT/skills/dispatching-parallel-agents/SKILL.md"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export PYTHONPYCACHEPREFIX="$TMP/pycache"

python3 -m py_compile "$SCHEDULER"

decide() {
  python3 "$SCHEDULER" decide "$1" >"$2"
}

decide "$FIXTURES/diamond.json" "$TMP/diamond-initial.json"
python3 - "$TMP/diamond-initial.json" <<'PY'
import json, sys
from pathlib import Path
d=json.loads(Path(sys.argv[1]).read_text())
assert d["dispatch"] == ["t1", "t2"]
assert d["reviews"] == [] and d["merges"] == []
assert set(d["blocked"]) == {"t3", "t4", "u1"}
assert "worker capacity" in " ".join(d["reasons"]["tasks"]["u1"])
assert d["mode"] == "rolling" and d["reasons"]["completion"] == "in-progress"
PY

python3 - "$FIXTURES/diamond.json" "$TMP/diamond-review.json" "$TMP/diamond-merged.json" <<'PY'
import json, sys
from pathlib import Path
d=json.loads(Path(sys.argv[1]).read_text())
for task in d["tasks"]:
    if task["id"] in {"t1", "t2"}:
        task["phase"]="implemented"
        task["commit"]=("1" if task["id"] == "t1" else "2") * 40
Path(sys.argv[2]).write_text(json.dumps(d))
for task in d["tasks"]:
    if task["id"] in {"t1", "t2"}:
        task["phase"]="merged"
        task["review_result"]="pass"
    if task["id"] in {"t3", "t4"}:
        task["dependency_commits"]={"t1":"1"*40,"t2":"2"*40}
    if task["id"] == "u1":
        task["phase"]="merged"
        task["review_result"]="pass"
        task["commit"]="3"*40
Path(sys.argv[3]).write_text(json.dumps(d))
PY
decide "$TMP/diamond-review.json" "$TMP/diamond-review-out.json"
python3 - "$TMP/diamond-review-out.json" <<'PY'
import json, sys
from pathlib import Path
d=json.loads(Path(sys.argv[1]).read_text())
assert d["reviews"] == ["t1", "t2"]
assert d["dispatch"] == ["u1"]
PY
decide "$TMP/diamond-merged.json" "$TMP/diamond-merged-out.json"
python3 - "$TMP/diamond-merged-out.json" <<'PY'
import json, sys
from pathlib import Path
d=json.loads(Path(sys.argv[1]).read_text())
assert d["dispatch"] == ["t3", "t4"]
PY

decide "$FIXTURES/resource-conflict.json" "$TMP/resource.json"
python3 - "$TMP/resource.json" <<'PY'
import json, sys
from pathlib import Path
d=json.loads(Path(sys.argv[1]).read_text())
assert d["dispatch"] == ["a"] and d["blocked"] == ["b"]
reason=" ".join(d["reasons"]["tasks"]["b"])
assert "write set" in reason and "exclusive resource" in reason and "capacity resource" in reason
PY

decide "$FIXTURES/speculative-safe.json" "$TMP/safe.json"
decide "$FIXTURES/speculative-unsafe.json" "$TMP/unsafe.json"
python3 - "$TMP/safe.json" "$TMP/unsafe.json" <<'PY'
import json, sys
from pathlib import Path
safe=json.loads(Path(sys.argv[1]).read_text())
unsafe=json.loads(Path(sys.argv[2]).read_text())
assert safe["dispatch"] == ["dependent"]
assert "safe speculation" in " ".join(safe["reasons"]["tasks"]["dependent"])
assert unsafe["dispatch"] == [] and unsafe["blocked"] == ["dependent"]
assert "speculation" in " ".join(unsafe["reasons"]["tasks"]["dependent"])
PY

decide "$FIXTURES/host-limited.json" "$TMP/host.json"
python3 - "$TMP/host.json" <<'PY'
import json, sys
from pathlib import Path
d=json.loads(Path(sys.argv[1]).read_text())
assert d["mode"] == "serial"
assert d["dispatch"] == ["a"] and d["blocked"] == ["b"]
assert "host-limited serial" in " ".join(d["reasons"]["tasks"]["b"])
PY

python3 - "$FIXTURES/diamond.json" "$TMP" <<'PY'
import json, sys
from pathlib import Path
source=json.loads(Path(sys.argv[1]).read_text())
target=Path(sys.argv[2])

stale=json.loads(json.dumps(source))
stale["capacity"]["workers"]=10
stale["tasks"][0]["current_contract_hash"]="c"*64
(target/"stale.json").write_text(json.dumps(stale))

review=json.loads(json.dumps(source))
review["capacity"]["reviews"]=1
for task in review["tasks"]:
    if task["id"] in {"t1","t2"}:
        task["phase"]="implemented"; task["commit"]=("1" if task["id"]=="t1" else "2")*40
(target/"review-capacity.json").write_text(json.dumps(review))

merge=json.loads(json.dumps(review))
merge["capacity"]["reviews"]=2
merge["capacity"]["merges"]=1
for task in merge["tasks"]:
    if task["id"] in {"t1","t2"}:
        task["phase"]="reviewed"; task["review_result"]="pass"
(target/"merge-capacity.json").write_text(json.dumps(merge))

base=source["tasks"][0]
def state(name, tasks, gates="pending"):
    value={k:json.loads(json.dumps(source[k])) for k in ("graph_revision","capability_tier","capacity","speculation_limits")}
    value["tasks"]=tasks; value["acceptance_gates"]=gates
    (target/f"completion-{name}.json").write_text(json.dumps(value))

done=json.loads(json.dumps(base)); done.update(phase="merged", status="closed", review_result="pass", commit="1"*40)
state("complete", [done], "passing")
active=json.loads(json.dumps(base)); active["phase"]="implementing"
state("in-progress", [active])
human=json.loads(json.dumps(base)); human["status"]="human-gated"
state("human-gated", [human])
blocked=json.loads(json.dumps(base)); blocked["status"]="blocked"
state("blocked", [blocked])
review_failed=json.loads(json.dumps(base)); review_failed.update(phase="reviewed", review_result="fail", commit="4"*40)
state("review-failed", [review_failed])
closed_unmerged=json.loads(json.dumps(base)); closed_unmerged["status"]="closed"
state("closed-unmerged", [closed_unmerged], "passing")
c1=json.loads(json.dumps(base)); c2=json.loads(json.dumps(base))
c1.update(id="c1", dependencies=["c2"]); c2.update(id="c2", dependencies=["c1"], write_set=["src/c2.py"])
state("cyclic", [c1,c2])
PY

for name in stale review-capacity merge-capacity; do decide "$TMP/$name.json" "$TMP/$name-out.json"; done
python3 - "$TMP/stale-out.json" "$TMP/review-capacity-out.json" "$TMP/merge-capacity-out.json" <<'PY'
import json, sys
from pathlib import Path
stale, review, merge=(json.loads(Path(p).read_text()) for p in sys.argv[1:])
assert "t1" in stale["blocked"] and "stale contract" in " ".join(stale["reasons"]["tasks"]["t1"])
assert review["reviews"] == ["t1"] and "t2" in review["blocked"]
assert "review capacity" in " ".join(review["reasons"]["tasks"]["t2"])
assert merge["merges"] == ["t1"] and "t2" in merge["blocked"]
assert "merge capacity" in " ".join(merge["reasons"]["tasks"]["t2"])
PY

for state in complete in-progress human-gated blocked cyclic; do
  decide "$TMP/completion-$state.json" "$TMP/completion-$state-out.json"
  python3 - "$TMP/completion-$state-out.json" "$state" <<'PY'
import json, sys
from pathlib import Path
d=json.loads(Path(sys.argv[1]).read_text())
assert d["reasons"]["completion"] == sys.argv[2], d
PY
done

decide "$TMP/completion-review-failed.json" "$TMP/completion-review-failed-out.json"
python3 - "$TMP/completion-review-failed-out.json" <<'PY'
import json, sys
from pathlib import Path
d=json.loads(Path(sys.argv[1]).read_text())
assert d["blocked"] == ["t1"]
assert d["reasons"]["completion"] == "blocked"
assert "review result fail" in " ".join(d["reasons"]["tasks"]["t1"])
PY
if decide "$TMP/completion-closed-unmerged.json" "$TMP/completion-closed-unmerged-out.json" 2>"$TMP/closed-unmerged.err"; then
  echo "FAIL: closed task without a passing merged commit was accepted" >&2; exit 1
fi
grep -Fq "closed task must have a passing merged commit" "$TMP/closed-unmerged.err"

python3 - "$SCHEDULER" <<'PY'
import importlib.util, sys
from copy import deepcopy
from pathlib import Path
spec=importlib.util.spec_from_file_location("scheduler", Path(sys.argv[1]))
m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
deps={
 "t1":[], "t2":["t1"], "t2p":["t2"], "t3":["t2p"], "t4":["t2p"],
 "t5":["t4"], "t6":["t5"], "t7":["t5"], "t8":["t3","t4","t6","t7"],
 "t8b":["t8"], "t9":["t8b"], "t10":["t9"],
}
template={"status":"open","dependency_commits":{},"contract_hash":"b"*64,"current_contract_hash":"b"*64,"write_set":[],"exclusive_resources":[],"capacity_resources":{},"phase":"pending","review_result":None,"speculation":None,"commit":None}
tasks=[]
for i,(task_id, dependencies) in enumerate(deps.items(), 1):
    task=deepcopy(template); task.update(id=task_id, dependencies=dependencies, write_set=[f"slice/{task_id}.md"]); tasks.append(task)
state={"graph_revision":"a"*64,"capability_tier":"isolated","capacity":{"workers":12,"reviews":12,"merges":12,"resources":{}},"acceptance_gates":"pending","speculation_limits":{"max_discard_files":3,"max_rebase_commits":2},"tasks":tasks}
expected=[{"t1"},{"t2"},{"t2p"},{"t3","t4"},{"t5"},{"t6","t7"},{"t8"},{"t8b"},{"t9"},{"t10"}]
observed=[]
for wave in expected:
    result=m.decide(state)
    actual=set(result["dispatch"]); assert actual == wave, (actual,wave,result)
    observed.append(actual)
    for task in state["tasks"]:
        if task["id"] in wave:
            task["phase"]="merged"; task["status"]="closed"; task["review_result"]="pass"; task["commit"]=(f"{len(observed):x}"*40)[:40]
    by_id={task["id"]:task for task in state["tasks"]}
    for task in state["tasks"]:
        task["dependency_commits"]={dep:by_id[dep]["commit"] for dep in task["dependencies"] if by_id[dep]["phase"]=="merged"}
assert observed == expected
PY

for text in "immediate merge" "recompute" "safe speculation" "review capacity" "host-limited" "sdd-scheduler.py"; do
  grep -Fqi "$text" "$REFERENCE" || { echo "FAIL: scheduling reference missing $text" >&2; exit 1; }
done
for file in "$EXECUTING" "$PARALLEL"; do
  grep -Fq "sdd-scheduler.py" "$file" || { echo "FAIL: ${file#$ROOT/} does not route to scheduler" >&2; exit 1; }
done
if (( $(grep -Fc 'bd create --graph' "$EXECUTING") != 1 )); then
  echo "FAIL: executing-plans still recreates an accepted graph" >&2; exit 1
fi
if grep -Eq 'bd ready --parent|bd worktree create' "$PARALLEL"; then
  echo "FAIL: generic parallel dispatch duplicates graph scheduling tutorial" >&2; exit 1
fi
if grep -Fq 'independent plan tasks' "$PARALLEL"; then
  echo "FAIL: generic parallel dispatch still claims graph-plan task ownership" >&2; exit 1
fi

echo "PASS: rolling resource-aware SDD scheduler"
