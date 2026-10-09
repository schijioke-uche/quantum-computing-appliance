#!/usr/bin/env python3
"""BQCA v38 deterministic Qiskit account configuration manager."""
from __future__ import annotations

import argparse
import json
import os
import pathlib
import re
import shlex
import sys
import tempfile
from typing import Dict

PROFILE = "bqca"
CONFIG_RELATIVE = pathlib.Path(".qiskit") / "qiskit-ibm.json"
REQUIRED_VALUES = (
    "IQP_API_TOKEN",
    "OPEN_PLAN_CHANNEL",
    "PAID_PLAN_CHANNEL",
    "OPEN_PLAN_INSTANCE",
    "PAID_PLAN_INSTANCE",
)
PLAN_SWITCHES = (
    "OPEN_PLAN",
    "FLEX_PLAN",
    "PAYGO_PLAN",
    "PREMIUM_PLAN",
    "DEDICATED_PLAN",
)
PAID_SWITCHES = ("FLEX_PLAN", "PAYGO_PLAN", "PREMIUM_PLAN", "DEDICATED_PLAN")
KEY_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


class ConfigurationError(RuntimeError):
    """Raised for deterministic, user-actionable configuration failures."""


def project_root_from_script() -> pathlib.Path:
    # <root>/.bob/quantum-tools/qiskit-configuration.py
    return pathlib.Path(__file__).resolve().parents[2]


