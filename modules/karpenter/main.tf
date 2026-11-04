data "aws_partition" "current" {}

locals {
  tags = merge(
    {
      "platform:module"     = "karpenter"
      "platform:managed-by" = "terraform"
      "platform:cluster"    = var.cluster_name
    },
    var.tags,
  )

  discovery_value = coalesce(var.node_class.discovery_tag_value, var.cluster_name)
}

################################################################################
# AWS side: controller role (Pod Identity), node role, interruption queue
################################################################################

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "21.29.0"

  cluster_name = var.cluster_name

  namespace                       = var.namespace
  service_account                 = var.service_account
  create_pod_identity_association = true
  iam_role_source_arn_condition   = true

  iam_role_name            = "${substr(var.cluster_name, 0, 20)}-karpenter-ctrl"
  iam_role_use_name_prefix = true

  # Fixed name: EC2NodeClass references it and it must survive re-creation.
  node_iam_role_name            = "${var.cluster_name}-karpenter-node"
  node_iam_role_use_name_prefix = false
  node_iam_role_additional_policies = {
    ssm = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  enable_spot_termination = true
  queue_name              = "karpenter-${var.cluster_name}"

  tags = local.tags
}

################################################################################
# Controller
################################################################################

resource "helm_release" "karpenter" {
  count = var.install_helm_release ? 1 : 0

  name             = "karpenter"
  namespace        = var.namespace
  create_namespace = var.namespace != "kube-system"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = var.chart_version

  wait            = true
  atomic          = true
  cleanup_on_fail = true
  timeout         = 600

  values = concat([
    yamlencode({
      replicas = var.controller_replicas
      serviceAccount = {
        name = var.service_account
      }
      settings = {
        clusterName       = var.cluster_name
        clusterEndpoint   = var.cluster_endpoint
        interruptionQueue = module.karpenter.queue_name
      }
      # The controller must never run on capacity it manages.
      nodeSelector = var.controller_node_selector
      tolerations = [{
        key      = "CriticalAddonsOnly"
        operator = "Exists"
      }]
      podDisruptionBudget = {
        name           = "karpenter"
        maxUnavailable = 1
      }
      controller = {
        resources = {
          requests = { cpu = "500m", memory = "512Mi" }
          limits   = { memory = "1Gi" }
        }
      }
    })
  ], var.helm_values)
}

################################################################################
# Default NodePool / EC2NodeClass
#
# Shipped as a tiny local chart instead of kubernetes_manifest: the CRDs do not
# exist at plan time on a fresh cluster, and helm defers that check to apply.
################################################################################

resource "helm_release" "defaults" {
  count = var.install_helm_release && var.create_default_node_pool ? 1 : 0

  name      = "karpenter-defaults"
  namespace = var.namespace
  chart     = "${path.module}/charts/karpenter-defaults"

  values = [
    yamlencode({
      nodeClass = {
        name          = var.node_class.name
        role          = module.karpenter.node_iam_role_name
        amiAlias      = var.node_class.ami_alias
        rootVolumeGiB = var.node_class.root_volume_gib
        discoveryTag  = local.discovery_value
        tags          = local.tags
      }
      nodePool = {
        name                = var.node_pool.name
        capacityTypes       = var.node_pool.capacity_types
        architectures       = var.node_pool.architectures
        instanceCategories  = var.node_pool.instance_categories
        instanceGeneration  = tostring(var.node_pool.instance_generation)
        cpuLimit            = tostring(var.node_pool.cpu_limit)
        memoryLimit         = "${var.node_pool.memory_limit_gib}Gi"
        consolidationPolicy = var.node_pool.consolidation_policy
        consolidateAfter    = var.node_pool.consolidate_after
        expireAfter         = var.node_pool.expire_after
        disruptionBudget    = var.node_pool.disruption_budget
        weight              = var.node_pool.weight
      }
    })
  ]

  depends_on = [helm_release.karpenter]
}
