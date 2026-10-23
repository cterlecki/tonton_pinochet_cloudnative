# epitech_tonton_cloud_serverless

## Repository layout

| Path | Purpose |
|------|---------|
| `.github/workflows/` | CI/CD pipelines (C03) |
| `.github/scripts/` | Helper scripts for workflows (`plan-stacks.sh`) |
| `mkdocs.yml` | MkDocs Material config for the documentation site |
| `infra/org/` | AWS Organization + dev/prd accounts (bootstrap, applied once from the management account) |
| `infra/access/` | State bucket, CI deployer role, budget (separate stack) |
| `infra/github/` | Repo settings, `main` protection, environments, Actions variables, collaborators (applied by hand by a repo admin) |
| `infra/docs/` | Private S3 + CloudFront (OAC) hosting this site, dev account, state key `docs/terraform.tfstate` (applied by hand) |
| `infra/foundation/` | Network, IAM, cluster, runners (C02, C04) |
| `infra/foundation/backends/` | Per-environment backend config |
| `infra/serverless/` | API Gateway, functions, queues, storage (C05-C07) |
| `app/functions/` | Serverless function source |
| `app/frontend/` | Web frontend source |
| `docs/architecture.md` | Architecture diagram |

## Documentation site

The `docs/` folder is published as a static site (MkDocs Material, S3 + CloudFront) by `docs.yml` on each push to `main`. URL: `<docs URL: terraform -chdir=infra/docs output -raw url>`.

Preview locally:

```sh
pip install -r requirements-docs.txt && mkdocs serve
```

## Usage

```sh
cd infra/foundation
terraform init -backend-config=backends/dev.hcl
terraform plan -var-file=dev.tfvars
```

GitHub settings (repo admin, once and after each change):

```sh
cd infra/github
export GITHUB_TOKEN=$(gh auth token)
terraform init
terraform apply
```
