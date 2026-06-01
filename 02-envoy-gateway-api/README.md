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

[📊 Mermaid diagram](./architecture.mermaid.md) | [✏️ Draw.io diagram](./architecture.drawio)

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
│  │  │  Namespace: demo                                          │   │  │
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
- No local Docker installation required; the shared image is built remotely with Azure Container Registry Tasks
- Active Azure subscription with permissions to create resources

## Deployment

### Option 1: Automated Deployment (Recommended)

```bash
# Run the deployment script
./scripts/deploy.sh
```

The script runs the three focused deployment phases in sequence:
1. `./scripts/deploy-infra.sh` creates/registers Azure resources, deploys AKS via Bicep, enables managed Prometheus, creates/reuses the shared ACR, Azure Monitor workspace, and Grafana in `rg-aksdemo-shared`, and grants AKS pull access. This phase does not use `kubectl` and can be run in parallel with other demos.
2. `./scripts/build-image.sh` builds the shared sample app image with Azure Container Registry Tasks only if the source-content tag is missing.
3. `./scripts/configure-kubernetes.sh` gets AKS credentials, installs Envoy Gateway, deploys Gateway/HTTPRoute/application resources, and displays the public URL. This is the only phase that changes or relies on the active `kubectl` context.

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
  --name rg-02-envoy-gateway-demo \
  --location swedencentral

# Deploy Bicep template and reference the shared ACR
cd infrastructure
source ../../shared/scripts/acr-image.sh
ACR_NAME=$(ensure_shared_acr)
USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)
az deployment group create \
  --resource-group rg-02-envoy-gateway-demo \
  --name envoy-demo-deployment \
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

#### Step 3: Build Shared Image with ACR Tasks

```bash
# Get shared ACR name
ACR_NAME=$(az deployment group show \
  --resource-group rg-02-envoy-gateway-demo \
  --name envoy-demo-deployment \
  --query properties.outputs.acrName.value \
  --output tsv)

# Build remotely only if the source-content tag is missing
source ../../shared/scripts/acr-image.sh
ensure_sample_app_image "$ACR_NAME" "../../shared/sample-app" "aks-ingress-demo"
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

#### Step 7: Get External IP

```bash
# Wait for Gateway to get IP (may take 2-3 minutes)
kubectl get gateway envoy-demo-gateway -n demo --watch

# Once IP is assigned
EXTERNAL_IP=$(kubectl get gateway envoy-demo-gateway -n demo -o jsonpath='{.status.addresses[0].value}')
echo "Application URL: http://$EXTERNAL_IP"
```

## Testing

### Access the Application

```bash
# Get the external IP
EXTERNAL_IP=$(kubectl get gateway envoy-demo-gateway -n demo -o jsonpath='{.status.addresses[0].value}')

# Main page
curl http://$EXTERNAL_IP

# Health check
curl http://$EXTERNAL_IP/health

# API info
curl http://$EXTERNAL_IP/api/info
```

### Verify Gateway API Resources

```bash
# Check all demo application resources
kubectl get all -n demo

# Check GatewayClass
kubectl get gatewayclass

# Check Gateway
kubectl get gateway envoy-demo-gateway -n demo
kubectl describe gateway envoy-demo-gateway -n demo

# Check HTTPRoute
kubectl get httproute envoy-demo-route -n demo
kubectl describe httproute envoy-demo-route -n demo

# Check pods
kubectl get pods -n demo -l app=envoy-demo-app

# Check service
kubectl get service envoy-demo-service -n demo
```

### View Logs

```bash
# Application logs
kubectl logs -n demo -l app=envoy-demo-app --tail=50 -f

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
kubectl describe gateway envoy-demo-gateway -n demo

# Check Envoy service
kubectl get svc -n envoy-gateway-system

# Check events
kubectl get events -n demo --sort-by='.lastTimestamp'
```

### HTTPRoute Not Working

```bash
# Check HTTPRoute status
kubectl describe httproute envoy-demo-route -n demo

# Verify parentRefs match Gateway name
kubectl get httproute envoy-demo-route -n demo -o yaml
```

### Application Not Responding

```bash
# Check pod status
kubectl get pods -n demo -l app=envoy-demo-app

# Check service endpoints
kubectl get endpoints envoy-demo-service -n demo

# Test service directly
kubectl run test-pod -n demo --rm -i --tty --image=curlimages/curl -- sh
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

Gateway API splits the single Ingress resource into role-oriented resources. The
shared sample app uses the same Deployment and Service shape in both demos; only
the north-south routing resources change.

### Concept mapping

| Ingress API | Gateway API | Notes |
|-------------|-------------|-------|
| `IngressClass` | `GatewayClass` | Cluster-scoped implementation choice. `nginx` becomes `envoy-gateway` in this demo. |
| `Ingress.spec.ingressClassName` | `Gateway.spec.gatewayClassName` | The Gateway selects the implementation; routes attach to that Gateway. |
| `Ingress` listener details | `Gateway` | Hosts, ports, protocols, TLS, and allowed route namespaces move to Gateway listeners. |
| `Ingress.spec.rules[].http.paths[]` | `HTTPRoute.spec.rules[].matches[]` and `backendRefs[]` | Application teams express path routing in HTTPRoute. |
| Ingress annotations | Typed Gateway API fields, filters, or implementation-specific policies | Common routing behavior has typed fields; controller-specific features may need Envoy Gateway policy CRDs or may not have a 1:1 equivalent. |

