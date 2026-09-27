# ============================================
# Atlassian (Jira + Confluence) MCP Module
# ============================================
# Auto-detects Docker and recommends best option

Write-Host "Atlassian MCP lets Claude access:" -ForegroundColor White
Write-Host "  - Jira (view issues, create tasks)" -ForegroundColor Gray
Write-Host "  - Confluence (search, read pages)" -ForegroundColor Gray
Write-Host ""

# ============================================
# Auto-detect Docker
# ============================================
$hasDocker = [bool](Get-Command docker -ErrorAction SilentlyContinue)
$dockerRunning = $false
if ($hasDocker) {
    $null = docker info 2>&1
    $dockerRunning = ($LASTEXITCODE -eq 0)
}

# ============================================
# Show options based on Docker status
# ============================================
Write-Host "========================================" -ForegroundColor Cyan
if ($hasDocker) {
    Write-Host "  Docker is installed!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Select installation method:" -ForegroundColor White
    Write-Host "  1. Local install (Recommended) - Uses Docker, runs on your machine" -ForegroundColor Green
    Write-Host "  2. Simple install - Browser login only" -ForegroundColor White
} else {
    Write-Host "  Docker is not installed." -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Select installation method:" -ForegroundColor White
    Write-Host "  1. Simple install (Recommended) - Browser login only, no extra install" -ForegroundColor Green
    Write-Host "  2. Local install - Requires Docker" -ForegroundColor White
}
Write-Host ""
$choice = Read-Host "Select (1/2)"

# Determine which mode based on Docker status and choice
$useDocker = $false
if ($hasDocker) {
    # Docker installed: 1=Docker, 2=Rovo
    if ($choice -ne "2") { $useDocker = $true }
} else {
    # Docker not installed: 1=Rovo, 2=Docker
    if ($choice -eq "2") { $useDocker = $true }
}

# ============================================
# Execute selected mode
# ============================================
if ($useDocker) {
    # ========================================
    # MCP-ATLASSIAN (Docker)
    # ========================================

    # Check Docker is running
    if (-not $hasDocker) {
        Write-Host ""
        Write-Host "Docker is not installed!" -ForegroundColor Red
        Write-Host "Please install Docker Desktop first:" -ForegroundColor White
        Write-Host "  https://www.docker.com/products/docker-desktop/" -ForegroundColor Cyan
        Write-Host ""
        throw "Docker is required for local installation"
    }

    if (-not $dockerRunning) {
        Write-Host ""
        Write-Host "Docker is not running!" -ForegroundColor Yellow
        Write-Host "Please start Docker Desktop." -ForegroundColor White
        Write-Host ""
        $waitDocker = Read-Host "Press Enter after starting Docker (q to cancel)"
        if ($waitDocker -eq 'q') { throw "Cancelled by user" }

        $null = docker info 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Docker is still not running." -ForegroundColor Red
            throw "Docker is not running"
        }
    }
    Write-Host ""
    Write-Host "[OK] Docker check complete" -ForegroundColor Green

    Write-Host ""
    Write-Host "Setting up mcp-atlassian (Docker)..." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "API token required. Create one here:" -ForegroundColor White
    Write-Host "  https://id.atlassian.com/manage-profile/security/api-tokens" -ForegroundColor Cyan
    Write-Host ""

    $openToken = Read-Host "Open API token page in browser? (y/n)"
    if ($openToken -eq "y" -or $openToken -eq "Y") {
        Start-Process "https://id.atlassian.com/manage-profile/security/api-tokens"
        Write-Host "Create and copy the token." -ForegroundColor Yellow
        Read-Host "Press Enter when ready"
    }

    Write-Host ""
    $atlassianUrl = Read-Host "Atlassian URL (e.g., https://company.atlassian.net)"
    $atlassianUrl = $atlassianUrl.TrimEnd('/')
    $jiraUrl = $atlassianUrl
    $confluenceUrl = "$atlassianUrl/wiki"

    Write-Host "  Jira: $jiraUrl" -ForegroundColor Gray
    Write-Host "  Confluence: $confluenceUrl" -ForegroundColor Gray
    Write-Host ""
    $email = Read-Host "Email"
    $apiToken = Read-Host "API Token"

    # Pull Docker image
    Write-Host ""
    Write-Host "[Pull] Downloading mcp-atlassian Docker image..." -ForegroundColor Yellow
    docker pull ghcr.io/sooperset/mcp-atlassian:latest 2>$null
    Write-Host "  OK" -ForegroundColor Green

    # Source shared MCP utilities (works both local and remote)
    if (-not (Get-Command Add-McpDockerServer -ErrorAction SilentlyContinue)) {
        $mcpConfigLocal = "$PSScriptRoot\..\shared\mcp-config.ps1"
        if ($PSScriptRoot -and (Test-Path $mcpConfigLocal)) {
            . $mcpConfigLocal
        } else {
            irm "https://raw.githubusercontent.com/ww-w-ai/ai-driven-work-quickstart/main/installer/modules/shared/mcp-config.ps1" | iex
        }
    }

    # Update MCP config via CLI
    Write-Host ""
    Write-Host "[Config] Updating MCP config..." -ForegroundColor Yellow
    Add-McpDockerServer "atlassian" "ghcr.io/sooperset/mcp-atlassian:latest" @(
        "-e", "CONFLUENCE_URL=$confluenceUrl",
        "-e", "CONFLUENCE_USERNAME=$email",
        "-e", "CONFLUENCE_API_TOKEN=$apiToken",
        "-e", "JIRA_URL=$jiraUrl",
        "-e", "JIRA_USERNAME=$email",
        "-e", "JIRA_API_TOKEN=$apiToken"
    ) @("--transport", "stdio")
    Add-McpPermission "mcp__atlassian"

} else {
    # ========================================
    # ROVO MCP (Official Atlassian SSE)
    # ========================================
    Write-Host ""
    Write-Host "Setting up Atlassian Rovo MCP..." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "A browser will open for Atlassian login." -ForegroundColor White
    Write-Host "Please login and authorize the access." -ForegroundColor White
    Write-Host ""

    $cliCmd = if ($env:CLI_TYPE -eq "gemini") { "gemini" } else { "claude" }
    & $cliCmd mcp add --transport sse atlassian https://mcp.atlassian.com/v1/sse

    Write-Host ""
    Write-Host "  Rovo MCP setup complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Guide: https://support.atlassian.com/atlassian-rovo-mcp-server/" -ForegroundColor Gray
}

# Remove project-level blocks
Write-Host ""
Write-Host "[Fix] Removing project-level blocks..." -ForegroundColor Yellow
if (-not (Get-Command Remove-McpProjectBlock -ErrorAction SilentlyContinue)) {
    $mcpConfigLocal = "$PSScriptRoot\..\shared\mcp-config.ps1"
    if ($PSScriptRoot -and (Test-Path $mcpConfigLocal)) {
        . $mcpConfigLocal
    } else {
        irm "https://raw.githubusercontent.com/ww-w-ai/ai-driven-work-quickstart/main/installer/modules/shared/mcp-config.ps1" | iex
    }
}
Remove-McpProjectBlock "atlassian"

Write-Host ""
Write-Host "----------------------------------------" -ForegroundColor DarkGray
Write-Host "Atlassian MCP installation complete!" -ForegroundColor Green
