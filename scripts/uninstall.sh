#!/usr/bin/env bash
# Removes AIControlNotch: the login item, the app, and (after asking) its data and logs.
#
#   ./scripts/uninstall.sh [--yes] [--keep-data] [--help]
#
#   --yes        delete the data and log folders without asking
#   --keep-data  keep the data and log folders without asking
#
# It never edits ~/.claude/settings.json: if your Claude Code status line goes through
# aicontrolnotch-tap, it tells you what to put back.
set -euo pipefail

APP_NAME="AIControlNotch"
APP_PATH="/Applications/$APP_NAME.app"
APP_BINARY="$APP_PATH/Contents/MacOS/$APP_NAME"
SUPPORT_DIR="$HOME/Library/Application Support/AIControlNotch"
LOG_DIR="$HOME/Library/Logs/AIControlNotch"
TAP_CONFIG="$SUPPORT_DIR/tap.json"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.noha.aicontrolnotch.plist"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
QUIT_WAIT_SECONDS=10

usage() {
    cat <<'EOF'
Usage: ./scripts/uninstall.sh [--yes] [--keep-data] [--help]

Turns off opening at login, quits AIControlNotch and removes /Applications/AIControlNotch.app.
Then it asks before deleting the data folder (~/Library/Application Support/AIControlNotch,
which holds providers.json) and the logs (~/Library/Logs/AIControlNotch).

  --yes        delete the data and log folders without asking
  --keep-data  keep the data and log folders without asking
  --help       show this help

It never edits ~/.claude/settings.json.
EOF
}

say() { printf '%s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
fail() { printf 'error: %s\n' "$*" >&2; exit 1; }

data_choice="ask"
for arg in "$@"; do
    case "$arg" in
        --yes) [[ "$data_choice" == "keep" ]] && fail "--yes and --keep-data cannot be combined."; data_choice="delete" ;;
        --keep-data) [[ "$data_choice" == "delete" ]] && fail "--yes and --keep-data cannot be combined."; data_choice="keep" ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; exit 64 ;;
    esac
done

app_is_running() {
    pgrep -f "^$APP_BINARY" >/dev/null 2>&1
}

wait_until_stopped() {
    local waited=0
    while app_is_running && (( waited < QUIT_WAIT_SECONDS )); do
        sleep 1
        waited=$((waited + 1))
    done
    ! app_is_running
}

turn_off_login_item() {
    if [[ -x "$APP_BINARY" ]]; then
        "$APP_BINARY" --launch-at-login off >/dev/null 2>&1 || true
    fi
    # The app's fallback when macOS refuses its login item: a per-user LaunchAgent.
    rm -f "$LAUNCH_AGENT"
}

quit_app() {
    app_is_running || return 0
    say "› quitting $APP_NAME"
    osascript -e "quit app \"$APP_NAME\"" >/dev/null 2>&1 || true
    if ! wait_until_stopped; then
        pkill -f "^$APP_BINARY" >/dev/null 2>&1 || true
        wait_until_stopped || fail "could not quit $APP_NAME. Quit it by hand and run this script again."
    fi
}

remove_app() {
    if [[ -d "$APP_PATH" ]]; then
        say "› removing $APP_PATH"
        rm -rf "$APP_PATH" || fail "could not remove $APP_PATH. Move it to the Trash by hand."
    else
        say "$APP_PATH is not installed."
    fi
}

ask_yes_no() {
    case "$data_choice" in
        delete) return 0 ;;
        keep) return 1 ;;
    esac
    [[ -t 0 ]] || return 1
    local reply=""
    read -r -p "$1 [y/N] " reply || true
    [[ "$reply" == [yY] || "$reply" == [yY][eE][sS] ]]
}

remove_folder() {
    local folder="$1" description="$2"
    [[ -d "$folder" ]] || return 0
    if ask_yes_no "Delete $description ($folder)?"; then
        rm -rf "$folder"
        say "✓ deleted $folder"
    else
        say "kept $folder"
    fi
}

# Read before the data folder can be deleted: the original status line command lives in tap.json.
original_status_line_command() {
    [[ -f "$TAP_CONFIG" ]] || return 0
    plutil -extract command raw -o - "$TAP_CONFIG" 2>/dev/null || true
}

settings_use_the_tap() {
    [[ -f "$CLAUDE_SETTINGS" ]] || return 1
    local current
    current="$(plutil -extract statusLine.command raw -o - "$CLAUDE_SETTINGS" 2>/dev/null || true)"
    [[ "$current" == *aicontrolnotch-tap* ]]
}

print_status_line_reminder() {
    local original="$1"
    say ""
    say "Claude Code status line"
    say "-----------------------"
    say "The aicontrolnotch-tap wrapper lives in the data folder, so restore your own"
    say "status line in ~/.claude/settings.json (this script never edits that file)."
    if [[ -n "$original" ]]; then
        say "Your original command was:"
        say ""
        if command -v python3 >/dev/null 2>&1; then
            python3 -c 'import json,sys; print("  \"statusLine\": " + json.dumps({"type": "command", "command": sys.argv[1]}))' "$original"
        else
            say "  $original"
        fi
    else
        say "No original command was saved: remove the \"statusLine\" entry, or set your own."
    fi
    if [[ -e "$CLAUDE_SETTINGS.bak-aicontrolnotch" ]]; then
        say ""
        say "~/.claude/settings.json.bak-aicontrolnotch is a copy of your settings from before"
        say "Claude was connected. Delete it once your status line is back."
    fi
    say ""
}

main() {
    turn_off_login_item
    quit_app
    remove_app

    local original reminder=false
    original="$(original_status_line_command)"
    if [[ -n "$original" ]] || settings_use_the_tap; then reminder=true; fi
    if $reminder; then print_status_line_reminder "$original"; fi

    remove_folder "$SUPPORT_DIR" "the data folder (saved numbers, providers.json, status line wrapper)"
    remove_folder "$LOG_DIR" "the logs"

    say ""
    say "✓ $APP_NAME was uninstalled."
    if $reminder; then say "Remember to restore your Claude Code status line (see above)."; fi
}

main
