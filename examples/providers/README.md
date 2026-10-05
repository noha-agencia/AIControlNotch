# Script providers

Add any AI model to AIControlNotch with a small script, in any language. The full guide, with the JSON format and the rules scripts run under, is [Add a model](../../docs/add-a-model.md) ([Português](../../docs/pt-BR/add-a-model.md)).

| File | What it is |
|---|---|
| [`template.sh`](template.sh) | Commented bash script that prints a valid v1 JSON with fixed sample numbers. Start here. |
| [`providers.example.json`](providers.example.json) | A `providers.json` with one script model named "Example". |

## Quick start

```bash
mkdir -p ~/Library/Application\ Support/AIControlNotch/scripts
chmod 700 ~/Library/Application\ Support/AIControlNotch/scripts
cp examples/providers/template.sh ~/Library/Application\ Support/AIControlNotch/scripts/example.sh
chmod 700 ~/Library/Application\ Support/AIControlNotch/scripts/example.sh
~/Library/Application\ Support/AIControlNotch/scripts/example.sh | python3 -m json.tool
```

Then right-click the notch, choose **Configure models…** and add the model as shown in [Add a model](../../docs/add-a-model.md#1-configure).

Prefer to let your AI assistant do it? Paste this into Claude Code, Codex or any assistant that can run commands on your Mac (change the name):

```text
Connect Gemini to AIControlNotch. Follow step 6 of https://github.com/noha-agencia/AIControlNotch/blob/main/docs/install-with-ai.md and ask me before changing anything.
```

## Sharing a script

This folder only ships the template, because every example here has to be verified: it must read local files or commands of the model's own tool, ask for no password or token, and never scrape a website. If you wrote a script that meets this bar, open a [new model issue](https://github.com/noha-agencia/AIControlNotch/issues/new/choose) or a pull request. See [CONTRIBUTING.md](../../CONTRIBUTING.md).
