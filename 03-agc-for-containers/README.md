# AGC Demo

✅ **Azure-native, enterprise-ready application delivery solution**

## Overview

This demo deploys a simple .NET 10 web application to Azure Kubernetes Service (AKS) using **Application Gateway for Containers** (AGC), Microsoft's modern, cloud-native application load balancer built specifically for containerized workloads.

**Why Application Gateway for Containers?**
- ✅ **Azure-Native**: Deep integration with Azure networking, security, and monitoring
- ✅ **Enterprise Features**: Ready for WAF, Azure Monitor, and advanced traffic management
- ✅ **Simplified Management**: Fully managed by Azure, no infrastructure to maintain
- ✅ **Gateway API Compatible**: Uses Kubernetes Gateway API standard
- ✅ **Scalable**: Automatically scales based on demand
- ✅ **Cost-Effective**: Pay only for what you use with consumption-based pricing

**When to Use AGC?**
- You're building on Azure and want the best Azure integration
- You need enterprise features (WAF, centralized monitoring, advanced routing)
- You want Azure to manage the infrastructure for you
- You need seamless integration with Azure Virtual Networks
- You want a future-proof, actively developed solution

## Traffic Flow

```
┌────────────────────────────────────────────────────────────────────────────┐
│                          Azure Cloud                                       │
│                                                                            │
│  Internet User                                                             │
│       │                                                                    │
│       │ HTTP Request                                                       │
│       ▼                                                                    │
│  ┌────────────────────────────────────────────────────────────────────┐   │
│  │  Application Gateway for Containers (Public IP: x.x.x.x)           │   │
│  │  - Managed by Azure (PaaS service)                                 │   │
│  │  - Subnet: 10.4.4.0/24 (delegated)                                 │   │
│  │  - Reads Gateway + HTTPRoute from AKS                              │   │
│  │  - Handles SSL termination, WAF, routing                           │   │
│  └────────────────────────┬───────────────────────────────────────────┘   │
│                           │                                                │
│                           │ Routes to AKS via Private Endpoint             │
│                           ▼                                                │
│  ┌──────────────────────────────────────────────────────────────────────┐ │
│  │  Virtual Network: 10.4.0.0/16                                        │ │
│  │                                                                       │ │
│  │  ┌────────────────────────────────────────────────────────────────┐  │ │
│  │  │  AKS Cluster (Subnet: 10.4.0.0/22)                             │  │ │
│  │  │                                                                 │  │ │
│  │  │  ┌──────────────────────────────────────────────────────────┐  │  │ │
│  │  │  │  Namespace: azure-alb-system                              │  │  │ │
│  │  │  │                                                            │  │  │ │
│  │  │  │  ┌────────────────────────────────────────────────────┐   │  │  │ │
│  │  │  │  │  ALB Controller (Deployment)                       │   │  │  │ │
│  │  │  │  │  - Watches Gateway API resources                   │   │  │  │ │
│  │  │  │  │  - Configures Azure Application Gateway            │   │  │  │ │
│  │  │  │  │  - Syncs AKS resources → AGC configuration         │   │  │  │ │
│  │  │  │  └────────────────────────────────────────────────────┘   │  │  │ │
│  │  │  │                                                            │  │  │ │
│  │  │  │  ┌────────────────────────────────────────────────────┐   │  │  │ │
│  │  │  │  │  ApplicationLoadBalancer CRD                       │   │  │  │ │
│  │  │  │  │  - Associates AGC with subnet                      │   │  │  │ │
│  │  │  │  │  - Links to Azure infrastructure                   │   │  │  │ │
│  │  │  │  └────────────────────────────────────────────────────┘   │  │  │ │
│  │  │  └──────────────────────────────────────────────────────────┘  │  │ │
│  │  │                                                                 │  │ │
│  │  │  ┌──────────────────────────────────────────────────────────┐  │  │ │
│  │  │  │  Namespace: demo                                       │  │  │ │
│  │  │  │                                                            │  │  │ │
│  │  │  │  ┌────────────────────────────────────────────────────┐   │  │  │ │
│  │  │  │  │  Gateway: agc-demo-gateway                       │   │  │  │ │
│  │  │  │  │  - GatewayClassName: azure-alb-external            │   │  │  │ │
│  │  │  │  │  - Listener: HTTP on port 80                       │   │  │  │ │
│  │  │  │  │  - Configures AGC frontend listener                │   │  │  │ │
│  │  │  │  └────────────────────┬───────────────────────────────┘   │  │  │ │
│  │  │  │                       │                                    │  │  │ │
│  │  │  │                       │ Referenced by                      │  │  │ │
│  │  │  │                       ▼                                    │  │  │ │
│  │  │  │  ┌────────────────────────────────────────────────────┐   │  │  │ │
│  │  │  │  │  HTTPRoute: agc-demo-route                       │   │  │  │ │
│  │  │  │  │  - ParentRef: agc-demo-gateway                   │   │  │  │ │
│  │  │  │  │  - Match: Path "/"                                 │   │  │  │ │
│  │  │  │  │  - BackendRef: agc-demo-service                  │   │  │  │ │
│  │  │  │  │  - Configures AGC routing rules                    │   │  │  │ │
│  │  │  │  └────────────────────┬───────────────────────────────┘   │  │  │ │
│  │  │  │                       │                                    │  │  │ │
│  │  │  │                       │ Routes to                          │  │  │ │
│  │  │  │                       ▼                                    │  │  │ │
│  │  │  │  ┌────────────────────────────────────────────────────┐   │  │  │ │
│  │  │  │  │  Service: agc-demo-service                       │   │  │  │ │
│  │  │  │  │  - Type: ClusterIP                                 │   │  │  │ │
│  │  │  │  │  - Port: 80 → TargetPort: 8080                     │   │  │  │ │
│  │  │  │  │  - Selector: app=agc-demo-app                    │   │  │  │ │
│  │  │  │  └────────────────────┬───────────────────────────────┘   │  │  │ │
│  │  │  │                       │                                    │  │  │ │
│  │  │  │                       │ Load balances to                   │  │  │ │
│  │  │  │                       ▼                                    │  │  │ │
│  │  │  │  ┌─────────────────────────────────────────────────┐      │  │  │ │
│  │  │  │  │  Deployment: agc-demo-app                     │      │  │  │ │
│  │  │  │  │  - Replicas: 2                                  │      │  │  │ │
│  │  │  │  │                                                  │      │  │  │ │
│  │  │  │  │  ┌─────────────────┐    ┌─────────────────┐    │      │  │  │ │
│  │  │  │  │  │  Pod 1          │    │  Pod 2          │    │      │  │  │ │
│  │  │  │  │  │  ┌───────────┐  │    │  ┌───────────┐  │    │      │  │  │ │
│  │  │  │  │  │  │ Container │  │    │  │ Container │  │    │      │  │  │ │
│  │  │  │  │  │  │ .NET App  │  │    │  │ .NET App  │  │    │      │  │  │ │
│  │  │  │  │  │  │ Port 8080 │  │    │  │ Port 8080 │  │    │      │  │  │ │
│  │  │  │  │  │  └───────────┘  │    │  └───────────┘  │    │      │  │  │ │
│  │  │  │  │  └─────────────────┘    └─────────────────┘    │      │  │  │ │
│  │  │  │  └─────────────────────────────────────────────────┘      │  │  │ │
│  │  │  └──────────────────────────────────────────────────────────┘  │  │ │
│  │  └─────────────────────────────────────────────────────────────────┘  │ │
│  └──────────────────────────────────────────────────────────────────────┘ │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘

Traffic Path Summary:
  1. User → Application Gateway for Containers (Public IP)
  2. AGC → Reads Gateway + HTTPRoute from AKS via ALB Controller
  3. AGC → Routes to AKS cluster via private VNet connectivity
  4. HTTPRoute → Defines routing to agc-demo-service
  5. Service → Load balances to Pod (Port 8080)
  6. Pod → .NET Application responds

Key Azure-Specific Features:
  • AGC is a managed Azure PaaS service (no pods to manage)
  • ALB Controller syncs K8s resources to AGC configuration
  • Traffic stays within Azure VNet for security
  • Supports WAF, Azure Monitor, advanced routing
  • ApplicationLoadBalancer CRD associates AGC with subnet
  • Uses Gateway API standard (portable pattern)
```

