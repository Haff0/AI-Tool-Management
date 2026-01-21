# scaffold-hrmai.ps1
# Usage:
#   pwsh .\scaffold-hrmai.ps1 -Root "AI-Tool-Management" -Framework "net8.0"
# Notes:
#   - Comments are in English (as requested).
#   - This script creates a Clean Architecture solution skeleton.

param(
  [string]$Root = "HrmAi",
  [string]$Framework = "net8.0"
)

$ErrorActionPreference = "Stop"

function Ensure-Dir([string]$path) {
  if (-not (Test-Path $path)) { New-Item -ItemType Directory -Path $path | Out-Null }
}

function Write-File([string]$path, [string]$content) {
  $dir = Split-Path $path -Parent
  Ensure-Dir $dir
  $content | Out-File -FilePath $path -Encoding UTF8
}

# --- 0) Root setup ---
Ensure-Dir $Root
Set-Location $Root

Ensure-Dir "src"
Ensure-Dir "tests"
Ensure-Dir "docker"

# --- 1) Create solution ---
dotnet new sln -n $Root | Out-Null

# --- 2) Create projects ---
dotnet new classlib -n "$Root.Domain" -o "src/$Root.Domain" -f $Framework | Out-Null
dotnet new classlib -n "$Root.Application" -o "src/$Root.Application" -f $Framework | Out-Null
dotnet new classlib -n "$Root.Infrastructure" -o "src/$Root.Infrastructure" -f $Framework | Out-Null
dotnet new webapi   -n "$Root.Api" -o "src/$Root.Api" -f $Framework --no-https | Out-Null
dotnet new worker   -n "$Root.Worker" -o "src/$Root.Worker" -f $Framework | Out-Null
dotnet new classlib -n "$Root.Contracts" -o "src/$Root.Contracts" -f $Framework | Out-Null
dotnet new xunit    -n "$Root.UnitTests" -o "tests/$Root.UnitTests" -f $Framework | Out-Null
dotnet new xunit    -n "$Root.IntegrationTests" -o "tests/$Root.IntegrationTests" -f $Framework | Out-Null

# --- 3) Add to solution ---
dotnet sln "$Root.sln" add `
  "src/$Root.Domain/$Root.Domain.csproj" `
  "src/$Root.Application/$Root.Application.csproj" `
  "src/$Root.Infrastructure/$Root.Infrastructure.csproj" `
  "src/$Root.Api/$Root.Api.csproj" `
  "src/$Root.Worker/$Root.Worker.csproj" `
  "src/$Root.Contracts/$Root.Contracts.csproj" `
  "tests/$Root.UnitTests/$Root.UnitTests.csproj" `
  "tests/$Root.IntegrationTests/$Root.IntegrationTests.csproj" | Out-Null

# --- 4) Project references (Clean Architecture) ---
dotnet add "src/$Root.Application/$Root.Application.csproj" reference "src/$Root.Domain/$Root.Domain.csproj" | Out-Null
dotnet add "src/$Root.Infrastructure/$Root.Infrastructure.csproj" reference "src/$Root.Application/$Root.Application.csproj" | Out-Null
dotnet add "src/$Root.Infrastructure/$Root.Infrastructure.csproj" reference "src/$Root.Domain/$Root.Domain.csproj" | Out-Null
dotnet add "src/$Root.Api/$Root.Api.csproj" reference "src/$Root.Application/$Root.Application.csproj" | Out-Null
dotnet add "src/$Root.Api/$Root.Api.csproj" reference "src/$Root.Infrastructure/$Root.Infrastructure.csproj" | Out-Null
dotnet add "src/$Root.Worker/$Root.Worker.csproj" reference "src/$Root.Application/$Root.Application.csproj" | Out-Null
dotnet add "src/$Root.Worker/$Root.Worker.csproj" reference "src/$Root.Infrastructure/$Root.Infrastructure.csproj" | Out-Null
dotnet add "src/$Root.Application/$Root.Application.csproj" reference "src/$Root.Contracts/$Root.Contracts.csproj" | Out-Null
dotnet add "src/$Root.Worker/$Root.Worker.csproj" reference "src/$Root.Contracts/$Root.Contracts.csproj" | Out-Null

