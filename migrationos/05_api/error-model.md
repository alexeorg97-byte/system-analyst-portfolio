# Error Model — MigrationOS

## 1. Назначение документа

Документ описывает единую модель ошибок API платформы MigrationOS.

Error Model нужен, чтобы:

- унифицировать формат ошибок для frontend, mobile и backend;
- сделать ошибки предсказуемыми для API-клиентов;
- отделить HTTP-код от бизнес-кода ошибки;
- обеспечить корректную обработку validation, access, status transition и integration errors;
- упростить тестирование API;
- обеспечить трассировку ошибок через `traceId`.

Документ связан с [API Overview](./api-overview.md), [OpenAPI Specification](./openapi.yaml), webhook-документами и статусными моделями доменных сущностей.

---

## 2. Общий формат ошибки

Все API должны возвращать ошибку в едином формате:

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

---

## 3. Поля ErrorResponse

| Поле | Тип | Обязательное | Описание |
|---|---|---:|---|
| `error.code` | string | Да | Машиночитаемый код ошибки |
| `error.message` | string | Да | Краткое человекочитаемое сообщение |
| `error.details` | array | Нет | Детали ошибки, чаще всего по полям |
| `error.details[].field` | string | Нет | Поле, к которому относится ошибка |
| `error.details[].message` | string | Нет | Описание ошибки по конкретному полю |
| `error.traceId` | string | Да | ID запроса для логов и расследования |

---

## 4. Принципы модели ошибок

| ID | Принцип |
|---|---|
| `ERR-GEN-001` | API всегда возвращает ошибку в формате `ErrorResponse` |
| `ERR-GEN-002` | HTTP-код отражает технический класс ошибки |
| `ERR-GEN-003` | `error.code` отражает бизнес- или системную причину |
| `ERR-GEN-004` | `message` должен быть понятным, но не раскрывать чувствительные детали |
| `ERR-GEN-005` | Для расследования используется `traceId` |
| `ERR-GEN-006` | Ошибки доступа не должны раскрывать чужие данные |
| `ERR-GEN-007` | Ошибки webhook должны фиксироваться в `IntegrationLog` |
| `ERR-GEN-008` | Ошибки критичных операций могут дополнительно попадать в `AuditLog` |

---

## 5. HTTP-коды

| HTTP-код | Назначение | Пример |
|---|---|---|
| `400 Bad Request` | Некорректный формат запроса | Невалидный JSON |
| `401 Unauthorized` | Нет или некорректна авторизация | Нет token, невалидный API key |
| `403 Forbidden` | Пользователь авторизован, но доступа нет | Чужой мигрант, чужой запрос |
| `404 Not Found` | Ресурс не найден | Несуществующий `requestId` |
| `409 Conflict` | Конфликт состояния | Недопустимый статусный переход |
| `422 Unprocessable Entity` | Бизнес-валидация не пройдена | Не заполнен `reason`, неверная сумма |
| `429 Too Many Requests` | Слишком много запросов | Rate limit |
| `500 Internal Server Error` | Внутренняя ошибка | Необработанное исключение |
| `503 Service Unavailable` | Внешний или внутренний сервис недоступен | `Notification Service` недоступен |

---

## 6. Базовые коды ошибок

| Код ошибки | HTTP | Описание |
|---|---:|---|
| `BAD_REQUEST` | `400` | Некорректный формат запроса |
| `VALIDATION_ERROR` | `422` | Ошибка валидации данных |
| `UNAUTHORIZED` | `401` | Пользователь не авторизован |
| `FORBIDDEN` | `403` | Доступ запрещен |
| `NOT_FOUND` | `404` | Ресурс не найден |
| `CONFLICT` | `409` | Конфликт состояния |
| `RATE_LIMIT_EXCEEDED` | `429` | Превышен лимит запросов |
| `INTERNAL_ERROR` | `500` | Внутренняя ошибка |
| `SERVICE_UNAVAILABLE` | `503` | Сервис временно недоступен |

---

## 7. Validation errors

Validation errors используются, когда payload синтаксически корректный, но не проходит бизнес-валидацию.

Пример:

