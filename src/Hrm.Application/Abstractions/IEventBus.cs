using Hrm.Contracts.Common;

namespace Hrm.Application.Abstractions;

public interface IEventBus
{
    Task PublishAsync<TEvent>(TEvent @event, CancellationToken ct) where TEvent : IntegrationEvent;
}
