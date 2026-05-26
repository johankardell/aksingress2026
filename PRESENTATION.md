# Major Changes in AKS (Level 400)

> Source markdown for the slide deck. Each `---` separates a slide.
> Sections labeled **Speaker notes** become the speaker notes pane in PowerPoint.
> Sections labeled **➡ Move to speaker notes (script)** contain Azure CLI / kubectl that should NOT be on the visible slide — paste them into the speaker-notes pane when authoring the deck.

---

## Slide 1 — Title

# Major Changes in AKS
### Service Mesh, Ingress, Gateway API, and GitOps in 2026
Level 400 — deep dive

**Speaker notes:**
We will cover four shifts that change how we build platforms on AKS this year:
1. Istio: sidecar → ambient mode (now generally available in the AKS-managed Istio add-on).
2. Ingress → Gateway API (the new standard, role-oriented, vendor-neutral).
3. Application Gateway for Containers (AGC) — the Azure-native Gateway API implementation, successor to AGIC.
4. Managed Argo CD on AKS — a first-class GitOps option next to managed Flux.
Audience is expected to know AKS basics, kubectl, Helm and CRDs.

---

## Slide 2 — Agenda

1. Istio: from sidecar to ambient
2. Where (and where not) to use a service mesh
3. Pod-to-pod traffic across nodes in ambient mode
4. Ingress → Gateway API
5. Gateway API on AKS with Envoy Gateway
6. Application Gateway for Containers (AGC) + Gateway API
7. Legacy: community ingress-nginx on AKS (retirement reference)
8. Managed Argo CD on AKS (vs Flux)
9. Q&A

---

# Part 1 — Service Mesh: Sidecar → Ambient

---

## Slide 3 — Why a service mesh at all?

**What a mesh actually gives you**
- mTLS everywhere, identity-based (SPIFFE) — zero-trust between workloads
- L7 traffic control: retries, timeouts, circuit breaking, traffic splitting
- Uniform telemetry: golden signals per service without app code
- Policy: authZ between services, rate limiting, header rewrites

**When it makes sense**
- > ~10 services or multiple teams sharing a cluster
- Regulated workloads (PCI/HIPAA) needing encryption-in-transit & audit
- Progressive delivery: canary, blue/green, A/B by header
- Multi-cluster / multi-tenant platforms

**When it does NOT make sense**
- 2–3 microservices behind a single ingress — overkill
- Hard real-time / ultra-low-latency hot paths (extra hop matters)
- Small team without platform capacity to operate it
- If you only need mTLS at the edge → a Gateway can be enough

**Speaker notes:**
The honest answer: most teams discover they want *parts* of a mesh (mTLS, retries, observability) before they want all of it. Ambient mode finally lets you adopt those parts incrementally without committing every pod to a sidecar. Use this slide to set expectations: a mesh is a platform investment, not a free feature.

---

## Slide 4 — Sidecar mode (the old way)

```
                ┌─────────────── Pod A ───────────────┐
   inbound ───▶ │  envoy (sidecar) ──▶ app container  │
                └─────────────────────────────────────┘
                          │ mTLS
                          ▼
                ┌─────────────── Pod B ───────────────┐
                │  app container ◀── envoy (sidecar)  │
                └─────────────────────────────────────┘
```
- Every pod gets an Envoy injected
- Pros: full L7 features per pod, mature
- Cons: 2× container count, +100–200 MB RAM per pod, restart on Istio upgrade, lifecycle coupling with the app

**Speaker notes:**
Sidecars worked, but the cost model scales linearly with pod count, not with the actual traffic you want governed. Every Java pod paid the Envoy tax even if it only talked to one other service. Upgrading Istio meant restarting every app pod. That is what ambient mode fixes.

---

## Slide 5 — Ambient mode (the new way)

