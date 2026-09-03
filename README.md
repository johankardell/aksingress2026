# AKS Ingress Comparison Demo 2026

A collection of six AKS demonstrations: five ingress and service-networking approaches plus an intentionally minimal AKS Fleet Manager integration demo.

> **✅ Verified Configuration**: Demos 01-03, 05, and 06 are configured for **Sweden Central**. Demo 04 intentionally uses **North Europe** because Azure Kubernetes Application Network is a preview feature with regional availability. The five workload demos use Kubernetes 1.35.4, Standard_B4as_v2 VMs, and the Free AKS tier where supported; Demo 06 creates no AKS cluster.

## Overview

This repository contains six demonstrations. Demos 01-05 showcase ingress, gateway, and service networking solutions; Demo 06 adds optional fleet membership without changing those solutions:

1. **[NGINX Ingress Controller](./01-nginx-ingress/)** - The traditional Ingress-based approach ([Mermaid](./01-nginx-ingress/architecture.mermaid.md), [Draw.io](./01-nginx-ingress/architecture.drawio))
2. **[Gateway API with Envoy](./02-envoy-gateway-api/)** - Modern, vendor-neutral Kubernetes standard ([Mermaid](./02-envoy-gateway-api/architecture.mermaid.md), [Draw.io](./02-envoy-gateway-api/architecture.drawio))
3. **[Application Gateway for Containers](./03-agc-for-containers/)** - Azure-native ingress solution ([Mermaid](./03-agc-for-containers/architecture.mermaid.md), [Draw.io](./03-agc-for-containers/architecture.drawio))
4. **[Managed Istio Ambient Mesh](./04-managed-istio-ambient/)** - Managed ambient mesh with Azure Kubernetes Application Network preview, Gateway API ingress, waypoint telemetry, Prometheus, and Kiali ([Mermaid](./04-managed-istio-ambient/architecture.mermaid.md), [Draw.io](./04-managed-istio-ambient/architecture.drawio))
5. **[Azure Front Door (WAF) + Application Gateway](./05-afd-appgw/)** - Global edge WAF via Azure Front Door Premium, fronting a classic Application Gateway v2 that load-balances into AKS through the AGIC add-on ([Mermaid](./05-afd-appgw/architecture.mermaid.md), [Draw.io](./05-afd-appgw/architecture.drawio))
6. **[AKS Fleet Manager](./06-aks-fleet-manager/)** - A hubless Fleet that discovers and reconciles membership for already deployed demo AKS clusters without altering ingress behavior

Each of Demos 01-05 deploys a .NET 10 sample application to its own AKS cluster. Demo 04 runs the same image as a three-service mesh chain (`frontend` → `orders` → `inventory`) to make east-west traffic visible. Demo 06 deploys only the Fleet resource and memberships.

## Demo Comparison

| Feature | NGINX Ingress | Gateway API (Envoy) | AGC | Managed Ambient Mesh | Front Door + App Gateway | AKS Fleet Manager |
|---------|---------------|---------------------|-----|----------------------|---------------------------|-------------------|
| **Status** | ⚠️ Legacy / Traditional | ✅ Modern Standard | ✅ Azure-Native | 🧪 Preview Azure service networking | ✅ Azure-Native, Global Edge | ✅ Optional management layer |
| **Specification** | Ingress v1 | Gateway API v1 | Gateway API + Azure Extensions | Gateway API + ambient mesh concepts | Ingress v1 (AGIC) | AKS Fleet membership |
| **Provider** | Community | CNCF/Envoy | Microsoft Azure | Microsoft Azure Application Network | Microsoft Azure | Microsoft Azure |
| **Role-Based** | No | Yes | Yes | Yes | No | Not an ingress concern |
| **Multi-tenancy** | Limited | Native | Native | Namespace/service waypoint model | Limited | Not demonstrated |
| **Azure Integration** | External | External | Deep Integration | Managed ambient data plane | Deep Integration (2 layers) | Cross-cluster membership |
| **WAF Support** | Manual | Manual | Built-in Ready | Not the focus of this demo | Built-in (Front Door Premium) | Does not provide WAF |
| **Use Case** | Legacy systems | Cross-cloud portability | Azure-first ingress | East-west service mesh visualization | Global edge + regional VNet routing | Minimal fleet organization demo |

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