## Architecture

```
┌───────────────────────────────────────────────────────────────────┐
│                     Azure Cloud                                   │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐│
│  │   Virtual Network (10.4.0.0/16)                              ││
│  │                                                               ││
│  │   ┌───────────────────────────────────────────────────────┐ ││
│  │   │  Application Gateway Subnet (10.4.4.0/24)             │ ││
│  │   │  - Delegated to ServiceNetworking/trafficControllers  │ ││
│  │   │  - Application Gateway for Containers (AGC)           │ ││
│  │   │  - Frontend with Public IP                            │ ││
│  │   └───────────────────────────────────────────────────────┘ ││
│  │                          │                                    ││
│  │                          ▼                                    ││
│  │   ┌───────────────────────────────────────────────────────┐ ││
│  │   │  AKS Subnet (10.4.0.0/22)                             │ ││
│  │   │                                                        │ ││
│  │   │  ┌──────────────────────────────────────────────────┐│ ││
│  │   │  │  azure-alb-system Namespace (Platform)          ││ ││
│  │   │  │  - ALB Controller                               ││ ││
│  │   │  │  alb-infra Namespace                            ││ ││
│  │   │  │  - ApplicationLoadBalancer Resource              ││ ││
│  │   │  └──────────────────────────────────────────────────┘│ ││
│  │   │                                                        │ ││
│  │   │  ┌──────────────────────────────────────────────────┐│ ││
│  │   │  │  demo Namespace (Application)                 ││ ││
│  │   │  │  - Gateway: agc-demo-gateway                   ││ ││
│  │   │  │  - HTTPRoute: agc-demo-route                   ││ ││
│  │   │  │  - Service: agc-demo-service                   ││ ││
│  │   │  │  - Deployment: agc-demo-app (2 replicas)       ││ ││
│  │   │  └──────────────────────────────────────────────────┘│ ││
│  │   └───────────────────────────────────────────────────────┘ ││
│  └──────────────────────────────────────────────────────────────┘│
│                          ▲                                        │
└──────────────────────────┼────────────────────────────────────────┘
                           │
                    Internet Traffic
                  (via AGC Public IP)
```

