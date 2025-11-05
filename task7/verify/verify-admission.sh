#!/bin/bash

# Скрипт для проверки работы PodSecurity Admission Controller
# Проверяет, что небезопасные поды блокируются в namespace audit-zone

set -e

echo "=== Проверка PodSecurity Admission Controller ==="
echo ""

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Создаем namespace если его нет
echo "1. Создание namespace audit-zone с PodSecurity restricted..."
kubectl apply -f ../01-create-namespace.yaml
echo ""

# Ждем немного
sleep 2

echo "2. Проверка блокировки небезопасных подов..."
echo ""

# Проверка privileged pod
echo -n "   Тест 1: Privileged pod должен быть заблокирован... "
if kubectl apply -f ../insecure-manifests/01-privileged-pod.yaml 2>&1 | grep -q "forbidden\|violates\|denied"; then
    echo -e "${GREEN}✓ ЗАБЛОКИРОВАН${NC}"
    PRIVILEGED_BLOCKED=1
else
    echo -e "${RED}✗ НЕ ЗАБЛОКИРОВАН (ОШИБКА!)${NC}"
    PRIVILEGED_BLOCKED=0
fi

# Очистка если под создался
kubectl delete pod pod-privileged -n audit-zone --ignore-not-found=true 2>/dev/null

# Проверка hostPath pod
echo -n "   Тест 2: HostPath pod должен быть заблокирован... "
if kubectl apply -f ../insecure-manifests/02-hostpath-pod.yaml 2>&1 | grep -q "forbidden\|violates\|denied"; then
    echo -e "${GREEN}✓ ЗАБЛОКИРОВАН${NC}"
    HOSTPATH_BLOCKED=1
else
    echo -e "${RED}✗ НЕ ЗАБЛОКИРОВАН (ОШИБКА!)${NC}"
    HOSTPATH_BLOCKED=0
fi

# Очистка если под создался
kubectl delete pod pod-hostpath -n audit-zone --ignore-not-found=true 2>/dev/null

# Проверка root user pod
echo -n "   Тест 3: Root user pod должен быть заблокирован... "
if kubectl apply -f ../insecure-manifests/03-root-user-pod.yaml 2>&1 | grep -q "forbidden\|violates\|denied"; then
    echo -e "${GREEN}✓ ЗАБЛОКИРОВАН${NC}"
    ROOT_BLOCKED=1
else
    echo -e "${RED}✗ НЕ ЗАБЛОКИРОВАН (ОШИБКА!)${NC}"
    ROOT_BLOCKED=0
fi

# Очистка если под создался
kubectl delete pod pod-root-user -n audit-zone --ignore-not-found=true 2>/dev/null

echo ""
echo "=== Результаты проверки ==="

TOTAL_TESTS=3
PASSED_TESTS=$((PRIVILEGED_BLOCKED + HOSTPATH_BLOCKED + ROOT_BLOCKED))

echo "Пройдено тестов: $PASSED_TESTS из $TOTAL_TESTS"

if [ $PASSED_TESTS -eq $TOTAL_TESTS ]; then
    echo -e "${GREEN}✓ Все тесты пройдены! PodSecurity Admission работает корректно.${NC}"
    exit 0
else
    echo -e "${RED}✗ Некоторые тесты не прошли. Проверьте конфигурацию PodSecurity.${NC}"
    exit 1
fi
