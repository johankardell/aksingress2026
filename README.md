# AKS Ingress Comparison Demo 2026

A comprehensive comparison of three different ingress approaches for Azure Kubernetes Service (AKS), demonstrating the evolution from traditional Ingress-based solutions to modern, Azure-native architectures.

> **✅ Verified Configuration**: All demos are tested and configured for **Sweden Central** region with verified Azure resources (Kubernetes 1.35.4, Standard_B4as_v2 VMs, Free AKS tier).

## Overview

This repository contains three independent demonstrations showcasing different ingress/gateway solutions for AKS:

1. **[NGINX Ingress Controller](./01-nginx-ingress/)** - The traditional Ingress-based approach
2. **[Gateway API with Envoy](./02-envoy-gateway-api/)** - Modern, vendor-neutral Kubernetes standard
3. **[Application Gateway for Containers](./03-agc-for-containers/)** - Azure-native ingress solution

Each demo deploys a simple .NET 10 web application to its own AKS cluster, accessible via a public IP address.

## Demo Comparison

| Feature | NGINX Ingress | Gateway API (Envoy) | AGC |
|---------|---------------|---------------------|---------------------------|
| **Status** | ⚠️ Legacy / Traditional | ✅ Modern Standard | ✅ Azure-Native |
| **Specification** | Ingress v1 | Gateway API v1 | Gateway API + Azure Extensions |
| **Provider** | Community | CNCF/Envoy | Microsoft Azure |
| **Role-Based** | No | Yes | Yes |
| **Multi-tenancy** | Limited | Native | Native |
| **Azure Integration** | External | External | Deep Integration |
| **WAF Support** | Manual | Manual | Built-in Ready |
| **Use Case** | Legacy systems | Cross-cloud portability | Azure-first deployments |

## Prerequisites

Before running any demo, ensure you have:

- **Azure Subscription** with permissions to:
  - Create resource groups
  - Create AKS clusters
  - Create or reuse the shared Azure Container Registry
  - Assign role-based access control (RBAC)

  AKS access is configured through Microsoft Entra ID and Azure RBAC. The
  demos disable local AKS accounts and do not use admin kubeconfigs.

- **Azure CLI** (`az`) version 2.50.0 or later
  ```bash
  az --version
  az login
  az account set --subscription <your-subscription-id>
  ```

- **kubectl** version 1.27 or later
  ```bash
  kubectl version --client
  ```

- **Bicep CLI** (installed via Azure CLI)
  ```bash
  az bicep version
  ```

- Local Docker is **not** required. Deployment scripts tag the sample app with a source-content hash and build the single shared image remotely with Azure Container Registry Tasks (`az acr build`) only when that tag is missing from the shared registry.

- **Helm** version 3.12 or later
  ```bash
  helm version
  ```

## Verified Azure Configuration

All demos are configured and tested for **Sweden Central** region:

| Setting | Value | Status |
|---------|-------|--------|
| **Azure Region** | `swedencentral` | ✅ Verified |
| **Kubernetes Version** | `1.35.4` | ✅ Latest non-preview supported patch |
| **VM SKU** | `Standard_B4as_v2` | ✅ Available (B-series v2, ARM-based) |
| **VM Specs** | 4 vCPUs, 16 GiB RAM | Modern Ampere Altra processor |
| **AKS SKU Tier** | `Free` | Cost-optimized |
| **Node Count** | 2 per cluster | Suitable for demos |
| **AKS Maintenance Window** | Sunday 02:00-06:00 (fixed `+01:00`) | Nighttime auto-upgrade and node OS image updates |

**Resource Group Names**:
- Shared ACR: `rg-aksdemo-shared`
- Demo 01: `rg-01-nginx-ingress-demo`
- Demo 02: `rg-02-envoy-gateway-demo`
- Demo 03: `rg-03-agc-containers-demo`

## Quick Start

Each demo is self-contained in its own folder with complete infrastructure and deployment automation.
Run `./scripts/deploy.sh` for the full sequential path, or run `./scripts/deploy-infra.sh`,
`./scripts/build-image.sh`, and `./scripts/configure-kubernetes.sh` independently when you want
separate infrastructure, image build, and Kubernetes configuration phases. `deploy-infra.sh`
creates or reuses the shared ACR in `rg-aksdemo-shared`, and `build-image.sh` builds the shared
sample image only if the source-content tag is missing. Only the Kubernetes configuration phase
changes or relies on the active `kubectl` context.

### 1. NGINX Ingress Demo
```bash
cd 01-nginx-ingress
./scripts/deploy.sh
```
[📖 Full Documentation](./01-nginx-ingress/README.md)

### 2. Gateway API with Envoy Demo
```bash
cd 02-envoy-gateway-api
./scripts/deploy.sh
```
[📖 Full Documentation](./02-envoy-gateway-api/README.md)

### 3. AGC Demo
```bash
cd 03-agc-for-containers
./scripts/deploy.sh
```
[📖 Full Documentation](./03-agc-for-containers/README.md)

## Repository Structure

```
aksingress2026/
├── README.md                          # This file
├── CONTRIBUTING.md                    # Contribution guidelines
├── SECURITY.md                        # Security reporting guidance
├── LICENSE                            # MIT License
├── shared/
│   └── sample-app/                    # .NET 10 web application
│       ├── Program.cs
│       ├── sample-app.csproj
│       ├── Dockerfile
│       └── README.md
├── 01-nginx-ingress/                  # NGINX Ingress demo
│   ├── README.md
│   ├── infrastructure/                # Bicep templates
│   ├── kubernetes/                    # K8s manifests
│   └── scripts/                       # Deployment automation
├── 02-envoy-gateway-api/              # Gateway API demo
│   ├── README.md
│   ├── infrastructure/
│   ├── kubernetes/
│   └── scripts/
└── 03-agc-for-containers/           # AGC demo
    ├── README.md
    ├── infrastructure/
    ├── kubernetes/
    └── scripts/
```

