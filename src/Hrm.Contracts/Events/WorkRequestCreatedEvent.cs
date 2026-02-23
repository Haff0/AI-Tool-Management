using Hrm.Contracts.Common;

namespace Hrm.Contracts.Events;

public sealed record WorkRequestCreatedEvent(
    Guid EventId,
    DateTime OccurredUtc,
    string CorrelationId,
    Guid WorkRequestId,
    string Title
) : IntegrationEvent(EventId, OccurredUtc, CorrelationId);
