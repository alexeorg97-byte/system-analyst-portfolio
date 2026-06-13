# API Overview — MigrationOS

## 1. Назначение документа

Документ описывает общий подход к проектированию API платформы MigrationOS.

API Overview нужен, чтобы:

- зафиксировать принципы REST API;
- описать основные API-домены;
- показать связь API с ролями, permissions и моделью данных;
- определить единый подход к ошибкам, пагинации, фильтрации и сортировке;
- описать webhook-подход для интеграций;
- подготовить основу для `openapi.yaml`, API-документации и тестирования.

Документ не заменяет полную OpenAPI-спецификацию. Его задача — зафиксировать архитектурные правила, границы доменов и единые API-подходы.

---

## 2. Общие принципы API

| Принцип | Описание |
|---|---|
| REST-подход | Основные операции выполняются через HTTP-методы и ресурсы |
| JSON | Основной формат обмена данными — JSON |
| Версионирование | Все endpoints имеют префикс `/api/v1` |
| Auth required by default | Все приватные endpoints требуют авторизации |
| RBAC + context access | Доступ проверяется по роли, permission и контексту данных |
| Backend as source of truth | Frontend не определяет финальные статусы самостоятельно |
| Idempotency | Webhook и критичные повторяемые операции должны быть устойчивы к дублям |
| Auditability | Критичные действия должны попадать в audit log |
| Least privilege | API возвращает только данные, доступные пользователю |
| Secure by design | ПДн, документы, риски и платежи возвращаются только в разрешенном scope |

---

## 3. Базовый URL и версия

Базовый путь API:

```http
/api/v1
```

Примеры:

```http
GET /api/v1/migrants
GET /api/v1/migrants/{migrantId}
POST /api/v1/documents
POST /api/v1/integrations/rkl/webhook
```

Версионирование через URL выбрано потому, что оно:

- понятно frontend- и mobile-разработчикам;
- удобно для документации и тестирования;
- позволяет поддерживать несколько версий API при изменении контрактов;
- хорошо читается в OpenAPI и gateway-настройках.

---

## 4. Формат данных

### 4.1. Request / Response

Основной формат данных:

```http
Content-Type: application/json
Accept: application/json
```

Пример ответа:

```json
{
  "id": "b5c2f21e-3e18-4f21-b41b-27a8a5d11111",
  "status": "active",
  "createdAt": "2026-05-01T10:30:00Z"
}
```

### 4.2. Naming convention

| Уровень | Формат |
|---|---|
| JSON fields | `camelCase` |
| SQL fields | `snake_case` |
| URL resources | `plural nouns` |
| Status values | `snake_case` |

Пример соответствия:

| SQL | JSON |
|---|---|
| `created_at` | `createdAt` |
| `employer_id` | `employerId` |
| `service_order_id` | `serviceOrderId` |

### 4.3. Политика частичных обновлений

- Для частичных изменений используется `PATCH`.
- Для создания ресурса используется `POST`.
- Для чтения используется `GET`.
- Для удаления или архивирования в MVP предпочтительнее явная бизнес-операция, а не физическое удаление ресурса.

Пример:

```http
PATCH /api/v1/migrants/{migrantId}
PATCH /api/v1/documents/{documentId}
POST /api/v1/requests/{requestId}/status
```

---

## 5. Авторизация и доступ

### 5.1. Auth

Для приватных endpoints используется bearer token:

```http
Authorization: Bearer <access_token>
```

### 5.2. Проверка доступа

Доступ проверяется на трех уровнях:

| Уровень | Пример |
|---|---|
| Роль | `migrant`, `employer`, `manager`, `supervisor`, `superadmin` |
| Permission | `document.read`, `request.create`, `payment.read` |
| Контекст | `own`, `org`, `assigned`, `agency`, `technical` |

### 5.3. Примеры контекстов

| Контекст | Описание |
|---|---|
| `own` | Пользователь видит только свои данные |
| `org` | Работодатель видит только данные своей организации |
| `assigned` | Менеджер видит назначенные ему данные |
| `agency` | Внутренние роли агентства видят данные по агентству |
| `technical` | Технический или интеграционный доступ |

