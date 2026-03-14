#!/bin/bash

echo "==== Limpando laboratório kagent ===="

echo "Removendo cluster kind..."
kind delete cluster --name kagent-lab 2>/dev/null

echo "Removendo containers docker parados..."
docker container prune -f

echo "Removendo imagens docker não utilizadas..."
docker image prune -a -f

echo "Removendo volumes docker..."
docker volume prune -f

echo "Removendo modelos Ollama..."
ollama rm llama3 2>/dev/null
ollama rm qwen2.5 2>/dev/null
ollama rm deepseek-coder 2>/dev/null

echo "Removendo cache do Ollama..."
rm -rf ~/.ollama/models

# echo "Removendo diretório do laboratório..."
# rm -rf ~/Documents/estudo/kagent-lab

echo "==== Limpeza concluída ===="