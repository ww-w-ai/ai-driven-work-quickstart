# ============================================
# Google Workspace MCP Module
# ============================================
# Prerequisites: Docker must be running
# Called by install.ps1 when -google flag is used

# ============================================
# 1. Docker Check
# ============================================
Write-Host "[Check] Docker is running..." -ForegroundColor Yellow
$dockerRunning = $false
try {
    $null = docker info 2>&1
    if ($LASTEXITCODE -eq 0) { $dockerRunning = $true }
} catch {}

if (-not $dockerRunning) {
    Write-Host ""
    Write-Host "Docker is not running!" -ForegroundColor Red
    Write-Host ""
    Write-Host "How to start Docker Desktop:" -ForegroundColor Yellow
    Write-Host "  - Press Windows key, type 'Docker Desktop', press Enter" -ForegroundColor Cyan
    Write-Host "  - Wait for Docker to fully start (whale icon stops animating)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Then run installer again." -ForegroundColor White
    throw "Docker is required for Google MCP"
}
Write-Host "  OK" -ForegroundColor Green

# ============================================
# 2. Role Selection (Admin / Employee)
# ============================================
Write-Host ""
Write-Host "What is your role?" -ForegroundColor White
Write-Host "  1. Admin (first-time setup, create OAuth credentials)" -ForegroundColor White
Write-Host "  2. Employee (received client_secret.json from admin)" -ForegroundColor White
Write-Host ""
$roleChoice = Read-Host "Select (1/2)"

