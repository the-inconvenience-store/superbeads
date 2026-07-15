#!/usr/bin/env python3
"""Run isolated, cost-capped behavioral skill microtests."""

from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import json
import math
import os
import re
import shutil
import statistics
import subprocess
import sys
import tempfile
import threading
import uuid
from pathlib import Path
from typing import Any


RUNNER_VERSION = "3"
ROOT = Path(__file__).resolve().parent.parent
FIXTURE_ROOT = ROOT / "tests/fixtures/skill-microtests/allowed"
SCHEMA_ROOT = ROOT / "tests/skill-microtests/schemas"
IDENTITY_FIELDS = (
    "scenario",
    "skill_hash",
    "provider",
    "model",
    "fixture_hash",
    "rubric_version",
    "runner_version",
    "runs",
)
LIVE_PROVIDERS = {"codex", "claude"}
LIVE_CALL_RESERVATION_USD = 1.0
PROVIDER_STATUS = {
    "fake": "test_only",
    "replay": "deterministic_replay",
    "codex": "live",
    "claude": "not_live_tested",
}
SECRET_KEY = re.compile(r"(?i)(api[_-]?key|token|secret|password|credential)")
SECRET_VALUE = re.compile(
    r"(?i)\b([a-z0-9_]*(?:api[_-]?key|token|secret|password|credential)[a-z0-9_]*)=\S+"
)
TEMP_PATH = re.compile(r"(?:/private)?/(?:tmp|var/folders)/[^\s\"']+")


class MicrotestError(ValueError):
    """A preflight or provider failure safe to show to the maintainer."""


def read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise MicrotestError(f"invalid JSON input: {error}") from error
    if not isinstance(value, dict):
        raise MicrotestError("JSON input must be an object")
    return value


def validate_fixture_paths(raw_paths: list[str], allowed_root: Path) -> list[Path]:
    root = allowed_root.resolve()
    paths: list[Path] = []
    for raw_path in raw_paths:
        if not isinstance(raw_path, str) or not raw_path:
            raise MicrotestError("fixture path must be a non-empty string")
        candidate = (root / raw_path).resolve()
        try:
            candidate.relative_to(root)
        except ValueError as error:
            raise MicrotestError(
                f"fixture path escapes allowed fixture root: {raw_path}"
            ) from error
        if not candidate.is_file():
            raise MicrotestError(f"fixture does not exist: {raw_path}")
        paths.append(candidate)
    return paths


def validate_candidate_skill_paths(raw_paths: list[str], repo_root: Path) -> list[Path]:
    if not isinstance(raw_paths, list) or not raw_paths:
        raise MicrotestError("candidate_skill_paths must be a non-empty array")
    root = repo_root.resolve()
    lexical_skills_root = root / "skills"
    if lexical_skills_root.is_symlink() or not lexical_skills_root.is_dir():
        raise MicrotestError("trusted skills root must be a real directory")
    skills_root = lexical_skills_root.resolve()
    paths: list[Path] = []
    seen: set[Path] = set()
    for raw_path in raw_paths:
        if not isinstance(raw_path, str) or not raw_path:
            raise MicrotestError("candidate skill path must be a non-empty string")
        relative = Path(raw_path)
        parts = relative.parts
        if (
            relative.is_absolute()
            or not parts
            or parts[0] != "skills"
            or ".." in parts
            or any(part.startswith(".") for part in parts)
            or relative.suffix != ".md"
        ):
            raise MicrotestError(f"candidate skill path must be non-hidden Markdown beneath skills/: {raw_path}")
        for index in range(1, len(parts) + 1):
            component = root.joinpath(*parts[:index])
            if component.is_symlink():
                raise MicrotestError(
                    f"candidate skill path traverses a symlink: {raw_path}"
                )
        candidate = (root / relative).resolve()
        try:
            candidate.relative_to(skills_root)
        except ValueError as error:
            raise MicrotestError(
                f"candidate skill path escapes trusted skills root: {raw_path}"
            ) from error
        if not candidate.is_file():
            raise MicrotestError(f"candidate skill path does not exist: {raw_path}")
        if candidate in seen:
            raise MicrotestError(f"duplicate candidate skill path: {raw_path}")
        seen.add(candidate)
        paths.append(candidate)
    return paths


