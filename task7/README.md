# Задание 7: Аудит и обеспечение соответствия политике безопасности контейнеров

## Описание решения

Реализована система аудита и обеспечения соответствия политике безопасности контейнеров с использованием:
- **PodSecurity Admission** (встроенный механизм Kubernetes)
- **OPA Gatekeeper** (расширенная политика безопасности)
- **Audit Policy** (логирование событий безопасности)

## Структура проекта

```
task7/
├── 01-create-namespace.yaml          # Namespace с PodSecurity restricted
├── insecure-manifests/                # Небезопасные манифесты для тестирования
│   ├── 01-privileged-pod.yaml        # Pod с privileged: true
│   ├── 02-hostpath-pod.yaml          # Pod с hostPath volume
│   └── 03-root-user-pod.yaml         # Pod запускающийся от root (UID 0)
├── secure-manifests/                  # Безопасные версии манифестов
│   ├── 01-secure.yaml                # Безопасный pod (без privileged)
│   ├── 02-secure.yaml                # Безопасный pod (без hostPath)
│   └── 03-secure.yaml                # Безопасный pod (не от root)
├── gatekeeper/
│   ├── constraint-templates/          # Шаблоны политик OPA Gatekeeper
│   │   ├── privileged.yaml           # Запрет privileged контейнеров
│   │   ├── hostpath.yaml             # Запрет hostPath volumes
│   │   └── runasnonroot.yaml         # Требование runAsNonRoot и readOnlyRootFilesystem
│   └── constraints/                   # Применение политик
│       ├── privileged.yaml           # Constraint для privileged
│       ├── hostpath.yaml             # Constraint для hostPath
│       └── runasnonroot.yaml         # Constraint для security context
├── verify/
│   ├── verify-admission.sh           # Проверка блокировки небезопасных подов
│   └── validate-security.sh          # Проверка работы безопасных подов
├── audit-policy.yaml                  # Политика аудита для API Server
└── README_FOR_REVIEWER.md            # Этот файл
```

## Реализованные политики безопасности

### 1. PodSecurity Admission (встроенный механизм K8s)

Namespace `audit-zone` настроен с уровнем `restricted`:

```yaml
labels:
  pod-security.kubernetes.io/enforce: restricted
  pod-security.kubernetes.io/audit: restricted
  pod-security.kubernetes.io/warn: restricted
```

**Что блокирует:**
- Привилегированные контейнеры
- HostPath, HostNetwork, HostPID, HostIPC
- Запуск от root (UID 0)
- Небезопасные capabilities
- Отсутствие seccompProfile

### 2. OPA Gatekeeper (расширенная политика)

#### ConstraintTemplate: K8sPSPPrivilegedContainer
Запрещает использование `privileged: true` в контейнерах.

**Проверяет:**
- `spec.containers[*].securityContext.privileged`
- `spec.initContainers[*].securityContext.privileged`
- `spec.ephemeralContainers[*].securityContext.privileged`

#### ConstraintTemplate: K8sPSPHostFilesystem
Запрещает использование `hostPath` volumes.

**Проверяет:**
- `spec.volumes[*].hostPath`
- Поддерживает whitelist разрешенных путей (если нужно)

#### ConstraintTemplate: K8sPSPRequiredSecurityContext
Требует обязательные настройки безопасности:

**Требования:**
- `runAsNonRoot: true` - запрет запуска от root
- `readOnlyRootFilesystem: true` - только чтение корневой ФС
- `allowPrivilegeEscalation: false` - запрет повышения привилегий
- `runAsUser != 0` - явный запрет UID 0

### 3. Audit Policy

Политика аудита логирует:
- Все операции с подами в namespace `audit-zone`
- Все отклоненные запросы (admission denied)
- Изменения в ConstraintTemplates и Constraints
- Изменения в RBAC и ServiceAccounts
- Операции с Secrets
- Опасные операции (exec, attach, portforward)

## Инструкция по развертыванию

### Шаг 1: Установка OPA Gatekeeper

```bash
# Установка Gatekeeper
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/deploy/gatekeeper.yaml

# Проверка установки
kubectl get pods -n gatekeeper-system
kubectl wait --for=condition=Ready pods --all -n gatekeeper-system --timeout=300s
```

