# Task 6: Аудит активности пользователей и обнаружение инцидентов

Этот проект содержит инструменты для настройки аудита Kubernetes, симуляции инцидентов безопасности и анализа логов аудита.

## Установка и настройка

### Шаг 1: Настройка аудита в Minikube

1. Остановите Minikube (если запущен):
```bash
minikube stop
```

2. Скопируйте файл политики аудита:
```bash
# Создайте директорию для конфигурации (если не существует)
mkdir -p ~/.minikube/files/etc/kubernetes/audit

# Скопируйте политику аудита
cp audit-policy.yaml ~/.minikube/files/etc/kubernetes/audit/audit-policy.yaml
```

3. Запустите Minikube с включённым аудитом:
```bash
minikube start \
  --extra-config=apiserver.audit-policy-file=/etc/kubernetes/audit/audit-policy.yaml \
  --extra-config=apiserver.audit-log-path=/var/log/kubernetes/audit.log \
  --extra-config=apiserver.audit-log-maxage=30 \
  --extra-config=apiserver.audit-log-maxbackup=10 \
  --extra-config=apiserver.audit-log-maxsize=100
```

4. Проверьте, что аудит работает:
```bash
minikube ssh "sudo tail -f /var/log/kubernetes/audit.log"
```

## 📖 Использование

### 1. Запуск симуляции инцидентов

Сделайте скрипт исполняемым и запустите его:

```bash
chmod +x simulate-incident.sh
./simulate-incident.sh
```

### 2. Извлечение логов аудита

Скопируйте логи аудита из Minikube:

```bash
minikube ssh "sudo cat /var/log/kubernetes/audit.log" > audit.log
```

### 3. Анализ логов

Запустите скрипт анализа:

```bash
# Сделайте скрипт исполняемым
chmod +x analyze-audit.sh

# Запустите анализ
./analyze-audit.sh audit.log
```

Скрипт создаст файл `audit-extract.json` с подозрительными событиями и выведет статистику:

```
Анализ файла: audit.log

Статистика анализа:
   Всего строк обработано: 15234
   Подозрительных событий: 42

Детализация:
   - Доступ к секретам: 8
   - Привилегированные поды: 3
   - Использование exec: 5
   - Создание RoleBinding: 2
   - Изменения audit-policy: 1
   - Неавторизованный доступ: 23

Результаты сохранены в: audit-extract.json
```

### 4. Просмотр результатов

Откройте файлы с результатами:

```bash
# Просмотр отчёта
cat analysis.md

# Просмотр подозрительных событий (с форматированием)
cat audit-extract.json | jq '.'
```

## Анализ результатов

### Структура audit-extract.json

Файл содержит категории подозрительных событий:

```json
{
  "secretAccess": [...],           // Доступ к секретам
  "privilegedPods": [...],         // Привилегированные поды
  "execInPods": [...],             // Использование kubectl exec
  "roleBindingCreation": [...],    // Создание RoleBinding
  "auditPolicyChanges": [...],     // Изменения audit-policy
  "unauthorizedAccess": [...]      // Неавторизованный доступ (403)
}
```

### Ключевые индикаторы компрометации

1. **🔴 Критические:**
   - Создание RoleBinding с cluster-admin
   - Привилегированные поды
   - Доступ к секретам в kube-system

2. **🟡 Подозрительные:**
   - Использование exec в системных подах
   - Попытки изменения audit-policy
   - Множественные 403 ошибки

3. **🟢 Информационные:**
   - Обычные операции CRUD
   - Легитимные запросы с правильными правами

## Проверка самостоятельно

### 1. Проверка событий доступа к секретам

```bash
cat audit.log | jq 'select(.objectRef.resource=="secrets" and .verb=="get")'
```

### 2. Проверка kubectl exec в чужие поды

```bash
cat audit.log | jq 'select(.verb=="create" and .objectRef.subresource=="exec")'
```

### 3. Проверка привилегированных подов

```bash
cat audit.log | jq 'select(.objectRef.resource=="pods" and .requestObject.spec.containers[].securityContext.privileged==true)'
```

### 4. Проверка изменений audit-policy

```bash
grep -i 'audit-policy' audit.log
```

### 5. Проверка создания RoleBinding с cluster-admin

```bash
cat audit.log | jq 'select(.objectRef.resource=="rolebindings" and .requestObject.roleRef.name=="cluster-admin")'
```

## Очистка

После завершения тестирования удалите созданные ресурсы:

```bash
# Удалить namespace и все ресурсы в нём
kubectl delete namespace secure-ops
```
