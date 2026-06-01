# Copilot Instructions for AKS Ingress Demo Repository

This repository contains three independent AKS ingress demos:

| Demo | Path | Purpose |
| --- | --- | --- |
| 01 | `01-nginx-ingress/` | NGINX Ingress Controller as a traditional/legacy comparison pattern. |
| 02 | `02-envoy-gateway-api/` | Gateway API with Envoy Gateway, using role-oriented Gateway/HTTPRoute ownership. |
| 03 | `03-agc-for-containers/` | Azure Application Gateway for Containers (AGC), Azure-native Gateway API implementation. |

All demos are self-contained with Bicep infrastructure, Kubernetes manifests, Bash deploy/cleanup scripts, and documentation. They share the .NET 10 sample app in `shared/sample-app/`.

## Baseline Azure configuration

- Region: `swedencentral`.
- AKS Kubernetes version: `1.35.4` unless explicitly changed after verifying non-preview availability.
- Node VM SKU: `Standard_B4as_v2` (AMD64/x64, 4 vCPU, 16 GiB).
- AKS SKU: `Base` / `Free`.
- Resource groups:
  - Demo 01: `rg-01-nginx-ingress-demo`
  - Demo 02: `rg-02-envoy-gateway-demo`
  - Demo 03: `rg-03-agc-containers-demo`
- AKS managed resource groups use the demo resource group name plus `-infra`.

Before changing AKS versions, VM SKUs, or region, verify Sweden Central support with:

```bash
az aks get-versions --location swedencentral --output table
az vm list-skus --location swedencentral --size <SKU> --all --output table
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
- Preserve endpoints `/`, `/health`, and `/api/info`; Kubernetes probes depend on `/health`.
- Keep demo-specific display text configurable through Kubernetes environment variables.

## Kubernetes manifests

- Use stable Kubernetes APIs only.
- Include resource requests/limits plus liveness and readiness probes.
- Use `imagePullPolicy: Always` for demo deployments.
- Keep app resources in the `default` namespace unless a demo requires otherwise.
- Demo 02 and Demo 03 use Gateway API `v1` resources.

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
- Do not use preview/beta Azure or Kubernetes features without explicit approval.
- Do not change away from Sweden Central without verification and documentation updates.
- Do not require local Docker for deployment.
- Do not remove cleanup scripts.
