#!/bin/bash

# Скрипт для создания пользователей Kubernetes с сертификатами
# Для PropDevelopment RBAC

set -e

echo "==================================="
echo "Создание пользователей Kubernetes"
echo "==================================="

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Директория для хранения сертификатов
CERT_DIR="./k8s-certs"
mkdir -p "$CERT_DIR"

# Функция для создания пользователя
create_user() {
    local USERNAME=$1
    local GROUP=$2
    local DESCRIPTION=$3

    echo -e "\n${YELLOW}Создание пользователя: $USERNAME${NC}"
    echo "Группа: $GROUP"
    echo "Описание: $DESCRIPTION"

    # Генерация приватного ключа
    openssl genrsa -out "$CERT_DIR/$USERNAME.key" 2048
    echo -e "${GREEN}✓${NC} Создан приватный ключ: $CERT_DIR/$USERNAME.key"

    # Создание запроса на подпись сертификата (CSR)
    openssl req -new -key "$CERT_DIR/$USERNAME.key" \
        -out "$CERT_DIR/$USERNAME.csr" \
        -subj "/CN=$USERNAME/O=$GROUP"
    echo -e "${GREEN}✓${NC} Создан CSR: $CERT_DIR/$USERNAME.csr"

    # Подпись сертификата CA кластера (используем minikube CA)
    if [ -f ~/.minikube/ca.crt ] && [ -f ~/.minikube/ca.key ]; then
        openssl x509 -req -in "$CERT_DIR/$USERNAME.csr" \
            -CA ~/.minikube/ca.crt \
            -CAkey ~/.minikube/ca.key \
            -CAcreateserial \
            -out "$CERT_DIR/$USERNAME.crt" \
            -days 365
        echo -e "${GREEN}✓${NC} Подписан сертификат: $CERT_DIR/$USERNAME.crt"
    else
        echo "ВНИМАНИЕ: CA сертификаты minikube не найдены"
        echo "Для production используйте: kubectl certificate approve"
    fi

    # Создание kubeconfig для пользователя
    KUBECONFIG_FILE="$CERT_DIR/$USERNAME-kubeconfig"

    # Получение адреса API сервера
    API_SERVER=$(kubectl config view -o jsonpath='{.clusters[0].cluster.server}')

    # Создание kubeconfig
    kubectl config set-cluster minikube \
        --server="$API_SERVER" \
        --certificate-authority="$HOME/.minikube/ca.crt" \
        --embed-certs=true \
        --kubeconfig="$KUBECONFIG_FILE"

    kubectl config set-credentials "$USERNAME" \
        --client-certificate="$CERT_DIR/$USERNAME.crt" \
        --client-key="$CERT_DIR/$USERNAME.key" \
        --embed-certs=true \
        --kubeconfig="$KUBECONFIG_FILE"

    kubectl config set-context "$USERNAME-context" \
        --cluster=minikube \
        --user="$USERNAME" \
        --kubeconfig="$KUBECONFIG_FILE"

    kubectl config use-context "$USERNAME-context" \
        --kubeconfig="$KUBECONFIG_FILE"

    echo -e "${GREEN}✓${NC} Создан kubeconfig: $KUBECONFIG_FILE"
    echo -e "${GREEN}✓${NC} Пользователь $USERNAME успешно создан"
}

# =================================
# Создание пользователей
# =================================

echo -e "\n${YELLOW}=== Администраторы кластера (cluster-admin) ===${NC}"
create_user "admin-devops" "system:masters" "Старший DevOps-инженер"
create_user "admin-infra" "system:masters" "Системный администратор"

echo -e "\n${YELLOW}=== Специалисты по безопасности (security-auditor) ===${NC}"
create_user "security-auditor" "security:auditors" "Специалист по ИБ"

echo -e "\n${YELLOW}=== Команды разработки - namespace-editor ===${NC}"

# Домен Sales
create_user "owner-sales" "namespace:sales:editors" "Владелец продукта домена Продажи"
create_user "devops-sales" "namespace:sales:editors" "DevOps-инженер команды продаж"
create_user "dev-backend-sales" "namespace:sales:editors" "Backend-разработчик команды продаж"
create_user "dev-frontend-sales" "namespace:sales:editors" "Frontend-разработчик команды продаж"

# Домен Tenant Services
create_user "owner-tenant" "namespace:tenant-services:editors" "Владелец продукта домена ЖКУ"
create_user "devops-tenant" "namespace:tenant-services:editors" "DevOps-инженер команды ЖКУ"
create_user "dev-backend-tenant" "namespace:tenant-services:editors" "Backend-разработчик команды ЖКУ"
create_user "dev-smarthome" "namespace:tenant-services:editors" "Разработчик Smart Home Integration"

# Домен Finance
create_user "owner-finance" "namespace:finance:editors" "Владелец продукта домена Финансы"
create_user "dev-finance" "namespace:finance:editors" "Разработчик финансовых систем"

# Домен Data
create_user "owner-data" "namespace:data:editors" "Владелец продукта домена Дата"
create_user "dev-data" "namespace:data:editors" "Разработчик систем обработки данных"

echo -e "\n${YELLOW}=== Мониторинг и бизнес - namespace-viewer ===${NC}"

# Операторы и аналитики
create_user "ops-sales" "namespace:sales:viewers" "Инженер по эксплуатации команды продаж"
create_user "analyst-clients" "namespace:sales:viewers" "Бизнес-аналитик, работающий с клиентами"

create_user "ops-tenant" "namespace:tenant-services:viewers" "Инженер по эксплуатации команды ЖКУ"
create_user "analyst-zku" "namespace:tenant-services:viewers" "Бизнес-аналитик, оптимизирующий процессы ЖКУ"

create_user "ops-finance" "namespace:finance:viewers" "Инженер по эксплуатации финансовой команды"
create_user "accountant" "namespace:finance:viewers" "Бухгалтер"

create_user "ops-monitoring" "namespace:data:viewers" "Инженер мониторинга"
create_user "analyst-bi" "namespace:data:viewers" "Аналитик BI"

echo -e "\n${GREEN}==================================="
echo "Все пользователи успешно созданы!"
echo "===================================${NC}"

echo -e "\nСертификаты и kubeconfig файлы находятся в директории: $CERT_DIR"
echo -e "\nДля использования kubeconfig пользователя:"
echo -e "  export KUBECONFIG=$CERT_DIR/<username>-kubeconfig"
echo -e "  kubectl get pods"

echo -e "\n${YELLOW}Созданные пользователи:${NC}"
echo "  Администраторы (2): admin-devops, admin-infra"
echo "  Аудиторы безопасности (1): security-auditor"
echo "  Команды разработки (12): owner-*, devops-*, dev-*"
echo "  Мониторинг и аналитика (8): ops-*, analyst-*, accountant"
echo "  ВСЕГО: 23 пользователя"

echo -e "\n${YELLOW}ВАЖНО:${NC}"
echo "1. Сертификаты действительны 365 дней"
echo "2. Храните приватные ключи в безопасном месте"
echo "3. Не коммитьте сертификаты в git"
echo "4. Для production используйте систему управления секретами (Vault, etc.)"
echo "5. После создания пользователей выполните скрипт 2-create-roles.sh"

# Создание .gitignore для защиты сертификатов
cat > "$CERT_DIR/.gitignore" << EOF
# Игнорировать все сертификаты и ключи
*.key
*.crt
*.csr
*-kubeconfig
*.srl
EOF

echo -e "\n${GREEN}✓${NC} Создан .gitignore для защиты сертификатов"
