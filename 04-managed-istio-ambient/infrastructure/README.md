# Managed Istio Ambient Demo - Infrastructure

This folder contains Bicep infrastructure-as-code for Demo 04: a managed ambient-style service mesh on AKS using Azure Kubernetes Application Network preview.

## Resources Deployed

- AKS Standard cluster using Azure CNI Overlay, Cilium network dataplane/policy, public API server, Entra ID, Azure RBAC, OIDC issuer, and Workload Identity.
- Azure Kubernetes Application Network preview resource and AKS member link.
- Managed Kubernetes Gateway API enablement through `scripts/configure-kubernetes.sh` after Bicep creates the cluster.
- Log Analytics workspace plus Azure Monitor managed Prometheus data collection.
- Shared Azure Container Registry, Azure Monitor workspace, and Azure Managed Grafana reuse through `rg-aksdemo-shared`.
- Role assignments for the signed-in user and AKS kubelet ACR pull access.

## Important Preview Decision

Demo 04 intentionally uses Azure Kubernetes Application Network preview in `northeurope`. This is different from Demos 01-03, which use the repository's Sweden Central baseline, because the classic AKS Istio add-on path does not provide the requested managed ambient mode and Gateway API combination.

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `location` | `northeurope` | Region selected for Application Network preview availability. |
| `baseName` | `istio-ambient-demo` | Base name for AKS and related resources. |
| `kubernetesVersion` | `1.35.4` | AKS version, subject to preview regional availability. |
| `systemNodeSize` | `Standard_B4as_v2` | System node pool VM size. |
| `systemNodeCount` | `2` | Node count for the system pool. |
| `appNetName` | Generated | Azure Kubernetes Application Network name. |

## Validation

Before deploying, verify regional support:

```bash
az appnet list-versions --location northeurope -o table
az aks get-versions --location northeurope --output table
az vm list-skus --location northeurope --size Standard_B4as_v2 --all --output table
```

Validate the Bicep sources:

```bash
az bicep build --file 04-managed-istio-ambient/infrastructure/main.bicep
az bicep build-params --file 04-managed-istio-ambient/infrastructure/main.bicepparam
```

## Deployment

Use the demo scripts from the demo root:

```bash
cd 04-managed-istio-ambient
./scripts/deploy-infra.sh
./scripts/build-image.sh
./scripts/configure-kubernetes.sh
```

## Cleanup

```bash
cd 04-managed-istio-ambient
./scripts/cleanup.sh
```

The cleanup script deletes only `rg-04-istio-ambient-demo` and Kubernetes resources. Delete `rg-aksdemo-shared` manually only after all demos that reuse the shared ACR/Grafana resources are removed.
