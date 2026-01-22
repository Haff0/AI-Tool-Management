Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoApiRoot = "E:\Project\Git\AI-Tool-Management"
$ComposeDir = Join-Path $RepoApiRoot "docker\compose"
$ComposeFile = Join-Path $ComposeDir "docker-compose.dev.yml"
$EnvExample = Join-Path $ComposeDir ".env.dev.example"
$Readme = Join-Path $ComposeDir "README.md"

function Write-Info([string]$Message) { Write-Host $Message -ForegroundColor Cyan }
function Ensure-Dir([string]$Path) { if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path | Out-Null } }

Ensure-Dir $ComposeDir
Write-Info "04) Creating docker-compose.dev.yml + .env.dev.example ..."

$env = @'
# --- Core ---
ASPNETCORE_ENVIRONMENT=Development

# --- Database ---
POSTGRES_USER=hrm
POSTGRES_PASSWORD=hrm_password
POSTGRES_DB=hrm

# For .NET ConnectionStrings__Default (note: double underscore)
CONNECTIONSTRINGS__DEFAULT=Host=postgres;Port=5432;Database=hrm;Username=hrm;Password=hrm_password

# --- Redis ---
REDIS__HOST=redis

# --- RabbitMQ ---
RABBIT__HOST=rabbitmq
RABBIT__USER=guest
RABBIT__PASS=guest
RABBIT__EXCHANGE=hrm.events

# --- MinIO ---
MINIO_ROOT_USER=minio
MINIO_ROOT_PASSWORD=minio_password

# --- AI Provider (dev) ---
AI__PROVIDER=ollama
AI__MODEL=llama3.1
OPENAI_API_KEY=
GEMINI_API_KEY=

# --- API ports ---
HRM_API_HTTP_PORT=8080

# --- Rabbit UI ---
RABBIT_UI_PORT=15672
RABBIT_PORT=5672

# --- Postgres host port ---
POSTGRES_PORT=5432

# --- MinIO ports ---
MINIO_PORT=9000
MINIO_CONSOLE_PORT=9001

# --- Ollama port (optional) ---
OLLAMA_PORT=11434
'@
Set-Content -Path $EnvExample -Value $env -Encoding UTF8

$compose = @'
services:
  hrm-api:
    build:
      context: ../..
      dockerfile: Dockerfile
    container_name: hrm-api
    environment:
      - ASPNETCORE_ENVIRONMENT=${ASPNETCORE_ENVIRONMENT}
      - ConnectionStrings__Default=${CONNECTIONSTRINGS__DEFAULT}
      - Redis__Host=${REDIS__HOST}
      - Rabbit__Host=${RABBIT__HOST}
      - Rabbit__User=${RABBIT__USER}
      - Rabbit__Pass=${RABBIT__PASS}
      - Rabbit__Exchange=${RABBIT__EXCHANGE}
      - AI__Provider=${AI__PROVIDER}
      - AI__Model=${AI__MODEL}
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - GEMINI_API_KEY=${GEMINI_API_KEY}
    depends_on:
      - postgres
      - redis
      - rabbitmq
    ports:
      - "${HRM_API_HTTP_PORT}:8080"
    networks:
      - hrm-net

  hrm-worker:
    build:
      context: ../..
      dockerfile: src/Hrm.Worker/Dockerfile
    container_name: hrm-worker
    environment:
      - ConnectionStrings__Default=${CONNECTIONSTRINGS__DEFAULT}
      - Redis__Host=${REDIS__HOST}
      - Rabbit__Host=${RABBIT__HOST}
      - Rabbit__User=${RABBIT__USER}
      - Rabbit__Pass=${RABBIT__PASS}
      - Rabbit__Exchange=${RABBIT__EXCHANGE}
      - AI__Provider=${AI__PROVIDER}
      - AI__Model=${AI__MODEL}
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - GEMINI_API_KEY=${GEMINI_API_KEY}
    depends_on:
      - postgres
      - redis
      - rabbitmq
    networks:
      - hrm-net

  postgres:
    image: postgres:16
    container_name: postgres
    environment:
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=${POSTGRES_DB}
    ports:
      - "${POSTGRES_PORT}:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - hrm-net

  redis:
    image: redis:7
    container_name: redis
    command: ["redis-server", "--appendonly", "yes"]
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    networks:
      - hrm-net

  rabbitmq:
    image: rabbitmq:3-management
    container_name: rabbitmq
    ports:
      - "${RABBIT_PORT}:5672"
      - "${RABBIT_UI_PORT}:15672"
    networks:
      - hrm-net

  minio:
    image: minio/minio:latest
    container_name: minio
    command: ["server", "/data", "--console-address", ":9001"]
    environment:
      - MINIO_ROOT_USER=${MINIO_ROOT_USER}
      - MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}
    ports:
      - "${MINIO_PORT}:9000"
      - "${MINIO_CONSOLE_PORT}:9001"
    volumes:
      - minio_data:/data
    networks:
      - hrm-net

  # --- Optional: local LLM for dev/offline ---
  # ollama:
  #   image: ollama/ollama:latest
  #   container_name: ollama
  #   ports:
  #     - "${OLLAMA_PORT}:11434"
  #   volumes:
  #     - ollama_data:/root/.ollama
  #   networks:
  #     - hrm-net

networks:
  hrm-net:
    driver: bridge

volumes:
  postgres_data:
  redis_data:
  minio_data:
  # ollama_data:
'@
Set-Content -Path $ComposeFile -Value $compose -Encoding UTF8

$readmeContent = 
@'
# HRM AI - Local Dev Stack

## Quick start

1) Copy env file

- Copy `.env.dev.example` -> `.env.dev`

2) Start stack

```bash

cd docker/compose
docker compose --env-file .env.dev -f docker-compose.dev.yml up -d --build
'@
