# kagent-lab

Lab local para testar `kagent` em um cluster `kind`.

## O que funcionou neste ambiente

O caminho que funcionou foi:

1. Criar o cluster `kind`
2. Instalar o Argo CD
3. Instalar os CRDs do `kagent`
4. Instalar o chart local do `kagent` com `helm`

Observacao: o deploy do chart via GHCR/Argo CD ficou sensivel ao proxy/certificado corporativo. Para continuar trabalhando sem depender disso, o fluxo mais confiavel foi instalar o chart local extraido em `charts/kagent`.

## Pre-requisitos

- `docker`
- `kind`
- `kubectl`
- `helm`
- certificado corporativo exportado em PEM
- arquivo local `scripts/.ghcr.env` com credenciais do GHCR

Exemplo de `scripts/.ghcr.env`:

```bash
GHCR_USERNAME="seu-usuario-github"
GHCR_TOKEN="seu-token-com-read-packages"
```

## Subir tudo de novo amanha

### 1. Criar o cluster

Use o certificado exportado do Netskope/goskope:

```bash
KIND_EXTRA_CA_CERT=~/Documents/'*.dfw3.goskope.com.pem' bash scripts/create-cluster.sh
```

### 2. Instalar o Argo CD

```bash
bash scripts/destroy-cluster.sh

KIND_EXTRA_CA_CERT=/Users/natanaele.balica/Documents/*.dfw3.goskope.com.pem bash scripts/create-cluster.sh
KIND_EXTRA_CA_CERT=/Users/natanaele.balica/Documents/*.dfw3.goskope.com.pem bash scripts/install-argocd.sh

kubectl get pods -n argocd
kubectl get pods -n argocd
```

Espere os pods do `argocd` ficarem `Running`.

kubectl get pods -n argocd


### 3. Instalar os CRDs do kagent

```bash
bash scripts/install-kagent-crds.sh
kubectl get crd | grep kagent.dev
```

### 4. Instalar o kagent localmente

```bash
bash scripts/install-kagent-local.sh
kubectl get pods -n kagent
kubectl get svc -n kagent
```

### 5. Acessar a UI

Quando o service `kagent-ui` existir:

```bash
kubectl port-forward -n kagent svc/kagent-ui 8082:8080
```

Abra:

```text
http://localhost:8082
```

## Links e acessos de amanha

### Argo CD UI

Port-forward:

```bash
kubectl port-forward -n argocd svc/argocd-server 8080:80
```

Abrir:

```text
http://localhost:8080
```

### kagent UI

Port-forward:

```bash
kubectl port-forward -n kagent svc/kagent-ui 8082:8080
```

Abrir:

```text
http://localhost:8082
```

### Repo do lab

```text
https://github.com/nathbalica/kagent-lab
```

### Chart OCI que estavamos usando

```text
oci://ghcr.io/kagent-dev/kagent/helm/kagent
```

### Blob host que deu problema de certificado

```text
https://pkg-containers.githubusercontent.com
```

## Validacao rapida

Ver pods do Argo CD:

```bash
kubectl get pods -n argocd
```

Ver pods do kagent:

```bash
kubectl get pods -n kagent
```

Ver tudo no namespace do kagent:

```bash
kubectl get all -n kagent
```

Ver eventos se algo travar:

```bash
kubectl get events -n kagent --sort-by=.lastTimestamp
```

## Parar hoje e continuar amanha

Se voce so vai desligar o Mac e quer recomecar limpo amanha, o caminho mais simples e destruir o cluster:

```bash
bash scripts/destroy-cluster.sh
```

Isso remove do cluster:

- Argo CD
- kagent
- CRDs do kagent
- services, pods e secrets no Kubernetes

Os arquivos locais continuam no repo:

- `charts/kagent`
- `scripts/.ghcr.env`
- scripts do lab

## Limpeza mais agressiva

Se quiser limpar tambem cache/imagens/volumes do Docker:

```bash
bash scripts/cleanup-lab.sh
```

## Scripts uteis

- `scripts/create-cluster.sh`: cria o cluster `kind` e injeta a CA corporativa no node
- `scripts/install-argocd.sh`: instala o Argo CD
- `scripts/install-kagent-crds.sh`: instala os CRDs do `kagent`
- `scripts/install-kagent-local.sh`: instala o chart local do `kagent`
- `scripts/destroy-cluster.sh`: remove o cluster `kind`
- `scripts/cleanup-lab.sh`: limpeza mais agressiva do ambiente local

## Fluxo recomendado

Para recomecar rapido:

```bash
KIND_EXTRA_CA_CERT=~/Documents/'*.dfw3.goskope.com.pem' bash scripts/create-cluster.sh
KIND_EXTRA_CA_CERT=~/Documents/'*.dfw3.goskope.com.pem' bash scripts/install-argocd.sh
bash scripts/install-kagent-crds.sh
bash scripts/install-kagent-local.sh
```