```
   ┌──────────────────────────  Node 1  ──────────────────────────┐
   │                                                              │
   │   Pod A (app, no sidecar)        Pod B (app, no sidecar)     │
   │        │                              │                      │
   │        └─────────► ztunnel  ◀─────────┘   (per-node DaemonSet)│
   │                       │                                      │
   └───────────────────────┼──────────────────────────────────────┘
                           │ HBONE (mTLS, TCP, port 15008)
   ┌───────────────────────┼──────────────────────────────────────┐
   │                       ▼                                      │
   │                    ztunnel        Pod C (app, no sidecar)    │
   │                       │                ▲                     │
   │                       └────────────────┘                     │
   │                                                              │
   │            (L7 needed?) ──► Waypoint Proxy (Envoy, per-ns)   │
   └────────────────────────────  Node 2  ────────────────────────┘
```

**Two layers, opt-in:**
- **Secure overlay (L4):** `ztunnel` DaemonSet — mTLS + identity + L4 authZ for *every* pod. Cheap.
- **L7 (optional):** `waypoint` Envoy deployment per namespace/service-account — adds retries, traffic splitting, L7 authZ *only where you ask*.

**Wins**
- No sidecar injection, no pod restarts on mesh upgrade
- ~ order-of-magnitude lower memory overhead in mostly-L4 fleets
- Incremental adoption: label a namespace, done

**Trade-offs**
- Newer code path; some advanced sidecar features still landing
- Node-level component → node draining matters during ztunnel upgrade
- Debugging spans an extra hop (ztunnel logs become important)

**Speaker notes:**
The big idea: separate the security plane (always-on, cheap, L4 + mTLS) from the policy plane (L7, on-demand). Most pods only ever needed mTLS and identity. They now get that from ztunnel without an injected container. Only pods that actually need L7 features route through a waypoint Envoy, and that waypoint is shared per namespace/identity instead of one-per-pod.

---

## Slide 6 — Pod-to-pod traffic across nodes (ambient)

```
  Pod A on Node 1 wants to call svc:Pod C on Node 2
  ─────────────────────────────────────────────────

  1. Pod A sends plain TCP to Pod C's ClusterIP
        │
        ▼
  2. Node 1 kernel: iptables/eBPF redirect ──► ztunnel (Node 1)
        │            (transparent, no app change)
        ▼
  3. ztunnel-1 looks up identity (SPIFFE) + policy
        │
        ▼
  4. ztunnel-1 wraps the TCP stream in HBONE
        (HTTP/2 CONNECT over mTLS, port 15008)
        │
        ▼  ── encrypted, identity-tagged ──
  5. ztunnel-2 on Node 2 terminates HBONE, verifies peer cert
        │
        ▼
  6. If namespace has a Waypoint → ztunnel-2 forwards to Waypoint Envoy
     for L7 policy (retries, route, authZ on headers), else direct
        │
        ▼
  7. Plain TCP delivered to Pod C
```

**Key points**
- Encryption boundary: pod ↔ ztunnel is loopback on the node (kernel redirect); ztunnel ↔ ztunnel is mTLS over HBONE.
- Identity is the pod's ServiceAccount, issued as a SPIFFE SVID by istiod.
- Waypoints are only inserted when an `istio.io/use-waypoint` label / `Gateway` of class `istio-waypoint` exists.

**Speaker notes:**
Walk through the seven steps live. Emphasize that the app sends *plain* TCP — no client library, no port change. The node's CNI/redirect (eBPF on AKS with Cilium dataplane, iptables otherwise) hands the packet to ztunnel. HBONE is the tunnel protocol: HTTP/2 CONNECT carrying the original TCP, secured by mTLS using SPIFFE identities. The waypoint is *optional and per-namespace*, which is why ambient is cheaper than sidecars.

---

## Slide 7 — Enabling ambient Istio on AKS

**➡ Move to speaker notes (script):**

