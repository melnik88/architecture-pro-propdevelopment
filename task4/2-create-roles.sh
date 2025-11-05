#!/bin/bash

# Скрипт для создания ролей Kubernetes RBAC
# Для PropDevelopment

set -e

echo "==============================="
echo "Создание ролей Kubernetes RBAC"
echo "==============================="

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Директория для манифестов
MANIFESTS_DIR="./k8s-rbac-manifests"
mkdir -p "$MANIFESTS_DIR"

echo -e "\n${BLUE}Манифесты будут сохранены в: $MANIFESTS_DIR${NC}"

# =================================
# 1. Создание namespace
# =================================

echo -e "\n${YELLOW}=== Создание namespace ===${NC}"

cat > "$MANIFESTS_DIR/namespaces.yaml" << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: sales
  labels:
    domain: sales
    environment: production
---
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-services
  labels:
    domain: tenant-services
    environment: production
---
apiVersion: v1
kind: Namespace
metadata:
  name: finance
  labels:
    domain: finance
    environment: production
---
apiVersion: v1
kind: Namespace
metadata:
  name: data
  labels:
    domain: data
    environment: production
EOF

kubectl apply -f "$MANIFESTS_DIR/namespaces.yaml"
echo -e "${GREEN}✓${NC} Namespace созданы"

# =================================
# 2. ClusterRole: security-auditor
# =================================

echo -e "\n${YELLOW}=== Создание ClusterRole: security-auditor ===${NC}"

cat > "$MANIFESTS_DIR/clusterrole-security-auditor.yaml" << 'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: security-auditor
  labels:
    rbac.propdevelopment.com/role: security-auditor
rules:
# Просмотр всех ресурсов
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
# Просмотр секретов (только чтение)
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
# Просмотр логов
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get", "list"]
# Просмотр событий
- apiGroups: [""]
  resources: ["events"]
  verbs: ["get", "list", "watch"]
# Просмотр RBAC конфигураций
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]
  verbs: ["get", "list", "watch"]
# Просмотр NetworkPolicies
- apiGroups: ["networking.k8s.io"]
  resources: ["networkpolicies"]
  verbs: ["get", "list", "watch"]
EOF

kubectl apply -f "$MANIFESTS_DIR/clusterrole-security-auditor.yaml"
echo -e "${GREEN}✓${NC} ClusterRole security-auditor создана"

# =================================
# 3. Role: namespace-editor
# =================================

echo -e "\n${YELLOW}=== Создание Role: namespace-editor ===${NC}"

for NAMESPACE in sales tenant-services finance data; do
cat > "$MANIFESTS_DIR/role-namespace-editor-$NAMESPACE.yaml" << EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: namespace-editor
  namespace: $NAMESPACE
  labels:
    rbac.propdevelopment.com/role: namespace-editor
rules:
# Полный доступ к основным ресурсам
- apiGroups: ["", "apps", "batch", "extensions"]
  resources:
    - pods
    - pods/log
    - pods/exec
    - pods/portforward
    - services
    - endpoints
    - persistentvolumeclaims
    - configmaps
    - secrets
    - deployments
    - replicasets
    - statefulsets
    - daemonsets
    - jobs
    - cronjobs
  verbs: ["*"]
# Управление RBAC внутри namespace
- apiGroups: ["rbac.authorization.k8s.io"]
  resources:
    - roles
    - rolebindings
  verbs: ["*"]
# Управление ServiceAccounts
- apiGroups: [""]
  resources: ["serviceaccounts"]
  verbs: ["*"]
# Управление ResourceQuotas и LimitRanges
- apiGroups: [""]
  resources:
    - resourcequotas
    - limitranges
  verbs: ["*"]
# Управление Ingress
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["*"]
# Просмотр событий
- apiGroups: [""]
  resources: ["events"]
  verbs: ["get", "list", "watch"]
EOF
    kubectl apply -f "$MANIFESTS_DIR/role-namespace-editor-$NAMESPACE.yaml"
    echo -e "${GREEN}✓${NC} Role namespace-editor создана в namespace: $NAMESPACE"
done

# =================================
# 4. Role: namespace-viewer
# =================================

echo -e "\n${YELLOW}=== Создание Role: namespace-viewer ===${NC}"

