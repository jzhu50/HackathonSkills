#!/usr/bin/env bash
# install.sh — hackathon-skills installer (macOS/Linux)
#
# Downloads runner.sh from the latest GitHub release, installs it as
#   ~/.local/bin/hackathon-skills
# and ensures ~/.local/bin is on PATH.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Victor-Casado/HackathonSkills/main/install.sh | bash
#   # or locally:
#   ./install.sh

set -euo pipefail

REPO="Victor-Casado/HackathonSkills"
TOOL_NAME="hackathon-skills"
INSTALL_DIR="${HOME}/.local/bin"
INSTALL_PATH="${INSTALL_DIR}/${TOOL_NAME}"

# ── helpers ──────────────────────────────────────────────────────────────────

_die() { printf 'error: %s\n' "$*" >&2; exit 1; }
_info() { printf '  %s\n' "$*"; }

_require() {
  command -v "$1" &>/dev/null || _die "$1 is required but not found in PATH"
}

# ── resolve latest release tag ────────────────────────────────────────────────

_latest_tag() {
  local url="https://api.github.com/repos/${REPO}/releases/latest"
  if command -v curl &>/dev/null; then
    curl -fsSL "$url" \
      | grep '"tag_name"' \
      | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/'
  elif command -v wget &>/dev/null; then
    wget -qO- "$url" \
      | grep '"tag_name"' \
      | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/'
  else
    _die "curl or wget is required to download releases"
  fi
}

# ── download ──────────────────────────────────────────────────────────────────

_download() {
  local url="$1"
  local dest="$2"
  if command -v curl &>/dev/null; then
    curl -fsSL -o "$dest" "$url"
  else
    wget -qO "$dest" "$url"
  fi
}

# ── PATH setup ────────────────────────────────────────────────────────────────

_add_to_path() {
  local shell_rc=""
  case "${SHELL:-}" in
    */zsh)  shell_rc="${HOME}/.zshrc" ;;
    */fish) shell_rc="${HOME}/.config/fish/config.fish" ;;
    *)      shell_rc="${HOME}/.bashrc" ;;
  esac

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

# ── main ──────────────────────────────────────────────────────────────────────

printf '\nhackathon-skills installer\n'
printf '==========================\n\n'

TAG="${1:-}"
if [[ -z "$TAG" ]]; then
  printf 'Fetching latest release tag...\n'
  TAG=$(_latest_tag)
  [[ -n "$TAG" ]] || _die "could not determine latest release tag"
fi
_info "version: ${TAG}"

DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${TAG}/runner.sh"
_info "source:  ${DOWNLOAD_URL}"
_info "target:  ${INSTALL_PATH}"
printf '\n'

mkdir -p "$INSTALL_DIR"

TMP=$(mktemp /tmp/hs-runner-XXXXXX.sh)
trap "rm -f '$TMP'" EXIT

printf 'Downloading...\n'
_download "$DOWNLOAD_URL" "$TMP"
chmod +x "$TMP"

# Basic sanity check: verify it's a shell script
head -1 "$TMP" | grep -q 'bash\|sh' \
  || _die "downloaded file does not look like a shell script"

mv "$TMP" "$INSTALL_PATH"
chmod +x "$INSTALL_PATH"
printf 'Installed: %s\n\n' "$INSTALL_PATH"

# Ensure ~/.local/bin is on PATH
if ! printf '%s' "$PATH" | tr ':' '\n' | grep -qxF "$INSTALL_DIR"; then
  _add_to_path
fi

printf 'Done.\n\n'
printf 'Run:  hackathon-skills --help\n'
printf '      hackathon-skills            # launches configured AI CLI in PTY\n'
printf '      hackathon-skills --reconfigure  # change AI CLI selection\n\n'
printf 'Note: a GitHub release with runner.sh as an asset must exist for this\n'
printf '      installer to work end-to-end.  See the repo README for details.\n\n'