```bash
# Variables
RG=rg-mesh-demo
LOC=swedencentral
AKS=aks-mesh-demo

# 1. Create resource group + AKS (Free tier, K8s 1.34.7, Sweden Central)
az group create -n $RG -l $LOC

az aks create \
  -g $RG -n $AKS \
  --location $LOC \
  --kubernetes-version 1.34.7 \
  --tier free \
  --node-vm-size Standard_B4as_v2 \
  --node-count 3 \
  --network-plugin azure \
  --network-dataplane cilium \
  --network-policy cilium \
  --enable-oidc-issuer \
  --enable-workload-identity \
  --generate-ssh-keys

az aks get-credentials -g $RG -n $AKS

# 2. Enable the AKS-managed Istio add-on (ambient profile)
az aks mesh enable \
  -g $RG -n $AKS \
  --revision asm-1-24

# 3. Switch the add-on to ambient profile (AKS exposes via mesh profile)
az aks mesh upgrade complete -g $RG -n $AKS

# 4. Opt a namespace into ambient (no sidecar injection!)
kubectl label namespace demo istio.io/dataplane-mode=ambient

# 5. (Optional) Add a Waypoint for L7 policy on a namespace
kubectl apply -n demo -f - <<'YAML'
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: waypoint
  labels:
    istio.io/waypoint-for: service
spec:
  gatewayClassName: istio-waypoint
  listeners:
  - name: mesh
    port: 15008
    protocol: HBONE
YAML
```

**Speaker notes:**
On AKS, ambient is delivered through the managed Istio add-on. You don't run istiod yourself; AKS does. You opt namespaces in with a label. Waypoints are deployed as standard Gateway API `Gateway` objects — that is a nice preview of part 2 of the talk.

---

# Part 2 — Ingress → Gateway API

---

## Slide 8 — What is Ingress?

**Ingress is how external HTTP/HTTPS traffic gets into a Kubernetes cluster.**

It's made up of a few cooperating pieces:

| Term | What it is |
|---|---|
| **Ingress (resource)** | Kubernetes API object describing host/path routing rules — pure configuration |
| **Ingress Controller** | The software (pods) that watches Ingress resources and configures a proxy |
| **IngressClass** | Tells Kubernetes which controller should handle a given Ingress |
| **Backend Service** | The `Service` the Ingress routes traffic to |
| **TLS Secret** | `kubernetes.io/tls` secret used for HTTPS termination |

The controller has two roles: a **control plane** (reconciles K8s resources into proxy config) and a **data plane** (the actual proxy — NGINX, Envoy, HAProxy — that receives traffic). In most implementations both run in the same pod.

**Full traffic path**

```
Client
  ↓
DNS → Public IP
  ↓
Cloud Load Balancer (from the controller's Service of type LoadBalancer)
  ↓
Ingress Controller pod (proxy / data plane)  ← traffic actually arrives here
  ↓
Backend Service (ClusterIP) → Pod Endpoints
  ↓
Application Pod
```

**Speaker notes:**
Before we talk about *why* Ingress isn't enough anymore, let's make sure everyone has the same mental model. An `Ingress` object is just YAML — it does nothing on its own. The Ingress Controller is what brings it to life: it watches the API server and programs a reverse proxy (NGINX, Envoy, …) that actually handles the requests. Externally, a cloud load balancer fronts the controller's pods. Some implementations (like Application Gateway for Containers) push the data plane *outside* the cluster, but the conceptual model is the same: a controller reconciles intent, a proxy carries traffic.

---

## Slide 9 — Why Ingress alone is no longer enough

**Important distinction**
- Kubernetes `Ingress` API is stable, not deprecated
- The community `kubernetes/ingress-nginx` controller is the retired/EOL component
- Gateway API is the recommended direction for new, richer traffic-management designs

**Limitations of `Ingress` as an API model**
- Annotation soup: every controller invented its own annotations → not portable
- Single role: cluster admin and app dev edit the same object
- No first-class TCP/UDP, gRPC, traffic splitting, header-based routing
- Extension story = vendor lock-in

**Gateway API fixes the model**
| Concern | Resource | Persona |
|---|---|---|
| What controller / data plane | `GatewayClass` | Infra provider |
| Listeners, IP, TLS certs | `Gateway` | Cluster operator |
| Routes, hosts, paths, splits | `HTTPRoute` / `GRPCRoute` / `TCPRoute` | App developer |

- Status is structured (`conditions`) — observability built-in
- Same spec across NGINX, Envoy, Cilium, Azure AGC, GKE, AWS — workload portability

