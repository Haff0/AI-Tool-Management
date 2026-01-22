using System.Diagnostics;

namespace Shared.Observability;

public static class Correlation
{
    public const string HeaderName = "x-correlation-id";

    public static string Ensure(string? correlationId)
        => string.IsNullOrWhiteSpace(correlationId) ? Guid.NewGuid().ToString("N") : correlationId;

    public static ActivitySource ActivitySource { get; } = new("HrmAi.Activity");
}
