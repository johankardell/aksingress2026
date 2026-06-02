# Managed Istio Ambient Mesh on AKS

Demo 04 shows a managed ambient-style service mesh on AKS with Gateway API ingress, east-west service-to-service traffic, and Kiali visualization for workshops.

> **Preview decision**: this demo intentionally uses **Azure Kubernetes Application Network Preview** in **North Europe**. The classic AKS Istio service mesh add-on is not used because the requested combination of managed ambient data plane and Gateway API is not available through that add-on path.

## What This Demo Deploys

- A separate AKS Standard cluster in `rg-04-istio-ambient-demo` with managed infrastructure resource group `rg-04-istio-ambient-demo-infra`.
- Azure CNI Overlay with Cilium network dataplane and policy.
- Entra ID integration, Azure RBAC, local AKS accounts disabled, OIDC issuer, Workload Identity, and managed identities.
- Azure Kubernetes Application Network preview resource with the AKS cluster as a member.
- Managed Kubernetes Gateway API for ingress.
- Three in-cluster services that generate a visible mesh graph:
  - `frontend` → `orders` → `inventory`
- Ambient namespace enrollment with `istio.io/dataplane-mode=ambient`.
- A namespace waypoint Gateway for L7 telemetry and policy visibility.
- In-cluster Prometheus and Kiali for traffic visualization.

## Architecture

```text
Browser/curl
    │
    ▼
Managed Gateway API Gateway + HTTPRoute
    │
    ▼
frontend ─────▶ orders ─────▶ inventory
    │             │              │
    └──────── ambient capture via ztunnel / waypoint ────────┘
                         │
                         ▼
                 Prometheus + Kiali
```

See [architecture.drawio](./architecture.drawio) and [architecture.mermaid.md](./architecture.mermaid.md).

## Prerequisites

- Azure CLI with the Application Network preview extension available (`az appnet`). The deployment script attempts to install/update it.
- Subscription approval for Azure Kubernetes Application Network preview.
- `kubectl`.
- `helm` for Prometheus and Kiali installation.
- Permissions to create resource groups, AKS clusters, role assignments, shared ACR resources, and Application Network resources.

## Validate Regional Support

Run these checks before a live workshop:

```bash
az appnet list-versions --location northeurope -o table
az aks get-versions --location northeurope --output table
az vm list-skus --location northeurope --size Standard_B4as_v2 --all --output table
```

## Deploy

```bash
cd 04-managed-istio-ambient
./scripts/deploy.sh
```

The orchestrator runs:

1. `./scripts/deploy-infra.sh` registers providers/preview features, verifies regional support, creates `rg-04-istio-ambient-demo`, deploys AKS + Application Network using Bicep, and grants AKS pull access to the shared ACR.
2. `./scripts/build-image.sh` builds or reuses the shared sample app image with ACR Tasks.
3. `./scripts/configure-kubernetes.sh` gets AKS credentials, checks Gateway API and Application Network membership, deploys the mesh application, applies Gateway/HTTPRoute/waypoint/telemetry resources, and installs Prometheus + Kiali.

You can also run the phases independently.

## Application Endpoints

The external Gateway address is printed at the end of `configure-kubernetes.sh`.

| Endpoint | Purpose |
|----------|---------|
| `/` | Frontend page; calls `orders` on every page load. |
| `/health`, `/health/live`, `/health/ready` | Health probes. |
| `/api/info` | JSON service metadata, pod name, request ID, request details, and selected forwarded headers. |
| `/api/call` | Calls the configured downstream service and returns a nested JSON result. |

The deployed chain is:

```text
frontend /api/call -> orders /api/call -> inventory /api/info
```

## Generate Visible Mesh Traffic

```bash
cd 04-managed-istio-ambient
./scripts/generate-traffic.sh
```

Optional controls:

```bash
REQUESTS=120 SLEEP_SECONDS=1 ./scripts/generate-traffic.sh
FRONTEND_HOST=<gateway-ip-or-host> ./scripts/generate-traffic.sh
```

## View Traffic in Kiali

Kiali is not exposed publicly by default. Use port-forwarding:

```bash
kubectl port-forward -n kiali-system svc/kiali 20001:20001
```

Open <http://localhost:20001>, then:

1. Select the `mesh-demo` namespace.
2. Open **Graph**.
3. Generate traffic with `./scripts/generate-traffic.sh`.
4. Enable graph options that show service nodes, traffic animation, waypoints, and ambient/ztunnel edges when available.

If Kiali cannot consume telemetry from the preview managed ambient data plane in your subscription, use the fallback validation commands below.

## Validate

```bash
./scripts/validate-demo.sh
```

Useful manual checks:

```bash
az appnet member show --resource-group rg-04-istio-ambient-demo --appnet-name <appnet-name> --member-name <aks-name>
kubectl get crd | grep -E 'gateway.networking.k8s.io|istio.io'
kubectl get daemonset -A | grep -E 'ztunnel|istio-cni|applink'
kubectl get gateway,httproute -A
kubectl get pods,svc -n mesh-demo
kubectl logs -n mesh-demo -l app=frontend --since=5m
```

## Cleanup

```bash
./scripts/cleanup.sh
```

The script deletes only the Demo 04 resource group and Kubernetes resources. Shared ACR/Grafana/Prometheus workspace resources in `rg-aksdemo-shared` remain for the other demos.

## Notes and Risks

- This demo uses preview Azure functionality and a region outside the repository's Sweden Central baseline by design.
- Do not enable the AKS Istio service mesh add-on for this path; Application Network supplies the managed ambient data plane.
- The GatewayClass name can vary while the preview evolves. Set `GATEWAY_CLASS_NAME=<name>` before running `configure-kubernetes.sh` if auto-detection chooses the wrong class.
- Kiali compatibility with the managed ambient preview should be validated before presenting live.
