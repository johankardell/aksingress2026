# GitHub Copilot Instructions for AKS Ingress Demo Repository

## Project Overview

This repository contains three independent demonstrations comparing different ingress/gateway approaches for Azure Kubernetes Service (AKS):

1. **Demo 01**: NGINX Ingress Controller (traditional Ingress pattern, for educational purposes)
2. **Demo 02**: Gateway API with Envoy (modern, vendor-neutral)
3. **Demo 03**: Application Gateway for Containers (Azure-native)

Each demo is self-contained with its own infrastructure, Kubernetes manifests, deployment automation, and documentation.

## Verified Azure Configuration (Sweden Central)

### Location
- **Region**: `swedencentral` (all resources must use this location)

### Kubernetes Version
- **Version**: `1.34.7`
- **Status**: ✅ Verified available in Sweden Central (as of May 2026)
- **Support Plan**: KubernetesOfficial, AKSLongTermSupport

### VM SKU
- **SKU**: `Standard_B4as_v2`
- **Specs**: 4 vCPUs, 16 GiB RAM
- **Type**: B-series burstable, ARM-based (Ampere Altra)
- **Status**: ✅ Verified available in Sweden Central with no restrictions
- **Cost**: ~$35/month per node

### AKS SKU
- **Tier**: `Free`
- **Configuration**:
  ```bicep
  sku: {
    name: 'Base'
    tier: 'Free'
  }
  ```

### Resource Group Naming
- Demo 01 (NGINX): `rg-01-nginx-ingress-demo`
- Demo 02 (Envoy): `rg-02-envoy-gateway-demo`
- Demo 03 (AppGW): `rg-03-appgw-containers-demo`

## Code Standards and Rules

### Infrastructure as Code (Bicep)

1. **Always use Bicep** for Azure infrastructure (not Terraform or ARM templates)
2. **Parameterize everything**: Location, VM size, K8s version, node count
3. **Use parameter files**: Separate `.bicepparam` files for each deployment
4. **Free AKS tier**: All clusters must use the Free tier unless explicitly requested
5. **Managed identities**: Use system-assigned for AKS, user-assigned where needed
6. **Tagging**: Include Environment, Demo, and ManagedBy tags on all resources

### Kubernetes Manifests

1. **Resource requests/limits**: Always specify for production-quality demos
2. **Health probes**: Include both liveness and readiness probes
3. **Namespace**: Default namespace for application resources
4. **Environment variables**: Use for demo-specific configuration
5. **Image pull policy**: `Always` for demo purposes

### Application Code

1. **Tech Stack**: .NET 10 minimal API
2. **Containerization**: Multi-stage Dockerfile for optimal image size
3. **Health endpoints**: `/health` for Kubernetes probes
4. **Logging**: Log all requests for demo purposes
5. **Non-root user**: Run containers as non-root user

### Automation Scripts

1. **Language**: Bash (not PowerShell)
2. **Error handling**: Use `set -e` to exit on errors
3. **Output formatting**: Color-coded output (green for success, yellow for info, red for warnings)
4. **Idempotency**: Scripts should be safe to run multiple times
5. **Cleanup**: Always provide cleanup scripts to avoid resource costs

### Documentation

1. **Professional quality**: Assume public repository visibility
2. **Architecture diagrams**: Use ASCII/text-based diagrams in markdown
3. **Step-by-step instructions**: Both automated and manual deployment paths
4. **Prerequisites**: Clearly list all required tools and permissions
5. **Cost estimates**: Provide monthly cost breakdowns
6. **Troubleshooting**: Include common issues and solutions

## Microsoft Best Practices

The following Microsoft best practices are applied throughout:

- ✅ Infrastructure as Code (Bicep)
- ✅ Managed Identities (no service principals with secrets)
- ✅ Workload Identity enabled (modern authentication)
- ✅ Azure CNI networking (advanced networking capabilities)
- ✅ Azure Monitor integration via Log Analytics
- ✅ RBAC enabled with proper role assignments
- ✅ Auto-upgrade channels configured
- ✅ Network policies enabled (Azure network policy)

## Demo-Specific Guidelines

