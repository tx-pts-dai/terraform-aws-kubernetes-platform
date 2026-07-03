---
name: eks-k8s-version-upgrade
description: >-
  Bump the default Kubernetes minor version of the terraform-aws-kubernetes-platform
  (EKS) module when AWS EKS supports a newer one. Detects the next supported minor via
  the AWS CLI (falling back to web research), edits variables.tf and the README, researches
  version-specific upgrade caveats, and opens a MAJOR-release PR. Use this whenever the user
  asks to "upgrade kubernetes", "bump the k8s version", "check for a new EKS version", "is
  there a newer kubernetes version", "update kubernetes_version", or mentions moving the EKS
  cluster to a newer Kubernetes release — even if they don't name the exact target version.
  Do NOT use it to upgrade a live cluster or write workload manifests; this only changes the
  module's default version and ships it as a release.
---

# Upgrade the EKS Kubernetes Minor Version

This skill bumps the default `kubernetes_version` of this Terraform module by **exactly one
minor version** when AWS EKS starts supporting a newer one, and ships that change as a
**MAJOR** release of the module.

## Why this is delicate

A Kubernetes minor bump is a backwards-incompatible change for every consumer of this module:
it advances the control plane, can deprecate or remove APIs, and **cannot be skipped or rolled
back**. Two rules follow from that and drive everything below:

1. **Never skip a minor.** Go from `1.N` to `1.N+1` only — never jump `1.N` → `1.N+2`, even if
   AWS already supports the further version. Consumers must step through each minor.
2. **A minor bump must be released as MAJOR.** The commit has to be marked breaking so
   semantic-release produces an `X.0.0` bump. A plain `feat:` would silently ship a
   breaking change as a MINOR — that's the failure mode to avoid.

## Workflow

### 1. Find the current default

Read the default from `variables.tf`:

```bash
grep -A4 'variable "kubernetes_version"' variables.tf
```

The default is on the `default = "1.NN"` line. Call this the **current version**. The target
is always current minor + 1 (e.g. current `1.35` → target `1.36`).

### 2. Check whether the target is actually supported by EKS

Prefer the live AWS CLI — it's authoritative. `describe-cluster-versions` lists every version
EKS offers plus its support status:

```bash
aws eks describe-cluster-versions \
  --query 'clusterVersions[].{version:clusterVersion,status:status,default:defaultVersion,eol:endOfStandardSupportDate}' \
  --output table
```

Interpret the result:

- The target (`1.N+1`) must appear with `status` of `STANDARD_SUPPORT`. If it does, proceed.
- If the target isn't listed yet, EKS doesn't support it — **stop and tell the user** the
  module is already on the newest supported minor (or that the next one isn't GA yet). Don't
  invent a version.
- If the CLI errors (no credentials, `aws` not installed, `AccessDenied`), fall back to web
  research: check the AWS "Amazon EKS now supports Kubernetes version 1.N" announcements and
  the [EKS Kubernetes versions doc](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html).
  Confirm the target is GA on EKS before continuing, and note in your summary that you used
  web research rather than the live API.

Only bump one minor per run. If the module is several minors behind, do the next single step
and mention to the user that further steps will be needed afterward (each its own MAJOR release).

### 3. Research version-specific upgrade caveats

Before editing, find out what changes in the target minor so the README warns consumers
properly. This is what makes the upgrade safe to adopt, not just a number change. Look up:

- The AWS "Amazon EKS now supports Kubernetes version 1.N" blog/announcement.
- The Kubernetes 1.N release notes / changelog for removed and deprecated APIs, and for
  runtime/node changes (container runtime, cgroups, kubelet defaults, AMI implications).

Distill this into 1–4 short bullets a consumer must act on before upgrading — removed APIs,
node/AMI requirements, anything that can't be rolled back. Keep the existing bullets' tone:
concrete and action-oriented (see the current "Notes for 1.35" section as the model). If your
research surfaces nothing actionable, say so with a single bullet linking the EKS support
announcement rather than padding it.

### 4. Edit the files

Exactly these edits (addon versions resolve dynamically via the AWS API, so they need no
change):

- **`variables.tf`** — update the `default` and the example in the `description`:
  ```
  description = "Kubernetes version for the EKS cluster (e.g., \"1.N\")"
  ...
  default     = "1.N"
  ```
- **`README.md`** — three spots in the "Upgrading Kubernetes Version" section:
  - the `kubernetes_version = "1.N"` line in the example block;
  - the `**Important**: ...` example minors, so the progression stays current
    (e.g. `1.33 → 1.34 → 1.35`);
  - replace the `### Notes for 1.<old>` heading and its bullets with `### Notes for 1.N` using
    the caveats from step 3, and update the linked EKS support announcement URL.

Do **not** hand-edit the auto-generated `terraform-docs` table further down the README — it's
regenerated by pre-commit in the next step.

### 5. Regenerate docs and validate

Run the repo's pre-commit hooks so terraform-docs, fmt, and tflint update/validate:

```bash
pre-commit run --all-files
```

If `pre-commit` isn't available, at minimum run `terraform fmt -recursive` and
`terraform validate`. Fix anything the hooks flag before committing. Re-run until clean —
terraform-docs edits the README on first pass, so a second run confirms a clean tree.

**If `terraform_validate` fails with "Module source has changed" or "Module version
requirements have changed ... Run terraform init":** this is a stale local `.terraform`
module cache, not a problem with your edit — the pinned module versions in the `.tf` files
are newer than what's cached locally (common in a fresh checkout). Refresh it and retry:

```bash
terraform init -backend=false -input=false
```

`-backend=false` means no AWS credentials are needed — it only downloads modules/providers.
This can also surface when the git pre-commit hook runs on `git commit` even if an earlier
`pre-commit run --all-files` passed, so run the init before committing. It may update
`.terraform.lock.hcl`; check `git status` and don't stage unrelated lock-file churn into
this PR (the file is usually gitignored here).

### 6. Branch, commit as breaking, open the PR

The commit **must** be marked breaking so the release is MAJOR. Use a `feat!:` subject:

```bash
git checkout -b chore/k8s-1.N
git add -A
git commit -m "feat!: bump default kubernetes version to 1.N

Advances the EKS control-plane default from 1.<old> to 1.N. This is a
backwards-incompatible change for consumers and cannot be rolled back.

BREAKING CHANGE: default kubernetes_version is now 1.N; consumers pinned to
older module majors are unaffected, but upgrading requires stepping the
control plane and reviewing the version notes in the README."
git push -u origin chore/k8s-1.N
gh pr create --fill
```

Both the `feat!:` subject and the `BREAKING CHANGE:` footer signal MAJOR to semantic-release;
including both is belt-and-suspenders and harmless.

Write the PR body to include: the version delta (`1.<old>` → `1.N`), how support was verified
(AWS CLI vs web research), the consumer-facing caveats from step 3, and a note that CI
(`tests/main`) deploys the change to real AWS for validation.

### 7. Report back

Summarize for the user: old → new version, how you confirmed EKS support, the key upgrade
caveats you found, the files changed, and the PR link. If the module was more than one minor
behind, remind them this was a single step and further MAJOR releases are needed to keep going.

## When to stop instead of proceeding

- Target minor not yet supported by EKS → report that the module is current; make no edits.
- AWS CLI unavailable **and** web research can't confirm the target is GA → ask the user how
  to proceed rather than guessing.
- The repo isn't this module (no `kubernetes_version` variable in `variables.tf`) → say so;
  this skill is specific to terraform-aws-kubernetes-platform.
