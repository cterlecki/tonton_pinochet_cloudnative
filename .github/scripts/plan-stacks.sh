#!/usr/bin/env bash
# Plan every stack in $STACKS for $ENV, write each plan to $1 (markdown), and set the `digest` step output:
# a hash of the planned changes (address + actions), so the apply job can prove it applies what was reviewed.
set -euo pipefail
summary=$1
changes=$(mktemp)

for stack in $STACKS; do
  dir="infra/$stack"
  if [ ! -d "$dir" ]; then
    [ "$stack" = monitoring ] && { echo "skip $stack (not created yet)"; continue; }
    echo "::error::$dir is missing"; exit 1
  fi
  echo "::group::plan $stack"
  args=()
  [ -f "$dir/$ENV.tfvars" ] && args+=("-var-file=$ENV.tfvars")
  terraform -chdir="$dir" init -input=false -backend-config="backends/$ENV.hcl"
  terraform -chdir="$dir" plan -input=false -no-color -lock-timeout=5m ${args[@]+"${args[@]}"} -out=tfplan
  echo "::endgroup::"

  terraform -chdir="$dir" show -json tfplan |
    jq -c --arg s "$stack" '[.resource_changes[]? | select(.change.actions != ["no-op"]) | {s: $s, a: .address, c: .change.actions}]' >> "$changes"
  {
    echo "### $stack / $ENV"
    echo '<details><summary>plan</summary>'
    echo
    echo '````'
    terraform -chdir="$dir" show -no-color tfplan | head -c 300000 || true
    echo
    echo '````'
    echo '</details>'
  } >> "$summary"
done

echo "digest=$(sha256sum "$changes" | cut -d' ' -f1)" >> "$GITHUB_OUTPUT"
