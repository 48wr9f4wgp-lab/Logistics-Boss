#!/usr/bin/env python3
"""Generate an ephemeral iOS export preset for CI/native bootstrap.

The committed project intentionally keeps only the Web engineering-preview preset.
This tool appends an iOS preset at build time using real account-owned identifiers
(or synthetic values in CI smoke tests), so production identifiers do not need to
be committed to source control.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
import tempfile
from pathlib import Path

from native_release_inputs import IOS_BUNDLE_ID, IOS_TEAM_ID, _validate_ios

_PRESET_RE = re.compile(r"^\[preset\.(\d+)\]$", re.MULTILINE)


def _escape_cfg(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')


def _next_preset_index(base_text: str) -> int:
    indices = [int(match.group(1)) for match in _PRESET_RE.finditer(base_text)]
    return max(indices, default=-1) + 1


def _render_ios_preset(index: int, team_id: str, bundle_id: str, preset_name: str) -> str:
    name = _escape_cfg(preset_name)
    team = _escape_cfg(team_id)
    bundle = _escape_cfg(bundle_id)
    return f'''\n[preset.{index}]\n\nname="{name}"\nplatform="iOS"\nrunnable=false\nadvanced_options=true\ndedicated_server=false\ncustom_features=""\nexport_filter="all_resources"\ninclude_filter=""\nexclude_filter=""\nexport_path="../ios-build/LogisticsBoss"\npatches=PackedStringArray()\nencryption_include_filters=""\nencryption_exclude_filters=""\nseed=0\nencrypt_pck=false\nencrypt_directory=false\nscript_export_mode=2\n\n[preset.{index}.options]\n\ncustom_template/debug=""\ncustom_template/release=""\narchitectures/arm64=true\napplication/app_store_team_id="{team}"\napplication/export_method_debug=1\napplication/code_sign_identity_debug=""\napplication/code_sign_identity_release=""\napplication/provisioning_profile_specifier_debug=""\napplication/provisioning_profile_specifier_release=""\napplication/export_method_release=0\napplication/bundle_identifier="{bundle}"\napplication/signature=""\napplication/short_version="0.1.0"\napplication/version="1"\napplication/additional_plist_content=""\napplication/icon_interpolation=4\napplication/export_project_only=true\napplication/delete_old_export_files_unconditionally=true\n'''


def generate(base_path: Path, output_path: Path, team_id: str, bundle_id: str, preset_name: str) -> int:
    values = {IOS_TEAM_ID: team_id, IOS_BUNDLE_ID: bundle_id}
    missing, invalid = _validate_ios(values)
    if missing or invalid:
        for key in missing:
            print(f"missing: {key}", file=sys.stderr)
        for message in invalid:
            print(f"invalid: {message}", file=sys.stderr)
        return 2

    if not base_path.is_file():
        print(f"base export preset file not found: {base_path}", file=sys.stderr)
        return 3

    base_text = base_path.read_text(encoding="utf-8")
    if 'platform="iOS"' in base_text:
        print("base export presets already contain an iOS target; refusing to append a duplicate", file=sys.stderr)
        return 3

    index = _next_preset_index(base_text)
    rendered = base_text.rstrip() + "\n" + _render_ios_preset(index, team_id, bundle_id, preset_name)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(rendered, encoding="utf-8")
    print(f"prepared ephemeral iOS export preset '{preset_name}' at index {index}")
    return 0


def _self_test() -> int:
    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        base = root / "export_presets.cfg"
        output = root / "generated.cfg"
        base.write_text(
            '[preset.0]\n\nname="Web"\nplatform="Web"\nrunnable=true\n\n[preset.0.options]\nprogressive_web_app/enabled=false\n',
            encoding="utf-8",
        )
        code = generate(base, output, "ABCDE12XYZ", "com.example.logistics-boss-ci", "iOS CI Project")
        assert code == 0
        text = output.read_text(encoding="utf-8")
        assert '[preset.1]' in text
        assert 'platform="iOS"' in text
        assert 'application/app_store_team_id="ABCDE12XYZ"' in text
        assert 'application/bundle_identifier="com.example.logistics-boss-ci"' in text
        assert 'application/export_project_only=true' in text
        assert 'export_path="../ios-build/LogisticsBoss"' in text
        assert 'progressive_web_app/enabled=false' in text

        duplicate = generate(output, root / "duplicate.cfg", "ABCDE12XYZ", "com.example.test", "iOS Duplicate")
        assert duplicate == 3

        invalid = generate(base, root / "invalid.cfg", "bad-team", "not_bundle", "iOS Invalid")
        assert invalid == 2

    print("iOS export preset generator self-test passed")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default="export_presets.cfg")
    parser.add_argument("--output", default="export_presets.cfg")
    parser.add_argument("--preset-name", default="iOS Native")
    parser.add_argument("--team-id", default=os.environ.get(IOS_TEAM_ID, ""))
    parser.add_argument("--bundle-id", default=os.environ.get(IOS_BUNDLE_ID, ""))
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        return _self_test()

    return generate(
        Path(args.base),
        Path(args.output),
        args.team_id.strip(),
        args.bundle_id.strip(),
        args.preset_name,
    )


if __name__ == "__main__":
    raise SystemExit(main())