if ($roleChoice -eq "1") {
    # ========================================
    # ADMIN PATH - Full Google Cloud Setup
    # ========================================
    Write-Host ""
    Write-Host "=== Google Cloud Admin Setup ===" -ForegroundColor Cyan
    Write-Host ""

    # Check/Install gcloud CLI
    Write-Host "[1/6] Checking gcloud CLI..." -ForegroundColor Yellow
    $gcloudCheck = Get-Command gcloud -ErrorAction SilentlyContinue
    if (-not $gcloudCheck) {
        Write-Host "  gcloud CLI is not installed." -ForegroundColor Red
        $wingetCheck = Get-Command winget -ErrorAction SilentlyContinue
        if ($wingetCheck) {
            Write-Host "  Installing gcloud CLI via winget..." -ForegroundColor Yellow
            winget install Google.CloudSDK --accept-source-agreements --accept-package-agreements
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            $gcloudCheck = Get-Command gcloud -ErrorAction SilentlyContinue
            if (-not $gcloudCheck) {
                Write-Host ""
                Write-Host "gcloud installed but not in PATH yet." -ForegroundColor Yellow
                Write-Host "Please close this window and run the script again." -ForegroundColor White
                throw "Restart required after gcloud installation"
            }
        } else {
            Start-Process "https://cloud.google.com/sdk/docs/install"
            throw "Please install Google Cloud SDK manually, then run again"
        }
    }
    Write-Host "  OK" -ForegroundColor Green

    # gcloud login (always)
    Write-Host ""
    Write-Host "[2/6] Google Cloud login..." -ForegroundColor Yellow
    Write-Host "  Opening browser for login..." -ForegroundColor White
    $ErrorActionPreference = "Continue"
    gcloud auth login --launch-browser 2>&1 | Out-Null
    $ErrorActionPreference = "Stop"
    Read-Host "Press Enter after completing login"

    $ErrorActionPreference = "Continue"
    $account = (gcloud config get-value account 2>&1) | Out-String
    $account = $account.Trim()
    $ErrorActionPreference = "Stop"
    if (-not $account -or $account -match "unset") {
        throw "Login failed or cancelled"
    }
    if ($account -match "[\w\.\-]+@[\w\.\-]+") { $account = $Matches[0] }
    Write-Host "  Logged in as: $account" -ForegroundColor Green

    # Internal vs External
    Write-Host ""
    Write-Host "[3/6] Setup type selection..." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Do you use Google Workspace (company email like @company.com)?" -ForegroundColor White
    Write-Host "  1. Yes - Internal app (unlimited users, no token expiry)" -ForegroundColor White
    Write-Host "  2. No - External app (100 test users, 7-day token expiry)" -ForegroundColor White
    Write-Host ""
    $appTypeChoice = Read-Host "Select (1 or 2)"
    if ($appTypeChoice -eq "1") {
        $appType = "internal"
        Write-Host "  Selected: Internal" -ForegroundColor Green
    } else {
        $appType = "external"
        Write-Host "  Selected: External" -ForegroundColor Green
    }

    # Create or select project
    Write-Host ""
    Write-Host "[4/6] Setting up Google Cloud project..." -ForegroundColor Yellow
    Write-Host "  1. Create new project"
    Write-Host "  2. Use existing project"
    Write-Host ""
    $projectChoice = Read-Host "Select (1 or 2)"

    $ErrorActionPreference = "Continue"
    if ($projectChoice -eq "1") {
        $projectId = "workspace-mcp-" + (Get-Random -Minimum 100000 -Maximum 999999)
        Write-Host "  Creating project: $projectId" -ForegroundColor Yellow
        gcloud projects create $projectId --name="Google Workspace MCP" 2>&1 | Out-Null
        gcloud config set project $projectId 2>&1 | Out-Null
    } else {
        Write-Host ""
        Write-Host "Available projects:" -ForegroundColor White
        gcloud projects list --format="table(projectId,name)"
        Write-Host ""
        $projectId = Read-Host "Enter project ID"
        gcloud config set project $projectId 2>&1 | Out-Null
    }
    $ErrorActionPreference = "Stop"
    Write-Host "  Project: $projectId" -ForegroundColor Green

    # Enable APIs
    Write-Host ""
    Write-Host "[5/6] Enabling APIs..." -ForegroundColor Yellow
    $apis = @(
        "gmail.googleapis.com",
        "calendar-json.googleapis.com",
        "drive.googleapis.com",
        "docs.googleapis.com",
        "sheets.googleapis.com",
        "slides.googleapis.com"
    )
    $ErrorActionPreference = "Continue"
    foreach ($api in $apis) {
        Write-Host "  Enabling $api..." -ForegroundColor DarkGray
        gcloud services enable $api 2>&1 | Out-Null
    }
    $ErrorActionPreference = "Stop"
    Write-Host "  All APIs enabled!" -ForegroundColor Green

    # OAuth Consent Screen (Manual)
    Write-Host ""
    Write-Host "[6/6] OAuth Consent Screen Setup" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  MANUAL STEP REQUIRED" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    $consoleUrl = "https://console.cloud.google.com/apis/credentials/consent?project=$projectId"
    Start-Process $consoleUrl
    Start-Sleep -Seconds 2

    Write-Host "Follow these steps in the browser:" -ForegroundColor White
    Write-Host ""
    Write-Host "  [0] Click 'Get Started' button on the OAuth overview page" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  [1] App Info" -ForegroundColor Cyan
    Write-Host "      - App name: Google Workspace MCP"
    Write-Host "      - User support email: (select your email)"
    Write-Host "      -> Click 'Next'"
    Write-Host ""
    Write-Host "  [2] Audience" -ForegroundColor Cyan
    if ($appType -eq "internal") {
        Write-Host "      - Select 'Internal'" -ForegroundColor Yellow
    } else {
        Write-Host "      - Select 'External'" -ForegroundColor Yellow
    }
    Write-Host "      -> Click 'Next'"
    Write-Host ""
    Write-Host "  [3] Contact Info" -ForegroundColor Cyan
    Write-Host "      - Enter your email address"
    Write-Host "      -> Click 'Next'"
    Write-Host ""
    Write-Host "  [4] Finish -> Check agreement, Click 'Continue'" -ForegroundColor Cyan

    if ($appType -eq "external") {
        Write-Host ""
        Write-Host "  [5] Add TEST USERS in Audience section" -ForegroundColor Yellow
    }

    Write-Host ""
    Read-Host "Press Enter when consent screen is configured"

    # Create OAuth Client
    Write-Host ""
    Write-Host "Now create OAuth Client:" -ForegroundColor Yellow
    Write-Host "  [1] Left menu -> 'Clients'" -ForegroundColor Cyan
    Write-Host "  [2] Click '+ Create Client'" -ForegroundColor White
    Write-Host "  [3] Type: 'Desktop app', Name: any" -ForegroundColor White
    Write-Host "  [4] Click created client -> Download JSON" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Save as:" -ForegroundColor Yellow
    Write-Host "  $env:USERPROFILE\.google-workspace\client_secret.json" -ForegroundColor Cyan
    Write-Host ""

    $configDir = "$env:USERPROFILE\.google-workspace"
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }
    Start-Process explorer.exe -ArgumentList $configDir

    Read-Host "Press Enter when client_secret.json is saved"

    Write-Host ""
    Write-Host "Admin setup complete!" -ForegroundColor Green
    Write-Host "  - Project: $projectId" -ForegroundColor White
    Write-Host "  - Type: $appType" -ForegroundColor White
    Write-Host ""
}

# ========================================
# EMPLOYEE PATH (runs for both Admin and Employee)
# ========================================
Write-Host ""
Write-Host "Setting up Google MCP..." -ForegroundColor Yellow

