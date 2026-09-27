# ============================================
# AI-Driven Work Installer (ADW) - Windows
# ============================================
# Dynamic Module Loading System (Folder Scan)
#
# Usage:
#   .\install.ps1 -modules "google,atlassian"
#   .\install.ps1 -all
#   .\install.ps1 -installDocker
#   .\install.ps1 -list
#
# Remote (Step 1 - base + Docker):
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/.../install.ps1))) -installDocker
#
# Remote (Step 2 - modules only):
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/.../install.ps1))) -modules "google" -skipBase

param(
    [string]$modules = "",       # Comma-separated module list
    [string]$cli = "",           # CLI type: claude or gemini
    [switch]$all,                # Install all modules
    [switch]$skipBase,           # Skip base module
    [switch]$installDocker,      # Force Docker installation (for Step 1)
    [switch]$list                # List available modules
)

# ============================================
# Environment Variable Support
# ============================================
# $env:MODULES        - Module selection (e.g., "google", "google,atlassian")
# $env:SKIP_BASE      - Skip base module ("true" or "1")
# $env:INSTALL_ALL    - Install all modules ("true" or "1")
# $env:INSTALL_DOCKER - Force Docker installation ("true" or "1")
#
# Step 1: $env:INSTALL_DOCKER='true'; irm .../install.ps1 | iex
# Step 2: $env:MODULES='google'; $env:SKIP_BASE='true'; irm .../install.ps1 | iex
if (-not $modules -and $env:MODULES) {
    $modules = $env:MODULES
}
if (-not $cli -and $env:CLI_TYPE) {
    $cli = $env:CLI_TYPE
}
if (-not $cli) { $cli = "claude" }
if ($cli -ne "claude" -and $cli -ne "gemini") {
    Write-Host "Invalid -cli value: $cli (use 'claude' or 'gemini')" -ForegroundColor Red
    exit 1
}
$env:CLI_TYPE = $cli
if ($env:SKIP_BASE -eq "true" -or $env:SKIP_BASE -eq "1") {
    $skipBase = $true
}
if ($env:INSTALL_ALL -eq "true" -or $env:INSTALL_ALL -eq "1") {
    $all = $true
}

# Base URL for module downloads - GitHub raw (always latest from master)
$BaseUrl = "https://raw.githubusercontent.com/ww-w-ai/ai-driven-work-quickstart/main/installer"

# For local development, use local files
# Remote execution sets $MyInvocation.MyCommand.Path to null, so check needed
$ScriptPath = $MyInvocation.MyCommand.Path
if ($ScriptPath) {
    $ScriptDir = Split-Path -Parent $ScriptPath
    $UseLocal = Test-Path "$ScriptDir\modules"
} else {
    $ScriptDir = $null
    $UseLocal = $false
}

# ============================================
# 1. Scan Modules Folder (before admin check for -list)
# ============================================
function Get-AvailableModules {
    $moduleList = @()

    if ($UseLocal) {
        # Local: scan modules/ folder
        $moduleDirs = Get-ChildItem "$ScriptDir\modules" -Directory
        foreach ($dir in $moduleDirs) {
            $jsonPath = "$($dir.FullName)\module.json"
            if (Test-Path $jsonPath) {
                $moduleJson = Get-Content $jsonPath -Raw | ConvertFrom-Json
                $moduleList += $moduleJson
            }
        }
    } else {
        # Remote: fetch module list from modules.json
        try {
            $modulesIndex = irm "$BaseUrl/modules.json" -ErrorAction SilentlyContinue
            if ($modulesIndex -and $modulesIndex.modules) {
                # Only download full module.json for modules we actually need
                $needFullMeta = @("base")
                if ($modules) { $needFullMeta += ($modules -split "," | ForEach-Object { $_.Trim() }) }
                $loadAll = $all -or $list

                foreach ($mod in $modulesIndex.modules) {
                    if ($loadAll -or ($mod.name -in $needFullMeta)) {
                        try {
                            $moduleJson = irm "$BaseUrl/modules/$($mod.name)/module.json" -ErrorAction SilentlyContinue
                            if ($moduleJson) {
                                $moduleList += $moduleJson
                                continue
                            }
                        } catch {}
                    }
                    # Minimal entry for name validation (no HTTP request)
                    $moduleList += [PSCustomObject]@{
                        name = $mod.name
                        order = $mod.order
                        displayName = $mod.name
                        description = ""
                        required = $false
                    }
                }
            }
        } catch {}
    }

    # Sort by order
    return $moduleList | Sort-Object { $_.order }
}

