# AI-Driven Work (ADW)

An all-in-one installer that sets up Claude Code or Gemini CLI + development tools + MCP modules in a single step.

---

## One-Click Install (Recommended)

Select the modules you want on the landing page, and the install command will be automatically generated:
https://ai-driven-work.vercel.app

### Windows (Claude)

Press `Win + R`, then paste and run the following command:
```
powershell -ep bypass -c "irm https://raw.githubusercontent.com/ww-w-ai/ai-driven-work-quickstart/main/installer/install.ps1 | iex"
```

Install with modules:
```
powershell -ep bypass -c "$env:MODULES='google,notion'; irm https://raw.githubusercontent.com/ww-w-ai/ai-driven-work-quickstart/main/installer/install.ps1 | iex"
```

### Windows (Gemini)

```
powershell -ep bypass -c "$env:CLI_TYPE='gemini'; irm https://raw.githubusercontent.com/ww-w-ai/ai-driven-work-quickstart/main/installer/install.ps1 | iex"
```

> **Windows**: Modules that require Docker (google, atlassian) need a 2-step installation. The landing page will guide you through this automatically.

### Mac/Linux (Claude)

Open a terminal and run the following command:
```bash
curl -fsSL https://raw.githubusercontent.com/ww-w-ai/ai-driven-work-quickstart/main/installer/install.sh | bash
```

Install with modules:
```bash
curl -fsSL https://raw.githubusercontent.com/ww-w-ai/ai-driven-work-quickstart/main/installer/install.sh | MODULES="google,notion" bash
```

### Mac/Linux (Gemini)

```bash
curl -fsSL https://raw.githubusercontent.com/ww-w-ai/ai-driven-work-quickstart/main/installer/install.sh | CLI_TYPE=gemini bash
```

---

## What Gets Installed

### Base Installation

| Program | Claude | Gemini |
|---------|--------|--------|
| Node.js | O | O |
| Git | O | O |
| IDE | VS Code | VS Code |
| VS Code Extension | Claude Code (`anthropic.claude-code`) | Gemini CLI Companion (`Google.gemini-cli-vscode-ide-companion`) |
| Docker Desktop | Optional | Optional |
| AI CLI | Claude Code CLI | Gemini CLI |
| Plugin | bkit (Claude plugin) | bkit-gemini (Gemini extension) |

### MCP Modules (Optional)

| Module | Description | Docker |
|--------|-------------|--------|
| Google | Gmail, Calendar, Drive, Docs, Sheets, Slides integration | Required |
| Atlassian | Jira, Confluence integration | Required |
| Notion | Notion pages/DB integration | Not required |
| GitHub | GitHub CLI integration | Not required |
| Figma | Figma design file integration | Not required |
| Pencil | AI design canvas within IDE | Not required |

---

## Having Trouble Installing?

If you encounter issues during installation, run the diagnostic tool.

**Windows:**
```
powershell -ep bypass -c "irm https://raw.githubusercontent.com/ww-w-ai/ai-driven-work-quickstart/main/installer/diagnose.ps1 | iex"
```

**Mac/Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/ww-w-ai/ai-driven-work-quickstart/main/installer/diagnose.sh | bash
```

It will automatically check your installation environment (Node.js, Docker, permissions, etc.) and report the cause of any issues.

---

## Folder Structure

```
popup-claude/
├── installer/              # Modular automated installer
│   ├── install.ps1         # Windows main entry point
│   ├── install.sh          # Mac/Linux main entry point
│   ├── diagnose.ps1        # Windows installation diagnostic tool
│   ├── diagnose.sh         # Mac/Linux installation diagnostic tool
│   ├── modules.json        # Module list
│   ├── claude-desktop/     # Claude Desktop installation scripts
│   └── modules/            # Individual modules (base, google, atlassian, notion, github, figma, pencil)
├── docs/                   # Configuration guide documents
├── google-workspace-mcp/   # Google MCP source code
├── .github/workflows/      # CI tests
└── README.md
```

> The landing page is in a separate repository: https://github.com/ww-w-ai/ai-driven-work-landing

---

## Documentation

- [Installer System Architecture](installer/ARCHITECTURE.md)
- [Google MCP Admin Setup (Internal)](docs/SETUP_GOOGLE_INTERNAL_ADMIN.md)
- [Google MCP Admin Setup (External)](docs/SETUP_GOOGLE_EXTERNAL_ADMIN.md)
- [Google MCP Developer Guide](google-workspace-mcp/SETUP.md)

---

## Need Help?

If you encounter any issues, please reach out via [Issues](https://github.com/ww-w-ai/ai-driven-work-quickstart/issues).
