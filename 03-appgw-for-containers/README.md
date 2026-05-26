# Application Gateway for Containers Demo

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
│  │  │  │  Namespace: kube-system                                   │  │  │ │
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
│  │  │  │  Namespace: default                                       │  │  │ │
│  │  │  │                                                            │  │  │ │
│  │  │  │  ┌────────────────────────────────────────────────────┐   │  │  │ │
│  │  │  │  │  Gateway: appgw-demo-gateway                       │   │  │  │ │
│  │  │  │  │  - GatewayClassName: azure-alb-external            │   │  │  │ │
│  │  │  │  │  - Listener: HTTP on port 80                       │   │  │  │ │
│  │  │  │  │  - Configures AGC frontend listener                │   │  │  │ │
│  │  │  │  └────────────────────┬───────────────────────────────┘   │  │  │ │
│  │  │  │                       │                                    │  │  │ │
│  │  │  │                       │ Referenced by                      │  │  │ │
│  │  │  │                       ▼                                    │  │  │ │
│  │  │  │  ┌────────────────────────────────────────────────────┐   │  │  │ │
│  │  │  │  │  HTTPRoute: appgw-demo-route                       │   │  │  │ │
│  │  │  │  │  - ParentRef: appgw-demo-gateway                   │   │  │  │ │
│  │  │  │  │  - Match: Path "/"                                 │   │  │  │ │
│  │  │  │  │  - BackendRef: appgw-demo-service                  │   │  │  │ │
│  │  │  │  │  - Configures AGC routing rules                    │   │  │  │ │
│  │  │  │  └────────────────────┬───────────────────────────────┘   │  │  │ │
│  │  │  │                       │                                    │  │  │ │
│  │  │  │                       │ Routes to                          │  │  │ │
│  │  │  │                       ▼                                    │  │  │ │
│  │  │  │  ┌────────────────────────────────────────────────────┐   │  │  │ │
│  │  │  │  │  Service: appgw-demo-service                       │   │  │  │ │
│  │  │  │  │  - Type: ClusterIP                                 │   │  │  │ │
│  │  │  │  │  - Port: 80 → TargetPort: 8080                     │   │  │  │ │
│  │  │  │  │  - Selector: app=appgw-demo-app                    │   │  │  │ │
│  │  │  │  └────────────────────┬───────────────────────────────┘   │  │  │ │
│  │  │  │                       │                                    │  │  │ │
│  │  │  │                       │ Load balances to                   │  │  │ │
│  │  │  │                       ▼                                    │  │  │ │
│  │  │  │  ┌─────────────────────────────────────────────────┐      │  │  │ │
│  │  │  │  │  Deployment: appgw-demo-app                     │      │  │  │ │
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
  4. HTTPRoute → Defines routing to appgw-demo-service
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
│  │   │  │  kube-system Namespace (Platform)                ││ ││
│  │   │  │  - ALB Controller                                 ││ ││
│  │   │  │  - ApplicationLoadBalancer Resource              ││ ││
│  │   │  └──────────────────────────────────────────────────┘│ ││
│  │   │                                                        │ ││
│  │   │  ┌──────────────────────────────────────────────────┐│ ││
│  │   │  │  default Namespace (Application)                 ││ ││
│  │   │  │  - Gateway: appgw-demo-gateway                   ││ ││
│  │   │  │  - HTTPRoute: appgw-demo-route                   ││ ││
│  │   │  │  - Service: appgw-demo-service                   ││ ││
│  │   │  │  - Deployment: appgw-demo-app (2 replicas)       ││ ││
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

#### 1. ALB Controller (kube-system)
- Kubernetes controller installed by AKS
- Watches for Gateway and HTTPRoute resources
- Configures Application Gateway for Containers
- Manages lifecycle of AGC instances

#### 2. ApplicationLoadBalancer CRD
```yaml
apiVersion: alb.networking.azure.io/v1
kind: ApplicationLoadBalancer
metadata:
  name: alb-controller
  namespace: kube-system
spec:
  associations:
  - <appgw-subnet-id>
```
- Represents the AGC instance
- Associates with delegated subnet
- Managed by ALB Controller

#### 3. Gateway (Application Namespace)
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  annotations:
    alb.networking.azure.io/alb-name: alb-controller
    alb.networking.azure.io/alb-namespace: kube-system
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
  - name: appgw-demo-gateway
  rules:
  - matches:
    - path: /
    backendRefs:
    - name: appgw-demo-service
