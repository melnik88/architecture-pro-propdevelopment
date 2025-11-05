# Задание 5. Управление трафиком внутри кластера Kubernetes

## Описание

В этом задании реализовано разграничение трафика между сервисами в кластере Kubernetes с использованием Network Policies. Развернуты 4 сервиса с различными ролями и настроены политики для контроля сетевого взаимодействия между ними.

## Архитектура решения

### Сервисы

1. **front-end-app** - фронтенд приложение для обычных пользователей
2. **back-end-api** - API для обычных пользователей
3. **admin-front-end-app** - административный фронтенд
4. **admin-back-end-api** - административный API

### Сетевые политики

Реализованы следующие правила:
- `front-end` может взаимодействовать только с `back-end-api`
- `admin-front-end` может взаимодействовать только с `admin-back-end-api`
- API сервисы принимают трафик только от соответствующих фронтенд приложений
- Все остальные соединения запрещены

## Файлы проекта

- [`pods-deployment.yaml`](pods-deployment.yaml) - манифест для развертывания подов и сервисов
- [`non-admin-api-allow.yaml`](non-admin-api-allow.yaml) - сетевые политики для обычных сервисов
- [`admin-api-allow.yaml`](admin-api-allow.yaml) - сетевые политики для административных сервисов

## Инструкция по развертыванию

### 1. Развертывание подов и сервисов

```bash
kubectl apply -f pods-deployment.yaml
```

Проверка создания подов:
```bash
kubectl get pods -l 'role in (front-end,back-end-api,admin-front-end,admin-back-end-api)'
```

Проверка создания сервисов:
```bash
kubectl get svc -l 'role in (front-end,back-end-api,admin-front-end,admin-back-end-api)'
```

### 2. Применение сетевых политик

Применить политики для обычных сервисов:
```bash
kubectl apply -f non-admin-api-allow.yaml
```

Применить политики для административных сервисов:
```bash
kubectl apply -f admin-api-allow.yaml
```

Проверка созданных политик:
```bash
kubectl get networkpolicies
```

Детальная информация о политике:
```bash
kubectl describe networkpolicy back-end-api-policy
kubectl describe networkpolicy admin-back-end-api-policy
```

## Тестирование

### Тест 1: Проверка разрешенного трафика (front-end → back-end-api)

```bash
# Запуск тестового пода с меткой front-end
kubectl run test-frontend --rm -i -t --image=alpine --labels role=front-end -- sh

# Внутри пода выполнить:
/ # wget -qO- --timeout=2 http://back-end-api
```

**Ожидаемый результат:** Успешное подключение, получение HTML страницы nginx.

### Тест 2: Проверка запрещенного трафика (front-end → admin-back-end-api)

```bash
# Запуск тестового пода с меткой front-end
kubectl run test-frontend-2 --rm -i -t --image=alpine --labels role=front-end -- sh

# Внутри пода выполнить:
/ # wget -qO- --timeout=2 http://admin-back-end-api
```

**Ожидаемый результат:** Timeout, соединение заблокировано.

### Тест 3: Проверка разрешенного трафика (admin-front-end → admin-back-end-api)

```bash
# Запуск тестового пода с меткой admin-front-end
kubectl run test-admin-frontend --rm -i -t --image=alpine --labels role=admin-front-end -- sh

# Внутри пода выполнить:
/ # wget -qO- --timeout=2 http://admin-back-end-api
```

**Ожидаемый результат:** Успешное подключение, получение HTML страницы nginx.

### Тест 4: Проверка запрещенного трафика (admin-front-end → back-end-api)

```bash
# Запуск тестового пода с меткой admin-front-end
kubectl run test-admin-frontend-2 --rm -i -t --image=alpine --labels role=admin-front-end -- sh

# Внутри пода выполнить:
/ # wget -qO- --timeout=2 http://back-end-api
```

**Ожидаемый результат:** Timeout, соединение заблокировано.

### Тест 5: Проверка запрещенного трафика от пода без метки

```bash
# Запуск тестового пода без специальной метки
kubectl run test-no-label --rm -i -t --image=alpine -- sh

# Внутри пода выполнить:
/ # wget -qO- --timeout=2 http://back-end-api
/ # wget -qO- --timeout=2 http://admin-back-end-api
```

**Ожидаемый результат:** Timeout для обоих запросов, соединения заблокированы.

## Матрица доступа

| Источник | Назначение | Доступ |
|----------|------------|--------|
| front-end | back-end-api | ✅ Разрешен |
| front-end | admin-back-end-api | ❌ Запрещен |
| admin-front-end | admin-back-end-api | ✅ Разрешен |
| admin-front-end | back-end-api | ❌ Запрещен |
| Другие поды | back-end-api | ❌ Запрещен |
| Другие поды | admin-back-end-api | ❌ Запрещен |

## Очистка ресурсов

Для удаления всех созданных ресурсов:

```bash
# Удаление сетевых политик
kubectl delete -f non-admin-api-allow.yaml
kubectl delete -f admin-api-allow.yaml

# Удаление подов и сервисов
kubectl delete -f pods-deployment.yaml
```

Или удалить все ресурсы по меткам:

```bash
kubectl delete networkpolicy --all
kubectl delete pod -l 'role in (front-end,back-end-api,admin-front-end,admin-back-end-api)'
kubectl delete svc -l 'role in (front-end,back-end-api,admin-front-end,admin-back-end-api)'
```
