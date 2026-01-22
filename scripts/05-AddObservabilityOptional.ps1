
# File 5 — `scripts/05-AddObservabilityOptional.ps1` (Optional)

#Script này thêm cấu hình cơ bản Prometheus/Grafana/Loki (chưa gắn OpenTelemetry vào code của bạn — phần đó bạn có thể làm ở bước tiếp theo).

#```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoApiRoot = "E:\Project\Git\AI-Tool-Management"
$ComposeDir = Join-Path $RepoApiRoot "docker\compose"

$Prometheus = Join-Path $ComposeDir "prometheus.yml"
$Loki = Join-Path $ComposeDir "loki-config.yml"
$OtelCollector = Join-Path $ComposeDir "otel-collector-config.yml"

function Write-Info([string]$Message) { Write-Host $Message -ForegroundColor Cyan }
function Ensure-Dir([string]$Path) { if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path | Out-Null } }

Ensure-Dir $ComposeDir
Write-Info "05) Adding optional observability configs (Prometheus/Loki/OTel Collector)..."

$prom = @'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: "docker"
    static_configs:
      - targets: ["hrm-api:8080"]
'@
Set-Content -Path $Prometheus -Value $prom -Encoding UTF8

$lokiCfg = @'
auth_enabled: false

server:
  http_listen_port: 3100

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2024-01-01
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h
'@
Set-Content -Path $Loki -Value $lokiCfg -Encoding UTF8

$otel = @'
receivers:
  otlp:
    protocols:
      http:
      grpc:

exporters:
  logging:
    loglevel: info

service:
  pipelines:
    traces:
      receivers: [otlp]
      exporters: [logging]
    metrics:
      receivers: [otlp]
      exporters: [logging]
'@
Set-Content -Path $OtelCollector -Value $otel -Encoding UTF8

Write-Info "Done. Optional observability configs created."
Write-Host "You can now extend docker-compose.dev.yml to include grafana/loki/otel-collector." -ForegroundColor Yellow
