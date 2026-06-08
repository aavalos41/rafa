# afk-rafa.ps1
# Run from the Rafa folder: ./afk-rafa.ps1 -n <iterations>
#
# Examples:
#   ./afk-rafa.ps1 -n 5     # Run up to 5 tasks
#   ./afk-rafa.ps1 -n 20    # Run up to 20 tasks
#
# Stops early when all eligible tasks are complete.

param(
    [Parameter(Mandatory=$true)]
    [ValidateRange(1, 1000)]
    [int]$n
)

Set-Location $PSScriptRoot

$ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host "  Rafa - AFK Mode  (max $n tasks)"
Write-Host "  $ts"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""

$completed = 0

for ($i = 1; $i -le $n; $i++) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "┌─ Task $i of $n ────────────────────────────────────"
    Write-Host "│  $ts"
    Write-Host "│"

    $date   = Get-Date -Format "yyyy-MM-dd HH:mm"
    $prompt = (Get-Content "$PSScriptRoot\rafa-prompt.txt" -Raw).Replace("{{DATE}}", $date)

    $result = claude -p --dangerously-skip-permissions $prompt

    $result -split "`n" | ForEach-Object { Write-Host "│  $_" }

    $completed++

    if ($result -match "<promise>COMPLETE</promise>") {
        Write-Host "│"
        Write-Host "└─ ✅ All eligible tasks complete after $i iteration(s)."
        Write-Host ""
        exit 0
    }

    Write-Host "└──────────────────────────────────────────────────────────"
    Write-Host ""
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host "  Reached $n-task cap. $completed task(s) processed."
Write-Host "  Run again with -n to continue."
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""