## Shared Azure Container Registry

All three demos use one Azure Container Registry in `rg-aksdemo-shared` and the same `aks-ingress-demo:<source-hash>` image tag. The deployment scripts derive a deterministic ACR name from the current subscription, or you can set `SHARED_ACR_NAME` before running the scripts to use an existing registry name.

- `deploy-infra.sh` creates/reuses `rg-aksdemo-shared`, creates/reuses the shared ACR, deploys the demo AKS resources, and grants that AKS kubelet identity `AcrPull` on the shared registry.
- `build-image.sh` can be run once from any demo folder; it builds the shared sample app image with ACR Tasks only when the computed source-content tag is absent.
- `configure-kubernetes.sh` deploys the same image reference for every demo while keeping demo-specific UI/content in Kubernetes environment variables.
- Demo cleanup scripts delete only the demo resource group and Kubernetes resources. Delete `rg-aksdemo-shared` manually only after all demos that depend on the shared image have been removed.

## Sample Application

All demos use the same [.NET 10 minimal API application](./shared/sample-app/), which provides:

- **Main Page** (`/`) - Beautiful UI showing demo information
- **Health Check** (`/health`) - Kubernetes liveness/readiness probe
- **API Info** (`/api/info`) - JSON metadata endpoint

The application displays which demo and ingress type is running, making it easy to verify successful deployment.

## Cost Considerations

⚠️ **Important**: Each Sweden Central demo creates billable Azure resources. Actual Azure pricing is region-dependent and may vary with usage:

- **AKS cluster (Free tier)**: $0/month
- **2 x Standard_B4as_v2 nodes**: ~$70/month
- **Shared Azure Container Registry (Standard SKU)**: ~$20/month total when present
- **Load Balancer** (for NGINX and Envoy demos): ~$20/month
- **Application Gateway for Containers** (for AGC demo): ~$40/month
- **Virtual Network resources**: Minimal cost
- **Log Analytics**: ~$5/month

**Estimated monthly cost per demo**: 
- Demos 01-02 (NGINX/Envoy): ~$115/month
- Demo 03 (App Gateway): ~$155/month

💡 **To minimize costs**:
- Use `./scripts/cleanup.sh` to delete demo resources after testing
- Delete `rg-aksdemo-shared` only after all demos are cleaned up
- Deploy only one demo at a time
- All demos use cost-optimized configurations (Free AKS tier, B-series VMs)

## Choosing the Right Ingress Solution

### Choose NGINX Ingress if:
- ⚠️ You're maintaining existing Ingress-based workloads
- You need broad ecosystem compatibility with the classic Kubernetes Ingress API
- You want to understand the traditional architecture before evaluating Gateway API

### Choose Gateway API (Envoy) if:
- ✅ You want a vendor-neutral, Kubernetes-native solution
- ✅ You need portability across cloud providers
- ✅ You want role-oriented resource management
- ✅ You're building multi-tenant applications

### Choose Application Gateway for Containers if:
- ✅ You're all-in on Azure
- ✅ You need enterprise features (WAF, Azure Monitor integration)
- ✅ You want simplified Azure networking integration
- ✅ You require centralized application delivery

## Learning Path

**Recommended order** for learning:

1. Start with **NGINX Ingress** to understand the traditional approach
2. Move to **Gateway API** to see the modern Kubernetes standard
3. Finish with **AGC** to see Azure's optimized solution

## Contributing

This repository is designed for demonstration and educational purposes. See [CONTRIBUTING.md](./CONTRIBUTING.md) for contribution expectations and validation guidance.

Feel free to:

- Open issues for bugs or improvements
- Submit pull requests with enhancements
- Use this as a template for your own demos

**Important**: If you make changes, verify resources are available in Sweden Central:
```bash
# Check VM SKU availability
az vm list-skus --location swedencentral --size <SKU> --all

# Check Kubernetes versions
az aks get-versions --location swedencentral --output table
```

For security-sensitive issues, see [SECURITY.md](./SECURITY.md) for reporting guidance and support scope. See [`.github/copilot-instructions.md`](./.github/copilot-instructions.md) for AI-assisted development guidance and coding standards.

## Resources

### Official Documentation
- [AKS Documentation](https://learn.microsoft.com/azure/aks/)
- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)
- [Application Gateway for Containers](https://learn.microsoft.com/azure/application-gateway/for-containers/)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)

### Microsoft Learn Paths
- [AKS Core Concepts](https://learn.microsoft.com/azure/aks/concepts-clusters-workloads)
- [Gateway API on AKS](https://learn.microsoft.com/azure/aks/app-routing)
- [Application Gateway for Containers Overview](https://learn.microsoft.com/azure/application-gateway/for-containers/overview)

## License

MIT License - see [LICENSE](./LICENSE).

## Support

This is a demo repository for educational purposes. For production support:
- AKS Issues: [Azure Support](https://azure.microsoft.com/support/)
- Kubernetes Questions: [Kubernetes Community](https://kubernetes.io/community/)
- Gateway API: [CNCF Slack #gateway-api](https://kubernetes.slack.com/)

---

**Last Updated**: 2026
**Maintained by**: AKS Community Demos