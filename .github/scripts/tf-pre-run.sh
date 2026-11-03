#!/usr/bin/env bash
# Temporary pre-run for the DND-IT tf-feature/tf-cleanup workflows (FUM-3347).
# Re-installs the AWS CLI like the upstream default and logs in to ECR Public so the
# Helm provider pulls charts with an authenticated quota. Remove once upstream
# exposes an ecr_public_login input.
set -euo pipefail

AWS_CLI_VERSION=2.15.36
curl -sS "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWS_CLI_VERSION}.zip" -o awscliv2.zip
unzip -qq -o awscliv2.zip
./aws/install

REGISTRY_CONFIG="${HELM_REGISTRY_CONFIG:-${HOME:-/root}/.config/helm/registry/config.json}"
mkdir -p "$(dirname "$REGISTRY_CONFIG")"
TOKEN="$(aws ecr-public get-login-password --region us-east-1)"
AUTH="$(printf 'AWS:%s' "$TOKEN" | base64 | tr -d '\n')"
printf '{"auths":{"public.ecr.aws":{"auth":"%s"}}}\n' "$AUTH" > "$REGISTRY_CONFIG"
echo "Logged in to public.ecr.aws (registry config: $REGISTRY_CONFIG)"
