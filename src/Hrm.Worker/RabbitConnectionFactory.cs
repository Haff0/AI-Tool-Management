using RabbitMQ.Client;

public sealed class RabbitConnectionFactory
{
    public async Task<IConnection> CreateConnection(IConfiguration config)
    {
        var host = config["Rabbit:Host"] ?? "rabbitmq";
        var user = config["Rabbit:User"] ?? "guest";
        var pass = config["Rabbit:Pass"] ?? "guest";
        var vhost = config["Rabbit:VHost"] ?? "/";

        var factory = new ConnectionFactory
        {
            HostName = host,
            UserName = user,
            Password = pass,
            VirtualHost = vhost,
            //DispatchConsumersAsync = true
        };

        return await factory.CreateConnectionAsync("hrm-worker");
    }
}