$configDir = "$env:USERPROFILE\.google-workspace"
if (-not (Test-Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
}

# Check client_secret.json
$clientSecretPath = "$configDir\client_secret.json"
if (-not (Test-Path $clientSecretPath)) {
    Write-Host ""
    Write-Host "client_secret.json required." -ForegroundColor White
    Write-Host "Copy from admin to: $clientSecretPath" -ForegroundColor Cyan
    Write-Host ""
    Start-Process explorer.exe -ArgumentList $configDir
    Read-Host "Press Enter when file is ready"

    if (-not (Test-Path $clientSecretPath)) {
        throw "client_secret.json not found"
    }
}
Write-Host "  client_secret.json found" -ForegroundColor Green

# Pull Docker image
Write-Host ""
Write-Host "[Pull] Google MCP Docker image..." -ForegroundColor Yellow
docker pull ghcr.io/popup-studio-ai/google-workspace-mcp:latest
Write-Host "  OK" -ForegroundColor Green

# OAuth authentication (always - installer runs once)
$tokenPath = "$configDir\token.json"
# Remove existing token to force re-login
if (Test-Path $tokenPath) {
    Remove-Item $tokenPath -Force
}

Write-Host ""
Write-Host "Opening browser for Google login..." -ForegroundColor Yellow

$configDirUnix = $configDir -replace '\\', '/'
$ErrorActionPreference = "Continue"

# Stop any leftover Google MCP auth container
$oldContainer = (docker ps -q --filter "ancestor=ghcr.io/popup-studio-ai/google-workspace-mcp:latest") 2>$null
if ($oldContainer) { docker stop $oldContainer 2>$null | Out-Null; docker rm $oldContainer 2>$null | Out-Null }

# Find a free port for OAuth callback
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
$listener.Start()
$authPort = $listener.LocalEndpoint.Port
$listener.Stop()

# Run auth container in background with dynamic port
$containerId = (docker run -d -p "${authPort}:${authPort}" -e "OAUTH_PORT=$authPort" -v "${configDirUnix}:/app/.google-workspace" ghcr.io/popup-studio-ai/google-workspace-mcp:latest node -e "require('./dist/auth/oauth.js').getAuthenticatedClient().then(() => { console.log('Authentication complete!'); process.exit(0); }).catch(e => { console.error(e); process.exit(1); })") 2>$null
if ($containerId) { $containerId = $containerId.Trim() }

if (-not $containerId) {
    Write-Host "  Failed to start auth container" -ForegroundColor Red
} else {
    # Poll for OAuth URL and auto-open browser
    $opened = $false
    for ($i = 0; $i -lt 60; $i++) {
        $logOutput = docker logs $containerId 2>&1 | Out-String -Width 10000
        if ($logOutput -match "(https://accounts\.google\.com/\S+)") {
            if (-not $opened) {
                $authUrl = $Matches[1]
                Start-Process $authUrl
                Write-Host "  Browser opened for Google login!" -ForegroundColor Green
                Write-Host ""
                Write-Host "  If the browser doesn't open, copy and paste this URL:" -ForegroundColor DarkGray
                Write-Host "  $authUrl" -ForegroundColor Gray
                $opened = $true
            }
            break
        }
        $running = (docker inspect --format='{{.State.Running}}' $containerId 2>$null) | Out-String
        if ($running.Trim() -ne "true") { break }
        Start-Sleep -Milliseconds 200
    }

    if (-not $opened) {
        Write-Host "  Could not detect login URL. Check Docker logs:" -ForegroundColor Yellow
        docker logs $containerId 2>&1 | ForEach-Object { Write-Host "  $_" }
    }

    # Wait for auth to complete
    Write-Host "  Waiting for login to complete..." -ForegroundColor Gray
    docker wait $containerId 2>$null | Out-Null
    docker rm $containerId 2>$null | Out-Null
}
$ErrorActionPreference = "Stop"

if (Test-Path $tokenPath) {
    Write-Host "  Google login successful!" -ForegroundColor Green
} else {
    Write-Host "  Login may have failed. Try again later." -ForegroundColor Yellow
}

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
$configDirUnix = $configDir -replace '\\', '/'
Add-McpDockerServer "google-workspace" "ghcr.io/popup-studio-ai/google-workspace-mcp:latest" @("-v", "${configDirUnix}:/app/.google-workspace")
Add-McpPermission "mcp__google-workspace"

# Remove project-level blocks
Write-Host ""
Write-Host "[Fix] Removing project-level blocks..." -ForegroundColor Yellow
Remove-McpProjectBlock "google-workspace"

Write-Host ""
Write-Host "----------------------------------------" -ForegroundColor DarkGray
Write-Host "Google MCP installation complete!" -ForegroundColor Green
