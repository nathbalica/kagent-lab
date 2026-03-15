#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

kubectl delete secret -n argocd ghcr-oci-creds --ignore-not-found
bash "$SCRIPT_DIR/configure-argocd-ghcr.sh"
kubectl rollout status deployment/argocd-repo-server -n argocd
kubectl annotate application -n argocd kagent-chart argocd.argoproj.io/refresh=hard --overwrite
kubectl describe application -n argocd kagent-chart
kubectl get pods -n kagent