dotnet add "tests/$Root.UnitTests/$Root.UnitTests.csproj" reference "src/$Root.Application/$Root.Application.csproj" | Out-Null
dotnet add "tests/$Root.UnitTests/$Root.UnitTests.csproj" reference "src/$Root.Domain/$Root.Domain.csproj" | Out-Null
dotnet add "tests/$Root.IntegrationTests/$Root.IntegrationTests.csproj" reference "src/$Root.Api/$Root.Api.csproj" | Out-Null

# --- 5) Create folders and placeholder files ---

# Domain
Write-File "src/$Root.Domain/Common/Entity.cs" @"
namespace $Root.Domain.Common;

// Base entity for domain models.
public abstract class Entity<TId>
{
    public TId Id { get; protected set; } = default!;
}
"@

Write-File "src/$Root.Domain/Common/AggregateRoot.cs" @"
namespace $Root.Domain.Common;

// Aggregate root marker + base.
public abstract class AggregateRoot<TId> : Entity<TId>
{
}
"@

Write-File "src/$Root.Domain/Employees/Employee.cs" @"
using $Root.Domain.Common;

namespace $Root.Domain.Employees;

public sealed class Employee : AggregateRoot<Guid>
{
    public string Code { get; private set; } = string.Empty;
    public string FullName { get; private set; } = string.Empty;

    private Employee() { } // For ORM

    public Employee(Guid id, string code, string fullName)
    {
        Id = id;
        Code = code;
        FullName = fullName;
    }
}
"@

Write-File "src/$Root.Domain/Tasks/WorkRequest.cs" @"
using $Root.Domain.Common;

namespace $Root.Domain.Tasks;

public sealed class WorkRequest : AggregateRoot<Guid>
{
    public string Title { get; private set; } = string.Empty;
    public string Description { get; private set; } = string.Empty;

    private WorkRequest() { } // For ORM

    public WorkRequest(Guid id, string title, string description)
    {
        Id = id;
        Title = title;
        Description = description;
    }
}
"@

# Contracts
Write-File "src/$Root.Contracts/Common/IntegrationEvent.cs" @"
namespace $Root.Contracts.Common;

// Base integration event for messaging between services.
public abstract record IntegrationEvent(
    Guid EventId,
    DateTime OccurredUtc,
    string CorrelationId
);
"@

Write-File "src/$Root.Contracts/Events/WorkRequestCreatedEvent.cs" @"
using $Root.Contracts.Common;

namespace $Root.Contracts.Events;

public sealed record WorkRequestCreatedEvent(
    Guid EventId,
    DateTime OccurredUtc,
    string CorrelationId,
    Guid WorkRequestId,
    string Title
) : IntegrationEvent(EventId, OccurredUtc, CorrelationId);
"@

# Application
Write-File "src/$Root.Application/Abstractions/IWorkRepository.cs" @"
using $Root.Domain.Tasks;

namespace $Root.Application.Abstractions;

// Repository abstraction for WorkRequest.
public interface IWorkRepository
{
    Task AddAsync(WorkRequest entity, CancellationToken ct);
    Task<WorkRequest?> GetAsync(Guid id, CancellationToken ct);
}
"@

Write-File "src/$Root.Application/Abstractions/IEventBus.cs" @"
using $Root.Contracts.Common;

namespace $Root.Application.Abstractions;

// Event bus abstraction (RabbitMQ/Kafka/etc).
public interface IEventBus
{
    Task PublishAsync<TEvent>(TEvent @event, CancellationToken ct) where TEvent : IntegrationEvent;
}
"@

Write-File "src/$Root.Application/Features/WorkRequests/CreateWorkRequest/CreateWorkRequestCommand.cs" @"
namespace $Root.Application.Features.WorkRequests.CreateWorkRequest;

public sealed record CreateWorkRequestCommand(string Title, string Description);
"@

Write-File "src/$Root.Application/Features/WorkRequests/CreateWorkRequest/CreateWorkRequestHandler.cs" @"
using $Root.Application.Abstractions;
using $Root.Contracts.Events;
using $Root.Domain.Tasks;

namespace $Root.Application.Features.WorkRequests.CreateWorkRequest;

// Simple handler example (no MediatR dependency).
public sealed class CreateWorkRequestHandler
{
    private readonly IWorkRepository _repo;
    private readonly IEventBus _bus;

    public CreateWorkRequestHandler(IWorkRepository repo, IEventBus bus)
    {
        _repo = repo;
        _bus = bus;
    }

