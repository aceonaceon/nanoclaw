# NanoClaw Specification

A personal Claude assistant accessible via WhatsApp, with persistent memory per conversation, scheduled tasks, and email integration.

---

## Table of Contents

1. [Architecture](#architecture)
2. [Folder Structure](#folder-structure)
3. [Configuration](#configuration)
4. [Memory System](#memory-system)
5. [Session Management](#session-management)
6. [Message Flow](#message-flow)
7. [Commands](#commands)
8. [Scheduled Tasks](#scheduled-tasks)
9. [MCP Servers](#mcp-servers)
10. [Deployment](#deployment)
11. [Security Considerations](#security-considerations)

---

## Architecture

NanoClaw supports two deployment modes: **macOS** (Apple Container) and **VPS** (Docker-in-Docker). The core message flow is identical — only the container runtime differs.

### macOS Mode (Apple Container)

```
┌─────────────────────────────────────────────────────────────────────┐
│                        HOST (macOS)                                  │
│                   (Main Node.js Process)                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────┐                     ┌────────────────────┐        │
│  │  WhatsApp    │────────────────────▶│   SQLite Database  │        │
│  │  (baileys)   │◀────────────────────│   (messages.db)    │        │
│  └──────────────┘   store/send        └─────────┬──────────┘        │
│                                                  │                   │
│         ┌────────────────────────────────────────┘                   │
│         │                                                            │
│         ▼                                                            │
│  ┌──────────────────┐    ┌──────────────────┐    ┌───────────────┐  │
│  │  Message Loop    │    │  Scheduler Loop  │    │  IPC Watcher  │  │
│  │  (polls SQLite)  │    │  (checks tasks)  │    │  (file-based) │  │
│  └────────┬─────────┘    └────────┬─────────┘    └───────────────┘  │
│           │                       │                                  │
│           └───────────┬───────────┘                                  │
│                       │ spawns container                             │
│                       ▼                                              │
├─────────────────────────────────────────────────────────────────────┤
│                  APPLE CONTAINER (Linux VM)                          │
├─────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                    AGENT RUNNER                               │   │
│  │  Working directory: /workspace/group (mounted from host)       │   │
│  │  Volume mounts:                                                │   │
│  │    • groups/{name}/ → /workspace/group                         │   │
│  │    • groups/global/ → /workspace/global/ (non-main only)        │   │
│  │    • data/sessions/{group}/.claude/ → /home/node/.claude/      │   │
│  │    • Additional dirs → /workspace/extra/*                      │   │
│  │                                                                │   │
│  │  Tools: Bash, Read, Write, Edit, Glob, Grep, WebSearch,       │   │
│  │         WebFetch, agent-browser, mcp__nanoclaw__*              │   │
│  └──────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────┘
```

### VPS Mode (Docker-in-Docker)

```
┌──────────────────────────────────────────────────────────────────────┐
│                        VPS HOST (Ubuntu)                              │
│                       Docker Engine                                   │
├──────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │  MAIN CONTAINER (nanoclaw-bot1)                              │    │
│  │  Built from Dockerfile.vps                                    │    │
│  │                                                                │    │
│  │  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐  │    │
│  │  │ Telegram │   │  SQLite  │   │ Scheduler│   │   IPC    │  │    │
│  │  │  Bot API │   │  (msgs)  │   │   Loop   │   │ Watcher  │  │    │
│  │  └────┬─────┘   └────┬─────┘   └────┬─────┘   └──────────┘  │    │
│  │       └──────────┬────┘──────────────┘                        │    │
│  │                  │  spawns via docker.sock                     │    │
│  │                  ▼                                              │    │
│  │  Mounts: /var/run/docker.sock, data-bot1/, groups-bot1/,      │    │
│  │          store-bot1/, container/                               │    │
│  └───────────────────────────────────────────────────────────────┘    │
│                  │                                                     │
│                  ▼ docker run (using HOST paths for bind mounts)       │
│  ┌───────────────────────────────────────────────────────────────┐    │
│  │  AGENT CONTAINER (nanoclaw-agent:latest, ephemeral)           │    │
│  │  entrypoint.sh: read stdin → chown dirs → gosu node → agent   │    │
│  │                                                                │    │
│  │  Volume mounts (from HOST, not from main container):           │    │
│  │    • groups-bot1/{name}/ → /workspace/group                    │    │
│  │    • groups-bot1/global/ → /workspace/global/ (non-main)       │    │
│  │    • data-bot1/sessions/{group}/.claude/ → /home/node/.claude/ │    │
│  │    • data-bot1/ipc/{group}/ → /workspace/ipc/                  │    │
│  │    • skills/ → /workspace/shared-skills/ (read-only)           │    │
│  │                                                                │    │
│  │  Tools: same as macOS mode                                     │    │
│  └───────────────────────────────────────────────────────────────┘    │
└───────────────────────────────────────────────────────────────────────┘
```

**Key VPS differences:**
- Main process runs inside a Docker container (built from `Dockerfile.vps`), not directly on the host
- Agent containers are spawned via the host's Docker socket (`/var/run/docker.sock` mount)
- `HOST_PROJECT_ROOT` env var signals VPS mode — `container-runner.ts` uses host filesystem paths for agent bind mounts instead of container-internal paths
- Agent container entrypoint (`container/entrypoint.sh`) reads stdin to a temp file first (Node.js subprocesses can consume stdin), then `chown`s bind-mounted directories and drops to `node` user via `gosu`

### Technology Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| Messaging | Telegram Bot API (grammy) | Send/receive messages |
| Message Storage | SQLite (better-sqlite3) | Store messages for polling |
| Container Runtime (macOS) | Apple Container | Isolated Linux VMs for agent execution |
| Container Runtime (VPS) | Docker (Docker-in-Docker) | Containerized agent execution |
| Agent | @anthropic-ai/claude-agent-sdk | Run Claude with tools and MCP servers |
| Browser Automation | agent-browser + Chromium | Web interaction and screenshots |
| Runtime | Node.js 22+ | Host process for routing and scheduling |

---

## Folder Structure

```
nanoclaw/
├── CLAUDE.md                      # Project context for Claude Code
├── docs/
│   ├── SPEC.md                    # This specification document
│   ├── REQUIREMENTS.md            # Architecture decisions
│   └── SECURITY.md                # Security model
├── README.md                      # User documentation
├── package.json                   # Node.js dependencies
├── tsconfig.json                  # TypeScript configuration
├── .mcp.json                      # MCP server configuration (reference)
├── .gitignore
│
├── src/
│   ├── index.ts                   # Main application (WhatsApp + routing)
│   ├── config.ts                  # Configuration constants
│   ├── types.ts                   # TypeScript interfaces
│   ├── utils.ts                   # Generic utility functions
│   ├── db.ts                      # Database initialization and queries
│   ├── whatsapp-auth.ts           # Standalone WhatsApp authentication
│   ├── task-scheduler.ts          # Runs scheduled tasks when due
│   └── container-runner.ts        # Spawns agents in containers (Apple Container or Docker)
│
├── container/
│   ├── Dockerfile                 # Container image (runs as 'node' user, includes Claude Code CLI)
│   ├── build.sh                   # Build script for container image
│   ├── agent-runner/              # Code that runs inside the container
│   │   ├── package.json
│   │   ├── tsconfig.json
│   │   └── src/
│   │       ├── index.ts           # Entry point (reads JSON, runs agent)
│   │       └── ipc-mcp.ts         # MCP server for host communication
│   └── skills/
│       └── agent-browser.md       # Browser automation skill
│
├── dist/                          # Compiled JavaScript (gitignored)
│
├── .claude/
│   └── skills/
│       ├── setup/
│       │   └── SKILL.md           # /setup skill
│       ├── customize/
│       │   └── SKILL.md           # /customize skill
│       └── debug/
│           └── SKILL.md           # /debug skill (container debugging)
│
├── groups/
│   ├── CLAUDE.md                  # Global memory (all groups read this)
│   ├── main/                      # Self-chat (main control channel)
│   │   ├── CLAUDE.md              # Main channel memory
│   │   └── logs/                  # Task execution logs
│   └── {Group Name}/              # Per-group folders (created on registration)
│       ├── CLAUDE.md              # Group-specific memory
│       ├── logs/                  # Task logs for this group
│       └── *.md                   # Files created by the agent
│
├── store/                         # Local data (gitignored)
│   ├── auth/                      # WhatsApp authentication state
│   └── messages.db                # SQLite database (messages, scheduled_tasks, task_run_logs)
│
├── data/                          # Application state (gitignored)
│   ├── sessions.json              # Active session IDs per group
│   ├── registered_groups.json     # Group JID → folder mapping
│   ├── router_state.json          # Last processed timestamp + last agent timestamps
│   ├── env/env                    # Copy of .env for container mounting
│   └── ipc/                       # Container IPC (messages/, tasks/)
│
├── logs/                          # Runtime logs (gitignored)
│   ├── nanoclaw.log               # Host stdout
│   └── nanoclaw.error.log         # Host stderr
│   # Note: Per-container logs are in groups/{folder}/logs/container-*.log
│
└── launchd/
    └── com.nanoclaw.plist         # macOS service configuration
```

---

## Configuration

Configuration constants are in `src/config.ts`:

```typescript
import path from 'path';

export const ASSISTANT_NAME = process.env.ASSISTANT_NAME || 'Andy';
export const POLL_INTERVAL = 2000;
export const SCHEDULER_POLL_INTERVAL = 60000;

// Paths are absolute (required for container mounts)
const PROJECT_ROOT = process.cwd();
export const STORE_DIR = path.resolve(PROJECT_ROOT, 'store');
export const GROUPS_DIR = path.resolve(PROJECT_ROOT, 'groups');
export const DATA_DIR = path.resolve(PROJECT_ROOT, 'data');

// Container configuration
export const CONTAINER_IMAGE = process.env.CONTAINER_IMAGE || 'nanoclaw-agent:latest';
export const CONTAINER_TIMEOUT = parseInt(process.env.CONTAINER_TIMEOUT || '300000', 10);
export const IPC_POLL_INTERVAL = 1000;

export const TRIGGER_PATTERN = new RegExp(`^@${ASSISTANT_NAME}\\b`, 'i');
```

**Note:** Paths must be absolute for Apple Container volume mounts to work correctly.

### Container Configuration

Groups can have additional directories mounted via `containerConfig` in `data/registered_groups.json`:

```json
{
  "1234567890@g.us": {
    "name": "Dev Team",
    "folder": "dev-team",
    "trigger": "@Andy",
    "added_at": "2026-01-31T12:00:00Z",
    "containerConfig": {
      "additionalMounts": [
        {
          "hostPath": "~/projects/webapp",
          "containerPath": "webapp",
          "readonly": false
        }
      ],
      "timeout": 600000
    }
  }
}
```

Additional mounts appear at `/workspace/extra/{containerPath}` inside the container.

**Apple Container mount syntax note:** Read-write mounts use `-v host:container`, but readonly mounts require `--mount "type=bind,source=...,target=...,readonly"` (the `:ro` suffix doesn't work).

### Claude Authentication

Configure authentication in a `.env` file in the project root. Two options:

**Option 1: Claude Subscription (OAuth token)**
```bash
CLAUDE_CODE_OAUTH_TOKEN=sk-ant-oat01-...
```
The token can be extracted from `~/.claude/.credentials.json` if you're logged in to Claude Code.

**Option 2: Pay-per-use API Key**
```bash
ANTHROPIC_API_KEY=sk-ant-api03-...
```

Only the authentication variables (`CLAUDE_CODE_OAUTH_TOKEN` and `ANTHROPIC_API_KEY`) are extracted from `.env` and mounted into the container at `/workspace/env-dir/env`, then sourced by the entrypoint script. This ensures other environment variables in `.env` are not exposed to the agent. This workaround is needed because Apple Container loses `-e` environment variables when using `-i` (interactive mode with piped stdin).

### Changing the Assistant Name

Set the `ASSISTANT_NAME` environment variable:

```bash
ASSISTANT_NAME=Bot npm start
```

Or edit the default in `src/config.ts`. This changes:
- The trigger pattern (messages must start with `@YourName`)
- The response prefix (`YourName:` added automatically)

### Placeholder Values in launchd

Files with `{{PLACEHOLDER}}` values need to be configured:
- `{{PROJECT_ROOT}}` - Absolute path to your nanoclaw installation
- `{{NODE_PATH}}` - Path to node binary (detected via `which node`)
- `{{HOME}}` - User's home directory

---

## Memory System

NanoClaw uses a hierarchical memory system based on CLAUDE.md files.

### Memory Hierarchy

| Level | Location | Read By | Written By | Purpose |
|-------|----------|---------|------------|---------|
| **Global** | `groups/CLAUDE.md` | All groups | Main only | Preferences, facts, context shared across all conversations |
| **Group** | `groups/{name}/CLAUDE.md` | That group | That group | Group-specific context, conversation memory |
| **Files** | `groups/{name}/*.md` | That group | That group | Notes, research, documents created during conversation |

### How Memory Works

1. **Agent Context Loading**
   - Agent runs with `cwd` set to `groups/{group-name}/`
   - Claude Agent SDK with `settingSources: ['project']` automatically loads:
     - `../CLAUDE.md` (parent directory = global memory)
     - `./CLAUDE.md` (current directory = group memory)

2. **Writing Memory**
   - When user says "remember this", agent writes to `./CLAUDE.md`
   - When user says "remember this globally" (main channel only), agent writes to `../CLAUDE.md`
   - Agent can create files like `notes.md`, `research.md` in the group folder

3. **Main Channel Privileges**
   - Only the "main" group (self-chat) can write to global memory
   - Main can manage registered groups and schedule tasks for any group
   - Main can configure additional directory mounts for any group
   - All groups have Bash access (safe because it runs inside container)

---

## Session Management

Sessions enable conversation continuity - Claude remembers what you talked about.

### How Sessions Work

1. Each group has a session ID stored in `data/sessions.json`
2. Session ID is passed to Claude Agent SDK's `resume` option
3. Claude continues the conversation with full context

**data/sessions.json:**
```json
{
  "main": "session-abc123",
  "Family Chat": "session-def456"
}
```

---

## Message Flow

### Incoming Message Flow

```
1. User sends WhatsApp message
   │
   ▼
2. Baileys receives message via WhatsApp Web protocol
   │
   ▼
3. Message stored in SQLite (store/messages.db)
   │
   ▼
4. Message loop polls SQLite (every 2 seconds)
   │
   ▼
5. Router checks:
   ├── Is chat_jid in registered_groups.json? → No: ignore
   └── Does message start with @Assistant? → No: ignore
   │
   ▼
6. Router catches up conversation:
   ├── Fetch all messages since last agent interaction
   ├── Format with timestamp and sender name
   └── Build prompt with full conversation context
   │
   ▼
7. Router invokes Claude Agent SDK:
   ├── cwd: groups/{group-name}/
   ├── prompt: conversation history + current message
   ├── resume: session_id (for continuity)
   └── mcpServers: nanoclaw (scheduler)
   │
   ▼
8. Claude processes message:
   ├── Reads CLAUDE.md files for context
   └── Uses tools as needed (search, email, etc.)
   │
   ▼
9. Router prefixes response with assistant name and sends via WhatsApp
   │
   ▼
10. Router updates last agent timestamp and saves session ID
```

### Trigger Word Matching

Messages must start with the trigger pattern (default: `@Andy`):
- `@Andy what's the weather?` → ✅ Triggers Claude
- `@andy help me` → ✅ Triggers (case insensitive)
- `Hey @Andy` → ❌ Ignored (trigger not at start)
- `What's up?` → ❌ Ignored (no trigger)

### Conversation Catch-Up

When a triggered message arrives, the agent receives all messages since its last interaction in that chat. Each message is formatted with timestamp and sender name:

```
[Jan 31 2:32 PM] John: hey everyone, should we do pizza tonight?
[Jan 31 2:33 PM] Sarah: sounds good to me
[Jan 31 2:35 PM] John: @Andy what toppings do you recommend?
```

This allows the agent to understand the conversation context even if it wasn't mentioned in every message.

---

## Commands

### Commands Available in Any Group

| Command | Example | Effect |
|---------|---------|--------|
| `@Assistant [message]` | `@Andy what's the weather?` | Talk to Claude |

### Commands Available in Main Channel Only

| Command | Example | Effect |
|---------|---------|--------|
| `@Assistant add group "Name"` | `@Andy add group "Family Chat"` | Register a new group |
| `@Assistant remove group "Name"` | `@Andy remove group "Work Team"` | Unregister a group |
| `@Assistant list groups` | `@Andy list groups` | Show registered groups |
| `@Assistant remember [fact]` | `@Andy remember I prefer dark mode` | Add to global memory |

---

## Scheduled Tasks

NanoClaw has a built-in scheduler that runs tasks as full agents in their group's context.

### How Scheduling Works

1. **Group Context**: Tasks created in a group run with that group's working directory and memory
2. **Full Agent Capabilities**: Scheduled tasks have access to all tools (WebSearch, file operations, etc.)
3. **Optional Messaging**: Tasks can send messages to their group using the `send_message` tool, or complete silently
4. **Main Channel Privileges**: The main channel can schedule tasks for any group and view all tasks

### Schedule Types

| Type | Value Format | Example |
|------|--------------|---------|
| `cron` | Cron expression | `0 9 * * 1` (Mondays at 9am) |
| `interval` | Milliseconds | `3600000` (every hour) |
| `once` | ISO timestamp | `2024-12-25T09:00:00Z` |

### Creating a Task

```
User: @Andy remind me every Monday at 9am to review the weekly metrics

Claude: [calls mcp__nanoclaw__schedule_task]
        {
          "prompt": "Send a reminder to review weekly metrics. Be encouraging!",
          "schedule_type": "cron",
          "schedule_value": "0 9 * * 1"
        }

Claude: Done! I'll remind you every Monday at 9am.
```

### One-Time Tasks

```
User: @Andy at 5pm today, send me a summary of today's emails

Claude: [calls mcp__nanoclaw__schedule_task]
        {
          "prompt": "Search for today's emails, summarize the important ones, and send the summary to the group.",
          "schedule_type": "once",
          "schedule_value": "2024-01-31T17:00:00Z"
        }
```

### Managing Tasks

From any group:
- `@Andy list my scheduled tasks` - View tasks for this group
- `@Andy pause task [id]` - Pause a task
- `@Andy resume task [id]` - Resume a paused task
- `@Andy cancel task [id]` - Delete a task

From main channel:
- `@Andy list all tasks` - View tasks from all groups
- `@Andy schedule task for "Family Chat": [prompt]` - Schedule for another group

---

## MCP Servers

### NanoClaw MCP (built-in)

The `nanoclaw` MCP server is created dynamically per agent call with the current group's context.

**Available Tools:**
| Tool | Purpose |
|------|---------|
| `schedule_task` | Schedule a recurring or one-time task |
| `list_tasks` | Show tasks (group's tasks, or all if main) |
| `get_task` | Get task details and run history |
| `update_task` | Modify task prompt or schedule |
| `pause_task` | Pause a task |
| `resume_task` | Resume a paused task |
| `cancel_task` | Delete a task |
| `send_message` | Send a WhatsApp message to the group |

---

## Deployment

NanoClaw supports two deployment modes:

### Option A: macOS (launchd service)

**Startup Sequence:**
1. **Ensures Apple Container system is running** - Automatically starts it if needed
2. Initializes the SQLite database
3. Loads state (registered groups, sessions, router state)
4. Connects to WhatsApp
5. Starts the message polling loop, scheduler loop, and IPC watcher

**launchd/com.nanoclaw.plist:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.nanoclaw</string>
    <key>ProgramArguments</key>
    <array>
        <string>{{NODE_PATH}}</string>
        <string>{{PROJECT_ROOT}}/dist/index.js</string>
    </array>
    <key>WorkingDirectory</key>
    <string>{{PROJECT_ROOT}}</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>{{HOME}}/.local/bin:/usr/local/bin:/usr/bin:/bin</string>
        <key>HOME</key>
        <string>{{HOME}}</string>
        <key>ASSISTANT_NAME</key>
        <string>Andy</string>
    </dict>
    <key>StandardOutPath</key>
    <string>{{PROJECT_ROOT}}/logs/nanoclaw.log</string>
    <key>StandardErrorPath</key>
    <string>{{PROJECT_ROOT}}/logs/nanoclaw.error.log</string>
</dict>
</plist>
```

```bash
# Install / start / stop
cp launchd/com.nanoclaw.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.nanoclaw.plist
launchctl unload ~/Library/LaunchAgents/com.nanoclaw.plist
```

### Option B: VPS (Docker Compose)

Uses `docker-compose.vps.yml` with Docker-in-Docker architecture. The main container (`Dockerfile.vps`) runs the Node.js router and spawns agent containers via the host's Docker socket.

**Startup Sequence:**
1. Docker Compose builds and starts the main container
2. Main container entrypoint checks if agent image exists, builds it if needed
3. Node.js router starts: initializes SQLite, loads state, connects to Telegram
4. Starts message polling loop, scheduler loop, and IPC watcher
5. On each message, spawns an agent container via `docker run` using host paths

**Key files:**
| File | Purpose |
|------|---------|
| `docker-compose.vps.yml` | Multi-bot Docker Compose config |
| `Dockerfile.vps` | Main container image (Node.js + Docker CLI) |
| `.env.vps.example` | Environment variable template |
| `init-vps-dirs.sh` | Creates directories with correct ownership (UID 1000) |
| `pair-main-group.sh` | Interactive script to register Telegram chat as main group |
| `container/entrypoint.sh` | Agent container entrypoint (stdin capture, chown, gosu) |

**VPS-specific environment variables (set in docker-compose.vps.yml):**
| Variable | Purpose |
|----------|---------|
| `HOST_PROJECT_ROOT` | Triggers VPS mode; host path for project root |
| `HOST_GROUPS_DIR` | Host path for groups directory (agent bind mounts) |
| `HOST_DATA_DIR` | Host path for data directory (agent bind mounts) |

When `HOST_PROJECT_ROOT` is set, `container-runner.ts` uses these host paths instead of `process.cwd()` for building agent container bind mounts. This is necessary because the main container's filesystem paths (e.g., `/app/groups`) differ from the host paths that the Docker daemon needs for volume mounts.

```bash
# Start / stop / restart
docker compose -f docker-compose.vps.yml up -d --build
docker compose -f docker-compose.vps.yml down
docker compose -f docker-compose.vps.yml restart nanoclaw-bot1

# View logs
docker compose -f docker-compose.vps.yml logs -f nanoclaw-bot1
```

---

## Security Considerations

### Container Isolation

All agents run inside containers (Apple Container on macOS, Docker on VPS), providing:
- **Filesystem isolation**: Agents can only access mounted directories
- **Safe Bash access**: Commands run inside the container, not on the host
- **Network isolation**: Can be configured per-container if needed
- **Process isolation**: Container processes can't affect the host
- **Non-root user**: Container runs as unprivileged `node` user (uid 1000)

### VPS: Permission Handling

In Docker-in-Docker VPS deployments, bind-mounted directories are created by root on the host but need to be writable by the `node` user (UID 1000) inside agent containers. This is handled at two levels:

1. **`init-vps-dirs.sh`**: Run at setup time, creates directories and sets `chown -R 1000:1000` on group and data directories
2. **`container/entrypoint.sh`**: Runs as root on container start, `chown`s `/home/node/.claude/`, `/workspace/group/`, and `/workspace/ipc/` before dropping to `node` via `gosu`

The entrypoint also reads stdin into a temp file before running any subprocesses, because Node.js child processes can consume the stdin pipe buffer even when they don't explicitly read from it.

### Prompt Injection Risk

Telegram/WhatsApp messages could contain malicious instructions attempting to manipulate Claude's behavior.

**Mitigations:**
- Container isolation limits blast radius
- Only registered groups are processed
- Trigger word required (reduces accidental processing)
- Agents can only access their group's mounted directories
- Main can configure additional directories per group
- Claude's built-in safety training

**Recommendations:**
- Only register trusted groups
- Review additional directory mounts carefully
- Review scheduled tasks periodically
- Monitor logs for unusual activity

### Credential Storage

| Credential | Storage Location | Notes |
|------------|------------------|-------|
| Claude CLI Auth | data/sessions/{group}/.claude/ | Per-group isolation, mounted to /home/node/.claude/ |
| Telegram Session | store/ (SQLite DB) | Bot token-based, no expiry |
| WhatsApp Session (macOS) | store/auth/ | Auto-created, persists ~20 days |

### File Permissions

The groups/ folder contains personal memory and should be protected:
```bash
chmod 700 groups/       # macOS
chmod 700 groups-bot1/  # VPS
```

---

## Troubleshooting

### Common Issues (All Modes)

| Issue | Cause | Solution |
|-------|-------|----------|
| "Claude Code process exited with code 1" | Session mount path wrong | Ensure mount is to `/home/node/.claude/` not `/root/.claude/` |
| Session not continuing | Session ID not saved | Check `data/sessions.json` |
| Session not continuing | Mount path mismatch | Container user is `node` with HOME=/home/node; sessions must be at `/home/node/.claude/` |
| "No groups registered" | Haven't added groups | Pair via `pair-main-group.sh` (VPS) or `@Andy add group "Name"` (macOS) |

### macOS-Specific Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| No response to messages | Service not running | Check `launchctl list | grep nanoclaw` |
| Container failed to start | Apple Container not running | Check logs; NanoClaw auto-starts container system but may fail |
| "QR code expired" | WhatsApp session expired | Delete store/auth/ and restart |

### VPS-Specific Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Agent container hangs (no response) | Bind-mount permissions (root:root) | Run `./init-vps-dirs.sh` and restart |
| Agent container hangs | Stdin consumed by subprocess | Should be fixed by entrypoint.sh stdin-to-tmpfile pattern |
| Container exits immediately | Missing auth tokens | Check `.env` has `ANTHROPIC_API_KEY` or `CLAUDE_CODE_OAUTH_TOKEN` |
| "Agent image not found" | Agent container not built | Run `cd container && ./build.sh` |

**VPS debugging commands:**
```bash
# Check agent containers
docker ps -a --filter "ancestor=nanoclaw-agent:latest"

# Check file permissions inside agent
docker exec <container_id> ls -la /home/node/.claude/

# Check what a stuck process is waiting on
docker exec <container_id> cat /proc/<pid>/wchan

# Main container logs
docker compose -f docker-compose.vps.yml logs -f nanoclaw-bot1
```

### Log Locations

**macOS:**
- `logs/nanoclaw.log` - stdout
- `logs/nanoclaw.error.log` - stderr

**VPS:**
- `docker compose -f docker-compose.vps.yml logs nanoclaw-bot1` - main container
- `groups-bot1/{group}/logs/container-*.log` - per-agent run logs

### Debug Mode

```bash
# macOS
npm run dev

# VPS: set LOG_LEVEL=debug in .env, then restart
docker compose -f docker-compose.vps.yml restart
```
