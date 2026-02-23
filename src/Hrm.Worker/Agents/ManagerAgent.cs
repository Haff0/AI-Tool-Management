using Hrm.Domain.Tasks;
using Microsoft.Extensions.Logging;

namespace Hrm.Worker.Agents;

public sealed class ManagerAgent : IManagerAgent
{
    private readonly IExecutorAgent _executor;
    private readonly ILogger<ManagerAgent> _logger;

    public ManagerAgent(IExecutorAgent executor, ILogger<ManagerAgent> logger)
    {
        _executor = executor;
        _logger = logger;
    }

    public async Task ExecutePlanAsync(WorkRequest request, string plan, CancellationToken ct = default)
    {
        _logger.LogInformation("Manager: Distributing plan steps to executor...");
        
        // TODO: This uses an MVP design pattern: forwarding the whole plan to executor.
        // A production pattern might parse the plan sequence and manage state incrementally.
        var execResult = await _executor.ExecuteTaskAsync(plan, ct);
        
        _logger.LogInformation("Manager: final executor output:\n{Result}", execResult);
    }
}
