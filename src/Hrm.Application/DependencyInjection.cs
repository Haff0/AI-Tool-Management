using Microsoft.Extensions.DependencyInjection;
using Hrm.Application.Features.WorkRequests.CreateWorkRequest;

namespace Hrm.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        services.AddScoped<CreateWorkRequestHandler>();

        return services;
    }
}
