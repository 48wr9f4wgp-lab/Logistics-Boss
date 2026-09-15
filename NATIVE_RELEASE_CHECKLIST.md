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

Copy the example locally to `godot/.native-release.env` and fill only on the trusted development machine. The real file is gitignored.

Validation command:

```bash
python3 godot/tools/native_release_inputs.py \
  --env-file godot/.native-release.env \
  --platform all \
  --require-signing
```

The validator checks identifier syntax and Android signing-file presence. It never prints the Android keystore password. CI runs the validator's synthetic self-test through the existing release-services smoke, so no production credentials are required in CI.

## 3. External identifiers required before native export presets can be finalized

These values must not be guessed or committed as fake production identifiers.

### iOS
- `LOGISTICS_BOSS_IOS_TEAM_ID`: Apple Developer Team ID, 10-character Apple team code
- `LOGISTICS_BOSS_IOS_BUNDLE_ID`: final unique reverse-DNS Bundle Identifier
- signing/provisioning managed in Xcode / Apple Developer account

Godot requires both the App Store Team ID and Bundle Identifier for iOS export. Final signing still happens with the real Apple account/certificates.

### Android
- `LOGISTICS_BOSS_ANDROID_PACKAGE`: final unique lowercase reverse-DNS application package
- `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`: release keystore path
- `GODOT_ANDROID_KEYSTORE_RELEASE_USER`: release key alias
- `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`: release signing password

Godot supports the three `GODOT_ANDROID_KEYSTORE_RELEASE_*` environment variables as export-time overrides, so release signing secrets do not need to be stored in `export_presets.cfg`.

Secrets/passwords belong in local export credentials / CI secret storage, never in source control.

Until the real identifiers exist, the repository intentionally keeps only the **Web engineering-preview** export preset.

## 4. Native export preset gate

After the validator reports READY:
1. add the iOS preset using the real Team ID and Bundle Identifier
2. add the Android preset using the real package name
3. keep Android keystore path/user/password outside source control and inject through the Godot-supported environment variables
4. export an unsigned/Xcode project or signed build only as appropriate to the platform setup
5. do not commit generated build products

Do not insert placeholder production identifiers merely to make export commands pass.

## 5. Native verification gate

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

## 6. Store / external-service actions requiring explicit approval

Do not perform without user approval:
- Apple App Store submission
- Google Play submission
- paid developer-account purchase or renewal
- analytics/crash provider contract or data upload
- IAP / ads / monetization activation
- production signing-key generation/rotation on behalf of the user

## 7. Current RC blocker definition

The repository is a **Code RC Candidate** once the RC audit CI is green.

Do **not** call it **Native RC** until all of the following are complete:
1. final iOS/Android identifiers are supplied
2. native export presets are finalized with real identifiers
3. signed iOS and Android builds are produced
4. physical iPhone and Android verification passes
5. native performance / safe-area / audio / haptic behavior is confirmed

Store submission is a later external action and is not part of the Native RC definition.
