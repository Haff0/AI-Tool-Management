using Hrm.Domain.Tasks;

namespace Hrm.Worker.Agents;

public interface IPlannerAgent
{
    Task<string> CreatePlanAsync(WorkRequest request, CancellationToken ct = default);
}
