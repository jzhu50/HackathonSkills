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
  local accept="${3:-application/vnd.github.v3.raw}"
  local auth_header=()
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    auth_header=(-H "Authorization: token ${GITHUB_TOKEN}")
  fi

  if command -v curl &>/dev/null; then
    curl -fsSL "${auth_header[@]}" -H "Accept: ${accept}" -o "$dest" "$url"
  else
    local wget_auth=()
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
      wget_auth=(--header="Authorization: token ${GITHUB_TOKEN}")
    fi
    wget -qO "$dest" "${wget_auth[@]}" --header="Accept: ${accept}" "$url"
  fi
}

# -- install one script --------------------------------------------------------

_install_script() {
  local tag="$1"
  local name="$2"
  local dest="$3"

  local tmp
  tmp=$(mktemp /tmp/hs-XXXXXX.sh)
  # shellcheck disable=SC2064  # intentional: expand $tmp now to capture current value
  trap "rm -f '$tmp'" RETURN

  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    # Private repo: find asset API URL
    local release_url="https://api.github.com/repos/${REPO}/releases/tags/${tag}"
    local asset_url
    asset_url=$(_download "$release_url" - "application/json" \
      | grep -C 10 "\"name\": \"${name}\"" \
      | grep "\"url\":" \
      | head -1 \
      | sed -E 's/.*"url": *"([^"]+)".*/\1/')

    [[ -n "$asset_url" ]] || _die "could not find asset ${name} in release ${tag}"
    _download "$asset_url" "$tmp" "application/octet-stream"
  else
    # Public repo: use standard download URL
    local url="https://github.com/${REPO}/releases/download/${tag}/${name}"
    _download "$url" "$tmp"
  fi

  chmod +x "$tmp"
  head -1 "$tmp" | grep -q 'bash\|sh'\
    || _die "downloaded ${name} does not look like a shell script"

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

printf 'Downloading...\n'
_install_script "$TAG" "runner.sh"         "$INSTALL_PATH"
_install_script "$TAG" "make-claude-md.sh" "$BOOTSTRAP_PATH"

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

exit 0
