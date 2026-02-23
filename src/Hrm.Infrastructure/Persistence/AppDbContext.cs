using Microsoft.EntityFrameworkCore;
using Hrm.Domain.Employees;
using Hrm.Domain.Tasks;

namespace Hrm.Infrastructure.Persistence;

public sealed class AppDbContext : DbContext
{
    public DbSet<Employee> Employees => Set<Employee>();
    public DbSet<WorkRequest> WorkRequests => Set<WorkRequest>();

    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        // Add configurations here later if needed
    }
}
