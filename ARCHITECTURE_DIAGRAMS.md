# Architecture Diagrams

This repository includes professional draw.io architecture diagrams for each demo, located in their respective folders:

- **Demo 01:** `01-nginx-ingress/architecture.drawio`
- **Demo 02:** `02-envoy-gateway-api/architecture.drawio`
- **Demo 03:** `03-appgw-for-containers/architecture.drawio`

## How to View and Edit

### Option 1: diagrams.net (Online)
1. Go to https://app.diagrams.net/
2. Click **File** → **Open from** → **Device**
3. Select the `.drawio` file from your local repository
4. View and edit the diagram

### Option 2: VS Code Extension
1. Install the **Draw.io Integration** extension in VS Code
2. Open any `.drawio` file directly in VS Code
3. Edit inline within your IDE

### Option 3: Draw.io Desktop App
1. Download from https://github.com/jgraph/drawio-desktop/releases
2. Open the `.drawio` file in the desktop application

## Diagram Overview

### Demo 01: NGINX Ingress Controller (Traditional)

**File:** `01-nginx-ingress/architecture.drawio`

**Components:**
- Internet → Azure Load Balancer
- NGINX Ingress Controller (in nginx-ingress namespace)
- Ingress Resource (classic Kubernetes API)
- Application Service and Pods
- Azure Container Registry (ACR)
- Log Analytics Workspace

**Key Features:**
- Shows the traditional NGINX Ingress approach
- Traditional Ingress resource (not Gateway API)
- Simple architecture for educational purposes
- Clearly framed as the legacy/traditional pattern

**Traffic Flow:**
```
Internet → Load Balancer → NGINX Controller → Service → Pods
```

---

### Demo 02: Gateway API with Envoy Gateway (Modern Standard)

**File:** `02-envoy-gateway-api/architecture.drawio`

**Components:**
- Internet → Azure Load Balancer
- Envoy Gateway System (envoy-gateway-system namespace)
  - Envoy Gateway Controller (control plane)
  - Envoy Proxy Deployment (data plane)
- Gateway API Resources (default namespace)
  - Gateway (v1)
  - HTTPRoute (v1)
  - Service
  - Deployment/Pods
- Azure Container Registry (ACR)
- Log Analytics Workspace

**Key Features:**
- ✅ Gateway API v1 (vendor-neutral standard)
- ✅ Separation of control plane and data plane
- ✅ Role-oriented design (infrastructure vs application teams)
- ✅ Modern Kubernetes networking

**Traffic Flow:**
```
Internet → Load Balancer → Envoy Proxy → Service → Pods
```

**Control Flow:**
```
Envoy Controller → Gateway → HTTPRoute → Service
Envoy Controller → Envoy Proxy (configuration)
```

**Architecture Highlights:**
- **Infrastructure Team** manages: GatewayClass, Gateway
- **Application Team** manages: HTTPRoute, Service, Deployment

---

### Demo 03: Application Gateway for Containers (Azure-Native)

**File:** `03-appgw-for-containers/architecture.drawio`

**Components:**
- Internet → Application Gateway for Containers (Azure-native)
- Virtual Network (10.4.0.0/16)
  - AKS Subnet (10.4.0.0/22)
  - AppGW Subnet (10.4.4.0/24, delegated)
- AKS Cluster with App Routing Add-on
  - kube-system namespace
    - ALB Controller Pod
    - ApplicationLoadBalancer CRD
  - default namespace
    - Gateway (v1)
    - HTTPRoute (v1)
    - Service
    - Deployment/Pods
- User-Assigned Managed Identity (Network Contributor)
- Azure Container Registry (ACR)
- Log Analytics Workspace

**Key Features:**
- ✅ Azure-native integration
- ✅ Gateway API v1 standard
- ✅ Application Load Balancer (ALB) Controller
- ✅ Subnet delegation (Microsoft.ServiceNetworking/trafficControllers)
- ✅ Azure Monitor ready
- ✅ WAF-ready architecture

**Traffic Flow:**
```
Internet → AppGW for Containers → Service → Pods
```

