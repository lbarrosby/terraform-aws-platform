mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names    = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d"]
      zone_ids = ["use1-az1", "use1-az2", "use1-az4", "use1-az6"]
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
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

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }
}

variables {
  name = "plat-dev-use1"
  cidr = "10.20.0.0/16"
}

run "subnet_layout" {
  command = plan

  assert {
    condition     = length(local.azs) == 3
    error_message = "Defaults to three AZs."
  }

  assert {
    condition     = local.private_subnets == ["10.20.0.0/19", "10.20.32.0/19", "10.20.64.0/19"]
    error_message = "Unexpected private subnet layout."
  }

  assert {
    condition     = local.public_subnets == ["10.20.128.0/24", "10.20.129.0/24", "10.20.130.0/24"]
    error_message = "Unexpected public subnet layout."
  }

  assert {
    condition     = local.intra_subnets == ["10.20.144.0/24", "10.20.145.0/24", "10.20.146.0/24"]
    error_message = "Unexpected intra subnet layout."
  }

  assert {
    condition     = length(module.vpc.natgw_ids) == 3
    error_message = "one_per_az must create one NAT gateway per AZ."
  }
}

run "single_nat_and_discovery_tags" {
  command = plan

  variables {
    nat_gateway_mode        = "single"
    eks_cluster_names       = ["plat-dev-use1"]
    karpenter_discovery_tag = "plat-dev-use1"
  }

  assert {
    condition     = length(module.vpc.natgw_ids) == 1
    error_message = "single mode must create exactly one NAT gateway."
  }
}

run "no_nat" {
  command = plan

  variables {
    nat_gateway_mode = "none"
    az_count         = 2
  }

  assert {
    condition     = length(module.vpc.natgw_ids) == 0 && length(local.azs) == 2
    error_message = "none mode must not create NAT gateways."
  }
}

run "endpoints" {
  command = plan

  variables {
    vpc_endpoints = ["s3", "ecr.api", "ecr.dkr", "sts", "ec2"]
  }

  assert {
    condition     = toset(local.interface_endpoints) == toset(["ecr.api", "ecr.dkr", "sts", "ec2"])
    error_message = "s3 must be a gateway endpoint, the rest interface endpoints."
  }
}

run "max_length_name_with_endpoints" {
  command = plan

  variables {
    name          = "platform-shared-services-prod-sa-east-1ab"
    vpc_endpoints = ["s3", "sts"]
  }

  assert {
    condition     = length(var.name) == 41
    error_message = "Test should exercise the maximum name length."
  }
}

run "rejects_small_cidr" {
  command = plan

  variables {
    cidr = "10.20.0.0/24"
  }

  expect_failures = [var.cidr]
}

run "rejects_unknown_endpoint" {
  command = plan

  variables {
    vpc_endpoints = ["dynamodb-fips"]
  }

  expect_failures = [var.vpc_endpoints]
}

run "rejects_bad_nat_mode" {
  command = plan

  variables {
    nat_gateway_mode = "two"
  }

  expect_failures = [var.nat_gateway_mode]
}
