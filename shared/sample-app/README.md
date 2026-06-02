# AKS Ingress Demo - Sample Application

This is a simple .NET 10 minimal API web application used across all AKS ingress and service networking demos.

## Features

- **Main Page** (`/`): Displays demo information and request inspector details with a beautiful UI
- **Health Checks** (`/health`, `/health/live`, `/health/ready`): Compatibility, liveness, and readiness endpoints
- **API Info** (`/api/info`): JSON endpoint with service metadata, request inspector data, the current request ID, and downstream configuration
- **Downstream Call** (`/api/call`, `/api/orders`): Calls the configured downstream service and returns a nested JSON result for mesh demos
- **Request Tracing**: Accepts or generates `X-Request-Id`, returns it as a response header, forwards it downstream, and includes it in application logs

## Environment Variables

The application uses environment variables to customize the display:

- `SERVICE_NAME`: Service role name shown in JSON and the UI (e.g., `frontend`, `orders`, `inventory`)
- `DEMO_NAME`: The name of the demo (e.g., "NGINX Ingress Demo")
- `DEMO_TYPE`: The type of ingress or service networking path (e.g., "NGINX Ingress Controller", "Gateway API with Envoy", "Application Gateway for Containers")
- `APP_VERSION`: Application version (default: "1.0.0")
- `DOWNSTREAM_URL`: Optional absolute HTTP/HTTPS URL to call from `/` and `/api/call`
- `DOWNSTREAM_LABEL`: Optional friendly name for the downstream dependency
- `HOSTNAME`: Pod hostname (automatically set by Kubernetes)

## Running Locally

```bash
dotnet run
```

Visit http://localhost:5000 to see the application.

Trace a single request locally:

```bash
REQUEST_ID="demo-$(date +%s)"
curl -i -H "X-Request-Id: ${REQUEST_ID}" http://localhost:5000/api/info
```

Run with a downstream target for mesh-call testing:

```bash
SERVICE_NAME=frontend DOWNSTREAM_URL=http://localhost:5000/api/info dotnet run
curl -s http://localhost:5000/api/call
```

## Health Probes

The app exposes three health endpoints:

- `/health`: Compatibility endpoint for scripts and documentation that need a simple health check.
- `/health/live`: Kubernetes liveness probe endpoint. It reports whether the app process is running and should be restarted if it fails.
- `/health/ready`: Kubernetes readiness probe endpoint. It reports whether the app is ready to receive traffic.

## Building with Azure Container Registry Tasks

```bash
source ../scripts/acr-image.sh
ensure_sample_app_image "<acr-name>" "." "aks-ingress-demo"
```

This tags the image with a source-content hash, skips the build if that tag already exists in ACR, and builds remotely in Azure when needed. The local machine does not need Docker installed.

## Tracing a Request in AKS

After deploying one of the demos, send a request with a known ID and search for the same value in the app logs:

```bash
REQUEST_ID="demo-$(date +%s)"
APP_HOST="<application-ip-or-hostname>"
APP_NAMESPACE="demo" # sample manifests in this repository deploy to the demo namespace
APP_LABEL="app=nginx-demo-app" # use app=envoy-demo-app or app=agc-demo-app for those demos

curl -i -H "X-Request-Id: ${REQUEST_ID}" "http://${APP_HOST}/api/info"
kubectl logs -n "${APP_NAMESPACE}" -l "${APP_LABEL}" --since=5m | grep "${REQUEST_ID}"
```

## Technology Stack

- .NET 10 minimal API
- Uses the built-in .NET HTTP client factory for optional downstream calls
- Optimized for containerized deployments
