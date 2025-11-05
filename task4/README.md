# Задание 4: Организация ролевого доступа к Kubernetes

## Описание

Этот проект содержит полное решение для организации ролевого доступа (RBAC) к Kubernetes кластеру компании PropDevelopment.

## Структура проекта

```
task4/
├── README.md                      # Этот файл
├── rbac-roles-table.md           # Таблица ролей и их описание
├── 1-create-users.sh             # Скрипт создания пользователей
├── 2-create-roles.sh             # Скрипт создания ролей
├── 3-create-bindings.sh          # Скрипт связывания пользователей с ролями
├── k8s-certs/                    # Директория с сертификатами (создается автоматически)
└── k8s-rbac-manifests/           # Директория с манифестами (создается автоматически)
```

## Модель RBAC

### Роли в системе

#### 1. **cluster-admin** (встроенная роль)
- **Пользователи:** 2 администратора
- **Права:** Полный доступ ко всему кластеру

#### 2. **security-auditor** (ClusterRole)
- **Пользователи:** 1 специалист по ИБ
- **Права:** Чтение всех ресурсов + секретов

#### 3. **namespace-editor** (Role в каждом namespace)
- **Пользователи:** 12 человек (владельцы, DevOps, разработчики)
- **Права:** Полный доступ к приложениям в namespace

#### 4. **namespace-viewer** (Role в каждом namespace)
- **Пользователи:** 8 человек (операторы, аналитики)
- **Права:** Только чтение

**Всего:** 23 пользователя

## Предварительные требования

1. **Minikube** установлен и запущен:
   ```bash
   minikube start
   ```

2. **kubectl** настроен для работы с кластером:
   ```bash
   kubectl cluster-info
   ```

3. **OpenSSL** установлен (для генерации сертификатов):
   ```bash
   openssl version
   ```

4. Права на выполнение скриптов:
   ```bash
   chmod +x 1-create-users.sh 2-create-roles.sh 3-create-bindings.sh
   ```

## Порядок выполнения

### Шаг 1: Создание пользователей

```bash
./1-create-users.sh
```

**Создает:**
- 2 администратора (admin-devops, admin-infra)
- 1 аудитор безопасности (security-auditor)
- 12 editors (владельцы продуктов, DevOps, разработчики)
- 8 viewers (операторы, аналитики, бухгалтеры)

### Шаг 2: Создание ролей

```bash
./2-create-roles.sh
```

**Создает:**
- 4 namespace: sales, tenant-services, finance, data
- ClusterRole: security-auditor
- Role в каждом namespace: namespace-editor, namespace-viewer
- ResourceQuotas и NetworkPolicies

### Шаг 3: Связывание пользователей с ролями

```bash
./3-create-bindings.sh
```

**Создает:**
- ClusterRoleBindings для администраторов и аудиторов
- RoleBindings в каждом namespace

## Проверка работы

### 1. Проверка созданных ресурсов

```bash
# Проверка namespace
kubectl get namespaces

# Проверка ролей
kubectl get clusterroles | grep security-auditor
kubectl get roles -n sales

# Проверка привязок
kubectl get clusterrolebindings | grep propdevelopment
kubectl get rolebindings -n sales
```

### 2. Проверка прав пользователя

```bash
# Проверка прав editor в namespace sales
kubectl auth can-i --list --as=dev-backend-sales -n sales

# Проверка что editor НЕ может получить доступ к другому namespace
kubectl auth can-i get pods --as=dev-backend-sales -n finance
```

### 3. Тестирование от имени namespace-editor

```bash
# Экспортируем kubeconfig разработчика
export KUBECONFIG=./k8s-certs/dev-backend-sales-kubeconfig

# Разрешенные операции
kubectl get pods -n sales              # ✓ Работает
kubectl get deployments -n sales       # ✓ Работает
kubectl get secrets -n sales           # ✓ Работает
kubectl delete deployment -n sales     # ✓ Работает (editor)
kubectl exec -it pod-name -n sales     # ✓ Работает (отладка)

# Запрещенные операции
kubectl get pods -n finance            # ✗ Запрещено (другой namespace)
kubectl delete namespace sales         # ✗ Запрещено (управление namespace)

# Возврат к admin kubeconfig
unset KUBECONFIG
```

