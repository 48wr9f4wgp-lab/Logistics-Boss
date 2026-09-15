# LOGISTICS BOSS — Native Release Checklist

Status: production-readiness sprint
Engine: Godot 4.7.2 Standard / GDScript / GL Compatibility
Reference viewport: portrait 390×844

## 1. Already prepared in repository

- authoritative Domain simulation separated from UI/View
- schema-versioned local save with primary + backup recovery
- startup / FTUE / Rank 1 / Rank 2 / Rank 3 / Web export regressions
- touch orbit + pinch zoom
- procedural gameplay feedback audio baseline
- native haptic hooks through `Input.vibrate_handheld`
- provider-neutral analytics event layer; no external data transmission
- runtime FPS health sampling
- iPhone Safari engineering-preview verification

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

## 3. Native verification gate

Run on at least one physical iPhone and one physical Android device.

Required pass:
- cold launch
- fresh-save FTUE
- existing schema-v7 save load
- 10+ minute session
- pause/background/resume
- touch orbit and pinch at screen edges
- Safe Area / Dynamic Island / navigation-area clearance
- audio starts only after platform permits playback
- haptics fire for meaningful events and do not spam shipments
- Rank 1 → Rank 2 → Rank 3 controls remain reachable
- management sheet scrolls without horizontal drift
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

Code can reach **RC Candidate** without the identifiers above. Final **Native RC** requires the identifiers, signed builds, and physical-device verification.