def candidate_skill_hash(paths: list[Path], repo_root: Path) -> str:
    root = repo_root.resolve()
    digest = hashlib.sha256()
    for path in paths:
        relative = path.resolve().relative_to(root).as_posix()
        digest.update(relative.encode("utf-8") + b"\0")
        digest.update(path.read_bytes() + b"\0")
    return digest.hexdigest()


def reject_secret_environment(value: Any, under_environment: bool = False) -> None:
    if isinstance(value, dict):
        for key, nested in value.items():
            nested_environment = under_environment or str(key).lower() in {
                "env",
                "environment",
                "provider_env",
            }
            if nested_environment and SECRET_KEY.search(str(key)):
                raise MicrotestError("secret-like environment input is forbidden")
            reject_secret_environment(nested, nested_environment)
    elif under_environment and isinstance(value, str) and SECRET_VALUE.search(value):
        raise MicrotestError("secret-like environment input is forbidden")


def validate_scenario(document: dict[str, Any]) -> None:
    reject_secret_environment(document)
    required = {
        "id",
        "control_prompt",
        "candidate_prompt",
        "candidate_skill_paths",
        "rubric",
        "output_schema",
        "fixture_paths",
    }
    if set(document) != required:
        extras = sorted(set(document) - required)
        missing = sorted(required - set(document))
        raise MicrotestError(f"scenario fields differ: missing={missing}, extra={extras}")
    for field in ("id", "control_prompt", "candidate_prompt", "output_schema"):
        if not isinstance(document[field], str) or not document[field]:
            raise MicrotestError(f"scenario {field} must be a non-empty string")
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]*", document["id"]):
        raise MicrotestError("scenario id must contain lowercase letters, digits, or hyphens")
    if not isinstance(document["fixture_paths"], list):
        raise MicrotestError("scenario fixture_paths must be an array")
    if not isinstance(document["candidate_skill_paths"], list):
        raise MicrotestError("scenario candidate_skill_paths must be an array")
    rubric = document["rubric"]
    if not isinstance(rubric, dict):
        raise MicrotestError("scenario rubric must be an object")
    if set(rubric) != {"version", "pass_score", "criteria"}:
        raise MicrotestError("rubric requires version, pass_score, and criteria")
    if not isinstance(rubric["version"], str) or not rubric["version"]:
        raise MicrotestError("rubric version must be a non-empty string")
    pass_score = rubric["pass_score"]
    if isinstance(pass_score, bool) or not isinstance(pass_score, (int, float)):
        raise MicrotestError("rubric pass_score must be numeric")
    if not 0 <= pass_score <= 1:
        raise MicrotestError("rubric pass_score must be between zero and one")
    criteria = rubric["criteria"]
    if not isinstance(criteria, list) or not criteria:
        raise MicrotestError("rubric criteria must be a non-empty array")
    seen: set[str] = set()
    for criterion in criteria:
        if not isinstance(criterion, dict) or set(criterion) != {"id", "weight"}:
            raise MicrotestError("each rubric criterion requires id and weight")
        criterion_id = criterion["id"]
        weight = criterion["weight"]
        if not isinstance(criterion_id, str) or not criterion_id or criterion_id in seen:
            raise MicrotestError("rubric criterion ids must be unique non-empty strings")
        if isinstance(weight, bool) or not isinstance(weight, (int, float)) or weight <= 0:
            raise MicrotestError("rubric criterion weight must be positive")
        seen.add(criterion_id)


def fixture_hash(paths: list[Path], allowed_root: Path) -> str:
    digest = hashlib.sha256()
    root = allowed_root.resolve()
    for path in sorted(paths):
        relative = path.resolve().relative_to(root).as_posix()
        digest.update(relative.encode("utf-8") + b"\0")
        digest.update(path.read_bytes() + b"\0")
    return digest.hexdigest()


