public class Startup
{
    public void ConfigureServices(IServiceCollection services)
    {
        var configs = new List<BusConfig>
        {
            new BusConfig
            {
                Transport = TransportType.RabbitMQ,
                ConnectionString = "rabbitmq://localhost",
                UserName = "guest",
                Password = "guest",
                ReceiverQueue = "queue1",
                RetryCount = 5,
                RetryInterval = TimeSpan.FromSeconds(10)
            },
            // Add other configurations here
        };

        services.AddMassTransit(x =>
        {
            foreach (var config in configs)
            {
                // Example with different consumer and message types
                CommonBusConfigurator.ConfigureBus<FilteredProcessingConsumer<Message1>, Message1>(x, config, message => message.Priority > 5, async msg =>
                {
                    // Apply some operation to the message
                    msg.Content = $"Processed: {msg.Content}";
                    return msg;
                });

                CommonBusConfigurator.ConfigureBus<FilteredProcessingConsumer<Message2>, Message2>(x, config, message => message.Type == "Important", async msg =>
                {
                    // Apply another operation to the message
                    msg.Content = $"Important Processed: {msg.Content}";
                    return msg;
                });
                // Add other configurations here
            }
        });

        services.AddMassTransitHostedService();

        // Register other services
        services.AddTransient<Publisher>();
        services.AddTransient<IMessageSendingService, MessageSendingService>();
        services.AddSingleton(config);
    }

    public void Configure(IApplicationBuilder app, IWebHostEnvironment env)
    {
        // Configure the application
    }
}