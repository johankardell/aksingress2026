# GitHub Copilot Instructions for AKS Ingress Demo Repository

## Project Overview

This repository contains three independent AKS ingress/gateway demos:

1. **Demo 01**: NGINX Ingress Controller - traditional Kubernetes Ingress pattern for comparison and migration education.
2. **Demo 02**: Gateway API with Envoy - modern, vendor-neutral Gateway API implementation.
3. **Demo 03**: AGC - Azure-native Gateway API implementation.

Each demo is self-contained with its own Bicep infrastructure, Kubernetes manifests, Bash automation, cleanup script, and documentation. All demos share the sample application in `shared/sample-app/`.

## Verified Azure Configuration

- **Region**: `swedencentral` for all Azure resources.
- **AKS Kubernetes version**: `1.35.4`, latest non-preview supported patch verified in Sweden Central as of May 2026. Do not use preview AKS versions unless explicitly requested.
- **VM SKU**: `Standard_B4as_v2`, 4 vCPU / 16 GiB, AMD64/x64 burstable B-series v2.
- **AKS SKU**: Free tier:
  ```bicep
  sku: {
    name: 'Base'
    tier: 'Free'
  }
  ```
- **Resource groups**:
  - Demo 01: `rg-01-nginx-ingress-demo`
  - Demo 02: `rg-02-envoy-gateway-demo`
  - Demo 03: `rg-03-agc-containers-demo`
- **AKS-managed infrastructure resource group**: use the demo resource group name with `-infra` suffix, e.g. `rg-02-envoy-gateway-demo-infra`.

## Repository Structure

```text
aksingress2026/
├── .github/copilot-instructions.md
├── shared/sample-app/                  # Shared .NET sample app
│   ├── Program.cs
│   ├── sample-app.csproj
│   ├── Dockerfile
│   └── README.md
├── 01-nginx-ingress/
│   ├── infrastructure/
│   ├── kubernetes/
│   └── scripts/
├── 02-envoy-gateway-api/
│   ├── infrastructure/
│   ├── kubernetes/
│   └── scripts/
└── 03-agc-for-containers/
    ├── infrastructure/
    ├── kubernetes/
    └── scripts/
```

## Infrastructure Rules

- Use **Bicep** for Azure infrastructure. Do not introduce Terraform or hand-written ARM templates.
- Keep configuration consistent across all three demos unless the user asks for a demo-specific change.
- Parameterize location, Kubernetes version, VM size, and node count.
- Keep `.bicepparam` files updated with shared defaults.
- Generated ARM JSON files in demo `infrastructure/` folders are ignored by `.gitignore`; edit Bicep sources, not generated JSON.
- Use managed identities and role assignments; never use service principals with secrets.
- Keep Azure Container Registry admin user disabled.
- Include `Environment`, `Demo`, and `ManagedBy` tags on Azure resources.
- Before changing Azure versions or SKUs, verify Sweden Central availability:
  ```bash
  az aks get-versions --location swedencentral --output table
  az vm list-skus --location swedencentral --size <SKU> --all --output table
  ```

## AKS and RBAC Notes

- AKS clusters use Azure RBAC role assignments and ACR Pull for the kubelet identity.
- Scripts are intended to be idempotent. If `RoleAssignmentExists` occurs, deploy scripts should clean only the known conflicting role assignments for that demo and retry once.
- Demo scripts use Entra ID / Azure RBAC credentials with local AKS accounts disabled. Do not add `--admin` credentials unless explicitly requested.
- Demo 03 uses AGC with the ALB Controller installed by Helm. Do not use AKS Web App Routing or `az aks approuting` for Demo 03.
- Demo 03 must create the `ApplicationLoadBalancer` resource before applying Gateway resources.

## Container Build Workflow

- Local Docker is **not required** on the VM running the scripts.
- Use `az acr build` / ACR Tasks to build the shared sample app image remotely.
- Do **not** pass `--platform linux/arm64` and do not use `FROM --platform=...` in the Dockerfile. ACR Tasks dependency scanning has failed on that syntax in this repo, and the selected node SKU is AMD64/x64.
- Keep the Dockerfile multi-stage:
  - build stage: `mcr.microsoft.com/dotnet/sdk:10.0`
  - runtime stage: `mcr.microsoft.com/dotnet/aspnet:10.0`
