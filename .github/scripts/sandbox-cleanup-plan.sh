#!/usr/bin/env bash
set -euo pipefail

# Required settings, set by the runner and the workflow step env. Empty values stop the script.
: "${GITHUB_REPOSITORY:?}"
: "${GITHUB_OUTPUT:?}"
: "${GITHUB_STEP_SUMMARY:?}"
: "${STATE_BUCKET:?}"
: "${STATE_PREFIX:?}"
: "${STALE_DAYS:?}"
: "${DRY_RUN:?}"
: "${PROTECTED_WORKSPACES:?}"
: "${OUT_DIR:?}"

mkdir -p "$OUT_DIR"

# List state files as {workspace, tf_dir}, e.g. my-branch/tests/main.tfstate.
aws s3api list-objects-v2 \
  --bucket "$STATE_BUCKET" \
  --prefix "$STATE_PREFIX" \
  --query 'Contents[].Key' \
  --output json |
  jq --arg prefix "$STATE_PREFIX" '
    [ (. // [])[]
      | select(endswith(".tfstate"))
      | ltrimstr($prefix)
      | capture("^(?<workspace>[^/]+)/(?<tf_dir>.+)\\.tfstate$")
    ]' >"$OUT_DIR/states.json"

# Get open and closed PRs. Stop if the list is empty, otherwise every workspace would look like it has no PR.
gh pr list \
  --repo "$GITHUB_REPOSITORY" \
  --state all \
  --limit 200 \
  --json number,state,headRefName,headRefOid,updatedAt >"$OUT_DIR/prs.json"

if [[ $(jq length "$OUT_DIR/prs.json") -eq 0 ]]; then
  echo "Aborting: gh pr list returned no pull requests" >&2
  exit 1
fi

# Map each PR branch to its workspace name (/ -> -, as tf-feature does). Prefer the open PR, then the newest.
jq '
  map(. + { workspace: (.headRefName | gsub("/"; "-")) })
  | group_by(.workspace)
  | map(sort_by((.state == "OPEN"), .updatedAt) | last)
' "$OUT_DIR/prs.json" >"$OUT_DIR/pr-by-workspace.json"

# Decide keep or destroy for each workspace.
: >"$OUT_DIR/workspaces.jsonl"
while IFS= read -r state; do
  workspace=$(jq -r .workspace <<<"$state")
  pr=$(jq -c --arg ws "$workspace" '.[] | select(.workspace == $ws)' "$OUT_DIR/pr-by-workspace.json")

  # Count unfinished workflow runs on the branch, and get the head commit date of an open PR.
  last_commit=""
  running=0
  if [[ -n "$pr" ]]; then
    branch=$(jq -r .headRefName <<<"$pr")
    running=$(gh run list --repo "$GITHUB_REPOSITORY" --branch "$branch" --limit 20 --json status \
      --jq '[.[] | select(.status != "completed")] | length')
    if [[ $(jq -r .state <<<"$pr") == "OPEN" ]]; then
      last_commit=$(gh api "repos/$GITHUB_REPOSITORY/commits/$(jq -r .headRefOid <<<"$pr")" --jq .commit.committer.date)
    fi
  fi

  # Rules, first match wins: protected, in-progress, no-pr, closed-pr, stale-pr, active.
  jq -n -c \
    --argjson state "$state" \
    --argjson pr "${pr:-null}" \
    --arg last_commit "$last_commit" \
    --argjson running "$running" \
    --argjson stale_days "$STALE_DAYS" \
    --arg protected "$PROTECTED_WORKSPACES" '
    ($state + {
      pr: $pr.number,
      pr_state: $pr.state,
      last_commit: (if $last_commit == "" then null else $last_commit end)
    }) as $ws
    | if ($protected | split(" ") | index($ws.workspace)) != null then
        $ws + { decision: "keep", reason: "protected", checkout_ref: null }
      elif $running > 0 then
        $ws + { decision: "keep", reason: "in-progress", checkout_ref: null }
      elif $pr == null then
        $ws + { decision: "destroy", reason: "no-pr", checkout_ref: "main" }
      elif $pr.state != "OPEN" then
        $ws + { decision: "destroy", reason: "closed-pr", checkout_ref: "refs/pull/\($pr.number)/head" }
      elif (now - ($last_commit | fromdateiso8601)) > ($stale_days * 86400) then
        $ws + { decision: "destroy", reason: "stale-pr", checkout_ref: "refs/pull/\($pr.number)/head" }
      else
        $ws + { decision: "keep", reason: "active", checkout_ref: null }
      end
  ' >>"$OUT_DIR/workspaces.jsonl"
done < <(jq -c '.[]' "$OUT_DIR/states.json")

jq -s . "$OUT_DIR/workspaces.jsonl" >"$OUT_DIR/workspaces.json"

# Destroy list for the workflow matrix.
jq -c '[.[] | select(.decision == "destroy") | {workspace, tf_dir, checkout_ref, reason}]' \
  "$OUT_DIR/workspaces.json" >"$OUT_DIR/matrix.json"

total=$(jq length "$OUT_DIR/workspaces.json")
to_destroy=$(jq length "$OUT_DIR/matrix.json")

# Job outputs.
{
  echo "matrix=$(cat "$OUT_DIR/matrix.json")"
  echo "total=$total"
  echo "to_destroy=$to_destroy"
  echo "dry_run=$DRY_RUN"
} >>"$GITHUB_OUTPUT"

# Table in the job summary.
{
  echo "## Sandbox workspaces"
  echo
  echo "Dry run: \`$DRY_RUN\`. Workspaces: $total. To destroy: $to_destroy. Stale after $STALE_DAYS days without a commit."
  echo
  if [[ "$total" -gt 0 ]]; then
    echo "| Workspace | Directory | PR | PR state | Last commit | Decision | Reason | Checkout ref |"
    echo "|---|---|---|---|---|---|---|---|"
    jq -r '.[] | "| \(.workspace) | \(.tf_dir) | \(.pr // "-") | \(.pr_state // "-") | \(.last_commit // "-") | \(.decision) | \(.reason) | \(.checkout_ref // "-") |"' \
      "$OUT_DIR/workspaces.json"
  fi
} >>"$GITHUB_STEP_SUMMARY"
