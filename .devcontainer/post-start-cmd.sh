#!/bin/bash

# Update modelrelay to latest version on every container start
echo "[post-start-cmd.sh] Updating modelrelay..."
if command -v npm &>/dev/null && command -v modelrelay &>/dev/null; then
  # Get version from package.json (modelrelay --version starts the server, not suitable for CLI)
  GET_NPM_VERSION='console.log(require("/usr/local/lib/modelrelay/lib/node_modules/modelrelay/package.json").version)'
  BEFORE=$(node -e "$GET_NPM_VERSION" 2>/dev/null || echo "unknown")
  npm update -g modelrelay --quiet 2>/tmp/npm-modelrelay-update.log
  AFTER=$(node -e "$GET_NPM_VERSION" 2>/dev/null || echo "unknown")
  if [ "$BEFORE" != "$AFTER" ] && [ "$BEFORE" != "unknown" ]; then
    echo "  modelrelay updated (${BEFORE} → ${AFTER})"
  else
    echo "  already up to date (${AFTER})"
  fi
elif command -v modelrelay &>/dev/null; then
  echo "  npm not found, skipping update"
else
  echo "  modelrelay not installed, skipping update"
fi

echo "[post-start-cmd.sh] Checking modelrelay..."
if command -v modelrelay &>/dev/null; then
  if pgrep -f modelrelay > /dev/null; then
    echo "[post-start-cmd.sh] modelrelay is already running, skipping"
  else
    echo "[post-start-cmd.sh] Starting modelrelay in the background..."
    setsid /usr/local/bin/modelrelay >> /tmp/modelrelay.log 2>&1 &
  fi
else
  echo "[post-start-cmd.sh] modelrelay not found, skipping start"
fi

# Update hermes-agent to latest version on every container start
echo "[post-start-cmd.sh] Updating hermes-agent..."
if command -v hermes &>/dev/null && [ -d "$HOME/.hermes/hermes-agent/.git" ]; then
  cd "$HOME/.hermes/hermes-agent"
  BEFORE=$(git rev-parse HEAD 2>/dev/null)
  git pull --ff-only origin main 2>/dev/null || echo "  already up to date"
  AFTER=$(git rev-parse HEAD 2>/dev/null)
  if [ "$BEFORE" != "$AFTER" ]; then
    echo "  hermes-agent updated (${BEFORE:0:7}... → ${AFTER:0:7}...)"
    echo "  Reinstalling dependencies..."
    if [ -d venv ] && command -v uv &>/dev/null; then
      UV_PROJECT_ENVIRONMENT="$PWD/venv" uv sync --extra all --locked --quiet 2>/dev/null && echo "  Dependencies updated" || echo "  Warning: dependency sync failed, run 'hermes setup' manually"
    fi
  else
    echo "  already up to date"
  fi
elif command -v hermes &>/dev/null; then
  echo "  hermes-agent found but no .git directory (installed via npm/pip), skipping git update"
else
  echo "  hermes-agent not found, skipping"
fi

# so that the script doesn't exit immediately before modelrelay has a chance to start properly
sleep 60