## Key Concepts

### Application Gateway for Containers (AGC)

AGC is a modern application delivery controller optimized for:
- **Containerized Workloads**: Purpose-built for Kubernetes
- **Azure Integration**: Native integration with Azure services
- **Automatic Scaling**: Scales based on traffic demand
- **High Performance**: Low latency, high throughput
- **Enterprise Ready**: WAF support, advanced routing, observability

### Components

#### 1. ALB Controller (`azure-alb-system`)
- Kubernetes controller installed with the Application Gateway for Containers Helm chart
- Watches for Gateway and HTTPRoute resources
- Configures Application Gateway for Containers
- Manages lifecycle of AGC instances

#### 2. ApplicationLoadBalancer CRD
```yaml
apiVersion: alb.networking.azure.io/v1
kind: ApplicationLoadBalancer
metadata:
  name: alb
  namespace: alb-infra
spec:
  associations:
  - <agc-subnet-id>
```
- Represents the AGC instance
- Associates with delegated subnet
- Managed by ALB Controller

#### 3. Gateway (Application Namespace)
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  namespace: demo
  annotations:
    alb.networking.azure.io/alb-name: alb
    alb.networking.azure.io/alb-namespace: alb-infra
spec:
  gatewayClassName: azure-alb-external
  listeners:
  - name: http
    port: 80
    protocol: HTTP
```
- Defines how traffic enters the cluster
- References the ApplicationLoadBalancer
- Created by application teams

#### 4. HTTPRoute (Application Namespace)
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
spec:
  parentRefs:
  - name: agc-demo-gateway
  rules:
  - matches:
    - path: /
    backendRefs:
    - name: agc-demo-service
```
- Defines routing rules
- Maps requests to Kubernetes services
- Created by application teams

## Prerequisites

- Azure CLI (`az`) version 2.50.0+
- kubectl version 1.27+
- Helm version 3.12+
- No local Docker installation required; the shared image is built remotely with Azure Container Registry Tasks
- Active Azure subscription with permissions to:
  - Create resource groups
  - Create Virtual Networks
  - Create AKS clusters
  - Register resource providers (Microsoft.ServiceNetworking)
  - Create role assignments

## Deployment

### Option 1: Automated Deployment (Recommended)

```bash
# Run the deployment script
./scripts/deploy.sh
```

The script runs the three focused deployment phases in sequence:
1. `./scripts/deploy-infra.sh` registers required Azure providers, creates the resource group, deploys VNet/AKS via Bicep, enables managed Prometheus, creates/reuses the shared ACR, Azure Monitor workspace, and Grafana in `rg-aksdemo-shared`, and grants AKS pull access. This phase does not use `kubectl` and can be run in parallel with other demos.
2. `./scripts/build-image.sh` builds the shared sample app image with Azure Container Registry Tasks only if the source-content tag is missing.
3. `./scripts/configure-kubernetes.sh` gets AKS credentials, configures Application Gateway for Containers, deploys Gateway/HTTPRoute/application resources, and displays the public URL. This is the only phase that changes or relies on the active `kubectl` context.

