#!/bin/bash

set -euo pipefail

ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
ARGOCD_MANIFEST_URL="${ARGOCD_MANIFEST_URL:-https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml}"
ARGOCD_TLS_CERT_PATH="${ARGOCD_TLS_CERT_PATH:-${KIND_EXTRA_CA_CERT:-}}"
ARGOCD_TLS_HOST="${ARGOCD_TLS_HOST:-ghcr.io}"

kubectl get namespace "$ARGOCD_NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$ARGOCD_NAMESPACE"

# CRDs do Argo CD ficaram grandes o bastante para estourar a annotation
# `kubectl.kubernetes.io/last-applied-configuration` quando usamos apply client-side.
kubectl apply --server-side -n "$ARGOCD_NAMESPACE" \
  -f "$ARGOCD_MANIFEST_URL"

if [[ -n "$ARGOCD_TLS_CERT_PATH" ]]; then
  if [[ ! -f "$ARGOCD_TLS_CERT_PATH" ]]; then
    echo "Certificado informado em ARGOCD_TLS_CERT_PATH/KIND_EXTRA_CA_CERT nao foi encontrado: $ARGOCD_TLS_CERT_PATH" >&2
    exit 1
  fi

  temp_configmap="$(mktemp "${TMPDIR:-/tmp}/argocd-tls-certs.XXXXXX.yaml")"
  trap 'rm -f "$temp_configmap"' EXIT

  kubectl create configmap argocd-tls-certs-cm \
    -n "$ARGOCD_NAMESPACE" \
    --from-file="$ARGOCD_TLS_HOST=$ARGOCD_TLS_CERT_PATH" \
    --dry-run=client \
    -o yaml > "$temp_configmap"

  kubectl apply --server-side -f "$temp_configmap"
  kubectl rollout restart deployment/argocd-repo-server -n "$ARGOCD_NAMESPACE"
fi