**Speaker notes:**
Be precise here: the Kubernetes `Ingress` API is stable and existing workloads can keep using it. The retirement concern is specifically the community `kubernetes/ingress-nginx` controller implementation, not the core API. Gateway API is to Ingress what `Deployment` was to `ReplicationController`: same intent, much better data model and extension points. The key word is *role-oriented*: a platform team owns the `Gateway`, dev teams own `HTTPRoute`s and attach to it via `parentRefs`. That alone removes 80% of the annotation collisions we used to have.

---

## Slide 10 — Ingress vs Gateway API side-by-side

```
   ┌─── Ingress (one resource, one persona) ───┐
   │                                            │
   │   Ingress  ──► IngressController           │
   │   (annotations control everything)         │
   └────────────────────────────────────────────┘

   ┌─── Gateway API (separation of concerns) ───────────────────┐
   │                                                            │
   │   GatewayClass  ◄── installed by infra (controller)        │
   │       ▲                                                    │
   │       │ referenced by                                      │
   │   Gateway      ◄── owned by platform team (listeners,TLS)  │
   │       ▲                                                    │
   │       │ parentRefs                                         │
   │   HTTPRoute    ◄── owned by app team (rules, backends)     │
   │       │                                                    │
   │       ▼                                                    │
   │   Service / Pod                                            │
   └────────────────────────────────────────────────────────────┘
```

**Speaker notes:**
Show the contrast. With Ingress, the app developer files a PR that touches a cluster-scoped resource with annotations the platform team has to review. With Gateway API, the platform team publishes one `Gateway` with hostnames/cert/IP; dev teams ship `HTTPRoute` objects in their own namespace and attach to that Gateway. The `ReferenceGrant` resource controls cross-namespace attachment. RBAC finally lines up with how teams actually work.

---

## Slide 11 — Gateway API with Envoy Gateway on AKS

```
   ┌──────────────────────  AKS Cluster  ─────────────────────┐
   │                                                          │
   │  envoy-gateway (control plane, Deployment)               │
   │      │  watches GatewayClass=envoy + Gateway + HTTPRoute │
   │      ▼  programs                                          │
   │  Envoy data plane Pods (one Deployment per Gateway)       │
   │      ▲                                                    │
   │      │ Service type=LoadBalancer                          │
   │      │                                                    │
   └──────┼────────────────────────────────────────────────────┘
          │
          ▼
   Azure Standard Load Balancer  ◀─── public IP, your DNS A record
          │
          ▼
        Client
```

- 100% open source, Envoy data plane, runs anywhere
- L7: HTTP, gRPC, WebSocket; L4 via TCPRoute
- Filters: rate limit, JWT auth, transformations, OIDC

**➡ Move to speaker notes (script):**

```bash
# Install Envoy Gateway (CRDs + controller)
helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.3.0 \
  -n envoy-gateway-system --create-namespace

kubectl apply -f - <<'YAML'
---
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata: { name: envoy }
spec:   { controllerName: gateway.envoyproxy.io/gatewayclass-controller }
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: { name: public, namespace: edge }
spec:
  gatewayClassName: envoy
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces: { from: All }
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: { name: app, namespace: demo }
spec:
  parentRefs:
  - { name: public, namespace: edge }
  hostnames: [ "app.contoso.com" ]
  rules:
  - matches: [ { path: { type: PathPrefix, value: / } } ]
    backendRefs:
    - { name: sample-app, port: 80 }
YAML
```

**Speaker notes:**
Envoy Gateway is the upstream-reference implementation. The controller watches GatewayClass/Gateway/HTTPRoute and renders an Envoy Deployment + Service per Gateway. On AKS, the Service of type LoadBalancer triggers an Azure SLB and a public IP — same model you already use, but the routing is now portable Gateway API YAML rather than NGINX annotations.

---

## Slide 12 — Application Gateway for Containers (AGC)

