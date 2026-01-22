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