    public async Task<Guid> HandleAsync(CreateWorkRequestCommand cmd, string correlationId, CancellationToken ct)
    {
        var id = Guid.NewGuid();
        var entity = new WorkRequest(id, cmd.Title, cmd.Description);
        await _repo.AddAsync(entity, ct);

        var evt = new WorkRequestCreatedEvent(
            EventId: Guid.NewGuid(),
            OccurredUtc: DateTime.UtcNow,
            CorrelationId: correlationId,
            WorkRequestId: id,
            Title: cmd.Title
        );

        await _bus.PublishAsync(evt, ct);
        return id;
    }
}
"@

# Infrastructure (EF Core skeleton - you will add EF packages later)
Write-File "src/$Root.Infrastructure/Persistence/AppDbContext.cs" @"
using Microsoft.EntityFrameworkCore;
using $Root.Domain.Employees;
using $Root.Domain.Tasks;

namespace $Root.Infrastructure.Persistence;

public sealed class AppDbContext : DbContext
{
    public DbSet<Employee> Employees => Set<Employee>();
    public DbSet<WorkRequest> WorkRequests => Set<WorkRequest>();

    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // Apply configurations here (IEntityTypeConfiguration<T>).
        // modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);
    }
}
"@

Write-File "src/$Root.Infrastructure/Repositories/WorkRepository.cs" @"
using Microsoft.EntityFrameworkCore;
using $Root.Application.Abstractions;
using $Root.Domain.Tasks;
using $Root.Infrastructure.Persistence;

namespace $Root.Infrastructure.Repositories;

public sealed class WorkRepository : IWorkRepository
{
    private readonly AppDbContext _db;

    public WorkRepository(AppDbContext db) => _db = db;

    public async Task AddAsync(WorkRequest entity, CancellationToken ct)
    {
        _db.WorkRequests.Add(entity);
        await _db.SaveChangesAsync(ct);
    }

    public Task<WorkRequest?> GetAsync(Guid id, CancellationToken ct)
        => _db.WorkRequests.FirstOrDefaultAsync(x => x.Id == id, ct);
}
"@

Write-File "src/$Root.Infrastructure/Messaging/InMemoryEventBus.cs" @"
using $Root.Application.Abstractions;
using $Root.Contracts.Common;

namespace $Root.Infrastructure.Messaging;

// In-memory event bus for local testing; replace with RabbitMQ later.
public sealed class InMemoryEventBus : IEventBus
{
    public Task PublishAsync<TEvent>(TEvent @event, CancellationToken ct) where TEvent : IntegrationEvent
    {
        // TODO: Replace with real broker.
        Console.WriteLine($""[EventBus] Published: {typeof(TEvent).Name} CorrelationId={@event.CorrelationId}"");
        return Task.CompletedTask;
    }
}
"@

Write-File "src/$Root.Infrastructure/DependencyInjection/ServiceCollectionExtensions.cs" @"
using Microsoft.Extensions.DependencyInjection;
using $Root.Application.Abstractions;
using $Root.Infrastructure.Messaging;
using $Root.Infrastructure.Repositories;

namespace $Root.Infrastructure.DependencyInjection;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services)
    {
        // TODO: Add EF Core DbContext + real messaging + redis etc.
        services.AddScoped<IWorkRepository, WorkRepository>();
        services.AddSingleton<IEventBus, InMemoryEventBus>();
        return services;
    }
}
"@

# API
Write-File "src/$Root.Api/Controllers/WorkRequestsController.cs" @"
using Microsoft.AspNetCore.Mvc;
using $Root.Application.Features.WorkRequests.CreateWorkRequest;

namespace $Root.Api.Controllers;

[ApiController]
[Route(""api/work-requests"")]
public sealed class WorkRequestsController : ControllerBase
{
    private readonly CreateWorkRequestHandler _handler;

    public WorkRequestsController(CreateWorkRequestHandler handler)
    {
        _handler = handler;
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateWorkRequestRequest request, CancellationToken ct)
    {
        var correlationId = HttpContext.TraceIdentifier;
        var id = await _handler.HandleAsync(
            new CreateWorkRequestCommand(request.Title, request.Description),
            correlationId,
            ct
        );

        return CreatedAtAction(nameof(GetById), new { id }, new { id, correlationId });
    }

    [HttpGet(""{id:guid}"")]
    public IActionResult GetById(Guid id) => Ok(new { id });
}

