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

# Issue 1
kubectl apply -n pets -f - <<EOF
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

echo "✓ Issue 1 created"

# Issue 2
MANAGED_RG=$(az aks show \
  --name "$AKS_NAME" \
  --resource-group "$RG_NAME" \
  --query nodeResourceGroup -o tsv)

NODE_NSG=$(az network nsg list \
  --resource-group "$MANAGED_RG" \
  --query '[0].name' -o tsv)

if [[ -z "$NODE_NSG" ]]; then
  echo "❌ Error: Could not find NSG"
  exit 1
fi

EXISTING_RULE=$(az network nsg rule list \
  --resource-group "$MANAGED_RG" \
  --nsg-name "$NODE_NSG" \
  --query "[?name=='DenyAzureDNS'].name" -o tsv)

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
    --source-port-ranges '*'
fi

echo "✓ Issue 2 created"

# Issue 3: Generate and apply Kustomization patches to break store app services
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

mkdir -p "$TEMP_DIR/patches"

# Create kustomization.yaml that references the remote base
cat > "$TEMP_DIR/kustomization.yaml" <<'KUSTOM'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: pets

bases:
- https://github.com/Azure-Samples/aks-store-demo//kustomize/overlays/dev?ref=main

patchesStrategicMerge:
- patches/product-service-broken.yaml
- patches/store-front-crash.yaml
- patches/ai-service-with-ai-foundry.yaml
- patches/ai-service-account.yaml
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

# Patch 3: Deploy ai-service with Azure AI Foundry integration but broken workload identity
cat > "$TEMP_DIR/patches/ai-service-with-ai-foundry.yaml" <<'PATCH3'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ai-service
spec:
  template:
    spec:
      serviceAccountName: ai-service
      containers:
      - name: ai-service
        env:
        - name: AZURE_CLIENT_ID
          value: "00000000-0000-0000-0000-000000000000"
        - name: AZURE_TENANT_ID
          value: "00000000-0000-0000-0000-000000000000"
        - name: AZURE_AUTHORITY_HOST
          value: "https://login.microsoftonline.com/"
        - name: AI_API_BASE
          value: "${AI_API_BASE:-https://placeholder.openai.azure.com/}"
        - name: AI_API_KEY
          value: "placeholder-key-for-testing"
        resources:
          requests:
            memory: "512Mi"
          limits:
            memory: "512Mi"
PATCH3

# Patch 4: Create ServiceAccount with intentionally broken workload identity annotation
cat > "$TEMP_DIR/patches/ai-service-account.yaml" <<'PATCH4'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ai-service
  annotations:
    azure.workload.identity/client-id: "00000000-0000-0000-0000-000000000000"
PATCH4

# Apply the Kustomization
kubectl apply -k "$TEMP_DIR"

echo "✓ Issue 3 created"
echo ""
echo "✅ Cluster is now broken. Use agents to figure out what's wrong!"
echo "   (Hint: Check the source of this script if you get stuck)"
echo ""