- **Azure CLI fleet extension** for Demo 06 and optional Fleet membership integration:
  Azure CLI 2.82.0 or later and fleet extension 1.8.3 or later are required.
  ```bash
  az extension add --name fleet --upgrade
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

Demos 01-03, 05, and 06 are configured for **Sweden Central**. Demo 04 uses **North Europe** by explicit preview-feature decision:

| Setting | Value | Status |
|---------|-------|--------|
| **Azure Region** | `swedencentral` for Demos 01-03, 05, and 06; `northeurope` for Demo 04 | ✅ Baseline / 🧪 preview exception |
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
- Demo 05: `rg-05-afd-appgw-demo`
- Demo 06: `rg-06-aks-fleet-demo`

## Quick Start

Each demo is self-contained in its own folder with infrastructure and deployment automation.
The phase-oriented application workflow below applies to Demos 01-05.
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

### 5. Azure Front Door + Application Gateway Demo
```bash
cd 05-afd-appgw
./scripts/deploy.sh
```
[📖 Full Documentation](./05-afd-appgw/README.md) | [📊 Mermaid Diagram](./05-afd-appgw/architecture.mermaid.md) | [✏️ Draw.io Diagram](./05-afd-appgw/architecture.drawio)

### 6. AKS Fleet Manager Demo
```bash
cd 06-aks-fleet-manager
./scripts/deploy.sh
```
[📖 Full Documentation](./06-aks-fleet-manager/README.md)

This creates the hubless Fleet `aks-ingress-demo-fleet` with a system-assigned managed identity, then discovers and reconciles any Demo 01-05 AKS clusters that are already deployed. It creates no hub cluster or application workload and does not change ingress traffic.

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
├── 04-managed-istio-ambient/          # Managed ambient mesh demo
│   ├── README.md
│   ├── infrastructure/
│   ├── kubernetes/
│   └── scripts/
├── 05-afd-appgw/                      # Front Door + Application Gateway demo
│   ├── README.md
│   ├── infrastructure/
│   ├── kubernetes/
│   └── scripts/
└── 06-aks-fleet-manager/              # Hubless AKS Fleet Manager demo
    ├── README.md
    ├── infrastructure/
    └── scripts/
```

## Shared Azure Container Registry and Observability

Demos 01-05 use one shared resource group, `rg-aksdemo-shared`, for resources that are intentionally reused across application demo environments. Demo 06 does not use these application resources. This shared resource group is owned by the demo set rather than by any individual demo folder: each application demo's `deploy-infra.sh` run creates or reuses the shared resources, and each `cleanup.sh` deletes only its own demo resource group.

Shared resources:

- One Azure Container Registry with the same `aks-ingress-demo:<source-hash>` image tag. The deployment scripts derive a deterministic ACR name from the current subscription, or you can set `SHARED_ACR_NAME` before running the scripts to use an existing registry name.
- One Azure Monitor workspace for managed Prometheus metrics from all demo AKS clusters.
- One Azure Managed Grafana instance connected to that Azure Monitor workspace. The signed-in user that runs the deployment receives Grafana Admin on the shared instance, and Grafana's managed identity receives monitoring read permissions on the shared workspace.

- `deploy-infra.sh` creates/reuses `rg-aksdemo-shared`, creates/reuses the shared ACR, Azure Monitor workspace, and Grafana instance, deploys the demo AKS resources, enables Azure Monitor managed Prometheus for that AKS cluster, and grants that AKS kubelet identity `AcrPull` on the shared registry.
- `build-image.sh` can be run once from any Demo 01-05 folder; it builds the shared sample app image with ACR Tasks only when the computed source-content tag is absent.
- `configure-kubernetes.sh` deploys the same image reference for Demos 01-05 while keeping demo-specific UI/content in Kubernetes environment variables.
- Demo cleanup scripts delete only the demo resource group and Kubernetes resources. Delete `rg-aksdemo-shared` manually only after all demos that depend on the shared image and shared Grafana have been removed.

### Access Grafana

After any Demo 01-05 infrastructure deployment completes, the script prints the shared Grafana name and endpoint. You can also look it up later:

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

## Optional AKS Fleet Membership

Demo 06 creates the hubless Fleet `aks-ingress-demo-fleet` in `rg-06-aks-fleet-demo` with a system-assigned managed identity. Its deployment discovers and reconciles any existing Demo 01-05 AKS clusters. If the Fleet already exists when a workload demo's `deploy-infra.sh` runs, that cluster is automatically joined.

Fleet membership is an additional management relationship only; it does not replace or reconfigure NGINX, Gateway API, AGC, Application Network, Front Door, Application Gateway, or AGIC. Each workload demo cleanup removes its membership before deleting its AKS cluster. Demo 06 cleanup deletes only `rg-06-aks-fleet-demo` and leaves every AKS cluster and workload resource group intact.

## Sample Application

Demos 01-05 use the same [.NET 10 minimal API application](./shared/sample-app/), which provides:

