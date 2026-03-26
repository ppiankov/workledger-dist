#!/usr/bin/env bash
set -euo pipefail

# hiveram installer
# Usage: curl -fsSL https://raw.githubusercontent.com/ppiankov/hiveram-dist/main/install.sh | bash

REPO="ppiankov/hiveram-dist"
BINARY_NAME="workledger"
INSTALL_DIR="${WORKLEDGER_INSTALL_DIR:-/usr/local/bin}"
SKILLS_DIR="$HOME/.claude/skills"
CONFIG_DIR="$HOME/.workledger"

# --- helpers ---

info()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33mwarning:\033[0m %s\n' "$*"; }
error() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

detect_platform() {
    local os arch
    os="$(uname -s | tr '[:upper:]' '[:lower:]')"
    arch="$(uname -m)"

    case "$os" in
        darwin) os="darwin" ;;
        linux)  os="linux"  ;;
        *)      error "Unsupported OS: $os" ;;
    esac

    case "$arch" in
        x86_64|amd64)  arch="amd64" ;;
        arm64|aarch64) arch="arm64" ;;
        *)             error "Unsupported architecture: $arch" ;;
    esac

    echo "${os}_${arch}"
}

latest_version() {
    local version
    version=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null \
        | grep '"tag_name"' | sed 's/.*"v\(.*\)".*/\1/' || true)
    if [ -z "$version" ]; then
        error "Could not determine latest version. Check https://github.com/${REPO}/releases"
    fi
    echo "$version"
}

# --- phase 1: binary ---

install_binary() {
    info "Installing workledger binary"

    local platform version tarball url tmpdir
    platform="$(detect_platform)"
    version="$(latest_version)"
    tarball="${BINARY_NAME}_${version}_${platform}.tar.gz"
    url="https://github.com/${REPO}/releases/download/v${version}/${tarball}"
    tmpdir="$(mktemp -d)"

    info "Downloading ${BINARY_NAME} v${version} for ${platform}"
    curl -fsSL -o "${tmpdir}/${tarball}" "$url" \
        || error "Download failed. Check ${url}"

    info "Extracting to ${INSTALL_DIR}"
    tar -xzf "${tmpdir}/${tarball}" -C "$tmpdir"

    if [ -w "$INSTALL_DIR" ]; then
        mv "${tmpdir}/${BINARY_NAME}" "${INSTALL_DIR}/${BINARY_NAME}"
    else
        info "Need sudo to install to ${INSTALL_DIR}"
        sudo mv "${tmpdir}/${BINARY_NAME}" "${INSTALL_DIR}/${BINARY_NAME}"
    fi
    chmod +x "${INSTALL_DIR}/${BINARY_NAME}"

    rm -rf "$tmpdir"
    info "Installed ${INSTALL_DIR}/${BINARY_NAME} (v${version})"
}

# --- phase 2: skills ---

install_skills() {
    info "Installing skills to ${SKILLS_DIR}"

    local tmpdir skills
    tmpdir="$(mktemp -d)"
    skills=("workledger" "write-wo" "load-context" "wrapup" "save-memory")

    for skill in "${skills[@]}"; do
        local url="https://raw.githubusercontent.com/${REPO}/main/skills/${skill}/SKILL.md"
        mkdir -p "${SKILLS_DIR}/${skill}"
        local attempt
        for attempt in 1 2 3; do
            if curl -fsSL -o "${SKILLS_DIR}/${skill}/SKILL.md" "$url" 2>/dev/null; then
                break
            fi
            [ "$attempt" -lt 3 ] && sleep 2
        done
        [ -f "${SKILLS_DIR}/${skill}/SKILL.md" ] || warn "Failed to download skill: ${skill}"
        info "  ${skill}"
    done

    rm -rf "$tmpdir"
    info "Installed ${#skills[@]} skills"
}

# --- phase 3: MCP config ---

configure_mcp() {
    info "Configuring MCP server for Claude Code"

    local settings="$HOME/.claude/settings.json"
    mkdir -p "$(dirname "$settings")"

    if [ ! -f "$settings" ]; then
        echo '{}' > "$settings"
    fi

    # Check if workledger MCP is already configured
    if grep -q '"workledger"' "$settings" 2>/dev/null; then
        info "MCP already configured in ${settings}"
        return
    fi

    # Use python3 (available on macOS) to safely merge JSON
    python3 -c "
import json, sys

path = '$settings'
with open(path) as f:
    cfg = json.load(f)

cfg.setdefault('mcpServers', {})
cfg['mcpServers']['workledger'] = {
    'command': '${INSTALL_DIR}/${BINARY_NAME}',
    'args': ['serve', '--mcp']
}

with open(path, 'w') as f:
    json.dump(cfg, f, indent=2)
    f.write('\n')
" || warn "Could not auto-configure MCP. Add manually to ${settings}"

    info "MCP server added to ${settings}"
}

# --- phase 4: secrets ---

