# AI-Driven Work Installer v2 - Architecture

## Overview

A modular installation system where users select desired features on the landing page,
an install command is automatically generated, and all installations proceed sequentially in a single terminal window.

---

## User Flow

```
┌─────────────────────────────────────────────────────┐
│  1. Visit the landing page                          │
│     https://ai-driven-work.vercel.app               │
└─────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────┐
│  2. Select desired features                         │
│                                                     │
│     ✅ Claude Code + bkit (base - always included)  │
│     ☑️ Google Workspace (requires Docker)           │
│     ☑️ Atlassian (Jira + Confluence, requires Docker)│
│     ☐ Notion                                        │
│     ☐ GitHub                                        │
│     ☐ Figma                                         │
└─────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────┐
│  3. Command is auto-generated                       │
│                                                     │
│  Windows:                                           │
│  ┌────────────────────────────────────────────────┐ │
│  │ powershell -ep bypass -c "irm .../install.ps1  │ │
│  │ | iex"  (modules passed via env variables)     │ │
│  └────────────────────────────────────────────────┘ │
│                                                     │
│  Mac/Linux:                                         │
│  ┌────────────────────────────────────────────────┐ │
│  │ curl -fsSL .../install.sh | MODULES="..." bash │ │
│  └────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────┐
│  4. Run in terminal (everything in one window)      │
│                                                     │
│  PS> [paste command]                                │
│                                                     │
│  ========================================           │
│    AI-Driven Work Installer v2                      │
│  ========================================           │
│                                                     │
│  [1/3] Installing base (Claude + bkit)...           │
│    ✓ Node.js installed                              │
│    ✓ Claude CLI installed (native)                  │
│    ✓ bkit plugin installed                          │
│                                                     │
│  [2/3] Installing Google Workspace...               │
│    ...                                              │
│                                                     │
│  [3/3] Installing Notion...                         │
│    ...                                              │
│                                                     │
│  ========================================           │
│    Installation Complete!                           │
│  ========================================           │
└─────────────────────────────────────────────────────┘
```

---

## Folder Structure

```
adw/installer/
├── ARCHITECTURE.md          # This document
├── install.ps1              # Windows main entry point
├── install.sh               # Mac/Linux main entry point
├── modules.json             # Module list (used for remote execution)
│
├── modules/
│   ├── base/                # Base installation (Claude + bkit)
│   │   ├── module.json
│   │   ├── install.ps1
│   │   └── install.sh
│   │
│   ├── google/              # Google Workspace (requires Docker)
│   │   ├── module.json
│   │   ├── install.ps1
│   │   └── install.sh
│   │
│   ├── atlassian/           # Atlassian - Jira + Confluence (requires Docker)
│   │   ├── module.json
│   │   ├── install.ps1
│   │   └── install.sh
│   │
│   ├── notion/              # Notion integration
│   │   ├── module.json
│   │   ├── install.ps1
│   │   └── install.sh
│   │
│   ├── github/              # GitHub integration
│   │   ├── module.json
│   │   ├── install.ps1
│   │   └── install.sh
│   │
│   ├── figma/               # Figma integration (Remote MCP + OAuth)
│   │   ├── module.json
│   │   ├── install.ps1
│   │   └── install.sh
│   │
│   ├── pencil/              # Pencil AI Design Canvas (VS Code Extension)
│   │   ├── module.json
│   │   ├── install.ps1
│   │   └── install.sh
│   │
│   └── shared/              # FR-S3-05a: Shared utilities (sourced by all modules)
│       ├── colors.sh        # ANSI color codes + print_success/error/warning/info/debug
│       ├── browser-utils.sh # Cross-platform browser_open() with WSL support
│       ├── docker-utils.sh  # docker_check(), docker_pull_image(), compatibility check
│       ├── mcp-config.sh    # mcp_add_docker_server(), mcp_add_stdio_server()
│       └── oauth-helper.sh  # mcp_oauth_flow() for Remote MCP OAuth
│
└── (landing page is in a separate repo)
    # https://github.com/ww-w-ai/ai-driven-work-landing
```

---

## How It Works

### 1. Command Execution Methods

**Windows (PowerShell):**
```powershell
# Method 1: Pass modules via environment variables (used from Win+R)
powershell -ep bypass -c "$env:MODULES='google,notion'; irm https://raw.githubusercontent.com/ww-w-ai/ai-driven-work-quickstart/main/installer/install.ps1 | iex"

# Method 2: Pass as parameters (used from PowerShell)
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/ww-w-ai/ai-driven-work-quickstart/main/installer/install.ps1))) -modules 'google,notion'
```

