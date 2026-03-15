#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NAMESPACE="${NAMESPACE:-kagent}"
RELEASE_NAME="${RELEASE_NAME:-kagent}"
CHART_PATH="${CHART_PATH:-$REPO_ROOT/charts/kagent}"

if [[ ! -f "$CHART_PATH/Chart.yaml" ]]; then
  echo "Chart nao encontrado em $CHART_PATH" >&2
  exit 1
fi

kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$NAMESPACE"

helm upgrade --install "$RELEASE_NAME" "$CHART_PATH" \
  --namespace "$NAMESPACE" \
  --create-namespace

kubectl get all -n "$NAMESPACE"
