#!/bin/bash

# Скрипт для связывания пользователей с ролями (RoleBindings и ClusterRoleBindings)
# Для PropDevelopment RBAC

set -e

echo "============================================"
echo "Создание привязок пользователей к ролям"
echo "============================================"

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
# 1. ClusterRoleBindings для cluster-admin
# =================================

echo -e "\n${YELLOW}=== Создание ClusterRoleBindings для cluster-admin ===${NC}"

cat > "$MANIFESTS_DIR/clusterrolebinding-admins.yaml" << 'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-admins
  labels:
    rbac.propdevelopment.com/binding: cluster-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
# Администраторы инфраструктуры
- kind: User
  name: admin-devops
  apiGroup: rbac.authorization.k8s.io
- kind: User
  name: admin-infra
  apiGroup: rbac.authorization.k8s.io
# Группа администраторов
- kind: Group
  name: system:masters
  apiGroup: rbac.authorization.k8s.io
EOF

kubectl apply -f "$MANIFESTS_DIR/clusterrolebinding-admins.yaml"
echo -e "${GREEN}✓${NC} ClusterRoleBinding для cluster-admin создан"

# =================================
# 2. ClusterRoleBinding для security-auditor
# =================================

echo -e "\n${YELLOW}=== Создание ClusterRoleBinding для security-auditor ===${NC}"

cat > "$MANIFESTS_DIR/clusterrolebinding-security-auditor.yaml" << 'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: security-auditors
  labels:
    rbac.propdevelopment.com/binding: security-auditor
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: security-auditor
subjects:
# Специалисты по безопасности
- kind: User
  name: security-auditor
  apiGroup: rbac.authorization.k8s.io
# Группа аудиторов безопасности
- kind: Group
  name: security:auditors
  apiGroup: rbac.authorization.k8s.io
EOF

kubectl apply -f "$MANIFESTS_DIR/clusterrolebinding-security-auditor.yaml"
echo -e "${GREEN}✓${NC} ClusterRoleBinding для security-auditor создан"

# =================================
# 3. RoleBindings для namespace: sales
# =================================

echo -e "\n${YELLOW}=== Создание RoleBindings для namespace: sales ===${NC}"

cat > "$MANIFESTS_DIR/rolebindings-sales.yaml" << 'EOF'
# namespace-editor для sales
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: namespace-editors
  namespace: sales
  labels:
    rbac.propdevelopment.com/binding: namespace-editor
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: namespace-editor
subjects:
- kind: User
  name: owner-sales
  apiGroup: rbac.authorization.k8s.io
- kind: User
  name: devops-sales
  apiGroup: rbac.authorization.k8s.io
- kind: User
  name: dev-backend-sales
  apiGroup: rbac.authorization.k8s.io
- kind: User
  name: dev-frontend-sales
  apiGroup: rbac.authorization.k8s.io
- kind: Group
  name: namespace:sales:editors
  apiGroup: rbac.authorization.k8s.io
---
# namespace-viewer для sales
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: namespace-viewers
  namespace: sales
  labels:
    rbac.propdevelopment.com/binding: namespace-viewer
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: namespace-viewer
subjects:
- kind: User
  name: ops-sales
  apiGroup: rbac.authorization.k8s.io
- kind: User
  name: analyst-clients
  apiGroup: rbac.authorization.k8s.io
- kind: Group
  name: namespace:sales:viewers
  apiGroup: rbac.authorization.k8s.io
EOF

kubectl apply -f "$MANIFESTS_DIR/rolebindings-sales.yaml"
echo -e "${GREEN}✓${NC} RoleBindings для namespace sales созданы"

# =================================
# 4. RoleBindings для namespace: tenant-services
# =================================

echo -e "\n${YELLOW}=== Создание RoleBindings для namespace: tenant-services ===${NC}"

cat > "$MANIFESTS_DIR/rolebindings-tenant-services.yaml" << 'EOF'
# namespace-editor для tenant-services
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: namespace-editors
  namespace: tenant-services
  labels:
    rbac.propdevelopment.com/binding: namespace-editor
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: namespace-editor
subjects:
- kind: User
  name: owner-tenant
  apiGroup: rbac.authorization.k8s.io
- kind: User
  name: devops-tenant
  apiGroup: rbac.authorization.k8s.io
- kind: User
  name: dev-backend-tenant
  apiGroup: rbac.authorization.k8s.io
- kind: User
  name: dev-smarthome
  apiGroup: rbac.authorization.k8s.io
- kind: Group
  name: namespace:tenant-services:editors
  apiGroup: rbac.authorization.k8s.io
---
# namespace-viewer для tenant-services
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: namespace-viewers
  namespace: tenant-services
  labels:
    rbac.propdevelopment.com/binding: namespace-viewer
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: namespace-viewer
subjects:
- kind: User
  name: ops-tenant
  apiGroup: rbac.authorization.k8s.io
- kind: User
  name: analyst-zku
  apiGroup: rbac.authorization.k8s.io
- kind: Group
  name: namespace:tenant-services:viewers
  apiGroup: rbac.authorization.k8s.io