def evidence_identity(
    scenario: dict[str, Any],
    provider: str,
    model: str,
    fixtures: list[Path],
    candidate_skills: list[Path],
    runs: int,
    runner_version: str = RUNNER_VERSION,
) -> dict[str, Any]:
    scenario_bytes = json.dumps(
        scenario, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")
    return {
        "scenario": hashlib.sha256(scenario_bytes).hexdigest(),
        "skill_hash": candidate_skill_hash(candidate_skills, ROOT),
        "provider": provider,
        "model": model,
        "fixture_hash": fixture_hash(fixtures, FIXTURE_ROOT),
        "rubric_version": scenario["rubric"]["version"],
        "runner_version": runner_version,
        "runs": runs,
    }


def invalidation_reasons(
    previous: dict[str, Any], current: dict[str, Any]
) -> list[str]:
    return [
        f"{field}_changed"
        for field in IDENTITY_FIELDS
        if previous.get(field) != current.get(field)
    ]


def build_codex_launch(
    temp_root: Path, schema: Path, output: Path, model: str
) -> dict[str, Any]:
    return {
        "argv": [
            "codex", "exec", "--ephemeral", "--ignore-user-config", "--ignore-rules",
            "-c", 'shell_environment_policy.inherit="none"',
            "--sandbox", "read-only", "--ask-for-approval", "never",
            "--model", model, "-C", str(temp_root), "--output-schema", str(schema),
            "--output-last-message", str(output), "-",
        ],
        "cwd": str(temp_root),
    }


def resolve_codex_home(environment: dict[str, str]) -> Path:
    raw_path = environment.get("CODEX_HOME")
    if raw_path is None:
        parent_home = environment.get("HOME")
        if not parent_home:
            raise MicrotestError("Codex live provider requires CODEX_HOME or HOME")
        raw_path = str(Path(parent_home) / ".codex")
    path = Path(raw_path).expanduser()
    if not path.is_absolute():
        raise MicrotestError("CODEX_HOME must be an absolute directory")
    resolved = path.resolve()
    if not resolved.is_dir():
        raise MicrotestError("CODEX_HOME must resolve to an existing directory")
    return resolved


def build_provider_environment(temp_root: Path, codex_home: Path | None) -> dict[str, str]:
    environment = {
        "HOME": str(temp_root),
        "LANG": "C.UTF-8",
        "LC_ALL": "C.UTF-8",
        "PATH": "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin",
        "TMPDIR": str(temp_root),
    }
    if codex_home is not None:
        environment["CODEX_HOME"] = str(codex_home)
    return environment


def build_claude_launch(
    temp_root: Path, schema: Path, output: Path, model: str
) -> dict[str, Any]:
    del output
    return {
        "argv": [
            "claude", "--print", "--bare", "--tools", "", "--no-session-persistence",
            "--permission-mode", "dontAsk", "--model", model,
            "--output-format", "json", "--json-schema", str(schema),
        ],
        "cwd": str(temp_root),
    }


def provider_status(provider: str) -> str:
    return PROVIDER_STATUS[provider]


def build_provider_prompt(
    scenario: dict[str, Any],
    variant: str,
    sample_index: int,
    candidate_skills: list[Path],
    repo_root: Path,
) -> str:
    prompt = (
        f"variant: {variant}\nsample_index: {sample_index}\n\n"
        f"{scenario[f'{variant}_prompt']}\n"
    )
    if variant == "candidate":
        root = repo_root.resolve()
        for path in candidate_skills:
            relative = path.resolve().relative_to(root).as_posix()
            prompt += f"\n--- candidate skill: {relative}\n{path.read_text(encoding='utf-8')}"
    return prompt


def validate_provider_result(
    value: dict[str, Any], rubric: dict[str, Any]
) -> tuple[float, bool]:
    scores = value.get("rubric_scores")
    if not isinstance(scores, dict) or not isinstance(value.get("summary"), str):
        raise MicrotestError("provider result requires rubric_scores and summary")
    weighted = 0.0
    total_weight = 0.0
    for criterion in rubric["criteria"]:
        criterion_id = criterion["id"]
        score = scores.get(criterion_id)
        if isinstance(score, bool) or not isinstance(score, (int, float)):
            raise MicrotestError(f"provider score missing or non-numeric: {criterion_id}")
        if not 0 <= score <= 1:
            raise MicrotestError(f"provider score outside zero to one: {criterion_id}")
        weighted += float(score) * float(criterion["weight"])
        total_weight += float(criterion["weight"])
    score = weighted / total_weight
    return score, score >= float(rubric["pass_score"])


def redact_text(value: str, paths: list[Path]) -> str:
    redacted = value
    for path in sorted({str(path) for path in paths}, key=len, reverse=True):
        redacted = redacted.replace(path, "[REDACTED_PATH]")
        redacted = redacted.replace(
            str(Path(path).resolve()), "[REDACTED_PATH]"
        )
    redacted = SECRET_VALUE.sub(
        lambda match: f"{match.group(1)}=[REDACTED_SECRET]", redacted
    )
    return TEMP_PATH.sub("[REDACTED_PATH]", redacted)


def redact_value(value: Any, paths: list[Path]) -> Any:
    if isinstance(value, str):
        return redact_text(value, paths)
    if isinstance(value, list):
        return [redact_value(item, paths) for item in value]
    if isinstance(value, dict):
        return {key: redact_value(nested, paths) for key, nested in value.items()}
    return value


def execute_provider(
    provider: str,
    model: str,
    scenario: dict[str, Any],
    schema: Path,
    fixtures: list[Path],
    candidate_skills: list[Path],
    evidence_dir: Path,
    raw_root: Path,
    variant: str,
    sample_index: int,
    active: dict[str, int],
    active_lock: threading.Lock,
    codex_home: Path | None,
) -> dict[str, Any]:
    sandbox_id = uuid.uuid4().hex
    with active_lock:
        active["current"] += 1
        active["maximum"] = max(active["maximum"], active["current"])
    try:
        with tempfile.TemporaryDirectory(
            prefix=f"skill-microtest-provider-{sandbox_id}-"
        ) as raw_temp_root:
            temp_root = Path(raw_temp_root)
            if temp_root.resolve() == ROOT.resolve() or ROOT.resolve() in temp_root.resolve().parents:
                raise MicrotestError("OS temporary provider root is inside repository")
            for source in fixtures:
                relative = source.resolve().relative_to(FIXTURE_ROOT.resolve())
                destination = temp_root / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, destination)
            output = temp_root / "provider-result.json"
            if provider == "codex":
                launch = build_codex_launch(temp_root, schema, output, model)
            else:
                launch = {
                    "argv": [
                        sys.executable,
                        str(ROOT / f"tests/skill-microtests/{provider}-provider.py"),
                        "--output", str(output), "--variant", variant,
                        "--sample-index", str(sample_index),
                    ],
                    "cwd": str(temp_root),
                }
            prompt = build_provider_prompt(
                scenario, variant, sample_index, candidate_skills, ROOT
            )
            environment = build_provider_environment(temp_root, codex_home)
            try:
                result = subprocess.run(
                    launch["argv"],
                    cwd=launch["cwd"],
                    input=prompt,
                    env=environment,
                    text=True,
                    capture_output=True,
                    check=False,
                    timeout=120,
                )
            except (OSError, subprocess.TimeoutExpired) as error:
                raise MicrotestError(f"provider execution failed: {error}") from error
            raw_text = result.stdout + result.stderr
            raw_name = f"run-{sample_index:02d}-{variant}.txt"
            raw_path = raw_root / raw_name
            descriptor = os.open(
                raw_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600
            )
            with os.fdopen(descriptor, "w", encoding="utf-8") as raw_file:
                raw_file.write(raw_text)
            raw_path.chmod(0o600)
            if result.returncode != 0:
                raise MicrotestError(
                    f"provider failed for run {sample_index} {variant}: exit {result.returncode}"
                )
            provider_result = read_json(output)
            score, passed = validate_provider_result(
                provider_result, scenario["rubric"]
            )
            redaction_paths = [temp_root, raw_root, evidence_dir, ROOT]
            if codex_home is not None:
                redaction_paths.append(codex_home)
            return {
                "score": round(score, 6),
                "passed": passed,
                "sandbox_id": sandbox_id,
                "raw_transcript": f"[REDACTED_RAW_ROOT]/{raw_name}",
                "transcript": redact_text(raw_text, redaction_paths),
                "result": redact_value(provider_result, redaction_paths),
            }
    finally:
        with active_lock:
            active["current"] -= 1