**What it is**
- Azure-managed L7 load balancer, evolution of Application Gateway
- Native Gateway API implementation (the ALB Controller installs `GatewayClass: azure-alb-external`)
- Replaces AGIC (Ingress-based) for new workloads
- WAF, mTLS to backends, HTTP/2 + gRPC, path/header routing, weighted splits

**How it "jacks into" the cluster**

```
                ┌─────────────────────────────────────────────┐
                │           Azure subscription                │
                │                                             │
   Client ─────▶│  Application Gateway for Containers (PaaS)  │
                │   (frontend IP, listeners, WAF)             │
                │            │                                │
                │            │ associated via Association     │
                │            ▼                                │
                │   Delegated subnet (AGC frontend)           │
                └────────────┼────────────────────────────────┘
                             │  data plane connects to pod IPs
                             ▼   (Azure CNI pod IP, no kube-proxy hop)
                ┌────────────────────────────────────────────┐
                │  AKS cluster (VNet-integrated)             │
                │                                            │
                │  alb-controller (Deployment) ──┐           │
                │     ▲ watches Gateway/Route    │ uses      │
                │     │                          ▼  workload │
                │  Gateway (gatewayClassName:    │  identity │
                │      azure-alb-external) ──────┘           │
                │  HTTPRoute → Service → Pod                 │
                └────────────────────────────────────────────┘
```

**Traffic flow**
1. Client hits AGC public/private frontend IP.
2. AGC terminates TLS, applies WAF + listener rules.
3. AGC's data plane sends the request *directly to the backend pod IP* over the cluster's Azure CNI subnet (no NodePort, no kube-proxy).
4. ALB Controller in the cluster keeps AGC's backend pool in sync with `HTTPRoute` + `EndpointSlice` changes via ARM.
5. Response returns through AGC to the client.

**Speaker notes:**
The shape to remember: AGC is a *PaaS L7 LB* that lives in your VNet via a delegated subnet, and it talks to pod IPs directly because AKS uses Azure CNI. The in-cluster ALB Controller is just the bridge that translates Gateway API objects into ARM calls. There's no in-cluster proxy hop, which is the latency win over Envoy/NGINX-in-cluster designs.

---

## Slide 13 — Deploying AGC with Gateway API

**➡ Move to speaker notes (script):**

