#!/usr/bin/env bash
# runner.sh — hackathon-skills PTY runner (macOS/Linux)
#
# Spawns the configured AI CLI in a fresh pseudo-terminal for each task.
# Terminal geometry is set via TIOCSWINSZ so the child sees the real size.
#
# Usage:
#   ./runner.sh [--cli <name>] [--reconfigure] [args passed to AI CLI...]
#
# On first run, scans PATH for claude/aider/codex and writes the choice to
#   ~/.config/hackathon-skills/config.json
# Subsequent runs load that config.  Use --reconfigure to re-detect.
#
# Each invocation kills any previously tracked session (PID file) before
# spawning a new one — fresh context per task, state lives in files/GitHub.

set -euo pipefail

TOOL_NAME="hackathon-skills"
CONFIG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/${TOOL_NAME}"
CONFIG_FILE="${CONFIG_DIR}/config.json"
PID_FILE="${TMPDIR:-/tmp}/${TOOL_NAME}.pid"

# ── helpers ──────────────────────────────────────────────────────────────────

_die() { printf 'error: %s\n' "$*" >&2; exit 1; }

_require_python3() {
  command -v python3 &>/dev/null \
    || _die "python3 is required for PTY support (brew install python / apt install python3)"
}

# ── first-run AI CLI detection ────────────────────────────────────────────────

_detect_clis() {
  local found=()
  for cli in claude aider codex; do
    command -v "$cli" &>/dev/null && found+=("$cli")
  done
  printf '%s\n' "${found[@]:-}"
}