public sealed record CreateWorkRequestRequest(string Title, string Description);
"@

# Update API Program.cs for DI
$apiProgram = "src/$Root.Api/Program.cs"
if (Test-Path $apiProgram) {
  $programContent = Get-Content $apiProgram -Raw
  if ($programContent -notmatch "AddInfrastructure") {
    $programContent = $programContent -replace "var builder = WebApplication.CreateBuilder\(args\);", @"
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddInfrastructure();
builder.Services.AddScoped<$Root.Application.Features.WorkRequests.CreateWorkRequest.CreateWorkRequestHandler>();
"@
    $programContent = "using $Root.Infrastructure.DependencyInjection;`n" + $programContent
    Write-File $apiProgram $programContent
  }
}

# Worker
Write-File "src/$Root.Worker/Consumers/WorkRequestCreatedConsumer.cs" @"
using $Root.Contracts.Events;

namespace $Root.Worker.Consumers;

// Example consumer placeholder (wire it with RabbitMQ later).
public sealed class WorkRequestCreatedConsumer
{
    public Task HandleAsync(WorkRequestCreatedEvent evt, CancellationToken ct)
    {
        Console.WriteLine($""[Worker] Received WorkRequestCreated: {evt.WorkRequestId} Title={evt.Title}"");
        return Task.CompletedTask;
    }
}
"@

Write-File "src/$Root.Worker/Agents/PlannerAgent.cs" @"
namespace $Root.Worker.Agents;

// Planner agent splits a WorkRequest into smaller WorkItems.
public sealed class PlannerAgent
{
    public Task RunAsync(Guid workRequestId, CancellationToken ct)
    {
        // TODO: Call AI provider, generate plan, persist WorkItems.
        Console.WriteLine($""[PlannerAgent] Planning for WorkRequest={workRequestId}"");
        return Task.CompletedTask;
    }
}
"@

Write-File "src/$Root.Worker/DependencyInjection/ServiceCollectionExtensions.cs" @"
using Microsoft.Extensions.DependencyInjection;
using $Root.Worker.Agents;

namespace $Root.Worker.DependencyInjection;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddWorkerServices(this IServiceCollection services)
    {
        services.AddSingleton<PlannerAgent>();
        return services;
    }
}
"@

# Update Worker Program.cs for DI
$workerProgram = "src/$Root.Worker/Program.cs"
if (Test-Path $workerProgram) {
  $workerContent = Get-Content $workerProgram -Raw
  if ($workerContent -notmatch "AddWorkerServices") {
    $workerContent = "using $Root.Worker.DependencyInjection;`n" + $workerContent
    $workerContent = $workerContent -replace "var host = Host.CreateDefaultBuilder\(args\)", @"
var host = Host.CreateDefaultBuilder(args)
    .ConfigureServices(services =>
    {
        services.AddWorkerServices();
    })
"@
    Write-File $workerProgram $workerContent
  }
}

# Docker placeholders
Write-File "src/$Root.Api/Dockerfile" @"
# Build
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY . .
WORKDIR /src/src/$Root.Api
RUN dotnet publish -c Release -o /app/publish

# Runtime
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish .
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080
ENTRYPOINT [""dotnet"", ""$Root.Api.dll""]
"@

Write-File "src/$Root.Worker/Dockerfile" @"
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY . .
WORKDIR /src/src/$Root.Worker
RUN dotnet publish -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/runtime:8.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT [""dotnet"", ""$Root.Worker.dll""]
"@

Write-File "docker-compose.yml" @"
services:
  api:
    build:
      context: .
      dockerfile: src/$Root.Api/Dockerfile
    ports:
      - ""8080:8080""
    environment:
      - ASPNETCORE_ENVIRONMENT=Development
    depends_on:
      - postgres

  worker:
    build:
      context: .
      dockerfile: src/$Root.Worker/Dockerfile
    environment:
      - DOTNET_ENVIRONMENT=Development
    depends_on:
      - postgres

  postgres:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: postgres
      POSTGRES_USER: postgres
      POSTGRES_DB: hrmai
    ports:
      - ""5432:5432""
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:
"@

Write-Host "Done. Next steps:"
Write-Host "  1) dotnet build"
Write-Host "  2) dotnet run --project src/$Root.Api"
Write-Host "  3) docker compose up --build"
