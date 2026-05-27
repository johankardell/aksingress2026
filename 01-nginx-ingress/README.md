# NGINX Ingress Controller Demo

⚠️ **Important**: This demo showcases the traditional NGINX Ingress Controller approach. Kubernetes Ingress is stable and widely used, but Gateway API and Azure AGC provide a more expressive, role-oriented model for new designs.

## Overview

This demo deploys a simple .NET 10 web application to Azure Kubernetes Service (AKS) using the community **NGINX Ingress Controller**. This is the classic Ingress-based model: reliable and familiar, but limited compared with Gateway API for platform-oriented scenarios.

Key tradeoffs compared with Gateway API:

- Controller-specific annotations reduce portability
- Limited role-oriented resource model
- Multi-tenancy requires convention and RBAC discipline rather than first-class API separation
- Advanced traffic management is less standardized across implementations

**This demo is useful for**:
- Understanding legacy architectures
- Planning migrations to modern alternatives
- Learning the evolution of Kubernetes ingress

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Azure Cloud                             │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              AKS Cluster                             │  │
│  │                                                       │  │
│  │  ┌────────────────────────────────────────────────┐  │  │
│  │  │  NGINX Ingress Controller (Namespace)          │  │  │
│  │  │  - Deployment: nginx-ingress-controller        │  │  │
│  │  │  - Service: LoadBalancer (public IP)           │  │  │
│  │  └────────────────────────────────────────────────┘  │  │
│  │                          │                            │  │
│  │                          ▼                            │  │
│  │  ┌────────────────────────────────────────────────┐  │  │
│  │  │  Default Namespace                             │  │  │
│  │  │                                                 │  │  │
│  │  │  Ingress: nginx-demo-ingress                   │  │  │
│  │  │      │                                          │  │  │
│  │  │      ├──> Service: nginx-demo-service (ClusterIP)│ │
│  │  │              │                                  │  │  │
│  │  │              └──> Deployment: nginx-demo-app   │  │  │
│  │  │                      (2 replicas)               │  │  │
│  │  └────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────┘  │
│                          ▲                                  │
└──────────────────────────┼──────────────────────────────────┘
                           │
                    Internet Traffic
                    (via Public IP)
```

## What is NGINX Ingress Controller?

The NGINX Ingress Controller is controller software that:
- Runs as a deployment in the `ingress-nginx` namespace
- Exposes a LoadBalancer service with a public IP address
- Watches for Ingress resources in all namespaces
- Configures NGINX based on Ingress rules
- Routes HTTP/HTTPS traffic to backend services

### Key Components

1. **Ingress Controller Deployment**: Runs NGINX pods
2. **LoadBalancer Service**: Provides external access via Azure Load Balancer
3. **Ingress Resources**: Define routing rules (path → service mapping)
4. **ConfigMaps**: Configure NGINX behavior
5. **ClusterIP Services**: Internal services for applications

## Why Prefer Gateway API for New Designs?

The Kubernetes Ingress API is stable, but it is intentionally limited. Gateway API is the newer Kubernetes networking API for richer routing, clearer ownership boundaries, and portable extension points.

| Concern | NGINX Ingress | Modern Gateway API |
|-------|---------------|-------------------|
| **Portability** | Controller-specific annotations | Vendor-neutral typed resources |
| **Role Separation** | Single resource | Gateway + Route separation |
| **Multi-tenancy** | Convention-based | Native support |
| **Expressiveness** | Basic routing | Advanced routing capabilities |
| **Type Safety** | Annotation-heavy | Strongly-typed fields |
| **Extensibility** | Fragmented | Standardized |

## Prerequisites

- Azure CLI (`az`) version 2.50.0+
- kubectl version 1.27+
- Helm version 3.12+
- No local Docker installation required; the shared image is built remotely with Azure Container Registry Tasks
- Active Azure subscription with permissions to create resources

## Deployment

### Option 1: Automated Deployment (Recommended)

```bash
# Run the deployment script
./scripts/deploy.sh
```

The script runs the three focused deployment phases in sequence:
1. `./scripts/deploy-infra.sh` creates/registers Azure resources and deploys AKS via Bicep, creates/reuses the shared ACR in `rg-aksdemo-shared`, and grants AKS pull access. This phase does not use `kubectl` and can be run in parallel with other demos.
2. `./scripts/build-image.sh` builds the shared sample app image with Azure Container Registry Tasks only if the source-content tag is missing.
3. `./scripts/configure-kubernetes.sh` gets AKS credentials, installs NGINX Ingress Controller via Helm, deploys the application, and displays the public URL. This is the only phase that changes or relies on the active `kubectl` context.

You can also run the phases independently:

```bash
./scripts/deploy-infra.sh
./scripts/build-image.sh
./scripts/configure-kubernetes.sh
```

**Estimated time**: 8-12 minutes

The shared ACR lives in `rg-aksdemo-shared`. Set `SHARED_ACR_NAME` to reuse a specific registry name; otherwise the scripts derive one from the subscription. The shared ACR is intentionally not deleted by a single demo cleanup script.

### Option 2: Manual Deployment

#### Step 1: Deploy Infrastructure

```bash
# Create resource group
az group create \
  --name rg-01-nginx-ingress-demo \
  --location swedencentral

