namespace Shared.Contracts;

// WorkRequestCreated: API publishes when a work request is created.
public sealed record WorkRequestCreated(
    string WorkRequestId,
    string Title,
    string RequestedBy,
    DateTimeOffset CreatedAt,
    string CorrelationId);

// TaskCreated: planner/manager publishes when a sub-task is created.
public sealed record TaskCreated(
    string TaskId,
    string WorkRequestId,
    string TaskType,
    string PayloadJson,
    DateTimeOffset CreatedAt,
    string CorrelationId);

// TaskCompleted: executor publishes when task is completed.
public sealed record TaskCompleted(
    string TaskId,
    string WorkRequestId,
    bool Success,
    string ResultJson,
    DateTimeOffset CompletedAt,
    string CorrelationId);