# ============================================
# 2. List Mode (no admin required)
# ============================================
if ($list) {
    $availableModules = Get-AvailableModules
    Clear-Host
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Available Modules" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    foreach ($mod in $availableModules) {
        $required = if ($mod.required) { "(required)" } else { "" }
        $complexity = "[$($mod.complexity)]"

        Write-Host "  $($mod.name)" -ForegroundColor Green -NoNewline
        Write-Host " $required" -ForegroundColor Yellow -NoNewline
        Write-Host " $complexity" -ForegroundColor DarkGray
        Write-Host "    $($mod.description)" -ForegroundColor Gray
        Write-Host ""
    }

    Write-Host "Usage:" -ForegroundColor White
    Write-Host "  .\install.ps1 -modules `"google,atlassian`"" -ForegroundColor Gray
    Write-Host "  .\install.ps1 -all" -ForegroundColor Gray
    Write-Host ""
    exit
}

# ============================================
# 3. Smart Status Check (must be before Admin Check)
# ============================================
$script:_cachedStatus = $null

function Get-InstallStatus {
    param([switch]$CheckDocker)

    if ($script:_cachedStatus) {
        # Return cached result, but run Docker checks if newly requested
        if ($CheckDocker -and -not $script:_cachedStatus._dockerChecked) {
            $prevEA = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            wsl --version 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) { $script:_cachedStatus.WSL = $true }
            $ErrorActionPreference = $prevEA

            if ($script:_cachedStatus.Docker) {
                $null = docker info 2>&1
                $script:_cachedStatus.DockerRunning = ($LASTEXITCODE -eq 0)
            }
            $script:_cachedStatus._dockerChecked = $true
        }
        return $script:_cachedStatus
    }

    $cliCmd = if ($env:CLI_TYPE -eq "gemini") { "gemini" } else { "claude" }
    $status = @{
        NodeJS = [bool](Get-Command node -ErrorAction SilentlyContinue)
        Git = [bool](Get-Command git -ErrorAction SilentlyContinue)
        IDE = $false
        WSL = $false
        Docker = [bool](Get-Command docker -ErrorAction SilentlyContinue)
        DockerRunning = $false
        CLI = [bool](Get-Command $cliCmd -ErrorAction SilentlyContinue)
        Bkit = $false
        _dockerChecked = $false
    }

    # IDE check
    $status.IDE = (Test-Path "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe") -or (Test-Path "$env:ProgramFiles\Microsoft VS Code\Code.exe")

    # WSL & Docker checks: only when explicitly requested (slow on fresh machines)
    if ($CheckDocker) {
        $prevEA = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        wsl --version 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { $status.WSL = $true }
        $ErrorActionPreference = $prevEA

        if ($status.Docker) {
            $null = docker info 2>&1
            $status.DockerRunning = ($LASTEXITCODE -eq 0)
        }
        $status._dockerChecked = $true
    }

    if ($status.CLI) {
        if ($env:CLI_TYPE -ne "gemini") {
            $bkitCheck = claude plugin list 2>$null | Select-String "bkit"
            $status.Bkit = [bool]$bkitCheck
        }
    }

    $script:_cachedStatus = $status
    return $status
}

# ============================================
# 4. Admin Check & Elevation (always elevate)
# ============================================
function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Host "Restarting as administrator..." -ForegroundColor Yellow

    $params = @()
    if ($modules) { $params += "-modules '$modules'" }
    if ($cli -ne "claude") { $params += "-cli '$cli'" }
    if ($all) { $params += "-all" }
    if ($skipBase) { $params += "-skipBase" }
    if ($installDocker) { $params += "-installDocker" }
    $paramString = $params -join " "

    if ($UseLocal) {
        Start-Process PowerShell -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$ScriptDir\install.ps1`" $paramString"
    } else {
        $scriptUrl = "$BaseUrl/install.ps1"
        Start-Process PowerShell -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -c `"& ([scriptblock]::Create((irm $scriptUrl))) $paramString`""
    }
    exit
}

# Load modules for installation
$availableModules = Get-AvailableModules

# ============================================
# 4. Parse Module Selection
# ============================================
$selectedModules = @()

if ($all) {
    # All non-required modules
    $selectedModules = $availableModules | Where-Object { -not $_.required } | Select-Object -ExpandProperty name
} elseif ($modules) {
    $selectedModules = $modules -split "," | ForEach-Object { $_.Trim() }
}

# Validate modules
$validNames = $availableModules | Select-Object -ExpandProperty name
foreach ($mod in $selectedModules) {
    if ($mod -notin $validNames) {
        Write-Host "Unknown module: $mod" -ForegroundColor Red
        Write-Host "Use -list to see available modules." -ForegroundColor Gray
        exit 1
    }
}

