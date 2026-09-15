#!/usr/bin/env python3
"""Validate native release identifiers/signing inputs without exposing secrets.

This tool intentionally does not generate production export presets. It gates the
next native-release step until real identifiers are supplied by the account owner.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path
from typing import Dict, Iterable, Tuple

IOS_TEAM_ID = "LOGISTICS_BOSS_IOS_TEAM_ID"
IOS_BUNDLE_ID = "LOGISTICS_BOSS_IOS_BUNDLE_ID"
ANDROID_PACKAGE = "LOGISTICS_BOSS_ANDROID_PACKAGE"
ANDROID_KEYSTORE_PATH = "GODOT_ANDROID_KEYSTORE_RELEASE_PATH"
ANDROID_KEYSTORE_USER = "GODOT_ANDROID_KEYSTORE_RELEASE_USER"
ANDROID_KEYSTORE_PASSWORD = "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD"

_TEAM_RE = re.compile(r"^[A-Z0-9]{10}$")
_IOS_SEGMENT_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9-]*$")
_ANDROID_SEGMENT_RE = re.compile(r"^[a-z][a-z0-9_]*$")

SECRET_KEYS = {ANDROID_KEYSTORE_PASSWORD}


def _load_env_file(path: Path) -> Dict[str, str]:
    values: Dict[str, str] = {}
    if not path.exists():
        raise FileNotFoundError(str(path))
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[7:].strip()
        if "=" not in line:
            raise ValueError(f"invalid env line: {raw_line!r}")
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if not key:
            raise ValueError("empty env key")
        values[key] = value
    return values


def _inputs(env_file: str | None = None) -> Dict[str, str]:
    values = dict(os.environ)
    if env_file:
        values.update(_load_env_file(Path(env_file)))
    return values


def _validate_ios(values: Dict[str, str]) -> Tuple[list[str], list[str]]:
    missing: list[str] = []
    invalid: list[str] = []

    team = values.get(IOS_TEAM_ID, "").strip()
    bundle = values.get(IOS_BUNDLE_ID, "").strip()

    if not team:
        missing.append(IOS_TEAM_ID)
    elif not _TEAM_RE.fullmatch(team):
        invalid.append(f"{IOS_TEAM_ID} must be a 10-character uppercase alphanumeric Apple Team ID")

    if not bundle:
        missing.append(IOS_BUNDLE_ID)
    else:
        segments = bundle.split(".")
        if len(segments) < 2 or any(not _IOS_SEGMENT_RE.fullmatch(segment) for segment in segments):
            invalid.append(
                f"{IOS_BUNDLE_ID} must be a reverse-DNS identifier using letters, digits, hyphens and periods"
            )

    return missing, invalid


def _validate_android(values: Dict[str, str], require_signing: bool) -> Tuple[list[str], list[str]]:
    missing: list[str] = []
    invalid: list[str] = []

    package = values.get(ANDROID_PACKAGE, "").strip()
    if not package:
        missing.append(ANDROID_PACKAGE)
    else:
        segments = package.split(".")
        if len(segments) < 2 or any(not _ANDROID_SEGMENT_RE.fullmatch(segment) for segment in segments):
            invalid.append(
                f"{ANDROID_PACKAGE} must be lowercase reverse-DNS; every component must start with a letter"
            )

    if require_signing:
        keystore = values.get(ANDROID_KEYSTORE_PATH, "").strip()
        user = values.get(ANDROID_KEYSTORE_USER, "").strip()
        password = values.get(ANDROID_KEYSTORE_PASSWORD, "")

        if not keystore:
            missing.append(ANDROID_KEYSTORE_PATH)
        elif not Path(keystore).expanduser().is_file():
            invalid.append(f"{ANDROID_KEYSTORE_PATH} does not point to a file")
        if not user:
            missing.append(ANDROID_KEYSTORE_USER)
        if not password:
            missing.append(ANDROID_KEYSTORE_PASSWORD)

    return missing, invalid


def _selected(platform: str) -> Iterable[str]:
    if platform == "all":
        return ("ios", "android")
    return (platform,)


def _status(values: Dict[str, str], platform: str, require_signing: bool) -> Dict[str, dict]:
    result: Dict[str, dict] = {}
    for target in _selected(platform):
        if target == "ios":
            missing, invalid = _validate_ios(values)
        else:
            missing, invalid = _validate_android(values, require_signing)
        result[target] = {
            "ready": not missing and not invalid,
            "missing": missing,
            "invalid": invalid,
        }
    return result


def _print_human(result: Dict[str, dict], require_signing: bool) -> None:
    print("LOGISTICS BOSS native release input check")
    for target, state in result.items():
        label = "iOS" if target == "ios" else "Android"
        print(f"{label}: {'READY' if state['ready'] else 'BLOCKED'}")
        for key in state["missing"]:
            suffix = " (value intentionally not printed)" if key in SECRET_KEYS else ""
            print(f"  missing: {key}{suffix}")
        for message in state["invalid"]:
            print(f"  invalid: {message}")
    if require_signing and "android" in result:
        print("Android signing credentials were checked without printing credential values.")


def _self_test() -> int:
    good = {
        IOS_TEAM_ID: "ABCDE12XYZ",
        IOS_BUNDLE_ID: "com.example.logistics-boss",
        ANDROID_PACKAGE: "com.example.logistics_boss",
    }
    result = _status(good, "all", False)
    assert result["ios"]["ready"]
    assert result["android"]["ready"]

    bad_ios = dict(good)
    bad_ios[IOS_TEAM_ID] = "not-a-team"
    bad_ios[IOS_BUNDLE_ID] = "bad_bundle"
    result = _status(bad_ios, "ios", False)
    assert not result["ios"]["ready"] and len(result["ios"]["invalid"]) == 2

    bad_android = dict(good)
    bad_android[ANDROID_PACKAGE] = "Com.example.8game"
    result = _status(bad_android, "android", False)
    assert not result["android"]["ready"] and result["android"]["invalid"]

    missing = _status({}, "all", False)
    assert IOS_TEAM_ID in missing["ios"]["missing"]
    assert ANDROID_PACKAGE in missing["android"]["missing"]

    print("native release input validator self-test passed")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--platform", choices=("ios", "android", "all"), default="all")
    parser.add_argument("--env-file", default=None)
    parser.add_argument("--require-signing", action="store_true")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        return _self_test()

    try:
        values = _inputs(args.env_file)
    except (OSError, ValueError) as exc:
        print(f"input error: {exc}", file=sys.stderr)
        return 3

    result = _status(values, args.platform, args.require_signing)
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        _print_human(result, args.require_signing)

    if all(state["ready"] for state in result.values()):
        return 0
    if any(state["invalid"] for state in result.values()):
        return 3
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
