# Section: Actions Runner Controller (self-hosted runners)

# Put by hand in Secrets Manager (plain PEM) before apply.
data "aws_secretsmanager_secret_version" "arc_github_app_key" {
  secret_id = "arc/github-app-private-key"
}

resource "kubernetes_namespace_v1" "arc_systems" {
  metadata { name = "arc-systems" }
  depends_on = [module.eks]
}

resource "kubernetes_namespace_v1" "arc_runners" {
  metadata { name = "arc-runners" }
  depends_on = [module.eks]
}

# The key lands in Terraform state (accepted, see docs/PLAN.md risks).
resource "kubernetes_secret_v1" "arc_github_app" {
  metadata {
    name      = "arc-github-app"
    namespace = kubernetes_namespace_v1.arc_runners.metadata[0].name
  }
  data = {
    github_app_id              = var.github_app_id
    github_app_installation_id = var.github_app_installation_id
    github_app_private_key     = data.aws_secretsmanager_secret_version.arc_github_app_key.secret_string
  }
}

# Runs on the system node (no toleration).
resource "helm_release" "arc_controller" {
  name       = "arc"
  namespace  = kubernetes_namespace_v1.arc_systems.metadata[0].name
  repository = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart      = "gha-runner-scale-set-controller"
  version    = "0.15.0"

  # Fixed name so the scale set can reference it.
  values = [yamlencode({
    serviceAccount = { name = local.arc_controller_sa }
  })]

  depends_on = [module.eks]
}

locals {
  arc_controller_sa = "arc-controller"
}

resource "helm_release" "arc_runners" {
  name       = "arc-runner-set"
  namespace  = kubernetes_namespace_v1.arc_runners.metadata[0].name
  repository = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart      = "gha-runner-scale-set"
  version    = "0.15.0"

  values = [yamlencode({
    githubConfigUrl    = var.github_config_url
    githubConfigSecret = kubernetes_secret_v1.arc_github_app.metadata[0].name
    runnerScaleSetName = local.name # the runs-on label
    minRunners         = 0
    maxRunners         = 14
    controllerServiceAccount = {
      namespace = kubernetes_namespace_v1.arc_systems.metadata[0].name
      name      = local.arc_controller_sa
    }
    template = {
      spec = {
        nodeSelector = { pool = "runners" }
        tolerations  = [{ key = "runners", operator = "Equal", value = "true", effect = "NoSchedule" }]
        containers = [{
          name    = "runner"
          image   = "ghcr.io/actions/actions-runner:2.338.1"
          command = ["/home/runner/run.sh"]
          # Sized from measured allocatable (~1930m / 3.2Gi minus DaemonSets): 2 runners per node.
          resources = {
            requests = { cpu = "700m", memory = "1280Mi" }
            limits   = { memory = "1400Mi" }
          }
        }]
      }
    }
  })]

  depends_on = [helm_release.arc_controller]
}
