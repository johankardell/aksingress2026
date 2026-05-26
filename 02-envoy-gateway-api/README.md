# Gateway API with Envoy Demo

✅ **Modern, Kubernetes-native, vendor-neutral ingress solution**

## Overview

This demo deploys a simple .NET 10 web application to Azure Kubernetes Service (AKS) using the **Gateway API** with **Envoy Gateway** as the implementation. Gateway API is the modern, role-oriented successor to the Kubernetes Ingress API.

**Why Gateway API?**
- ✅ **Kubernetes Standard**: Official Kubernetes SIG project
- ✅ **Vendor Neutral**: Not tied to any specific implementation
- ✅ **Role-Oriented**: Separate concerns between infrastructure and application teams
- ✅ **Expressive**: Rich routing capabilities with typed fields
- ✅ **Portable**: Works across cloud providers and on-premises

**Why Envoy?**
- High-performance proxy built for cloud-native applications
- Production-proven (used by Lyft, Airbnb, and many others)
- Rich feature set (load balancing, observability, traffic management)
- Active CNCF project with strong community support

## Traffic Flow

```
┌──────────────────────────────────────────────────────────────────────────┐
│                                                                          │
│  Internet User                                                           │
│       │                                                                  │
│       │ HTTP Request                                                     │
│       ▼                                                                  │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  Azure Load Balancer (Public IP: x.x.x.x)                        │   │
│  │  - Type: LoadBalancer                                             │   │
│  │  - Provisioned by Gateway resource                                │   │
│  └────────────────────┬─────────────────────────────────────────────┘   │
│                       │                                                  │
│                       │ Forwards to Envoy Proxy Service                  │
│                       ▼                                                  │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │  AKS Cluster                                                       │  │
│  │                                                                    │  │
│  │  ┌─────────────────────────────────────────────────────────────┐  │  │
│  │  │  Namespace: envoy-gateway-system                             │  │  │
│  │  │                                                               │  │  │
│  │  │  ┌────────────────────────────────────────────────────────┐  │  │  │
│  │  │  │  GatewayClass: envoy-gateway                           │  │  │  │
│  │  │  │  - Controller: gateway.envoyproxy.io/gatewayclass-ctrl │  │  │  │
│  │  │  │  - Defines Envoy as the implementation                 │  │  │  │
│  │  │  └────────────────────────────────────────────────────────┘  │  │  │
│  │  │                                                               │  │  │
│  │  │  ┌────────────────────────────────────────────────────────┐  │  │  │
│  │  │  │  Envoy Gateway Controller (Deployment)                 │  │  │  │
│  │  │  │  - Watches Gateway & HTTPRoute resources               │  │  │  │
│  │  │  │  - Configures Envoy Proxy dynamically                  │  │  │  │
│  │  │  │  - Manages lifecycle of proxy pods                     │  │  │  │
│  │  │  └────────────────────────────────────────────────────────┘  │  │  │
│  │  │                                                               │  │  │
│  │  │  ┌────────────────────────────────────────────────────────┐  │  │  │
│  │  │  │  Envoy Proxy Pods (Deployment)                         │  │  │  │
│  │  │  │  - Created per Gateway resource                        │  │  │  │
│  │  │  │  - Handles actual traffic routing                      │  │  │  │
│  │  │  │  - Exposed via LoadBalancer Service                    │  │  │  │
│  │  │  └────────────────────┬─────────────────────────────────┘  │  │  │
│  │  └───────────────────────┼──────────────────────────────────────┘  │  │
│                              │                                          │  │
│                              │ Configured by Gateway resource           │  │
│                              │ Routes based on HTTPRoute                │  │
│                              ▼                                          │  │
│  │  ┌─────────────────────────────────────────────────────────────┐   │  │
│  │  │  Namespace: default                                          │   │  │
│  │  │                                                               │   │  │
│  │  │  ┌────────────────────────────────────────────────────────┐  │   │  │
│  │  │  │  Gateway: envoy-demo-gateway                           │  │   │  │
│  │  │  │  - GatewayClass: envoy-gateway                         │  │   │  │
│  │  │  │  - Listener: HTTP on port 80                           │  │   │  │
│  │  │  │  - Creates LoadBalancer Service + Envoy Proxy Pods     │  │   │  │
│  │  │  └────────────────────┬───────────────────────────────────┘  │   │  │
│  │  │                       │                                       │   │  │
│  │  │                       │ Referenced by                         │   │  │
│  │  │                       ▼                                       │   │  │
│  │  │  ┌────────────────────────────────────────────────────────┐  │   │  │
│  │  │  │  HTTPRoute: envoy-demo-route                           │  │   │  │
│  │  │  │  - ParentRef: envoy-demo-gateway                       │  │   │  │
│  │  │  │  - Match: Path "/"                                     │  │   │  │
│  │  │  │  - BackendRef: envoy-demo-service                      │  │   │  │
│  │  │  └────────────────────┬───────────────────────────────────┘  │   │  │
│  │  │                       │                                       │   │  │
│  │  │                       │ Routes to                             │   │  │
│  │  │                       ▼                                       │   │  │
│  │  │  ┌────────────────────────────────────────────────────────┐  │   │  │
│  │  │  │  Service: envoy-demo-service                           │  │   │  │
│  │  │  │  - Type: ClusterIP                                     │  │   │  │
│  │  │  │  - Port: 80 → TargetPort: 8080                         │  │   │  │
│  │  │  │  - Selector: app=envoy-demo-app                        │  │   │  │
│  │  │  └────────────────────┬───────────────────────────────────┘  │   │  │
│  │  │                       │                                       │   │  │
│  │  │                       │ Load balances to                      │   │  │
│  │  │                       ▼                                       │   │  │
│  │  │  ┌──────────────────────────────────────────────────────┐    │   │  │
│  │  │  │  Deployment: envoy-demo-app                          │    │   │  │
│  │  │  │  - Replicas: 2                                       │    │   │  │
│  │  │  │                                                       │    │   │  │
│  │  │  │  ┌─────────────────┐    ┌─────────────────┐         │    │   │  │
│  │  │  │  │  Pod 1          │    │  Pod 2          │         │    │   │  │
│  │  │  │  │  ┌───────────┐  │    │  ┌───────────┐  │         │    │   │  │
│  │  │  │  │  │ Container │  │    │  │ Container │  │         │    │   │  │
│  │  │  │  │  │ .NET App  │  │    │  │ .NET App  │  │         │    │   │  │
│  │  │  │  │  │ Port 8080 │  │    │  │ Port 8080 │  │         │    │   │  │
│  │  │  │  │  └───────────┘  │    │  └───────────┘  │         │    │   │  │
│  │  │  │  └─────────────────┘    └─────────────────┘         │    │   │  │
│  │  │  └──────────────────────────────────────────────────────┘    │   │  │
│  │  └───────────────────────────────────────────────────────────────┘   │  │
│  └────────────────────────────────────────────────────────────────────────┘
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘

Traffic Path Summary:
  1. User → Azure Load Balancer (Public IP)
  2. Load Balancer → Envoy Proxy Service (created by Gateway)
  3. Envoy Proxy → Reads Gateway + HTTPRoute configuration
  4. HTTPRoute → Defines routing rules to envoy-demo-service
  5. Service → Load balances to Pod (Port 8080)
  6. Pod → .NET Application responds

Key Differences from NGINX Ingress:
  • Gateway resource creates the LoadBalancer (not controller)
  • HTTPRoute defines routing (instead of Ingress resource)
  • Separation of concerns: Gateway (infra) vs HTTPRoute (app)
  • Envoy Proxy pods created per Gateway resource
```

