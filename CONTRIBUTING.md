# Contributing

Thank you for your interest in improving this AKS ingress comparison demo.

## Scope

This repository is intended for demonstration and educational use. Contributions should keep the demos easy to understand, reproducible, and aligned with the documented Sweden Central configuration.

Good contribution areas include:

- Fixing documentation, scripts, templates, or Kubernetes manifests
- Improving clarity for workshop or demo usage
- Updating demo dependencies or Azure configuration when required
- Reporting reproducible issues with deployment or cleanup flows

## Before You Submit

Please keep changes focused and avoid unrelated formatting or restructuring. When a change affects Azure resources, verify that the documented region, SKU, Kubernetes version, and cleanup guidance remain accurate.

For changes to scripts or infrastructure, run the relevant validation before opening a pull request:

```bash
# Validate shell scripts
bash -n <script>

# Validate Bicep templates
az bicep build --file <main.bicep>

# Validate Bicep parameter files
az bicep build-params --file <main.bicepparam>
```

For sample application changes, build or test the affected project using the existing project tooling.

## Pull Request Expectations

- Explain what changed and why.
- List the validation you ran.
- Include screenshots or command output when they help verify demo behavior.
- Do not commit generated files, local configuration, credentials, subscription IDs, or other secrets.

For security-sensitive issues, follow [SECURITY.md](./SECURITY.md) instead of posting exploit details publicly.
