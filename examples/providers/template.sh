#!/bin/bash
# AIControlNotch script provider: template.
#
# AIControlNotch runs this script on a timer and reads ONE JSON document from its
# standard output. It draws the result in the notch next to Claude and Codex, with
# the same pace dot and the same alert every 10 points.
#
# How you are run:
#   - no shell (the command in providers.json is an argv array)
#   - minimal environment: HOME, PATH and LANG only; working directory is your home
#   - 15 s timeout by default (60 s at most), then this script and anything it
#     started are stopped; at most 64 KB on stdout
#   - up to 4 windows, one per length (5 hours, a week, ...); text up to 24 characters
#   - exit code other than 0, invalid JSON or an out of range value shows a
#     visible problem in the panel (never a made up number)
#   - everything on stderr goes to the log (truncated), never to the notch
#
# This template prints FIXED SAMPLE NUMBERS. To make it real, replace step 1 with
# something that reads a file your model's own tool already writes, or runs a local
# command. Never ask for a login, never keep one, and never scrape a website.
#
# Try it in a terminal:
#   ./template.sh | python3 -m json.tool
set -euo pipefail

# 1. Your numbers. Replace these fixed values.
PLAN="Example"           # optional text next to the model name
LABEL="5h"               # optional row label
DURATION_MINUTES=300     # length of the window: 300 = 5 hours, 10080 = 1 week
USED_PERCENT=38.5        # how much of the limit is used (100 = limit reached)

# 2. When the window renews, as an ISO 8601 time in UTC.
#    macOS ships BSD date: -v+3H means "3 hours from now". Leave "resetsAt" out of
#    the JSON if the window has not started yet.
RESETS_AT="$(date -u -v+3H +%Y-%m-%dT%H:%M:%SZ)"

# 3. Print the JSON (version 1). Plain numbers and fixed text are safe to paste into
#    the template below. If you add text that comes from outside, escape it first
#    (python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$text").
#    To report a failure, write a short reason to stderr and exit non zero:
#      echo "could not read usage file" >&2; exit 1
cat <<JSON
{
  "version": 1,
  "plan": "$PLAN",
  "windows": [
    {
      "label": "$LABEL",
      "durationMinutes": $DURATION_MINUTES,
      "usedPercent": $USED_PERCENT,
      "resetsAt": "$RESETS_AT"
    }
  ]
}
JSON
