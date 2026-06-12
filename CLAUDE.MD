# CLAUDE.md

## Gotchas

- **Never run `terraform apply` locally.** Apply runs in CI on push to `main` via per-stack workflows in `.github/workflows/<stack>.yaml`.
- **Always consider creating or updating examples for testing new features.** Examples live in `examples/`.

## Examples & CI deploy workflows

- **Not every example has a workflow.** Dedicated deploy workflows exist only for **complete, datadog, lacework, network** (`.github/workflows/examples-<name>.yaml`), each triggered on `pull_request` with `paths: examples/<name>/*.tf`. So an example deploys only when its own `*.tf` files change. `auto-mode`, `simple` and `disable-addons` have **no** workflow and are never CI-deployed.
- **Module-root changes deploy `tests/main`, not `examples/complete`.** `feature.yaml` triggers on `*.tf` / `modules/**/*.tf` / `tests/**/*.tf` and deploys `tests/main` (the canonical EKS test cluster) via `DND-IT/github-workflows`. So a change to `main.tf`, `karpenter.tf`, `addons.tf`, etc. auto-deploys `tests/main` on the PR.
- To CI-test a feature that an example must exercise (e.g. pure Auto Mode), edit that example's `*.tf` and ensure it has a workflow, or add one.

## Workflow

- **Before pushing**: run `pre-commit run -a`. Hooks include `terraform_fmt -recursive`, `terraform_validate`, `terraform_docs`, `terraform_tflint`, `renovate-config-validator`, plus trailing-whitespace / EOF / merge-conflict checks. `no-commit-to-branch` blocks direct commits to protected branches.