### 5.4. Общие правила авторизации

| ID | Правило |
|---|---|
| API-AUTHZ-001 | Backend обязан проверять роль, permission и контекст доступа |
| API-AUTHZ-002 | UI-ограничения не заменяют backend authorization |
| API-AUTHZ-003 | Доступ к чужой сущности должен возвращать `403 Forbidden` или безопасный `404` по политике защиты от enumeration |
| API-AUTHZ-004 | Внутренние комментарии и служебные поля не возвращаются внешним ролям |
| API-AUTHZ-005 | Критичные административные действия должны логироваться в audit log |

---

## 6. Основные API-домены

| Домен | Назначение |
|---|---|
| Auth API | Авторизация, OTP, refresh token, профиль текущей сессии |
| Users API | Пользователи, роли, профиль, служебные операции по доступу |
| Migrants API | Карточки мигрантов, связанные данные и риск |
| Employers API | Работодатели и кабинет работодателя |
| Documents API | Документы, файлы, статусы проверки |
| Requests API | Запросы между мигрантом, работодателем и агентством |
| Marketplace API | Каталог услуг и заявки |
| Payments API | Платежи, счета, подтверждение оплаты |
| RKL API | Прием результатов SHERPA RPA и чтение РКЛ-истории |
| Notifications API | Уведомления пользователей |
| Chats API | Диалоги и сообщения |
| Analytics API | Дашборды, агрегаты, риски, операционные выборки |
| Admin API | Административные и технические операции |

---

## 7. Auth API

### 7.1. Назначение

Auth API отвечает за вход, выпуск токенов, обновление сессии и получение текущего пользователя.

### 7.2. Примеры endpoints

| Метод | Endpoint | Назначение |
|---|---|---|
| `POST` | `/auth/otp/request` | Запросить OTP для входа мигранта |
| `POST` | `/auth/otp/verify` | Подтвердить OTP и создать сессию |
| `POST` | `/auth/login` | Вход web-пользователя |
| `POST` | `/auth/refresh` | Обновить access token |
| `POST` | `/auth/logout` | Завершить сессию |
| `GET` | `/auth/me` | Получить текущего пользователя |

### 7.3. Правила

| ID | Правило |
|---|---|
| API-AUTH-001 | OTP используется для мобильного приложения мигранта |
| API-AUTH-002 | Внутренние роли должны поддерживать 2FA |
| API-AUTH-003 | Заблокированный пользователь не может получить token |
| API-AUTH-004 | Refresh token должен иметь отдельный срок жизни |
| API-AUTH-005 | Попытки OTP и ошибки входа должны попадать в security/audit log по политике безопасности |

---

## 8. Users API

### 8.1. Назначение

Users API покрывает профиль пользователя, служебные операции по управлению учетной записью и, для административных ролей, операции управления доступом.

### 8.2. Примеры endpoints

| Метод | Endpoint | Назначение |
|---|---|---|
| `GET` | `/users/me` | Получить профиль текущего пользователя |
| `PATCH` | `/users/me` | Обновить собственный профиль |
| `GET` | `/users/{userId}` | Получить пользователя по ID |
| `PATCH` | `/users/{userId}` | Обновить пользователя |
| `POST` | `/users/{userId}/block` | Заблокировать пользователя |
| `POST` | `/users/{userId}/unblock` | Разблокировать пользователя |
| `POST` | `/users/{userId}/change-role` | Изменить системную роль |

### 8.3. Правила

| ID | Правило |
|---|---|
| API-USER-001 | Пользователь может читать и обновлять только собственный профиль, если не имеет административных прав |
| API-USER-002 | Изменение роли пользователя доступно только `superadmin` |
| API-USER-003 | Блокировка, разблокировка и смена роли должны логироваться |
| API-USER-004 | API не должен возвращать чувствительные внутренние поля, например `passwordHash` |

---

## 9. Migrants API

### 9.1. Назначение

Migrant API управляет карточками мигрантов и их отображением в мобильном приложении, кабинете работодателя и админ-панели.

