# FLOTRA — DEVICE_VALIDATION Access Record

Status: **Pre-GO / DEVICE_VALIDATION**
Updated: 2026-09-18 JST

## 1. Confirmed access state

- REAL_DEVICE_ACCESS: **AVAILABLE**
- Physical test owner: user
- Representative device: user's iPhone
- Exact model / iOS version: **UNRECORDED**
- Repeated sessions: **AVAILABLE**
- MAC_XCODE_ACCESS_PATH: **BLOCKED — no Mac currently available**

Do not infer the exact iPhone model from account/client metadata. Record it from the actual device when DEVICE_VALIDATION begins.

## 2. Current technical position

Already proven:
- FLOTRA Godot project parses/imports in CI
- unsigned iOS Xcode-project generation works on GitHub-hosted macOS
- iOS arm64 Godot payload is present
- FLOTRA display name is injected
- portrait/full-screen project settings are present

Not proven:
- development signing on the user's Apple Account
- physical-device pairing
- installation to the user's iPhone
- native launch/lifecycle/audio/haptic/performance behavior

GitHub Actions macOS is therefore **build infrastructure only** for the current gate. It does not establish a physical-device installation path.

## 3. Minimum viable Pre-GO install path

The next valid path is:

1. obtain temporary access to a Mac that can run the current Xcode;
2. download/use the existing FLOTRA unsigned Xcode project;
3. open the project in Xcode;
4. sign in with the user's Apple Account;
5. use **Personal Team** / automatic signing;
6. select a **unique development-only Bundle ID**; it does not need to be the final production Bundle ID;
7. connect/pair the user's iPhone;
8. enable Developer Mode if iOS requests it;
9. build and run FLOTRA on the iPhone;
10. begin the multi-session DEVICE_VALIDATION matrix.

No paid Apple Developer Program membership is required merely to install/test on a personal device with Xcode Personal Team. Personal Team provisioning is temporary and must be renewed periodically.

## 4. Explicitly deferred until after GREENLIGHT + GO

- final production Bundle ID / App ID
- production distribution signing
- TestFlight production workflow
- App Store Connect release setup
- Store assets / submission
- active Android production work

## 5. Official Apple references

- Running your app on simulated or physical devices:
  https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices

- Developer account overview / Personal Team:
  https://developer.apple.com/help/account/basics/about-your-developer-account

- Programs overview:
  https://developer.apple.com/help/account/membership/programs-overview

## 6. Current blocker

**MAC_XCODE_ACCESS_PATH only.**

Do not buy hardware, enroll in a paid developer program, start TestFlight, or create production signing material merely to clear this Pre-GO blocker without explicit user approval.
