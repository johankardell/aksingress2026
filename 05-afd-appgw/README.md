# Demo 05: Azure Front Door (WAF) + Application Gateway

[📊 Mermaid Diagram](./architecture.mermaid.md) | [✏️ Draw.io Diagram](./architecture.drawio)

## Overview

This demo layers two Azure edge/networking services in front of AKS:

1. **Azure Front Door (Premium)** is the public internet entry point. It terminates global HTTPS traffic, applies a **Web Application Firewall (WAF)** policy in Prevention mode with the managed OWASP default rule set plus the bot manager rule set, and forwards traffic to a regional origin.
2. **Azure Application Gateway v2** is the regional origin behind Front Door. It receives traffic forwarded by Front Door and load-balances it across AKS pods.
3. **AKS** hosts the same .NET 10 sample application used across this repository, exposed through a classic Kubernetes `Ingress` resource. The **Application Gateway Ingress Controller (AGIC)** AKS add-on reconciles the Application Gateway's listeners, routing rules, and backend pool directly from that `Ingress` resource — the "backend pool" is the AKS-hosted web app itself.

This is a common enterprise pattern: **global WAF + CDN-style edge at Front Door**, with a **regional Layer-7 load balancer (Application Gateway)** doing VNet-integrated routing to workloads. WAF protection is centralized at Front Door, so Application Gateway itself runs the non-WAF `Standard_v2` SKU.

```
Internet
   │
   ▼
Azure Front Door (Premium) ── WAF Policy (Prevention, managed rule sets)
   │  (HTTPS at the edge, HTTP to origin)
   ▼
Application Gateway v2 (Standard_v2, public IP, regional)
   │  (backend pool managed by AGIC)
   ▼
AKS Cluster
   └── Ingress (azure/application-gateway) → Service (ClusterIP) → Deployment (2 pods)
```

## Why Application Gateway Ingress Controller (AGIC)?

Unlike Demo 03 (which uses the Application Gateway for Containers ALB Controller and Gateway API), this demo uses the **classic Application Gateway v2** SKU with the **AGIC add-on**, which is Microsoft's supported integration for classic App Gateway + AKS:

- Enabled declaratively through the AKS `addonProfiles.ingressApplicationGateway` property, referencing an existing Application Gateway (`applicationGatewayId`) created by this demo's Bicep template.
- Watches standard `networking.k8s.io/v1` `Ingress` resources annotated with `kubernetes.io/ingress.class: azure/application-gateway` and configures the Application Gateway's listeners, rules, and backend pools to match.
- Requires the add-on's auto-created managed identity to have `Contributor` permissions on the resource group containing the Application Gateway, which `scripts/deploy-infra.sh` grants automatically.

## Prerequisites

