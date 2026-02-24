using Hrm.Application.Abstractions;
using Hrm.Contracts.Common;
using MassTransit;

namespace Hrm.Infrastructure.MessageBroker.EventBus;

public sealed class MassTransitEventBus : IEventBus
{
    private readonly IPublishEndpoint _publishEndpoint;

    public MassTransitEventBus(IPublishEndpoint publishEndpoint)
    {
        _publishEndpoint = publishEndpoint;
    }

    public async Task PublishAsync<TEvent>(TEvent @event, CancellationToken ct) where TEvent : IntegrationEvent
    {
        await _publishEndpoint.Publish(@event, ct);
    }
}