# Deploy Bicep template and reference the shared ACR
cd infrastructure
source ../../shared/scripts/acr-image.sh
ACR_NAME=$(ensure_shared_acr)
USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)
az deployment group create \
  --resource-group rg-01-nginx-ingress-demo \
  --name nginx-demo-deployment \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --parameters userObjectId="$USER_OBJECT_ID" \
  --parameters sharedAcrName="$ACR_NAME" \
  --parameters sharedAcrResourceGroupName="$SHARED_ACR_RESOURCE_GROUP"
```

#### Step 2: Get Credentials

```bash
# Get AKS cluster name
AKS_NAME=$(az deployment group show \
  --resource-group rg-01-nginx-ingress-demo \
  --name nginx-demo-deployment \
  --query properties.outputs.aksClusterName.value \
  --output tsv)

# Get credentials
az aks get-credentials \
  --resource-group rg-01-nginx-ingress-demo \
  --name $AKS_NAME \
  --overwrite-existing
```

#### Step 3: Build Shared Image with ACR Tasks

```bash
# Get shared ACR name
ACR_NAME=$(az deployment group show \
  --resource-group rg-01-nginx-ingress-demo \
  --name nginx-demo-deployment \
  --query properties.outputs.acrName.value \
  --output tsv)

# Build remotely only if the source-content tag is missing
source ../../shared/scripts/acr-image.sh
ensure_sample_app_image "$ACR_NAME" "../../shared/sample-app" "aks-ingress-demo"
```

#### Step 4: Install NGINX Ingress Controller

```bash
# Add Helm repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install controller
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --create-namespace \
  --namespace ingress-nginx \
  --set controller.service.externalTrafficPolicy=Local \
  --wait
```

#### Step 5: Deploy Application

```bash
cd ../kubernetes

# Get ACR login server
ACR_LOGIN_SERVER=$(az acr show --resource-group rg-aksdemo-shared --name $ACR_NAME --query loginServer --output tsv)

# Deploy application (replace ACR_LOGIN_SERVER in deployment.yaml)
sed -e "s|\${ACR_LOGIN_SERVER}|${ACR_LOGIN_SERVER}|g" -e "s|\${IMAGE_TAG}|${SAMPLE_APP_IMAGE_TAG}|g" deployment.yaml | kubectl apply -f -
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml
```

#### Step 6: Get External IP

```bash
# Wait for IP assignment (may take 2-3 minutes)
kubectl get ingress nginx-demo-ingress --watch

