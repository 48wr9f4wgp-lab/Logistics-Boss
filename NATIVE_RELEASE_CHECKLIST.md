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

## 2. External identifiers required before native export presets can be finalized

These values must not be guessed or committed as fake production identifiers.

### iOS
- Apple Developer Team ID
- final Bundle Identifier (reverse-DNS, unique)
- signing/provisioning managed in Xcode / Apple Developer account

### Android
- final application package / unique name
- release keystore
- release key alias
- release credentials kept outside repository

Secrets/passwords belong in local export credentials / CI secret storage, never in `export_presets.cfg` or source control.

Until these values exist, the repository intentionally keeps only the **Web engineering-preview** export preset.

## 3. Native verification gate

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

## 4. Store / external-service actions requiring explicit approval

Do not perform without user approval:
- Apple App Store submission
- Google Play submission
- paid developer-account purchase or renewal
- analytics/crash provider contract or data upload
- IAP / ads / monetization activation
- production signing-key generation/rotation on behalf of the user

## 5. Current RC blocker definition

The repository may be called **Code RC Candidate** once the RC audit CI is green.

Do **not** call it **Native RC** until all of the following are complete:
1. final iOS/Android identifiers are supplied
2. native export presets are finalized with real identifiers
3. signed iOS and Android builds are produced
4. physical iPhone and Android verification passes
5. native performance / safe-area / audio / haptic behavior is confirmed

Store submission is a later external action and is not part of the Native RC definition.
