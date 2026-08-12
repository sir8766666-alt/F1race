#!/bin/bash

set -e

echo "🚀 Booting Modular AI God-Mode..."

# ==========================================
# Core Dependencies
# ==========================================
echo "📦 Installing core tools..."

rm -rf "$(npm root -g)/@anthropic-ai" 2>/dev/null || true

curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"

npm install -g @anthropic-ai/claude-code

# ==========================================
# Python & AI Engine
# ==========================================
echo "⚙️ Installing AI engine..."

uv python install 3.14

uv tool install --force --python 3.14 \
  git+https://github.com/Alishahryar1/free-claude-code.git

# ==========================================
# Sync Claude Skills
# ==========================================
echo "🧠 Syncing Claude Skills..."

rm -rf ~/.claude/skills
mkdir -p ~/.claude/skills

TEMP_DIR="$(mktemp -d)"

if git clone --quiet --depth 1 \
  https://github.com/Surya-git-enf/Claude-skills.git \
  "$TEMP_DIR"; then

    find "$TEMP_DIR" \
      -type f \
      -iname "*.md" \
      -exec cp {} ~/.claude/skills/ \;

    echo "✅ Skills synced successfully"
else
    echo "❌ Failed to sync skills"
fi

rm -rf "$TEMP_DIR"

# ==========================================
# Configure Environment
# ==========================================
export PATH="$HOME/.local/bin:$PATH"
export ANTHROPIC_AUTH_TOKEN="freecc"
export ANTHROPIC_BASE_URL="http://127.0.0.1:8082"

grep -qxF 'export PATH="$HOME/.local/bin:$PATH"' ~/.bashrc || \
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

grep -qxF 'export ANTHROPIC_AUTH_TOKEN="freecc"' ~/.bashrc || \
echo 'export ANTHROPIC_AUTH_TOKEN="freecc"' >> ~/.bashrc

grep -qxF 'export ANTHROPIC_BASE_URL="http://127.0.0.1:8082"' ~/.bashrc || \
echo 'export ANTHROPIC_BASE_URL="http://127.0.0.1:8082"' >> ~/.bashrc

# ==========================================
# Load Local Environment
# ==========================================
if [ -f .env ]; then
    echo "📂 Loading .env variables..."

    set -a
    source .env
    set +a
fi

if [ ! -f .env.example ]; then
    if [ -f .env ]; then
        cp .env .env.example
    else
        touch .env.example
    fi
fi

# ==========================================
# Prepare HoodAI Claude Hooks
# ==========================================
echo "🧩 Preparing HoodAI Claude hooks..."

HOODAI_ROOT="/workspaces/HoodAI"
HOODAI_HOOK="$HOODAI_ROOT/.claude/hooks/hoodai-state.sh"

mkdir -p "$HOODAI_ROOT/.claude/hooks"

if [ ! -f "$HOODAI_HOOK" ]; then
    echo "❌ HoodAI hook not found:"
    echo "$HOODAI_HOOK"
    exit 1
fi

chmod +x "$HOODAI_HOOK"

echo "✅ HoodAI hook ready"

# ==========================================
# Reset HoodAI State
# ==========================================
echo "🧹 Resetting HoodAI Claude state..."

mkdir -p /tmp/hoodai

cat > /tmp/hoodai/claude-state.json <<'EOF'
{
  "state": "idle",
  "assistant": "Claude Code",
  "sessionId": "startup",
  "updatedAt": ""
}
EOF

# ==========================================
# Restart Proxy
# ==========================================
echo "⚡ Starting proxy..."

pkill -f fcc-server 2>/dev/null || true

"$HOME/.local/bin/fcc-server" > proxy.log 2>&1 &

PROXY_PID=$!

echo "⏳ Waiting for proxy..."

sleep 5

# ==========================================
# Health Check
# ==========================================
if curl -fsS http://127.0.0.1:8082 >/dev/null 2>&1; then
    echo "✅ Proxy server running on port 8082"
else
    echo "❌ Proxy startup failed"

    if [ -f proxy.log ]; then
        echo "----- proxy.log -----"
        cat proxy.log
        echo "---------------------"
    fi

    kill "$PROXY_PID" 2>/dev/null || true
    exit 1
fi

# ==========================================
# Launch Claude
# ==========================================
echo "🚀 Launching Claude Code..."
echo "🧠 HoodAI Claude hooks are enabled."

if command -v claude >/dev/null 2>&1; then
    CLAUDE_BIN="$(command -v claude)"
else
    CLAUDE_BIN=""
fi

if [ -n "$CLAUDE_BIN" ]; then
    chmod +x "$CLAUDE_BIN" 2>/dev/null || true
fi

# Use one Claude process only.
# The previous script launched npx Claude and then
# tried to launch `claude` again after it exited.
exec npx -y @anthropic-ai/claude-code \
    --continue \
    --dangerously-skip-permissions
