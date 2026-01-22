Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# === Config ===
$RepoApiRoot = "E:\Project\Git\AI-Tool-Management"
$RepoConnectAiRoot = "E:\Project\Git\ConnectAI"
$RepoToolHelperRoot = "E:\Project\Git\ToolHelper"

function Ensure-Dir([string]$Path) {
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Write-Info([string]$Message) {
    Write-Host $Message -ForegroundColor Cyan
}

Write-Info "01) Creating folders for Docker/Compose + Shared modules..."

# AI-Tool-Management folders
Ensure-Dir "$RepoApiRoot\scripts"
Ensure-Dir "$RepoApiRoot\docker"
Ensure-Dir "$RepoApiRoot\docker\compose"
Ensure-Dir "$RepoApiRoot\src"
Ensure-Dir "$RepoApiRoot\src\Hrm.Worker"
Ensure-Dir "$RepoApiRoot\src\Shared"
Ensure-Dir "$RepoApiRoot\src\Shared\Contracts"
Ensure-Dir "$RepoApiRoot\src\Shared\Observability"

# Optional: add a place for docs
Ensure-Dir "$RepoApiRoot\docs"

# ConnectAI (optional)
Ensure-Dir "$RepoConnectAiRoot\docs"
Ensure-Dir "$RepoConnectAiRoot\docker"

# ToolHelper (optional)
Ensure-Dir "$RepoToolHelperRoot\docs"

Write-Info "Done. Folders ensured."
Write-Host "Next: run scripts/02-ScaffoldWorker.ps1" -ForegroundColor Green