- Keep health endpoint `/health`; Kubernetes manifests use readiness and liveness probes.

## Sample Application

- Current tech stack: **.NET 10 minimal API**.
- Project path: `shared/sample-app/sample-app.csproj`.
- The app exposes:
  - `/`
  - `/health`
  - `/api/info`
- Keep demo-specific display text configurable with environment variables in the Kubernetes manifests.

## Kubernetes Manifest Rules

- Use stable Kubernetes APIs only.
- Include resource requests and limits.
- Include liveness and readiness probes for the app.
- Use `imagePullPolicy: Always` for demo deployments.
- Application resources live in the `default` namespace unless a demo explicitly requires otherwise.
- Demo 02 and Demo 03 use Gateway API `v1` resources (`Gateway`, `HTTPRoute`).

## Automation Script Rules

- Scripts must be Bash, not PowerShell.
- Use `set -e`; add `set -o pipefail` where pipelines affect control flow.
- Use color-coded output already established in the repo.
- Scripts should be safe to rerun and should not fail on already-existing expected resources.
- Always provide cleanup scripts and keep them aligned with deploy scripts.
- Avoid local Docker checks; require only tools the workflow actually needs (`az`, `kubectl`, and `helm` where used).

## Demo-Specific Guidance

### Demo 01: NGINX Ingress

- Describe as **traditional** or **legacy comparison**, not as a deprecated Kubernetes API.
- Kubernetes Ingress is stable but feature-frozen; Gateway API is preferred for new advanced ingress designs.
- Use the NGINX Ingress Controller Helm chart.
- Include migration guidance toward Gateway API / AGC.

### Demo 02: Gateway API with Envoy

- Use Gateway API v1 resources.
- Install Envoy Gateway using the repo's existing deployment pattern.
- Emphasize role-oriented design: platform owns Gateway/GatewayClass, apps own HTTPRoute.

### Demo 03: Application Gateway for Containers

- Use the Application Gateway for Containers ALB Controller Helm chart (`oci://mcr.microsoft.com/application-lb/charts/alb-controller`).
- Do not use AKS Web App Routing for this demo.
- Ensure `ApplicationLoadBalancer` is created before Gateway and HTTPRoute resources.
- Highlight Azure-native integration, WAF-readiness, and Azure Monitor integration.

## Documentation Rules

- Keep README files professional and public-repo ready.
- Use Markdown tables for comparisons and cost estimates.
- Keep manual and automated deployment instructions in sync with scripts.
- Cost estimates should say they are approximate and region-dependent unless current Sweden Central pricing has been verified.
- When changing infrastructure defaults, update:
  - root `README.md`
  - demo README files if relevant
  - `infrastructure/README.md` files
  - `.github/copilot-instructions.md`
  - presentation sources if they mention the changed value

## Validation Checklist

Before finishing changes:

- Run Bicep build for changed templates:
  ```bash
  az bicep build --file 01-nginx-ingress/infrastructure/main.bicep
  az bicep build --file 02-envoy-gateway-api/infrastructure/main.bicep
  az bicep build --file 03-agc-for-containers/infrastructure/main.bicep
  ```
- Run shell syntax checks for changed scripts:
  ```bash
  bash -n 01-nginx-ingress/scripts/deploy.sh 02-envoy-gateway-api/scripts/deploy.sh 03-agc-for-containers/scripts/deploy.sh
  ```
- For sample app changes, run:
  ```bash
  dotnet publish shared/sample-app/sample-app.csproj -c Release
  ```
- Search for stale values after configuration changes, especially AKS version, region, VM SKU, and resource group names.

## Do Not Do

- Do not commit secrets, kubeconfigs, tokens, credentials, or personal tenant identifiers.
- Do not require local Docker for deployment scripts.
- Do not use preview/beta Azure or Kubernetes features without explicit user approval.
- Do not change the Azure region away from Sweden Central without verifying availability and updating docs.
- Do not hand-edit generated ARM JSON as the source of truth.
- Do not remove cleanup scripts.
