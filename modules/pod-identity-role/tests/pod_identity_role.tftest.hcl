mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
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

variables {
  name         = "plat-dev-use1-payments-api"
  cluster_name = "plat-dev-use1"
  associations = {
    api = {
      namespace       = "payments"
      service_account = "payments-api"
    }
  }
}

run "inline_policy_only" {
  command = plan

  variables {
    policy_documents = [jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = ["arn:aws:s3:::payments-artifacts/*"]
      }]
    })]
  }

  assert {
    condition     = length(aws_iam_role_policy.this) == 1 && length(aws_iam_role_policy_attachment.this) == 0
    error_message = "Expected exactly one inline policy and no attachments."
  }

  assert {
    condition     = aws_eks_pod_identity_association.this["api"].namespace == "payments" && aws_eks_pod_identity_association.this["api"].service_account == "payments-api"
    error_message = "Association does not target the expected service account."
  }

  assert {
    condition     = local.cluster_arn == "arn:aws:eks:us-east-1:123456789012:cluster/plat-dev-use1"
    error_message = "Trust policy source ARN is wrong."
  }
}

run "managed_policies_and_multiple_associations" {
  command = plan

  variables {
    associations = {
      api    = { namespace = "payments", service_account = "payments-api" }
      worker = { namespace = "payments", service_account = "payments-worker" }
    }
    managed_policy_arns = {
      sqs_read = "arn:aws:iam::aws:policy/AmazonSQSReadOnlyAccess"
    }
  }

  assert {
    condition     = length(aws_eks_pod_identity_association.this) == 2
    error_message = "One association per service account expected."
  }

  assert {
    condition     = length(aws_iam_role_policy.this) == 0 && length(aws_iam_role_policy_attachment.this) == 1
    error_message = "Expected only the managed policy attachment."
  }
}

run "rejects_empty_associations" {
  command = plan

  variables {
    associations = {}
  }

  expect_failures = [var.associations]
}

run "rejects_invalid_json" {
  command = plan

  variables {
    policy_documents = ["not-json"]
  }

  expect_failures = [var.policy_documents]
}

run "rejects_invalid_k8s_names" {
  command = plan

  variables {
    associations = {
      bad = { namespace = "Payments_NS", service_account = "api" }
    }
  }

  expect_failures = [var.associations]
}
