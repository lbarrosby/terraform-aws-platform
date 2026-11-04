# live (reference layout)

How the modules are consumed per account/region/environment with Terragrunt. The account IDs and role ARNs are placeholders; nothing here is applied from this repository.

```
live/
├── root.hcl                      # remote state, provider generation, default tags, naming
├── _envcommon/                   # module source + pinned ref + dependency wiring, one file per module
│   ├── vpc.hcl
│   ├── eks-cluster.hcl
│   └── karpenter.hcl
├── nonprod/                      # one directory per AWS account
│   ├── account.hcl               # account id, terraform role, org prefix
│   └── us-east-1/
│       ├── region.hcl
│       └── dev/
│           ├── env.hcl
│           ├── vpc/terragrunt.hcl
│           ├── eks-cluster/terragrunt.hcl
│           └── karpenter/terragrunt.hcl
└── prod/
    └── us-east-1/prod/...
```

Conventions:

- **Naming**: `<org_prefix>-<environment>-<region_short>`, e.g. `plat-prod-use1`. Computed once in `root.hcl` and passed as `name` to every unit.
- **State**: one S3 bucket per account and region, key = unit path. Locking uses the S3 native lock file (`use_lockfile = true`); no DynamoDB table.
- **Credentials**: CI assumes `terraform_role_arn` per account; `allowed_account_ids` in the generated provider prevents applying to the wrong account.
- **Promotion**: a module change is tagged (`eks-cluster-v1.3.0`). Nonprod units override the ref first (`terraform { source = "${include.envcommon.locals.source_url}?ref=eks-cluster-v1.3.0" }`); once it is proven there, the pin in `_envcommon` moves and the override is removed.
- `root.hcl` (not a root `terragrunt.hcl`) follows the current Terragrunt recommendation so `terragrunt run --all` does not treat the root as a unit.

```bash
cd live/nonprod/us-east-1/dev
terragrunt run --all plan
```
