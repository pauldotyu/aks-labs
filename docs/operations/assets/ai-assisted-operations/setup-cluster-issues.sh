#!/bin/bash
set -euo pipefail

# Script to break the cluster in interesting ways for troubleshooting practice
# If you're curious what this does, read the source code!
# If you get stuck, just run cleanup-cluster-issues.sh to restore the cluster

echo "🔧 Breaking cluster..."
echo ""

# Validate environment variables
if [[ -z "${AKS_NAME:-}" ]] || [[ -z "${RG_NAME:-}" ]]; then
  echo "❌ Error: AKS_NAME and RG_NAME environment variables must be set"
  exit 1
fi

# Issue 1: NetworkPolicy blocking all ingress in pets namespace
kubectl apply -n pets -f - > /dev/null <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: pets
spec:
  podSelector: {}
  policyTypes:
  - Ingress
EOF

echo "✓ Issue 1 setup completed"

# Issue 2: NSG rule blocking Azure DNS
MANAGED_RG=$(az aks show \
  --name "$AKS_NAME" \
  --resource-group "$RG_NAME" \
  --query nodeResourceGroup -o tsv 2> /dev/null)

NODE_NSG=$(az network nsg list \
  --resource-group "$MANAGED_RG" \
  --query '[0].name' -o tsv 2> /dev/null)

if [[ -z "$NODE_NSG" ]]; then
  echo "❌ Error: Could not find NSG"
  exit 1
fi

EXISTING_RULE=$(az network nsg rule list \
  --resource-group "$MANAGED_RG" \
  --nsg-name "$NODE_NSG" \
  --query "[?name=='DenyAzureDNS'].name" -o tsv 2> /dev/null)

if [[ -z "$EXISTING_RULE" ]]; then
  az network nsg rule create \
    --resource-group "$MANAGED_RG" \
    --nsg-name "$NODE_NSG" \
    --name DenyAzureDNS \
    --direction Outbound \
    --priority 100 \
    --destination-address-prefixes "168.63.129.16" \
    --access Deny \
    --protocol '*' \
    --destination-port-ranges '*' \
    --source-address-prefixes '*' \
    --source-port-ranges '*' > /dev/null
fi

echo "✓ Issue 2 setup completed"

# Issue 3: Break store app services and deploy broken ai-service
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

mkdir -p "$TEMP_DIR/patches"

# Kustomization to patch existing services (product-service, store-front)
# ai-service is not in the dev overlay base, so it is deployed separately below
cat > "$TEMP_DIR/kustomization.yaml" <<'KUSTOM'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: pets

resources:
- https://github.com/Azure-Samples/aks-store-demo//kustomize/overlays/dev?ref=main

patches:
- path: patches/product-service-broken.yaml
- path: patches/store-front-crash.yaml
KUSTOM

# Patch 1: Break product-service by referencing a non-existent ConfigMap
cat > "$TEMP_DIR/patches/product-service-broken.yaml" <<'PATCH1'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: product-service
spec:
  template:
    spec:
      containers:
      - name: product-service
        envFrom:
        - configMapRef:
            name: product-db-config-missing
PATCH1

# Patch 2: Break store-front with a bad liveness probe
cat > "$TEMP_DIR/patches/store-front-crash.yaml" <<'PATCH2'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: store-front
spec:
  template:
    spec:
      containers:
      - name: store-front
        livenessProbe:
          tcpSocket:
            port: 9999
          initialDelaySeconds: 5
          periodSeconds: 10
PATCH2

# Apply the kustomization for existing service patches
kubectl apply -k "$TEMP_DIR" > /dev/null

# Deploy ai-service as a standalone resource with broken workload identity
# Uses an unquoted heredoc so AI_API_BASE is expanded at runtime
kubectl apply -n pets -f - > /dev/null <<AIEOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ai-service
  namespace: pets
  annotations:
    azure.workload.identity/client-id: "00000000-0000-0000-0000-000000000000"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ai-service
  namespace: pets
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ai-service
  template:
    metadata:
      labels:
        app: ai-service
    spec:
      serviceAccountName: ai-service
      containers:
      - name: ai-service
        image: ghcr.io/azure-samples/aks-store-demo/ai-service:latest
        ports:
        - containerPort: 5001
        env:
        - name: USE_AZURE_OPENAI
          value: "True"
        - name: AZURE_OPENAI_DEPLOYMENT_NAME
          value: "gpt-5-mini"
        - name: AZURE_OPENAI_ENDPOINT
          value: "${AI_API_BASE:-https://placeholder.openai.azure.com/}"
        - name: USE_AZURE_AD
          value: "True"
        resources:
          requests:
            memory: "512Mi"
          limits:
            memory: "512Mi"
AIEOF

echo "✓ Issue 3 setup completed"
echo ""
echo "✅ Cluster is now broken. Use agents to figure out what's wrong!"
echo "   (Hint: Check the source of this script if you get stuck)"
echo ""
