# AKS Ingress Comparison Demo 2026

A comprehensive comparison of four different ingress and service networking approaches for Azure Kubernetes Service (AKS), demonstrating the evolution from traditional Ingress-based solutions to modern, Azure-native architectures.

> **✅ Verified Configuration**: Demos 01-03 are tested and configured for **Sweden Central**. Demo 04 intentionally uses **North Europe** because Azure Kubernetes Application Network is a preview feature with regional availability. All demos use Kubernetes 1.35.4, Standard_B4as_v2 VMs, and the Free AKS tier where supported.

## Overview

This repository contains four independent demonstrations showcasing different ingress, gateway, and service networking solutions for AKS:

1. **[NGINX Ingress Controller](./01-nginx-ingress/)** - The traditional Ingress-based approach ([Mermaid](./01-nginx-ingress/architecture.mermaid.md), [Draw.io](./01-nginx-ingress/architecture.drawio))
2. **[Gateway API with Envoy](./02-envoy-gateway-api/)** - Modern, vendor-neutral Kubernetes standard ([Mermaid](./02-envoy-gateway-api/architecture.mermaid.md), [Draw.io](./02-envoy-gateway-api/architecture.drawio))
3. **[Application Gateway for Containers](./03-agc-for-containers/)** - Azure-native ingress solution ([Mermaid](./03-agc-for-containers/architecture.mermaid.md), [Draw.io](./03-agc-for-containers/architecture.drawio))
4. **[Managed Istio Ambient Mesh](./04-managed-istio-ambient/)** - Managed ambient mesh with Azure Kubernetes Application Network preview, Gateway API ingress, waypoint telemetry, Prometheus, and Kiali ([Mermaid](./04-managed-istio-ambient/architecture.mermaid.md), [Draw.io](./04-managed-istio-ambient/architecture.drawio))

Each demo deploys a .NET 10 sample application to its own AKS cluster. Demo 04 runs the same image as a three-service mesh chain (`frontend` → `orders` → `inventory`) to make east-west traffic visible.

## Demo Comparison

| Feature | NGINX Ingress | Gateway API (Envoy) | AGC | Managed Ambient Mesh |
|---------|---------------|---------------------|-----|----------------------|
| **Status** | ⚠️ Legacy / Traditional | ✅ Modern Standard | ✅ Azure-Native | 🧪 Preview Azure service networking |
| **Specification** | Ingress v1 | Gateway API v1 | Gateway API + Azure Extensions | Gateway API + ambient mesh concepts |
| **Provider** | Community | CNCF/Envoy | Microsoft Azure | Microsoft Azure Application Network |
| **Role-Based** | No | Yes | Yes | Yes |
| **Multi-tenancy** | Limited | Native | Native | Namespace/service waypoint model |
| **Azure Integration** | External | External | Deep Integration | Managed ambient data plane |
| **WAF Support** | Manual | Manual | Built-in Ready | Not the focus of this demo |
| **Use Case** | Legacy systems | Cross-cloud portability | Azure-first ingress | East-west service mesh visualization |

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

Demos 01-03 are configured and tested for **Sweden Central**. Demo 04 uses **North Europe** by explicit preview-feature decision:

| Setting | Value | Status |
|---------|-------|--------|
| **Azure Region** | `swedencentral` for Demos 01-03; `northeurope` for Demo 04 | ✅ Verified baseline / 🧪 preview exception |
| **Kubernetes Version** | `1.35.4` | ✅ Latest non-preview supported patch |
| **VM SKU** | `Standard_B4as_v2` | ✅ Available (B-series v2, ARM-based) |
| **VM Specs** | 4 vCPUs, 16 GiB RAM | Modern Ampere Altra processor |
| **AKS SKU Tier** | `Free` | Cost-optimized |
| **Node Count** | 2 per cluster | Suitable for demos |
| **AKS Maintenance Window** | Sunday 02:00-06:00 (fixed `+01:00`) | Nighttime auto-upgrade and node OS image updates |

**Resource Group Names**:
- Shared ACR/Grafana/Prometheus workspace: `rg-aksdemo-shared`
- Demo 01: `rg-01-nginx-ingress-demo`
- Demo 02: `rg-02-envoy-gateway-demo`
- Demo 03: `rg-03-agc-containers-demo`
- Demo 04: `rg-04-istio-ambient-demo`

## Quick Start

Each demo is self-contained in its own folder with complete infrastructure and deployment automation.
Run `./scripts/deploy.sh` for the full sequential path, or run `./scripts/deploy-infra.sh`,
`./scripts/build-image.sh`, and `./scripts/configure-kubernetes.sh` independently when you want
separate infrastructure, image build, and Kubernetes configuration phases. `deploy-infra.sh`
creates or reuses the shared ACR and shared observability resources in `rg-aksdemo-shared`, and `build-image.sh` builds the shared
sample image only if the source-content tag is missing. Only the Kubernetes configuration phase
changes or relies on the active `kubectl` context.

