# rafa-once.ps1
# Run from the Rafa folder: ./rafa-once.ps1

Set-Location $PSScriptRoot

$ts     = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$date   = Get-Date -Format "yyyy-MM-dd HH:mm"
$prompt = (Get-Content "$PSScriptRoot\rafa-prompt.txt" -Raw).Replace("{{DATE}}", $date)

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host "  Rafa - Single Task Run"
Write-Host "  $ts"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""

claude -p --dangerously-skip-permissions $prompt
