# Vvewell

A smart health management iOS app that connects with wearable ring devices to track and analyze your health data.

## Features

- **Home Dashboard** — Overview of health metrics including heart rate, blood oxygen, stress level, and sleep quality
- **Health Tracking** — Detailed health profile with connected device data and health scores
- **Health Check** — Interactive health assessment questionnaire
- **Services** — Discover health-related content, articles, and recommendations
- **Nutritions** — Home > More Services > Nutrition opens a fully localized demo storefront with placeholder banners, category filters, consultant CTA, and product cards; supports all 7 app languages and light/dark mode; no cart, checkout, or payment flow is included
- **Profile** — Account management, device settings, and app preferences
- **Bluetooth Ring Integration** — Connects to wearable ring devices for real-time health monitoring

## Requirements

- iOS 15.0+
- Xcode 15.0+
- Swift 5.9+

## Project Structure

```
vvewell-app-ios/
├── Sources/
│   ├── App/
│   │   ├── AppDelegate.swift          # App lifecycle
│   │   └── SceneDelegate.swift        # Scene lifecycle
│   ├── Views/
│   │   ├── LaunchViewController.swift         # Welcome screen
│   │   ├── LoginViewController.swift          # Legacy login
│   │   ├── RelayLoginViewController.swift     # Relay auth login
│   │   ├── MainTabBarController.swift         # Tab bar navigation
│   │   ├── MainViewController.swift           # Home dashboard shell
│   │   ├── MainViewController+Sections.swift  # Home section layout/builders
│   │   ├── MainViewController+Localization.swift
│   │   ├── MainViewController+HealthOverview.swift
│   │   ├── NutritionMallViewController.swift  # Demo nutrition shopping entrance
│   │   ├── HealthViewController.swift         # Health page shell
│   │   ├── HealthViewController+Sections.swift
│   │   ├── HealthViewController+Refresh.swift
│   │   ├── HealthViewController+OCR.swift
│   │   ├── HealthProduct.swift               # Health product model
│   │   ├── OcrReport.swift                   # OCR report model
│   │   ├── OcrReportRepository.swift         # OCR local persistence
│   │   ├── OcrReportDetailViewController.swift
│   │   ├── SymptomChatViewController.swift   # Chat page shell
│   │   ├── SymptomChatViewController+Attachments.swift
│   │   ├── SymptomChatViews.swift            # Chat bubble/cards/sections
│   │   ├── HealthCheckViewController.swift   # Health assessment
│   │   ├── DiscoverViewController.swift      # Services & content
│   │   └── ProfileViewController.swift       # User profile
│   ├── Services/
│   │   ├── APIClient.swift                # Relay / OCR / assistant APIs
│   │   ├── AuthManager.swift              # Local auth state
│   │   ├── AuthTokenManager.swift         # Relay token state
│   │   ├── HealthRecordRepository.swift   # Health record access
│   │   └── L10n.swift                     # Localized strings
│   ├── Metrics/                          # Metric storage / sync / models
│   ├── Models/                           # App models
│   ├── AppDesign.swift                   # Design constants
│   └── Info.plist
└── Products/
    └── vvewell-app-ios.app
```

## Architecture

- **UIKit** — Programmatic UI layout (no Storyboards)
- **MVC** — Model-View-Controller pattern
- **Companion-file split for large screens** — Home / Health / SymptomChat are split into a small screen shell plus focused extensions/helpers to reduce single-file bloat while preserving behavior
- **AppDesign** — Centralized design token system for colors, corner radii, shadows, and layout constants
- **Scene-based** — Uses UIScene lifecycle for window management
- **XcodeGen source discovery** — `project.yml` includes the entire `Sources/` directory for app targets, so newly added Swift files under `Sources/` are automatically included in builds without manually editing the Xcode project

## Recent Updates

- **Health page cleanup** — Removed the `Recommended Products` carousel and embedded advertisement from the Health screen
- **Nutritions page** — Renamed from "Nutrition Factory"; all UI strings use L10n keys with translations in en/zh/ar/es/fr/id/th; colors use semantic system colors (`.secondarySystemBackground`, `.label`) for dark mode support; language-change observer rebuilds all content live
- **Cloud sync pull** — "Sync Now" on the Health page now downloads cloud readings via `GET /api/v1/health/readings`, converts them to local `RawReading` objects, and imports them into `HealthMetricStore` with deduplication; previously it only fetched the count and discarded the data

## Getting Started

1. Clone the repository
2. Open `vvewell-app-ios.xcodeproj` in Xcode
3. Select a simulator or connected device
4. Build and run (⌘R)

## License

All rights reserved.