### 1. NGINX Ingress Demo
```bash
cd 01-nginx-ingress
./scripts/deploy.sh
```
[📖 Full Documentation](./01-nginx-ingress/README.md) | [📊 Mermaid Diagram](./01-nginx-ingress/architecture.mermaid.md) | [✏️ Draw.io Diagram](./01-nginx-ingress/architecture.drawio)

### 2. Gateway API with Envoy Demo
```bash
cd 02-envoy-gateway-api
./scripts/deploy.sh
```
[📖 Full Documentation](./02-envoy-gateway-api/README.md) | [📊 Mermaid Diagram](./02-envoy-gateway-api/architecture.mermaid.md) | [✏️ Draw.io Diagram](./02-envoy-gateway-api/architecture.drawio)

### 3. AGC Demo
```bash
cd 03-agc-for-containers
./scripts/deploy.sh
```
[📖 Full Documentation](./03-agc-for-containers/README.md) | [📊 Mermaid Diagram](./03-agc-for-containers/architecture.mermaid.md) | [✏️ Draw.io Diagram](./03-agc-for-containers/architecture.drawio)

### 4. Managed Istio Ambient Mesh Demo
```bash
cd 04-managed-istio-ambient
./scripts/deploy.sh
```
[📖 Full Documentation](./04-managed-istio-ambient/README.md) | [📊 Mermaid Diagram](./04-managed-istio-ambient/architecture.mermaid.md) | [✏️ Draw.io Diagram](./04-managed-istio-ambient/architecture.drawio)

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
├── 03-agc-for-containers/             # AGC demo
│   ├── README.md
│   ├── infrastructure/
│   ├── kubernetes/
│   └── scripts/
└── 04-managed-istio-ambient/          # Managed ambient mesh demo
    ├── README.md
    ├── infrastructure/
    ├── kubernetes/
    └── scripts/
```

## Shared Azure Container Registry and Observability

All four demos use one shared resource group, `rg-aksdemo-shared`, for resources that are intentionally reused across demo environments. This shared resource group is owned by the demo set rather than by any individual demo folder: each `deploy-infra.sh` run creates or reuses the shared resources, and each `cleanup.sh` deletes only its own demo resource group.

Shared resources:

- One Azure Container Registry with the same `aks-ingress-demo:<source-hash>` image tag. The deployment scripts derive a deterministic ACR name from the current subscription, or you can set `SHARED_ACR_NAME` before running the scripts to use an existing registry name.
- One Azure Monitor workspace for managed Prometheus metrics from all demo AKS clusters.
- One Azure Managed Grafana instance connected to that Azure Monitor workspace. The signed-in user that runs the deployment receives Grafana Admin on the shared instance, and Grafana's managed identity receives monitoring read permissions on the shared workspace.

- `deploy-infra.sh` creates/reuses `rg-aksdemo-shared`, creates/reuses the shared ACR, Azure Monitor workspace, and Grafana instance, deploys the demo AKS resources, enables Azure Monitor managed Prometheus for that AKS cluster, and grants that AKS kubelet identity `AcrPull` on the shared registry.
- `build-image.sh` can be run once from any demo folder; it builds the shared sample app image with ACR Tasks only when the computed source-content tag is absent.
- `configure-kubernetes.sh` deploys the same image reference for every demo while keeping demo-specific UI/content in Kubernetes environment variables.
- Demo cleanup scripts delete only the demo resource group and Kubernetes resources. Delete `rg-aksdemo-shared` manually only after all demos that depend on the shared image and shared Grafana have been removed.

### Access Grafana

After any demo infrastructure deployment completes, the script prints the shared Grafana name and endpoint. You can also look it up later:

```bash
az resource list \
  --resource-group rg-aksdemo-shared \
  --resource-type Microsoft.Dashboard/grafana \
  --query "[0].{name:name,endpoint:properties.endpoint}" \
  --output table
