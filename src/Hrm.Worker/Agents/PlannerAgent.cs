using Hrm.Domain.Tasks;
using ConnectAI.Gemini;
using Microsoft.Extensions.Logging;

namespace Hrm.Worker.Agents;

public sealed class PlannerAgent : IPlannerAgent
{
    private readonly IAIService _aiService;
    private readonly ILogger<PlannerAgent> _logger;

    public PlannerAgent(IAIService aiService, ILogger<PlannerAgent> logger)
    {
        _aiService = aiService;
        _logger = logger;
    }

    public async Task<string> CreatePlanAsync(WorkRequest request, CancellationToken ct = default)
    {
        _logger.LogInformation("Planner: generating plan for '{Title}'", request.Title);
        var prompt = $"Create a simple step-by-step sequential plan to fulfill this request:\nTitle: {request.Title}\nDescription: {request.Description}\nRespond strictly with the plan text. Do not over-explain.";
        
        var result = await _aiService.GenerateContentAsync(prompt);
        return result.Text;
    }
}
