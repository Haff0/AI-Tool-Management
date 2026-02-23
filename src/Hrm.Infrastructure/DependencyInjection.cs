using Microsoft.Extensions.DependencyInjection;
using Microsoft.EntityFrameworkCore;
using Hrm.Application.Abstractions;
using Hrm.Infrastructure.Messaging;
using Hrm.Infrastructure.Persistence;
using Hrm.Infrastructure.Repositories;
using Microsoft.Extensions.Configuration;

namespace Hrm.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration configuration)
    {
        var connectionString = configuration.GetConnectionString("Default");

        services.AddDbContext<AppDbContext>(options =>
            options.UseNpgsql(connectionString));

        services.AddScoped<IWorkRepository, WorkRepository>();
        
        // Use InMemoryEventBus for now. We will add MassTransit or RabbitMQ logic later.
        services.AddSingleton<IEventBus, InMemoryEventBus>();

        return services;
    }
}
