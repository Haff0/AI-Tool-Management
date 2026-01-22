using System.Text;
using System.Text.Json;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;
using Shared.Contracts;
using Shared.Observability;

public sealed class RabbitEventConsumer : BackgroundService
{
    private readonly ILogger<RabbitEventConsumer> _logger;
    private readonly IConfiguration _config;
    private readonly RabbitConnectionFactory _factory;

    private IConnection? _conn;
    private IModel? _ch;

    public RabbitEventConsumer(
        ILogger<RabbitEventConsumer> logger,
        IConfiguration config,
        RabbitConnectionFactory factory)
    {
        _logger = logger;
        _config = config;
        _factory = factory;
    }

    protected override Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _conn = _factory.CreateConnection(_config);
        _ch = _conn.CreateModel();

        var exchange = _config["Rabbit:Exchange"] ?? "hrm.events";
        var queue = _config["Rabbit:Queue"] ?? "hrm.worker";
        var routingKey = _config["Rabbit:RoutingKey"] ?? "workrequest.created";

        _ch.ExchangeDeclare(exchange, ExchangeType.Topic, durable: true, autoDelete: false);
        _ch.QueueDeclare(queue, durable: true, exclusive: false, autoDelete: false);
        _ch.QueueBind(queue, exchange, routingKey);

        var consumer = new AsyncEventingBasicConsumer(_ch);
        consumer.Received += OnMessageAsync;

        _ch.BasicQos(0, prefetchCount: 10, global: false);
        _ch.BasicConsume(queue, autoAck: false, consumer);

        _logger.LogInformation("Rabbit consumer started. exchange={Exchange} queue={Queue} key={Key}", exchange, queue, routingKey);

        return Task.CompletedTask;
    }

    private async Task OnMessageAsync(object sender, BasicDeliverEventArgs ea)
    {
        try
        {
            var json = Encoding.UTF8.GetString(ea.Body.ToArray());

            // Example: WorkRequestCreated event
            // If your routing key includes multiple events, switch by ea.RoutingKey
            var evt = JsonSerializer.Deserialize<WorkRequestCreated>(json, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });

            var correlationId = Correlation.Ensure(evt?.CorrelationId);

            _logger.LogInformation("Received WorkRequestCreated. id={Id} correlationId={CorrelationId}", evt?.WorkRequestId, correlationId);

            // TODO: call planner -> manager -> executor pipeline
            await Task.Delay(10);

            _ch?.BasicAck(ea.DeliveryTag, multiple: false);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to handle message. routingKey={Key}", ea.RoutingKey);
            // Requeue=true for transient errors
            _ch?.BasicNack(ea.DeliveryTag, multiple: false, requeue: true);
        }
    }

    public override void Dispose()
    {
        try { _ch?.Close(); } catch { }
        try { _conn?.Close(); } catch { }
        base.Dispose();
    }
}