```bash
RG=rg-agc-demo
LOC=swedencentral
AKS=aks-agc-demo
VNET=vnet-agc
SUBNET_NODE=snet-nodes
SUBNET_ALB=snet-alb

# 1. Networking
az group create -n $RG -l $LOC
az network vnet create -g $RG -n $VNET --address-prefixes 10.20.0.0/16 \
  --subnet-name $SUBNET_NODE --subnet-prefixes 10.20.0.0/22
az network vnet subnet create -g $RG --vnet-name $VNET -n $SUBNET_ALB \
  --address-prefixes 10.20.4.0/24 \
  --delegations Microsoft.ServiceNetworking/trafficControllers

SUBNET_NODE_ID=$(az network vnet subnet show -g $RG --vnet-name $VNET -n $SUBNET_NODE --query id -o tsv)
SUBNET_ALB_ID=$(az network vnet subnet show  -g $RG --vnet-name $VNET -n $SUBNET_ALB  --query id -o tsv)

# 2. AKS with workload identity + Azure CNI
az aks create -g $RG -n $AKS -l $LOC \
  --kubernetes-version 1.34.7 \
  --tier free \
  --node-vm-size Standard_B4as_v2 \
  --node-count 3 \
  --network-plugin azure --network-dataplane cilium \
  --vnet-subnet-id $SUBNET_NODE_ID \
  --enable-oidc-issuer --enable-workload-identity \
  --generate-ssh-keys
az aks get-credentials -g $RG -n $AKS

# 3. Managed identity + federated credential for the ALB Controller
IDENTITY=mi-alb
az identity create -g $RG -n $IDENTITY -l $LOC
PRINCIPAL=$(az identity show -g $RG -n $IDENTITY --query principalId -o tsv)
CLIENT=$(az identity show   -g $RG -n $IDENTITY --query clientId    -o tsv)

# Allow ALB Controller to manage AGC
az role assignment create --assignee-object-id $PRINCIPAL --assignee-principal-type ServicePrincipal \
  --role "AppGw for Containers Configuration Manager" \
  --scope $(az group show -g $RG --query id -o tsv)
az role assignment create --assignee-object-id $PRINCIPAL --assignee-principal-type ServicePrincipal \
  --role "Network Contributor" --scope $SUBNET_ALB_ID

ISSUER=$(az aks show -g $RG -n $AKS --query oidcIssuerProfile.issuerUrl -o tsv)
az identity federated-credential create -g $RG --identity-name $IDENTITY \
  --name fedcred --issuer "$ISSUER" \
  --subject "system:serviceaccount:azure-alb-system:alb-controller-sa" \
  --audiences api://AzureADTokenExchange

# 4. Install the ALB Controller
helm install alb-controller oci://mcr.microsoft.com/application-lb/charts/alb-controller \
  --version 1.0.0 \
  -n azure-alb-system --create-namespace \
  --set albController.podIdentity.clientID=$CLIENT

# 5. Create the AGC resource and Association (delegated subnet)
az network alb create -g $RG -n agc-demo
az network alb frontend create -g $RG --alb-name agc-demo -n fe-public
az network alb association create -g $RG --alb-name agc-demo -n assoc \
  --subnet $SUBNET_ALB_ID

# 6. Gateway + HTTPRoute (managed by ALB Controller)
kubectl apply -f - <<'YAML'
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: agc-gw
  namespace: edge
  annotations:
    alb.networking.azure.io/alb-namespace: azure-alb-system
    alb.networking.azure.io/alb-name: agc-demo
spec:
  gatewayClassName: azure-alb-external
  listeners:
  - { name: http, port: 80, protocol: HTTP, allowedRoutes: { namespaces: { from: All } } }
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: { name: app, namespace: demo }
spec:
  parentRefs: [ { name: agc-gw, namespace: edge } ]
  hostnames: [ "app.contoso.com" ]
  rules:
  - matches: [ { path: { type: PathPrefix, value: / } } ]
    backendRefs: [ { name: sample-app, port: 80 } ]
YAML
```

**Speaker notes:**
Pay attention to two things: (1) the `Association` resource ties AGC to the delegated subnet — that's how the PaaS LB gets a foothold inside *your* VNet; (2) the ALB Controller uses Workload Identity (federated credential on its ServiceAccount) — no secrets, no service principals. This is the AKS-recommended pattern across the board.

---

## Slide 14 — Legacy reference: community ingress-nginx on AKS

```
   Client
     │
     ▼
   Azure SLB ──▶ Service type=LoadBalancer
                       │
                       ▼
              ingress-nginx Pod  (Deployment, in-cluster)
                       │  reads Ingress + annotations
                       ▼
              Service ──► Pod (via kube-proxy)
```

- Kubernetes `Ingress` API: stable, still valid
- Community `kubernetes/ingress-nginx` controller: retired/EOL implementation
- Single resource (`Ingress`) with controller-specific annotations
- For new platform designs, Gateway API gives cleaner ownership, portability, and typed extension points

**Speaker notes:**
Show this last in the ingress part of the talk. It is what many teams have had in production for years, and the `Ingress` API itself remains a valid Kubernetes API. The correction is that the community `kubernetes/ingress-nginx` controller is the piece being retired, so new designs should avoid depending on it. Gateway API better matches modern platform requirements: clearer ownership, fewer controller-specific annotations, and more portable routing semantics.

---

# Part 3 — How AGC integrates with Gateway API on AKS

---

## Slide 15 — End-to-end: AGC + Gateway API + AKS

