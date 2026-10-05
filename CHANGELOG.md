# Changelog

All notable changes to AIControlNotch are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

- Claude and Codex are drawn with their official logos. Models added by script keep a letter in their color.

## [0.1.0] - 2026-10-05

First public release.

### Added

- The notch: the highest usage of two pinned models at rest, every limit of up to 6 models on hover, with a pace dot per model. Each model is drawn as a letter in its color.
- Alerts every 10 points of any limit, also over full-screen apps.
- Claude, from the limits Claude Code hands to its status line, saved by a small wrapper (`aicontrolnotch-tap`). The app never reads a login or token and makes no network requests of its own.
- Codex, from the local `codex app-server`, with the session logs as fallback.
- Script providers: add any model with a script that prints JSON, configured in `providers.json`.
- English and Portuguese, following the system language.
- Install and uninstall scripts that build the app from source.
- A guide that lets an AI assistant install the app and connect other AI tools: [docs/install-with-ai.md](docs/install-with-ai.md).

[Unreleased]: https://github.com/noha-agencia/AIControlNotch/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/noha-agencia/AIControlNotch/releases/tag/v0.1.0