## Architecture

```
┌───────────────────────────────────────────────────────────────┐
│                     Azure Cloud                               │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐│
│  │              AKS Cluster                                 ││
│  │                                                           ││
│  │  ┌────────────────────────────────────────────────────┐ ││
│  │  │  Envoy Gateway System (Namespace)                  │ ││
│  │  │  - GatewayClass: envoy-gateway                     │ ││
│  │  │  - Envoy Proxy Deployment                          │ ││
│  │  │  - Service: LoadBalancer (public IP)               │ ││
│  │  └────────────────────────────────────────────────────┘ ││
│  │                          │                               ││
│  │                          ▼                               ││
│  │  ┌────────────────────────────────────────────────────┐ ││
│  │  │  Default Namespace (Application Team)              │ ││
│  │  │                                                     │ ││
│  │  │  Gateway: envoy-demo-gateway                       │ ││
│  │  │      │                                              │ ││
│  │  │      ├──> HTTPRoute: envoy-demo-route              │ ││
│  │  │              │                                      │ ││
│  │  │              ├──> Service: envoy-demo-service      │ ││
│  │  │                      │                              │ ││
│  │  │                      └──> Deployment: envoy-demo-app││
│  │  │                              (2 replicas)           │ ││
│  │  └────────────────────────────────────────────────────┘ ││
│  └──────────────────────────────────────────────────────────┘│
│                          ▲                                    │
└──────────────────────────┼────────────────────────────────────┘
                           │
                    Internet Traffic
                    (via Public IP)
```

