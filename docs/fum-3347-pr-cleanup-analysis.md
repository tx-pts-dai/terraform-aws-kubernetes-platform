# FUM-3347: PR cleanup (`feature_destroy`) failures

Working notes for the follow-up. Repo: `tx-pts-dai/terraform-aws-kubernetes-platform`.
Sandbox account 911453050078, region eu-central-1 (`AWS_PROFILE=dai-sandbox`).
Test PR: #332, branch `fum-3347-ecr-public-login`.

## Problem

`feature_destroy` (reusable workflow `DND-IT/github-workflows/.github/workflows/tf-cleanup.yaml@v3`)
failed on every PR close since mid October 2026. Each failure left an EKS cluster plus nodes
running in the sandbox.

## Root causes (verified)

| # | Cause | Status |
|---|-------|--------|
| 1 | Anonymous pulls from `public.ecr.aws` hit the per-IP data limit (HTTP 429) when the Helm provider resolves `oci://public.ecr.aws/karpenter` at plan/refresh. Kills deploys and destroys. | Fixed in this repo (see below). Upstream change pending. |
| 2 | Helm uninstall of `karpenter_resources` (NodePool/EC2NodeClass) times out. | Fixed (terminationGracePeriod). |
| 3 | Karpenter node security group: `DependencyViolation`, ENIs of nodes that were never terminated. | Same cause as 2. |
| 4 | When the cluster is already gone but Kubernetes objects are still in state, the kubernetes/helm providers fall back to localhost and the refresh fails. | Open. |

### Causes 2 and 3 in detail

Destroy order is the reverse of create order and cannot be changed with `depends_on`:

1. `module.eks_addons` depends on `time_sleep.wait_after_karpenter`, which depends on
   `helm_release.karpenter_resources`. Nodes must exist before addons at create time, so
   at destroy time Terraform removes the addons (EBS CSI driver, kubecost) **before** the NodePool.
2. Kubecost (StatefulSet with PVCs) is deleted. Its `VolumeAttachment` objects get a deletion
   timestamp but nobody processes them: the EBS CSI controller is already gone.
3. The NodePool is deleted. Karpenter drains all nodes. Nodes without PVs terminate at once.
   Nodes with kubecost volumes stay at `VolumesDetached=Unknown` /
   `AwaitingVolumeDetachment` forever. Karpenter only skips that wait once the NodeClaim's
   `terminationGracePeriod` has elapsed, and our NodePool set none
   (`kubernetes-sigs/karpenter`, `pkg/controllers/node/termination/controller.go`,
   `awaitVolumeDetachment`).
4. Helm times out (5 min default, 15 min did not help either). The "Retry Terraform Destroy"
   step then removes the Karpenter controller and its IAM policy, so nothing can ever finish
   the node termination. Security group deletion fails on the node ENIs, the CRD uninstall
   hangs on NodeClaim finalizers, the cluster is never deleted.

Evidence: run 41666516858 (2026-11-03), live cluster `tests-main-6ae9f587`
(`kubectl get nodeclaims`, `kubectl get volumeattachments`), Karpenter source.

First hypothesis (IAM policy `karpenter_controller` destroyed before the controller) was real
but secondary: it only made the retry step worse. The `depends_on` fix for it stays.

### Side finding: orphan EBS volumes

Even successful destroys leave the kubecost volumes behind. StatefulSet PVCs survive the addon
removal, and the CSI driver is destroyed before the PV reclaim can run.

Sandbox on 2026-11-03: 34 unattached gp3 volumes, 1457 GiB, all kubecost PVCs from
`tests-main-*` / `ex-complete-*` clusters since 2026-08-24, roughly 130 USD/month.
Not cleaned up yet. Filter: `aws ec2 describe-volumes --filters Name=status,Values=available`,
tag `kubernetes.io/created-for/pvc/name`.

## Changes made (branch `fum-3347-ecr-public-login`)

- `.github/scripts/tf-pre-run.sh` + `tf_pre_run:` in `feature.yaml`, `feature-destroy.yaml`,
  `examples-cleanup.yaml`: installs AWS CLI in the dflook container, logs in to ECR Public,
  writes the Helm registry config. Verified: no 429 in deploy run 41646516378 and destroy run
  41650979735.
- `karpenter.tf`: `aws_iam_role_policy.karpenter_controller` added to `depends_on` of
  `helm_release.karpenter_release`. The helm `timeout = 900` experiment was reverted.
- `terminationGracePeriod: 2m` on every NodePool in `tests/main`, `examples/complete`
  (`default` and `balanced`), `examples/datadog`, `examples/lacework`. Not set as module
  default on purpose: it would force-kill nodes with stuck pods in every cluster.
- `tests/main`: `enable_kubecost`, its `gp3` default StorageClass and the commented kubecost
  ingress removed. The `enabled_log_types` override (reason was kubecost) removed too.

## Open items

1. Test: deploy PR #332, close it, confirm `feature_destroy` succeeds in one pass with the
   default 5 min Helm timeout.
2. Upstream: PR to `DND-IT/github-workflows` adding an opt-in `ecr_public_login` input to
   `tf-feature`, `tf-cleanup`, `tf-apply`, `tf-plan`, `tf-destroy` (same name and docs as the
   docker workflows change #171, implemented in the default `TERRAFORM_PRE_RUN`). Then drop
   `.github/scripts/tf-pre-run.sh` and the `tf_pre_run:` lines here.
3. Upstream: the "Retry Terraform Destroy" step runs blind and removes the Karpenter controller
   while nodes are still terminating. Consider a pre-destroy step (delete NodePools, wait for
   NodeClaims) or no retry for this repo.
4. Cause 4: pre-destroy state cleanup when the cluster no longer exists.
5. Sandbox cleanup: 34 orphan kubecost volumes (list above), plus leftovers of
   `tests-main-6ae9f587` if the manual destroy did not finish.
6. Orphan monitor (ticket ask): scheduled job that lists EKS clusters, instances with
   `kubernetes.io/cluster/*` tags and unattached volumes older than N hours in the sandbox.
7. FUM-3250 (sandbox nuke): reassess once 1 to 5 are done.
8. Jira FUM-3347 has the causes table and findings (comment 390561). Solutions still to be
   added after review.

## Manual recovery of a stuck cluster

```
export AWS_PROFILE=dai-sandbox AWS_REGION=eu-central-1
aws eks update-kubeconfig --name <cluster>
kubectl get nodeclaims
kubectl patch nodeclaim <names...> -p '{"metadata":{"finalizers":null}}' --type=merge
aws ec2 terminate-instances --instance-ids <ids>
```

Then run "Manual Destroy Feature Branch Test" on the branch. If the cluster is already gone,
`terraform state rm` the helm/kubernetes resources first (cause 4).
