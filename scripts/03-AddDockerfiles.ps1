Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoApiRoot = "E:\Project\Git\AI-Tool-Management"
$ApiCsproj = Join-Path $RepoApiRoot "AI-Tool-Management.csproj"
$ApiDockerfile = Join-Path $RepoApiRoot "Dockerfile"

$WorkerRoot = Join-Path $RepoApiRoot "src\Hrm.Worker"
$WorkerCsproj = Join-Path $WorkerRoot "Hrm.Worker.csproj"
$WorkerDockerfile = Join-Path $WorkerRoot "Dockerfile"

function Write-Info([string]$Message) { Write-Host $Message -ForegroundColor Cyan }
function Backup-File([string]$Path) {
    if (Test-Path $Path) {
        $bak = "$Path.bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
        Copy-Item $Path $bak -Force
        Write-Host "Backed up: $Path -> $bak" -ForegroundColor Yellow
    }
}

Write-Info "03) Adding Dockerfiles (API + Worker) ..."

if (-not (Test-Path $ApiCsproj)) { throw "API csproj not found: $ApiCsproj" }
if (-not (Test-Path $WorkerCsproj)) { throw "Worker csproj not found: $WorkerCsproj" }

# --- API Dockerfile (root project) ---
Backup-File $ApiDockerfile
$apiDocker = @'
# syntax=docker/dockerfile:1

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy csproj first for better layer caching
COPY AI-Tool-Management.csproj ./
RUN dotnet restore ./AI-Tool-Management.csproj

# Copy everything else
COPY . ./
RUN dotnet publish ./AI-Tool-Management.csproj -c Release -o /app/publish /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app

# Disable diagnostics for lighter prod containers
ENV DOTNET_EnableDiagnostics=0
ENV ASPNETCORE_URLS=http://+:8080

COPY --from=build /app/publish ./

EXPOSE 8080
ENTRYPOINT ["dotnet", "AI-Tool-Management.dll"]
'@
Set-Content -Path $ApiDockerfile -Value $apiDocker -Encoding UTF8

# --- Worker Dockerfile ---
Backup-File $WorkerDockerfile
$workerDocker = @'
# syntax=docker/dockerfile:1

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

COPY src/Hrm.Worker/Hrm.Worker.csproj src/Hrm.Worker/
RUN dotnet restore src/Hrm.Worker/Hrm.Worker.csproj

COPY . ./
RUN dotnet publish src/Hrm.Worker/Hrm.Worker.csproj -c Release -o /app/publish /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/runtime:8.0 AS runtime
WORKDIR /app

ENV DOTNET_EnableDiagnostics=0

COPY --from=build /app/publish ./

ENTRYPOINT ["dotnet", "Hrm.Worker.dll"]
'@
Set-Content -Path $WorkerDockerfile -Value $workerDocker -Encoding UTF8

Write-Info "Done. Dockerfiles created/updated."
Write-Host "Next: run scripts/04-AddComposeDev.ps1" -ForegroundColor Green