### 9.2. Примеры endpoints

| Метод | Endpoint | Назначение |
|---|---|---|
| `GET` | `/migrants` | Получить список мигрантов |
| `GET` | `/migrants/{migrantId}` | Получить карточку мигранта |
| `POST` | `/migrants` | Создать карточку мигранта |
| `PATCH` | `/migrants/{migrantId}` | Обновить карточку |
| `GET` | `/migrants/{migrantId}/risk` | Получить риск-статус |
| `GET` | `/migrants/{migrantId}/documents` | Получить документы мигранта |
| `GET` | `/migrants/{migrantId}/requests` | Получить запросы мигранта |
| `GET` | `/migrants/{migrantId}/rkl-checks` | Получить историю РКЛ-проверок |

### 9.3. Доступ

| Роль | Доступ |
|---|---|
| `migrant` | Только свой профиль |
| `employer` | Только мигранты своей организации |
| `manager` | Назначенные мигранты или проектный scope |
| `supervisor` | Расширенный просмотр и аналитика |
| `superadmin` | Полный административный доступ |

### 9.4. Правила

| ID | Правило |
|---|---|
| API-MIG-001 | `migrant` не может открыть чужую карточку мигранта |
| API-MIG-002 | `employer` получает данные только по `org`-контексту |
| API-MIG-003 | Поля с ПДн должны возвращаться только ролям с разрешенным scope |
| API-MIG-004 | Статус карточки мигранта должен соответствовать Status Models |

---

## 10. Employers API

### 10.1. Назначение

Employers API обслуживает кабинет работодателя, чтение и ограниченное обновление данных организации, а также связанные выборки по мигрантам, запросам и заявкам.

### 10.2. Примеры endpoints

| Метод | Endpoint | Назначение |
|---|---|---|
| `GET` | `/employers/me` | Получить организацию текущего работодателя |
| `GET` | `/employers/{employerId}` | Получить работодателя |
| `PATCH` | `/employers/{employerId}` | Обновить данные работодателя |
| `GET` | `/employers/{employerId}/migrants` | Получить мигрантов работодателя |
| `GET` | `/employers/{employerId}/requests` | Получить запросы работодателя |
| `GET` | `/employers/{employerId}/service-orders` | Получить заявки работодателя |

### 10.3. Правила

| ID | Правило |
|---|---|
| API-EMP-001 | Работодатель не является tenant |
| API-EMP-002 | `employer` user не может получить данные чужой организации |
| API-EMP-003 | Проверка доступа выполняется по `employerId` и контексту `org` |
| API-EMP-004 | Прямой URL к чужому `employerId` должен возвращать `403 Forbidden` или безопасный `404` |

---

## 11. Documents API

### 11.1. Назначение

Documents API отвечает за документы мигрантов, статусы проверки, загрузку файлов и безопасный доступ к файлам.

### 11.2. Примеры endpoints

| Метод | Endpoint | Назначение |
|---|---|---|
| `GET` | `/documents` | Список документов |
| `GET` | `/documents/{documentId}` | Карточка документа |
| `POST` | `/documents` | Создать документ |
| `PATCH` | `/documents/{documentId}` | Обновить метаданные |
| `POST` | `/documents/{documentId}/files` | Загрузить файл |
| `POST` | `/documents/{documentId}/approve` | Подтвердить документ |
| `POST` | `/documents/{documentId}/reject` | Отклонить документ |
| `GET` | `/documents/{documentId}/download-url` | Получить временную ссылку на файл |

### 11.3. Правила

| ID | Правило |
|---|---|
| API-DOC-001 | Внешний пользователь получает доступ только к разрешенным документам |
| API-DOC-002 | Файлы не должны иметь публичных URL |
| API-DOC-003 | Скачивание файла может логироваться |
| API-DOC-004 | Отклонение документа требует `reason` |
| API-DOC-005 | Статус документа меняется только по Status Model |
| API-DOC-006 | Временная ссылка на файл должна быть ограничена по времени и формироваться только после backend-проверки прав |

---

## 12. Requests API

### 12.1. Назначение