```

Open the endpoint in a browser and sign in with Microsoft Entra ID. Use the same account that ran `deploy-infra.sh`, or grant another user Grafana access on the shared Managed Grafana resource.

### Dashboard guidance

Use the shared Grafana data source backed by the Azure Monitor workspace to show metrics from all deployed demos. Useful views during demos:

- Cluster health: node readiness, `up`, API server health, and scrape status.
- Pod health: `kube_pod_status_phase`, restarts, ready replicas, and namespace filtering for `demo`.
- Resource usage: CPU and memory by cluster, namespace, pod, and container.
- Ingress/gateway traffic: NGINX ingress controller metrics for Demo 01, Envoy/Gateway API metrics for Demo 02, AGC/Application Gateway metrics in Azure Monitor for Demo 03, and mesh traffic from Demo 04 through in-cluster Prometheus/Kiali plus Azure Monitor cluster metrics.

Start with the built-in Azure Managed Prometheus Kubernetes dashboards, then filter by the `cluster` label to switch between Demo 01, Demo 02, Demo 03, and Demo 04.

## Sample Application

All demos use the same [.NET 10 minimal API application](./shared/sample-app/), which provides:

- **Main Page** (`/`) - Beautiful UI showing demo information and request inspector details
- **Health Checks** (`/health`, `/health/live`, `/health/ready`) - Compatibility, liveness, and readiness endpoints
- **API Info** (`/api/info`) - JSON metadata and request inspector endpoint with the current request ID
- **Downstream Call** (`/api/call`, `/api/orders`) - Optional environment-driven service-to-service call used by Demo 04
- **Request Tracing** - Accepts or generates `X-Request-Id`, returns it as a response header, forwards it downstream, and includes it in application logs

The application displays which demo and ingress type is running, making it easy to verify successful deployment.

Trace one request through the application logs:

```bash
REQUEST_ID="demo-$(date +%s)"
APP_HOST="<application-ip-or-hostname>"
APP_NAMESPACE="demo" # sample manifests in this repository deploy to the demo namespace
APP_LABEL="app=nginx-demo-app" # use app=envoy-demo-app or app=agc-demo-app for those demos

curl -i -H "X-Request-Id: ${REQUEST_ID}" "http://${APP_HOST}/api/info"
kubectl logs -n "${APP_NAMESPACE}" -l "${APP_LABEL}" --since=5m | grep "${REQUEST_ID}"
```

## Cost Considerations

⚠️ **Important**: Each demo creates billable Azure resources. Demos 01-03 use Sweden Central; Demo 04 uses North Europe preview resources. Actual Azure pricing is region-dependent and may vary with usage:

- **AKS cluster (Free tier)**: $0/month
- **2 x Standard_B4as_v2 nodes**: ~$70/month
- **Shared Azure Container Registry (Standard SKU)**: ~$20/month total when present
- **Shared Azure Managed Grafana**: billed while `rg-aksdemo-shared` remains
- **Load Balancer** (for NGINX and Envoy demos): ~$20/month
- **Application Gateway for Containers** (for AGC demo): ~$40/month
- **Azure Kubernetes Application Network preview** (for Demo 04): preview pricing and regional availability may change
- **Virtual Network resources**: Minimal cost
- **Log Analytics**: ~$5/month
- **Azure Monitor workspace / managed Prometheus ingestion**: usage-based

**Estimated monthly cost per demo**: 
- Demos 01-02 (NGINX/Envoy): ~$115/month
- Demo 03 (App Gateway): ~$155/month
- Demo 04 (Application Network preview + in-cluster Kiali/Prometheus): verify current preview pricing before workshops

💡 **To minimize costs**:
- Use `./scripts/cleanup.sh` to delete demo resources after testing
- Delete `rg-aksdemo-shared` only after all demos are cleaned up and nobody still needs the shared Grafana dashboards
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

### Choose Managed Ambient Mesh if:
- 🧪 You explicitly accept Azure Kubernetes Application Network preview dependencies
- ✅ You need east-west traffic visibility between in-cluster services
- ✅ You want to explain ambient mesh, ztunnel, and waypoint trade-offs
- ✅ You want Kiali traffic graphs for a live workshop

## Learning Path

**Recommended order** for learning:

1. Start with **NGINX Ingress** to understand the traditional approach
2. Move to **Gateway API** to see the modern Kubernetes standard
3. Continue with **AGC** to see Azure's optimized ingress solution
4. Finish with **Managed Ambient Mesh** to compare ingress with east-west service networking

## Contributing

This repository is designed for demonstration and educational purposes. See [CONTRIBUTING.md](./CONTRIBUTING.md) for contribution expectations and validation guidance.

Feel free to:

- Open issues for bugs or improvements
- Submit pull requests with enhancements
- Use this as a template for your own demos

**Important**: If you make changes to Demos 01-03, verify resources are available in Sweden Central. For Demo 04, verify North Europe Application Network preview availability:
```bash
# Check VM SKU availability
az vm list-skus --location swedencentral --size <SKU> --all

# Check Kubernetes versions
az aks get-versions --location swedencentral --output table

# Demo 04 preview checks
az appnet list-versions --location northeurope -o table
az aks get-versions --location northeurope --output table
```

For security-sensitive issues, see [SECURITY.md](./SECURITY.md) for reporting guidance and support scope. See [`.github/copilot-instructions.md`](./.github/copilot-instructions.md) for AI-assisted development guidance and coding standards.

## Resources

### Official Documentation
- [AKS Documentation](https://learn.microsoft.com/azure/aks/)
- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)
- [Application Gateway for Containers](https://learn.microsoft.com/azure/application-gateway/for-containers/)
- [Istio Ambient Mesh](https://istio.io/latest/docs/ambient/)
- [Kiali](https://kiali.io/)
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