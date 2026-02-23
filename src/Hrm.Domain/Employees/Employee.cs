using Hrm.Domain.Common;

namespace Hrm.Domain.Employees;

public sealed class Employee : AggregateRoot<Guid>
{
    public string Code { get; private set; } = string.Empty;
    public string FullName { get; private set; } = string.Empty;

    private Employee() { }

    public Employee(Guid id, string code, string fullName)
    {
        Id = id;
        Code = code;
        FullName = fullName;
    }
}