- **Main Page** (`/`) - Beautiful UI showing demo information, a backend banner, pod identity, and request inspector details
- **Health Checks** (`/health`, `/health/live`, `/health/ready`) - Compatibility, liveness, and readiness endpoints
- **API Info** (`/api/info`) - JSON metadata, backend identity, and request inspector endpoint with the current request ID
- **Downstream Call** (`/api/call`, `/api/orders`) - Optional environment-driven service-to-service call used by Demo 04
- **Request Tracing** - Accepts or generates `X-Request-Id`, returns it as a response header, forwards it downstream, and includes it in application logs

The application displays the configured backend banner, app version, and pod name in both the browser and `/api/info` output so blue/green, canary, weighted, and header-routing demos are obvious during refreshes and curl loops.

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

⚠️ **Important**: Each demo creates Azure resources. Demos 01-03, 05, and 06 use Sweden Central; Demo 04 uses North Europe preview resources. Actual Azure pricing is region-dependent and may vary with usage:

- **AKS cluster (Free tier)**: $0/month
- **2 x Standard_B4as_v2 nodes**: ~$70/month
- **Shared Azure Container Registry (Standard SKU)**: ~$20/month total when present
- **Shared Azure Managed Grafana**: billed while `rg-aksdemo-shared` remains
- **Load Balancer** (for NGINX and Envoy demos): ~$20/month
- **Application Gateway for Containers** (for AGC demo): ~$40/month
- **Azure Kubernetes Application Network preview** (for Demo 04): preview pricing and regional availability may change
- **Azure Front Door Premium** (for Demo 05): ~$330/month base, dominant cost driver
- **Application Gateway v2 (Standard_v2, autoscale)** (for Demo 05): ~$175-250/month
- **Hubless AKS Fleet Manager** (for Demo 06): no hub-cluster compute; verify current Fleet pricing before deployment
- **Virtual Network resources**: Minimal cost
- **Log Analytics**: ~$5/month
- **Azure Monitor workspace / managed Prometheus ingestion**: usage-based

**Estimated monthly cost per demo**: 
- Demos 01-02 (NGINX/Envoy): ~$115/month
- Demo 03 (App Gateway): ~$155/month
- Demo 04 (Application Network preview + in-cluster Kiali/Prometheus): verify current preview pricing before workshops
- Demo 05 (Front Door Premium + App Gateway v2): ~$600-750/month — the most expensive demo in this repo, driven by Front Door Premium's fixed base fee
- Demo 06 (hubless AKS Fleet Manager): no additional hub-cluster compute; no estimate is asserted here

💡 **To minimize costs**:
- Use `./scripts/cleanup.sh` to delete demo resources after testing
- Delete `rg-aksdemo-shared` only after all application demos are cleaned up and nobody still needs the shared Grafana dashboards
- Deploy only one demo at a time
- Demos 01-05 use cost-optimized AKS configurations (Free AKS tier, B-series VMs); Demo 06 creates no cluster

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

### Choose Azure Front Door + Application Gateway if:
- ✅ You need a global edge entry point with managed WAF (OWASP + bot protection) before traffic reaches Azure
- ✅ You want CDN/edge caching, custom domains, and TLS termination at a global point of presence
- ✅ You still want a familiar, classic Application Gateway/AGIC-based regional load balancer in front of AKS
- ✅ Cost is secondary to defense-in-depth, multi-region failover, or public-facing enterprise workloads

### Add the AKS Fleet Manager demo if:
- ✅ You want a minimal example of organizing the already deployed demo clusters as Fleet members
- ✅ You understand that this hubless Fleet adds no hub compute and does not alter ingress behavior
- ⚠️ You are evaluating the management relationship itself rather than expecting new traffic-management capabilities

## Learning Path

**Recommended order** for learning:

1. Start with **NGINX Ingress** to understand the traditional approach
2. Move to **Gateway API** to see the modern Kubernetes standard
3. Continue with **AGC** to see Azure's optimized ingress solution
4. Continue with **Managed Ambient Mesh** to compare ingress with east-west service networking
5. Continue with **Front Door + Application Gateway** to see a layered, global edge + regional architecture with defense-in-depth WAF
6. Finish with **AKS Fleet Manager** to see optional cross-cluster membership without changing any ingress implementation

## Contributing

This repository is designed for demonstration and educational purposes. See [CONTRIBUTING.md](./CONTRIBUTING.md) for contribution expectations and validation guidance.

Feel free to:

- Open issues for bugs or improvements
- Submit pull requests with enhancements
- Use this as a template for your own demos

**Important**: If you make changes to Demos 01-03, 05, or 06, verify resources are available in Sweden Central. For Demo 04, verify North Europe Application Network preview availability:
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
- [Azure Kubernetes Fleet Manager documentation](https://learn.microsoft.com/azure/kubernetes-fleet/)
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