def aggregate(samples: list[dict[str, Any]]) -> dict[str, float]:
    controls = [float(sample["control"]["score"]) for sample in samples]
    candidates = [float(sample["candidate"]["score"]) for sample in samples]
    deltas = [candidate - control for control, candidate in zip(controls, candidates)]
    return {
        "candidate_mean": round(statistics.fmean(candidates), 6),
        "candidate_variance": round(statistics.pvariance(candidates), 6),
        "control_mean": round(statistics.fmean(controls), 6),
        "control_variance": round(statistics.pvariance(controls), 6),
        "delta_mean": round(statistics.fmean(deltas), 6),
        "delta_variance": round(statistics.pvariance(deltas), 6),
    }


def cache_state(cache_path: Path, identity: dict[str, Any]) -> tuple[dict[str, Any] | None, list[str]]:
    if not cache_path.exists():
        return None, ["no_passing_evidence"]
    try:
        previous = read_json(cache_path)
    except MicrotestError:
        return None, ["invalid_evidence"]
    previous_identity = previous.get("identity")
    if not isinstance(previous_identity, dict):
        return None, ["invalid_evidence"]
    reasons = invalidation_reasons(previous_identity, identity)
    if reasons:
        return None, reasons
    if not previous.get("passed"):
        return None, ["previous_evidence_not_passing"]
    return previous, []