configure_secrets() {
    info "Configuring secrets"
    mkdir -p "$CONFIG_DIR"

    local env_file="${CONFIG_DIR}/api-key.env"

    if [ -f "$env_file" ]; then
        info "Secrets file already exists at ${env_file}"
        # shellcheck disable=SC1090
        source "$env_file"
    fi

    # When piped via curl|bash, stdin is the script itself.
    # Read user input from /dev/tty instead.
    if [ ! -t 0 ] && [ -e /dev/tty ]; then
        local input="/dev/tty"
    else
        local input="/dev/stdin"
    fi

    # Connection mode: URL (recommended) or DSN (advanced)
    if [ -z "${WORKLEDGER_URL:-}" ] && [ -z "${WORKLEDGER_DSN:-}" ]; then
        echo ""
        echo "How will you connect to workledger?"
        echo "  1) HTTP API (recommended) -- needs URL + API key"
        echo "  2) Direct database -- needs PostgreSQL DSN"
        echo "  3) Local only -- SQLite, no remote connection"
        printf "Choice [1]: "
        read -r mode < "$input" || mode=""
        mode="${mode:-1}"

        case "$mode" in
            1)
                echo ""
                echo "Enter your workledger server URL (WORKLEDGER_URL)."
                echo "Example: https://wl-yourorg-prod.fly.dev"
                printf "URL: "
                read -r wl_url < "$input" || wl_url=""
                if [ -n "$wl_url" ]; then
                    echo "export WORKLEDGER_URL='${wl_url}'" >> "$env_file"
                else
                    warn "Skipped URL -- workledger will use local SQLite"
                fi

                echo ""
                echo "Enter your workledger API key (WORKLEDGER_API_KEY)."
                printf "API key: "
                read -r apikey < "$input" || apikey=""
                if [ -n "$apikey" ]; then
                    echo "export WORKLEDGER_API_KEY='${apikey}'" >> "$env_file"
                else
                    warn "Skipped API key -- requests will be unauthenticated"
                fi
                ;;
            2)
                echo ""
                echo "Enter your Neon PostgreSQL connection string (WORKLEDGER_DSN)."
                echo "Format: postgresql://user:pass@host/dbname?sslmode=require"
                printf "DSN: "
                read -r dsn < "$input" || dsn=""
                if [ -n "$dsn" ]; then
                    echo "export WORKLEDGER_DSN='${dsn}'" >> "$env_file"
                else
                    warn "Skipped DSN -- workledger will use local SQLite"
                fi
                ;;
            3)
                info "Using local SQLite -- no remote connection"
                ;;
            *)
                warn "Invalid choice -- defaulting to local SQLite"
                ;;
        esac
    else
        [ -n "${WORKLEDGER_URL:-}" ] && info "WORKLEDGER_URL already set"
        [ -n "${WORKLEDGER_DSN:-}" ] && info "WORKLEDGER_DSN already set"
    fi

    chmod 600 "$env_file"

    # Add to shell profile if not already there
    local profile
    if [ -f "$HOME/.zshrc" ]; then
        profile="$HOME/.zshrc"
    elif [ -f "$HOME/.bashrc" ]; then
        profile="$HOME/.bashrc"
    elif [ -f "$HOME/.bash_profile" ]; then
        profile="$HOME/.bash_profile"
    else
        profile=""
    fi

    if [ -n "$profile" ]; then
        local source_line='[ -f ~/.workledger/api-key.env ] && source ~/.workledger/api-key.env'
        if ! grep -qF "$source_line" "$profile" 2>/dev/null; then
            echo "" >> "$profile"
            echo "# workledger" >> "$profile"
            echo "$source_line" >> "$profile"
            info "Added source line to ${profile}"
        fi
    else
        warn "No shell profile found. Add manually: source ~/.workledger/api-key.env"
    fi
}

# --- phase 5: verify ---

verify() {
    info "Verifying installation"
    local ok=true

    # Binary
    if command -v "$BINARY_NAME" &>/dev/null; then
        info "  binary: $($BINARY_NAME version 2>/dev/null || echo 'ok')"
    else
        warn "  binary: not on PATH (installed to ${INSTALL_DIR}/${BINARY_NAME})"
        ok=false
    fi

    # Skills
    local count=0
    for skill in workledger write-wo load-context wrapup save-memory; do
        [ -f "${SKILLS_DIR}/${skill}/SKILL.md" ] && count=$((count + 1))
    done
    info "  skills: ${count}/5 installed"

    # MCP
    if grep -q '"workledger"' "$HOME/.claude/settings.json" 2>/dev/null; then
        info "  mcp: configured"
    else
        warn "  mcp: not configured"
        ok=false
    fi

    # Secrets
    if [ -f "${CONFIG_DIR}/api-key.env" ]; then
        # shellcheck disable=SC1091
        source "${CONFIG_DIR}/api-key.env" 2>/dev/null || true
        if [ -n "${WORKLEDGER_DSN:-}" ]; then
            info "  dsn: set"
        else
            warn "  dsn: not set (using local SQLite)"
        fi
        if [ -n "${WORKLEDGER_API_KEY:-}" ]; then
            info "  api key: set"
        else
            warn "  api key: not set (HTTP API unavailable)"
        fi
    else
        warn "  secrets: not configured"
        ok=false
    fi

    echo ""
    if $ok; then
        info "Installation complete. Open a new terminal or run: source ~/.workledger/api-key.env"
        info "Then start Claude Code and run /load-context to verify."
    else
        warn "Installation completed with warnings. Review the messages above."
    fi
}

# --- main ---

main() {
    echo ""
    echo "  hiveram installer"
    echo "  ================="
    echo ""

    install_binary
    echo ""
    install_skills
    echo ""
    configure_mcp
    echo ""
    configure_secrets
    echo ""
    verify
}

main "$@"
