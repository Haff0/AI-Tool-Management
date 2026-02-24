using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Configuration;
using Hrm.Worker.Agents;
using ConnectAI.Gemini;
using ConnectAI.AiClient;
using Microsoft.Extensions.Logging;
using Hrm.Application;
using Hrm.Infrastructure;
using Hrm.Worker.Consumers;

try
{
    var builder = Host.CreateApplicationBuilder(args);

    // Register Clean Architecture Layers
    builder.Services.AddInfrastructure(builder.Configuration);
    builder.Services.AddApplication();

    // Register ConnectAI Gemini Service
    builder.Services.AddSingleton<IAIService>(sp =>
    {
        var config = sp.GetRequiredService<IConfiguration>();
        var apiKey = config["GEMINI_API_KEY"] ?? config["OPENAI_API_KEY"] ?? "NO_KEY";
        return AiClient.Gemini(apiKey);
    });

    // Register Worker Consumer
    builder.Services.AddSingleton<RabbitConnectionFactory>();
    builder.Services.AddHostedService<RabbitEventConsumer>();

    // Register Agents
    builder.Services.AddScoped<IPlannerAgent, PlannerAgent>();
    builder.Services.AddScoped<IManagerAgent, ManagerAgent>();
    builder.Services.AddScoped<IExecutorAgent, ExecutorAgent>();

    var host = builder.Build();
    
    var logger = host.Services.GetRequiredService<ILogger<Program>>();
    logger.LogInformation("Hrm.Worker is starting");

    await host.RunAsync();
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
}
