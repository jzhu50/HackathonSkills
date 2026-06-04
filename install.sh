#!/usr/bin/env bash
#
# hackathon-skills installer for macOS and Linux
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Victor-Casado/HackathonSkills/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/Victor-Casado/HackathonSkills/main/install.sh | bash -s -- --beta
#

set -euo pipefail

# -- Configuration ------------------------------------------------------------

REPO="Victor-Casado/HackathonSkills"
TOOL_NAME="hackathon-skills"
INSTALL_DIR="${HOME}/.local/bin"

# Define assets to download and their installation targets (source:target)
ASSETS=(
    "runner.sh:hackathon-skills"
    "make-claude-md.sh:hackathon-bootstrap"
)

# -- Colours ------------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Colour

# -- Arguments ----------------------------------------------------------------

BETA=false
TAG=""
BASE_URL=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --beta)
            BETA=true
            shift
            ;;
        --tag)
            TAG="$2"
            shift 2
            ;;
        --base-url)
            BASE_URL="$2"
            shift 2
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# -- Helpers ------------------------------------------------------------------

info() {
    echo -e "${CYAN}  $1${NC}"
}

success() {
    echo -e "${GREEN}  $1${NC}"
}

warn() {
    echo -e "${YELLOW}  $1${NC}"
}

error() {
    echo -e "${RED}error: $1${NC}" >&2
    exit 1
}

# Get latest release tag from GitHub API
get_latest_release() {
    if [[ -n "$BASE_URL" ]]; then
        echo "latest"
        return
    fi

    local url="https://api.github.com/repos/${REPO}/releases"
    local auth_header=()
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        auth_header=(-H "Authorization: token ${GITHUB_TOKEN}")
    fi

    if [[ "$BETA" == "true" ]]; then
        # Get latest release including pre-releases
        curl -fsSL "${auth_header[@]}" "$url" | grep '"tag_name":' | head -1 | sed -E 's/.*"([^"]+)".*/\1/'
    else
        # Get latest stable release only
        curl -fsSL "${auth_header[@]}" "${url}/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'
    fi
}

