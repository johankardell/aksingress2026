# AKS Ingress Demo - Sample Application

This is a simple .NET 8 minimal API web application used across all three AKS ingress demos.

## Features

- **Main Page** (`/`): Displays demo information with a beautiful UI
- **Health Check** (`/health`): Kubernetes health probe endpoint
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

## Building with Docker

```bash
docker build -t aks-ingress-demo:latest .
docker run -p 8080:8080 -e DEMO_NAME="Local Test" -e DEMO_TYPE="Local Docker" aks-ingress-demo:latest
```

## Technology Stack

- .NET 8 minimal API
- No external dependencies
- Optimized for containerized deployments
