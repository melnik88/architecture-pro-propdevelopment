#!/bin/bash

# Скрипт анализа Kubernetes Audit Log
# Фильтрует подозрительные события и сохраняет их в audit-extract.json

set -e

# Конфигурация
INPUT_FILE="${1:-audit.log}"
OUTPUT_FILE="audit-extract.json"
TEMP_DIR=$(mktemp -d)

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для вывода с цветом
print_color() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

# Проверка наличия входного файла
if [ ! -f "$INPUT_FILE" ]; then
    print_color "$RED" "❌ Файл $INPUT_FILE не найден!"
    echo ""
    echo "Использование: $0 [путь_к_audit.log]"
    exit 1
fi

# Проверка наличия jq
if ! command -v jq &> /dev/null; then
    print_color "$RED" "❌ Требуется установить jq для работы скрипта"
    echo ""
    echo "Установка:"
    echo "  macOS:   brew install jq"
    echo "  Ubuntu:  sudo apt install jq"
    echo "  CentOS:  sudo yum install jq"
    exit 1
fi

print_color "$BLUE" "🔍 Анализ файла: $INPUT_FILE"
echo ""

# Подсчёт общего количества строк
TOTAL_LINES=$(wc -l < "$INPUT_FILE")

# Создание временных файлов для каждой категории
SECRET_ACCESS="$TEMP_DIR/secret_access.json"
PRIVILEGED_PODS="$TEMP_DIR/privileged_pods.json"
EXEC_IN_PODS="$TEMP_DIR/exec_in_pods.json"
ROLEBINDING_CREATION="$TEMP_DIR/rolebinding_creation.json"
AUDIT_POLICY_CHANGES="$TEMP_DIR/audit_policy_changes.json"
UNAUTHORIZED_ACCESS="$TEMP_DIR/unauthorized_access.json"

# Инициализация файлов пустыми массивами
echo "[]" > "$SECRET_ACCESS"
echo "[]" > "$PRIVILEGED_PODS"
echo "[]" > "$EXEC_IN_PODS"
echo "[]" > "$ROLEBINDING_CREATION"
echo "[]" > "$AUDIT_POLICY_CHANGES"
echo "[]" > "$UNAUTHORIZED_ACCESS"

print_color "$YELLOW" "⏳ Обработка событий..."

# 1. Поиск доступа к секретам
print_color "$BLUE" "   🔐 Анализ доступа к секретам..."
jq -c 'select(.objectRef.resource=="secrets" and (.verb=="get" or .verb=="list")) | {
    timestamp: .requestReceivedTimestamp,
    user: .user.username,
    namespace: .objectRef.namespace,
    secretName: .objectRef.name,
    verb: .verb,
    responseStatus: .responseStatus.code,
    userAgent: .userAgent
}' "$INPUT_FILE" 2>/dev/null | jq -s '.' > "$SECRET_ACCESS"

# 2. Поиск привилегированных подов
print_color "$BLUE" "   ⚠️  Анализ привилегированных подов..."
jq -c 'select(.objectRef.resource=="pods" and .verb=="create" and .requestObject.spec.containers[]?.securityContext.privileged==true) | {
    timestamp: .requestReceivedTimestamp,
    user: .user.username,
    namespace: .objectRef.namespace,
    podName: .objectRef.name,
    responseStatus: .responseStatus.code,
    userAgent: .userAgent
}' "$INPUT_FILE" 2>/dev/null | jq -s '.' > "$PRIVILEGED_PODS"

# 3. Поиск использования kubectl exec
print_color "$BLUE" "   🔧 Анализ использования exec..."
jq -c 'select(.verb=="create" and .objectRef.subresource=="exec") | {
    timestamp: .requestReceivedTimestamp,
    user: .user.username,
    namespace: .objectRef.namespace,
    podName: .objectRef.name,
    responseStatus: .responseStatus.code,
    userAgent: .userAgent
}' "$INPUT_FILE" 2>/dev/null | jq -s '.' > "$EXEC_IN_PODS"

# 4. Поиск создания RoleBinding с cluster-admin
print_color "$BLUE" "   👤 Анализ создания RoleBinding..."
jq -c 'select((.objectRef.resource=="rolebindings" or .objectRef.resource=="clusterrolebindings") and .verb=="create" and .requestObject.roleRef.name=="cluster-admin") | {
    timestamp: .requestReceivedTimestamp,
    user: .user.username,
    namespace: .objectRef.namespace,
    bindingName: .objectRef.name,
    subjects: .requestObject.subjects,
    responseStatus: .responseStatus.code,
    userAgent: .userAgent
}' "$INPUT_FILE" 2>/dev/null | jq -s '.' > "$ROLEBINDING_CREATION"

# 5. Поиск изменений audit-policy
print_color "$BLUE" "   📝 Анализ изменений audit-policy..."
grep -i 'audit-policy' "$INPUT_FILE" 2>/dev/null | jq -c '{
    timestamp: .requestReceivedTimestamp,
    user: .user.username,
    verb: .verb,
    requestURI: .requestURI,
    responseStatus: .responseStatus.code,
    userAgent: .userAgent
}' 2>/dev/null | jq -s '.' > "$AUDIT_POLICY_CHANGES"

