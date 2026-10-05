# Add a model

**English** · [Português (Brasil)](pt-BR/add-a-model.md)

Any AI that shows its usage somewhere you can read on your Mac can go in the notch. AIControlNotch runs a small script of yours on a timer, reads JSON from its standard output, and draws it next to Claude and Codex, with the same pace dot and the same alert every 10 points.

**The easy way:** ask your AI assistant. Paste this into Claude Code, Codex or any assistant that can run commands on your Mac (change the tool name):

```text
Connect Gemini to AIControlNotch. Follow step 6 of https://github.com/noha-agencia/AIControlNotch/blob/main/docs/install-with-ai.md and ask me before changing anything.
```

It looks for a safe source of numbers, writes and tests the script with you, and adds it to the app. The rest of this page is the reference, for doing it by hand.

## Where the numbers can come from

Only use sources that need no new secret:

- a file the model's own tool already writes on your Mac;
- a command the model's own tool ships.

Do not scrape websites, read browser cookies, ask for a password or store a token. If the numbers only exist on the provider's servers, use a command of the provider's own tool that fetches them. A script must never read, copy or send that tool's token itself.

## Quick start

1. Copy the template to the app's folder and make it executable:

   ```bash
   mkdir -p ~/Library/Application\ Support/AIControlNotch/scripts
   chmod 700 ~/Library/Application\ Support/AIControlNotch/scripts
   cp examples/providers/template.sh ~/Library/Application\ Support/AIControlNotch/scripts/example.sh
   chmod 700 ~/Library/Application\ Support/AIControlNotch/scripts/example.sh
   ```

2. Check that it prints valid JSON:

   ```bash
   ~/Library/Application\ Support/AIControlNotch/scripts/example.sh | python3 -m json.tool
   ```

3. Right-click the notch and choose **Configure models…**, then add the model (see below). The template prints fixed sample numbers: replace its step 1 with your real source.

4. Save the file. The change is picked up on the next refresh; **Reload models** reads it at once. If the file has a mistake, the menu says what and where, and the last good settings stay in use.

## 1. Configure

**Configure models…** creates and opens `~/Library/Application Support/AIControlNotch/providers.json`:

```json
{
  "pinned": ["claude", "codex"],
  "disabled": [],
  "providers": [
    {
      "id": "mymodel",
      "name": "My Model",
      "color": "#5B8CFF",
      "command": ["~/Library/Application Support/AIControlNotch/scripts/mymodel.sh"],
      "intervalSeconds": 300,
      "timeoutSeconds": 15
    }
  ]
}
```

| Field | Meaning |
|---|---|
| `pinned` | Models shown in the resting notch, up to two ids. A disabled model is unpinned; with none left, the first enabled models are used. |
| `disabled` | Ids to hide. At least one model stays enabled, and at most 6 are enabled. |
| `id` | Unique slug: lowercase letters, digits and `-`, up to 32 characters, not starting with `-`. Different from `claude` and `codex`. |
| `name` | Name shown in the panel and in alerts, 1 to 24 visible characters. |
| `color` | Hex color, `#RRGGBB`. Third party models get a monogram in this color. |
| `command` | The script, as an argv array. Use the full path; `~/` at the start of any item means your home folder, but `$HOME` and other variables are not expanded, because there is no shell. |
| `intervalSeconds` | Seconds between runs: 300 by default, from 60 to 86400. |
| `timeoutSeconds` | Seconds before the script is stopped: 15 by default, 60 at most. |

[`examples/providers/providers.example.json`](../examples/providers/providers.example.json) is a ready file with one sample model.

## 2. Print JSON

Your script writes this to stdout:

```json
{
  "version": 1,
  "plan": "Pro",
  "windows": [
    {"label": "5h", "durationMinutes": 300, "usedPercent": 38.5, "resetsAt": "2026-10-05T18:00:00Z"},
    {"label": "Week", "durationMinutes": 10080, "usedPercent": 12, "resetsAt": "2026-10-09T09:00:00Z"}
  ]
}
```

| Field | Meaning |
|---|---|
| `version` | Always `1`. |
| `plan` | Optional text shown next to the model name, up to 24 visible characters. |
| `windows` | The limits of the model, up to 4, one per length (see below). |
| `windows[].label` | Optional row label, up to 24 visible characters. |
| `windows[].durationMinutes` | Length of the window, a whole number from 1 to 525600 (300 is 5 hours, 10080 is a week). |
| `windows[].usedPercent` | How much of the limit is used, from 0 to 1000 (100 means the limit is reached). |
| `windows[].resetsAt` | Optional ISO 8601 time when the window renews. Leave it out when the window has not started. |

The pace dot needs `resetsAt` and `durationMinutes` to tell whether the limit will last until it renews.

Windows are told apart by their length class: about 5 hours, about a week, a number of minutes under a day, or a number of days. Alerts and panel rows are keyed by that class, so two windows of about the same length (say 10080 and 10000 minutes) are rejected, with the error naming both.

[`examples/providers/template.sh`](../examples/providers/template.sh) is a commented bash script that prints a valid document.

## How scripts run

- **No shell.** `command` is an argv array, so pipes and `$VAR` are not expanded. Put them inside the script. Only a leading `~/` is expanded.
- **Minimal environment.** Only `HOME`, `LANG` and `PATH` (`/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin`). The working directory is your home folder.
- **Time and size.** 15 s timeout by default, 60 s at most; then the script and anything it started are stopped. At most 64 KB on stdout. A script runs at most once per `intervalSeconds` (once a minute with **Refresh now**).
- **Errors are visible.** A non zero exit code, invalid JSON or a value out of range shows a problem in the panel, naming the model and the reason. It never crashes the app and never shows a made up number. Whatever the script writes to stderr goes to the log, truncated, with anything that looks like a token or password hidden.
- **`providers.json` is code: it decides which programs the app runs.** It must belong to you and must not be writable by other users (`chmod 600` on it), or it is ignored.
- **So are the scripts.** The program, any file named in its arguments and the folders holding them must be yours (or the system's) and not writable by others (`chmod go-w`). Folders only admins can change, like Homebrew's `bin`, are fine. Otherwise the panel says "other users can change its files" and the script does not run.
- **Your user, your trust.** A script runs with your permissions. Only add scripts you read and trust.

The hover panel shows every enabled model, pinned ones first, up to 6. When they add up to more than 12 lines, the least used limits of the models with the most windows are left out of the panel (every model keeps at least one). Alerts every 10 points work for all of them.

## Sharing a script

The repository only ships the template, because every example has to be verified: it must read local files or commands of the model's own tool, ask for no password or token, and never scrape a website. If you wrote a script that meets this bar, open a [new model issue](https://github.com/noha-agencia/AIControlNotch/issues/new/choose) or a pull request. See [CONTRIBUTING.md](../CONTRIBUTING.md).
