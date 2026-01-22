Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoApiRoot = "E:\Project\Git\AI-Tool-Management"
$WorkerPath = Join-Path $RepoApiRoot "src\Hrm.Worker"
$SharedContractsPath = Join-Path $RepoApiRoot "src\Shared\Contracts"
$SharedObsPath = Join-Path $RepoApiRoot "src\Shared\Observability"

function Write-Info([string]$Message) { Write-Host $Message -ForegroundColor Cyan }
function Ensure-Dir([string]$Path) { if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path | Out-Null } }

function Exec([string]$Cmd) {
    Write-Host ">> $Cmd" -ForegroundColor DarkGray
    $p = Start-Process -FilePath "pwsh" -ArgumentList @("-NoProfile","-Command",$Cmd) -Wait -PassThru
    if ($p.ExitCode -ne 0) { throw "Command failed: $Cmd" }
}

Write-Info "02) Scaffolding .NET Worker + Shared Contracts/Observability..."

Ensure-Dir $WorkerPath
Ensure-Dir $SharedContractsPath
Ensure-Dir $SharedObsPath

# --- Create Shared Contracts (simple POCO records) ---
$contracts = @'
namespace Shared.Contracts;

// WorkRequestCreated: API publishes when a work request is created.
public sealed record WorkRequestCreated(
    string WorkRequestId,
    string Title,
    string RequestedBy,
    DateTimeOffset CreatedAt,
    string CorrelationId);

// TaskCreated: planner/manager publishes when a sub-task is created.
public sealed record TaskCreated(
    string TaskId,
    string WorkRequestId,
    string TaskType,
    string PayloadJson,
    DateTimeOffset CreatedAt,
    string CorrelationId);

// TaskCompleted: executor publishes when task is completed.
public sealed record TaskCompleted(
    string TaskId,
    string WorkRequestId,
    bool Success,
    string ResultJson,
    DateTimeOffset CompletedAt,
    string CorrelationId);
'@
Set-Content -Path (Join-Path $SharedContractsPath "Events.cs") -Value $contracts -Encoding UTF8

# --- Create Shared Observability helpers ---
$obs = @'
using System.Diagnostics;

namespace Shared.Observability;

public static class Correlation
{
    public const string HeaderName = "x-correlation-id";

    public static string Ensure(string? correlationId)
        => string.IsNullOrWhiteSpace(correlationId) ? Guid.NewGuid().ToString("N") : correlationId;

    public static ActivitySource ActivitySource { get; } = new("HrmAi.Activity");
}
'@
Set-Content -Path (Join-Path $SharedObsPath "Correlation.cs") -Value $obs -Encoding UTF8

# --- Create Worker csproj if not exists ---
$workerCsproj = Join-Path $WorkerPath "Hrm.Worker.csproj"
if (-not (Test-Path $workerCsproj)) {
    Push-Location $WorkerPath
    try {
        # Create worker project
        Exec "dotnet new worker --name Hrm.Worker --framework net8.0"

        # Move generated files from nested folder to this folder if needed
        if (Test-Path (Join-Path $WorkerPath "Hrm.Worker\Hrm.Worker.csproj")) {
            Copy-Item (Join-Path $WorkerPath "Hrm.Worker\*") -Destination $WorkerPath -Recurse -Force
            Remove-Item (Join-Path $WorkerPath "Hrm.Worker") -Recurse -Force
        }

        # Add packages (basic)
        Exec "dotnet add package RabbitMQ.Client --version 6.*"
        Exec "dotnet add package Microsoft.Extensions.Http"
        Exec "dotnet add package Serilog.Extensions.Hosting --version 8.*"
        Exec "dotnet add package Serilog.Sinks.Console --version 6.*"
    }
    finally { Pop-Location }
}

# --- Add minimal Worker code: Rabbit consumer skeleton ---
$program = @'
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.DependencyInjection;
using Serilog;
using Shared.Observability;

Log.Logger = new LoggerConfiguration()
    .Enrich.FromLogContext()
    .WriteTo.Console()
    .CreateLogger();

try
{
    var builder = Host.CreateApplicationBuilder(args);
    builder.Services.AddSerilog();

    builder.Services.AddSingleton<RabbitConnectionFactory>();
    builder.Services.AddHostedService<RabbitEventConsumer>();

    // TODO: add planner/manager/executor registrations here.
    // builder.Services.AddSingleton<IPlanner, Planner>();
    // builder.Services.AddSingleton<IManager, Manager>();
    // builder.Services.AddSingleton<IExecutor, Executor>();

    var host = builder.Build();
    await host.RunAsync();
}
catch (Exception ex)
{
    Log.Fatal(ex, "Worker terminated unexpectedly.");
}
finally
{
    Log.CloseAndFlush();
}