EOF

kubectl apply -f "$MANIFESTS_DIR/rolebindings-tenant-services.yaml"
echo -e "${GREEN}✓${NC} RoleBindings для namespace tenant-services созданы"

# =================================
# 5. RoleBindings для namespace: finance
# =================================

echo -e "\n${YELLOW}=== Создание RoleBindings для namespace: finance ===${NC}"

cat > "$MANIFESTS_DIR/rolebindings-finance.yaml" << 'EOF'
# namespace-editor для finance
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: namespace-editors
  namespace: finance
  labels:
    rbac.propdevelopment.com/binding: namespace-editor
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: namespace-editor
subjects:
- kind: User
  name: owner-finance
  apiGroup: rbac.authorization.k8s.io
- kind: User
  name: dev-finance
  apiGroup: rbac.authorization.k8s.io
- kind: Group
  name: namespace:finance:editors
  apiGroup: rbac.authorization.k8s.io
---
# namespace-viewer для finance
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: namespace-viewers
  namespace: finance
  labels:
    rbac.propdevelopment.com/binding: namespace-viewer
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: namespace-viewer
subjects:
- kind: User
  name: ops-finance
  apiGroup: rbac.authorization.k8s.io
- kind: User
  name: accountant
  apiGroup: rbac.authorization.k8s.io
- kind: Group
  name: namespace:finance:viewers
  apiGroup: rbac.authorization.k8s.io
EOF

kubectl apply -f "$MANIFESTS_DIR/rolebindings-finance.yaml"
echo -e "${GREEN}✓${NC} RoleBindings для namespace finance созданы"

# =================================
# 6. RoleBindings для namespace: data
# =================================

echo -e "\n${YELLOW}=== Создание RoleBindings для namespace: data ===${NC}"

cat > "$MANIFESTS_DIR/rolebindings-data.yaml" << 'EOF'
# namespace-editor для data
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: namespace-editors
  namespace: data
  labels:
    rbac.propdevelopment.com/binding: namespace-editor
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: namespace-editor
subjects:
- kind: User
  name: owner-data
  apiGroup: rbac.authorization.k8s.io
- kind: User
  name: dev-data
  apiGroup: rbac.authorization.k8s.io
- kind: Group
  name: namespace:data:editors
  apiGroup: rbac.authorization.k8s.io
---
# namespace-viewer для data
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: namespace-viewers
  namespace: data
  labels:
    rbac.propdevelopment.com/binding: namespace-viewer
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: namespace-viewer
subjects:
- kind: User
  name: ops-monitoring
  apiGroup: rbac.authorization.k8s.io
- kind: User
  name: analyst-bi
  apiGroup: rbac.authorization.k8s.io
- kind: Group
  name: namespace:data:viewers
  apiGroup: rbac.authorization.k8s.io
EOF

kubectl apply -f "$MANIFESTS_DIR/rolebindings-data.yaml"
echo -e "${GREEN}✓${NC} RoleBindings для namespace data созданы"

echo -e "\n${GREEN}============================================"
echo "Все привязки успешно созданы!"
echo "============================================${NC}"

echo -e "\n${YELLOW}Распределение пользователей по ролям:${NC}"
echo "  cluster-admin: 2 пользователя"
echo "  security-auditor: 1 пользователь"
echo "  namespace-editor: 12 пользователей"
echo "  namespace-viewer: 8 пользователей"
echo "  ВСЕГО: 23 пользователя"

echo -e "\n${BLUE}Проверка созданных привязок:${NC}"
echo "  # ClusterRoleBindings"
echo "  kubectl get clusterrolebindings | grep propdevelopment"
echo ""
echo "  # RoleBindings в namespace sales"
echo "  kubectl get rolebindings -n sales"
echo ""
echo "  # Проверка прав пользователя"
echo "  kubectl auth can-i --list --as=dev-backend-sales -n sales"
echo ""
echo "  # Проверка доступа security-auditor"
echo "  kubectl auth can-i get secrets --all-namespaces --as=security-auditor"

echo -e "\n${YELLOW}Тестирование доступа:${NC}"
echo "1. Экспортируйте kubeconfig пользователя:"
echo "   export KUBECONFIG=./k8s-certs/dev-backend-sales-kubeconfig"
echo ""
echo "2. Попробуйте выполнить команды:"
echo "   kubectl get pods -n sales          # ✓ Должно работать"
echo "   kubectl get secrets -n sales       # ✓ Должно работать"
echo "   kubectl delete deployment -n sales # ✓ Должно работать (editor)"
echo "   kubectl get pods -n finance        # ✗ Должно быть запрещено"
echo ""
echo "3. Для возврата к admin kubeconfig:"
echo "   unset KUBECONFIG"

echo -e "\n${GREEN}✓${NC} Настройка RBAC завершена!"
echo -e "\n${BLUE}Документация:${NC}"
echo "  Таблица ролей: ./rbac-roles-table.md"
echo "  Манифесты: $MANIFESTS_DIR/"
echo "  README: ./README.md"
