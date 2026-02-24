namespace Hrm.Worker.Agents;

public interface IExecutorAgent
{
    Task<string> ExecuteTaskAsync(string taskDescription, CancellationToken ct = default);
}
