using Hrm.Domain.Tasks;

namespace Hrm.Worker.Agents;

public interface IManagerAgent
{
    Task ExecutePlanAsync(WorkRequest request, string plan, CancellationToken ct = default);
}
