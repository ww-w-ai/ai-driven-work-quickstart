# ============================================
# Base Module - Claude + bkit Installation
# ============================================
# This module installs: Node.js, Git, VS Code, Docker, Claude CLI, bkit Plugin
# Called by install.ps1, can also run standalone

$preflight = @{
    isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    hasNvm = $false; hasDockerToolbox = $false
    hasNpmClaude = $false; hasCode = $false; hasCodeInsiders = $false
    hasAgy = $false; hasProxy = $false; warnings = @()
}

# ============================================
# Helper Functions
# ============================================
function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path","User")
}

function Test-CommandExists {
    param([string]$Command)
    return [bool](Get-Command $Command -ErrorAction SilentlyContinue)
}

# Mod 3: PATH enhancement - directly add known paths as fallback
function Ensure-InPath {
    param([string]$Dir)
    if ((Test-Path $Dir) -and ($env:PATH -notlike "*$Dir*")) {
        # Apply to current session immediately
        $env:PATH = "$Dir;$env:PATH"

        # Persist to registry permanently
        $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
        if ($userPath -notlike "*$Dir*") {
            [Environment]::SetEnvironmentVariable("PATH", "$userPath;$Dir", "User")
        }
    }
}

# Mod 4: VS Code extension install with error capture (fixes silent failure)
function Install-VSCodeExtension {
    param(
        [string]$ExtensionId,
        [string]$DisplayName,
        [string]$Command = "code"
    )

    if (-not (Test-CommandExists $Command)) {
        Write-Host "  $Command not found in PATH. Skip $DisplayName extension." -ForegroundColor Yellow
        return $false
    }

    Write-Host "  Installing $DisplayName extension..." -ForegroundColor Gray
    $output = & $Command --install-extension $ExtensionId --force 2>&1 | Out-String

    if ($output -like "*Failed*" -or $output -like "*not found*" -or $output -like "*not compatible*") {
        Write-Host "  Warning: $DisplayName extension install may have failed:" -ForegroundColor Yellow
        if ($output -like "*not found*") {
            Write-Host "    Extension ID '$ExtensionId' not found in marketplace." -ForegroundColor Yellow
        } elseif ($output -like "*not compatible*") {
            Write-Host "    Extension requires newer $Command version. Update your IDE." -ForegroundColor Yellow
        } elseif ($output -like "*signature*") {
            Write-Host "    Signature verification failed. Corporate proxy may be modifying downloads." -ForegroundColor Yellow
        } else {
            $trimmed = $output.Trim()
            if ($trimmed.Length -gt 200) { $trimmed = $trimmed.Substring(0, 200) + "..." }
            Write-Host "    $trimmed" -ForegroundColor Gray
        }
        return $false
    } else {
        Write-Host "  $DisplayName extension OK" -ForegroundColor Green
        return $true
    }
}

# Mod 8: winget install with --scope user fallback for non-admin
function Install-WithWinget {
    param(
        [string]$PackageId,
        [string]$DisplayName
    )

    $baseArgs = @("install", $PackageId, "--accept-source-agreements", "--accept-package-agreements", "-h")
    & winget @baseArgs
    Refresh-Path

    # If failed and not admin, retry with --scope user
    if ($LASTEXITCODE -ne 0 -and -not $preflight.isAdmin) {
        Write-Host "  Retrying with --scope user..." -ForegroundColor Gray
        $userArgs = $baseArgs + @("--scope", "user")
        & winget @userArgs
        Refresh-Path
    }
}

# ============================================
# 1. Check winget
# ============================================
Write-Host "[1/8] Checking winget..." -ForegroundColor Yellow
if (-not (Test-CommandExists "winget")) {
    Write-Host ""
    Write-Host "winget not found!" -ForegroundColor Red
    if ($preflight.isLTSC) {
        Write-Host "LTSC/Server edition detected. winget is not pre-installed." -ForegroundColor Yellow
        Write-Host "Install manually from: https://github.com/microsoft/winget-cli/releases" -ForegroundColor Cyan
    } else {
        Write-Host "Please update Windows or install App Installer from Microsoft Store:" -ForegroundColor White
        Write-Host "https://apps.microsoft.com/store/detail/app-installer/9NBLGGH4NNS1" -ForegroundColor Cyan
    }
    throw "winget is required"
}
Write-Host "  OK" -ForegroundColor Green