'@
Set-Content -Path (Join-Path $WorkerPath "Program.cs") -Value $program -Encoding UTF8

$rabbitFactory = @'
using RabbitMQ.Client;

public sealed class RabbitConnectionFactory
{
    public IConnection CreateConnection(IConfiguration config)
    {
        var host = config["Rabbit:Host"] ?? "rabbitmq";
        var user = config["Rabbit:User"] ?? "guest";
        var pass = config["Rabbit:Pass"] ?? "guest";
        var vhost = config["Rabbit:VHost"] ?? "/";

        var factory = new ConnectionFactory
        {
            HostName = host,
            UserName = user,
            Password = pass,
            VirtualHost = vhost,
            DispatchConsumersAsync = true
        };

        return factory.CreateConnection("hrm-worker");
    }
}
'@
Set-Content -Path (Join-Path $WorkerPath "RabbitConnectionFactory.cs") -Value $rabbitFactory -Encoding UTF8

$consumer = @'
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;
using Shared.Contracts;
using Shared.Observability;

public sealed class RabbitEventConsumer : BackgroundService
{
    private readonly ILogger<RabbitEventConsumer> _logger;
    private readonly IConfiguration _config;
    private readonly RabbitConnectionFactory _factory;

    private IConnection? _conn;
    private IModel? _ch;

    public RabbitEventConsumer(
        ILogger<RabbitEventConsumer> logger,
        IConfiguration config,
        RabbitConnectionFactory factory)
    {
        _logger = logger;
        _config = config;
        _factory = factory;
    }

    protected override Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _conn = _factory.CreateConnection(_config);
        _ch = _conn.CreateModel();

        var exchange = _config["Rabbit:Exchange"] ?? "hrm.events";
        var queue = _config["Rabbit:Queue"] ?? "hrm.worker";
        var routingKey = _config["Rabbit:RoutingKey"] ?? "workrequest.created";

        _ch.ExchangeDeclare(exchange, ExchangeType.Topic, durable: true, autoDelete: false);
        _ch.QueueDeclare(queue, durable: true, exclusive: false, autoDelete: false);
        _ch.QueueBind(queue, exchange, routingKey);

        var consumer = new AsyncEventingBasicConsumer(_ch);
        consumer.Received += OnMessageAsync;

        _ch.BasicQos(0, prefetchCount: 10, global: false);
        _ch.BasicConsume(queue, autoAck: false, consumer);

        _logger.LogInformation("Rabbit consumer started. exchange={Exchange} queue={Queue} key={Key}", exchange, queue, routingKey);

        return Task.CompletedTask;
    }

    private async Task OnMessageAsync(object sender, BasicDeliverEventArgs ea)
    {
        try
        {
            var json = Encoding.UTF8.GetString(ea.Body.ToArray());

            // Example: WorkRequestCreated event
            // If your routing key includes multiple events, switch by ea.RoutingKey
            var evt = JsonSerializer.Deserialize<WorkRequestCreated>(json, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });

            var correlationId = Correlation.Ensure(evt?.CorrelationId);

            _logger.LogInformation("Received WorkRequestCreated. id={Id} correlationId={CorrelationId}", evt?.WorkRequestId, correlationId);

            // TODO: call planner -> manager -> executor pipeline
            await Task.Delay(10);

            _ch?.BasicAck(ea.DeliveryTag, multiple: false);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to handle message. routingKey={Key}", ea.RoutingKey);
            // Requeue=true for transient errors
            _ch?.BasicNack(ea.DeliveryTag, multiple: false, requeue: true);
        }
    }

    public override void Dispose()
    {
        try { _ch?.Close(); } catch { }
        try { _conn?.Close(); } catch { }
        base.Dispose();
    }
}
'@
Set-Content -Path (Join-Path $WorkerPath "RabbitEventConsumer.cs") -Value $consumer -Encoding UTF8

# --- Add appsettings for Worker ---
$workerSettings = @'
{
  "Rabbit": {
    "Host": "rabbitmq",
    "User": "guest",
    "Pass": "guest",
    "VHost": "/",
    "Exchange": "hrm.events",
    "Queue": "hrm.worker",
    "RoutingKey": "workrequest.created"
  },
  "AI": {
    "Provider": "ollama",
    "Model": "llama3.1",
    "TimeoutSeconds": 60
  }
}
'@
Set-Content -Path (Join-Path $WorkerPath "appsettings.json") -Value $workerSettings -Encoding UTF8

Write-Info "Done. Worker + Shared modules created."
Write-Host "Next: run scripts/03-AddDockerfiles.ps1" -ForegroundColor Green
