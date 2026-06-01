# AKS Ingress Demo - Sample Application

This is a simple .NET 10 minimal API web application used across all three AKS ingress demos.

## Features

- **Main Page** (`/`): Displays demo information and request inspector details with a beautiful UI
- **Health Check** (`/health`): Kubernetes health probe endpoint
- **API Info** (`/api/info`): JSON endpoint with demo metadata and request inspector data

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