# Once IP is assigned
EXTERNAL_IP=$(kubectl get ingress nginx-demo-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Application URL: http://$EXTERNAL_IP"
```

## Testing

### Access the Application

```bash
# Get the external IP
EXTERNAL_IP=$(kubectl get ingress nginx-demo-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Main page
curl http://$EXTERNAL_IP

# Health check
curl http://$EXTERNAL_IP/health

# API info
curl http://$EXTERNAL_IP/api/info
```

### Verify Deployment

```bash
# Check pods
kubectl get pods -l app=nginx-demo-app

# Check service
kubectl get service nginx-demo-service

# Check ingress
kubectl get ingress nginx-demo-ingress

# Check NGINX controller
kubectl get pods -n ingress-nginx
```

### View Logs

```bash
# Application logs
kubectl logs -l app=nginx-demo-app --tail=50 -f

# NGINX Ingress Controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=50 -f
```

## Troubleshooting

### External IP Stuck in "Pending"

```bash
# Check LoadBalancer service
kubectl get svc -n ingress-nginx

# Check events
kubectl get events -n ingress-nginx --sort-by='.lastTimestamp'
```

### Application Not Responding

```bash
# Check pod status
kubectl get pods -l app=nginx-demo-app

# Describe pod for events
kubectl describe pod -l app=nginx-demo-app

# Check logs
kubectl logs -l app=nginx-demo-app
```

### Ingress Not Working

```bash
# Verify ingress resource
kubectl describe ingress nginx-demo-ingress

# Check NGINX controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
```

## Comparison with Modern Alternatives

| Feature | NGINX Ingress | Gateway API | AGC |
|---------|--------------|-------------|---------------------------|
| **Kubernetes Native** | Yes | Yes | Yes |
| **Azure Native** | No | No | Yes |
| **Public IP Assignment** | LoadBalancer | LoadBalancer | Azure-managed |
| **Configuration** | Annotations | Typed fields | Typed + Azure annotations |
| **TLS Termination** | Manual certs | Manual certs | Azure Key Vault integration |
| **WAF** | Requires ModSecurity | External | Built-in ready |
| **Cost** | Lower | Lower | Higher (but more features) |

## Migration Paths

If you're using NGINX Ingress Controller, consider migrating to:

1. **Gateway API with Envoy** - For cross-cloud portability and modern Kubernetes standards
2. **Application Gateway for Containers** - For Azure-first deployments with enterprise features

See the other demos in this repository:
- [Gateway API with Envoy](../02-envoy-gateway-api/)
- [Application Gateway for Containers](../03-agc-for-containers/)

## Clean Up

Demo cleanup scripts leave the shared ACR in `rg-aksdemo-shared` so another demo can continue pulling the shared image. After all demos are removed, delete the shared registry resource group manually if you no longer need it:

```bash
az group delete --name rg-aksdemo-shared --yes --no-wait
```


### Using the Cleanup Script

```bash
./scripts/cleanup.sh
```

### Manual Cleanup

```bash
# Delete the resource group (removes all resources)
az group delete \
  --name rg-01-nginx-ingress-demo \
  --yes \
  --no-wait
```

## Cost Breakdown

Approximate monthly costs for the Sweden Central demos. Actual Azure pricing is region-dependent and may vary with usage:

| Resource | Cost |
|----------|------|
| AKS Cluster (2 nodes) | ~$140 |
| Shared Azure Container Registry | ~$20 total |
| Load Balancer | ~$20 |
| Public IP Address | ~$4 |
| Log Analytics | ~$5 |
| **Total** | **~$189/month** |

💡 Remember to delete resources when not in use.

## Resources

### Official Documentation
- [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [AKS Networking](https://learn.microsoft.com/azure/aks/concepts-network)

### Migration Guides
- [Migrating from Ingress to Gateway API](https://gateway-api.sigs.k8s.io/guides/migrating-from-ingress/)
- [AKS Application Routing (Gateway API)](https://learn.microsoft.com/azure/aks/app-routing)

## Next Steps

1. ✅ Deploy this demo to understand NGINX Ingress
2. 🔄 Compare with [Gateway API demo](../02-envoy-gateway-api/)
3. 🚀 Explore [Azure AGC](../03-agc-for-containers/)
4. 📚 Plan your migration strategy

---

**Demo Status**: ⚠️ Educational (Traditional Ingress Pattern)  
**Last Updated**: 2026  
**Maintained by**: AKS Community Demos
