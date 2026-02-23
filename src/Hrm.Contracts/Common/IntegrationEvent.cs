namespace Hrm.Contracts.Common;

public abstract record IntegrationEvent(
    Guid EventId,
    DateTime OccurredUtc,
    string CorrelationId
);
