#!/usr/bin/env bash

set -Eeuo pipefail

echo "🚀 Booting Modular AI God-Mode..."

# ==========================================
# Basic paths
# ==========================================

export PATH="$HOME/.local/bin:$PATH"

# ==========================================
# Install Core Dependencies
# ==========================================

echo "📦 Installing core tools..."

# Remove previous Anthropic global package namespace
rm -rf "$(npm root -g)/@anthropic-ai" 2>/dev/null || true

# Install uv only when it is not already available
if ! command -v uv >/dev/null 2>&1; then
    echo "📥 Installing uv..."

    curl -LsSf https://astral.sh/uv/install.sh | sh

    export PATH="$HOME/.local/bin:$PATH"
fi

# Confirm uv exists
if ! command -v uv >/dev/null 2>&1; then
    echo "❌ uv installation failed."
    exit 1
fi

# Install Claude Code
echo "🤖 Installing Claude Code..."

npm install -g @anthropic-ai/claude-code

# ==========================================
# Install Python & AI Engine
# ==========================================

echo "⚙️ Installing AI engine..."

uv python install 3.14

uv tool install \
    --force \
    --python 3.14 \
    git+https://github.com/Alishahryar1/free-claude-code.git

# ==========================================
# Sync Claude Skills
# ==========================================

echo "🧠 Syncing Claude Skills..."

rm -rf "$HOME/.claude/skills"
mkdir -p "$HOME/.claude/skills"

TEMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

if git clone \
    --quiet \
    --depth 1 \
    https://github.com/Surya-git-enf/Claude-skills.git \
    "$TEMP_DIR"; then

    find "$TEMP_DIR" \
        -type f \
        -iname "*.md" \
        -exec cp {} "$HOME/.claude/skills/" \;

    echo "✅ Skills synced successfully"
else
    echo "⚠️ Failed to sync Claude skills; continuing..."
fi

# ==========================================
# Configure Environment
# ==========================================

export ANTHROPIC_AUTH_TOKEN="freecc"
export ANTHROPIC_BASE_URL="http://127.0.0.1:8082"

# Persist variables in .bashrc without duplicating them
grep -qxF 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc" || \
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"

grep -qx