You can also run the phases independently:

```bash
./scripts/deploy-infra.sh
./scripts/build-image.sh
./scripts/configure-kubernetes.sh
```

**Estimated time**: 10-15 minutes

The shared ACR lives in `rg-aksdemo-shared`. Set `SHARED_ACR_NAME` to reuse a specific registry name; otherwise the scripts derive one from the subscription. The shared ACR is intentionally not deleted by a single demo cleanup script.

### Option 2: Manual Deployment

#### Step 1: Register Provider

```bash
# Register AGC providers
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.NetworkFunction
az provider register --namespace Microsoft.ServiceNetworking

# Wait for registration to complete
az provider show --namespace Microsoft.ServiceNetworking --query "registrationState"
```

#### Step 2: Deploy Infrastructure

```bash
# Create resource group
az group create \
  --name rg-03-agc-containers-demo \
  --location swedencentral

# Deploy Bicep template and reference the shared ACR
cd infrastructure
source ../../shared/scripts/acr-image.sh
ACR_NAME=$(ensure_shared_acr)
USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)
az deployment group create \
  --resource-group rg-03-agc-containers-demo \
  --name agc-demo-deployment \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --parameters userObjectId="$USER_OBJECT_ID" \
  --parameters sharedAcrName="$ACR_NAME" \
  --parameters sharedAcrResourceGroupName="$SHARED_ACR_RESOURCE_GROUP"
```

The automated `scripts/deploy-infra.sh` also assigns the AGC managed identity these required permissions:

- Reader on the AKS resource group
- Reader on the AKS-managed infrastructure resource group
- AppGw for Containers Configuration Manager on the AKS-managed infrastructure resource group
- Network Contributor on the delegated AGC subnet

If deploying manually, mirror those role assignments before installing the ALB Controller.

#### Step 3: Get Credentials

```bash
# Get AKS cluster name
AKS_NAME=$(az deployment group show \
  --resource-group rg-03-agc-containers-demo \
  --name agc-demo-deployment \
  --query properties.outputs.aksClusterName.value \
  --output tsv)

# Get credentials
az aks get-credentials \
  --resource-group rg-03-agc-containers-demo \
  --name $AKS_NAME \
  --overwrite-existing
```

#### Step 4: Build Shared Image with ACR Tasks

```bash
# Get shared ACR name
ACR_NAME=$(az deployment group show \
  --resource-group rg-03-agc-containers-demo \
  --name agc-demo-deployment \
  --query properties.outputs.acrName.value \
  --output tsv)

# Build remotely only if the source-content tag is missing
source ../../shared/scripts/acr-image.sh
ensure_sample_app_image "$ACR_NAME" "../../shared/sample-app" "aks-ingress-demo"
```

#### Step 5: Install ALB Controller

```bash
# Read AGC identity outputs
AGC_IDENTITY_NAME=$(az deployment group show \
  --resource-group rg-03-agc-containers-demo \
  --name agc-demo-deployment \
  --query properties.outputs.agcIdentityName.value \
  --output tsv)

AGC_IDENTITY_CLIENT_ID=$(az deployment group show \
  --resource-group rg-03-agc-containers-demo \
  --name agc-demo-deployment \
  --query properties.outputs.agcIdentityClientId.value \
  --output tsv)

OIDC_ISSUER_URL=$(az deployment group show \
  --resource-group rg-03-agc-containers-demo \
  --name agc-demo-deployment \
  --query properties.outputs.oidcIssuerUrl.value \
  --output tsv)

# Federate the AGC identity with the ALB Controller service account
az identity federated-credential create \
  --resource-group rg-03-agc-containers-demo \
  --identity-name $AGC_IDENTITY_NAME \
  --name alb-controller \
  --issuer $OIDC_ISSUER_URL \
  --subject system:serviceaccount:azure-alb-system:alb-controller-sa

# Install ALB Controller with Helm
helm upgrade --install alb-controller oci://mcr.microsoft.com/application-lb/charts/alb-controller \
  --namespace azure-alb-system \
  --create-namespace \
  --version 1.10.28 \
  --set albController.namespace=azure-alb-system \
  --set albController.podIdentity.clientID=$AGC_IDENTITY_CLIENT_ID \
  --wait \
  --timeout 10m
```

#### Step 6: Create ApplicationLoadBalancer

