# Notes for AI assistants

AIControlNotch is a macOS app that shows AI plan usage (Claude, Codex and models added with scripts) in the MacBook notch. It is written in Swift 6 with SwiftPM and needs no Xcode project.

## What the person wants

- **Install the app, or connect their AI tools to it:** follow [docs/install-with-ai.md](docs/install-with-ai.md) step by step, including its ground rules. Step 6 covers connecting a new tool.
- **Fix a problem with the installed app:** read [docs/troubleshooting.md](docs/troubleshooting.md) and the log at `~/Library/Logs/AIControlNotch/aicontrolnotch.log`.
- **Change the code:** read [CONTRIBUTING.md](CONTRIBUTING.md) first and follow its working rules.

## Never

- Read, print, copy or store tokens, passwords, API keys, cookies or Keychain values. Do not open `~/.codex/auth.json`.
- Add code that reads another tool's login or token, or that makes the app send network requests.
- Log a token or a raw response.
- Edit `~/.claude/settings.json` without the person's yes to the exact change.
- Use `sudo`, or weaken a file permission to get past an error.

## Developing

```bash
./scripts/test.sh                     # all tests (Swift Testing); add --filter <name> for one suite
./scripts/coverage.sh                 # AIControlNotchCore line coverage, fails below 90%
swift build                           # debug build
./scripts/build-app.sh                # builds .build/AIControlNotch.app
./scripts/install.sh --no-login       # builds and installs to /Applications
```

| Path | What lives there |
|---|---|
| `Sources/AIControlNotchCore` | All the logic: providers, parsing, pace, alerts, scheduling, state. No AppKit or SwiftUI. |
| `Sources/AIControlNotchApp` | The notch UI (AppKit and SwiftUI). It only draws the state it receives. |
| `Sources/aicontrolnotch-tap` | The Claude Code status line wrapper. |
| `Tests/AIControlNotchCoreTests` | Swift Testing suites and JSON fixtures. |

- Test first: write a failing test, see it fail, then write the smallest code that passes.
- Everything that touches the outside world (processes, files) goes through a protocol so tests use fakes.
- Keep values immutable, files small and functions short.
- User-facing text exists in English and Portuguese. Update the docs in both languages when behavior changes.
- Commits follow conventional commits (`feat:`, `fix:`, `docs:`…).
