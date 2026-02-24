using Microsoft.Extensions.DependencyInjection;
using Microsoft.EntityFrameworkCore;
using Hrm.Application.Abstractions;
using Hrm.Infrastructure.Persistence;
using Hrm.Infrastructure.Repositories;
using Microsoft.Extensions.Configuration;
using MassTransit;
using Hrm.Infrastructure.MessageBroker.EventBus;
using Hrm.Infrastructure.Caching;
using Hrm.Infrastructure.Storage;
using Minio;

namespace Hrm.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration configuration)
    {
        var connectionString = configuration.GetConnectionString("Default");

        services.AddDbContext<AppDbContext>(options =>
            options.UseNpgsql(connectionString));

        services.AddScoped<IWorkRepository, WorkRepository>();
        
        // Redis Cache
        services.AddStackExchangeRedisCache(options =>
        {
            options.Configuration = configuration.GetConnectionString("Redis");
        });
        services.AddSingleton<ICacheService, RedisCacheService>();

        // MinIO Storage
        services.AddSingleton<IMinioClient>(sp =>
        {
            var endpoint = configuration["MinIO:Endpoint"];
            var accessKey = configuration["MinIO:AccessKey"];
            var secretKey = configuration["MinIO:SecretKey"];
            var secure = configuration.GetValue<bool>("MinIO:Secure");

            return new MinioClient()
                .WithEndpoint(endpoint)
                .WithCredentials(accessKey, secretKey)
                .WithSSL(secure)
                .Build();
        });
        services.AddTransient<IFileStorageService, MinIOFileStorageService>();

        // MassTransit EventBus
        services.AddMassTransit(x =>
        {
            x.UsingRabbitMq((context, cfg) =>
            {
                var rabbitMqHost = configuration["RabbitMQ:Host"] ?? "localhost";
                var rabbitMqVirtualHost = configuration["RabbitMQ:VirtualHost"] ?? "/";
                var rabbitMqUsername = configuration["RabbitMQ:Username"] ?? "guest";
                var rabbitMqPassword = configuration["RabbitMQ:Password"] ?? "guest";

                cfg.Host(rabbitMqHost, rabbitMqVirtualHost, h =>
                {
                    h.Username(rabbitMqUsername);
                    h.Password(rabbitMqPassword);
                });

                cfg.ConfigureEndpoints(context);
            });
        });

        services.AddTransient<IEventBus, MassTransitEventBus>();

        return services;
    }
}