_first_run_setup() {
  printf '%s: first run — scanning PATH for AI CLIs...\n' "$TOOL_NAME"

  local found=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && found+=("$line")
  done < <(_detect_clis)

  if [[ ${#found[@]} -eq 0 ]]; then
    printf '\nNo known AI CLIs found (claude, aider, codex).\n'
    printf 'Enter the command to use (e.g. my-ai-cli): '
    read -r custom
    [[ -z "$custom" ]] && _die "no AI CLI specified"
    found=("$custom")
  else
    printf '\nFound:\n'
    local i=1
    for cli in "${found[@]}"; do
      printf '  %d. %s\n' "$i" "$cli"
      ((i++))
    done
    printf '\nEnter numbers to select (space-separated), or press Enter to use all: '
    read -r selection
    if [[ -n "$selection" ]]; then
      local chosen=()
      for n in $selection; do
        [[ $n -ge 1 && $n -le ${#found[@]} ]] \
          || _die "invalid selection: $n"
        chosen+=("${found[$((n - 1))]}")
      done
      found=("${chosen[@]}")
    fi
  fi

  mkdir -p "$CONFIG_DIR"
  {
    printf '{\n  "cli": ['
    local sep=""
    for cli in "${found[@]}"; do
      printf '%s"%s"' "$sep" "$cli"
      sep=", "
    done
    printf ']\n}\n'
  } > "$CONFIG_FILE"

  printf '\nSaved: %s\n' "$CONFIG_FILE"
  printf '  cli: %s\n\n' "${found[*]}"
}

# ── process management ────────────────────────────────────────────────────────

_kill_existing_session() {
  [[ ! -f "$PID_FILE" ]] && return 0
  local pid
  pid=$(cat "$PID_FILE" 2>/dev/null) || return 0
  rm -f "$PID_FILE"
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    kill -TERM "$pid" 2>/dev/null || true
    sleep 0.3
    kill -KILL "$pid" 2>/dev/null || true
  fi
}

# ── PTY launch ───────────────────────────────────────────────────────────────
#
# Uses pty.openpty() + TIOCSWINSZ so the child process sees the real PTY
# geometry (220×50), not just environment variables.

_spawn_pty() {
  local ai_cli="$1"; shift
  _require_python3
  _kill_existing_session

  # Write runner PID so the next invocation can clean up this session
  echo "$$" > "$PID_FILE"
  trap 'rm -f "$PID_FILE"' EXIT

  # Inline Python: opens a real PTY, sets geometry, forks, relays I/O
  python3 - "$ai_cli" "$@" << 'PYEOF'
import fcntl, os, pty, select, struct, sys, termios, tty

COLS, ROWS = 220, 50

def main():
    args = sys.argv[1:]

    master, slave = pty.openpty()

    # Set actual PTY window size (TIOCSWINSZ) so child ioctl sees 220x50
    winsize = struct.pack("HHHH", ROWS, COLS, 0, 0)
    fcntl.ioctl(master, termios.TIOCSWINSZ, winsize)

    pid = os.fork()
    if pid == 0:                        # child
        os.close(master)
        os.setsid()
        fcntl.ioctl(slave, termios.TIOCSCTTY, 0)
        for fd in (0, 1, 2):
            os.dup2(slave, fd)
        if slave > 2:
            os.close(slave)
        os.environ.update({
            "TERM":    "xterm-256color",
            "COLUMNS": str(COLS),
            "ROWS":    str(ROWS),
        })
        os.execvp(args[0], args)
        os._exit(1)

    # parent — I/O relay
    os.close(slave)
    saved = None
    if sys.stdin.isatty():
        saved = termios.tcgetattr(sys.stdin.fileno())
        tty.setraw(sys.stdin.fileno())

    poll_fds = [master]
    if sys.stdin.isatty():
        poll_fds.append(sys.stdin.fileno())

    try:
        while True:
            try:
                r, _, _ = select.select(poll_fds, [], [])
            except (InterruptedError, OSError):
                break
            if master in r:
                try:
                    chunk = os.read(master, 4096)
                except OSError:
                    break
                if not chunk:
                    break
                sys.stdout.buffer.write(chunk)
                sys.stdout.buffer.flush()
            if sys.stdin.isatty() and sys.stdin.fileno() in r:
                try:
                    chunk = os.read(sys.stdin.fileno(), 4096)
                except OSError:
                    break
                if chunk:
                    os.write(master, chunk)
    finally:
        if saved:
            termios.tcsetattr(sys.stdin.fileno(), termios.TCSADRAIN, saved)
        try:
            os.close(master)
        except OSError:
            pass

    _, status = os.waitpid(pid, 0)
    code = os.waitstatus_to_exitcode(status) if hasattr(os, "waitstatus_to_exitcode") \
        else (status >> 8)
    sys.exit(code)

main()
PYEOF
}

# ── read config ───────────────────────────────────────────────────────────────

_primary_cli() {
  python3 - "$CONFIG_FILE" << 'PYEOF'
import json, sys
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
except (OSError, json.JSONDecodeError) as e:
    print(f"error: cannot read config: {e}", file=sys.stderr)
    sys.exit(1)
clis = data.get("cli", [])
if not clis:
    print("error: config 'cli' list is empty — run with --reconfigure", file=sys.stderr)
    sys.exit(1)
print(clis[0])
PYEOF
}

# ── main ──────────────────────────────────────────────────────────────────────

RECONFIGURE=false
OVERRIDE_CLI=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --reconfigure)   RECONFIGURE=true; shift ;;
    --cli)           OVERRIDE_CLI="${2:?--cli requires a value}"; shift 2 ;;
    --help|-h)
      cat <<EOF
Usage: hackathon-skills [--cli <name>] [--reconfigure] [args...]

  Spawns the configured AI CLI in a fresh PTY (TERM=xterm-256color,
  COLUMNS=220, ROWS=50) and kills any previous session first.

  --cli <name>    override the configured AI CLI for this invocation
  --reconfigure   re-run AI CLI detection and update config

  Config: ${CONFIG_FILE}
EOF
      exit 0
      ;;
    *) break ;;
  esac
done

if [[ -n "$OVERRIDE_CLI" ]]; then
  # Direct override - skip config detection for this run
  AI_CLI="$OVERRIDE_CLI"
else
  if [[ "$RECONFIGURE" == true || ! -f "$CONFIG_FILE" ]]; then
    _first_run_setup
  fi
  AI_CLI=$(_primary_cli)
fi

_spawn_pty "$AI_CLI" "$@"