```http
422 Unprocessable Entity
```

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Request validation failed",
    "details": [
      {
        "field": "requestType",
        "message": "requestType is required"
      },
      {
        "field": "migrantId",
        "message": "migrantId is not available in current context"
      }
    ],
    "traceId": "req-332"
  }
}
```

Типовые случаи:

| Ситуация | Код |
|---|---|
| Обязательное поле не заполнено | `VALIDATION_ERROR` |
| Неверный enum | `VALIDATION_ERROR` |
| Неверный формат даты | `VALIDATION_ERROR` |
| Неверный UUID | `VALIDATION_ERROR` |
| Некорректная сумма платежа | `VALIDATION_ERROR` |
| Не передана причина отклонения | `VALIDATION_ERROR` |

---

## 8. Access errors

Access errors возникают при нарушении авторизации, permissions или context access.

### 8.1. Не авторизован

```http
401 Unauthorized
```

```json
{
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Authentication is required",
    "traceId": "req-401"
  }
}
```

### 8.2. Нет доступа

```http
403 Forbidden
```

```json
{
  "error": {
    "code": "FORBIDDEN",
    "message": "User has no access to this resource",
    "traceId": "req-403"
  }
}
```

Правила:

| ID | Правило |
|---|---|
| `ERR-ACCESS-001` | Отсутствие token возвращает `401` |
| `ERR-ACCESS-002` | Недостаточно permissions возвращает `403` |
| `ERR-ACCESS-003` | Нарушение контекста доступа возвращает `403` или безопасный `404` |
| `ERR-ACCESS-004` | API не должен раскрывать существование чужих сущностей без необходимости |
| `ERR-ACCESS-005` | Попытки доступа к чувствительным данным могут логироваться |

---

## 9. Status transition errors

Status transition errors возникают, когда пользователь или сервис пытается выполнить недопустимый переход статуса.

Пример:

```http
409 Conflict
```

```json
{
  "error": {
    "code": "STATUS_TRANSITION_NOT_ALLOWED",
    "message": "Transition from completed to in_progress is not allowed",
    "traceId": "req-409"
  }
}
```

Типовые случаи:

| Сущность | Пример |
|---|---|
| `Request` | `completed -> in_progress` |
| `Document` | `draft -> approved` |
| `ServiceOrder` | `waiting_payment -> in_progress` без оплаты |
| `Payment` | `paid -> pending` |
| `User` | `archived -> active` |

Правила:

| ID | Правило |
|---|---|
| `ERR-STATE-001` | Недопустимый переход возвращает `409 Conflict` |
| `ERR-STATE-002` | Ошибка должна ссылаться на текущий и целевой статус |
| `ERR-STATE-003` | Критичные попытки смены статуса должны логироваться |
| `ERR-STATE-004` | Frontend не должен самостоятельно определять допустимость перехода как источник истины |

---

## 10. Webhook and integration errors

Ошибки интеграций возникают при обработке событий от внешних систем.

### 10.1. Недоверенный источник

```http
401 Unauthorized
```

```json
{
  "error": {
    "code": "UNAUTHORIZED_INTEGRATION",
    "message": "Invalid integration credentials",
    "traceId": "req-501"
  }
}
```

### 10.2. Дубликат события

Для webhook-дубликатов допустим безопасный успешный ответ:

```http
202 Accepted
```

```json
{
  "accepted": true,
  "status": "duplicate",
  "eventId": "pay_evt_2026_000001"
}
```

### 10.3. Ошибка сопоставления

```http
202 Accepted
```

```json
{
  "accepted": true,
  "status": "unmatched",
  "eventId": "rkl_evt_2026_000001"
}
```

Коды integration errors:

| Код ошибки | HTTP | Описание |
|---|---:|---|
| `UNAUTHORIZED_INTEGRATION` | `401` | Недоверенный источник |
| `INVALID_SIGNATURE` | `401` | Некорректная подпись |
| `INVALID_SOURCE` | `422` | Некорректный источник события |
| `DUPLICATE_EVENT` | `202 / 409` | Дубликат webhook-события |
| `PAYMENT_NOT_FOUND` | `202 / 422` | Платеж не сопоставлен |
| `AMOUNT_MISMATCH` | `422` | Сумма webhook не совпадает |
| `INTEGRATION_EVENT_UNMATCHED` | `202` | Событие принято, но не сопоставлено |
| `INTEGRATION_PROCESSING_FAILED` | `500` | Ошибка обработки интеграционного события |

---

## 11. Payment errors

| Код ошибки | HTTP | Описание |
|---|---:|---|
| `PAYMENT_NOT_FOUND` | `404 / 422` | Платеж не найден |
| `AMOUNT_MISMATCH` | `422` | Сумма не совпадает с ожидаемой |
| `CURRENCY_MISMATCH` | `422` | Валюта не совпадает |
| `PAYMENT_ALREADY_PAID` | `409` | Платеж уже подтвержден |
| `PAYMENT_STATUS_NOT_ALLOWED` | `409` | Недопустимый статусный переход платежа |
| `PAYMENT_PROVIDER_UNAVAILABLE` | `503` | Провайдер недоступен |

---

## 12. RKL errors

| Код ошибки | HTTP | Описание |
|---|---:|---|
| `RKL_SOURCE_INVALID` | `422` | Источник не равен `SHERPA_RPA` |
| `RKL_EVENT_DUPLICATE` | `202 / 409` | Повторное событие |
| `RKL_MIGRANT_UNMATCHED` | `202` | Мигрант не сопоставлен |
| `RKL_PAYLOAD_INVALID` | `422` | Payload РКЛ некорректен |
| `RKL_PROCESSING_FAILED` | `500` | Ошибка обработки РКЛ-события |

---

## 13. Request Service errors

| Код ошибки | HTTP | Описание |
|---|---:|---|
| `REQUEST_NOT_FOUND` | `404` | Запрос не найден |
| `REQUEST_ACCESS_DENIED` | `403` | Нет доступа к запросу |
| `REQUEST_CONTEXT_INVALID` | `422` | Некорректный бизнес-контекст |
| `REQUEST_INTERNAL_COMMENT_FORBIDDEN` | `403` | Внешняя роль пытается передать внутренний комментарий |
| `REQUEST_ASSIGNEE_INVALID` | `422` | Ответственный не найден или недопустим |
| `STATUS_TRANSITION_NOT_ALLOWED` | `409` | Недопустимый переход статуса |

---

## 14. Error details

`details` используется для ошибок, где нужно вернуть список проблем.

Пример:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Validation failed",
    "details": [
      {
        "field": "expirationDate",
        "message": "expirationDate must be greater than issueDate"
      },
      {
        "field": "documentType",
        "message": "documentType is required"
      }
    ],
    "traceId": "req-601"
  }
}
```

