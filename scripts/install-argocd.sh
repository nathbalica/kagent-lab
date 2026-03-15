#!/bin/bash

set -euo pipefail

ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
ARGOCD_MANIFEST_URL="${ARGOCD_MANIFEST_URL:-https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml}"
ARGOCD_TLS_CERT_PATH="${ARGOCD_TLS_CERT_PATH:-${KIND_EXTRA_CA_CERT:-}}"
ARGOCD_TLS_HOSTS="${ARGOCD_TLS_HOSTS:-ghcr.io,pkg-containers.githubusercontent.com}"
ARGOCD_IMAGE="${ARGOCD_IMAGE:-quay.io/argoproj/argocd:v3.3.3}"

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
  temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/argocd-tls-certs.XXXXXX")"
  trap 'rm -f "$temp_configmap"; rm -rf "$temp_dir"' EXIT

  IFS=',' read -r -a tls_hosts <<< "$ARGOCD_TLS_HOSTS"

  configmap_args=(
    create configmap argocd-tls-certs-cm
    -n "$ARGOCD_NAMESPACE"
    --dry-run=client
    -o yaml
  )

  for tls_host in "${tls_hosts[@]}"; do
    tls_host="$(echo "$tls_host" | xargs)"
    [[ -n "$tls_host" ]] || continue
    cp "$ARGOCD_TLS_CERT_PATH" "$temp_dir/$tls_host"
    configmap_args+=(--from-file="$tls_host=$temp_dir/$tls_host")
  done

  kubectl "${configmap_args[@]}" > "$temp_configmap"

  kubectl apply --server-side -f "$temp_configmap"
  kubectl patch deployment argocd-repo-server \
    -n "$ARGOCD_NAMESPACE" \
    --type strategic \
    -p "{
      \"spec\": {
        \"template\": {
          \"spec\": {
            \"initContainers\": [
              {
                \"name\": \"argocd-repo-server-ca-bundle\",
                \"image\": \"$ARGOCD_IMAGE\",
                \"command\": [\"/bin/sh\", \"-c\"],
                \"args\": [
                  \"cat /etc/ssl/certs/ca-certificates.crt /app/config/tls/* > /custom-certs/ca-certificates.crt\"
                ],
                \"volumeMounts\": [
                  {
                    \"name\": \"tls-certs\",
                    \"mountPath\": \"/app/config/tls\",
                    \"readOnly\": true
                  },
                  {
                    \"name\": \"custom-ca-bundle\",
                    \"mountPath\": \"/custom-certs\"
                  }
                ]
              }
            ],
            \"containers\": [
              {
                \"name\": \"argocd-repo-server\",
                \"env\": [
                  {
                    \"name\": \"SSL_CERT_FILE\",
                    \"value\": \"/custom-certs/ca-certificates.crt\"
                  }
                ],
                \"volumeMounts\": [
                  {
                    \"name\": \"custom-ca-bundle\",
                    \"mountPath\": \"/custom-certs\"
                  }
                ]
              }
            ],
            \"volumes\": [
              {
                \"name\": \"custom-ca-bundle\",
                \"emptyDir\": {}
              }
            ]
          }
        }
      }
    }"
  kubectl rollout restart deployment/argocd-repo-server -n "$ARGOCD_NAMESPACE"
fi
