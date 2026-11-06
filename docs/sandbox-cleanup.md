# Sandbox workspace cleanup

PRs in this repo deploy `tests/main` and the examples to the DAI sandbox account `911453050078` (`eu-central-1`). Each PR gets its own Terraform workspace, named after the PR branch with `/` replaced by `-`. The PR-close jobs (`feature_destroy`, `example_*_destroy`) destroy the workspace when the PR closes. A workspace stays behind when that destroy fails, when someone deploys by hand, or when a PR sits open without work.

The `Sandbox Cleanup` workflow (`.github/workflows/sandbox-cleanup.yaml`) finds those workspaces every Friday and destroys them.

Jira: FUM-3347.

## How it works

### Job `plan`

Runs `.github/scripts/sandbox-cleanup-plan.sh`. The script only reads data.

1. Lists the state files in `s3://tf-state-911453050078/terraform-aws-kubernetes-platform/`. Each key `<workspace>/<tf_dir>.tfstate` is one workspace, for example `my-branch/tests/main.tfstate`. Lock files are ignored.
2. Lists the last 200 PRs (open and closed) and maps each branch to its workspace name. Stops with an error if the list is empty, otherwise every workspace would look like it has no PR.
3. Decides for each workspace. The first matching rule wins:

    | Rule | Decision | Reason | Destroy checks out |
    | --- | --- | --- | --- |
    | Workspace is in `PROTECTED_WORKSPACES` (`main`, `default`) | keep | `protected` | - |
    | A workflow run on the branch is not finished | keep | `in-progress` | - |
    | No PR for the branch | destroy | `no-pr` | `main` |
    | PR is closed or merged | destroy | `closed-pr` | `refs/pull/<n>/head` |
    | PR is open, head commit older than `STALE_DAYS` | destroy | `stale-pr` | `refs/pull/<n>/head` |
    | PR is open, head commit is recent | keep | `active` | - |

4. Writes the result:
    - Job summary: a table with every workspace and its decision.
    - Artifact `workspace-plan`: `workspaces.json` (all workspaces) and `matrix.json` (only those to destroy).
    - Job outputs: `matrix`, `total`, `to_destroy`, `dry_run`.

### Job `destroy`

Runs only when dry run is off and `to_destroy` is not `0`. Calls `DND-IT/github-workflows` `tf-cleanup.yaml@tf-cleanup-v0` once per workspace, at most 2 at a time, with `tf_workspace`, `tf_dir` and `gh_checkout_ref` from the matrix. This is the same destroy the PR-close jobs use. A failed workspace does not stop the others.

### Jobs `notify-failure` and `notify-success`

| Job | When | Channel |
| --- | --- | --- |
| `notify-failure` | `plan` or `destroy` failed, any trigger | `#t_pts_dai_warning` (`C01EHPC4P29`) |
| `notify-success` | scheduled run, `plan` succeeded, `destroy` succeeded or was skipped | `#it_pts_dai_logs` (`C09JRFAB73J`) |

Both messages show the workspace count, the number to destroy, and the destroy result.

## Settings

| Setting | Where | Value |
| --- | --- | --- |
| Schedule | `on.schedule` | `0 16 * * 5` (Friday 16:00 UTC) |
| Dry run default | workflow-level `env.DRY_RUN` | `"true"` (only report) |
| Dry run for one run | `workflow_dispatch` input `dry_run` | overrides `env.DRY_RUN` |
| Stale threshold | `workflow_dispatch` input `stale_days` | `7` (the schedule always uses 7) |
| State bucket and prefix | `plan` step `env` (`STATE_BUCKET`, `STATE_PREFIX`) | `tf-state-911453050078`, `terraform-aws-kubernetes-platform/` |
| Protected workspaces | `plan` step `env` (`PROTECTED_WORKSPACES`) | `main default` |
| AWS role and region | GitHub environment `examples` (`AWS_OIDC_ROLE_ARN`, `AWS_REGION`) | `cicd-iac`, `eu-central-1` |

All script settings come from the `plan` step `env`. The script has no defaults and stops if one is missing or empty.

### Turn on real destroys