### Class selection

<table>
<tr>
<th>IngressClass</th>
<th>GatewayClass + Gateway selection</th>
</tr>
<tr>
<td>
<pre><code class="language-yaml">apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: nginx
spec:
  controller: k8s.io/ingress-nginx
---
apiVersion: networking.k8s.io/v1
kind: Ingress
spec:
  ingressClassName: nginx
</code></pre>
</td>
<td>
<pre><code class="language-yaml">apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: envoy-gateway
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
spec:
  gatewayClassName: envoy-gateway
</code></pre>
</td>
</tr>
</table>

### Basic shared sample app route

<table>
<tr>
<th>Ingress</th>
<th>Gateway API</th>
</tr>
<tr>
<td>
<pre><code class="language-yaml">apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-demo-ingress
  namespace: demo
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx-demo-service
            port:
              number: 80
</code></pre>
</td>
<td>
<pre><code class="language-yaml">apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: envoy-demo-gateway
  namespace: demo
spec:
  gatewayClassName: envoy-gateway
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    allowedRoutes:
      namespaces:
        from: Same
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: envoy-demo-route
  namespace: demo
spec:
  parentRefs:
  - name: envoy-demo-gateway
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: envoy-demo-service
      port: 80
</code></pre>
</td>
</tr>
</table>

### Equivalent path routing examples

<table>
<tr>
<th>Ingress paths</th>
<th>HTTPRoute rules</th>
</tr>
<tr>
<td>
<pre><code class="language-yaml">rules:
- host: demo.example.com
  http:
    paths:
    - path: /
      pathType: Prefix
      backend:
        service:
          name: web
          port:
            number: 80
    - path: /api
      pathType: Prefix
      backend:
        service:
          name: api
          port:
            number: 80
    - path: /health
      pathType: Exact
      backend:
        service:
          name: web
          port:
            number: 80
</code></pre>
</td>
<td>
<pre><code class="language-yaml">hostnames:
- demo.example.com
rules:
- matches:
  - path:
      type: PathPrefix
      value: /api
  backendRefs:
  - name: api
    port: 80
- matches:
  - path:
      type: Exact
      value: /health
  backendRefs:
  - name: web
    port: 80
- matches:
  - path:
      type: PathPrefix
      value: /
  backendRefs:
  - name: web
    port: 80
</code></pre>
</td>
</tr>
</table>

Gateway API path matches are explicit (`PathPrefix`, `Exact`, or
`RegularExpression` when supported). Model specific matches explicitly and verify
route precedence when migrating an Ingress.

### Annotation translation notes

| NGINX Ingress annotation | Gateway API migration guidance |
|--------------------------|--------------------------------|
| `nginx.ingress.kubernetes.io/rewrite-target` | Use an `HTTPRoute` `URLRewrite` filter when the Gateway implementation supports it. The sample app does not require a rewrite for `/`, `/health`, or `/api/info`. |
| `nginx.ingress.kubernetes.io/ssl-redirect` | No direct annotation equivalent. Configure HTTPS listeners and, when needed, an HTTP-to-HTTPS redirect with an `HTTPRoute` `RequestRedirect` filter. |
| `nginx.ingress.kubernetes.io/backend-protocol` | Usually becomes typed backend configuration or implementation policy. Plain HTTP backends like this sample app only need `backendRefs[].port`. |
| `cert-manager.io/*` | Certificate automation remains outside core Gateway API. Use cert-manager Gateway support or your platform certificate workflow. |
| Controller tuning annotations such as timeouts, buffers, and WAF | These do not translate cleanly to core Gateway API. Check Envoy Gateway policy CRDs or move Azure-specific edge controls to Application Gateway for Containers. |

### Migration exercise

1. Deploy the NGINX demo and confirm the shared sample app responds at `/`,
   `/health`, and `/api/info`.
2. Open `../01-nginx-ingress/kubernetes/ingress.yaml` and identify the
   `ingressClassName`, annotations, path match, backend Service name, and port.
3. In this demo, compare those fields with `kubernetes/gateway.yaml` and
   `kubernetes/httproute.yaml`. Notice that the class and listener move to the
   Gateway, while the path match and backend move to the HTTPRoute.
4. Apply the Gateway API resources and retest the same paths against the Gateway
   public address:

   ```bash
   kubectl apply -f kubernetes/gateway.yaml
   kubectl apply -f kubernetes/httproute.yaml
   kubectl get gateway -n demo envoy-demo-gateway
   kubectl get httproute -n demo envoy-demo-route
   ```

5. Optional: add an `/api` `PathPrefix` route to `httproute.yaml` that points to
   the same sample app Service, apply it, and verify `/api/info` still returns
   the sample app metadata.

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
  --name rg-02-envoy-gateway-demo \
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
| Shared Azure Managed Grafana / managed Prometheus ingestion | Usage-based |
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
3. 🚀 Compare with [Azure AGC](../03-agc-for-containers/)
4. 📚 Evaluate for your production workloads

---

**Demo Status**: ✅ Production-Ready Technology  
**Last Updated**: 2026  
**Maintained by**: AKS Community Demos
