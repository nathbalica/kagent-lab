#!/bin/bash

set -euo pipefail

ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
ARGOCD_MANIFEST_URL="${ARGOCD_MANIFEST_URL:-https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml}"

kubectl get namespace "$ARGOCD_NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$ARGOCD_NAMESPACE"

# CRDs do Argo CD ficaram grandes o bastante para estourar a annotation
# `kubectl.kubernetes.io/last-applied-configuration` quando usamos apply client-side.
kubectl apply --server-side -n "$ARGOCD_NAMESPACE" \
  -f "$ARGOCD_MANIFEST_URL"
