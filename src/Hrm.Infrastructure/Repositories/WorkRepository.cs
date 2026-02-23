using Microsoft.EntityFrameworkCore;
using Hrm.Application.Abstractions;
using Hrm.Domain.Tasks;
using Hrm.Infrastructure.Persistence;

namespace Hrm.Infrastructure.Repositories;

public sealed class WorkRepository : IWorkRepository
{
    private readonly AppDbContext _db;

    public WorkRepository(AppDbContext db) => _db = db;

    public async Task AddAsync(WorkRequest entity, CancellationToken ct)
    {
        _db.WorkRequests.Add(entity);
        await _db.SaveChangesAsync(ct);
    }

    public Task<WorkRequest?> GetAsync(Guid id, CancellationToken ct)
        => _db.WorkRequests.FirstOrDefaultAsync(x => x.Id == id, ct);
}
