# AKS Ingress Demo - Sample Application

This is a simple .NET 10 minimal API web application used across all three AKS ingress demos.

## Features

- **Main Page** (`/`): Displays demo information with a beautiful UI
- **Health Checks** (`/health`, `/health/live`, `/health/ready`): Compatibility, liveness, and readiness endpoints
- **API Info** (`/api/info`): JSON endpoint with demo metadata

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

## Technology Stack

- .NET 10 minimal API
- No external dependencies
- Optimized for containerized deployments