```
- Defines routing rules
- Maps requests to Kubernetes services
- Created by application teams

## Prerequisites

- Azure CLI (`az`) version 2.50.0+
- kubectl version 1.27+
- No local Docker installation required; images are built remotely with Azure Container Registry Tasks
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

The script will:
1. Register Microsoft.ServiceNetworking provider
2. Create Azure resource group
3. Deploy VNet, AKS cluster, and ACR via Bicep
4. Build and push the container image with Azure Container Registry Tasks
5. Enable ALB Controller on AKS
6. Create ApplicationLoadBalancer resource
7. Deploy Gateway and HTTPRoute resources
8. Deploy the application
9. Display the public URL

**Estimated time**: 10-15 minutes

### Option 2: Manual Deployment

#### Step 1: Register Provider

```bash
# Register Microsoft.ServiceNetworking provider
az provider register --namespace Microsoft.ServiceNetworking

# Wait for registration to complete
az provider show --namespace Microsoft.ServiceNetworking --query "registrationState"
```

#### Step 2: Deploy Infrastructure

```bash
# Create resource group
az group create \
  --name rg-03-appgw-containers-demo \
  --location swedencentral

# Deploy Bicep template
cd infrastructure
az deployment group create \
  --resource-group rg-03-appgw-containers-demo \
  --name appgw-demo-deployment \
  --template-file main.bicep \
  --parameters main.bicepparam
```

#### Step 3: Get Credentials

```bash
# Get AKS cluster name
AKS_NAME=$(az deployment group show \
  --resource-group rg-03-appgw-containers-demo \
  --name appgw-demo-deployment \
  --query properties.outputs.aksClusterName.value \
  --output tsv)

# Get credentials
az aks get-credentials \
  --resource-group rg-03-appgw-containers-demo \
  --name $AKS_NAME \
  --overwrite-existing
```

#### Step 4: Build and Push Image with ACR Tasks

```bash
# Get ACR name
ACR_NAME=$(az deployment group show \
  --resource-group rg-03-appgw-containers-demo \
  --name appgw-demo-deployment \
  --query properties.outputs.acrName.value \
  --output tsv)

# Build and push remotely in Azure; no local Docker daemon is required
cd ../shared/sample-app
az acr build \
  --registry $ACR_NAME \
  --image aks-ingress-demo:latest \
  --file Dockerfile \
  .
```

#### Step 5: Enable Application Gateway for Containers

```bash
# Enable ALB Controller (Web App Routing)
az aks approuting enable \
  --resource-group rg-03-appgw-containers-demo \
  --name $AKS_NAME

# Wait for controller to be ready
kubectl wait --for=condition=available --timeout=300s \
  deployment/alb-controller -n kube-system
```

#### Step 6: Create ApplicationLoadBalancer

```bash
# Get subnet ID
APPGW_SUBNET_ID=$(az deployment group show \
  --resource-group rg-03-appgw-containers-demo \
  --name appgw-demo-deployment \
  --query properties.outputs.appgwSubnetId.value \
  --output tsv)

# Create ApplicationLoadBalancer resource
cat <<EOF | kubectl apply -f -
apiVersion: alb.networking.azure.io/v1
kind: ApplicationLoadBalancer
metadata:
  name: alb-controller
  namespace: kube-system
spec:
  associations:
  - $APPGW_SUBNET_ID
EOF

# Wait for provisioning
kubectl get applicationloadbalancer -n kube-system alb-controller --watch
```

#### Step 7: Deploy Application

```bash
cd ../03-appgw-for-containers/kubernetes

# Get ACR login server
ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --query loginServer --output tsv)

# Deploy application
sed "s|\${ACR_LOGIN_SERVER}|${ACR_LOGIN_SERVER}|g" deployment.yaml | kubectl apply -f -
kubectl apply -f service.yaml
kubectl apply -f gateway.yaml
kubectl apply -f httproute.yaml
```

#### Step 8: Get External IP

```bash
# Wait for Gateway to get IP (may take 2-3 minutes)
kubectl get gateway appgw-demo-gateway --watch

# Once IP is assigned
EXTERNAL_IP=$(kubectl get gateway appgw-demo-gateway -o jsonpath='{.status.addresses[0].value}')
echo "Application URL: http://$EXTERNAL_IP"
```

## Testing

### Access the Application

```bash
# Get the external IP
EXTERNAL_IP=$(kubectl get gateway appgw-demo-gateway -o jsonpath='{.status.addresses[0].value}')