## Gateway API Concepts

### Role-Oriented Design

Gateway API separates concerns between different personas:

1. **Infrastructure Provider** (Platform Team)
   - Installs Envoy Gateway
   - Defines GatewayClass resources
   - Manages cluster-level policies

2. **Cluster Operator** (Platform Team)
   - Creates Gateway resources
   - Configures listeners (HTTP, HTTPS, TCP)
   - Manages infrastructure-level settings

3. **Application Developer** (Application Team)
   - Creates HTTPRoute resources
   - Defines routing rules
   - Manages application-level concerns

### Key Resources

#### GatewayClass
```yaml
kind: GatewayClass
name: envoy-gateway
```
Defines a class of Gateways (created by Envoy Gateway installation).

#### Gateway
```yaml
kind: Gateway
spec:
  gatewayClassName: envoy-gateway
  listeners:
  - name: http
    protocol: HTTP
    port: 80
```
Infrastructure-level resource that defines how traffic enters the cluster.

#### HTTPRoute
```yaml
kind: HTTPRoute
spec:
  parentRefs:
  - name: envoy-demo-gateway
  rules:
  - matches:
    - path: /
    backendRefs:
    - name: envoy-demo-service
```
Application-level resource that defines routing logic.

## Comparison: Gateway API vs. Ingress

| Aspect | Traditional Ingress | Gateway API |
|--------|-------------------|-------------|
| **Configuration** | Annotation-heavy | Strongly-typed fields |
| **Role Separation** | Single resource | Gateway + Routes |
| **Extensibility** | Vendor-specific annotations | Standardized extension points |
| **Route Types** | HTTP/HTTPS only | HTTP, HTTPS, TCP, UDP, TLS |
| **Advanced Routing** | Limited | Header matching, method matching, weights |
| **Multi-tenancy** | Difficult | Native support |
| **Status Reporting** | Limited | Rich status conditions |

## Prerequisites

- Azure CLI (`az`) version 2.50.0+
- kubectl version 1.27+
- Helm version 3.12+
- No local Docker installation required; images are built remotely with Azure Container Registry Tasks
- Active Azure subscription with permissions to create resources

## Deployment

### Option 1: Automated Deployment (Recommended)

```bash
# Run the deployment script
./scripts/deploy.sh
```

The script will:
1. Create Azure resource group
2. Deploy AKS cluster and ACR via Bicep
3. Build and push the container image with Azure Container Registry Tasks
4. Install Envoy Gateway via Helm
5. Deploy Gateway and HTTPRoute resources
6. Deploy the application
7. Display the public URL

**Estimated time**: 8-12 minutes

### Option 2: Manual Deployment

