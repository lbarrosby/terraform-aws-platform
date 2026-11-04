# Contributing

## Setup

```bash
brew install terraform tflint terraform-docs trivy pre-commit
pre-commit install
tflint --init
```

## Workflow

1. Branch from `main`. One module per PR when possible; it keeps the release notes and the tag obvious.
2. Change the module, then its tests. A new input gets a `validation` block when there is a wrong value worth rejecting, and an `expect_failures` run proving it.
3. Run the checks:

   ```bash
   terraform fmt -recursive
   for d in modules/*/ examples/complete/; do
     (cd "$d" && terraform init -backend=false -input=false >/dev/null && terraform validate && terraform test)
   done
   tflint --recursive --config "$PWD/.tflint.hcl"
   for d in modules/*/ examples/complete/; do terraform-docs -c .terraform-docs.yml "$d"; done
   trivy config --config trivy.yaml .
   ```

4. Commit with [Conventional Commits](https://www.conventionalcommits.org/) and the module as scope: `feat(eks-cluster): ...`, `fix(vpc): ...`, `docs(karpenter): ...`. Breaking changes use `feat(scope)!:` and a `BREAKING CHANGE:` footer describing the migration (usually `moved` blocks or a state command).

## Releasing

After merge, tag the module that changed:

```bash
git tag -a eks-cluster-v1.1.0 -m "eks-cluster v1.1.0"
git push origin eks-cluster-v1.1.0
```

Bump MAJOR for anything that changes or replaces existing resources on an unchanged config.

## Design rules

- Wrap upstream modules; do not re-implement them. Pin their version exactly.
- Keep the interface small. Pass-through of every upstream variable is not a goal.
- No provider blocks inside modules. The caller configures providers.
- No `kubernetes_manifest` for resources whose CRDs are installed in the same apply.
- Anything that costs money per hour (NAT, interface endpoints, extended support) is explicit in the inputs.
