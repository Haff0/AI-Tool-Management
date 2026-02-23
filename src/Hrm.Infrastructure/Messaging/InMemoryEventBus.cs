using Hrm.Application.Abstractions;
using Hrm.Contracts.Common;
using System.Text.Json;

namespace Hrm.Infrastructure.Messaging;

public sealed class InMemoryEventBus : IEventBus
{
    public Task PublishAsync<TEvent>(TEvent @event, CancellationToken ct) where TEvent : IntegrationEvent
    {
        var json = JsonSerializer.Serialize(@event);
        Console.WriteLine($"[EventBus] Published: {@event.GetType().Name} CorrelationId={@event.CorrelationId} Payload={json}");
        // TODO: Replace with RabbitMQ actual publish
        return Task.CompletedTask;
    }
}
