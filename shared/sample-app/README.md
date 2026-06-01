# AKS Ingress Demo - Sample Application

This is a simple .NET 10 minimal API web application used across all three AKS ingress demos.

## Features

- **Main Page** (`/`): Displays demo information with a beautiful UI
- **Health Check** (`/health`): Kubernetes health probe endpoint
- **API Info** (`/api/info`): JSON endpoint with demo metadata and the current request ID
- **Request Tracing**: Accepts or generates `X-Request-Id`, returns it as a response header, and includes it in application logs

## Environment Variables

The application uses environment variables to customize the display:

- `DEMO_NAME`: The name of the demo (e.g., "NGINX Ingress Demo")
- `DEMO_TYPE`: The type of ingress (e.g., "NGINX Ingress Controller", "Gateway API with Envoy", "Application Gateway for Containers")
- `APP_VERSION`: Application version (default: "1.0.0")
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
APP_LABEL="app=nginx-demo-app" # use app=envoy-demo-app or app=agc-demo-app for those demos

curl -i -H "X-Request-Id: ${REQUEST_ID}" "http://${APP_HOST}/api/info"
kubectl logs -n demo -l "${APP_LABEL}" --since=5m | grep "${REQUEST_ID}"
```

## Technology Stack

- .NET 10 minimal API
- No external dependencies
- Optimized for containerized deployments