Requests API управляет запросами между мигрантом, работодателем и агентством.

### 12.2. Примеры endpoints

| Метод | Endpoint | Назначение |
|---|---|---|
| `GET` | `/requests` | Получить список запросов |
| `GET` | `/requests/{requestId}` | Получить запрос |
| `POST` | `/requests` | Создать запрос |
| `PATCH` | `/requests/{requestId}` | Обновить запрос |
| `POST` | `/requests/{requestId}/status` | Изменить статус |
| `POST` | `/requests/{requestId}/comments` | Добавить комментарий |
| `POST` | `/requests/{requestId}/assign` | Назначить ответственного |

### 12.3. Правила

| ID | Правило |
|---|---|
| API-REQ-001 | Мигрант может создавать запрос только от своего имени |
| API-REQ-002 | Работодатель видит только запросы своей организации |
| API-REQ-003 | Агентство видит запросы для контроля |
| API-REQ-004 | `internalComment` не возвращается внешним ролям |
| API-REQ-005 | Недопустимый статусный переход возвращает `409 Conflict` |

---

## 13. Marketplace API

### 13.1. Назначение

Marketplace API отвечает за каталог услуг и заявки на услуги.

### 13.2. Примеры endpoints

| Метод | Endpoint | Назначение |
|---|---|---|
| `GET` | `/services` | Получить каталог услуг |
| `GET` | `/services/{serviceId}` | Получить услугу |
| `POST` | `/service-orders` | Создать заявку |
| `GET` | `/service-orders` | Получить список заявок |
| `GET` | `/service-orders/{serviceOrderId}` | Получить заявку |
| `POST` | `/service-orders/{serviceOrderId}/status` | Изменить статус заявки |
| `POST` | `/service-orders/{serviceOrderId}/assign` | Назначить исполнителя |

### 13.3. Правила

| ID | Правило |
|---|---|
| API-SERVICE-001 | Неактивные услуги не отображаются внешним пользователям |
| API-SO-001 | Платная заявка должна ожидать payment webhook |
| API-SO-002 | Frontend redirect не переводит заявку в `paid` |
| API-SO-003 | Работодатель может создавать заявку только по своим мигрантам |
| API-SO-004 | Статус заявки должен соответствовать Status Model |

---

## 14. Payments API

### 14.1. Назначение

Payments API управляет платежами, счетами и подтверждением оплаты от внешнего провайдера.

### 14.2. Примеры endpoints

| Метод | Endpoint | Назначение |
|---|---|---|
| `POST` | `/payments` | Создать платеж |
| `GET` | `/payments/{paymentId}` | Получить платеж |
| `POST` | `/payments/webhook` | Принять payment webhook |
| `GET` | `/invoices/{invoiceId}` | Получить счет |
| `POST` | `/service-orders/{serviceOrderId}/invoice` | Создать счет по заявке |

### 14.3. Правила

| ID | Правило |
|---|---|
| API-PAY-001 | Webhook является источником истины для оплаты |
| API-PAY-002 | Webhook должен быть идемпотентным |
| API-PAY-003 | Повторное событие не должно повторно менять бизнес-сущность |
| API-PAY-004 | Webhook должен проверять подпись, API key или другой механизм доверия |
| API-PAY-005 | Смена payment status должна логироваться |

---

## 15. RKL API

### 15.1. Назначение

RKL API принимает результаты проверок от SHERPA RPA и предоставляет чтение истории РКЛ по мигрантам для разрешенных ролей.

### 15.2. Примеры endpoints

| Метод | Endpoint | Назначение |
|---|---|---|
| `POST` | `/integrations/rkl/webhook` | Принять результат РКЛ-проверки |
| `GET` | `/rkl-checks` | Получить список РКЛ-проверок |
| `GET` | `/migrants/{migrantId}/rkl-checks` | Получить историю РКЛ мигранта |

### 15.3. Правила

| ID | Правило |
|---|---|
| API-RKL-001 | Источник РКЛ-результатов — только SHERPA RPA |
| API-RKL-002 | Webhook должен иметь `eventId` для идемпотентности |
| API-RKL-003 | Результат РКЛ не редактируется пользователями |
| API-RKL-004 | При `matched = true` risk level должен стать `critical` |
| API-RKL-005 | Все события должны попадать в `IntegrationLog` |