```
    ┌─ App team (namespace: demo) ─┐    ┌─ Platform team (namespace: edge) ─┐
    │                              │    │                                   │
    │  HTTPRoute  ────parentRefs──▶│────│▶  Gateway (azure-alb-external)    │
    │   hostnames, paths,          │    │   listeners, TLS, hostnames       │
    │   header rules, splits       │    │                                   │
    └──────────────────────────────┘    └───────────────┬───────────────────┘
                                                        │ reconciled by
                                                        ▼
                                       alb-controller (in-cluster, WI)
                                                        │ ARM API calls
                                                        ▼
                                Application Gateway for Containers (PaaS)
                                  ├─ frontend(s) (public/private IP)
                                  ├─ listener rules from Gateway listeners
                                  ├─ backend settings from HTTPRoute filters
                                  └─ backend pool = pod IPs from EndpointSlice
                                                        │
                                                        ▼
                                                   AKS pods (Azure CNI)
```

**Why this is great**
- **Role separation**: platform owns Gateway, app owns HTTPRoute
- **Direct pod targeting**: AGC backend pool = real pod IPs, no extra hop
- **Identity, not secrets**: ALB Controller uses Workload Identity + federated credential
- **Portable spec**: same `HTTPRoute` yaml runs against Envoy Gateway in dev and AGC in prod
- **Enterprise edge features for free**: WAF, mTLS to backend, autoscaled PaaS, Azure Monitor integration

**Speaker notes:**
This is the slide to land the point of part 2 + part 3: Gateway API is the *contract*, AGC is the *Azure-native implementation*. Teams write the same YAML for any environment; the platform team picks the implementation per environment (Envoy in dev, AGC in production). That is what "vendor-neutral with managed-service benefits" actually looks like.

---

## Slide 16 — Traffic flow: client → AGC → pod (request lifecycle)

```
  1. DNS:  app.contoso.com  → AGC frontend IP
  2. Client TCP+TLS to AGC                         (TLS terminated at AGC)
  3. AGC listener matches host/path/headers        (from Gateway+HTTPRoute)
  4. WAF inspects request                          (if WAF policy attached)
  5. AGC picks healthy backend from pool           (pool = pod IPs)
  6. AGC opens connection to pod IP in delegated   (Azure CNI: pods have
     subnet's peer — directly to the pod            VNet IPs, routable)
  7. (Optional) mTLS to backend, HTTP/2 / gRPC
  8. Response returns through AGC to client
  9. Telemetry → Azure Monitor / Log Analytics
```

**Speaker notes:**
Two micro-points worth calling out: (a) AGC's "backend pool" is dynamic — the ALB Controller updates it from `EndpointSlice` events, so pod churn is reflected within seconds; (b) because pods have real VNet IPs (Azure CNI), there's no kube-proxy/iptables hop. That's the architectural reason AGC is faster than in-cluster ingress controllers for north-south traffic.

---

# Part 4 — Managed Argo CD on AKS

---

## Slide 17 — GitOps on AKS today

**Two managed options, one model**
| | Managed Flux (existing) | Managed Argo CD (new) |
|---|---|---|
| Add-on | `microsoft.flux` extension | `microsoft.argocd` extension |
| UI | None (CLI / Git only) | Argo CD Web UI + CLI |
| Reconciler | Flux controllers | Argo CD controllers |
| Multi-cluster | Per-cluster | Hub-and-spoke from one Argo CD |
| Tenancy model | Kustomization / HelmRelease | Application / ApplicationSet / Project |
| Strength | Lightweight, pull-only, great for fleet | Visual, app-centric, great for dev teams |

**Speaker notes:**
This is *not* "Argo CD replaces Flux" — both are first-class Azure-managed extensions. Flux has been the AKS default for fleet-style GitOps (lots of clusters, one config repo). Argo CD has historically been preferred by app teams that want a UI and per-app views. Until now, you ran Argo CD yourself. Managed Argo CD removes that operational burden.

---

## Slide 18 — Why managed Argo CD on AKS matters

- **No more "who owns the Argo CD cluster?"** — Microsoft runs the control plane components, upgrades, CVEs, backups
- **Identity integrated with Entra ID** — SSO, RBAC mapped to AAD groups out of the box
- **Workload Identity to target clusters** — no kubeconfig secrets stored in Argo CD
- **Azure Monitor integration** — sync status, drift, app health as standard metrics
- **Fleet-scale** — install via Azure Arc / AKS extension on many clusters with one ARM template
- **Same upstream API** — your existing `Application`, `ApplicationSet`, `AppProject` manifests work unchanged