# 6. Поиск неавторизованного доступа (403)
print_color "$BLUE" "   🚫 Анализ неавторизованного доступа..."
jq -c 'select(.responseStatus.code==403) | {
    timestamp: .requestReceivedTimestamp,
    user: .user.username,
    verb: .verb,
    resource: .objectRef.resource,
    namespace: .objectRef.namespace,
    name: .objectRef.name,
    reason: .responseStatus.reason,
    userAgent: .userAgent
}' "$INPUT_FILE" 2>/dev/null | jq -s '.' > "$UNAUTHORIZED_ACCESS"

# Подсчёт событий в каждой категории
SECRET_COUNT=$(jq 'length' "$SECRET_ACCESS")
PRIVILEGED_COUNT=$(jq 'length' "$PRIVILEGED_PODS")
EXEC_COUNT=$(jq 'length' "$EXEC_IN_PODS")
ROLEBINDING_COUNT=$(jq 'length' "$ROLEBINDING_CREATION")
AUDIT_POLICY_COUNT=$(jq 'length' "$AUDIT_POLICY_CHANGES")
UNAUTHORIZED_COUNT=$(jq 'length' "$UNAUTHORIZED_ACCESS")

TOTAL_SUSPICIOUS=$((SECRET_COUNT + PRIVILEGED_COUNT + EXEC_COUNT + ROLEBINDING_COUNT + AUDIT_POLICY_COUNT + UNAUTHORIZED_COUNT))

# Создание итогового JSON файла
print_color "$YELLOW" "📦 Формирование результатов..."
jq -n \
    --slurpfile secretAccess "$SECRET_ACCESS" \
    --slurpfile privilegedPods "$PRIVILEGED_PODS" \
    --slurpfile execInPods "$EXEC_IN_PODS" \
    --slurpfile roleBindingCreation "$ROLEBINDING_CREATION" \
    --slurpfile auditPolicyChanges "$AUDIT_POLICY_CHANGES" \
    --slurpfile unauthorizedAccess "$UNAUTHORIZED_ACCESS" \
    '{
        secretAccess: $secretAccess[0],
        privilegedPods: $privilegedPods[0],
        execInPods: $execInPods[0],
        roleBindingCreation: $roleBindingCreation[0],
        auditPolicyChanges: $auditPolicyChanges[0],
        unauthorizedAccess: $unauthorizedAccess[0]
    }' > "$OUTPUT_FILE"

# Очистка временных файлов
rm -rf "$TEMP_DIR"

# Вывод статистики
echo ""
print_color "$GREEN" "📊 Статистика анализа:"
echo "   Всего строк обработано: $TOTAL_LINES"
echo "   Подозрительных событий: $TOTAL_SUSPICIOUS"
echo ""
print_color "$GREEN" "📋 Детализация:"
echo "   🔐 Доступ к секретам: $SECRET_COUNT"
echo "   ⚠️  Привилегированные поды: $PRIVILEGED_COUNT"
echo "   🔧 Использование exec: $EXEC_COUNT"
echo "   👤 Создание RoleBinding: $ROLEBINDING_COUNT"
echo "   📝 Изменения audit-policy: $AUDIT_POLICY_COUNT"
echo "   🚫 Неавторизованный доступ: $UNAUTHORIZED_COUNT"
echo ""
print_color "$GREEN" "✅ Результаты сохранены в: $OUTPUT_FILE"

# Вывод предупреждений о критических событиях
if [ "$PRIVILEGED_COUNT" -gt 0 ]; then
    echo ""
    print_color "$RED" "⚠️  ВНИМАНИЕ: Обнаружены привилегированные поды!"
fi

if [ "$ROLEBINDING_COUNT" -gt 0 ]; then
    echo ""
    print_color "$RED" "⚠️  КРИТИЧНО: Обнаружено создание RoleBinding с cluster-admin!"
fi

if [ "$AUDIT_POLICY_COUNT" -gt 0 ]; then
    echo ""
    print_color "$RED" "⚠️  КРИТИЧНО: Обнаружены попытки изменения audit-policy!"
fi

# Вывод топ-5 пользователей с наибольшим количеством подозрительных действий
echo ""
print_color "$YELLOW" "👥 Топ-5 пользователей с подозрительной активностью:"
jq -r '
    [
        .secretAccess[].user,
        .privilegedPods[].user,
        .execInPods[].user,
        .roleBindingCreation[].user,
        .auditPolicyChanges[].user,
        .unauthorizedAccess[].user
    ] |
    group_by(.) |
    map({user: .[0], count: length}) |
    sort_by(.count) |
    reverse |
    .[:5] |
    .[] |
    "   \(.count)x - \(.user)"
' "$OUTPUT_FILE" 2>/dev/null || echo "   (нет данных)"

echo ""
print_color "$BLUE" "💡 Для просмотра результатов используйте:"
echo "   cat $OUTPUT_FILE | jq '.'"
echo ""
print_color "$BLUE" "📖 Для просмотра отчёта:"
echo "   cat analysis.md"