---

## 16. Notifications API

### 16.1. Назначение

Notifications API управляет уведомлениями пользователей и статусом их прочтения.

### 16.2. Примеры endpoints

| Метод | Endpoint | Назначение |
|---|---|---|
| `GET` | `/notifications` | Получить уведомления текущего пользователя |
| `POST` | `/notifications/{notificationId}/read` | Отметить уведомление прочитанным |
| `POST` | `/notifications/send` | Создать или отправить уведомление внутренним процессом |

### 16.3. Правила

| ID | Правило |
|---|---|
| API-NOTIF-001 | Пользователь видит только свои уведомления |
| API-NOTIF-002 | Ошибка доставки не откатывает основную операцию |
| API-NOTIF-003 | Критичные уведомления создаются при изменениях риска, документов и заявок |

---

## 17. Chats API

### 17.1. Назначение

Chats API отвечает за диалоги и сообщения.

### 17.2. Примеры endpoints

| Метод | Endpoint | Назначение |
|---|---|---|
| `GET` | `/chat/threads` | Получить список диалогов |
| `GET` | `/chat/threads/{threadId}` | Получить диалог |
| `POST` | `/chat/threads` | Создать диалог |
| `POST` | `/chat/threads/{threadId}/messages` | Отправить сообщение |
| `POST` | `/chat/threads/{threadId}/close` | Закрыть диалог |

### 17.3. Правила

| ID | Правило |
|---|---|
| API-CHAT-001 | Доступ к чату проверяется по контексту участника |
| API-CHAT-002 | Сообщение должно содержать текст или вложение |
| API-CHAT-003 | Внешние пользователи не видят внутренние обсуждения агентства |

---

## 18. Analytics API

### 18.1. Назначение

Analytics API предоставляет агрегированные данные для дашбордов и операционной аналитики.

### 18.2. Примеры endpoints

| Метод | Endpoint | Назначение |
|---|---|---|
| `GET` | `/analytics/dashboard` | Общий дашборд |
| `GET` | `/analytics/risks` | Риск-аналитика |
| `GET` | `/analytics/documents/expiring` | Документы с истекающим сроком |
| `GET` | `/analytics/service-orders` | Аналитика заявок |
| `GET` | `/analytics/integrations/errors` | Ошибки интеграций |

### 18.3. Правила

| ID | Правило |
|---|---|
| API-AN-001 | Analytics API учитывает роль и scope пользователя |
| API-AN-002 | Работодатель видит аналитику только по своей организации |
| API-AN-003 | Supervisor видит агрегированную аналитику агентства |
| API-AN-004 | Дашборды не должны раскрывать лишние ПДн |

---

## 19. Admin API

### 19.1. Назначение

Admin API покрывает административные и технические операции: роли, permissions, справочники, системные настройки, журналы и retry интеграционных событий.

### 19.2. Примеры endpoints

| Метод | Endpoint | Назначение |
|---|---|---|
| `GET` | `/admin/roles` | Получить роли |
| `GET` | `/admin/permissions` | Получить permissions |
| `PATCH` | `/admin/settings` | Обновить системные настройки |
| `GET` | `/admin/audit-log` | Получить audit log |
| `GET` | `/admin/integration-log` | Получить integration log |
| `POST` | `/admin/integration-log/{integrationEventId}/retry` | Повторная обработка события |
| `GET` | `/admin/dictionaries/{dictionaryName}` | Получить справочник |

### 19.3. Правила

| ID | Правило |
|---|---|
| API-ADMIN-001 | Административные операции доступны только внутренним ролям с нужными permissions |
| API-ADMIN-002 | Retry интеграционного события должен логироваться |
| API-ADMIN-003 | Управление ролями и настройками доступно только `superadmin` или другой явно разрешенной административной роли |
| API-ADMIN-004 | Административные endpoints не должны возвращать лишние чувствительные данные без необходимости |