**Where it fits**
- Platform teams running 10s–100s of clusters who want a single pane of glass per app
- Organizations standardizing on Entra ID for everything (Argo's native auth is replaced)
- Teams that want UI-driven rollback / sync without giving cluster-admin to developers

**Speaker notes:**
The "why it matters" is operational, not functional. Argo CD itself is unchanged. What changes is that you stop running it. For an enterprise platform team that means: no Argo CD upgrades, no Redis HA, no Dex/SSO plumbing, no cert rotation, no backup of the application controller. You declare the extension on the AKS cluster and you get a hardened, identity-integrated Argo CD.

---

## Slide 19 — Enabling managed Argo CD

**➡ Move to speaker notes (script):**

```bash
RG=rg-gitops-demo
LOC=swedencentral
AKS=aks-gitops-demo

az group create -n $RG -l $LOC
az aks create -g $RG -n $AKS -l $LOC \
  --kubernetes-version 1.34.7 \
  --tier free \
  --node-vm-size Standard_B4as_v2 \
  --node-count 3 \
  --enable-oidc-issuer --enable-workload-identity \
  --generate-ssh-keys
az aks get-credentials -g $RG -n $AKS

# Ensure the K8s-configuration provider + extension CLI are available
az extension add --name k8s-extension --upgrade
az provider register --namespace Microsoft.KubernetesConfiguration

# Install the managed Argo CD extension on the cluster
az k8s-extension create \
  -g $RG \
  --cluster-name $AKS --cluster-type managedClusters \
  --name argocd \
  --extension-type Microsoft.ArgoCD \
  --auto-upgrade-minor-version true \
  --release-namespace argocd \
  --configuration-settings \
      sso.entraID.enabled=true \
      sso.entraID.tenantId=$(az account show --query tenantId -o tsv) \
      controller.workloadIdentity.enabled=true

# Bootstrap an Application from Git
kubectl apply -n argocd -f - <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata: { name: sample-app, namespace: argocd }
spec:
  project: default
  source:
    repoURL: https://github.com/contoso/platform-gitops
    targetRevision: main
    path: apps/sample-app
  destination:
    server: https://kubernetes.default.svc
    namespace: demo
  syncPolicy:
    automated: { prune: true, selfHeal: true }
    syncOptions: [ CreateNamespace=true ]
YAML
```

**Speaker notes:**
The flow is identical to managed Flux from an operations standpoint: an AKS extension. The config knobs you care about are `sso.entraID.enabled` (turn on Entra-backed login) and `controller.workloadIdentity.enabled` (target other AKS clusters without kubeconfig secrets). Everything else is upstream Argo CD.

---

## Slide 20 — Recap

- **Mesh:** ambient Istio splits security (always-on, cheap ztunnel) from L7 (opt-in waypoints). No sidecars, no pod restarts on mesh upgrade.
- **Ingress → Gateway API:** role-oriented, portable, structured status. Same YAML across Envoy, AGC, and others.
- **AGC:** Azure-native Gateway API implementation; PaaS L7 LB in your VNet talking directly to pod IPs via Azure CNI; ALB Controller bridges Gateway API ↔ ARM with Workload Identity.
- **Managed Argo CD:** AKS extension, Entra-SSO, Workload Identity, sits alongside managed Flux — pick per team.

**One-liner to remember:** *Gateway API is the contract. Ambient is the safety net. AGC is the Azure on-ramp. Managed Argo CD is how the platform team keeps it all reconciled.*

---

## Slide 21 — Q&A

Thank you. Questions?

**Speaker notes (extra references):**
- Istio ambient architecture & HBONE: istio.io/latest/docs/ambient
- Gateway API spec: gateway-api.sigs.k8s.io
- Application Gateway for Containers + ALB Controller: aka.ms/agc
- Managed Argo CD on AKS: aka.ms/aks/argocd
- AKS managed Istio add-on: learn.microsoft.com/azure/aks/istio-about