```bash
# Get subnet ID
AGC_SUBNET_ID=$(az deployment group show \
  --resource-group rg-03-agc-containers-demo \
  --name agc-demo-deployment \
  --query properties.outputs.agcSubnetId.value \
  --output tsv)

# Create ApplicationLoadBalancer resource
kubectl create namespace alb-infra --dry-run=client -o yaml | kubectl apply -f -

cat <<EOF | kubectl apply -f -
apiVersion: alb.networking.azure.io/v1
kind: ApplicationLoadBalancer
metadata:
  name: alb
  namespace: alb-infra
spec:
  associations:
  - $AGC_SUBNET_ID
EOF

# Wait for provisioning
kubectl get applicationloadbalancer -n alb-infra alb --watch
```

#### Step 7: Deploy Application

```bash
cd ../kubernetes

# Get ACR login server
ACR_LOGIN_SERVER=$(az acr show --resource-group rg-aksdemo-shared --name "$ACR_NAME" --query loginServer --output tsv)

# Deploy application
kubectl apply -f namespace.yaml
sed -e "s|\${ACR_LOGIN_SERVER}|${ACR_LOGIN_SERVER}|g" -e "s|\${IMAGE_TAG}|${SAMPLE_APP_IMAGE_TAG}|g" deployment.yaml | kubectl apply -f -
kubectl apply -f service.yaml
kubectl apply -f gateway.yaml
kubectl apply -f httproute.yaml
```

#### Step 8: Get External IP

```bash
# Wait for Gateway to get IP (may take 2-3 minutes)
kubectl get gateway agc-demo-gateway -n demo --watch

# Once IP is assigned
EXTERNAL_IP=$(kubectl get gateway agc-demo-gateway -n demo -o jsonpath='{.status.addresses[0].value}')
echo "Application URL: http://$EXTERNAL_IP"
```

## Testing

### Access the Application

```bash
# Get the external IP
EXTERNAL_IP=$(kubectl get gateway agc-demo-gateway -n demo -o jsonpath='{.status.addresses[0].value}')

# Main page
curl http://$EXTERNAL_IP

# Health check
curl http://$EXTERNAL_IP/health

# API info
curl http://$EXTERNAL_IP/api/info
```

### Verify Resources

```bash
# Check all demo application resources
kubectl get all -n demo

# Check ApplicationLoadBalancer
kubectl get applicationloadbalancer -n alb-infra
kubectl describe applicationloadbalancer -n alb-infra alb

# Check Gateway
kubectl get gateway agc-demo-gateway -n demo
kubectl describe gateway agc-demo-gateway -n demo

# Check HTTPRoute
kubectl get httproute agc-demo-route -n demo
kubectl describe httproute agc-demo-route -n demo

# Check pods
kubectl get pods -n demo -l app=agc-demo-app

# Check ALB Controller
kubectl get pods -n azure-alb-system -l app=alb-controller
```

### View Logs

```bash
# Application logs
kubectl logs -n demo -l app=agc-demo-app --tail=50 -f

# ALB Controller logs
kubectl logs -n azure-alb-system -l app=alb-controller --tail=50 -f
```

## Advanced Features

### SSL/TLS Termination with Azure Key Vault

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  namespace: demo
  annotations:
    alb.networking.azure.io/alb-name: alb
    alb.networking.azure.io/alb-namespace: alb-infra
spec:
  gatewayClassName: azure-alb-external
  listeners:
  - name: https
    protocol: HTTPS
    port: 443
    tls:
      mode: Terminate
      certificateRefs:
      - kind: Secret
        name: my-tls-secret
```

### Header-Based Routing

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
spec:
  rules:
  - matches:
    - headers:
      - name: api-version
        value: v2
    backendRefs:
    - name: api-v2-service
```

### Traffic Splitting (Blue/Green, Canary)

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
spec:
  rules:
  - backendRefs:
    - name: app-blue
      port: 80
      weight: 90
    - name: app-green
      port: 80
      weight: 10
```

## Troubleshooting

### ApplicationLoadBalancer Not Provisioning

```bash
# Check ALB resource status
kubectl describe applicationloadbalancer -n alb-infra alb

# Check ALB Controller logs
kubectl logs -n azure-alb-system -l app=alb-controller

# Verify subnet delegation
az network vnet subnet show \
  --resource-group rg-03-agc-containers-demo \
  --vnet-name <vnet-name> \
  --name agc-subnet \
  --query delegations
```

### Gateway Not Getting External IP

```bash
# Check Gateway status
kubectl describe gateway agc-demo-gateway -n demo

# Check events
kubectl get events -n demo --sort-by='.lastTimestamp'

