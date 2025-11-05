#!/bin/bash

# Скрипт симуляции инцидентов безопасности в Kubernetes
# Выполняет различные подозрительные действия для тестирования аудита

echo "=== Начало симуляции инцидентов безопасности ==="

# Создание namespace для тестирования
echo "1. Создание namespace secure-ops..."
kubectl create ns secure-ops
kubectl config set-context --current --namespace=secure-ops

# Создание ServiceAccount и пода
echo "2. Создание ServiceAccount monitoring и пода attacker-pod..."
kubectl create sa monitoring
kubectl run attacker-pod --image=alpine --command -- sleep 3600

# Проверка прав доступа к secrets
echo "3. Проверка прав доступа к secrets..."
kubectl auth can-i get secrets --as=system:serviceaccount:secure-ops:monitoring

# Попытка доступа к секретам в kube-system
echo "4. Попытка доступа к секретам в kube-system..."
kubectl get secret -n kube-system $(kubectl get secrets -n kube-system | grep default-token | head -n1 | awk '{print $1}') --as=system:serviceaccount:secure-ops:monitoring

# Создание привилегированного пода
echo "5. Создание привилегированного пода..."
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

# Использование kubectl exec в чужом поде
echo "6. Использование kubectl exec в поде kube-system..."
kubectl exec -n kube-system $(kubectl get pods -n kube-system | grep coredns | awk '{print $1}' | head -n1) -- cat /etc/resolv.conf

# Попытка удаления audit-policy
echo "7. Попытка удаления audit-policy.yaml..."
kubectl delete -f /etc/kubernetes/audit-policy.yaml --as=admin 2>/dev/null || echo "Не удалось удалить audit-policy (ожидаемо)"

# Создание опасного RoleBinding
echo "8. Создание RoleBinding с правами cluster-admin..."
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: escalate-binding
  namespace: secure-ops
subjects:
- kind: ServiceAccount
  name: monitoring
  namespace: secure-ops
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
EOF

echo "=== Симуляция инцидентов завершена ==="
echo "Проверьте audit.log для анализа событий"