Open a PR that sets `DRY_RUN: "false"` in the workflow-level `env` of `sandbox-cleanup.yaml`. Do this after a few scheduled dry runs show the expected workspaces.

### Run by hand

```bash
gh workflow run sandbox-cleanup.yaml -f dry_run=true
gh workflow run sandbox-cleanup.yaml -f dry_run=false -f stale_days=14
```

`workflow_dispatch` only works once the workflow file is on `main`.

## Test

### Locally against the real bucket

Needs `aws`, `gh` and `jq`, an `aws sso login --profile dai-sandbox` session, and `gh auth status` logged in. The script only reads data.

```bash
export AWS_PROFILE=dai-sandbox
export GITHUB_REPOSITORY=tx-pts-dai/terraform-aws-kubernetes-platform
export STATE_BUCKET=tf-state-911453050078
export STATE_PREFIX=terraform-aws-kubernetes-platform/
export STALE_DAYS=7
export DRY_RUN=true
export PROTECTED_WORKSPACES="main default"
export OUT_DIR=$(mktemp -d)
export GITHUB_OUTPUT=$OUT_DIR/github-output.txt
export GITHUB_STEP_SUMMARY=$OUT_DIR/summary.md

.github/scripts/sandbox-cleanup-plan.sh
cat "$GITHUB_STEP_SUMMARY"
cat "$GITHUB_OUTPUT"
jq . "$OUT_DIR/workspaces.json"
```

The script appends to `GITHUB_OUTPUT` and `GITHUB_STEP_SUMMARY`, as GitHub Actions expects. Empty both files before running it again: `: > "$GITHUB_OUTPUT"; : > "$GITHUB_STEP_SUMMARY"`.

### Locally with dummy state files

When the bucket has no workspaces, upload empty states to see every rule. An empty state has no resources, so even a real destroy of it only deletes the workspace.

```bash
B=tf-state-911453050078
P=terraform-aws-kubernetes-platform
cat > "$OUT_DIR/empty.tfstate" <<'EOF'
{"version":4,"terraform_version":"1.13.0","serial":1,"lineage":"00000000-0000-0000-0000-000000000000","outputs":{},"resources":[],"check_results":null}
EOF

for k in sandbox-cleanup-test/tests/main <closed-pr-branch>/examples/complete <open-pr-branch>/tests/main main/tests/main; do
  aws s3 cp "$OUT_DIR/empty.tfstate" "s3://$B/$P/$k.tfstate"
done

.github/scripts/sandbox-cleanup-plan.sh
cat "$GITHUB_STEP_SUMMARY"
```

Replace `<closed-pr-branch>` and `<open-pr-branch>` with the workspace names of a merged PR and an open PR. Expected: `sandbox-cleanup-test` -> `no-pr`, the merged PR -> `closed-pr`, the open PR -> `active` (`stale-pr` with `STALE_DAYS=0`), `main` -> `protected`.

Remove the dummy states afterwards:

```bash
for k in sandbox-cleanup-test/tests/main <closed-pr-branch>/examples/complete <open-pr-branch>/tests/main main/tests/main; do
  aws s3 rm "s3://$B/$P/$k.tfstate"
done
```

### In GitHub Actions

1. Upload only `sandbox-cleanup-test/tests/main.tfstate` as above.
2. `gh workflow run sandbox-cleanup.yaml -f dry_run=true`. Check the job summary and the `workspace-plan` artifact (`gh run download <run-id>`).
3. `gh workflow run sandbox-cleanup.yaml -f dry_run=false`. The `destroy` job runs `tf-cleanup` on the empty state and deletes the workspace.
4. Run the dry run again. It should report `Workspaces: 0`.

## Known limits

- A `no-pr` workspace is destroyed with the code from `main`, which may not match what deployed it. `tf-cleanup` retries once. If it still fails, `notify-failure` reports it; destroy it by hand with `feature-destroy.yaml` or `examples-cleanup.yaml` from a fitting commit.
- Only the last 200 PRs are checked. A workspace from an older PR counts as `no-pr`.
- The workflow and the PR-close jobs use different concurrency groups. The `in-progress` rule and the S3 lock file (`use_lockfile`) prevent two destroys on the same workspace.