for NAMESPACE in sales tenant-services finance data; do
cat > "$MANIFESTS_DIR/role-namespace-viewer-$NAMESPACE.yaml" << EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: namespace-viewer
  namespace: $NAMESPACE
  labels:
    rbac.propdevelopment.com/role: namespace-viewer
rules:
# Только чтение всех ресурсов
- apiGroups: ["", "apps", "batch", "extensions"]
  resources:
    - pods
    - pods/log
    - services
    - endpoints
    - persistentvolumeclaims
    - configmaps
    - deployments
    - replicasets
    - statefulsets
    - daemonsets
    - jobs
    - cronjobs
  verbs: ["get", "list", "watch"]
# Просмотр событий
- apiGroups: [""]
  resources: ["events"]
  verbs: ["get", "list", "watch"]
# Просмотр Ingress
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch"]
# Просмотр метрик
- apiGroups: ["metrics.k8s.io"]
  resources: ["pods", "nodes"]
  verbs: ["get", "list"]
EOF
    kubectl apply -f "$MANIFESTS_DIR/role-namespace-viewer-$NAMESPACE.yaml"
    echo -e "${GREEN}✓${NC} Role namespace-viewer создана в namespace: $NAMESPACE"
done

# =================================
# 5. Создание ResourceQuotas
# =================================

echo -e "\n${YELLOW}=== Создание ResourceQuotas для namespace ===${NC}"

for NAMESPACE in sales tenant-services finance data; do
cat > "$MANIFESTS_DIR/resourcequota-$NAMESPACE.yaml" << EOF
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-resources
  namespace: $NAMESPACE
spec:
  hard:
    requests.cpu: "20"
    requests.memory: 40Gi
    limits.cpu: "40"
    limits.memory: 80Gi
    persistentvolumeclaims: "10"
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: object-counts
  namespace: $NAMESPACE
spec:
  hard:
    pods: "50"
    services: "20"
    secrets: "50"
    configmaps: "50"
EOF
    kubectl apply -f "$MANIFESTS_DIR/resourcequota-$NAMESPACE.yaml"
    echo -e "${GREEN}✓${NC} ResourceQuota создана для namespace: $NAMESPACE"
done

# =================================
# 6. Создание NetworkPolicies
# =================================

echo -e "\n${YELLOW}=== Создание NetworkPolicies для изоляции namespace ===${NC}"

for NAMESPACE in sales tenant-services finance data; do
cat > "$MANIFESTS_DIR/networkpolicy-$NAMESPACE.yaml" << EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: $NAMESPACE
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-same-namespace
  namespace: $NAMESPACE
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector: {}
  egress:
  - to:
    - podSelector: {}
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
EOF
    kubectl apply -f "$MANIFESTS_DIR/networkpolicy-$NAMESPACE.yaml"
    echo -e "${GREEN}✓${NC} NetworkPolicy создана для namespace: $NAMESPACE"
done

echo -e "\n${GREEN}==============================="
echo "Все роли успешно созданы!"
echo "===============================${NC}"

echo -e "\nСозданные ресурсы:"
echo "1. Namespace: sales, tenant-services, finance, data"
echo "2. ClusterRole: security-auditor"
echo "3. Role в каждом namespace: namespace-editor, namespace-viewer"
echo "4. ResourceQuotas для ограничения ресурсов"
echo "5. NetworkPolicies для изоляции namespace"

echo -e "\n${YELLOW}Созданные роли:${NC}"
echo "  ✓ cluster-admin (встроенная роль Kubernetes)"
echo "  ✓ security-auditor (ClusterRole)"
echo "  ✓ namespace-editor (Role в каждом namespace)"
echo "  ✓ namespace-viewer (Role в каждом namespace)"

echo -e "\n${YELLOW}Следующий шаг:${NC}"
echo "Выполните скрипт 3-create-bindings.sh для связывания пользователей с ролями"

echo -e "\n${BLUE}Проверка созданных ролей:${NC}"
echo "  kubectl get clusterroles | grep security-auditor"
echo "  kubectl get roles -n sales"
echo "  kubectl get resourcequotas -n sales"
echo "  kubectl get networkpolicies -n sales"