### Шаг 2: Создание namespace с PodSecurity

```bash
cd task7
kubectl apply -f 01-create-namespace.yaml

# Проверка меток
kubectl get namespace audit-zone --show-labels
```

### Шаг 3: Установка ConstraintTemplates

```bash
# Установка всех шаблонов политик
kubectl apply -f gatekeeper/constraint-templates/

# Проверка установки
kubectl get constrainttemplates
```

**Ожидаемый вывод:**
```
NAME                            AGE
k8spsphostfilesystem           10s
k8spspprivilegedcontainer      10s
k8spsprequiredsecuritycontext  10s
```

### Шаг 4: Применение Constraints

```bash
# Применение политик к namespace audit-zone
kubectl apply -f gatekeeper/constraints/

# Проверка статуса
kubectl get constraints
```

### Шаг 5: Настройка Audit Policy (опционально)

Для включения аудита необходимо настроить API Server:

```bash
# Скопировать audit-policy.yaml на control plane ноду
# Добавить в /etc/kubernetes/manifests/kube-apiserver.yaml:

--audit-policy-file=/etc/kubernetes/audit-policy.yaml
--audit-log-path=/var/log/kubernetes/audit.log
--audit-log-maxage=30
--audit-log-maxbackup=10
--audit-log-maxsize=100
```

## Проверка работы

### Автоматическая проверка

```bash
cd task7/verify

# 1. Проверка блокировки небезопасных подов
chmod +x verify-admission.sh
./verify-admission.sh

# 2. Проверка работы безопасных подов
chmod +x validate-security.sh
./validate-security.sh
```

### Ручная проверка

#### Тест 1: Проверка блокировки privileged pod

```bash
kubectl apply -f insecure-manifests/01-privileged-pod.yaml
```

**Ожидаемый результат:**
```
Error from server (Forbidden): error when creating "insecure-manifests/01-privileged-pod.yaml":
pods "pod-privileged" is forbidden: violates PodSecurity "restricted:latest":
privileged (container "nginx" must not set securityContext.privileged=true)
```

#### Тест 2: Проверка блокировки hostPath

```bash
kubectl apply -f insecure-manifests/02-hostpath-pod.yaml
```

**Ожидаемый результат:**
```
Error from server (Forbidden): error when creating "insecure-manifests/02-hostpath-pod.yaml":
pods "pod-hostpath" is forbidden: violates PodSecurity "restricted:latest":
hostPath volumes (volume "host-volume")
```

#### Тест 3: Проверка блокировки root user

```bash
kubectl apply -f insecure-manifests/03-root-user-pod.yaml
```

**Ожидаемый результат:**
```
Error from server (Forbidden): error when creating "insecure-manifests/03-root-user-pod.yaml":
pods "pod-root-user" is forbidden: violates PodSecurity "restricted:latest":
runAsNonRoot != true (container "nginx" must not set securityContext.runAsNonRoot=false)
```

#### Тест 4: Развертывание безопасных подов

```bash
# Должны успешно создаться
kubectl apply -f secure-manifests/01-secure.yaml
kubectl apply -f secure-manifests/02-secure.yaml
kubectl apply -f secure-manifests/03-secure.yaml

# Проверка статуса
kubectl get pods -n audit-zone
```

**Ожидаемый результат:**
```
NAME           READY   STATUS    RESTARTS   AGE
pod-secure-1   1/1     Running   0          10s
pod-secure-2   1/1     Running   0          8s
pod-secure-3   1/1     Running   0          6s
```

## Проверка OPA Gatekeeper

### Проверка статуса Gatekeeper

```bash
# Проверка работы контроллера
kubectl get pods -n gatekeeper-system

# Проверка установленных шаблонов
kubectl get constrainttemplates

# Проверка активных constraints
kubectl get constraints
```

### Проверка логов Gatekeeper

```bash
# Логи контроллера
kubectl logs -n gatekeeper-system -l control-plane=controller-manager --tail=50

# Логи аудита
kubectl logs -n gatekeeper-system -l control-plane=audit-controller --tail=50
```

### Проверка нарушений политик

```bash
# Просмотр нарушений для конкретного constraint
kubectl get k8spspprivilegedcontainer psp-privileged-container -o yaml

# Статус всех constraints
kubectl get constraints -A
```
