# ============================================
# ADW Installation Diagnostic Tool (Windows)
# ============================================
# Run this if installation failed:
#   powershell -ep bypass -c "irm https://raw.githubusercontent.com/ww-w-ai/ai-driven-work-quickstart/main/installer/diagnose.ps1 | iex"

$BaseUrl = "https://raw.githubusercontent.com/ww-w-ai/ai-driven-work-quickstart/main/installer"

Clear-Host
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  ADW Installation Diagnostic" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Checking your environment for potential" -ForegroundColor Gray
Write-Host "installation issues..." -ForegroundColor Gray
Write-Host ""

try {
    $preflightContent = irm "$BaseUrl/modules/shared/preflight.ps1" -ErrorAction Stop
    Invoke-Expression $preflightContent
} catch {
    if ($_.Exception.Message -like "*Cancelled*") {
        Write-Host "Diagnostic cancelled." -ForegroundColor Yellow
    } else {
        Write-Host "Diagnostic failed: $_" -ForegroundColor Red
        Write-Host "Check your internet connection and try again." -ForegroundColor Gray
    }
}

Write-Host ""
Read-Host "Press Enter to close"
