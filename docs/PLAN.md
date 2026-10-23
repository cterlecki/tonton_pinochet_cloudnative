# MVP Plan — issues and implementation process

Architecture: [architecture.md](architecture.md). Requirements: the subject PDF (Subject + C00–C08). Provider: **AWS**.

## 1. MVP definition

The MVP is the **grade D baseline** from the subject, deployed in `prd`, plus every item the subject marks mandatory:

- Foundation (VPC, IAM, EKS, autoscaling ARC runners) by Terraform + Helm via CI/CD, keyless GitHub OIDC → IAM roles.
- Serverless, event-driven app: API Gateway → proxy Lambda → SQS → worker Lambda for **every** command and web draw.
- All 7 Discord commands, Ed25519 validation, admin authorization in the worker.
- Real-time web canvas (no polling), 10000×10000 grid, pixel inspection, brush, Discord OAuth2.
- Dashboards, structured logs with correlation id, traces, ≥ 1 resource alert + ≥ 1 app alert, a load demo.
- Diagram that matches `prd`, signed commits, PR history.

Out of MVP (C/B/A polish, do after): tile PNG cache in S3 + CloudFront, API Gateway throttling/usage plans, External Secrets Operator, Discord alert channel, infinite grid, Grafana.

## 2. Way of working (GitFlow)

1. One GitHub issue per row of the backlog below. Branch `<issue#>-<slug>` from `main`.
2. Signed commits only (`git config commit.gpgsign true`, `tag.gpgsign true`). Conventional Commits.
3. PR to `main` with `Closes #<issue>`. CI must be green (fmt, validate, plan dev+prd, tests). 1 review from another member.
4. `main` protected: no direct push, required checks, required signed commits, linear history (squash merge).
5. Release: signed tag `vX.Y.Z` on `main` → `release.yml` applies dev, then prd after approval in the `prd` environment.
6. Every merged PR that changes architecture updates `docs/architecture.md` in the same PR.

Suggested split (everyone must still explain everything at the defense):

| Member | Owns |
|---|---|
| A — Platform | M0 access stack, M1 foundation, runners, CI/CD workflows |
| B — Backend | M2 serverless core, M3 Discord bot and workers, data model |
| C — Frontend & Ops | M4 web app + OAuth, M5 observability, load tests, diagram |

## 3. Milestones and order

```
M0 Bootstrap ─► M1 Foundation ─► (runners up) ─► switch CI to self-hosted
       │
       └──────► M2 Serverless core ─► M3 Discord bot ─┐
                         └──────────► M4 Frontend ─────┼─► M5 Observability ─► M6 Defense
```

M1 and M2 run in parallel once M0 is done (both only need the access stack + CI).

## 4. Issue backlog

Labels: `infra`, `ci`, `app`, `frontend`, `obs`, `docs`, `security`. Each issue lists its acceptance criteria (AC).

### M0 — Bootstrap (week 1)

| # | Title | AC |
|---|---|---|
| 1 | Team prerequisites | Group locked on intranet; each member's GPG/SSH signing key on GitHub; a signed empty commit from each member shows **Verified** |
| 2 | Repository skeleton | Layout from `architecture.md` (`.github/workflows`, `infra/{org,access,foundation,serverless}`, `app/{functions,frontend}`, `docs`, `loadtest`); `.gitignore` excludes `*.tfstate*`, `.terraform/`, `.env*`, `credentials*`; README with local setup |
| 3 | AWS accounts + billing (`infra/org`) | Management account created by hand (root MFA, free credits claimed, manual budget alert on day 1); `infra/org` applied from it creates the Organization and `<team>-cloudnative-dev` / `-prd` from one `team` variable, accounts under `prevent_destroy`; IAM Identity Center users for each member (`aws sso login` works on both accounts); instructor Identity Center user with `InstructorReadOnly` (`ReadOnlyAccess` + `AWSBillingReadOnlyAccess`) on dev and prd, password set by the instructor from the Identity Center invite email |
| 4 | `infra/access` stack | Applied locally per account: tfstate S3 bucket (versioned, encrypted, public access blocked, `use_lockfile = true`), GitHub OIDC provider, deployer IAM role per env whose trust policy only accepts `repo:<org>/<repo>:environment:<env>`, IAM access to billing enabled, GitHub collaborators incl. `Kloox`, AWS Budgets 50/90/100 %. `aws sts get-caller-identity` works for every member |
| 5 | Branch protection + environments | `main` protected (PR, review, checks, signed commits); GitHub environments `dev` and `prd` (prd requires reviewer); repo variables `AWS_REGION`, `AWS_ROLE_ARN_DEV`, `AWS_ROLE_ARN_PRD` (no secrets needed for AWS auth) |

### M1 — Foundation (weeks 1–2)