See the [repository root README](../README.md#prerequisites) for common prerequisites (Azure CLI, kubectl, Bicep, Helm). This demo additionally requires:

- The `Microsoft.Cdn` resource provider registered in your subscription (handled automatically by `deploy-infra.sh`) for Azure Front Door.
- The Azure CLI `fleet` extension when using the optional Demo 06 Fleet membership.

## Deployment

Run the full sequence from this folder:

```bash
cd 05-afd-appgw
./scripts/deploy.sh
```

Or run each phase independently:

```bash
./scripts/deploy-infra.sh          # Creates/reuses shared ACR + observability, deploys VNet/AKS/App Gateway/Front Door/WAF
./scripts/build-image.sh           # Builds the shared sample app image in ACR if the content hash tag is missing
./scripts/configure-kubernetes.sh  # Deploys the app and Ingress; waits for AGIC to reconcile the Application Gateway
```

If the hubless `aks-ingress-demo-fleet` from Demo 06 already exists, `deploy-infra.sh` also joins this AKS cluster as a Fleet member. Membership is optional and does not change Front Door, Application Gateway, AGIC, or ingress traffic.

After `configure-kubernetes.sh` completes, it prints:

- The **Front Door endpoint URL** (`https://<endpoint>.z01.azurefd.net` or similar) — this is the recommended, WAF-protected entry point.
- The **Application Gateway's direct public IP** — useful for troubleshooting, but it bypasses Front Door and the WAF.

## Cleanup

```bash
./scripts/cleanup.sh
```

If Demo 06's Fleet exists, cleanup first removes this cluster's membership. It then deletes the Kubernetes resources and the `rg-05-afd-appgw-demo` resource group (Front Door profile, WAF policy, Application Gateway, AKS cluster, VNet, and Log Analytics workspace). The Fleet, other AKS clusters, shared ACR, Azure Monitor workspace, and Grafana instance are left untouched.

## Resource Group

- **Name**: `rg-05-afd-appgw-demo`
- **Region**: `swedencentral`
- **AKS**: Kubernetes `1.35.4`, `Standard_B4as_v2` nodes, `Free` AKS tier, Azure RBAC with local accounts disabled

## Key Azure Resources

| Resource | Purpose |
|----------|---------|
| `Microsoft.Cdn/profiles` (Premium_AzureFrontDoor) | Azure Front Door profile |
| `Microsoft.Cdn/profiles/afdEndpoints` | Public Front Door endpoint (`*.z01.azurefd.net`) |
| `Microsoft.Network/frontdoorWebApplicationFirewallPolicies` | WAF policy (Prevention mode, `Microsoft_DefaultRuleSet` 2.1 + `Microsoft_BotManagerRuleSet` 1.0) |
| `Microsoft.Cdn/profiles/originGroups` + `origins` | Origin group pointing at the Application Gateway's public FQDN, with a `/health` probe |
| `Microsoft.Cdn/profiles/securityPolicies` | Binds the WAF policy to the Front Door endpoint |
| `Microsoft.Network/applicationGateways` (Standard_v2) | Regional Application Gateway, backend pool managed by AGIC |
| `Microsoft.Network/publicIPAddresses` | Standard SKU static public IP + FQDN for the Application Gateway |
| `Microsoft.ContainerService/managedClusters` | AKS cluster with the `ingressApplicationGateway` add-on enabled |

## Testing the Deployment

```bash
FRONT_DOOR_HOST="<front-door-endpoint-hostname-from-script-output>"

curl -i "https://${FRONT_DOOR_HOST}/health"
curl -s "https://${FRONT_DOOR_HOST}/api/info" | jq
```

Trace one request through application logs (see the [repository root README](../README.md#sample-application) for the general pattern):

```bash
REQUEST_ID="demo-$(date +%s)"
curl -i -H "X-Request-Id: ${REQUEST_ID}" "https://${FRONT_DOOR_HOST}/api/info"
kubectl logs -n demo -l app=afd-appgw-demo-app --since=5m | grep "${REQUEST_ID}"
```

## Cost Considerations

⚠️ This demo is more expensive than Demos 01-03 because it adds Azure Front Door Premium (required for managed WAF rule sets) in addition to a regional Application Gateway:

- **AKS cluster (Free tier)**: $0/month
- **2 x Standard_B4as_v2 nodes**: ~$70/month
- **Application Gateway v2 (Standard_v2, autoscale 1-3 instances)**: ~$175-250/month depending on scale
- **Azure Front Door Premium**: ~$330/month base + usage (data transfer, requests, WAF rule evaluations)
- **Shared Azure Container Registry (Standard SKU)**: ~$20/month total when present
- **Log Analytics**: ~$5/month

**Estimated monthly cost**: ~$600-750/month while running. Run `./scripts/cleanup.sh` promptly after demos; Front Door Premium is the dominant cost driver. Costs are approximate, region-dependent, and should be verified with the [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/) before workshops.

## Choose This Pattern If:

- ✅ You need a global, CDN-backed edge with WAF and DDoS protection in front of regional workloads.
- ✅ You already use (or plan to use) Application Gateway for VNet-integrated Layer-7 routing to AKS or other backends.
- ✅ You want centralized WAF policy management at the edge, decoupled from regional Application Gateway scaling.
- ⚠️ You're comfortable with the added cost and operational surface of running two Layer-7 proxies (Front Door + Application Gateway) instead of one.

## Related Documentation

- [Azure Front Door overview](https://learn.microsoft.com/azure/frontdoor/front-door-overview)
- [Front Door WAF policy](https://learn.microsoft.com/azure/web-application-firewall/afds/afds-overview)
- [Application Gateway Ingress Controller (AGIC) add-on](https://learn.microsoft.com/azure/application-gateway/ingress-controller-overview)
- [Application Gateway v2 SKU](https://learn.microsoft.com/azure/application-gateway/application-gateway-autoscaling-zone-redundant)
