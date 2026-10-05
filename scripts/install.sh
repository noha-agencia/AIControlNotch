#!/usr/bin/env bash
# Builds AIControlNotch from source and installs it in /Applications.
#
#   ./scripts/install.sh [--yes] [--no-login] [--help]
#
#   --yes       non-interactive: open AIControlNotch at login, without asking
#   --no-login  do not ask about (or turn on) opening at login
#
# Claude connects through the Claude Code status line: this script saves your current
# status line command in tap.json and prints what to change. It never edits
# ~/.claude/settings.json.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="AIControlNotch"
APP_PATH="/Applications/$APP_NAME.app"
APP_BINARY="$APP_PATH/Contents/MacOS/$APP_NAME"
SUPPORT_DIR="$HOME/Library/Application Support/AIControlNotch"
TAP_CONFIG="$SUPPORT_DIR/tap.json"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
MIN_MACOS_MAJOR=14
MIN_SWIFT_MAJOR=6
QUIT_WAIT_SECONDS=10

usage() {
    cat <<'EOF'
Usage: ./scripts/install.sh [--yes] [--no-login] [--help]

Builds AIControlNotch from source and installs it in /Applications.

  --yes       non-interactive: open AIControlNotch at login, without asking
  --no-login  do not ask about (or turn on) opening at login
  --help      show this help

Requirements: macOS 14 or newer, and Xcode 16+ or the Command Line Tools
(xcode-select --install) with a Swift 6 toolchain.
EOF
}

say() { printf '%s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
fail() { printf 'error: %s\n' "$*" >&2; exit 1; }

login_choice="ask"
for arg in "$@"; do
    case "$arg" in
        --yes) [[ "$login_choice" == "no" ]] && fail "--yes and --no-login cannot be combined."; login_choice="yes" ;;
        --no-login) [[ "$login_choice" == "yes" ]] && fail "--yes and --no-login cannot be combined."; login_choice="no" ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; exit 64 ;;
    esac
done

check_requirements() {
    [[ "$(uname -s)" == "Darwin" ]] || fail "AIControlNotch only runs on macOS."

    local macos_major
    macos_major="$(sw_vers -productVersion | cut -d. -f1)"
    (( macos_major >= MIN_MACOS_MAJOR )) || fail "macOS $MIN_MACOS_MAJOR or newer is required (this Mac has $(sw_vers -productVersion))."

    # /usr/bin/swift exists even without developer tools, so ask xcode-select too.
    if ! command -v swift >/dev/null 2>&1 || ! xcode-select -p >/dev/null 2>&1; then
        say "Swift was not found. Install the Command Line Tools and run this script again:"
        say ""
        say "    xcode-select --install"
        say ""
        say "(Xcode 16 or newer works too.)"
        exit 1
    fi

    local swift_version swift_pattern='Swift version ([0-9]+)'
    swift_version="$(swift --version 2>&1 || true)"
    if [[ "$swift_version" =~ $swift_pattern ]] && (( BASH_REMATCH[1] < MIN_SWIFT_MAJOR )); then
        fail "Swift $MIN_SWIFT_MAJOR or newer is required (found ${BASH_REMATCH[1]}). Update Xcode or the Command Line Tools."
    fi
}

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

quit_app() {
    say "› quitting the running $APP_NAME"
    osascript -e "quit app \"$APP_NAME\"" >/dev/null 2>&1 || true
    if ! wait_until_stopped; then
        pkill -f "^$APP_BINARY" >/dev/null 2>&1 || true
        wait_until_stopped || fail "could not quit $APP_NAME. Quit it by hand and run this script again."
    fi
}

install_app() {
    local was_running=false
    if app_is_running; then
        was_running=true
        quit_app
    fi
    if ! ./scripts/build-app.sh --install; then
        # Nothing was replaced: bring the previous version back.
        if $was_running && [[ -d "$APP_PATH" ]]; then open "$APP_PATH"; fi
        fail "the build failed. See the messages above."
    fi
}

wants_login_item() {
    case "$login_choice" in
        yes) return 0 ;;
        no) return 1 ;;
    esac
    [[ -t 0 ]] || return 1
    local reply=""
    read -r -p "Open $APP_NAME at login? [y/N] " reply || true
    [[ "$reply" == [yY] || "$reply" == [yY][eE][sS] ]]
}

