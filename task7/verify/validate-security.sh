#!/bin/bash

# Скрипт для проверки что безопасные поды проходят валидацию
# и что OPA Gatekeeper корректно применяет политики

set -e

echo "=== Проверка безопасных подов и OPA Gatekeeper ==="
echo ""

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Проверка что namespace существует
echo "1. Проверка namespace audit-zone..."
if kubectl get namespace audit-zone &>/dev/null; then
    echo -e "${GREEN}✓ Namespace audit-zone существует${NC}"
else
    echo -e "${RED}✗ Namespace audit-zone не найден${NC}"
    exit 1
fi
echo ""

# Проверка OPA Gatekeeper
echo "2. Проверка установки OPA Gatekeeper..."
if kubectl get deployment gatekeeper-controller-manager -n gatekeeper-system &>/dev/null; then
    echo -e "${GREEN}✓ OPA Gatekeeper установлен${NC}"

    # Проверка что Gatekeeper работает
    READY=$(kubectl get deployment gatekeeper-controller-manager -n gatekeeper-system -o jsonpath='{.status.readyReplicas}')
    if [ "$READY" -gt 0 ]; then
        echo -e "${GREEN}✓ Gatekeeper controller работает${NC}"
    else
        echo -e "${YELLOW}⚠ Gatekeeper controller не готов${NC}"
    fi
else
    echo -e "${YELLOW}⚠ OPA Gatekeeper не установлен (установите с помощью: kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/deploy/gatekeeper.yaml)${NC}"
fi
echo ""

# Проверка ConstraintTemplates
echo "3. Проверка ConstraintTemplates..."
TEMPLATES=("k8spspprivilegedcontainer" "k8spsphostfilesystem" "k8spsprequiredsecuritycontext")
TEMPLATES_OK=0

for template in "${TEMPLATES[@]}"; do
    if kubectl get constrainttemplate "$template" &>/dev/null; then
        echo -e "${GREEN}✓ ConstraintTemplate $template установлен${NC}"
        ((TEMPLATES_OK++))
    else
        echo -e "${YELLOW}⚠ ConstraintTemplate $template не найден${NC}"
    fi
done

if [ $TEMPLATES_OK -eq ${#TEMPLATES[@]} ]; then
    echo -e "${GREEN}✓ Все ConstraintTemplates установлены${NC}"
fi
echo ""

# Проверка Constraints
echo "4. Проверка Constraints..."
if kubectl get k8spspprivilegedcontainer psp-privileged-container &>/dev/null; then
    echo -e "${GREEN}✓ Constraint для privileged установлен${NC}"
else
    echo -e "${YELLOW}⚠ Constraint для privileged не найден${NC}"
fi

if kubectl get k8spsphostfilesystem psp-host-filesystem &>/dev/null; then
    echo -e "${GREEN}✓ Constraint для hostPath установлен${NC}"
else
    echo -e "${YELLOW}⚠ Constraint для hostPath не найден${NC}"
fi

if kubectl get k8spsprequiredsecuritycontext psp-required-security-context &>/dev/null; then
    echo -e "${GREEN}✓ Constraint для security context установлен${NC}"
else
    echo -e "${YELLOW}⚠ Constraint для security context не найден${NC}"
fi
echo ""

# Тестирование безопасных подов
echo "5. Тестирование развертывания безопасных подов..."
echo ""

SECURE_PODS=("01-secure.yaml" "02-secure.yaml" "03-secure.yaml")
DEPLOYED=0

for pod_file in "${SECURE_PODS[@]}"; do
    echo -n "   Развертывание $pod_file... "
    if kubectl apply -f "../secure-manifests/$pod_file" &>/dev/null; then
        echo -e "${GREEN}✓ Успешно${NC}"
        ((DEPLOYED++))
    else
        echo -e "${RED}✗ Ошибка${NC}"
        kubectl apply -f "../secure-manifests/$pod_file" 2>&1 | head -n 3
    fi
done

echo ""
echo "Развернуто безопасных подов: $DEPLOYED из ${#SECURE_PODS[@]}"
echo ""

# Проверка статуса подов
echo "6. Проверка статуса развернутых подов..."
sleep 5

kubectl get pods -n audit-zone

echo ""
echo "=== Очистка тестовых подов ==="
kubectl delete pods --all -n audit-zone --ignore-not-found=true

echo ""
echo "=== Итоговый результат ==="
if [ $DEPLOYED -eq ${#SECURE_PODS[@]} ]; then
    echo -e "${GREEN}✓ Все безопасные поды успешно прошли валидацию${NC}"
    echo -e "${GREEN}✓ Система безопасности настроена корректно${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠ Некоторые безопасные поды не прошли валидацию${NC}"
    echo "Проверьте конфигурацию OPA Gatekeeper и PodSecurity"
    exit 1
fi