def base_report(
    scenario: dict[str, Any],
    provider: str,
    model: str,
    identity: dict[str, Any],
    max_cost_usd: float | None,
    runs: int,
) -> dict[str, Any]:
    reserved = 2 * runs * LIVE_CALL_RESERVATION_USD if provider in LIVE_PROVIDERS else None
    return {
        "schema_version": 1,
        "runner_version": RUNNER_VERSION,
        "scenario": {"id": scenario["id"], "hash": identity["scenario"]},
        "identity": identity,
        "provider": {
            "name": provider,
            "model": model,
            "status": provider_status(provider),
            "requested_max_cost_usd": max_cost_usd if provider in LIVE_PROVIDERS else None,
            "reserved_cost_usd": reserved,
            "cost_control": (
                "conservative_preflight_reservation"
                if provider in LIVE_PROVIDERS
                else None
            ),
        },
    }


def run_campaign(
    scenario: dict[str, Any],
    provider: str,
    model: str,
    fixtures: list[Path],
    candidate_skills: list[Path],
    schema: Path,
    runs: int,
    concurrency: int,
    evidence_dir: Path,
    max_cost_usd: float | None,
    codex_home: Path | None,
) -> tuple[dict[str, Any], Path | None]:
    identity = evidence_identity(
        scenario, provider, model, fixtures, candidate_skills, runs
    )
    evidence_dir.mkdir(parents=True, exist_ok=True)
    cache_path = evidence_dir / f"{scenario['id']}.json"
    report = base_report(scenario, provider, model, identity, max_cost_usd, runs)
    previous, reasons = cache_state(cache_path, identity)
    if previous is not None:
        reused = dict(previous)
        reused["cache"] = {"reused": True, "invalidation_reasons": []}
        reused["execution"] = dict(reused["execution"], provider_calls=0)
        return reused, None

    raw_root = Path(tempfile.mkdtemp(prefix="skill-microtest-raw-")).resolve()
    if raw_root == ROOT.resolve() or ROOT.resolve() in raw_root.parents:
        shutil.rmtree(raw_root)
        raise MicrotestError("OS temporary raw root is inside repository")
    raw_root.chmod(0o700)
    try:
        active = {"current": 0, "maximum": 0}
        active_lock = threading.Lock()
        samples = [{"run": index} for index in range(1, runs + 1)]
        work = [
            (index, variant)
            for index in range(1, runs + 1)
            for variant in ("control", "candidate")
        ]
        with concurrent.futures.ThreadPoolExecutor(max_workers=concurrency) as executor:
            futures = {
                executor.submit(
                    execute_provider,
                    provider,
                    model,
                    scenario,
                    schema,
                    fixtures,
                    candidate_skills,
                    evidence_dir,
                    raw_root,
                    variant,
                    index,
                    active,
                    active_lock,
                    codex_home,
                ): (index, variant)
                for index, variant in work
            }
            for future in concurrent.futures.as_completed(futures):
                index, variant = futures[future]
                samples[index - 1][variant] = future.result()

        report.update(
            {
                "cache": {"reused": False, "invalidation_reasons": reasons},
                "execution": {
                    "provider_calls": len(work),
                    "max_observed_concurrency": active["maximum"],
                },
                "samples": samples,
                "aggregate": aggregate(samples),
                "passed": all(sample["candidate"]["passed"] for sample in samples),
            }
        )
        cache_path.write_text(
            json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
    except BaseException:
        shutil.rmtree(raw_root, ignore_errors=True)
        raise
    return report, raw_root


def claude_report(
    scenario: dict[str, Any],
    model: str,
    fixtures: list[Path],
    candidate_skills: list[Path],
    runs: int,
    max_cost_usd: float,
    evidence_dir: Path,
) -> dict[str, Any]:
    identity = evidence_identity(
        scenario, "claude", model, fixtures, candidate_skills, runs
    )
    report = base_report(
        scenario, "claude", model, identity, max_cost_usd, runs
    )
    report.update(
        {
            "cache": {"reused": False, "invalidation_reasons": ["not_live_tested"]},
            "execution": {"provider_calls": 0, "max_observed_concurrency": 0},
            "samples": [],
            "aggregate": None,
            "passed": False,
        }
    )
    evidence_dir.mkdir(parents=True, exist_ok=True)
    (evidence_dir / f"{scenario['id']}.json").write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    return report


def validate_limits(args: argparse.Namespace) -> None:
    if args.runs < 1 or args.max_runs < 1 or args.runs > args.max_runs:
        raise MicrotestError(
            f"requested runs exceed max-runs run cap: {args.runs} > {args.max_runs}"
        )
    if args.concurrency < 1 or args.concurrency > 2:
        raise MicrotestError("concurrency must be between one and maximum 2")
    if args.provider in LIVE_PROVIDERS:
        if not args.confirm_cost:
            raise MicrotestError("live providers require --confirm-cost")
        if (
            args.max_cost_usd is None
            or not math.isfinite(args.max_cost_usd)
            or args.max_cost_usd <= 0
        ):
            raise MicrotestError("live providers require finite positive --max-cost-usd")
        reserved = 2 * args.runs * LIVE_CALL_RESERVATION_USD
        if args.max_cost_usd < reserved:
            raise MicrotestError(
                f"max-cost-usd is below reserved live cost: {reserved:.2f}"
            )
    if args.provider == "codex" and not args.model:
        raise MicrotestError("Codex live provider requires explicit --model")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scenario", type=Path, required=True)
    parser.add_argument(
        "--provider", choices=("fake", "replay", "codex", "claude"), required=True
    )
    parser.add_argument("--model")
    parser.add_argument("--runs", type=int, default=5)
    parser.add_argument("--max-runs", type=int, default=5)
    parser.add_argument("--concurrency", type=int, default=2)
    parser.add_argument("--max-cost-usd", type=float)
    parser.add_argument("--confirm-cost", action="store_true")
    parser.add_argument(
        "--evidence-dir", type=Path, default=ROOT / ".internal/skill-microtests"
    )
    return parser


def main() -> int:
    args = build_parser().parse_args()
    try:
        validate_limits(args)
        scenario = read_json(args.scenario)
        validate_scenario(scenario)
        fixtures = validate_fixture_paths(scenario["fixture_paths"], FIXTURE_ROOT)
        candidate_skills = validate_candidate_skill_paths(
            scenario["candidate_skill_paths"], ROOT
        )
        schema_root = SCHEMA_ROOT.resolve()
        schema = (ROOT / scenario["output_schema"]).resolve()
        try:
            schema.relative_to(schema_root)
        except ValueError as error:
            raise MicrotestError("output_schema escapes its allowed root") from error
        if not schema.is_file():
            raise MicrotestError("output_schema does not exist")
        model = args.model or {
            "fake": "fake-v1",
            "replay": "replay-v1",
            "codex": "",
            "claude": "not-live-tested",
        }[args.provider]
        codex_home = resolve_codex_home(dict(os.environ)) if args.provider == "codex" else None
        if args.provider == "claude":
            report = claude_report(
                scenario,
                model,
                fixtures,
                candidate_skills,
                args.runs,
                args.max_cost_usd,
                args.evidence_dir.resolve(),
            )
        else:
            report, raw_root = run_campaign(
                scenario,
                args.provider,
                model,
                fixtures,
                candidate_skills,
                schema,
                args.runs,
                args.concurrency,
                args.evidence_dir.resolve(),
                args.max_cost_usd,
                codex_home,
            )
            if raw_root is not None:
                print(f"raw_transcript_root={raw_root}", file=sys.stderr)
    except MicrotestError as error:
        print(f"skill microtest error: {error}", file=sys.stderr)
        return 2
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