# Main page
curl http://$EXTERNAL_IP

# Health check
curl http://$EXTERNAL_IP/health

# API info
curl http://$EXTERNAL_IP/api/info
```

### Verify Resources

```bash
# Check ApplicationLoadBalancer
kubectl get applicationloadbalancer -n kube-system
kubectl describe applicationloadbalancer -n kube-system alb-controller

# Check Gateway
kubectl get gateway appgw-demo-gateway
kubectl describe gateway appgw-demo-gateway

# Check HTTPRoute
kubectl get httproute appgw-demo-route
kubectl describe httproute appgw-demo-route

# Check pods
kubectl get pods -l app=appgw-demo-app

# Check ALB Controller
kubectl get pods -n kube-system -l app=alb-controller
```

### View Logs

```bash
# Application logs
kubectl logs -l app=appgw-demo-app --tail=50 -f

# ALB Controller logs
kubectl logs -n kube-system -l app=alb-controller --tail=50 -f
```

## Advanced Features

### SSL/TLS Termination with Azure Key Vault

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  annotations:
    alb.networking.azure.io/alb-name: alb-controller
    alb.networking.azure.io/alb-namespace: kube-system
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
kubectl describe applicationloadbalancer -n kube-system alb-controller

# Check ALB Controller logs
kubectl logs -n kube-system -l app=alb-controller

# Verify subnet delegation
az network vnet subnet show \
  --resource-group rg-03-appgw-containers-demo \
  --vnet-name <vnet-name> \
  --name appgw-subnet \
  --query delegations
```

### Gateway Not Getting External IP

```bash
# Check Gateway status
kubectl describe gateway appgw-demo-gateway

# Check events
kubectl get events --sort-by='.lastTimestamp'

# Verify Gateway references correct ALB
kubectl get gateway appgw-demo-gateway -o yaml | grep alb
```

### HTTPRoute Not Working

```bash
# Check HTTPRoute status
kubectl describe httproute appgw-demo-route

# Verify backend service exists
kubectl get service appgw-demo-service

# Check service endpoints
kubectl get endpoints appgw-demo-service
```

## Comparison with Other Solutions

| Feature | NGINX Ingress | Gateway API (Envoy) | App Gateway for Containers |
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

## Clean Up

### Using the Cleanup Script

```bash
./scripts/cleanup.sh
```

### Manual Cleanup

```bash
# Delete the resource group (removes all resources)
az group delete \
  --name rg-03-appgw-containers-demo \
  --yes \
  --no-wait
```

## Cost Breakdown

Approximate monthly costs for the Sweden Central demos. Actual Azure pricing is region-dependent and may vary with usage:

| Resource | Cost |
|----------|------|
| AKS Cluster (2 nodes) | ~$140 |
| Application Gateway for Containers | ~$40 (base) + consumption |
| Azure Container Registry | ~$20 |
| Virtual Network | No charge |
| Public IP Address | ~$4 |
| Log Analytics | ~$5 |
| **Total** | **~$209/month** |

💡 AGC uses consumption-based pricing for traffic, so costs vary with usage.

## Resources

### Official Documentation
- [Application Gateway for Containers](https://learn.microsoft.com/azure/application-gateway/for-containers/)
- [AKS Application Routing](https://learn.microsoft.com/azure/aks/app-routing)
- [Gateway API on AKS](https://learn.microsoft.com/azure/aks/app-routing-gateway-api)
- [Web App Routing Add-on](https://learn.microsoft.com/azure/aks/web-app-routing)

### Guides and Tutorials
- [Quickstart: Deploy Application Gateway for Containers](https://learn.microsoft.com/azure/application-gateway/for-containers/quickstart-deploy-application-gateway-for-containers-alb-controller)
- [Gateway API Overview](https://gateway-api.sigs.k8s.io/)

## Next Steps

1. ✅ Deploy this demo to understand Azure Application Gateway for Containers
2. 🔬 Explore advanced features (SSL/TLS, WAF, header routing)
3. 📊 Compare performance and cost with other solutions
4. 🚀 Consider for your production workloads

---

**Demo Status**: ✅ Production-Ready, Azure-Native Solution  
**Last Updated**: 2026  
**Maintained by**: AKS Community Demos
