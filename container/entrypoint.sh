#!/bin/bash
set -e

# IMPORTANT: Read stdin immediately before any subprocesses can consume it.
# Docker pipes are fragile - subprocesses (especially Node.js) can consume
# the stdin buffer even when they don't explicitly read from it.
cat > /tmp/input.json

# Fix ownership of bind-mounted directories (created as root on host)
# In VPS Docker-in-Docker deployments, bind mounts come in as root:root
# but the agent process needs to run as node (UID 1000)
if [ "$(id -u)" = "0" ]; then
  chown -R node:node /home/node/.claude/ 2>/dev/null || true
  chown -R node:node /workspace/group/ 2>/dev/null || true
  chown -R node:node /workspace/ipc/ 2>/dev/null || true
  chown node:node /tmp/input.json
fi

# Validate skills on startup (output to stderr to keep stdout clean for agent)
if [ -f /app/validate-skills.cjs ]; then
  if [ "$(id -u)" = "0" ]; then
    gosu node node /app/validate-skills.cjs >&2
  else
    node /app/validate-skills.cjs >&2
  fi
fi

# Source environment if exists (workaround for Apple Container -i bug)
[ -f /workspace/env-dir/env ] && export $(cat /workspace/env-dir/env | xargs)

# Run agent - drop privileges to node if currently root
if [ "$(id -u)" = "0" ]; then
  exec gosu node node /app/dist/index.js < /tmp/input.json
else
  exec node /app/dist/index.js < /tmp/input.json
fi
