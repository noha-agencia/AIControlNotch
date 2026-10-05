# How it works

**English** · [Português (Brasil)](pt-BR/how-it-works.md)

## Privacy

Everything happens on your Mac. **Nothing is sent to Noha or to anyone else.** There is no telemetry, no analytics and no auto-update. **The app makes no network requests of its own** and never reads a login, token or password.

The app refreshes every 5 minutes (every 15 when you have been away for 10 minutes or more), after the Mac wakes, and when you open the panel with data older than 3 minutes. After an error it waits longer before trying again.

### Claude

- **Source.** The limits Claude Code itself hands to its status line command, saved by the small `aicontrolnotch-tap` wrapper. See [Claude Code status line](#claude-code-status-line), below.
- The app never reads the Claude Code login, never touches the Keychain and never calls Anthropic.
- The numbers update whenever Claude Code runs. In between, the notch shows the last ones, and the dot turns gray after 30 minutes.
- With several Claude Code sessions open, an idle one can hand over older numbers. The notch keeps the highest usage seen for each limit until that limit renews, so it never goes down by mistake.

### Codex

- **Primary source.** The app runs the local `codex app-server`, the one bundled with the ChatGPT app or a `codex` CLI on your Mac, and talks to it over stdio. Codex reads the limits with its own login. AIControlNotch only receives the numbers.
- **Fallback.** The session logs in `~/.codex/sessions` (and `~/.codex/archived_sessions`). They also hold your Codex conversations: the app looks only for the latest rate limit entry, and copies or sends nothing from them.
- The app never reads `~/.codex/auth.json`.

### Script models

Scripts you add run locally, with your permissions, without a shell and with a minimal environment. See [Add a model](add-a-model.md#how-scripts-run).

### What it stores

In your user account:

- `~/Library/Application Support/AIControlNotch/`: the last numbers and alert state (`state.json`), your `providers.json` and scripts, and, once Claude is connected, `tap.json` and `claude-statusline.json`. The saved numbers and the log are readable only by you.
- `~/Library/Logs/AIControlNotch/aicontrolnotch.log`: short facts such as the source, the kind of error and timing. Never tokens or response bodies. It rotates at 1 MB.

## Claude Code status line

This is how Claude connects. Each time Claude Code updates its status line, it hands the status line command a JSON document that includes your plan limits. The wrapper `aicontrolnotch-tap` saves only the 5 hour and weekly percentages and their reset times to `~/Library/Application Support/AIControlNotch/claude-statusline.json`, then runs your original status line command with the same input and returns its output, so your status line keeps working. It needs Claude Code in a terminal, signed in with a Claude plan (Pro or Max): with an API key, Claude Code passes no plan limits.

`./scripts/install.sh` saves your current status line command to `tap.json` for you and prints what to change. **It never edits `~/.claude/settings.json`: you do that, or your AI assistant does it with your OK.** In that file, set:

```json
"statusLine": {"type": "command", "command": "\"$HOME/Library/Application Support/AIControlNotch/bin/aicontrolnotch-tap\""}
```

If you do it manually, `tap.json` holds your original command:

```json
{"command": "node ~/.claude/statusline.js"}
```

`tap.json` runs through the shell, so it gets the same checks as `providers.json`: it must belong to you and must not be writable by other users (`chmod 600` on it). Otherwise your status line shows `AIControlNotch: tap.json ignored:` and the reason, instead of running it.

To disconnect Claude, put your original command back in `settings.json`.

## Menu

Right-click the notch:

- **Refresh now**
- **Configure models…**: creates `providers.json` if needed and opens it
- **Reload models**: reads `providers.json` again now
- **Open at login**
- one line per model: where its numbers came from and how old they are (and, if `providers.json` was rejected, why)
- **Quit AIControlNotch**

There is no Dock icon: the notch is the app.

## Command line

The command line lives inside the app bundle:

```bash
APP=/Applications/AIControlNotch.app/Contents/MacOS/AIControlNotch

$APP --launch-at-login on    # open at login (use off to turn it off), then exit
$APP --demo                  # play a short demo with sample numbers on the real notch, then quit
$APP --render-states <dir>   # write a PNG of each notch state to <dir>, then exit
$APP --render-frames <dir> --scene rest|open|alerts|models [--fps 30] [--scale 3]
                             # write a transparent PNG sequence of one animated scene, then exit
```

`--render-states` and `--render-frames` take `--lang en` or `--lang pt` to pick the language. `--render-frames` writes `<dir>/<scene>/frame-0000.png…` and a `scene.json` with the frame size, the notch position and when each state change happens.

`--demo --snapshots <dir>` also saves what the panel shows at each step.