Clear-Host
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  AI-Driven Work Installer v2" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================
# System Requirements Check (skip in CI)
# ============================================
if ($env:CI -ne "true") {
    $ramGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
    $cpuCores = (Get-CimInstance Win32_Processor).NumberOfCores
    $diskFreeGB = [math]::Round((Get-PSDrive C).Free / 1GB)

    $minRAM = 8
    $minCPU = 4
    $minDisk = 10

    $specFailed = $false
    $specMessages = @()
    if ($ramGB -lt $minRAM) { $specMessages += "RAM: ${ramGB}GB (minimum: ${minRAM}GB)"; $specFailed = $true }
    if ($cpuCores -lt $minCPU) { $specMessages += "CPU: ${cpuCores} cores (minimum: ${minCPU} cores)"; $specFailed = $true }
    if ($diskFreeGB -lt $minDisk) { $specMessages += "Disk: ${diskFreeGB}GB free (minimum: ${minDisk}GB)"; $specFailed = $true }

    if ($specFailed) {
        Write-Host "System Requirements Check:" -ForegroundColor Red
        foreach ($msg in $specMessages) {
            Write-Host "  $msg" -ForegroundColor Red
        }
        Write-Host ""
        Write-Host "Your system does not meet the minimum requirements for installation." -ForegroundColor Red
        Write-Host ""
        Read-Host "Press Enter to exit"
        exit 1
    }
}

# Check Docker requirement for selected modules (before status check)
$script:needsDocker = $false
$script:needsDockerRunning = $false
# Parameter or environment variable to force Docker installation (for Step 1)
if ($installDocker -or $env:INSTALL_DOCKER -eq "true" -or $env:INSTALL_DOCKER -eq "1") {
    $script:needsDocker = $true
}
foreach ($modName in $selectedModules) {
    $mod = $availableModules | Where-Object { $_.name -eq $modName }
    if ($mod.requirements.docker) {
        $script:needsDocker = $true
        $script:needsDockerRunning = $true
        break
    }
}

# Run status check (WSL/Docker only when needed - saves 20-60s on fresh machines)
if ($script:needsDocker) {
    $status = Get-InstallStatus -CheckDocker
} else {
    $status = Get-InstallStatus
}

$ideLabel = "VS Code"
$cliLabel = if ($env:CLI_TYPE -eq "gemini") { "Gemini" } else { "Claude" }

Write-Host "Current Status: (CLI: $($env:CLI_TYPE))" -ForegroundColor White
Write-Host "  Node.js:     $(if($status.NodeJS){'[OK]'}else{'[  ]'})" -ForegroundColor $(if($status.NodeJS){'Green'}else{'DarkGray'})
Write-Host "  Git:         $(if($status.Git){'[OK]'}else{'[  ]'})" -ForegroundColor $(if($status.Git){'Green'}else{'DarkGray'})
Write-Host "  ${ideLabel}:  $(if($status.IDE){'[OK]'}else{'[  ]'})" -ForegroundColor $(if($status.IDE){'Green'}else{'DarkGray'})
if ($script:needsDocker) {
    Write-Host "  WSL:         $(if($status.WSL){'[OK]'}else{'[  ]'})" -ForegroundColor $(if($status.WSL){'Green'}else{'DarkGray'})
    Write-Host "  Docker:      $(if($status.Docker){'[OK]'}else{'[  ]'}) $(if($status.Docker -and $status.DockerRunning){'(Running)'}elseif($status.Docker){'(Not Running)'}else{''})" -ForegroundColor $(if($status.DockerRunning){'Green'}elseif($status.Docker){'Yellow'}else{'DarkGray'})
}
Write-Host "  ${cliLabel}:  $(if($status.CLI){'[OK]'}else{'[  ]'})" -ForegroundColor $(if($status.CLI){'Green'}else{'DarkGray'})
Write-Host "  bkit:        $(if($status.Bkit){'[OK]'}else{'[  ]'})" -ForegroundColor $(if($status.Bkit){'Green'}else{'DarkGray'})
Write-Host ""

if ($script:needsDockerRunning -and $status.Docker -and -not $status.DockerRunning) {
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "  Docker Desktop is not running!" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Selected modules require Docker to be running." -ForegroundColor White
    Write-Host ""
    Write-Host "How to start:" -ForegroundColor Gray
    Write-Host "  - Press Windows key, type 'Docker Desktop', Enter" -ForegroundColor Gray
    Write-Host ""
    $dockerWait = Read-Host "Press Enter after starting Docker (or 'q' to quit)"
    if ($dockerWait -eq 'q') { exit 0 }

    $null = docker info 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Docker still not running. Please start it and try again." -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
    Write-Host "Docker is now running!" -ForegroundColor Green
    Write-Host ""
}

# Auto-skip base if all required tools installed
$baseInstalled = $status.NodeJS -and $status.Git -and $status.CLI -and $status.Bkit
if ($script:needsDocker) {
    $baseInstalled = $baseInstalled -and $status.WSL -and $status.Docker
}
if ($baseInstalled -and -not $skipBase -and $selectedModules.Count -gt 0) {
    Write-Host "All base tools are already installed. Skipping base." -ForegroundColor Green
    $skipBase = $true
    Write-Host ""
}