download_file() {
    local asset_name="$1"
    local dest="$2"

    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        # 1. Fetch release JSON to get asset ID
        local api_url="https://api.github.com/repos/${REPO}/releases/tags/${version}"
        local release_json
        if ! release_json=$(curl -fsSL -u :"$GITHUB_TOKEN" "$api_url"); then
            echo "Error: Failed to fetch release info from API for tag ${version}" >&2
            return 1
        fi

        # 2. Extract asset ID using awk
        local asset_id
        asset_id=$(echo "$release_json" | awk -v name="$asset_name" '
          /^[[:space:]]*"name":/ {
            gsub(/[",[:space:]]/, "", $2)
            curr_name = $2
          }
          /^[[:space:]]*"id":/ {
            gsub(/[",[:space:]]/, "", $2)
            curr_id = $2
          }
          /^[[:space:]]*\}/ {
            if (curr_name == name) {
              print curr_id
              exit
            }
          }
        ')

        if [[ -z "$asset_id" ]]; then
            echo "Error: Asset ID for $asset_name not found in release info" >&2
            return 1
        fi

        # 3. Download via API
        local download_url="https://api.github.com/repos/${REPO}/releases/assets/${asset_id}"
        if ! curl -fsSL -H "Accept: application/octet-stream" -u :"$GITHUB_TOKEN" -o "$dest" "$download_url"; then
            echo "Error: Failed to download ${asset_name} via API" >&2
            return 1
        fi
    else
        # Public download fallback
        local download_url
        if [[ -n "${BASE_URL:-}" ]]; then
            download_url="${BASE_URL}/${asset_name}"
        else
            download_url="https://github.com/${REPO}/releases/download/${version}/${asset_name}"
        fi
        if ! curl -fsSL -o "$dest" "$download_url"; then
            echo "Error: Failed to download ${asset_name}" >&2
            return 1
        fi
    fi
}



# Global temp dir for cleanup trap
TEMP_DIR=""

cleanup() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

# -- Installation -------------------------------------------------------------

main() {
    echo ""
    echo -e "${CYAN}${TOOL_NAME} installer${NC}"
    echo -e "${CYAN}========================${NC}"
    echo ""
    
    local version="$TAG"
    if [[ -z "$version" ]]; then
        info "Fetching latest release tag..."
        version="$(get_latest_release)"
    fi

    if [[ -z "$version" ]]; then
        error "Could not determine version"
    fi
    
    info "Version: ${version}"
    if [[ "$BETA" == "true" ]]; then
        info "Channel: beta"
    fi
    echo ""

    TEMP_DIR="$(mktemp -d)"
    
    # Optional: Download checksums
    local has_checksums=false
    if download_file "checksums.sha256" "${TEMP_DIR}/checksums.sha256" 2>/dev/null; then
        has_checksums=true
        info "Checksums available for verification."
    else
        warn "Note: No checksums found for this release, skipping verification."
    fi

    mkdir -p "$INSTALL_DIR"

    for asset_pair in "${ASSETS[@]}"; do
        local target_path="${INSTALL_DIR}/${target_name}"

        info "Downloading ${asset_name}..."
        if ! download_file "$asset_name" "${TEMP_DIR}/${asset_name}"; then
            error "Failed to download ${asset_name}"
        fi

        # Verify checksum if available
        if [[ "$has_checksums" == "true" ]]; then
            info "Verifying checksum for ${asset_name}..."
            local expected_hash
            expected_hash=$(awk -v file="$asset_name" '{name=$2; sub(/^\*/, "", name)} name == file {print tolower($1); exit}' "${TEMP_DIR}/checksums.sha256" || true)
            
            if [[ -n "$expected_hash" ]]; then
                local actual_hash=""
                if command -v sha256sum &> /dev/null; then
                    actual_hash=$(sha256sum "${TEMP_DIR}/${asset_name}" | awk '{print $1}' | tr '[:upper:]' '[:lower:]')
                elif command -v shasum &> /dev/null; then
                    actual_hash=$(shasum -a 256 "${TEMP_DIR}/${asset_name}" | awk '{print $1}' | tr '[:upper:]' '[:lower:]')
                fi

                if [[ -n "$actual_hash" ]]; then
                    if [[ "$expected_hash" != "$actual_hash" ]]; then
                        error "Checksum verification failed for ${asset_name}!\nExpected: ${expected_hash}\nActual: ${actual_hash}"
                    fi
                    success "Checksum verified."
                else
                    warn "No checksum utility found, skipping verification"
                fi
            else
                warn "No hash found for ${asset_name} in checksums file."
            fi
        fi

        mv "${TEMP_DIR}/${asset_name}" "$target_path"
        chmod +x "$target_path"
        success "Installed: ${target_path}"
    done
    
    echo ""
    success "✓ ${TOOL_NAME} ${version} installed successfully!"
    
    # Check if install directory is in PATH
    if [[ ":$PATH:" != *":${INSTALL_DIR}:"* ]]; then
        echo ""
        warn "Note: ${INSTALL_DIR} is not in your PATH"
        echo ""
        echo "Add it to your shell configuration:"
        
        local shell_name
        shell_name="$(basename "$SHELL")"
        
        case "$shell_name" in
            bash)
                echo "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
                echo "  source ~/.bashrc"
                ;;
            zsh)
                echo "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc"
                echo "  source ~/.zshrc"
                ;;
            fish)
                echo "  fish_add_path ~/.local/bin"
                ;;
            *)
                echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
                ;;
        esac
    fi

    echo ""
    echo ""

    # Auto-bootstrap if running inside a git repo
    if git rev-parse --git-dir > /dev/null 2>&1; then
        echo "Git repo detected - running bootstrap..."
        "$INSTALL_DIR/hackathon-bootstrap"
    else
        echo "Get started:"
        echo "  hackathon-bootstrap           # generates CLAUDE.md + slash commands"
        echo "  hackathon-skills --help       # Show all commands (Claude, Aider, Codex, Antigravity)"
        echo ""
    fi
}

main "$@"