enable_login_item() {
    if "$APP_BINARY" --launch-at-login on; then
        say "✓ $APP_NAME will open at login (change it any time from the notch's right-click menu)"
    else
        warn "could not turn on opening at login. Use the right-click menu on the notch instead."
    fi
}

# Prints the statusLine command of ~/.claude/settings.json, or nothing. Fails when the file is not JSON.
read_status_line_command() {
    if command -v python3 >/dev/null 2>&1; then
        python3 -c '
import json, sys
settings = json.load(open(sys.argv[1], encoding="utf-8"))
line = settings.get("statusLine") if isinstance(settings, dict) else None
command = line.get("command") if isinstance(line, dict) else None
print(command if isinstance(command, str) else "", end="")
' "$CLAUDE_SETTINGS" 2>/dev/null
    else
        plutil -extract statusLine.command raw -o - "$CLAUDE_SETTINGS" 2>/dev/null || true
    fi
}

saved_tap_command() {
    [[ -f "$TAP_CONFIG" ]] || return 0
    plutil -extract command raw -o - "$TAP_CONFIG" 2>/dev/null || true
}

# Written to a private temporary file first, so a failure never leaves an empty tap.json.
write_tap_config() {
    local command="$1" tmp
    (umask 077; mkdir -p "$SUPPORT_DIR")
    tmp="$(mktemp "$SUPPORT_DIR/.tap.json.XXXXXX")"
    if python3 -c 'import json,sys; json.dump({"command": sys.argv[1]}, sys.stdout)' "$command" > "$tmp"; then
        mv -f "$tmp" "$TAP_CONFIG"
    else
        rm -f "$tmp"
        fail "could not save tap.json."
    fi
}

is_blank() {
    [[ -z "${1//[[:space:]]/}" ]]
}

print_status_line_instructions() {
    cat <<'EOF'

Connect Claude
--------------
AIControlNotch never reads your Claude login. It shows the limits Claude Code
hands to its status line: a small wrapper saves them, then runs your own status
line command. If you use Claude Code in a terminal with a Claude plan, set this
in ~/.claude/settings.json (this script never edits that file):

  "statusLine": {"type": "command", "command": "\"$HOME/Library/Application Support/AIControlNotch/bin/aicontrolnotch-tap\""}

The status line command kept in tap.json, if any, keeps working through the
wrapper. Then use Claude Code once. Skip this if you do not use Claude Code.
EOF
}

setup_claude_status_line() {
    local current="" saved
    if [[ -f "$CLAUDE_SETTINGS" ]] && ! current="$(read_status_line_command)"; then
        say ""
        warn "~/.claude/settings.json could not be read as JSON, so tap.json was not saved."
        print_status_line_instructions
        return
    fi

    if [[ "$current" == *aicontrolnotch-tap* ]]; then
        say ""
        say "✓ Claude is connected: your Claude Code status line goes through aicontrolnotch-tap."
        return
    fi

    saved="$(saved_tap_command)"
    if is_blank "$current"; then
        say ""
        say "You have no Claude Code status line command, so there is nothing to wrap."
        if [[ -f "$TAP_CONFIG" ]]; then
            warn "tap.json holds a status line command you no longer use. Delete it before you connect Claude:"
            warn "  rm \"$TAP_CONFIG\""
        fi
    elif [[ "$current" == "$saved" ]]; then
        say ""
        say "✓ tap.json already holds your current status line command."
    elif command -v python3 >/dev/null 2>&1; then
        write_tap_config "$current"
        say ""
        say "✓ Saved your current status line command in tap.json."
    else
        warn "python3 was not found, so your status line command was not saved to tap.json."
        warn "Before you change settings.json, create $TAP_CONFIG by hand"
        warn "with {\"command\": \"<your status line command>\"} and chmod 600 it, or your status line goes blank."
    fi
    print_status_line_instructions
}

main() {
    check_requirements
    install_app

    if wants_login_item; then enable_login_item; fi

    say "› opening $APP_NAME"
    open "$APP_PATH"

    setup_claude_status_line

    say ""
    say "✓ $APP_NAME is installed. Hover the notch to open it, right-click it for the menu."
}

main
