# Copilot Instructions for AKS Ingress Demo Repository

This repository contains four independent AKS ingress/gateway/service networking demos:

| Demo | Path | Purpose |
| --- | --- | --- |
| 01 | `01-nginx-ingress/` | NGINX Ingress Controller as a traditional/legacy comparison pattern. |
| 02 | `02-envoy-gateway-api/` | Gateway API with Envoy Gateway, using role-oriented Gateway/HTTPRoute ownership. |
| 03 | `03-agc-for-containers/` | Azure Application Gateway for Containers (AGC), Azure-native Gateway API implementation. |
| 04 | `04-managed-istio-ambient/` | Managed Istio Ambient Mesh with Azure Kubernetes Application Network preview, Gateway API ingress, waypoint telemetry, Prometheus, and Kiali. |

All demos are self-contained with Bicep infrastructure, Kubernetes manifests, Bash deploy/cleanup scripts, and documentation. They share the .NET 10 sample app in `shared/sample-app/`; Demo 04 runs it as `frontend`, `orders`, and `inventory` with environment-driven downstream calls.

## Baseline Azure configuration

- Region: `swedencentral` for Demos 01-03; Demo 04 intentionally uses `northeurope` for Azure Kubernetes Application Network preview availability.
- AKS Kubernetes version: `1.35.4` unless explicitly changed after verifying non-preview availability.
- Node VM SKU: `Standard_B4as_v2` (AMD64/x64, 4 vCPU, 16 GiB).
- AKS SKU: `Base` / `Free`.
- Resource groups:
  - Demo 01: `rg-01-nginx-ingress-demo`
  - Demo 02: `rg-02-envoy-gateway-demo`
  - Demo 03: `rg-03-agc-containers-demo`
  - Demo 04: `rg-04-istio-ambient-demo`
- AKS managed resource groups use the demo resource group name plus `-infra`; Demo 04 uses `rg-04-istio-ambient-demo-infra`.

Before changing AKS versions, VM SKUs, or region, verify Sweden Central support for Demos 01-03 and North Europe preview support for Demo 04 with:

```bash
az aks get-versions --location swedencentral --output table
az vm list-skus --location swedencentral --size <SKU> --all --output table
az appnet list-versions --location northeurope --output table
```

## Infrastructure and identity

- Use Bicep only; do not introduce Terraform or hand-written ARM templates.
- Edit Bicep sources and `.bicepparam` files, not generated ARM JSON.
- Keep location, Kubernetes version, VM size, and node count parameterized and consistent across demos unless a demo-specific change is requested.
- Use managed identities and Azure RBAC; never add service principals with secrets.
- Keep ACR admin user disabled.
- Include `Environment`, `Demo`, and `ManagedBy` tags.
- AKS uses Azure RBAC with local AKS accounts disabled; do not use `--admin` credentials unless explicitly requested.
- Assign ACR Pull to the kubelet identity.

## Container build and sample app

- Do not require local Docker in scripts; use `az acr build` / ACR Tasks.
- Do not use `--platform linux/arm64` or `FROM --platform=...`; the selected nodes are AMD64/x64 and ACR Tasks scanning has failed on that syntax.
- Keep the sample app as a .NET 10 minimal API at `shared/sample-app/sample-app.csproj`.
- Keep the multi-stage Dockerfile based on `mcr.microsoft.com/dotnet/sdk:10.0` and `mcr.microsoft.com/dotnet/aspnet:10.0`.
- Preserve endpoints `/`, `/health`, `/api/info`, `/api/call`, and `/api/orders`; Kubernetes probes depend on `/health`.
- Keep demo-specific display text and downstream call targets configurable through Kubernetes environment variables.

## Kubernetes manifests

- Use stable Kubernetes APIs only.
- Include resource requests/limits plus liveness and readiness probes.
- Use `imagePullPolicy: Always` for demo deployments.
- Keep app resources in the `default` namespace unless a demo requires otherwise; Demo 04 uses `mesh-demo` with ambient labels.
- Demo 02, Demo 03, and Demo 04 use Gateway API `v1` resources.

## Scripts

- Use Bash, not PowerShell.
- Use `set -e`; add `set -o pipefail` when pipelines affect control flow.
- Follow the existing color-coded output style.
- Keep deploy and cleanup scripts aligned, idempotent, and safe to rerun.
- If `RoleAssignmentExists` occurs, clean only the known conflicting role assignments for that demo and retry once.
- Require only workflow tools actually used (`az`, `kubectl`, and `helm` where needed); do not add local Docker checks.

## Demo-specific rules

- Demo 01: describe Kubernetes Ingress as stable but feature-frozen, not deprecated; use the NGINX Ingress Controller Helm chart and include migration guidance toward Gateway API/AGC.
- Demo 02: use Gateway API v1 and the repo's existing Envoy Gateway deployment pattern; emphasize platform-owned Gateway/GatewayClass and app-owned HTTPRoute.
- Demo 03: install AGC ALB Controller with `oci://mcr.microsoft.com/application-lb/charts/alb-controller`; do not use AKS Web App Routing or `az aks approuting`; create `ApplicationLoadBalancer` before Gateway/HTTPRoute resources; highlight Azure integration, WAF readiness, and Azure Monitor.
- Demo 04: use Azure Kubernetes Application Network preview in `northeurope`; do not switch this demo to the classic AKS Istio add-on. Keep Azure CNI Overlay with Cilium dataplane/policy where supported, use `istio.io/dataplane-mode=ambient`, a waypoint `Gateway` for L7 telemetry, Gateway API ingress, Kubernetes service DNS for `frontend` → `orders` → `inventory`, and Prometheus/Kiali visualization.

## Documentation

- Keep README files professional, public-repo ready, and synchronized with scripts.
- Use Markdown tables for comparisons and cost estimates.
- Mark costs as approximate and region-dependent unless current Sweden Central pricing was verified.
- When changing infrastructure defaults, update root/demo/infrastructure READMEs, `.github/copilot-instructions.md`, and presentation sources that mention the value.

## Validation

- For infrastructure changes, run `az bicep build` on changed `*/infrastructure/main.bicep` files and `az bicep build-params` on changed `.bicepparam` files.
- For script changes, run `bash -n` on changed scripts.
- For sample app changes, run `dotnet publish shared/sample-app/sample-app.csproj -c Release`.
- After configuration changes, search for stale AKS version, region, VM SKU, and resource group values.

## Never do

- Do not commit secrets, kubeconfigs, tokens, credentials, or personal tenant identifiers.
- Do not use preview/beta Azure or Kubernetes features without explicit user approval; Demo 04 has explicit approval for Azure Kubernetes Application Network preview.
- Do not change Demos 01-03 away from Sweden Central without verification and documentation updates; Demo 04 must remain in a supported Application Network preview region unless docs/scripts are updated.
- Do not require local Docker for deployment.
- Do not remove cleanup scripts.
