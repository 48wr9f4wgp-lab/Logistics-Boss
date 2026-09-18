#!/usr/bin/env python3
"""Generate an ephemeral Android export preset for CI/native bootstrap.

The committed project intentionally keeps only the Web engineering-preview preset.
This tool appends an Android preset at build time using a real account-owned package
identifier (or a synthetic value in CI smoke tests), so production identity does not
need to be committed to source control.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
import tempfile
from pathlib import Path

from native_release_inputs import ANDROID_PACKAGE, _validate_android

_PRESET_RE = re.compile(r"^\[preset\.(\d+)\]$", re.MULTILINE)


def _escape_cfg(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')


def _next_preset_index(base_text: str) -> int:
    indices = [int(match.group(1)) for match in _PRESET_RE.finditer(base_text)]
    return max(indices, default=-1) + 1


def _render_android_preset(index: int, package_id: str, preset_name: str) -> str:
    name = _escape_cfg(preset_name)
    package = _escape_cfg(package_id)
    return f'''\n[preset.{index}]\n\nname="{name}"\nplatform="Android"\nrunnable=false\nadvanced_options=true\ndedicated_server=false\ncustom_features=""\nexport_filter="all_resources"\ninclude_filter=""\nexclude_filter=""\nexport_path="../android-build/LogisticsBoss.apk"\npatches=PackedStringArray()\nencryption_include_filters=""\nencryption_exclude_filters=""\nseed=0\nencrypt_pck=false\nencrypt_directory=false\nscript_export_mode=2\n\n[preset.{index}.options]\n\ncustom_template/debug=""\ncustom_template/release=""\ngradle_build/use_gradle_build=false\ngradle_build/export_format=0\ngradle_build/min_sdk=""\ngradle_build/target_sdk=""\narchitectures/armeabi-v7a=false\narchitectures/arm64-v8a=true\narchitectures/x86=false\narchitectures/x86_64=false\nversion/code=1\nversion/name="0.1.0"\npackage/unique_name="{package}"\npackage/name="FLOTRA"\npackage/signed=true\npackage/app_category=0\npackage/retain_data_on_uninstall=false\npackage/exclude_from_recents=false\npackage/show_in_android_tv=false\npackage/show_in_app_library=true\npackage/show_as_launcher_app=false\nlauncher_icons/main_192x192=""\nlauncher_icons/adaptive_foreground_432x432=""\nlauncher_icons/adaptive_background_432x432=""\nlauncher_icons/adaptive_monochrome_432x432=""\ngraphics/opengl_debug=false\nxr_features/xr_mode=0\nscreen/immersive_mode=true\nscreen/support_small=true\nscreen/support_normal=true\nscreen/support_large=true\nscreen/support_xlarge=true\nuser_data_backup/allow=false\ncommand_line/extra_args=""\napk_expansion/enable=false\napk_expansion/SALT=""\napk_expansion/public_key=""\npermissions/custom_permissions=PackedStringArray()\n'''


def generate(base_path: Path, output_path: Path, package_id: str, preset_name: str) -> int:
    values = {ANDROID_PACKAGE: package_id}
    missing, invalid = _validate_android(values, False)
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
    if 'platform="Android"' in base_text:
        print("base export presets already contain an Android target; refusing to append a duplicate", file=sys.stderr)
        return 3

    index = _next_preset_index(base_text)
    rendered = base_text.rstrip() + "\n" + _render_android_preset(index, package_id, preset_name)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(rendered, encoding="utf-8")
    print(f"prepared ephemeral Android export preset '{preset_name}' at index {index}")
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
        code = generate(base, output, "com.example.logisticsbossci", "Android CI APK")
        assert code == 0
        text = output.read_text(encoding="utf-8")
        assert '[preset.1]' in text
        assert 'platform="Android"' in text
        assert 'package/unique_name="com.example.logisticsbossci"' in text
        assert 'architectures/arm64-v8a=true' in text
        assert 'gradle_build/use_gradle_build=false' in text
        assert 'package/show_in_app_library=true' in text
        assert 'package/show_as_launcher_app=false' in text
        assert 'export_path="../android-build/LogisticsBoss.apk"' in text
        assert 'progressive_web_app/enabled=false' in text

        duplicate = generate(output, root / "duplicate.cfg", "com.example.duplicate", "Android Duplicate")
        assert duplicate == 3

        invalid = generate(base, root / "invalid.cfg", "Com.example.8game", "Android Invalid")
        assert invalid == 2

    print("Android export preset generator self-test passed")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default="export_presets.cfg")
    parser.add_argument("--output", default="export_presets.cfg")
    parser.add_argument("--preset-name", default="Android Native")
    parser.add_argument("--package-id", default=os.environ.get(ANDROID_PACKAGE, ""))
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        return _self_test()

    return generate(
        Path(args.base),
        Path(args.output),
        args.package_id.strip(),
        args.preset_name,
    )


if __name__ == "__main__":
    raise SystemExit(main())