# Verify Gateway references correct ALB
kubectl get gateway agc-demo-gateway -n demo -o yaml | grep alb
```

### HTTPRoute Not Working

```bash
# Check HTTPRoute status
kubectl describe httproute agc-demo-route -n demo

# Verify backend service exists
kubectl get service agc-demo-service -n demo

# Check service endpoints
kubectl get endpoints agc-demo-service -n demo
```

## Comparison with Other Solutions

| Feature | NGINX Ingress | Gateway API (Envoy) | AGC |
|---------|--------------|---------------------|---------------------------|
| **Azure Integration** | External | External | Native (Deep) |
| **Management** | Self-managed | Self-managed | Fully managed by Azure |
| **WAF Support** | ModSecurity | External | Azure WAF (ready) |
| **Cost Model** | Infrastructure only | Infrastructure only | Consumption-based |
| **Scalability** | Manual | Manual | Automatic |
| **Key Vault Integration** | Manual | Manual | Native |
| **Azure Monitor** | Via container logs | Via container logs | Native integration |
| **Best For** | Legacy migrations | Cross-cloud portability | Azure-first deployments |

## Benefits of Application Gateway for Containers

✅ **Azure-Native**: Seamless integration with Azure services  
✅ **Fully Managed**: No infrastructure to maintain  
✅ **Enterprise Features**: WAF, advanced routing, centralized monitoring  
✅ **Auto-Scaling**: Automatically scales with traffic  
✅ **Gateway API Compatible**: Uses Kubernetes standard  
✅ **Cost-Effective**: Pay only for what you use  
✅ **Future-Proof**: Actively developed and supported by Microsoft  

## Observability

`deploy-infra.sh` enables Azure Monitor managed Prometheus on this AKS cluster and connects it to the shared Azure Monitor workspace and Azure Managed Grafana instance in `rg-aksdemo-shared`. The deployment output prints the Grafana endpoint. In Grafana, use the Azure Managed Prometheus Kubernetes dashboards and filter by this cluster to review cluster health, ingress/gateway traffic, pod health, and CPU/memory usage.

## Clean Up

Demo cleanup scripts leave the shared ACR in `rg-aksdemo-shared` so another demo can continue pulling the shared image. After all demos are removed, delete the shared registry resource group manually if you no longer need it:

```bash
az group delete --name rg-aksdemo-shared --yes --no-wait  # Only after all demos and shared Grafana use are finished
```


### Using the Cleanup Script

```bash
./scripts/cleanup.sh
```

### Manual Cleanup

```bash
# Delete the resource group (removes all resources)
az group delete \
  --name rg-03-agc-containers-demo \
  --yes \
  --no-wait
```

## Cost Breakdown

Approximate monthly costs for the Sweden Central demos. Actual Azure pricing is region-dependent and may vary with usage:

| Resource | Cost |
|----------|------|
| AKS Cluster (2 nodes) | ~$140 |
| Application Gateway for Containers | ~$40 (base) + consumption |
| Shared Azure Container Registry | ~$20 total |
| Virtual Network | No charge |
| Public IP Address | ~$4 |
| Log Analytics | ~$5 |
| Shared Azure Managed Grafana / managed Prometheus ingestion | Usage-based |
| **Total** | **~$209/month** |

💡 AGC uses consumption-based pricing for traffic, so costs vary with usage.

## Resources

### Official Documentation
- [Application Gateway for Containers](https://learn.microsoft.com/azure/application-gateway/for-containers/)
- [Gateway API on AKS](https://learn.microsoft.com/azure/aks/app-routing-gateway-api)

### Guides and Tutorials
- [Deploy Application Gateway for Containers ALB Controller with Helm](https://learn.microsoft.com/azure/application-gateway/for-containers/quickstart-deploy-application-gateway-for-containers-alb-controller-helm)
- [Create AGC managed by ALB Controller](https://learn.microsoft.com/azure/application-gateway/for-containers/quickstart-create-application-gateway-for-containers-managed-by-alb-controller)
- [Gateway API Overview](https://gateway-api.sigs.k8s.io/)

## Next Steps

1. ✅ Deploy this demo to understand Azure AGC
2. 🔬 Explore advanced features (SSL/TLS, WAF, header routing)
3. 📊 Compare performance and cost with other solutions
4. 🚀 Consider for your production workloads

---

**Demo Status**: ✅ Production-Ready, Azure-Native Solution  
**Last Updated**: 2026  
**Maintained by**: AKS Community Demos
