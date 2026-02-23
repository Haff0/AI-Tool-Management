using Hrm.Domain.Common;

namespace Hrm.Domain.Tasks;

public sealed class WorkRequest : AggregateRoot<Guid>
{
    public string Title { get; private set; } = string.Empty;
    public string Description { get; private set; } = string.Empty;

    private WorkRequest() { }

    public WorkRequest(Guid id, string title, string description)
    {
        Id = id;
        Title = title;
        Description = description;
    }
}
