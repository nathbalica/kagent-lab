#!/bin/bash

set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-kagent-lab}"
EXTRA_CA_CERT_PATH="${KIND_EXTRA_CA_CERT:-}"

TEMP_CERT_FILE=""

cleanup() {
  if [[ -n "$TEMP_CERT_FILE" && -f "$TEMP_CERT_FILE" ]]; then
    rm -f "$TEMP_CERT_FILE"
  fi
}

trap cleanup EXIT

require_docker() {
  if docker info >/dev/null 2>&1; then
    return 0
  fi

  cat >&2 <<'EOF'
Docker nao esta acessivel.

O kind precisa conversar com o daemon do Docker para criar os nodes do cluster.
No macOS, isso normalmente significa que o Docker Desktop ainda nao iniciou
completamente.

Verifique:
  1. Abra o Docker Desktop
  2. Espere ate aparecer "Engine running"
  3. Rode: docker info
  4. Execute novamente este script
EOF

  exit 1
}

find_netskope_ca() {
  local keychain
  local candidate

  for keychain in "/Library/Keychains/System.keychain" "$HOME/Library/Keychains/login.keychain-db"; do
    [[ -f "$keychain" ]] || continue

    candidate="$(security find-certificate -a -c Netskope -p "$keychain" 2>/dev/null || true)"
    if [[ -n "$candidate" ]]; then
      TEMP_CERT_FILE="$(mktemp "${TMPDIR:-/tmp}/netskope-ca.XXXXXX.crt")"
      printf '%s\n' "$candidate" > "$TEMP_CERT_FILE"
      echo "$TEMP_CERT_FILE"
      return 0
    fi
  done

  return 1
}

resolve_extra_ca_cert() {
  if [[ -n "$EXTRA_CA_CERT_PATH" ]]; then
    if [[ ! -f "$EXTRA_CA_CERT_PATH" ]]; then
      echo "Certificado informado em KIND_EXTRA_CA_CERT nao foi encontrado: $EXTRA_CA_CERT_PATH" >&2
      exit 1
    fi

    echo "$EXTRA_CA_CERT_PATH"
    return 0
  fi

  find_netskope_ca || true
}

install_extra_ca_on_kind_nodes() {
  local cert_path="$1"
  local node

  echo "Instalando CA extra nos nodes do kind..."

  while IFS= read -r node; do
    [[ -n "$node" ]] || continue

    echo "  - Atualizando confianca de certificados em $node"
    docker cp "$cert_path" "$node:/usr/local/share/ca-certificates/kind-extra-ca.crt"
    docker exec "$node" update-ca-certificates
    docker exec "$node" systemctl restart containerd
  done < <(kind get nodes --name "$CLUSTER_NAME")
}

echo "Criando cluster..."

require_docker

kind create cluster --name "$CLUSTER_NAME"

EXTRA_CA_CERT_PATH="$(resolve_extra_ca_cert)"
if [[ -n "$EXTRA_CA_CERT_PATH" ]]; then
  install_extra_ca_on_kind_nodes "$EXTRA_CA_CERT_PATH"
else
  echo "Nenhuma CA extra encontrada. Se voce usa proxy TLS corporativo, defina KIND_EXTRA_CA_CERT=/caminho/para/ca.crt"
fi

kubectl cluster-info

echo "Cluster pronto"
