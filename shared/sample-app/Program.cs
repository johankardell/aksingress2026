using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

const string RequestIdHeader = "X-Request-Id";
const string RequestIdItemKey = "RequestId";

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddHealthChecks();

var app = builder.Build();

var logger = app.Logger;

app.Use(async (context, next) =>
{
    var requestId = context.Request.Headers[RequestIdHeader].FirstOrDefault();
    if (string.IsNullOrWhiteSpace(requestId))
    {
        requestId = Guid.NewGuid().ToString("N");
    }

    context.Items[RequestIdItemKey] = requestId;
    context.Response.OnStarting(() =>
    {
        context.Response.Headers[RequestIdHeader] = requestId;
        return Task.CompletedTask;
    });

    logger.LogInformation("Request received: {Method} {Path} from {RemoteIp} with {RequestIdHeader}: {RequestId}",
        context.Request.Method,
        context.Request.Path,
        context.Connection.RemoteIpAddress,
        RequestIdHeader,
        requestId);

    await next();
});

app.MapGet("/", () =>
{
    var demoName = Environment.GetEnvironmentVariable("DEMO_NAME") ?? "AKS Ingress Demo";
    var demoType = Environment.GetEnvironmentVariable("DEMO_TYPE") ?? "Unknown";
    var hostname = Environment.GetEnvironmentVariable("HOSTNAME") ?? "unknown-pod";
    var version = Environment.GetEnvironmentVariable("APP_VERSION") ?? "1.0.0";

    var html = $@"
<!DOCTYPE html>
<html lang=""en"">
<head>
    <meta charset=""UTF-8"">
    <meta name=""viewport"" content=""width=device-width, initial-scale=1.0"">
    <title>{demoName}</title>
    <style>
        body {{
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            padding: 20px;
        }}
        .container {{
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            padding: 40px;
            max-width: 600px;
            box-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.37);
            border: 1px solid rgba(255, 255, 255, 0.18);
        }}
        h1 {{
            margin-top: 0;
            font-size: 2.5em;
            text-align: center;
        }}
        .info {{
            background: rgba(255, 255, 255, 0.1);
            padding: 20px;
            border-radius: 10px;
            margin: 20px 0;
        }}
        .info-item {{
            margin: 10px 0;
            font-size: 1.1em;
        }}
        .label {{
            font-weight: bold;
            color: #ffd700;
        }}
        .footer {{
            text-align: center;
            margin-top: 30px;
            opacity: 0.8;
            font-size: 0.9em;
        }}
        .logo {{
            text-align: center;
            font-size: 4em;
            margin-bottom: 20px;
        }}
    </style>
</head>
<body>
    <div class=""container"">
        <div class=""logo"">🚀</div>
        <h1>{demoName}</h1>
        <div class=""info"">
            <div class=""info-item"">
                <span class=""label"">Demo Type:</span> {demoType}
            </div>
            <div class=""info-item"">
                <span class=""label"">Pod Name:</span> {hostname}
            </div>
            <div class=""info-item"">
                <span class=""label"">Version:</span> {version}
            </div>
            <div class=""info-item"">
                <span class=""label"">Status:</span> ✅ Running on Azure Kubernetes Service
            </div>
        </div>
        <div class=""footer"">
            <p>Azure AKS Ingress Comparison Demo 2026</p>
        </div>
    </div>
</body>
</html>";

    return Results.Content(html, "text/html");
});

app.MapHealthChecks("/health");

app.MapGet("/api/info", (HttpContext context) =>
{
    return new
    {
        DemoName = Environment.GetEnvironmentVariable("DEMO_NAME") ?? "AKS Ingress Demo",
        DemoType = Environment.GetEnvironmentVariable("DEMO_TYPE") ?? "Unknown",
        Hostname = Environment.GetEnvironmentVariable("HOSTNAME") ?? "unknown-pod",
        Version = Environment.GetEnvironmentVariable("APP_VERSION") ?? "1.0.0",
        RequestId = context.Items[RequestIdItemKey] as string ?? context.TraceIdentifier,
        Status = "Running"
    };
});

logger.LogInformation("Starting AKS Ingress Demo Application");
logger.LogInformation("Demo Name: {DemoName}", Environment.GetEnvironmentVariable("DEMO_NAME") ?? "Not Set");
logger.LogInformation("Demo Type: {DemoType}", Environment.GetEnvironmentVariable("DEMO_TYPE") ?? "Not Set");

app.Run();
