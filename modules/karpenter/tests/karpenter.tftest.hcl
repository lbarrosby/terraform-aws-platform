mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = {
      partition  = "aws"
      dns_suffix = "amazonaws.com"
    }
  }

  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

mock_provider "helm" {}

variables {
  cluster_name     = "plat-dev-use1"
  cluster_endpoint = "https://ABCDEF.gr7.us-east-1.eks.amazonaws.com"
}

run "defaults" {
  command = plan

  assert {
    condition     = length(helm_release.karpenter) == 1 && helm_release.karpenter[0].version == "1.15.1"
    error_message = "Controller chart should be installed at the pinned version."
  }

  assert {
    condition     = helm_release.karpenter[0].repository == "oci://public.ecr.aws/karpenter"
    error_message = "Chart must come from the official OCI registry."
  }

  assert {
    condition     = yamldecode(helm_release.karpenter[0].values[0]).settings.clusterName == "plat-dev-use1"
    error_message = "clusterName not wired into chart values."
  }

  assert {
    condition     = yamldecode(helm_release.karpenter[0].values[0]).tolerations[0].key == "CriticalAddonsOnly"
    error_message = "Controller must tolerate the system node group taint."
  }

  assert {
    condition     = output.node_iam_role_name == "plat-dev-use1-karpenter-node"
    error_message = "Node role name must be deterministic."
  }

  assert {
    condition     = length(helm_release.defaults) == 1
    error_message = "Default NodePool/EC2NodeClass should be installed."
  }

  assert {
    condition     = yamldecode(helm_release.defaults[0].values[0]).nodePool.capacityTypes == ["spot", "on-demand"]
    error_message = "Default NodePool should mix spot and on-demand."
  }

  assert {
    condition     = yamldecode(helm_release.defaults[0].values[0]).nodeClass.discoveryTag == "plat-dev-use1"
    error_message = "Discovery tag should default to the cluster name."
  }
}

run "aws_only" {
  command = plan

  variables {
    install_helm_release = false
  }

  assert {
    condition     = length(helm_release.karpenter) == 0 && length(helm_release.defaults) == 0
    error_message = "No helm releases expected when the controller is managed elsewhere."
  }

  assert {
    condition     = output.chart_version == null && output.default_node_pool_name == null
    error_message = "Outputs must reflect that nothing was installed."
  }
}

run "on_demand_only_pool" {
  command = plan

  variables {
    node_pool = {
      capacity_types = ["on-demand"]
      cpu_limit      = 64
    }
  }

  assert {
    condition     = yamldecode(helm_release.defaults[0].values[0]).nodePool.capacityTypes == ["on-demand"] && yamldecode(helm_release.defaults[0].values[0]).nodePool.cpuLimit == "64"
    error_message = "NodePool overrides not propagated."
  }
}

run "max_length_cluster_name" {
  command = plan

  variables {
    cluster_name = "platform-shared-services-prod-sa-east-1"
  }

  assert {
    condition     = output.node_iam_role_name == "platform-shared-services-prod-sa-east-1-karpenter-node"
    error_message = "Node role name must fit IAM limits for long cluster names."
  }
}

run "rejects_unknown_capacity_type" {
  command = plan

  variables {
    node_pool = {
      capacity_types = ["preemptible"]
    }
  }

  expect_failures = [var.node_pool]
}

run "rejects_bad_ami_alias" {
  command = plan

  variables {
    node_class = {
      ami_alias = "ami-0123456789abcdef0"
    }
  }

  expect_failures = [var.node_class]
}

run "rejects_floating_chart_version" {
  command = plan

  variables {
    chart_version = "1.x"
  }

  expect_failures = [var.chart_version]
}
