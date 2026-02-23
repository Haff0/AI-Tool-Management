using RabbitMQ.Client;
using RabbitMQ.Client.Events;
using System.Text;
using System.Text.Json;
using Hrm.Contracts.Events;
using Hrm.Application.Abstractions;
using Hrm.Worker.Agents;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace Hrm.Worker.Consumers;

public sealed class RabbitEventConsumer : BackgroundService
{
    private readonly ILogger<RabbitEventConsumer> _logger;
    private readonly IConfiguration _config;
    private readonly RabbitConnectionFactory _factory;
    private readonly IServiceScopeFactory _scopeFactory;

    private IConnection? _conn;
    private IChannel? _ch;
    private AsyncEventingBasicConsumer? _consumer;

    public RabbitEventConsumer(
        ILogger<RabbitEventConsumer> logger,
        IConfiguration config,
        RabbitConnectionFactory factory,
        IServiceScopeFactory scopeFactory)
    {
        _logger = logger;
        _config = config;
        _factory = factory;
        _scopeFactory = scopeFactory;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _conn = await _factory.CreateConnection(_config);
        _ch = await _conn.CreateChannelAsync();

        var exchange = _config["Rabbit:Exchange"] ?? "hrm.events";
        var queue = _config["Rabbit:Queue"] ?? "hrm.worker";
        var routingKey = _config["Rabbit:RoutingKey"] ?? "workrequest.created";

        await _ch.ExchangeDeclareAsync(exchange, ExchangeType.Topic, durable: true, autoDelete: false);
        await _ch.QueueDeclareAsync(queue, durable: true, exclusive: false, autoDelete: false);
        await _ch.QueueBindAsync(queue, exchange, routingKey);

        await _ch.BasicQosAsync(0, prefetchCount: 10, global: false);

        _consumer = new AsyncEventingBasicConsumer(_ch);
        _consumer.ReceivedAsync += OnMessageAsync;

        await _ch.BasicConsumeAsync(queue, autoAck: false, consumer: _consumer);

        _logger.LogInformation(
            "Rabbit consumer started. exchange={Exchange} queue={Queue} key={Key}",
            exchange, queue, routingKey);

        try
        {
            await Task.Delay(Timeout.Infinite, stoppingToken);
        }
        catch (OperationCanceledException)
        {
        }
    }

    private async Task OnMessageAsync(object sender, BasicDeliverEventArgs ea)
    {
        try
        {
            var json = Encoding.UTF8.GetString(ea.Body.ToArray());

            var evt = JsonSerializer.Deserialize<WorkRequestCreatedEvent>(json, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });

            if (evt != null)
            {
                _logger.LogInformation("Received WorkRequestCreatedEvent. WorkRequestId={Id} CorrelationId={CorrelationId}", 
                    evt.WorkRequestId, evt.CorrelationId);

                using var scope = _scopeFactory.CreateScope();
                var repo = scope.ServiceProvider.GetRequiredService<IWorkRepository>();
                var planner = scope.ServiceProvider.GetRequiredService<IPlannerAgent>();
                var manager = scope.ServiceProvider.GetRequiredService<IManagerAgent>();

                var request = await repo.GetAsync(evt.WorkRequestId, CancellationToken.None);
                if (request != null)
                {
                    _logger.LogInformation("Planning WorkRequest {Id}...", request.Id);
                    var plan = await planner.CreatePlanAsync(request, CancellationToken.None);
                    
                    _logger.LogInformation("Executing Plan for {Id}...", request.Id);
                    await manager.ExecutePlanAsync(request, plan, CancellationToken.None);
                    
                    _logger.LogInformation("Finished WorkRequest {Id}", request.Id);
                }
                else
                {
                    _logger.LogWarning("WorkRequest {Id} not found in database.", evt.WorkRequestId);
                }
            }

            if (_ch != null)
                await _ch.BasicAckAsync(ea.DeliveryTag, multiple: false);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to handle message. routingKey={Key}", ea.RoutingKey);
            if (_ch != null)
                await _ch.BasicNackAsync(ea.DeliveryTag, multiple: false, requeue: true);
        }
    }

    public override void Dispose()
    {
        try { _ch?.CloseAsync(); } catch { }
        try { _conn?.CloseAsync(); } catch { }
        base.Dispose();
    }
}