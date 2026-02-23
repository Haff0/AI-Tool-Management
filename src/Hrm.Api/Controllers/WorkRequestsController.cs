using Microsoft.AspNetCore.Mvc;
using Hrm.Application.Features.WorkRequests.CreateWorkRequest;

namespace Hrm.Api.Controllers;

[ApiController]
[Route("api/work-requests")]
public sealed class WorkRequestsController : ControllerBase
{
    private readonly CreateWorkRequestHandler _handler;

    public WorkRequestsController(CreateWorkRequestHandler handler)
    {
        _handler = handler;
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateWorkRequestRequest request, CancellationToken ct)
    {
        var correlationId = HttpContext.TraceIdentifier;
        var id = await _handler.HandleAsync(
            new CreateWorkRequestCommand(request.Title, request.Description),
            correlationId,
            ct
        );

        return CreatedAtAction(nameof(GetById), new { id }, new { id, correlationId });
    }

    [HttpGet("{id:guid}")]
    public IActionResult GetById(Guid id) => Ok(new { id });
}

public sealed record CreateWorkRequestRequest(string Title, string Description);