def parse_env(path: pathlib.Path) -> Dict[str, str]:
    if not path.is_file():
        raise ConfigurationError(f"BQCA project environment file not found: {path}")
    values: Dict[str, str] = {}
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except UnicodeDecodeError as exc:
        raise ConfigurationError(f"BQCA .env must be UTF-8: {exc}") from exc

    for number, raw in enumerate(lines, 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[7:].lstrip()
        if "=" not in line:
            continue
        key, raw_value = line.split("=", 1)
        key = key.strip()
        if not KEY_RE.fullmatch(key):
            continue
        try:
            parts = shlex.split(raw_value, comments=True, posix=True)
        except ValueError as exc:
            raise ConfigurationError(f"Invalid .env syntax for {key} on line {number}: {exc}") from exc
        if not parts:
            value = ""
        elif len(parts) == 1:
            value = parts[0]
        else:
            value = " ".join(parts)
        values[key] = value
    return values


def require_values(env: Dict[str, str]) -> None:
    missing = [key for key in REQUIRED_VALUES if not env.get(key, "").strip()]
    missing.extend(key for key in PLAN_SWITCHES if key not in env)
    if missing:
        raise ConfigurationError("Missing required BQCA .env object(s): " + ", ".join(sorted(set(missing))))


def is_on(value: str) -> bool:
    return value.strip().lower() == "on"


def select_plan(env: Dict[str, str]) -> tuple[str, str, str]:
    open_on = is_on(env["OPEN_PLAN"])
    paid_on = [key for key in PAID_SWITCHES if is_on(env[key])]
    if open_on and paid_on:
        raise ConfigurationError(
            "OPEN_PLAN=on cannot be combined with a paid plan switch: " + ", ".join(paid_on)
        )
    if open_on:
        return "open", env["OPEN_PLAN_CHANNEL"].strip(), env["OPEN_PLAN_INSTANCE"].strip()
    if paid_on:
        return "paid", env["PAID_PLAN_CHANNEL"].strip(), env["PAID_PLAN_INSTANCE"].strip()
    raise ConfigurationError(
        "No active quantum plan. Set OPEN_PLAN=on or enable at least one paid plan switch."
    )


def desired_document(env: Dict[str, str]) -> tuple[str, dict]:
    plan, channel, instance = select_plan(env)
    document = {
        PROFILE: {
            "channel": channel,
            "is_default_account": True,
            "private_endpoint": False,
            "instance": instance,
            "token": env["IQP_API_TOKEN"].strip(),
            "url": "https://cloud.ibm.com",
        }
    }
    return plan, document


def validate_document(data: object) -> None:
    if not isinstance(data, dict):
        raise ConfigurationError("Qiskit account configuration must be a JSON object")
    if list(data.keys()) != [PROFILE]:
        raise ConfigurationError('Qiskit account configuration must contain exactly one profile named "bqca"')
    profile = data.get(PROFILE)
    if not isinstance(profile, dict):
        raise ConfigurationError('The "bqca" profile must be a JSON object')
    required = {
        "channel",
        "is_default_account",
        "private_endpoint",
        "instance",
        "token",
        "url",
    }
    if set(profile) != required:
        missing = sorted(required.difference(profile))
        extra = sorted(set(profile).difference(required))
        raise ConfigurationError(f"Invalid bqca profile fields; missing={missing}, extra={extra}")
    if profile["is_default_account"] is not True:
        raise ConfigurationError('The "bqca" profile must be the default account')
    if profile["private_endpoint"] is not False:
        raise ConfigurationError('The "bqca" profile private_endpoint must be false')
    if profile["url"] != "https://cloud.ibm.com":
        raise ConfigurationError('The "bqca" profile URL must be https://cloud.ibm.com')
    for key in ("channel", "instance", "token"):
        if not isinstance(profile[key], str) or not profile[key].strip():
            raise ConfigurationError(f'The "bqca" profile field {key} must be non-empty')


def config_path() -> pathlib.Path:
    return pathlib.Path.home() / CONFIG_RELATIVE


def atomic_write(path: pathlib.Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    os.chmod(path.parent, 0o700)
    payload = json.dumps(data, indent=4, ensure_ascii=False) + "\n"
    fd, temp_name = tempfile.mkstemp(prefix=path.name + ".", suffix=".tmp", dir=str(path.parent))
    temp = pathlib.Path(temp_name)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            stream.write(payload)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temp, path)
        os.chmod(path, 0o600)
    finally:
        if temp.exists():
            temp.unlink()


def configure(project_root: pathlib.Path, quiet: bool) -> int:
    env_path = project_root / ".env"
    env = parse_env(env_path)
    require_values(env)
    plan, document = desired_document(env)
    validate_document(document)
    destination = config_path()
    atomic_write(destination, document)
    loaded = json.loads(destination.read_text(encoding="utf-8"))
    validate_document(loaded)
    if loaded != document:
        raise ConfigurationError("Post-write verification failed")
    if not quiet:
        print("BQCA_QISKIT_CONFIGURATION=PASS")
        print(f"PROFILE={PROFILE}")
        print(f"PLAN={plan}")
        print(f"CONFIG={destination}")
    return 0


def validate_existing(quiet: bool) -> int:
    destination = config_path()
    if not destination.is_file():
        raise ConfigurationError(f"Qiskit account configuration not found: {destination}")
    try:
        data = json.loads(destination.read_text(encoding="utf-8"))
    except Exception as exc:
        raise ConfigurationError(f"Invalid Qiskit account JSON: {exc}") from exc
    validate_document(data)
    mode = destination.stat().st_mode & 0o777
    if mode & 0o077:
        raise ConfigurationError(f"Qiskit account configuration permissions are too broad: {oct(mode)}")
    if not quiet:
        print("BQCA_QISKIT_CONFIGURATION=VALID")
        print(f"PROFILE={PROFILE}")
        print(f"CONFIG={destination}")
    return 0


def show_redacted() -> int:
    destination = config_path()
    if not destination.is_file():
        raise ConfigurationError(f"Qiskit account configuration not found: {destination}")
    data = json.loads(destination.read_text(encoding="utf-8"))
    validate_document(data)
    redacted = json.loads(json.dumps(data))
    redacted[PROFILE]["token"] = "***REDACTED***"
    print(json.dumps(redacted, indent=4))
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="BQCA v38 Qiskit account configuration manager")
    parser.add_argument("command", choices=("configure", "validate", "show-redacted"))
    parser.add_argument("--project-root", type=pathlib.Path, default=project_root_from_script())
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()
    try:
        if args.command == "configure":
            return configure(args.project_root.resolve(), args.quiet)
        if args.command == "validate":
            return validate_existing(args.quiet)
        return show_redacted()
    except ConfigurationError as exc:
        print(f"BQCA_QISKIT_CONFIGURATION=FAIL: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())

# BQCA-ACTIVE-CENTRAL-POLICY:BEGIN
# Resolve the active authority through bqca-active-policy-listener.sh before
# every quantum DESIGN or CODE decision. Never hardcode a policy version or
# duplicate the full policy here. qiskit-design-policy-check.py and
# qiskit-code-policy-check.py reload the active registry/policy/contract on
# every invocation and create same-directory policy-compliance reports.
# Do not report completion until the active-policy report exists.
# BQCA-ACTIVE-CENTRAL-POLICY:END
