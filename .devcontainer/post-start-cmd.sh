#!/bin/bash

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