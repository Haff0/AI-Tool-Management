using RabbitMQ.Client;
using RabbitMQ.Client.Events;
using Shared.Contracts;
using Shared.Observability;
using System.Text;
using System.Text.Json;

public sealed class RabbitEventConsumer : BackgroundService
{
    private readonly ILogger<RabbitEventConsumer> _logger;
    private readonly IConfiguration _config;
    private readonly RabbitConnectionFactory _factory;

    private IConnection? _conn;
    private IChannel? _ch;
    private AsyncEventingBasicConsumer? _consumer;

    public RabbitEventConsumer(
        ILogger<RabbitEventConsumer> logger,
        IConfiguration config,
        RabbitConnectionFactory factory)
    {
        _logger = logger;
        _config = config;
        _factory = factory;
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

        // Quan trọng: giữ BackgroundService sống cho đến khi bị stop
        try
        {
            await Task.Delay(Timeout.Infinite, stoppingToken);
        }
        catch (OperationCanceledException)
        {
            // expected when stoppingToken is cancelled
        }
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

            _ch?.BasicAckAsync(ea.DeliveryTag, multiple: false);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to handle message. routingKey={Key}", ea.RoutingKey);
            // Requeue=true for transient errors
            _ch?.BasicNackAsync(ea.DeliveryTag, multiple: false, requeue: true);
        }
    }

    public override void Dispose()
    {
        try { _ch?.CloseAsync(); } catch { }
        try { _conn?.CloseAsync(); } catch { }
        base.Dispose();
    }
}