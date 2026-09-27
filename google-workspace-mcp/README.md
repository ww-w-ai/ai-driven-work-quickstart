# Google Workspace MCP

An MCP server that enables Claude Code to access Google Workspace (Gmail, Calendar, Drive).

---

## Installation

### Regular Users (Recommended)

Use the ADW installer:

**Windows:** Press `Win + R` and run
```
powershell -ep bypass -c "$env:MODULES='google'; irm https://raw.githubusercontent.com/ww-w-ai/ai-driven-work-quickstart/main/installer/install.ps1 | iex"
```

**Mac/Linux:** Run in terminal
```bash
curl -fsSL https://raw.githubusercontent.com/ww-w-ai/ai-driven-work-quickstart/main/installer/install.sh | MODULES="google" bash
```

### Administrators

To set up Google MCP for your team:

| Scenario | Guide |
|----------|-------|
| Using Google Workspace (company domain) | [Internal Admin Guide](../docs/SETUP_GOOGLE_INTERNAL_ADMIN.md) |
| Using Gmail (personal/external) | [External Admin Guide](../docs/SETUP_GOOGLE_EXTERNAL_ADMIN.md) |

---

## Docker Image

The Docker image is hosted on ghcr.io (multi-arch: amd64 + arm64).

```bash
# Pull the image
docker pull ghcr.io/popup-studio-ai/google-workspace-mcp:latest

# Run
docker run -i --rm \
  -v "$HOME/.google-workspace:/app/.google-workspace" \
  ghcr.io/popup-studio-ai/google-workspace-mcp:latest
```

---

## Supported Features

| Service | Features |
|---------|----------|
| Gmail | Read, search, send emails |
| Calendar | View, create events |
| Drive | Search, download files |
| Docs | Read, create documents |
| Sheets | Read, create spreadsheets |
| Slides | Read, create presentations |

---

## Development

### Build

```bash
npm install
npm run build
```

### Docker Image Build

```bash
docker build -t google-workspace-mcp .
```

### Multi-arch Build (AMD64 + ARM64)

```bash
docker buildx build --platform linux/amd64,linux/arm64 \
  -t ghcr.io/popup-studio-ai/google-workspace-mcp:latest --push .
```