#### Step 1: Deploy Infrastructure

```bash
# Create resource group
az group create \
  --name rg-02-envoy-gateway-demo \
  --location swedencentral

# Deploy Bicep template
cd infrastructure
az deployment group create \
  --resource-group rg-02-envoy-gateway-demo \
  --name envoy-demo-deployment \
  --template-file main.bicep \
  --parameters main.bicepparam
```

#### Step 2: Get Credentials

```bash
# Get AKS cluster name
AKS_NAME=$(az deployment group show \
  --resource-group rg-02-envoy-gateway-demo \
  --name envoy-demo-deployment \
  --query properties.outputs.aksClusterName.value \
  --output tsv)

# Get credentials
az aks get-credentials \
  --resource-group rg-02-envoy-gateway-demo \
  --name $AKS_NAME \
  --overwrite-existing
```

#### Step 3: Build and Push Image with ACR Tasks

```bash
# Get ACR name
ACR_NAME=$(az deployment group show \
  --resource-group rg-02-envoy-gateway-demo \
  --name envoy-demo-deployment \
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

#### Step 4: Install Envoy Gateway

```bash
# Install using kubectl
kubectl apply --server-side --force-conflicts -f https://github.com/envoyproxy/gateway/releases/download/latest/install.yaml

# Wait for deployment
kubectl wait --for=condition=available --timeout=300s deployment/envoy-gateway -n envoy-gateway-system
```

#### Step 5: Verify GatewayClass

```bash
# Check that GatewayClass is available
kubectl get gatewayclass
```

You should see:
```
NAME             CONTROLLER                       AGE
envoy-gateway    gateway.envoyproxy.io/gatewayclass-controller   1m
```

#### Step 6: Deploy Application

```bash
cd ../02-envoy-gateway-api/kubernetes

# Get ACR login server
ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --query loginServer --output tsv)

# Deploy application
sed "s|\${ACR_LOGIN_SERVER}|${ACR_LOGIN_SERVER}|g" deployment.yaml | kubectl apply -f -
kubectl apply -f service.yaml
kubectl apply -f gateway.yaml
kubectl apply -f httproute.yaml
```

#### Step 7: Get External IP

```bash
# Wait for Gateway to get IP (may take 2-3 minutes)
kubectl get gateway envoy-demo-gateway --watch

# Once IP is assigned
EXTERNAL_IP=$(kubectl get gateway envoy-demo-gateway -o jsonpath='{.status.addresses[0].value}')
echo "Application URL: http://$EXTERNAL_IP"
```

## Testing

### Access the Application

```bash
# Get the external IP
EXTERNAL_IP=$(kubectl get gateway envoy-demo-gateway -o jsonpath='{.status.addresses[0].value}')

# Main page
curl http://$EXTERNAL_IP

# Health check
curl http://$EXTERNAL_IP/health

# API info
curl http://$EXTERNAL_IP/api/info
```

### Verify Gateway API Resources

```bash
# Check GatewayClass
kubectl get gatewayclass

# Check Gateway
kubectl get gateway envoy-demo-gateway
kubectl describe gateway envoy-demo-gateway

# Check HTTPRoute
kubectl get httproute envoy-demo-route
kubectl describe httproute envoy-demo-route

# Check pods
kubectl get pods -l app=envoy-demo-app

# Check service
kubectl get service envoy-demo-service
```

### View Logs

```bash
# Application logs
kubectl logs -l app=envoy-demo-app --tail=50 -f

# Envoy Gateway logs
kubectl logs -n envoy-gateway-system -l control-plane=envoy-gateway --tail=50 -f

# Envoy Proxy logs
kubectl logs -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=envoy-demo-gateway --tail=50 -f
```

## Advanced Gateway API Features

### Header-Based Routing

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
spec:
  rules:
  - matches:
    - headers:
      - name: version
        value: v2
    backendRefs:
    - name: app-v2-service
  - backendRefs:
    - name: app-v1-service
```

