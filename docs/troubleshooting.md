# Troubleshooting

**English** · [Português (Brasil)](pt-BR/troubleshooting.md)

**Claude shows no data.**
Claude connects through the [Claude Code status line](how-it-works.md#claude-code-status-line). Check that `statusLine` in `~/.claude/settings.json` runs `aicontrolnotch-tap` (`plutil -extract statusLine.command raw -o - ~/.claude/settings.json` shows just that line), use Claude Code once in a terminal, then choose **Refresh now**. Claude Code passes plan limits only when you sign in with a Claude plan (Pro or Max), not with an API key.

**My status line shows "AIControlNotch: tap.json ignored".**
`tap.json` holds your original status line command, so it must belong to you and be private: `chmod 600 ~/Library/Application\ Support/AIControlNotch/tap.json`.

**Codex shows no data.**
Open Codex (the ChatGPT app or the `codex` CLI) once and sign in. The app looks for `codex` on your `PATH`, then in `/Applications/ChatGPT.app`, `/Applications/Codex.app`, `~/.local/bin` and `/opt/homebrew/bin`. If none is found, it falls back to the session logs, which only update while Codex runs.

**I do not use Claude or Codex.**
Right-click the notch, choose **Configure models…** and put its id (`claude` or `codex`) in `disabled`. At least one model has to stay enabled.

**The numbers look old.**
The menu shows each model's source and age. A gray dot means data older than 30 minutes. Claude's numbers, and Codex's when they come from the session logs, update only while Claude Code or Codex runs.

**A script model shows an error.**
The message in the panel names the script and the reason. Run the script in a terminal and pipe it through `python3 -m json.tool` to see what it prints. The rules are in [Add a model](add-a-model.md#how-scripts-run).

**"Other users can change its files".**
The script, a file named in its arguments, or a folder holding them can be changed by other users of this Mac. Run `chmod go-w` on them.

**Nothing at the top of the screen.**
Only one copy runs at a time, and there is no Dock icon. Look for `AIControlNotch` in Activity Monitor, or open it again from `/Applications`.

**The build fails.**
Check that `swift --version` shows Swift 6 or newer. If it does not, update Xcode or the Command Line Tools in **System Settings > General > Software Update**, or run `xcode-select --install`.

**Where is the log?**
`~/Library/Logs/AIControlNotch/aicontrolnotch.log`. It holds no tokens, but read it before you paste it anywhere:

```bash
tail -n 50 ~/Library/Logs/AIControlNotch/aicontrolnotch.log
```

Still stuck? Open a [bug report](https://github.com/noha-agencia/AIControlNotch/issues/new/choose).
