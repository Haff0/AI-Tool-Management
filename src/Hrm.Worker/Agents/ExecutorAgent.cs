using ConnectAI.Gemini;
using Microsoft.Extensions.Logging;

namespace Hrm.Worker.Agents;

public sealed class ExecutorAgent : IExecutorAgent
{
    private readonly IAIService _aiService;
    private readonly ILogger<ExecutorAgent> _logger;

    public ExecutorAgent(IAIService aiService, ILogger<ExecutorAgent> logger)
    {
        _aiService = aiService;
        _logger = logger;
    }

    public async Task<string> ExecuteTaskAsync(string taskDescription, CancellationToken ct = default)
    {
        _logger.LogInformation("Executor: running task chunk...");
        var prompt = $"Execute the following task/step as an AI agent:\n{taskDescription}\nProvide the exact action result or report on failure.";
        
        var result = await _aiService.GenerateContentAsync(prompt);
        return result.Text;
    }
}