### Traffic Splitting (Canary Deployments)

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
spec:
  rules:
  - backendRefs:
    - name: app-v1-service
      port: 80
      weight: 90
    - name: app-v2-service
      port: 80
      weight: 10
```

### Path-Based Routing

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
spec:
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /api
    backendRefs:
    - name: api-service
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: frontend-service
```

## Troubleshooting

### Gateway Not Getting External IP

```bash
# Check Gateway status
kubectl describe gateway envoy-demo-gateway

# Check Envoy service
kubectl get svc -n envoy-gateway-system

# Check events
kubectl get events --sort-by='.lastTimestamp'
```

### HTTPRoute Not Working

```bash
# Check HTTPRoute status
kubectl describe httproute envoy-demo-route

# Verify parentRefs match Gateway name
kubectl get httproute envoy-demo-route -o yaml
```

### Application Not Responding

```bash
# Check pod status
kubectl get pods -l app=envoy-demo-app

# Check service endpoints
kubectl get endpoints envoy-demo-service

# Test service directly
kubectl run test-pod --rm -i --tty --image=curlimages/curl -- sh
curl http://envoy-demo-service/health
```

## Benefits Over NGINX Ingress

✅ **Vendor Neutrality**: Switch implementations without changing routes  
✅ **Better Separation**: Infrastructure and app teams work independently  
✅ **Type Safety**: No more annotation typos  
✅ **Advanced Routing**: Headers, methods, weights built-in  
✅ **Future-Proof**: Active development and community support  
✅ **Multi-Tenancy**: Native namespace isolation  

## Migration from Ingress

If migrating from traditional Ingress:

```yaml
# Old: Ingress
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - http:
      paths:
      - path: /
        backend:
          service:
            name: my-service
            port: 80
```

Becomes:

```yaml
# New: Gateway + HTTPRoute
---
kind: Gateway
spec:
  gatewayClassName: envoy-gateway
  listeners:
  - name: http
    port: 80
    protocol: HTTP
---
kind: HTTPRoute
spec:
  parentRefs:
  - name: my-gateway
  rules:
  - matches:
    - path:
        value: /
    backendRefs:
    - name: my-service
      port: 80
```

## Clean Up

### Using the Cleanup Script

```bash
./scripts/cleanup.sh
```

### Manual Cleanup

```bash
# Delete the resource group (removes all resources)
az group delete \
  --name rg-02-envoy-gateway-demo \
  --yes \
  --no-wait
```

## Cost Breakdown

Approximate monthly costs for the Sweden Central demos. Actual Azure pricing is region-dependent and may vary with usage:

| Resource | Cost |
|----------|------|
| AKS Cluster (2 nodes) | ~$140 |
| Azure Container Registry | ~$20 |
| Load Balancer | ~$20 |
| Public IP Address | ~$4 |
| Log Analytics | ~$5 |
| **Total** | **~$189/month** |

💡 Remember to delete resources when not in use.

## Resources

### Official Documentation
- [Gateway API](https://gateway-api.sigs.k8s.io/)
- [Envoy Gateway](https://gateway.envoyproxy.io/)
- [Envoy Proxy](https://www.envoyproxy.io/)
- [AKS Application Routing](https://learn.microsoft.com/azure/aks/app-routing)

### Guides
- [Gateway API Getting Started](https://gateway-api.sigs.k8s.io/guides/)
- [Migrating from Ingress](https://gateway-api.sigs.k8s.io/guides/migrating-from-ingress/)
- [Envoy Gateway Tasks](https://gateway.envoyproxy.io/latest/tasks/)

## Next Steps

1. ✅ Deploy this demo to understand Gateway API
2. 🔬 Experiment with advanced routing features
3. 🚀 Compare with [Azure Application Gateway for Containers](../03-appgw-for-containers/)
4. 📚 Evaluate for your production workloads

---

**Demo Status**: ✅ Production-Ready Technology  
**Last Updated**: 2026  
**Maintained by**: AKS Community Demos
