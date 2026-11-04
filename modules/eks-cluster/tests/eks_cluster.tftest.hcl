mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = {
      partition  = "aws"
      dns_suffix = "amazonaws.com"
    }
  }

  mock_data "aws_region" {
    defaults = {
      name   = "us-east-1"
      region = "us-east-1"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:role/terraform"
    }
  }

  mock_data "aws_iam_session_context" {
    defaults = {
      issuer_arn = "arn:aws:iam::123456789012:role/terraform"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_data "aws_eks_addon_version" {
    defaults = {
      version = "v1.0.0-eksbuild.1"
    }
  }
}

mock_provider "tls" {}
mock_provider "time" {}

variables {
  name               = "plat-dev-use1"
  kubernetes_version = "1.34"
  vpc_id             = "vpc-0123456789abcdef0"
  subnet_ids         = ["subnet-aaaa1111", "subnet-bbbb2222", "subnet-cccc3333"]
}

run "defaults" {
  command = plan

  assert {
    condition     = toset(keys(output.addon_versions)) == toset(["vpc-cni", "eks-pod-identity-agent", "kube-proxy", "coredns", "aws-ebs-csi-driver"])
    error_message = "All five core add-ons must be managed by default."
  }

  assert {
    condition     = length(aws_iam_role.ebs_csi) == 1
    error_message = "EBS CSI Pod Identity role should be created by default."
  }

  assert {
    condition     = output.oidc_provider_arn == null
    error_message = "IRSA must be off by default."
  }

  assert {
    condition     = jsondecode(local.addons["vpc-cni"].configuration_values).env.ENABLE_PREFIX_DELEGATION == "true"
    error_message = "Prefix delegation should be enabled on vpc-cni by default."
  }

  assert {
    condition     = local.addons["vpc-cni"].before_compute && local.addons["eks-pod-identity-agent"].before_compute && !local.addons["coredns"].before_compute
    error_message = "Networking and identity add-ons must be installed before compute."
  }

  assert {
    condition     = local.tags["platform:managed-by"] == "terraform" && local.tags["platform:cluster"] == "plat-dev-use1"
    error_message = "Default tags are missing."
  }
}

run "ebs_csi_disabled" {
  command = plan

  variables {
    enable_ebs_csi_driver = false
  }

  assert {
    condition     = length(aws_iam_role.ebs_csi) == 0 && !contains(keys(output.addon_versions), "aws-ebs-csi-driver")
    error_message = "EBS CSI resources must not exist when disabled."
  }
}

run "addon_pin_and_config_override" {
  command = plan

  variables {
    addon_overrides = {
      coredns = {
        version              = "v1.12.1-eksbuild.2"
        configuration_values = "{\"replicaCount\":3}"
      }
    }
  }

  assert {
    condition     = output.addon_versions["coredns"] == "v1.12.1-eksbuild.2"
    error_message = "Pinned add-on version must win over the data source."
  }

  assert {
    condition     = output.addon_versions["kube-proxy"] == "v1.0.0-eksbuild.1"
    error_message = "Non pinned add-ons resolve through the data source."
  }

  assert {
    condition     = jsondecode(local.addons["coredns"].configuration_values).replicaCount == 3
    error_message = "configuration_values override not applied."
  }
}

run "admin_access_entries" {
  command = plan

  variables {
    admin_principal_arns = ["arn:aws:iam::123456789012:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_PlatformAdmin_abc123"]
  }

  assert {
    condition     = contains(keys(local.admin_access_entries), "admin-AWSReservedSSO-PlatformAdmin-abc123")
    error_message = "Admin access entry key should be derived from the role name."
  }
}

run "max_length_name" {
  # IAM name_prefix limits (38 chars) are only enforced by the provider, so
  # plan with the longest name the module accepts.
  command = plan

  variables {
    name = "platform-shared-services-prod-sa-east-1"
  }

  assert {
    condition     = length(var.name) == 39
    error_message = "Test should exercise the maximum name length."
  }
}

run "rejects_open_public_endpoint" {
  command = plan

  variables {
    endpoint_public_access       = true
    endpoint_public_access_cidrs = ["0.0.0.0/0"]
  }

  expect_failures = [var.endpoint_public_access_cidrs]
}

run "rejects_public_endpoint_without_allow_list" {
  command = plan

  variables {
    endpoint_public_access = true
  }

  expect_failures = [var.endpoint_public_access_cidrs]
}

run "rejects_bad_version" {
  command = plan

  variables {
    kubernetes_version = "1.34.1"
  }

  expect_failures = [var.kubernetes_version]
}

run "rejects_single_system_node" {
  command = plan

  variables {
    system_node_group = {
      min_size     = 1
      desired_size = 1
    }
  }

  expect_failures = [var.system_node_group]
}

run "rejects_unknown_addon_override" {
  command = plan

  variables {
    addon_overrides = {
      "aws-load-balancer-controller" = { version = "v1" }
    }
  }

  expect_failures = [var.addon_overrides]
}