# ============================================
# 2. Node.js
# ============================================
Write-Host ""
Write-Host "[2/8] Checking Node.js..." -ForegroundColor Yellow
try {
    # Mod 7: nvm detection - skip winget install if nvm manages Node.js
    if ($preflight.hasNvm) {
        Write-Host "  nvm detected. Skipping winget Node.js install (managed by nvm)." -ForegroundColor Gray
        if (Test-CommandExists "node") {
            Write-Host "  OK - $(node --version) (via nvm)" -ForegroundColor Green
        } else {
            Write-Host "  nvm found but no Node.js version active. Run: nvm install lts" -ForegroundColor Yellow
        }
    } elseif (-not (Test-CommandExists "node")) {
        Write-Host "  Installing Node.js LTS..." -ForegroundColor Gray
        Install-WithWinget -PackageId "OpenJS.NodeJS.LTS" -DisplayName "Node.js"
        Ensure-InPath "$env:ProgramFiles\nodejs"
        Ensure-InPath "${env:ProgramFiles(x86)}\nodejs"

        if (Test-CommandExists "node") {
            Write-Host "  OK - $(node --version)" -ForegroundColor Green
        } else {
            Write-Host "  Installed (restart terminal to use)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  OK - $(node --version)" -ForegroundColor Green
    }
} catch {
    Write-Host "  Node.js install failed: $_" -ForegroundColor Red
    if ($preflight.hasProxy) {
        Write-Host "  Proxy detected. Check proxy settings for winget." -ForegroundColor Yellow
    }
    Write-Host "  Manual install: https://nodejs.org/" -ForegroundColor Cyan
}

# ============================================
# 3. Git
# ============================================
Write-Host ""
Write-Host "[3/8] Checking Git..." -ForegroundColor Yellow
try {
    if (-not (Test-CommandExists "git")) {
        Write-Host "  Installing Git..." -ForegroundColor Gray
        Install-WithWinget -PackageId "Git.Git" -DisplayName "Git"
        Ensure-InPath "$env:ProgramFiles\Git\cmd"

        if (Test-CommandExists "git") {
            Write-Host "  OK - $(git --version)" -ForegroundColor Green
        } else {
            Write-Host "  Installed (restart terminal to use)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  OK - $(git --version)" -ForegroundColor Green
    }

    # Git recommended settings (longpaths + UTF-8)
    if (Test-CommandExists "git") {
        git config --global core.longpaths true 2>$null
        git config --global core.quotepath false 2>$null
    }
} catch {
    Write-Host "  Git install failed: $_" -ForegroundColor Red
    if ($preflight.hasProxy) {
        Write-Host "  Proxy detected. Check proxy settings." -ForegroundColor Yellow
    }
    Write-Host "  Manual install: https://git-scm.com/" -ForegroundColor Cyan
}

# ============================================
# 4. VS Code
# ============================================
Write-Host ""
Write-Host "[4/8] Checking VS Code..." -ForegroundColor Yellow
try {
    $vscodePaths = @(
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe",
        "$env:ProgramFiles\Microsoft VS Code\Code.exe"
    )
    $vscodeInstalled = $false
    foreach ($path in $vscodePaths) {
        if (Test-Path $path) { $vscodeInstalled = $true; break }
    }
    if (-not $vscodeInstalled) {
        Write-Host "  Installing VS Code..." -ForegroundColor Gray
        Install-WithWinget -PackageId "Microsoft.VisualStudioCode" -DisplayName "VS Code"
        Ensure-InPath "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin"
        Ensure-InPath "$env:ProgramFiles\Microsoft VS Code\bin"
    }
    Refresh-Path
    Write-Host "  OK" -ForegroundColor Green

    # Determine correct IDE command (code vs code-insiders)
    $codeCmd = "code"
    if ($preflight.hasCodeInsiders -and -not $preflight.hasCode) {
        $codeCmd = "code-insiders"
    }

    # Install IDE extension based on CLI type
    if ($env:CLI_TYPE -eq "gemini") {
        Install-VSCodeExtension -ExtensionId "Google.gemini-cli-vscode-ide-companion" -DisplayName "Gemini CLI Companion" -Command $codeCmd
    } else {
        Install-VSCodeExtension -ExtensionId "anthropic.claude-code" -DisplayName "Claude Code" -Command $codeCmd
    }
} catch {
    Write-Host "  VS Code install failed: $_" -ForegroundColor Red
    Write-Host "  Manual install: https://code.visualstudio.com/" -ForegroundColor Cyan
}

# ============================================
# 5. WSL (Windows Subsystem for Linux)
# ============================================
Write-Host ""
Write-Host "[5/8] Checking WSL..." -ForegroundColor Yellow
$script:WslNeedsRestart = $false
if ($script:needsDocker) {
    try {
        $prevErrorAction = $ErrorActionPreference
        $ErrorActionPreference = "Continue"

        $wslInstalled = $false
        wsl --version 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $wslInstalled = $true
        }

        if ($wslInstalled) {
            Write-Host "  Updating WSL..." -ForegroundColor Gray
            wsl --update 2>&1 | Out-Null
            Write-Host "  OK (up to date)" -ForegroundColor Green
        } else {
            if (-not $preflight.isAdmin) {
                Write-Host "  WSL install requires admin rights. Please run as Administrator." -ForegroundColor Yellow
            } else {
                Write-Host "  Installing WSL..." -ForegroundColor Gray
                wsl --install --no-distribution 2>&1 | Out-Null
                $script:WslNeedsRestart = $true
                Write-Host "  Installed (system restart required)" -ForegroundColor Yellow
            }
        }

        $ErrorActionPreference = $prevErrorAction
    } catch {
        Write-Host "  WSL setup failed: $_" -ForegroundColor Red
        if (-not $preflight.isVirtualization) {
            Write-Host "  BIOS virtualization may be disabled. Enable VT-x/AMD-V." -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "  Skipped (not required by selected modules)" -ForegroundColor Gray
}

# ============================================
# 6. Docker Desktop (only if needed)
# ============================================
Write-Host ""
Write-Host "[6/8] Checking Docker Desktop..." -ForegroundColor Yellow
$script:DockerNeedsRestart = $false
if ($script:needsDocker) {
    try {
        # Mod 7: Docker Toolbox conflict detection
        if ($preflight.hasDockerToolbox) {
            Write-Host "  Docker Toolbox detected. May conflict with Docker Desktop." -ForegroundColor Yellow
            Write-Host "  Recommend: Uninstall Docker Toolbox first." -ForegroundColor Yellow
            if ([Environment]::UserInteractive -and -not $env:NONINTERACTIVE) {
                Write-Host "  Continue anyway? (Y/N) " -ForegroundColor White -NoNewline
                $continue = Read-Host
                if ($continue -ne "Y" -and $continue -ne "y") { throw "Cancelled by user" }
            }
        }

        if (-not (Test-CommandExists "docker")) {
            if (-not $preflight.isAdmin) {
                Write-Host "  Docker Desktop install requires admin rights. Please run as Administrator." -ForegroundColor Yellow
            } else {
                Write-Host "  Installing Docker Desktop (this may take a few minutes)..." -ForegroundColor Gray
                Install-WithWinget -PackageId "Docker.DockerDesktop" -DisplayName "Docker Desktop"
                $script:DockerNeedsRestart = $true
                Write-Host "  Installed (system restart required)" -ForegroundColor Yellow
            }
        } else {
            # Docker daemon running check
            $dockerInfo = docker info 2>&1 | Out-String
            if ($dockerInfo -like "*Cannot connect*" -or $dockerInfo -like "*error*") {
                Write-Host "  OK (installed but Docker Desktop is not running)" -ForegroundColor Yellow
                Write-Host "  Start Docker Desktop before using Docker features." -ForegroundColor Yellow
            } else {
                Write-Host "  OK" -ForegroundColor Green
            }
        }
    } catch {
        Write-Host "  Docker install failed: $_" -ForegroundColor Red
        if (-not $preflight.isVirtualization) {
            Write-Host "  BIOS virtualization may be disabled." -ForegroundColor Yellow
        }
        Write-Host "  Manual install: https://www.docker.com/products/docker-desktop/" -ForegroundColor Cyan
    }
} else {
    Write-Host "  Skipped (not required by selected modules)" -ForegroundColor Gray
}

# ============================================
# 7. AI CLI (Claude or Gemini)
# ============================================
Write-Host ""
if ($env:CLI_TYPE -eq "gemini") {
    Write-Host "[7/8] Checking Gemini CLI..." -ForegroundColor Yellow
    try {
        Refresh-Path
        if (-not (Test-CommandExists "gemini")) {
            if (-not (Test-CommandExists "npm")) {
                Write-Host "  npm not found. Node.js is required for Gemini CLI." -ForegroundColor Red
                Write-Host "  Install Node.js first, then retry." -ForegroundColor Yellow
            } else {
                Write-Host "  Installing Gemini CLI..." -ForegroundColor Gray
                npm install -g @google/gemini-cli
                Refresh-Path
            }
        }
        if (Test-CommandExists "gemini") {
            $geminiVersion = gemini --version 2>$null
            Write-Host "  OK - $geminiVersion" -ForegroundColor Green
        } else {
            Write-Host "  Installed (restart terminal to use)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  Gemini CLI install failed: $_" -ForegroundColor Red
        if ($preflight.hasProxy) {
            Write-Host "  Proxy detected. Run: npm config set proxy $($preflight.proxyServer)" -ForegroundColor Yellow
        }
        Write-Host "  Manual install: npm install -g @google/gemini-cli" -ForegroundColor Cyan
    }
} else {
    Write-Host "[7/8] Checking Claude Code CLI..." -ForegroundColor Yellow
    try {
        Refresh-Path

        # Mod 7: Remove conflicting npm global Claude CLI
        if ($preflight.hasNpmClaude) {
            Write-Host "  Removing npm global Claude CLI to avoid conflict..." -ForegroundColor Gray
            npm uninstall -g @anthropic-ai/claude-code 2>$null
        }

        if (-not (Test-CommandExists "claude")) {
            Write-Host "  Installing Claude Code CLI (native)..." -ForegroundColor Gray
            irm https://claude.ai/install.ps1 | iex
            Refresh-Path
            # Native install puts claude in ~/.local/bin
            Ensure-InPath "$env:USERPROFILE\.local\bin"
        }
        if (Test-CommandExists "claude") {
            $claudeVersion = claude --version 2>$null
            Write-Host "  OK - $claudeVersion" -ForegroundColor Green
        } else {
            Write-Host "  Installed (restart terminal to use)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  Claude CLI install failed: $_" -ForegroundColor Red
        if ($preflight.hasProxy) {
            Write-Host "  Proxy detected. Corporate firewall may block claude.ai" -ForegroundColor Yellow
        }
        Write-Host "  Manual install: irm https://claude.ai/install.ps1 | iex" -ForegroundColor Cyan
    }
}

# ============================================
# 8. bkit Plugin
# ============================================
Write-Host ""
if ($env:CLI_TYPE -eq "gemini") {
    Write-Host "[8/8] Installing bkit Plugin (Gemini)..." -ForegroundColor Yellow
    try {
        if (-not (Test-CommandExists "gemini")) {
            Write-Host "  Gemini CLI not found. Skipping bkit plugin." -ForegroundColor Yellow
        } else {
            $ErrorActionPreference = "SilentlyContinue"
            "y" | gemini extensions install https://github.com/ww-w-ai/bkit-gemini.git 2>$null
            $ErrorActionPreference = "Stop"
            Write-Host "  OK" -ForegroundColor Green
        }
    } catch {
        Write-Host "  bkit plugin install failed: $_" -ForegroundColor Red
        Write-Host "  Manual install: gemini extensions install https://github.com/ww-w-ai/bkit-gemini.git" -ForegroundColor Cyan
    }
} else {
    Write-Host "[8/8] Installing bkit Plugin..." -ForegroundColor Yellow
    try {
        if (-not (Test-CommandExists "claude")) {
            Write-Host "  Claude CLI not found. Skipping bkit plugin." -ForegroundColor Yellow
        } else {
            $ErrorActionPreference = "SilentlyContinue"
            claude plugin marketplace add ww-w-ai/bkit-claude-code 2>$null
            claude plugin install bkit@bkit-marketplace 2>$null
            $ErrorActionPreference = "Stop"

            $bkitCheck = claude plugin list 2>$null | Select-String "bkit"
            if ($bkitCheck) {
                Write-Host "  OK" -ForegroundColor Green
            } else {
                Write-Host "  Installed (verify with 'claude plugin list')" -ForegroundColor Yellow
            }
        }
    } catch {
        Write-Host "  bkit plugin install failed: $_" -ForegroundColor Red
        Write-Host "  Manual: claude plugin marketplace add ww-w-ai/bkit-claude-code" -ForegroundColor Cyan
    }
}

# ============================================
# Summary
# ============================================
Write-Host ""
Write-Host "----------------------------------------" -ForegroundColor DarkGray
Write-Host "Base installation complete!" -ForegroundColor Green

if ($script:WslNeedsRestart -or $script:DockerNeedsRestart) {
    Write-Host ""
    if ($script:WslNeedsRestart) {
        Write-Host "IMPORTANT: WSL was installed." -ForegroundColor Yellow
    }
    if ($script:DockerNeedsRestart) {
        Write-Host "IMPORTANT: Docker Desktop was installed." -ForegroundColor Yellow
    }
    Write-Host "  1. Restart your computer" -ForegroundColor White
    Write-Host "  2. Start Docker Desktop" -ForegroundColor White
    Write-Host "  3. Run installer again with -skipBase flag:" -ForegroundColor White
    Write-Host "     .\install.ps1 -modules `"google,atlassian`" -skipBase" -ForegroundColor Cyan
}
