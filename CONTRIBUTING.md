# Contributing

Thanks for improving this AKS ingress demo.

## Guidelines

- Keep each demo deployable independently.
- Use Sweden Central defaults unless documenting a region-dependent alternative.
- Do not commit tenant-specific identifiers, credentials, kubeconfigs, or generated secrets.
- Validate the sample app with `dotnet restore shared/sample-app/sample-app.csproj` and `dotnet build shared/sample-app/sample-app.csproj --no-restore` when changing application code.
- Validate Bicep templates with `az bicep build --file <path-to-main.bicep>` when changing infrastructure.
