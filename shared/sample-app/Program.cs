using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using System.Net;

const string RequestIdHeader = "X-Request-Id";
const string RequestIdItemKey = "RequestId";

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddHealthChecks();
builder.Services.AddHttpClient("downstream", client =>
{
    client.Timeout = TimeSpan.FromSeconds(5);
});

var app = builder.Build();

var logger = app.Logger;

app.Use(async (context, next) =>
{
    var requestId = context.Request.Headers[RequestIdHeader].FirstOrDefault()?.Trim()
        .Replace("\r", string.Empty)
        .Replace("\n", string.Empty);

    if (string.IsNullOrEmpty(requestId))
    {
        requestId = Guid.NewGuid().ToString("N");
    }
    else if (requestId.Length > 128)
    {
        requestId = requestId[..128];
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

app.MapGet("/", async (HttpContext context, IHttpClientFactory httpClientFactory) =>
{
    var serviceInfo = CreateServiceInfo(context);
    var downstreamResult = await CallDownstreamAsync(context, httpClientFactory, logger);
    var requestInfo = serviceInfo.Request;
    var selectedHeaderRows = requestInfo.SelectedHeaders.Count == 0
        ? @"<div class=""info-item""><span class=""empty"">No selected ingress or gateway headers were present.</span></div>"
        : string.Join(Environment.NewLine, requestInfo.SelectedHeaders.Select(header => $@"
            <div class=""info-item"">
                <span class=""label"">{Display(header.Key)}:</span> {Display(header.Value)}
            </div>"));
    var downstreamHtml = downstreamResult is null
        ? @"<div class=""info-item""><span class=""empty"">No downstream service configured for this role.</span></div>"
        : $@"
            <div class=""info-item""><span class=""label"">Target:</span> {Display(downstreamResult.TargetUrl)}</div>
            <div class=""info-item""><span class=""label"">Status:</span> {Display(downstreamResult.Success ? "Success" : "Failed")}</div>
            <div class=""info-item""><span class=""label"">HTTP Status:</span> {Display(downstreamResult.StatusCode?.ToString())}</div>
            <div class=""info-item""><span class=""label"">Elapsed:</span> {downstreamResult.ElapsedMilliseconds} ms</div>
            <pre>{Display(downstreamResult.Body)}</pre>";

    var html = $@"
<!DOCTYPE html>
<html lang=""en"">
<head>
    <meta charset=""UTF-8"">
    <meta name=""viewport"" content=""width=device-width, initial-scale=1.0"">
    <title>{Display(serviceInfo.DemoName)}</title>
    <style>
        body {{
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            margin: 0;
            padding: 20px;
        }}
        .container {{
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            padding: 40px;
            max-width: 900px;
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
        .empty {{
            opacity: 0.8;
            font-style: italic;
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
        .button {{
            display: inline-block;
            margin-top: 10px;
            padding: 12px 18px;
            border-radius: 8px;
            color: #2d2d2d;
            background: #ffd700;
            text-decoration: none;
            font-weight: 700;
        }}
        pre {{
            white-space: pre-wrap;
            word-break: break-word;
            background: rgba(0, 0, 0, 0.25);
            border-radius: 8px;
            padding: 12px;
            overflow-x: auto;
        }}
    </style>
</head>
<body>
    <div class=""container"">
        <div class=""logo"">🚀</div>
        <h1>{Display(serviceInfo.DemoName)}</h1>
        <div class=""info"">
            <div class=""info-item"">
                <span class=""label"">Service:</span> {Display(serviceInfo.ServiceName)}
            </div>
            <div class=""info-item"">
                <span class=""label"">Demo Type:</span> {Display(serviceInfo.DemoType)}
            </div>
            <div class=""info-item"">
                <span class=""label"">Pod Name:</span> {Display(serviceInfo.Hostname)}
            </div>
            <div class=""info-item"">
                <span class=""label"">Version:</span> {Display(serviceInfo.Version)}
            </div>
            <div class=""info-item"">
                <span class=""label"">Request ID:</span> {Display(serviceInfo.RequestId)}
            </div>
            <div class=""info-item"">
                <span class=""label"">Status:</span> ✅ Running on Azure Kubernetes Service
            </div>
        </div>
        <div class=""info"">
            <h2>Mesh Traffic</h2>
            {downstreamHtml}
            <a class=""button"" href=""/api/call"">Generate mesh traffic</a>
        </div>
        <div class=""info"">
            <h2>Request Inspector</h2>
            <div class=""info-item"">
                <span class=""label"">Host:</span> {Display(requestInfo.Host)}
            </div>
            <div class=""info-item"">
                <span class=""label"">Path:</span> {Display(requestInfo.Path)}
            </div>
            <div class=""info-item"">
                <span class=""label"">Scheme:</span> {Display(requestInfo.Scheme)}
            </div>
            <div class=""info-item"">
                <span class=""label"">Method:</span> {Display(requestInfo.Method)}
            </div>
            <div class=""info-item"">
                <span class=""label"">Query String:</span> {Display(requestInfo.QueryString)}
            </div>
            <div class=""info-item"">
                <span class=""label"">Remote IP:</span> {Display(requestInfo.RemoteIp)}
            </div>
            <div class=""info-item"">
                <span class=""label"">User Agent:</span> {Display(requestInfo.UserAgent)}
            </div>
        </div>
        <div class=""info"">
            <h2>Selected Headers</h2>
            {selectedHeaderRows}
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
app.MapHealthChecks("/health/live");
app.MapHealthChecks("/health/ready");

app.MapGet("/api/info", (HttpContext context) => Results.Json(CreateServiceInfo(context)));
app.MapGet("/api/call", async (HttpContext context, IHttpClientFactory httpClientFactory) =>
{
    var serviceInfo = CreateServiceInfo(context);
    var downstream = await CallDownstreamAsync(context, httpClientFactory, logger);

    return Results.Json(new
    {
        Service = serviceInfo,
        Downstream = downstream
    });
});
app.MapGet("/api/orders", async (HttpContext context, IHttpClientFactory httpClientFactory) =>
{
    var serviceInfo = CreateServiceInfo(context);
    var downstream = await CallDownstreamAsync(context, httpClientFactory, logger);

    return Results.Json(new
    {
        Service = serviceInfo,
        Downstream = downstream
    });
});

logger.LogInformation("Starting AKS Ingress Demo Application");
logger.LogInformation("Service Name: {ServiceName}", Environment.GetEnvironmentVariable("SERVICE_NAME") ?? "Not Set");
logger.LogInformation("Demo Name: {DemoName}", Environment.GetEnvironmentVariable("DEMO_NAME") ?? "Not Set");
logger.LogInformation("Demo Type: {DemoType}", Environment.GetEnvironmentVariable("DEMO_TYPE") ?? "Not Set");
logger.LogInformation("Downstream URL: {DownstreamUrl}", Environment.GetEnvironmentVariable("DOWNSTREAM_URL") ?? "Not Set");

app.Run();

static ServiceInfo CreateServiceInfo(HttpContext context)
{
    var demoName = Environment.GetEnvironmentVariable("DEMO_NAME") ?? "AKS Ingress Demo";
    var demoType = Environment.GetEnvironmentVariable("DEMO_TYPE") ?? "Unknown";
    var serviceName = Environment.GetEnvironmentVariable("SERVICE_NAME") ?? demoName;
    var hostname = Environment.GetEnvironmentVariable("HOSTNAME") ?? "unknown-pod";
    var version = Environment.GetEnvironmentVariable("APP_VERSION") ?? "1.0.0";
    var downstreamUrl = Environment.GetEnvironmentVariable("DOWNSTREAM_URL") ?? string.Empty;

    return new ServiceInfo(
        serviceName,
        demoName,
        demoType,
        hostname,
        version,
        context.Items[RequestIdItemKey] as string ?? context.TraceIdentifier,
        string.IsNullOrWhiteSpace(downstreamUrl) ? null : downstreamUrl,
        "Running",
        CreateRequestInspector(context));
}

static async Task<DownstreamCall?> CallDownstreamAsync(HttpContext context, IHttpClientFactory httpClientFactory, ILogger logger)
{
    var downstreamUrl = Environment.GetEnvironmentVariable("DOWNSTREAM_URL");
    if (string.IsNullOrWhiteSpace(downstreamUrl))
    {
        return null;
    }

    if (!Uri.TryCreate(downstreamUrl, UriKind.Absolute, out var uri) || (uri.Scheme != Uri.UriSchemeHttp && uri.Scheme != Uri.UriSchemeHttps))
    {
        return new DownstreamCall(
            Environment.GetEnvironmentVariable("DOWNSTREAM_LABEL") ?? "downstream",
            downstreamUrl,
            false,
            null,
            0,
            "DOWNSTREAM_URL must be an absolute HTTP or HTTPS URL.");
    }

    var started = DateTimeOffset.UtcNow;
    var requestId = context.Items[RequestIdItemKey] as string ?? context.TraceIdentifier;
    var client = httpClientFactory.CreateClient("downstream");
    using var request = new HttpRequestMessage(HttpMethod.Get, uri);
    request.Headers.TryAddWithoutValidation(RequestIdHeader, requestId);
    request.Headers.TryAddWithoutValidation("X-Forwarded-Host", context.Request.Host.Value);
    request.Headers.TryAddWithoutValidation("X-Forwarded-Proto", context.Request.Scheme);
    request.Headers.TryAddWithoutValidation("X-Source-Service", Environment.GetEnvironmentVariable("SERVICE_NAME") ?? "sample-app");

    try
    {
        using var response = await client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, context.RequestAborted);
        var body = await response.Content.ReadAsStringAsync(context.RequestAborted);
        if (body.Length > 2_000)
        {
            body = body[..2_000] + "...";
        }

        return new DownstreamCall(
            Environment.GetEnvironmentVariable("DOWNSTREAM_LABEL") ?? uri.Host,
            uri.ToString(),
            response.IsSuccessStatusCode,
            (int)response.StatusCode,
            (long)(DateTimeOffset.UtcNow - started).TotalMilliseconds,
            body);
    }
    catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or OperationCanceledException)
    {
        logger.LogWarning(ex, "Downstream call to {DownstreamUrl} failed", uri);
        return new DownstreamCall(
            Environment.GetEnvironmentVariable("DOWNSTREAM_LABEL") ?? uri.Host,
            uri.ToString(),
            false,
            null,
            (long)(DateTimeOffset.UtcNow - started).TotalMilliseconds,
            ex.Message);
    }
}

static RequestInspector CreateRequestInspector(HttpContext context)
{
    var request = context.Request;

    return new RequestInspector(
        request.Host.Value ?? "unknown",
        request.PathBase.Add(request.Path).Value ?? "/",
        request.Scheme,
        request.Method,
        request.QueryString.HasValue ? request.QueryString.Value : string.Empty,
        context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
        request.Headers.UserAgent.ToString(),
        GetSelectedHeaders(request.Headers));
}

static IReadOnlyDictionary<string, string> GetSelectedHeaders(IHeaderDictionary headers)
{
    var selectedHeaders = new SortedDictionary<string, string>(StringComparer.OrdinalIgnoreCase);
    var selectedHeaderNames = new[]
    {
        "X-Forwarded-For",
        "X-Forwarded-Proto",
        "X-Forwarded-Host",
        "X-Forwarded-Port",
        "X-Forwarded-Prefix",
        "X-Real-IP",
        "X-Request-Id",
        "X-Correlation-Id",
        "X-Source-Service",
        "X-Envoy-External-Address",
        "X-Envoy-Original-Path",
        "X-Envoy-Expected-Rq-Timeout-Ms",
        "X-AppGw-Trace-Id",
        "X-Original-Host",
        "X-Original-Url",
        "X-Azure-ClientIP",
        "X-Azure-Ref"
    };

    foreach (var headerName in selectedHeaderNames)
    {
        if (headers.TryGetValue(headerName, out var value) && value.Count > 0)
        {
            selectedHeaders[headerName] = value.ToString();
        }
    }

    foreach (var header in headers)
    {
        if (IsGatewayHeader(header.Key) && !selectedHeaders.ContainsKey(header.Key))
        {
            selectedHeaders[header.Key] = header.Value.ToString();
        }
    }

    return selectedHeaders;
}

static bool IsGatewayHeader(string headerName)
{
    var gatewayHeaderPrefixes = new[]
    {
        "X-AppGw-",
        "X-Azure-",
        "X-Envoy-",
        "X-Gateway-",
        "X-Original-"
    };

    return gatewayHeaderPrefixes.Any(prefix => headerName.StartsWith(prefix, StringComparison.OrdinalIgnoreCase));
}

static string Display(string? value)
{
    return WebUtility.HtmlEncode(string.IsNullOrWhiteSpace(value) ? "—" : value);
}

record ServiceInfo(
    string ServiceName,
    string DemoName,
    string DemoType,
    string Hostname,
    string Version,
    string RequestId,
    string? DownstreamUrl,
    string Status,
    RequestInspector Request);

record DownstreamCall(
    string Label,
    string TargetUrl,
    bool Success,
    int? StatusCode,
    long ElapsedMilliseconds,
    string Body);

record RequestInspector(
    string Host,
    string Path,
    string Scheme,
    string Method,
    string QueryString,
    string RemoteIp,
    string UserAgent,
    IReadOnlyDictionary<string, string> SelectedHeaders);
