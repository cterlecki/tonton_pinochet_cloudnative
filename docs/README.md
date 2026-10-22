# epitech_tonton_cloud_serverless

## Repository layout

| Path | Purpose |
|------|---------|
| `.github/workflows/` | CI/CD pipelines (C03) |
| `infra/org/` | AWS Organization + dev/prd accounts (bootstrap, applied once from the management account) |
| `infra/access/` | Human + instructor access (separate stack) |
| `infra/foundation/` | Network, IAM, cluster, runners (C02, C04) |
| `infra/foundation/backends/` | Per-environment backend config |
| `infra/serverless/` | API Gateway, functions, queues, storage (C05-C07) |
| `app/functions/` | Serverless function source |
| `app/frontend/` | Web frontend source |
| `docs/architecture.md` | Architecture diagram |

## Usage

```sh
cd infra/foundation
terraform init -backend-config=backends/dev.hcl
terraform plan -var-file=dev.tfvars
```