| # | Title | AC |
|---|---|---|
| 6 | CI workflow `ci.yml` | On PR: `fmt -check`, `validate`, `plan` matrix {stack}×{dev,prd} via `aws-actions/configure-aws-credentials` (OIDC); plan output posted as PR comment or job summary; `runs-on: ${{ vars.RUNNER_LABEL \|\| 'ubuntu-latest' }}` |
| 7 | Network module | VPC, public + private subnets on 2 AZs, single NAT gateway (cost), S3/DynamoDB gateway endpoints; plans clean for both envs |
| 8 | EKS cluster + node groups | Private API endpoint (or public restricted to CIDRs), EKS Pod Identity, `system` managed node group (1 node) and tainted `runners` node group (t3a.medium) autoscaling 0–7 via Cluster Autoscaler; least-privilege node role (`AmazonEKSWorkerNodePolicy`, CNI, ECR read-only, CloudWatch agent) |
| 9 | ARC runners via Helm | GitHub App created; its key in Secrets Manager; `helm_release` for controller + scale set (`minRunners 0`, `maxRunners 14`, tolerations, requests forcing ~2 runners/node); runner registers on job and disappears after |
| 10 | Release + destroy workflows | `release.yml` on signed tag applies dev then prd (environment gates); `destroy.yml` manual with env input + confirmation; after destroy only `access` resources remain (verified in console and Cost Explorer) |
| 11 | Switch CI to self-hosted | `RUNNER_LABEL` set; PR jobs visibly run on in-cluster runners; `load-runners.yml` with N sleeping jobs makes the runner node group scale up then back to 0 |

### M2 — Serverless core (weeks 2–3)

| # | Title | AC |
|---|---|---|
| 12 | Functions workspace + shared lib | `app/functions` TS workspace; shared `envelope`, `logger` (JSON + correlation id + trace field), `sqs` send helper with message attributes; unit tests run in CI |
| 13 | Serverless stack skeleton | DynamoDB tables (`tiles`, `meta`, `ratelimits`, `processed` (TTL), `connections` (TTL), streams on `tiles` + `meta`), snapshot bucket (private, public access blocked, lifecycle 30 d), SQS queues + DLQs (redrive `maxReceiveCount` 5, visibility timeout > function timeout), Secrets Manager entries, one IAM execution role per function |
| 14 | API Gateway + hello proxy (C05 hands-on) | HTTP API (OpenAPI body) in Terraform; Lambda has no function URL and its resource policy allows only `apigateway.amazonaws.com` with the API's source ARN; unsigned `lambda:InvokeFunction` from outside → `AccessDenied`, call through gateway → 200; function reads a secret through its role |
| 15 | Grid data model + `draw-worker` | Per-pixel item model from `architecture.md §4.4`; `TransactWriteItems` (rate limit + `processed`) then `BatchWriteItem` pixels, idempotent on redelivery, pause, rate limit (default 20/min, override); unit tests: duplicate event, paused, over-limit, concurrent writes to same tile |
| 16 | `draw-proxy` + JWT route | `POST /pixels` rejects missing/invalid token at the gateway Lambda authorizer (401); validates ≤ 256 pixels, bounds, color; sends `pixel.draw` to the `pixel-draw` queue; returns 202 in < 300 ms p95 |

### M3 — Discord bot (weeks 3–4)

| # | Title | AC |
|---|---|---|
| 17 | `discord-proxy` | Ed25519 check on raw body before anything else (bad sig → 401, Discord portal accepts endpoint); PING→PONG; commands → `discord.command` queue + `{type:5}` |
| 18 | Command registration | Script/CI step registers exactly `/draw x y color`, `/get`, `/snapshot`, `/admin pause\|resume\|clear\|ratelimit user limit` per env |
| 19 | `command-worker` + `discord-notifier` | Admin check (role or allow-list) **in the worker**; non-admin gets "forbidden"; pause/resume/ratelimit update DynamoDB `meta`; draw/get/snapshot/clear routed to queues; replies edit the deferred message |
| 20 | `render-worker` (`/get`) | Downscaled PNG of whole grid posted as followup attachment within 15 min token life; Lambda timeout ≤ 14 min and memory sized so a 10000×10000 render fits (test locally) |
| 21 | Snapshot workflow | `snapshot-worker` writes `snapshot-<ISO8601>.png` to private bucket; S3 `ObjectCreated` notification → `snapshot-notifier` → presigned URL (1 h) posted in channel; bucket public access is blocked (`curl` the object URL → 403) |
| 22 | `clear-worker` | `/admin clear` deletes all tile items in `BatchWriteItem` batches, bumps `epoch` in `meta`; web clients see the canvas empty in real time |

### M4 — Frontend (weeks 3–5)