### Demo 01: NGINX Ingress
- Clearly frame as the **traditional** Ingress pattern, not as a deprecated API
- Include migration guidance to Gateway API
- Use NGINX Ingress Controller Helm chart
- Explain why Gateway API is preferred for new platform-oriented designs

### Demo 02: Gateway API with Envoy
- Use **Gateway API v1** resources (Gateway, HTTPRoute)
- Install Envoy Gateway via Helm
- Demonstrate role-oriented design (infrastructure vs application)
- Show benefits over traditional Ingress

### Demo 03: Application Gateway for Containers
- Enable Web App Routing add-on on AKS
- Use ApplicationLoadBalancer CRD
- Demonstrate Azure-native integration
- Highlight enterprise features (WAF-ready, Azure Monitor)

## File Structure Rules

```
aksingress2026/
├── .github/
│   └── copilot-instructions.md          # This file
├── shared/
│   └── sample-app/                       # Shared .NET app
│       ├── Program.cs
│       ├── sample-app.csproj
│       ├── Dockerfile
│       └── README.md
├── 01-nginx-ingress/
│   ├── README.md                         # Demo-specific docs
│   ├── infrastructure/
│   │   ├── main.bicep                    # Infrastructure template
│   │   ├── main.bicepparam               # Parameters
│   │   └── README.md                     # Infrastructure docs
│   ├── kubernetes/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── ingress.yaml
│   └── scripts/
│       ├── deploy.sh                     # Automated deployment
│       └── cleanup.sh                    # Resource cleanup
├── 02-envoy-gateway-api/                 # Same structure
└── 03-appgw-for-containers/              # Same structure
```

## Common Tasks

### Adding a New Demo Feature

1. Update the Bicep template in `infrastructure/main.bicep`
2. Update parameters in `main.bicepparam`
3. Update Kubernetes manifests in `kubernetes/`
4. Update deployment script in `scripts/deploy.sh`
5. Document in the demo README
6. Test the full deployment workflow
7. Update cost estimates

### Changing Azure Configuration

1. **Always verify availability** in Sweden Central:
   ```bash
   az vm list-skus --location swedencentral --size <SKU> --all
   az aks get-versions --location swedencentral
   ```
2. Update all three demos consistently
3. Update parameter files, templates, and documentation
4. Test at least one demo to verify changes

### Updating Documentation

1. Keep README files concise but comprehensive
2. Use markdown tables for comparisons
3. Include code examples with proper syntax highlighting
4. Provide both quick start and detailed manual steps
5. Always include cleanup instructions

## Code Quality Checklist

Before committing changes, verify:

- [ ] All three demos use consistent configuration
- [ ] Resource names follow the naming convention (rg-01-, rg-02-, rg-03-)
- [ ] Bicep templates validate successfully (`az bicep build`)
- [ ] Scripts are executable (`chmod +x`)
- [ ] Documentation is updated to match code changes
- [ ] Cost estimates are current
- [ ] No hardcoded values (use parameters)
- [ ] Proper error handling in scripts
- [ ] Comments explain "why" not "what"

## Forbidden Actions

**Never do these things:**

1. ❌ Use deprecated Kubernetes API versions
2. ❌ Store secrets in code or configuration files
3. ❌ Use admin credentials for ACR
4. ❌ Hardcode resource names (use generated unique names)
5. ❌ Skip resource cleanup scripts
6. ❌ Use preview/beta features without explicit approval
7. ❌ Change region from Sweden Central without verification
8. ❌ Use VM SKUs not verified in Sweden Central

## Testing and Validation

Before marking work complete:

1. **Bicep validation**: Run `az bicep build` on all templates
2. **Linting**: Check YAML syntax for Kubernetes manifests
3. **Script testing**: Test deploy.sh in a clean environment
4. **Documentation review**: Ensure all steps are accurate
5. **Cost verification**: Double-check monthly estimates

## Contact and Support

This is a demo repository for educational purposes. All code follows Microsoft best practices and is production-quality but should be adapted for specific production requirements.

---

**Last Updated**: May 2026  
**Azure Region**: Sweden Central  
**Verified For**: AKS demos and ingress comparison
