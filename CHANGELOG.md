# Changelog

All notable changes to Spread The Funds will be documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Copilot instruction files for consistent AI-assisted development
- CHANGELOG.md and PROGRESS.md for documentation discipline
- `.vscode/settings.json` for Dart/Flutter editor configuration

## [1.0.11] - 2026-03-31

### Changed
- Include native debug symbols in AAB for Play Store crash reporting

## [1.0.9]

### Changed
- Various improvements, bug fixes, and new widgets

## [1.0.7]

### Added
- Play Store links in app

### Fixed
- Navigation bar fixes

### Changed
- UI polish throughout the app

## [1.0.6]

### Changed
- Declare AD_ID permission for firebase-analytics

## [1.0.5]

### Changed
- Declare app does not use advertising ID (Android 13+ requirement)

## [1.0.4]

### Fixed
- R8 missing Play Core classes in proguard rules

### Changed
- Major rebrand to "Spread the Funds" with new features and assets

## [1.0.3] - Tagged

### Added
- Custom app icon
- Group details improvements
- Pull-to-refresh for invites
- Feedback form (Firestore)
- About screen easter egg

### Changed
- Open releases URL directly in browser instead of showing dialog
- UI updates throughout

### Fixed
- Removed accidental `cd` file from project root (#38)
- Updated Dart SDK constraint to >=3.6.0 for `Color.withValues()` API (#37)

## [1.0.0]

### Added
- Initial release — Spread the Fund bill-splitting app
- Bill detail screen
- Onboarding flow
- Group details with edit dropdowns (name + email display)
- Firebase real-time database integration
- Google Sign-In authentication
- Provider state management