---

## 20. Пагинация, фильтрация и сортировка

### 20.1. Пагинация

Для списков используется `limit-offset` или `cursor`-подход. В MVP допускается `limit-offset`, для длинных списков и журналов рекомендуется предусмотреть переход на cursor-подход.

Пример:

```http
GET /api/v1/migrants?limit=20&offset=0
```

Ответ:

```json
{
  "items": [],
  "pagination": {
    "limit": 20,
    "offset": 0,
    "total": 150
  }
}
```

### 20.2. Фильтрация

Примеры:

```http
GET /api/v1/migrants?employerId=...&status=active&riskLevel=critical
GET /api/v1/documents?status=under_review&documentType=patent
GET /api/v1/service-orders?status=waiting_payment
```

### 20.3. Сортировка

Примеры:

```http
GET /api/v1/documents?sort=expirationDate:asc
GET /api/v1/requests?sort=createdAt:desc
```

### 20.4. Общие правила списков

| ID | Правило |
|---|---|
| API-LIST-001 | Все list endpoints должны поддерживать пагинацию |
| API-LIST-002 | Сортировка должна быть ограничена поддерживаемым набором полей |
| API-LIST-003 | Фильтрация должна учитываться после применения scope доступа |
| API-LIST-004 | Поля фильтрации должны быть согласованы с моделью данных и индексами |

---

## 21. Модель ошибок

