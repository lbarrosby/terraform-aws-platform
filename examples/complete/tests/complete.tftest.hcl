# Wires the four modules together with mocked providers. Catches interface
# drift between modules (renamed outputs, type changes) without touching AWS.

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

  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b", "us-east-1c"]
    }
  }

  mock_data "aws_eks_addon_version" {
    defaults = {
      version = "v1.0.0-eksbuild.1"
    }
  }

  mock_resource "aws_vpc" {
    defaults = {
      id = "vpc-0123456789abcdef0"
    }
  }
}

mock_provider "helm" {}
mock_provider "tls" {}
mock_provider "time" {}

run "composes" {
  command = plan

  assert {
    condition     = output.cluster_name == "plat-example-use1"
    error_message = "Cluster name should flow from the root variable."
  }

  assert {
    condition     = output.karpenter_node_role == "plat-example-use1-karpenter-node"
    error_message = "Karpenter node role naming changed."
  }

  assert {
    condition     = length(keys(output.addon_versions)) == 5
    error_message = "Expected the five core add-ons."
  }
}
