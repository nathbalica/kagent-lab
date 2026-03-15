#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GHCR_ENV_FILE="${GHCR_ENV_FILE:-$SCRIPT_DIR/.ghcr.env}"

if [[ -f "$GHCR_ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$GHCR_ENV_FILE"
fi

ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
SECRET_NAME="${SECRET_NAME:-ghcr-oci-creds}"
REPO_CREDS_SECRET_NAME="${REPO_CREDS_SECRET_NAME:-ghcr-oci-repo-creds}"
GHCR_REGISTRY_URL="${GHCR_REGISTRY_URL:-ghcr.io}"
GHCR_REPO_URL="${GHCR_REPO_URL:-oci://ghcr.io/kagent-dev/kagent/helm/kagent}"
DEFAULT_GHCR_USERNAME=""
DEFAULT_GHCR_TOKEN=""
GHCR_USERNAME="${GHCR_USERNAME:-${GITHUB_USERNAME:-$DEFAULT_GHCR_USERNAME}}"
GHCR_TOKEN="${GHCR_TOKEN:-${GITHUB_TOKEN:-$DEFAULT_GHCR_TOKEN}}"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/argocd-ghcr.XXXXXX")"

cleanup() {
  rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

if [[ -z "$GHCR_USERNAME" ]]; then
  echo "Defina GHCR_USERNAME ou GITHUB_USERNAME com seu usuario do GitHub." >&2
  exit 1
fi

if [[ -z "$GHCR_TOKEN" ]]; then
  echo "Defina GHCR_TOKEN/GITHUB_TOKEN ou crie $GHCR_ENV_FILE com um token que tenha read:packages." >&2
  exit 1
fi

create_secret_manifest() {
  local secret_name="$1"
  local secret_type="$2"
  local secret_url="$3"
  local output_file="$4"

  kubectl create secret generic "$secret_name" \
    -n "$ARGOCD_NAMESPACE" \
    --from-literal=url="$secret_url" \
    --from-literal=type=oci \
    --from-literal=name="$secret_name" \
    --from-literal=enableOCI=true \
    --from-literal=username="$GHCR_USERNAME" \
    --from-literal=password="$GHCR_TOKEN" \
    --from-literal=ForceHttpBasicAuth=true \
    --dry-run=client \
    -o yaml > "$output_file"

  kubectl label --local -f "$output_file" \
    argocd.argoproj.io/secret-type="$secret_type" \
    -o yaml > "${output_file}.labeled"
}

kubectl delete secret -n "$ARGOCD_NAMESPACE" "$SECRET_NAME" --ignore-not-found
kubectl delete secret -n "$ARGOCD_NAMESPACE" "$REPO_CREDS_SECRET_NAME" --ignore-not-found

create_secret_manifest "$SECRET_NAME" "repository" "$GHCR_REPO_URL" "$TEMP_DIR/repository.yaml"
create_secret_manifest "$REPO_CREDS_SECRET_NAME" "repo-creds" "$GHCR_REGISTRY_URL" "$TEMP_DIR/repo-creds.yaml"

kubectl apply -f "$TEMP_DIR/repository.yaml.labeled"
kubectl apply -f "$TEMP_DIR/repo-creds.yaml.labeled"

kubectl rollout restart deployment/argocd-repo-server -n "$ARGOCD_NAMESPACE"

echo "Credenciais do GHCR aplicadas no Argo CD."
