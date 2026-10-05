# Security policy

## Reporting a vulnerability

Please report security problems **privately**. Do not open a public issue or pull request.

Use GitHub private vulnerability reporting: open the **Security** tab of [noha-agencia/AIControlNotch](https://github.com/noha-agencia/AIControlNotch/security/advisories/new) and choose **Report a vulnerability**.

Please include:

- what the problem is and what an attacker could do with it;
- steps to reproduce, or a small proof of concept;
- the version or commit, and your macOS version.

We will answer as soon as we can, work on a fix with you, and credit you in the release notes if you want. Please give us a reasonable time to fix the problem before you disclose it.

## Supported versions

Only the latest release and the `main` branch receive security fixes.

## What is in scope

- Anything that reads, stores or sends a credential. AIControlNotch must never read a login, token or password, and makes no network requests of its own: a code path that does either is a vulnerability.
- The script provider runner: ways for a `providers.json` entry or a script's output to break its rules (a shell, a larger environment, ignored timeout or output limit, a crash on crafted output).
- The status line wrapper `aicontrolnotch-tap`: ways to make it run something other than the command in `tap.json`, change what the status line prints, or write outside its own folder.
- `scripts/install.sh` and `scripts/uninstall.sh`: unsafe deletes, or edits to files they must not touch (`~/.claude/settings.json`).
- [The AI install guide](docs/install-with-ai.md): steps that would make an assistant read secrets, run unvetted code, or change more than the guide says.
- Files and logs that leak secrets or are readable by other users.
- The GitHub Actions workflow and the build scripts.

## What is out of scope

- What a script you configured does: scripts run with your permissions by design. Only add scripts you trust.
- Vulnerabilities in Claude Code, Codex, macOS or the services behind them. Report those to their vendors.
- Claude Code or Codex changing the data they hand over (the status line input, the `codex app-server` replies, the session logs).
- Attacks that need an already compromised account, root access or physical access to an unlocked Mac.
- Social engineering, and denial of service by someone who already controls your machine.

## Known limits

- The checks on `providers.json`, `tap.json` and script files look at the owner and the permission bits of the file and of the folder holding it. Access lists (`chmod +a`) and the folders further up are not checked. Folders only admins can change, such as Homebrew's `bin`, are trusted: admins can already act as root.
- For scripts, the program and each argument that is a whole path to a file are checked. A path inside an argument (`--config=/path`), a program found through `PATH` (`env python3`, a shebang line) and the command in `tap.json` are not.
- Script files are checked just before they start, not at the very moment they start. Swapping one in that gap needs write access to the file or its folder, which the checks allow only to you, root and admins.
- The `codex` program (found on the app's `PATH`, or in the ChatGPT or Codex app, `~/.local/bin` or `/opt/homebrew/bin`) is run as is: its owner and permissions are not checked.
- On a timeout, the script and everything in its process group are stopped. A script that starts a background process in a new group, or leaves one running after a normal exit, is not tracked.
- Hiding secrets in the stderr preview is best effort, by pattern. A script should not print secrets at all.

## How your data is handled

AIControlNotch runs entirely on your Mac. Nothing is sent to Noha or to anyone else, and there is no telemetry, no analytics and no auto-update.

- **No network requests.** The app itself contacts no server and never reads a login, token, password or Keychain item.
- **Claude:** only the limits Claude Code passes to its status line command. The `aicontrolnotch-tap` wrapper saves the 5 hour and weekly percentages and reset times, then runs your original status line command.
- **Codex:** reads the limits from the local `codex app-server` over stdio, and falls back to the session logs in `~/.codex/sessions`, which also hold your conversations: only the latest rate limit entry is read. Codex reaches OpenAI itself, with its own login. The app never reads `~/.codex/auth.json`.
- **Script providers:** run locally, without a shell, with a minimal environment (`HOME`, `PATH`, `LANG`), a timeout and an output limit.
- **On disk:** `~/Library/Application Support/AIControlNotch/` (saved numbers, alert state, your configuration) and `~/Library/Logs/AIControlNotch/aicontrolnotch.log` (short facts, no tokens, no response bodies). The saved numbers and the log are readable only by you.

The full description is in [How it works](docs/how-it-works.md#privacy).