**Mac/Linux (Bash):**
```bash
curl -fsSL https://raw.githubusercontent.com/ww-w-ai/ai-driven-work-quickstart/main/installer/install.sh | MODULES="google,notion" bash
```

### 2. Main Script Behavior

The main script (`install.ps1` / `install.sh`):
1. Scans the `modules/` folder to load the list of available modules
2. Validates the selected modules
3. Checks whether Docker is required (google, atlassian modules)
4. Requests administrator privileges (Windows) / checks sudo (Mac)
5. Executes base module first, then the selected modules in order

### 3. Module Execution Mechanism

```
irm "$BaseUrl/modules/$ModuleName/install.ps1" | iex
```

This command:
1. `irm` (Invoke-RestMethod) - **Downloads the contents of install.ps1 as text**
2. `|` (pipe) - Passes the downloaded content to the next command
3. `iex` (Invoke-Expression) - **Executes the code in the current session**

**No new window opens** - all code runs in the same PowerShell session.

### 4. Claude Code Installation Method

Claude Code is installed using the **native method**. (npm is deprecated)

| Platform | Command |
|----------|---------|
| **Mac/Linux** | `curl -fsSL https://claude.ai/install.sh \| bash` |
| **Windows** | `irm https://claude.ai/install.ps1 \| iex` |

On Windows, after native installation, `~/.local/bin` is added to PATH.

---

## Landing Page

The landing page is managed in a **separate repository**:
- Repo: https://github.com/ww-w-ai/ai-driven-work-landing
- Deployment: Vercel
- Tech stack: Next.js + TypeScript + Tailwind CSS

When users select modules, the React component dynamically generates the install command.
When modules that require Docker are selected, a 2-step install command is displayed.

---

## Module Types

### 1. Docker-Based MCP Modules
- Google Workspace, Atlassian (Docker mode)
- Requires Docker Desktop (auto-detected during installation)
- Runs MCP server as a Docker container

### 2. Remote MCP Modules
- Notion, Figma, Atlassian (Rovo mode)
- Docker not required
- Registered via `claude mcp add --transport http/sse`
- OAuth authentication handled automatically (shared/oauth-helper.sh)

### 3. CLI Tool Modules
- GitHub (gh CLI)
- No Docker required, no MCP configuration needed
- Claude uses it directly through the Bash tool

### 4. IDE Extension Modules
- Pencil (VS Code / Cursor extension)
- No Docker required, MCP auto-connects
- Installed via `code --install-extension`

---

## Execution Order (FR-S2-07)

Modules are sorted and executed according to the `order` field in `module.json`:

| Order | Module     | Type              | Docker |
|-------|------------|-------------------|--------|
| 0     | base       | required          | optional |
| 1     | notion     | remote-mcp        | No     |
| 2     | google     | docker-mcp        | Yes    |
| 3     | figma      | remote-mcp        | No     |
| 4     | github     | cli               | No     |
| 5     | atlassian  | docker-mcp / rovo | optional |
| 6     | pencil     | ide-extension     | No     |

---

## Hosting

| Item | Hosting | URL |
|------|---------|-----|
| **Install scripts** | GitHub Raw | `https://raw.githubusercontent.com/ww-w-ai/ai-driven-work-quickstart/main/installer/...` |
| **Landing page** | Vercel | `https://ai-driven-work.vercel.app` |

---

## Execution Flow Diagram

```
User runs command
        │
        ▼
┌───────────────────┐
│   install.ps1     │  ← Downloaded & executed from GitHub Raw
│   (main script)   │
└───────────────────┘
        │
        ├── modules/base/ executed ────────────┐
        │   (Node.js, Git, VS Code,            │
        │    Claude CLI, bkit installation)     │
        │                                      │
        ├── modules/google/ (if selected) ─────┤  Same terminal window
        │   (Docker + Google MCP setup)        │
        │                                      │
        ├── modules/notion/ (if selected) ─────┤
        │   (Notion MCP setup)                 │
        │                                      │
        ├── modules/github/ (if selected) ─────┤
        │   (GitHub CLI installation)          │
        │                                      │
        ├── modules/figma/ (if selected) ──────┤
        │   (Figma MCP setup)                  │
        │                                      │
        ├── modules/atlassian/ (if selected) ──┤
        │   (Docker or Rovo MCP setup)         │
        │                                      │
        ├── modules/pencil/ (if selected) ─────┤
        │   (VS Code/Cursor Extension install) │
        │                                      │
        ▼                                      │
   Installation Complete! ◄────────────────────┘
```

---

## CI/CD

Installation scripts are tested on Windows/macOS via GitHub Actions.

- Workflow: `.github/workflows/test-installer.yml`
- Trigger: `workflow_dispatch` (manual)
- Test OS: Windows, macOS
