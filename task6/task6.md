# Задание 6. Аудит активности пользователей и обнаружение инцидентов

Вам необходимо настроить аудит активности пользователей, чтобы своевременно обнаруживать аномалии, попытки несанкционированного доступа и другие угрозы.
Что нужно сделать

# Шаг 1. Настройте среду
Minikube с включённым audit-policy.yaml и экспортом лога (/var/log/audit.log).
```
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  - level: RequestResponse
    verbs: \["create", "delete", "update", "patch", "get", "list"\]
    resources:
      - group: ""
        resources: \["pods", "secrets", "configmaps", "serviceaccounts", "roles", "rolebindings"\]
  - level: Metadata
    resources:
      - group: "\*"
        resources: \["\*"\]
```

# Шаг 2. Запустите скрипт симуляции действий

```bash simulate-incident.sh```

Скрипт выполняет следующие действия:
1. Доступ к secrets от system:serviceaccount:monitoring.
2. Создание привилегированного пода.
3. Использование kubectl exec в чужом поде.
4. Удаление audit-policy.
5. Создание RoleBinding без согласования.

```
#!/bin/bash

kubectl create ns secure-ops
kubectl config set-context --current --namespace=secure-ops

kubectl create sa monitoring
kubectl run attacker-pod --image=alpine --command -- sleep 3600
kubectl auth can-i get secrets --as=system:serviceaccount:secure-ops:monitoring

kubectl get secret -n kube-system $(kubectl get secrets -n kube-system | grep default-token | head -n1 | awk '{print $1}') --as=system:serviceaccount:secure-ops:monitoring

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: privileged-pod
spec:
  containers:
  - name: pwn
    image: alpine
    command: ["sleep", "3600"]
    securityContext:
      privileged: true
  restartPolicy: Never
EOF

kubectl exec -n kube-system $(kubectl get pods -n kube-system | grep coredns | awk '{print $1}' | head -n1) -- cat /etc/resolv.conf

kubectl delete -f /etc/kubernetes/audit-policy.yaml --as=admin

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: escalate-binding
subjects:
- kind: ServiceAccount
  name: monitoring
  namespace: secure-ops
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
EOF
```

# Шаг 3. Проведите анализ audit.log
Найдите и распишите:
1. Кто инициировал каждое из действий.
2. Какие действия могли быть вредоносными.
3. Что можно считать компрометацией кластера.
4. Какие ошибки допускает политика RBAC.
5. Для анализа подготовьте скрипт.

На проверку вам нужно передать три артефакта:
1. analysis.md: краткий отчёт по выявленным событиям.
Шаблон отчёта:
# Отчёт по результатам анализа Kubernetes Audit Log

## Подозрительные события
```
1. Доступ к секретам:
   - Кто: ...
   - Где: ...
   - Почему подозрительно: ...

2. Привилегированные поды:
   - Кто: ...
   - Комментарий: ...

3. Использование kubectl exec в чужом поде:
   - Кто: ...
   - Что делал: ...

4. Создание RoleBinding с правами cluster-admin:
   - Кто: ...
   - К чему привело: ...

5. Удаление audit-policy.yaml:
   - Кто: ...
   - Возможные последствия: ...

## Вывод

...
```

2. audit-extract.json: выжимка из audit.log, содержащая подозрительные события.
3. Скрипт фильтрации audit.log, написанный на Bash или Python.

### Как проверить самостоятельно

1. Проверка на события доступа к secrets:
```jq 'select(.objectRef.resource=="secrets" and .verb=="get")' audit.log```

2. Проверка на kubectl exec в чужие поды:
```jq 'select(.verb=="create" and .objectRef.subresource=="exec")' audit.log```

3. Привилегированные поды:
```jq 'select(.objectRef.resource=="pods" and .requestObject.spec.containers[].securityContext.privileged==true)' audit.log```

4. Удаление или изменение audit policy:

```grep -i 'audit-policy' audit.log```

Когда вы выполните задание, у вас должно получиться три файла: analysis.md — краткий отчёт по выявленным событиям, audit-extract.json — выжимка из audit.log с подозрительными событиями и скрипт фильтрации audit.log на Bash или Python. Когда будете сдавать работу, загрузите файлы в директорию Task6 в рамках пул-реквеста.
