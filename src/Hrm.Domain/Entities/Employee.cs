namespace Hrm.Domain.Entities;

public class Employee
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public string Department { get; set; } = string.Empty;
    public string RoleLevel { get; set; } = "Level1_Employee"; // Level1_Employee or Level2_Manager
    public string ContractId { get; set; } = string.Empty;
}