| # | Title | AC |
|---|---|---|
| 23 | Discord OAuth2 + `auth-proxy` | Login with `identify` only; redirect URI allow-listed; code exchanged server-side; Discord access token never stored; short-lived session JWT (signing key in Secrets Manager) returned; Lambda authorizer checks it on HTTP and WebSocket routes; no client writes DynamoDB directly |
| 24 | Canvas viewer | S3 (private) + CloudFront with OAC per env via CI; zoom/pan; initial tiles via `GET /tiles/{tile}`, then API Gateway WebSocket: client subscribes only to visible tiles and unsubscribes when leaving viewport; DynamoDB Stream → `broadcaster` pushes changes; 60 fps pan on full grid; pixel drawn from Discord appears with no refresh |
| 25 | Inspect + draw + brush | Click shows author + timestamp; single-pixel draw and brush (size 1–15) batched ≤ 256 px/request through `/pixels`; pause and rate-limit rejections shown to the user |

### M5 — Observability & scale (weeks 4–5)

| # | Title | AC |
|---|---|---|
| 26 | Tracing + correlation | ADOT / X-Ray active tracing in every function; `traceparent` + `correlation_id` in SQS message attributes; one `/draw` visible as a single trace in X-Ray; logs filterable in CloudWatch Logs Insights by `correlation_id` |
| 27 | Dashboards as code | CloudWatch dashboards "Foundation" (nodes, pods, CPU/RAM via Container Insights, runner jobs) and "Application" (invocations, errors, duration, throttles, queue depth, `ApproximateAgeOfOldestMessage`, DLQ) in Terraform |
| 28 | Alerts | CloudWatch alarms: resource (runner node CPU) + app (5xx ratio, oldest message age, DLQ > 0) → SNS email; each fired once on purpose and screenshotted |
| 29 | Load test | `loadtest/locustfile.py` + token-minting script for dev; run shows Lambda concurrency scaling, queue filling then draining, p95 latency and errors stable on dashboards |

### M6 — Defense (week 6)

| # | Title | AC |
|---|---|---|
| 30 | Diagram + docs | draw.io diagram with official AWS icons: flows, protocols on arrows, IAM boundaries, queues/workers, real-time path; matches `prd`; exported to `docs/` |
| 30b | Docs site (#12) | `docs/` published as a static site (MkDocs Material, `use_directory_urls: false`) on private S3 + CloudFront OAC via `infra/docs` (dev account); `docs.yml` builds with `--strict`, syncs and invalidates on push to `main` touching `docs/**`; no secret or personal data in `docs/` |
| 31 | Security review | Checklist: no Lambda function URL / public invoke policy, no public bucket, no `*:*` IAM policy, no long-lived access key, no secret in repo (`gitleaks` in CI), OIDC only in CI, HTTPS only |
| 32 | Release `v1.0.0` + rehearsal | `prd` live from a tag; scripted demo: IDE → PR → review → tag → deploy; scaling demo; each member presents any part without notes |

## 5. Implementation process per issue

1. Read the matching C0x support section and checklist.
2. Write/adjust `infra/<stack>` and `app/` code on the branch; `terraform fmt` + `validate` + unit tests locally.
3. Open PR: CI plans dev **and** prd — review the plan, not only the code.
4. Merge, then tag a release when a milestone is complete (or more often): dev applies first, check dev, approve prd.
5. Tick the issue AC on the PR, update `architecture.md` if anything changed.

## 6. Risks and safeguards

| Risk | Safeguard |
|---|---|
| Autoscaling burns credits | Runner node group max 7 nodes, `maxRunners 14`, scale to 0, budgets, `destroy.yml` for dev when idle |
| EKS + NAT fixed cost (~$0.10/h control plane, NAT hourly + data) | Single NAT gateway, destroy dev foundation when idle, VPC gateway endpoints for S3/DynamoDB |
| Hot tile contention under brush load | One item per pixel (1 WCU/write), ≤ 256 px/message, SQS retries + DLQ, reserved concurrency on `draw-worker`; mention item-per-pixel vs item-per-tile trade-off at defense |
| Discord 3 s / 15 min limits | Proxy only verifies + enqueues; workers use followups; render sized to finish well under 15 min |
| Secrets in Terraform state (runner GitHub key) | State bucket private + versioned + encrypted, access limited to deployer roles; upgrade path: External Secrets Operator |
| First apply chicken-and-egg | `access` stack applied manually once; foundation apply pinned to GitHub-hosted runners |
| Account deleted by mistake (90-day suspension, email burned) | `infra/org` accounts have `prevent_destroy` + `close_on_deletion = false`; `org` never in `destroy.yml` |
| Instructor access lost on destroy | Human access lives only in `infra/org` (Identity Center), never touched by `destroy.yml` |