**Control Flow:**
```
ALB Controller → Application Gateway for Containers
ALB Controller → Gateway → HTTPRoute → Service
```

**Architecture Highlights:**
- Dedicated subnet for Application Gateway
- App Routing add-on automatically provisions ALB Controller
- Managed identity with Network Contributor role on VNet
- Enterprise-ready for production workloads

---

## Color Coding

The diagrams use consistent color coding across all three demos:

| Color | Meaning |
|-------|---------|
| **Blue** (Light) | Azure resources and AKS cluster |
| **Yellow** (Light) | Resource groups and organizational boundaries |
| **Purple** (Light) | Container images and deployments |
| **Green** (Light) | Node pools and pods |
| **Orange** (Light) | Gateway/Ingress resources |
| **Cyan** (Light) | Load balancers and networking |
| **Gray** | Monitoring and logging |
| **Thick Blue Lines** | HTTP traffic (data plane) |
| **Dashed Orange Lines** | Control plane communication |
| **Dashed Gray Lines** | Infrastructure dependencies |

---

## Comparison at a Glance

| Aspect | Demo 01 (NGINX) | Demo 02 (Envoy) | Demo 03 (AppGW) |
|--------|----------------|-----------------|-----------------|
| **API** | Ingress v1 | Gateway API v1 | Gateway API v1 |
| **Controller** | NGINX Ingress | Envoy Gateway | ALB Controller |
| **Data Plane** | NGINX Pods | Envoy Proxy Pods | Azure AppGW |
| **Networking** | Azure CNI | Azure CNI | Azure CNI + VNet |
| **Azure Integration** | Basic | Basic | Native (Managed) |
| **Subnet Delegation** | No | No | Yes (required) |
| **Status** | Legacy / Traditional | ✅ Recommended | ✅ Azure-Native |

---

## Exporting Diagrams

### Export to PNG
1. Open the diagram in draw.io
2. **File** → **Export as** → **PNG**
3. Select desired resolution (e.g., 2x for high quality)
4. Save to desired location

### Export to SVG (Vector)
1. Open the diagram in draw.io
2. **File** → **Export as** → **SVG**
3. Useful for documentation and presentations
4. Scales infinitely without quality loss

### Export to PDF
1. Open the diagram in draw.io
2. **File** → **Export as** → **PDF**
3. Good for printing or sharing

---

## Modifying Diagrams

All diagrams are fully editable. Common modifications:

1. **Update Resource Names**: Double-click any box and edit the text
2. **Add New Components**: Use the shape library on the left
3. **Change Colors**: Right-click → **Edit Style** → **Fill Color**
4. **Add Arrows**: Use the connector tool in the toolbar
5. **Rearrange Layout**: Drag components to new positions
6. **Add Notes**: Insert text boxes for additional annotations

---

## Integration with Documentation

These diagrams complement the written documentation in each demo's README:

- **Demo 01 README**: Explains the traditional NGINX Ingress model and Gateway API tradeoffs
- **Demo 02 README**: Details Gateway API benefits
- **Demo 03 README**: Covers Azure-native features

The diagrams provide visual reference while following the deployment guides.

---

## Diagram Standards

All diagrams follow these standards:

✓ Professional quality suitable for presentations  
✓ Consistent color scheme across all demos  
✓ Clear traffic flow indicators  
✓ Labeled connections and relationships  
✓ Resource names matching actual deployments  
✓ Namespace separation clearly shown  
✓ Azure resource grouping and hierarchy  
✓ Legend and notes for key features  

---

## Questions or Issues

If you need to modify these diagrams or have questions about the architecture:

1. Open the diagram in draw.io/diagrams.net
2. Refer to the demo's README for component details
3. Check the Bicep templates in `infrastructure/` for exact resource configurations
4. Review the Kubernetes manifests in `kubernetes/` for workload details

---

**Last Updated:** May 21, 2026  
**Format:** Draw.io XML (.drawio)  
**Compatibility:** diagrams.net, Draw.io Desktop, VS Code Draw.io extension
