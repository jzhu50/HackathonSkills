#!/usr/bin/env bash
# install.sh - hackathon-skills installer (macOS/Linux)
#
# Downloads runner.sh and make-claude-md.sh from the latest GitHub release:
#   ~/.local/bin/hackathon-skills      - PTY runner (launch your AI CLI)
#   ~/.local/bin/hackathon-bootstrap   - project bootstrapper (run once per project)
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Victor-Casado/HackathonSkills/main/install.sh | bash
#   # or locally:
#   ./install.sh

set -euo pipefail

REPO="Victor-Casado/HackathonSkills"
TOOL_NAME="hackathon-skills"
BOOTSTRAP_NAME="hackathon-bootstrap"
INSTALL_DIR="${HOME}/.local/bin"
INSTALL_PATH="${INSTALL_DIR}/${TOOL_NAME}"
BOOTSTRAP_PATH="${INSTALL_DIR}/${BOOTSTRAP_NAME}"

# -- helpers ------------------------------------------------------------------

_die() { printf 'error: %s\n' "$*" >&2; exit 1; }
_info() { printf '  %s\n' "$*"; }

# -- resolve latest release tag ------------------------------------------------

_latest_tag() {
  local url="https://api.github.com/repos/${REPO}/releases/latest"
  local auth_header=()
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    auth_header=(-H "Authorization: token ${GITHUB_TOKEN}")
  fi

  if command -v curl &>/dev/null; then
    curl -fsSL "${auth_header[@]}" "$url"\
      | grep '"tag_name"'\
      | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/'
  elif command -v wget &>/dev/null; then
    local wget_auth=()
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
      wget_auth=(--header="Authorization: token ${GITHUB_TOKEN}")
    fi
    wget -qO- "${wget_auth[@]}" "$url"\
      | grep '"tag_name"'\
      | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/'
  else
    _die "curl or wget is required to download releases"
  fi
}

# -- download ------------------------------------------------------------------

_download() {
  local url="$1"
  local dest="$2"
  local auth_header=()
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    auth_header=(-H "Authorization: token ${GITHUB_TOKEN}")
  fi

  if command -v curl &>/dev/null; then
    curl -fsSL "${auth_header[@]}" -o "$dest" "$url"
  else
    local wget_auth=()
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
      wget_auth=(--header="Authorization: token ${GITHUB_TOKEN}")
    fi
    wget -qO "$dest" "${wget_auth[@]}" "$url"
  fi
}

# -- PATH setup ----------------------------------------------------------------

_add_to_path() {
  local shell_rc=""
  case "${SHELL:-}" in
    */zsh)  shell_rc="${HOME}/.zshrc" ;;
    */fish) shell_rc="${HOME}/.config/fish/config.fish" ;;
    *)      shell_rc="${HOME}/.bashrc" ;;
  esac

  # shellcheck disable=SC2016  # intentional: literal string written to shell rc, expands at shell init
  local export_line='export PATH="${HOME}/.local/bin:${PATH}"'
  if [[ "$SHELL" == */fish ]]; then
    export_line='fish_add_path ~/.local/bin'
  fi

  if [[ -f "$shell_rc" ]] && grep -qF ".local/bin" "$shell_rc"; then
    _info "PATH already includes ~/.local/bin (${shell_rc})"
  else
    printf '\n# Added by hackathon-skills installer\n%s\n' "$export_line" >> "$shell_rc"
    _info "Added ~/.local/bin to PATH in ${shell_rc}"
    _info "Reload your shell or run:  source ${shell_rc}"
  fi
}

# -- install one script --------------------------------------------------------

_install_script() {
  local url="$1"
  local dest="$2"
  local label="$3"

  local tmp
  tmp=$(mktemp /tmp/hs-XXXXXX.sh)
  # shellcheck disable=SC2064  # intentional: expand $tmp now to capture current value
  trap "rm -f '$tmp'" RETURN

  _download "$url" "$tmp"
  chmod +x "$tmp"

  head -1 "$tmp" | grep -q 'bash\|sh'\
    || _die "downloaded ${label} does not look like a shell script"

  mv "$tmp" "$dest"
  chmod +x "$dest"
  _info "installed: ${dest}"
}

# -- main ----------------------------------------------------------------------

printf '\nhackathon-skills installer\n'
printf '==========================\n\n'

TAG="${1:-}"
if [[ -z "$TAG" ]]; then
  printf 'Fetching latest release tag...\n'
  TAG=$(_latest_tag)
  [[ -n "$TAG" ]] || _die "could not determine latest release tag"
fi
_info "version: ${TAG}"
printf '\n'

mkdir -p "$INSTALL_DIR"

BASE_URL="https://github.com/${REPO}/releases/download/${TAG}"

printf 'Downloading...\n'
_install_script "${BASE_URL}/runner.sh"         "$INSTALL_PATH"   "runner.sh"
_install_script "${BASE_URL}/make-claude-md.sh" "$BOOTSTRAP_PATH" "make-claude-md.sh"

printf '\n'

# Ensure ~/.local/bin is on PATH
if ! printf '%s' "$PATH" | tr ':' '\n' | grep -qxF "$INSTALL_DIR"; then
  _add_to_path
fi

printf 'Done.\n\n'
printf 'Next steps:\n'
printf '  1. Create a new repo from the template on GitHub\n'
printf '  2. Clone it, cd into it\n'
printf '  3. hackathon-bootstrap        - generates CLAUDE.md + slash commands\n'
printf '  4. Fill in PLAN.md\n'
printf '  5. Open Claude Code and run /hackathon-setup\n\n'
printf 'Other commands:\n'
printf '  hackathon-skills --help       - PTY runner help\n'
printf '  hackathon-skills --reconfigure - change AI CLI selection\n\n'