Единый формат ошибки:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Validation failed",
    "details": [
      {
        "field": "expirationDate",
        "message": "expirationDate must be greater than issueDate"
      }
    ],
    "traceId": "req-123"
  }
}
```

### 21.1. Основные HTTP-коды

| Код | Назначение |
|---|---|
| `400` | Некорректный запрос |
| `401` | Пользователь не авторизован |
| `403` | Нет доступа |
| `404` | Ресурс не найден |
| `409` | Конфликт состояния или недопустимый статусный переход |
| `422` | Ошибка бизнес-валидации |
| `429` | Rate limit |
| `500` | Внутренняя ошибка |
| `503` | Внешний сервис недоступен |

### 21.2. Принципы обработки ошибок

| ID | Правило |
|---|---|
| API-ERR-001 | Ошибка должна быть понятной клиенту, но не раскрывать чувствительные детали |
| API-ERR-002 | Ошибки доступа не должны раскрывать существование чужих сущностей без необходимости |
| API-ERR-003 | Для технических расследований используется `traceId` |
| API-ERR-004 | Недопустимый статусный переход должен быть согласован со Status Models |

---

## 22. Webhook-подход

Webhook используется для событий, где внешняя система является источником истины.

| Webhook | Источник | Назначение |
|---|---|---|
| RKL webhook | SHERPA RPA | Передача результатов РКЛ-проверки |
| Payment webhook | Payment provider / SBP | Подтверждение оплаты |
| Notification callback | Push/email provider | Доставка уведомлений, если поддерживается |

### 22.1. Общие правила webhook

| ID | Правило |
|---|---|
| API-WH-001 | Webhook должен иметь внешний `eventId` |
| API-WH-002 | Повторный webhook не должен повторно менять бизнес-сущность |
| API-WH-003 | Payload должен валидироваться |
| API-WH-004 | Ошибки webhook должны попадать в `IntegrationLog` |
| API-WH-005 | Для доверенных webhook должна использоваться подпись, API key или IP whitelist |
| API-WH-006 | Webhook должен возвращать успешный HTTP-ответ только после безопасной обработки или постановки события в очередь |

---

## 23. Идемпотентность

Идемпотентность нужна для операций, которые могут быть повторены:

- payment webhook;
- RKL webhook;
- повторная отправка уведомления;
- повторное создание платежа;
- retry интеграционного события.

Пример:

```http
Idempotency-Key: 2f8b8c6d-1111-4444-9999-abcdef123456
```

Правила:

| ID | Правило |
|---|---|
| API-IDEMP-001 | Повтор операции с тем же ключом не должен создавать дубль |
| API-IDEMP-002 | Для webhook используется внешний `eventId` |
| API-IDEMP-003 | Результат повторной операции должен быть предсказуемым |
| API-IDEMP-004 | Дубликаты должны попадать в `IntegrationLog` со статусом `duplicate` |

---

## 24. Связь API с моделью данных

| API-домен | Сущности |
|---|---|
| Auth API | `User`, `Role` |
| Users API | `User`, `Role`, `AuditLog` |
| Migrants API | `Migrant`, `RiskScore`, `Document`, `Request`, `RklCheck` |
| Employers API | `Employer`, `Migrant`, `Request`, `ServiceOrder` |
| Documents API | `Document`, `DocumentFile`, `AuditLog` |
| Requests API | `Request`, `Notification`, `AuditLog` |
| Marketplace API | `Service`, `ServiceOrder`, `Payment`, `Invoice` |
| Payments API | `Payment`, `Invoice`, `IntegrationLog`, `AuditLog` |
| RKL API | `RklCheck`, `RiskScore`, `IntegrationLog` |
| Notifications API | `Notification` |
| Chats API | `ChatThread`, `ChatMessage` |
| Analytics API | `Migrant`, `Document`, `RiskScore`, `ServiceOrder`, `IntegrationLog` |
| Admin API | `Role`, `User`, `AuditLog`, `IntegrationLog` |

---

## 25. Связь API со статусными моделями

API должен учитывать статусные модели сущностей и не позволять недопустимые переходы.

| Сущность | Где особенно важно в API |
|---|---|
| `User` | Блокировка, разблокировка, активация |
| `Migrant` | Активация, блокировка, архивирование |
| `Document` | `approve`, `reject`, повторная загрузка |
| `Request` | Изменение статуса и жизненный цикл обработки |
| `ServiceOrder` | Создание, ожидание оплаты, выполнение, отмена |
| `Payment` | Подтверждение webhook, ошибка оплаты, возврат |
| `Invoice` | Создание, оплата, отмена, истечение |
| `Notification` | Отправка, доставка, прочтение |
| `ChatThread` | Закрытие и архивирование |
| `IntegrationLog` | Обработка, duplicate, retry |

---

## 26. Связь API с процессами

| Процесс | API |
|---|---|
| Регистрация мигранта | Auth API, Migrants API |
| Загрузка документа | Documents API, Notifications API |
| РКЛ-проверка | RKL API, Analytics API, Admin API |
| Заказ услуги | Marketplace API, Payments API, Notifications API |
| Запрос мигранта к работодателю | Requests API, Notifications API, Chats API |

---

## 27. Связь API с permissions

API не должен полагаться только на роль. Для большинства endpoints требуется сочетание endpoint-level permission и контекстной проверки сущности.

Примеры:

| Endpoint | Permission | Контекст |
|---|---|---|
| `GET /migrants/{migrantId}` | `migrant.read` | `own`, `org`, `assigned`, `agency`, `technical` |
| `POST /documents/{documentId}/approve` | `document.approve` | `assigned`, `agency`, `technical` |
| `POST /requests` | `request.create` | `own` или `org` |
| `POST /service-orders` | `service_order.create` | `own` или `org` |
| `POST /payments/webhook` | `payment webhook trust policy` | `technical` |
| `GET /admin/audit-log` | `audit_log.read` | `agency` или `technical` |

---

## 28. Связанные артефакты

- [OpenAPI Specification](./openapi.yaml)
- [ERD](../04_data-model/erd.md)
- [Entities](../04_data-model/entities.md)
- [Data Dictionary](../04_data-model/data-dictionary.md)
- [Status Models](../04_data-model/status-models.md)
- [Role Model](../02_roles-and-access/role-model.md)
- [Access Matrix](../02_roles-and-access/access-matrix.md)
- [Permissions](../02_roles-and-access/permissions.md)
- [BPMN Document Upload](../03_processes/bpmn_document-upload.md)
- [BPMN RKL Check](../03_processes/bpmn_rkl-check.md)
- [BPMN Service Order](../03_processes/bpmn_service-order.md)
- [BPMN Employer Request](../03_processes/bpmn_employer-request.md)
