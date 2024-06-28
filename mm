To pass the filter condition directly inside the `Consume` method of the consumer, you can modify the consumer class to accept a filter condition delegate. This way, the filtering logic is encapsulated within the consumer itself. Here’s how you can achieve this:

### Step 1: Define the Consumer with a Filter Condition

First, modify the consumer class to accept a filter condition delegate and apply it within the `Consume` method.

```csharp
// FilteredProcessingConsumer.cs
public class FilteredProcessingConsumer<TMessage> : IConsumer<TMessage> where TMessage : class
{
    private readonly Func<TMessage, bool> _filterCondition;
    private readonly Func<TMessage, Task<TMessage>> _processMessage;
    private readonly IPublishEndpoint _publishEndpoint;

    public FilteredProcessingConsumer(Func<TMessage, bool> filterCondition, Func<TMessage, Task<TMessage>> processMessage, IPublishEndpoint publishEndpoint)
    {
        _filterCondition = filterCondition;
        _processMessage = processMessage;
        _publishEndpoint = publishEndpoint;
    }

    public async Task Consume(ConsumeContext<TMessage> context)
    {
        if (_filterCondition(context.Message))
        {
            var processedMessage = await _processMessage(context.Message);
            await _publishEndpoint.Publish(processedMessage);
        }
    }
}
```

### Step 2: Implement the Common Bus Configurator

Update the common bus configurator to configure the consumer with the necessary filter condition and processing logic.

```csharp
// CommonBusConfigurator.cs
public static class CommonBusConfigurator
{
    public static void ConfigureBus<TConsumer, TMessage>(IBusRegistrationConfigurator configurator, BusConfig config, Func<TMessage, bool> filterCondition, Func<TMessage, Task<TMessage>> processMessage)
        where TConsumer : class, IConsumer<TMessage>
        where TMessage : class
    {
        configurator.AddConsumer(() => new FilteredProcessingConsumer<TMessage>(filterCondition, processMessage, configurator.GetRequiredService<IPublishEndpoint>()));

        switch (config.Transport)
        {
            case TransportType.RabbitMQ:
                configurator.UsingRabbitMq((context, cfg) =>
                {
                    cfg.Host(config.ConnectionString, h =>
                    {
                        h.Username(config.UserName);
                        h.Password(config.Password);
                    });

                    cfg.ReceiveEndpoint(config.ReceiverQueue, e =>
                    {
                        e.ConfigureConsumer<TConsumer>(context);
                    });
                });
                break;

            case TransportType.AzureServiceBus:
                configurator.UsingAzureServiceBus((context, cfg) =>
                {
                    cfg.Host(config.ConnectionString);

                    cfg.ReceiveEndpoint(config.ReceiverQueue, e =>
                    {
                        e.ConfigureConsumer<TConsumer>(context);
                    });
                });
                break;

            default:
                throw new ArgumentException("Invalid transport type");
        }
    }
}
```

### Step 3: Configure Services in Startup

Update the `ConfigureServices` method in `Startup` to use the common bus configurator and pass the filter conditions.

```csharp
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
```

### Explanation

1. **FilteredProcessingConsumer**: This consumer class takes a filter condition and a message processing function as constructor parameters. The `Consume` method applies the filter and processes the message accordingly.

2. **CommonBusConfigurator**: This static class provides a method to configure the bus using the provided configuration. It also configures the consumer with the necessary filter condition and processing logic.

3. **Startup Configuration**: The `ConfigureServices` method in `Startup.cs` sets up the MassTransit configuration. It iterates over a list of configurations and uses the `CommonBusConfigurator` to configure the bus for different consumer/message types, passing the filter conditions and processing logic directly.

By following this approach, you can pass the filter condition inside the `Consume` method of the consumer, making the filtering logic more flexible and encapsulated within the consumer itself. Adjust the configurations, consumers, and message types according to your specific requirements.