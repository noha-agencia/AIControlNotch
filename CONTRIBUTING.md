# Contributing to AIControlNotch

Thanks for helping. Bug reports, new model scripts, docs and code are all welcome. For a security problem, do not open a public issue: see [SECURITY.md](SECURITY.md).

## Ways to contribute

- **Report a bug** with the [bug report](https://github.com/noha-agencia/AIControlNotch/issues/new/choose) template. Include the last lines of the log (`~/Library/Logs/AIControlNotch/aicontrolnotch.log`). It holds no tokens, but read it before pasting.
- **Add a model with a script.** This is the preferred way. See [below](#adding-a-model).
- **Send a pull request.** For anything bigger than a small fix, open an issue first so we can agree on the approach.
- **Keep the docs in sync.** The README and the guides in `docs/` exist in English and Brazilian Portuguese (`docs/pt-BR/`): change both. `docs/install-with-ai.md` is written for AI assistants and stays in English only.

## Build and test

You need macOS 14 or later and a Swift 6 toolchain (Xcode 16 or newer, or the matching Command Line Tools).

```bash
./scripts/test.sh        # runs the test suite (works with Xcode and with the Command Line Tools)
./scripts/coverage.sh    # line coverage of AIControlNotchCore; fails below 90%
./scripts/build-app.sh   # builds .build/AIControlNotch.app without installing it
```

`AIControlNotchCore` must stay at or above **90%** line coverage. The app target and the tap are thin shells and are not counted.

## How the code is organized

| Path | What lives there |
|---|---|
| `Sources/AIControlNotchCore` | All the logic: providers, parsing, pace, alerts, scheduling, state. No AppKit or SwiftUI. |
| `Sources/AIControlNotchApp` | The notch: AppKit and SwiftUI. It only draws the state it receives. |
| `Sources/aicontrolnotch-tap` | The Claude Code status line wrapper. |
| `Tests/AIControlNotchCoreTests` | Swift Testing suites and JSON fixtures. |
| `scripts/` | Install, uninstall, build, test and coverage scripts. |
| `examples/providers/` | The script template and a sample `providers.json`. |
| `docs/` | User guides (English, with Portuguese copies in `docs/pt-BR/`), the AI install runbook and the README images. |

Decisions live in Core. Everything that touches the outside world (processes, files) goes through a small protocol such as `ProcessRunning` or `InteractiveSpawning`, so tests use fakes and never touch your machine.

## Working rules

- **Test first.** Write a failing test, see it fail, write the smallest code that passes, then refactor. A change in Core without a test will not be merged.
- **Small files and functions.** Files around 200 to 400 lines (800 at most), functions under 50 lines, no deep nesting. Split by feature, not by type.
- **Immutable values.** Return a new value instead of changing one in place.
- **Handle errors.** No silent failures. Failures become visible problems in the panel and short, secret-free lines in the log.
- **No hardcoded secrets or personal data**, in code, tests or fixtures.
- **Conventional commits**: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`, `perf:`, `ci:`. One short line, then a body if the why is not obvious.

## Adding a model

### With a script (preferred)

A script needs no Swift and no rebuild. Start from [`examples/providers/`](examples/providers/): a commented template, a sample `providers.json` and the rules (no shell, minimal environment, timeout, size and interval limits, the JSON v1 format). [Add a model](docs/add-a-model.md) has the full reference.

To share a script, open a "new model" issue or a pull request. We only ship examples that are verifiable: they read local files that the model's own CLI already writes, they ask for no password or token, and they never scrape a website.

### As a Swift provider (pull request)

Use this only when a script cannot do the job. Open an issue first. A source is a type that conforms to `UsageProvider` (`Sources/AIControlNotchCore/Providers/UsageProvider.swift`):

```swift
public protocol UsageProvider: Sendable {
    var provider: ProviderID { get }
    var source: DataSource { get }
    var policy: FetchPolicy { get }   // defaults to .standard
    func fetch() async throws -> ProviderSnapshot
}
```

1. Add the provider in `Sources/AIControlNotchCore/Providers/`. Receive its dependencies through protocols, like `CodexAppServerProvider` does.
2. Parse the response into `UsageWindow` values and validate every field. Never trust external data. Throw a `UsageError` instead of returning a made up number.
3. Add tests with fixtures in `Tests/AIControlNotchCoreTests/Fixtures/`, for success and for every failure.
4. Wire it up in `Sources/AIControlNotchApp/ProviderFactory.swift`, and give it a name, a color and a monogram. Only Claude and Codex carry their official logos: new models are drawn as a letter in their color.
5. Update the docs in both languages: the READMEs, `docs/how-it-works.md` and `docs/pt-BR/how-it-works.md`.

### Rules for every provider

- **Never read another tool's login, token or password**, from the Keychain, a file or anywhere else. Use numbers the tool itself shows on the Mac, or a command of its own that fetches them.
- **No network requests from the app.** If the numbers only exist on the provider's servers, let the provider's own tool fetch them.
- **Never log secrets.** Log short facts only: the source, the kind of error, how long it took. No tokens and no raw output.
- **Be polite.** Respect the scheduler's minimum spacing and backoff. Do not poll faster than the data changes.

## Pull request checklist

- [ ] `./scripts/test.sh` passes
- [ ] `./scripts/coverage.sh` passes (Core at 90% or more)
- [ ] New logic has tests, written first
- [ ] No secrets, tokens or personal data
- [ ] Docs updated in both languages when behavior changed
- [ ] Commits follow conventional commits
