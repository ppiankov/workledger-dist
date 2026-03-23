# workledger-dist

Distribution package for [workledger](https://hiveram.com) — structured work order storage for AI agent workflows.

## What this is

Pre-built binaries, essential skills, and an install script that bootstraps any workstation with a working workledger setup: binary on PATH, MCP server configured for Claude Code, HTTP API access, and cross-machine memory sync.

## What this is NOT

- Not the source code — that lives in a private repo
- Not a framework or SDK — this is an installer
- Not a replacement for reading the docs at [hiveram.com](https://hiveram.com)

## Quick install

```bash
curl -fsSL https://raw.githubusercontent.com/ppiankov/workledger-dist/main/install.sh | bash
```

This will:
1. Download the workledger binary for your platform
2. Install 5 essential Claude Code skills
3. Configure the MCP server in Claude Code settings
4. Prompt for your Neon DSN and API key
5. Verify everything works

## Manual install

If you prefer not to pipe to bash:

```bash
# 1. Download the tarball for your platform
# macOS Apple Silicon
curl -LO https://github.com/ppiankov/workledger-dist/releases/download/v0.7.7/workledger_0.7.7_darwin_arm64.tar.gz

# macOS Intel
curl -LO https://github.com/ppiankov/workledger-dist/releases/download/v0.7.7/workledger_0.7.7_darwin_amd64.tar.gz

# Linux amd64
curl -LO https://github.com/ppiankov/workledger-dist/releases/download/v0.7.7/workledger_0.7.7_linux_amd64.tar.gz

# 2. Verify checksum
sha256sum -c checksums.txt

# 3. Extract and install
tar -xzf workledger_*.tar.gz
sudo mv workledger /usr/local/bin/
chmod +x /usr/local/bin/workledger

# 4. Copy skills
for skill in workledger write-wo load-context wrapup save-memory; do
    mkdir -p ~/.claude/skills/$skill
    curl -fsSL -o ~/.claude/skills/$skill/SKILL.md \
        "https://raw.githubusercontent.com/ppiankov/workledger-dist/main/skills/$skill/SKILL.md"
done

# 5. Configure secrets
mkdir -p ~/.workledger
cat > ~/.workledger/api-key.env << 'EOF'
export WORKLEDGER_DSN='postgresql://...'
export WORKLEDGER_API_KEY='wl_...'
EOF
chmod 600 ~/.workledger/api-key.env
echo '[ -f ~/.workledger/api-key.env ] && source ~/.workledger/api-key.env' >> ~/.zshrc
```

## Included skills

| Skill | Command | What it does |
|-------|---------|--------------|
| workledger | `/workledger` | Query, create, update work orders |
| write-wo | `/write-wo` | Create work orders from feature briefs |
| load-context | `/load-context` | Pull memory and WOs at session start |
| wrapup | `/wrapup` | Push memory, mark WOs done, commit |
| save-memory | `/save-memory` | Save and sync memory mid-session |

## Platforms

| OS | Architecture | Status |
|----|-------------|--------|
| macOS | Apple Silicon (arm64) | Supported |
| macOS | Intel (amd64) | Supported |
| Linux | amd64 | Supported |
| Linux | arm64 | Supported |

## Prerequisites

- [Claude Code](https://claude.ai/claude-code) installed
- A workledger account (Neon DSN + API key)

## Verify installation

After install, open a new terminal and run:

```bash
workledger version
```

Then start Claude Code in any project and run `/load-context` to verify the full stack.

## License

MIT
