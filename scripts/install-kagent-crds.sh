#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GHCR_ENV_FILE="${GHCR_ENV_FILE:-$SCRIPT_DIR/.ghcr.env}"
NAMESPACE="${NAMESPACE:-kagent}"
RELEASE_NAME="${RELEASE_NAME:-kagent-crds}"
CRDS_CHART="${CRDS_CHART:-oci://ghcr.io/kagent-dev/kagent/helm/kagent-crds}"
CRDS_VERSION="${CRDS_VERSION:-0.8.0-beta6}"

if [[ -f "$GHCR_ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$GHCR_ENV_FILE"
fi

GHCR_USERNAME="${GHCR_USERNAME:-${GITHUB_USERNAME:-}}"
GHCR_TOKEN="${GHCR_TOKEN:-${GITHUB_TOKEN:-}}"

if [[ -n "${GHCR_TOKEN:-}" && -n "${GHCR_USERNAME:-}" ]]; then
  echo "$GHCR_TOKEN" | helm registry login ghcr.io -u "$GHCR_USERNAME" --password-stdin >/dev/null
fi

helm upgrade --install "$RELEASE_NAME" "$CRDS_CHART" \
  --version "$CRDS_VERSION" \
  --namespace "$NAMESPACE" \
  --create-namespace

kubectl get crd | grep kagent.dev || true
