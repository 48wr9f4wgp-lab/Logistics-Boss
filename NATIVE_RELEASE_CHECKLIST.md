# LOGISTICS BOSS — Native Release Checklist

Status: **code-level RC candidate / native preparation pending**
Engine: Godot 4.7.2 Standard / GDScript / GL Compatibility
Reference viewport: portrait 390×844

## 1. Code-level readiness already prepared

- authoritative Domain simulation separated from UI/View
- schema-v7 local save with primary + backup recovery
- startup / FTUE / Rank 1 / Rank 2 / Rank 3 regressions
- long-running Rank 1 / Rank 3 soak and save/resume coverage
- touch orbit + pinch zoom
- portrait overview framing regression coverage
- Rank 3 management touch-scroll regression coverage
- procedural gameplay feedback audio baseline
- native haptic hooks through `Input.vibrate_handheld`
- provider-neutral analytics event layer; no external data transmission
- runtime FPS health sampling
- real iPhone Safari engineering-preview verification after PR #57
- RC preflight checks for viewport, renderer, required release assets and export-preset policy

## 2. Native release input bootstrap

The repository provides:
- `godot/native_release_inputs.example.env`
- `godot/tools/native_release_inputs.py`

Copy the example locally to `godot/.native-release.env` and fill only on a trusted machine. The real file is gitignored.

Validation command:

```bash
python3 godot/tools/native_release_inputs.py \
  --env-file godot/.native-release.env \
  --platform all \
  --require-signing
```

The validator checks identifier syntax and Android signing-file presence. It never prints the Android keystore password.

## 3. Mac-less iOS export bootstrap

A local Mac is not required for the first native-export gate.

The repository provides:
- `godot/tools/prepare_ios_export.py`
- `.github/workflows/ios-export-smoke.yml`

The generator appends an **ephemeral iOS export preset** at build time. The committed `godot/export_presets.cfg` still contains only the Web engineering-preview preset.

The macOS GitHub Actions smoke does this automatically:
1. start a hosted macOS runner with Xcode
2. install Godot 4.7.2 + export templates
3. validate synthetic iOS identifiers
4. generate a temporary iOS preset with `application/export_project_only=true`
5. import the Godot project on macOS
6. export an unsigned Xcode-project ZIP
7. verify the ZIP contains an `.xcodeproj/project.pbxproj`
8. upload the unsigned Xcode-project artifact for inspection

Synthetic values are used only by the smoke workflow. They are not production identifiers and are never merged into `export_presets.cfg`.

Once real Apple identifiers exist, the same path can inject them from CI variables/secrets without requiring a local Mac. Final signed-device/TestFlight work still requires Apple account signing material and an active Apple Developer setup.

## 4. External identifiers required before signed native builds

These values must not be guessed or committed as fake production identifiers.

### iOS
- `LOGISTICS_BOSS_IOS_TEAM_ID`: Apple Developer Team ID, 10-character Apple team code
- `LOGISTICS_BOSS_IOS_BUNDLE_ID`: final unique reverse-DNS Bundle Identifier
- signing/provisioning material from the Apple Developer account

Godot requires both the App Store Team ID and Bundle Identifier for iOS export.

### Android
- `LOGISTICS_BOSS_ANDROID_PACKAGE`: final unique lowercase reverse-DNS application package
- `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`: release keystore path
- `GODOT_ANDROID_KEYSTORE_RELEASE_USER`: release key alias
- `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`: release signing password

Godot supports the three `GODOT_ANDROID_KEYSTORE_RELEASE_*` environment variables as export-time overrides, so release signing secrets do not need to be stored in `export_presets.cfg`.

Secrets/passwords belong in local export credentials / CI secret storage, never in source control.

## 5. Native build gate

After the validator reports READY:
1. feed the real iOS Team ID and Bundle ID into the CI/native preset generator
2. import Apple certificate/provisioning material into the temporary CI keychain only when signed iOS builds are authorized
3. produce the signed iOS build / TestFlight candidate
4. add the Android preset using the real package name
5. inject Android keystore credentials at build time, not in source control
6. produce the signed Android APK/AAB candidate
7. do not commit generated build products or credentials

Do not insert placeholder production identifiers merely to make export commands pass.

## 6. Native verification gate

Run on at least one physical iPhone and one physical Android device.

Required pass:
- cold launch
- fresh-save FTUE
- existing schema-v7 save load
- 10+ minute representative session
- pause/background/resume
- touch orbit and pinch at screen edges
- maximum zoom-out keeps the operation readable
- Safe Area / Dynamic Island / navigation-area clearance
- management sheet reaches all actions by touch scroll
- no horizontal management drift or clipping
- audio starts only after platform permits playback
- haptics fire for meaningful events and do not spam shipments
- Rank 1 → Rank 2 → Rank 3 controls remain reachable
- all three routing modes remain playable after save/reload
- no sustained <30 FPS on target device during representative Rank 3 scene
- save survives app kill/relaunch

## 7. Store / external-service actions requiring explicit approval

Do not perform without user approval:
- Apple App Store submission
- Google Play submission
- paid developer-account purchase or renewal
- analytics/crash provider contract or data upload
- IAP / ads / monetization activation
- production signing-key generation/rotation on behalf of the user

## 8. Current RC blocker definition

The repository is a **Code RC Candidate**.

Do **not** call it **Native RC** until all of the following are complete:
1. final iOS/Android identifiers are supplied
2. signed native builds are produced
3. physical iPhone and Android verification passes
4. native performance / safe-area / audio / haptic behavior is confirmed

Store submission is a later external action and is not part of the Native RC definition.
