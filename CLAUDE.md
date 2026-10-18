# Vvewell iOS App — Development Guidelines

## Project Overview

Health management iOS app connecting with wearable devices (Ring, Watch, Band). UIKit programmatic layout, Combine, no third-party dependencies. Build with Xcode, target iOS 13.0+, device-only (Ring SDK frameworks don't support simulator).

## Build

```bash
xcodegen generate
xcodebuild -project vvewell-app-ios.xcodeproj -scheme vvewell-app-ios -sdk iphoneos -destination generic/platform=iOS build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

## Git Branch Management

### Core Principles
1. `main` is the only permanent baseline — always deployable
2. `release/*` represents a deployment action — multiple can coexist in parallel
3. Branches handle code flow only — deployment is controlled by CI/CD (decoupled)

### Branch Types

| Branch | Type | From | Merge To | Purpose |
|--------|------|------|----------|---------|
| `main` | Permanent | — | — | Stable baseline |
| `feature/KW-{ticket}-{desc}` | Temporary | main | release/* | Feature development |
| `release/YYYYMMDD-{desc}` | Temporary | main | main | Collect features for deployment |
| `hotfix/KW-{ticket}-{desc}` | Temporary | main | main | Emergency production fix |

### Release Flow
```
feature/* → (PR) → release/* → (PR) → main → tag vX.Y.Z
```

1. Create feature from main: `git checkout main && git pull && git checkout -b feature/KW-xxx-desc`
2. Rebase before merge: `git fetch origin && git rebase origin/main`
3. Create release from main: `git checkout main && git checkout -b release/YYYYMMDD-desc`
4. Merge features into release via PR (multiple features per release OK)
5. Bug fix: fix on feature branch, re-PR into release — **never commit directly on release/***
6. Ship: PR release/* → main (CI green + 1 approve), then `git tag vX.Y.Z`
7. Cleanup: delete release/* and merged feature/* branches

### Hotfix Flow
```
main → hotfix/KW-xxx-desc → (PR) → main → tag → cherry-pick to active release/*
```

### Commit Convention (Conventional Commits)
```
feat(ring): add heart rate measurement service
fix(health): handle nil sleep data gracefully
refactor(devices): replace RxSwift with Combine
chore(deps): update RingSDK to V2.0.36
```

## Architecture

### Devices Layer (`Sources/Devices/`)
- `HealthDeviceProtocol` — unified interface for all health hardware
- `DeviceManager` — registry + coordinator singleton
- `Ring/` — RingSDK wrapper (9 service modules)
- Adding new hardware: implement `HealthDeviceProtocol`, register with `DeviceManager`

### UI Rules
- **Never replace existing pages** — add new features to existing ViewControllers
- Follow existing design language (light theme with system colors)
- Use `AppDesign` tokens for colors, radii, spacing
- All layout is programmatic UIKit (no Storyboards)

### Vendor Frameworks (`Sources/Frameworks/`)
- Device-only (no simulator support) — do not modify
- Known warning: `SNBLELogManager` class duplication between RingSDK and EiotGluSdk (vendor issue, safe to ignore)