Правила:

| ID | Правило |
|---|---|
| `ERR-DETAILS-001` | `details` используется для field-level ошибок |
| `ERR-DETAILS-002` | Если ошибка не связана с конкретным полем, `details` можно не передавать |
| `ERR-DETAILS-003` | `details.message` не должен раскрывать чувствительные данные |
| `ERR-DETAILS-004` | Несколько ошибок можно вернуть одним ответом, если это не снижает безопасность |

---

## 15. TraceId

`traceId` нужен для связи ответа API с backend-логами.

Правила:

| ID | Правило |
|---|---|
| `ERR-TRACE-001` | Каждый error response должен содержать `traceId` |
| `ERR-TRACE-002` | `traceId` должен логироваться на backend |
| `ERR-TRACE-003` | `traceId` не должен содержать ПДн |
| `ERR-TRACE-004` | Support может использовать `traceId` для расследования инцидентов |
| `ERR-TRACE-005` | `traceId` должен прокидываться через API Gateway и микросервисы |

---

## 16. Security-принципы

| ID | Принцип |
|---|---|
| `ERR-SEC-001` | Ошибка не должна раскрывать чужие ПДн |
| `ERR-SEC-002` | Ошибка доступа может возвращать безопасный `404`, если нужно скрыть факт существования ресурса |
| `ERR-SEC-003` | Ошибки интеграционной авторизации не должны раскрывать, какая часть trust policy не прошла |
| `ERR-SEC-004` | Технические stack traces не возвращаются клиенту |
| `ERR-SEC-005` | Подробные внутренние причины сохраняются в логах, а не в response |

---

## 17. Правила для frontend

| ID | Правило |
|---|---|
| `ERR-FE-001` | Frontend должен ориентироваться на `error.code`, а не только на HTTP-код |
| `ERR-FE-002` | Field-level ошибки из `details` можно показывать рядом с полями формы |
| `ERR-FE-003` | Ошибки `401` должны инициировать logout или refresh-flow |
| `ERR-FE-004` | Ошибки `403` не должны автоматически повторяться бесконечно |
| `ERR-FE-005` | Ошибки `409` должны показывать пользователю конфликт состояния |
| `ERR-FE-006` | Ошибки `500/503` должны показывать безопасное сообщение и возможность повторить позже |

---

## 18. Правила для backend

| ID | Правило |
|---|---|
| `ERR-BE-001` | Backend должен возвращать единый `ErrorResponse` |
| `ERR-BE-002` | Backend должен маппить доменные исключения в согласованные `error.code` |
| `ERR-BE-003` | Backend не должен возвращать stack trace клиенту |
| `ERR-BE-004` | Backend должен логировать `traceId`, `service name`, `endpoint`, `user context` |
| `ERR-BE-005` | Backend должен фиксировать integration errors в `IntegrationLog` |
| `ERR-BE-006` | Backend должен фиксировать критичные user actions в `AuditLog` |

---

## 19. QA checklist

| ID | Проверка |
|---|---|
| `QA-ERR-001` | Все ошибки возвращаются в формате `ErrorResponse` |
| `QA-ERR-002` | `traceId` есть в каждой ошибке |
| `QA-ERR-003` | `401` возвращается без авторизации |
| `QA-ERR-004` | `403` возвращается при нарушении permissions |
| `QA-ERR-005` | `409` возвращается при недопустимом статусном переходе |
| `QA-ERR-006` | `422` возвращается при ошибке бизнес-валидации |
| `QA-ERR-007` | Ошибка не содержит stack trace |
| `QA-ERR-008` | Ошибка не раскрывает чужие ПДн |
| `QA-ERR-009` | Webhook duplicate обрабатывается идемпотентно |
| `QA-ERR-010` | Ошибки интеграций попадают в `IntegrationLog` |

---

## 20. Связанные артефакты

- [API Overview](./api-overview.md)
- [OpenAPI Specification](./openapi.yaml)
- [RKL Webhook API](./rkl-webhook.md)
- [Payment Webhook API](./payment-webhook.md)
- [Request Service API](./request-service-api.md)
- [Status Models](../04_data-model/status-models.md)
- [Permissions](../02_roles-and-access/permissions.md)
- [Data Dictionary](../04_data-model/data-dictionary.md)
