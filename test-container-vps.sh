#!/bin/bash
# Test NanoClaw agent container on VPS/Linux
# Usage: ./test-container-vps.sh

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_ROOT"

echo "=== Testing NanoClaw Agent Container ==="
echo "Project root: $PROJECT_ROOT"
echo ""

# Check if agent image exists
if ! docker image inspect nanoclaw-agent:latest > /dev/null 2>&1; then
    echo "❌ Error: nanoclaw-agent:latest image not found"
    echo "   Run: cd container && ./build.sh"
    exit 1
fi

# Check if .env exists
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found"
    echo "   Run: cp .env.vps.example .env (or .env.example for local dev)"
    exit 1
fi

echo "✅ Prerequisites OK"
echo ""
echo "Running test: 'What is 2+2?'"
echo "---"

echo '{"prompt":"Test: what is 2+2?","groupFolder":"test-group","chatId":"test@example.com","isMain":true}' | \
docker run -i --rm \
  -v "$PROJECT_ROOT/skills:/workspace/shared-skills:ro" \
  -v "$PROJECT_ROOT/groups:/workspace/groups:rw" \
  -v "$PROJECT_ROOT/data/env:/workspace/env-dir:ro" \
  nanoclaw-agent:latest

echo ""
echo "=== Test Complete ==="