# ============================================
# 6. Calculate Steps & Show Selection
# ============================================
$totalSteps = 0
if (-not $skipBase) { $totalSteps++ }
$totalSteps += $selectedModules.Count

if ($totalSteps -eq 0) {
    $totalSteps = 1
    $skipBase = $false
}

$baseLabel = if ($env:CLI_TYPE -eq "gemini") { "Base (Gemini + bkit)" } else { "Base (Claude + bkit)" }
Write-Host "Selected modules:" -ForegroundColor White
if (-not $skipBase) {
    Write-Host "  [*] $baseLabel" -ForegroundColor Green
} else {
    Write-Host "  [ ] Base (skipped)" -ForegroundColor DarkGray
}
foreach ($modName in $selectedModules) {
    $mod = $availableModules | Where-Object { $_.name -eq $modName }
    Write-Host "  [*] $($mod.displayName)" -ForegroundColor Green
}
Write-Host ""
Read-Host "Press Enter to start installation"

# ============================================
# 7. Module Execution Function
# ============================================
function Invoke-Module {
    param(
        [string]$ModuleName,
        [int]$Step,
        [int]$Total
    )

    $mod = $availableModules | Where-Object { $_.name -eq $ModuleName }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  [$Step/$Total] $($mod.displayName)" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  $($mod.description)" -ForegroundColor Gray
    Write-Host ""

    try {
        if ($UseLocal) {
            . "$ScriptDir\modules\$ModuleName\install.ps1"
        } else {
            irm "$BaseUrl/modules/$ModuleName/install.ps1" | iex
        }
    } catch {
        Write-Host ""
        Write-Host "Error in $($mod.displayName): $_" -ForegroundColor Red
        Write-Host "Installation aborted." -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
}

# ============================================
# 8. Execute Modules
# ============================================
$currentStep = 0

# Base module
if (-not $skipBase) {
    $currentStep++
    Invoke-Module -ModuleName "base" -Step $currentStep -Total $totalSteps
}

# Selected modules (sorted by order)
$sortedModules = $selectedModules | Sort-Object { ($availableModules | Where-Object { $_.name -eq $_ }).order }
foreach ($modName in $sortedModules) {
    $currentStep++
    Invoke-Module -ModuleName $modName -Step $currentStep -Total $totalSteps
}

# ============================================
# 9. Completion Summary
# ============================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Installation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Installed:" -ForegroundColor White

if (-not $skipBase) {
    if (Get-Command node -ErrorAction SilentlyContinue) { Write-Host "  [OK] Node.js" -ForegroundColor Green }
    if (Get-Command git -ErrorAction SilentlyContinue) { Write-Host "  [OK] Git" -ForegroundColor Green }
    if ($script:needsDocker) {
        if (Get-Command docker -ErrorAction SilentlyContinue) { Write-Host "  [OK] Docker" -ForegroundColor Green }
    }
    $cliCmd = if ($env:CLI_TYPE -eq "gemini") { "gemini" } else { "claude" }
    if (Get-Command $cliCmd -ErrorAction SilentlyContinue) { Write-Host "  [OK] $cliLabel CLI" -ForegroundColor Green }
    if ($env:CLI_TYPE -eq "gemini") {
        Write-Host "  [OK] bkit Plugin (Gemini)" -ForegroundColor Green
    } else {
        $bkitCheck = claude plugin list 2>$null | Select-String "bkit"
        if ($bkitCheck) { Write-Host "  [OK] bkit Plugin" -ForegroundColor Green }
    }
}

# Check MCP config
if ($env:CLI_TYPE -eq "gemini") {
    $mcpConfigPath = "$env:USERPROFILE\.gemini\settings.json"
} else {
    $mcpConfigPath = "$env:USERPROFILE\.claude\mcp.json"
}
if (Test-Path $mcpConfigPath) {
    $mcpJson = Get-Content $mcpConfigPath -Raw | ConvertFrom-Json
    foreach ($modName in $sortedModules) {
        $mod = $availableModules | Where-Object { $_.name -eq $modName }

        if ($mod.type -eq "remote-mcp") {
            # Remote MCP servers are registered via 'claude mcp add', not in .mcp.json
            Write-Host "  [OK] $($mod.displayName) (Remote MCP)" -ForegroundColor Green
        } elseif ($mod.mcpConfig -and $mod.mcpConfig.serverName) {
            if ($mcpJson.mcpServers.$($mod.mcpConfig.serverName)) {
                Write-Host "  [OK] $($mod.displayName)" -ForegroundColor Green
            }
        } elseif ($mod.type -eq "cli") {
            Write-Host "  [OK] $($mod.displayName)" -ForegroundColor Green
        }
    }
}

Write-Host ""
cmd /c pause
