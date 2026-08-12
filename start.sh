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

grep -qxF 'export ANTHROPIC_AUTH_TOKEN="freecc"' "$HOME/.bashrc" || \
    echo 'export ANTHROPIC_AUTH_TOKEN="freecc"' >> "$HOME/.bashrc"

grep -qxF 'export ANTHROPIC_BASE_URL="http://127.0.0.1:8082"' "$HOME/.bashrc" || \
    echo 'export ANTHROPIC_BASE_URL="http://127.0.0.1:8082"' >> "$HOME/.bashrc"

# ==========================================
# Load Local Environment Variables
# ==========================================

if [ -f ".env" ]; then
    echo "📂 Loading .env variables..."

    set -a
    # shellcheck disable=SC1091
    source ".env"
    set +a
fi

if [ ! -f ".env.example" ]; then
    if [ -f ".env" ]; then
        cp ".env" ".env.example"
    else
        touch ".env.example"
    fi
fi

# ==========================================
# Start / Restart Proxy
# ==========================================

echo "⚡ Starting proxy..."

# Only stop an existing fcc-server process.
# Do NOT use "pkill -f python" because it can kill
# unrelated Python processes in the Codespace.
if pgrep -f "$HOME/.local/bin/fcc-server" >/dev/null 2>&1; then
    pkill -f "$HOME/.local/bin/fcc-server" 2>/dev/null || true
    sleep 1
fi

# Remove old proxy log
: > proxy.log

"$HOME/.local/bin/fcc-server" > proxy.log 2>&1 &

PROXY_PID=$!

echo "⏳ Waiting for proxy..."

PROXY_READY=false

for _ in {1..15}; do
    if curl -s \
    --max-time 2 \
    http://127.0.0.1:8082 >/dev/null 2>&1; then

        PROXY_READY=true
        break
    fi

    if ! kill -0 "$PROXY_PID" 2>/dev/null; then
        break
    fi

    sleep 1
done

# ==========================================
# Proxy Health Check
# ==========================================

if [ "$PROXY_READY" = true ]; then
    echo "✅ Proxy server running on port 8082"
else
    echo "❌ Proxy startup failed"

    if [ -f "proxy.log" ]; then
        echo "----- proxy.log -----"
        cat proxy.log
        echo "---------------------"
    fi

    exit 1
fi

# ==========================================
# Launch Claude
# ==========================================

echo "🚀 Launching Claude..."

CLAUDE_BIN="$(command -v claude || true)"

if [ -n "$CLAUDE_BIN" ]; then
    chmod +x "$CLAUDE_BIN" 2>/dev/null || true
fi

# Launch exactly ONE Claude process.
# Do not add another "claude" command after this;
# exec replaces this shell with Claude Code.
exec npx -y @anthropic-ai/claude-code \
    --continue \
    --dangerously-skip-permissions
