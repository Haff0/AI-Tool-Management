using Hrm.Application.Abstractions;
using Hrm.Contracts.Events;
using Hrm.Domain.Tasks;

namespace Hrm.Application.Features.WorkRequests.CreateWorkRequest;

public sealed class CreateWorkRequestHandler
{
    private readonly IWorkRepository _repo;
    private readonly IEventBus _bus;

    public CreateWorkRequestHandler(IWorkRepository repo, IEventBus bus)
    {
        _repo = repo;
        _bus = bus;
    }

    public async Task<Guid> HandleAsync(CreateWorkRequestCommand cmd, string correlationId, CancellationToken ct)
    {
        var id = Guid.NewGuid();
        var entity = new WorkRequest(id, cmd.Title, cmd.Description);
        
        await _repo.AddAsync(entity, ct);

        var evt = new WorkRequestCreatedEvent(
            EventId: Guid.NewGuid(),
            OccurredUtc: DateTime.UtcNow,
            CorrelationId: correlationId,
            WorkRequestId: id,
            Title: cmd.Title
        );

        await _bus.PublishAsync(evt, ct);
        
        return id;
    }
}
