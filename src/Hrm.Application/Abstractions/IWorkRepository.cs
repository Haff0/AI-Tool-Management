using Hrm.Domain.Tasks;

namespace Hrm.Application.Abstractions;

public interface IWorkRepository
{
    Task AddAsync(WorkRequest entity, CancellationToken ct);
    Task<WorkRequest?> GetAsync(Guid id, CancellationToken ct);
}
