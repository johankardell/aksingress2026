# AKS Fleet Manager Infrastructure

This Bicep deployment creates a hubless Azure Kubernetes Fleet Manager resource with a system-assigned managed identity. It does not create a hub cluster, networking, or compute.

| Setting | Default |
| --- | --- |
| Resource group | `rg-06-aks-fleet-demo` |
| Region | `swedencentral` |
| Fleet name | `aks-ingress-demo-fleet` |
| API version | `2025-03-01` |

Deploy through `../scripts/deploy.sh` so existing demo AKS clusters are also reconciled as Fleet members.
