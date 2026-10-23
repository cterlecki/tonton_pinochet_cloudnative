# Cluster: EKS with API auth, add-ons, a fixed system pool and a 0..7 runners pool

data "aws_iam_role" "deployer" {
  name = "github-deployer"
}

# SSO role name carries a generated hash, so look it up.
data "aws_iam_roles" "sso_admin" {
  name_regex  = "^AWSReservedSSO_AdministratorAccess_.*"
  path_prefix = "/aws-reserved/sso.amazonaws.com/"
}

data "aws_iam_roles" "sso_instructor" {
  name_regex  = "^AWSReservedSSO_InstructorReadOnly_.*"
  path_prefix = "/aws-reserved/sso.amazonaws.com/"
}

locals {
  # Access entries take the full ARN with its path (stripping it is only for the aws-auth ConfigMap).
  sso_admin_arn = one(data.aws_iam_roles.sso_admin.arns)

  cluster_admin = {
    type         = "STANDARD"
    policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
    access_scope = { type = "cluster" }
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name = local.name
  # Newest version in standard support in eu-west-3: older ones are billed extended support.
  kubernetes_version = "1.37"
  # IAM name_prefix is capped at 38 chars, local.name is longer: use fixed names.
  iam_role_use_name_prefix = false

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # shortcut: public endpoint open to the internet (IAM-gated), because GitHub-hosted runners
  # have dynamic IPs; upgrade by narrowing cluster_endpoint_public_access_cidrs or using self-hosted runners.
  endpoint_private_access      = true
  endpoint_public_access       = true
  endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  # Defaults to whoever runs Terraform, so the key policy would flip between laptop (SSO) and CI (deployer).
  kms_key_administrators = [data.aws_iam_role.deployer.arn, local.sso_admin_arn]

  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = false
  access_entries = {
    deployer = {
      principal_arn       = data.aws_iam_role.deployer.arn
      type                = local.cluster_admin.type
      policy_associations = { admin = { policy_arn = local.cluster_admin.policy_arn, access_scope = local.cluster_admin.access_scope } }
    }
    sso_admin = {
      principal_arn       = local.sso_admin_arn
      type                = local.cluster_admin.type
      policy_associations = { admin = { policy_arn = local.cluster_admin.policy_arn, access_scope = local.cluster_admin.access_scope } }
    }
    # Read-only view of the cluster (nodes, pods) for the instructor; no Secrets access.
    instructor = {
      principal_arn = one(data.aws_iam_roles.sso_instructor.arns)
      type          = "STANDARD"
      policy_associations = {
        view = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }

  addons = {
    vpc-cni                = { most_recent = true, before_compute = true }
    eks-pod-identity-agent = { most_recent = true, before_compute = true }
    coredns                = { most_recent = true }
    kube-proxy             = { most_recent = true }
    # Needs the node role policy below.
    amazon-cloudwatch-observability = { most_recent = true }
  }

  eks_managed_node_groups = {
    system = {
      instance_types = ["t3.medium"]
      min_size       = 1
      max_size       = 1
      desired_size   = 1

      iam_role_additional_policies = {
        cloudwatch = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
      }
    }

    # Scaled by the Cluster Autoscaler; only runner pods tolerate the taint.
    runners = {
      # Cheapest x86 with 2 vCPU / 4 GiB in eu-west-3; t3.medium is the same size, used if t3a has no capacity.
      instance_types = ["t3a.medium", "t3.medium"]
      min_size       = 0
      max_size       = 7
      desired_size   = 0

      labels = { pool = "runners" }
      taints = {
        runners = { key = "runners", value = "true", effect = "NO_SCHEDULE" }
      }

      iam_role_additional_policies = {
        cloudwatch = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
      }
    }
  }
}

# Scale from zero: managed node groups don't copy labels/taints to the ASG, so the autoscaler
# can't know what a new runners node looks like unless the ASG carries these tags.
resource "aws_autoscaling_group_tag" "runners_node_template" {
  for_each = {
    "k8s.io/cluster-autoscaler/node-template/label/pool"    = "runners"
    "k8s.io/cluster-autoscaler/node-template/taint/runners" = "true:NoSchedule"
  }

  autoscaling_group_name = module.eks.eks_managed_node_groups["runners"].node_group_autoscaling_group_names[0]

  tag {
    key                 = each.key
    value               = each.value
    propagate_at_launch = false
  }
}

# Cluster Autoscaler: Pod Identity role + Helm release

module "cluster_autoscaler_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.0"

  name            = "${local.name}-cluster-autoscaler"
  use_name_prefix = false

  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_names = [module.eks.cluster_name]

  associations = {
    this = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "cluster-autoscaler"
    }
  }
}

resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  namespace  = "kube-system"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  # shortcut: newest chart ships appVersion 1.35, no 1.37 build yet; autoscaler tolerates a
  # small skew, bump the chart (and set image.tag) once a 1.37 release exists.
  version = "9.59.0"

  values = [yamlencode({
    autoDiscovery = { clusterName = module.eks.cluster_name }
    awsRegion     = var.region
    rbac          = { serviceAccount = { name = "cluster-autoscaler" } }
    extraArgs = {
      "scale-down-unneeded-time"    = "10m"
      "balance-similar-node-groups" = true
      "expander"                    = "least-waste"
      "skip-nodes-with-system-pods" = false
    }
  })]

  depends_on = [module.eks, module.vpc, module.cluster_autoscaler_pod_identity]
}