### 4. Тестирование от имени namespace-viewer

```bash
export KUBECONFIG=./k8s-certs/ops-sales-kubeconfig

# Разрешенные операции
kubectl get pods -n sales              # ✓ Работает
kubectl logs pod-name -n sales         # ✓ Работает

# Запрещенные операции
kubectl delete pod -n sales            # ✗ Запрещено (только чтение)
kubectl get secrets -n sales           # ✗ Запрещено (нет доступа к секретам)
kubectl exec -it pod-name -n sales     # ✗ Запрещено (нет exec)

unset KUBECONFIG
```

### 5. Тестирование security-auditor

```bash
export KUBECONFIG=./k8s-certs/security-auditor-kubeconfig

# Аудитор может просматривать все
kubectl get pods --all-namespaces      # ✓ Работает
kubectl get secrets -n finance         # ✓ Работает (чтение секретов)
kubectl get secrets -n finance -o yaml # ✓ Работает (содержимое)

# Но не может изменять
kubectl delete pod -n sales            # ✗ Запрещено (только чтение)

unset KUBECONFIG
```

## Описание ролей

| Роль | Пользователей | Права | Использование |
|------|---------------|-------|---------------|
| **cluster-admin** | 2 | Полный доступ ко всему | Администрирование инфраструктуры |
| **security-auditor** | 1 | Чтение всех ресурсов + секретов | Аудит безопасности |
| **namespace-editor** | 12 | Полный доступ в namespace | Разработка и деплой |
| **namespace-viewer** | 8 | Только чтение в namespace | Мониторинг и аналитика |

## Распределение по доменам

### Namespace: sales (Продажи)
- **Editors (4):** owner-sales, devops-sales, dev-backend-sales, dev-frontend-sales
- **Viewers (2):** ops-sales, analyst-clients

### Namespace: tenant-services (ЖКУ)
- **Editors (4):** owner-tenant, devops-tenant, dev-backend-tenant, dev-smarthome
- **Viewers (2):** ops-tenant, analyst-zku

### Namespace: finance (Финансы)
- **Editors (2):** owner-finance, dev-finance
- **Viewers (2):** ops-finance, accountant

### Namespace: data (Обработка данных)
- **Editors (2):** owner-data, dev-data
- **Viewers (2):** ops-monitoring, analyst-bi

## Безопасность

### Принципы
1. **Минимальные привилегии** - Каждая роль имеет только необходимые права
2. **Изоляция доменов** - Каждый домен в своем namespace
3. **Аудит** - Специальная роль для контроля безопасности
4. **Ограничение администраторов** - Только 2 человека с полным доступом

### Защита сертификатов
- Все сертификаты в `k8s-certs/` (добавлено в `.gitignore`)
- **НЕ коммитьте сертификаты в git!**

### Ограничения ресурсов
- ResourceQuotas ограничивают CPU/Memory
- NetworkPolicies изолируют namespace

## Обслуживание

### Ротация сертификатов (раз в год)
```bash
rm -rf k8s-certs/
./1-create-users.sh
```

### Добавление нового пользователя
1. Отредактируйте `1-create-users.sh`
2. Добавьте `create_user "username" "group" "description"`
3. Запустите скрипт
4. Добавьте в `3-create-bindings.sh`
5. Запустите скрипт привязок

### Удаление пользователя
```bash
kubectl delete rolebinding <binding-name> -n <namespace>
rm k8s-certs/<username>.*
```

## Troubleshooting

### Ошибка: "ca.crt not found"
```bash
minikube status
ls ~/.minikube/ca.crt
```

### Ошибка: "Forbidden"
```bash
echo $KUBECONFIG
kubectl auth can-i --list --as=<username> -n <namespace>
```

### Ошибка: "User cannot list pods"
```bash
kubectl get rolebindings -n <namespace>
kubectl get role <role-name> -n <namespace>
```
