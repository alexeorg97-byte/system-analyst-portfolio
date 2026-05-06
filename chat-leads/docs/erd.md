# ERD

## Назначение

Документ фиксирует:

- физическую модель данных, реализованную в текущем MVP
- целевую модель развития, которая была заложена концептуально

Важно: не все сущности из целевой модели реализованы физически в PostgreSQL на текущем этапе.

## Физическая модель данных

```mermaid
erDiagram
    Lead ||--o{ OperatorComment : has
    Lead ||--o{ LeadEvent : has
    Lead ||--o{ IntegrationLog : has
    Lead ||--o{ ChatSession : may_have
    ChatSession ||--o{ Message : contains
    User ||--o{ AuditLog : creates
    User ||--o{ ChatSession : assigned_to

    Lead {
        string id PK
        string name
        string contact
        string need
        string comment
        string source
        string status
        boolean telegramSent
        string telegramError
        boolean crmSent
        string crmError
        string bitrixLeadId
        string utmSource
        string utmMedium
        string utmCampaign
        string utmContent
        string utmTerm
        string referrer
        string landingPage
        datetime createdAt
        datetime updatedAt
    }

    User {
        string id PK
        string email UK
        string name
        string passwordHash
        string role
        boolean isActive
        datetime lastLoginAt
        datetime createdAt
        datetime updatedAt
    }

    ChatSession {
        string id PK
        string leadId FK
        string visitorId
        string source
        string status
        string assignedOperator
        string assignedOperatorId FK
        string selectedOption
        string summary
        datetime closedAt
        datetime createdAt
        datetime updatedAt
    }

    Message {
        string id PK
        string chatSessionId FK
        string sender
        string text
        datetime createdAt
    }

    LeadEvent {
        string id PK
        string leadId FK
        string type
        string title
        string description
        json metadata
        datetime createdAt
    }

    OperatorComment {
        string id PK
        string leadId FK
        string text
        string author
        datetime createdAt
    }

    IntegrationLog {
        string id PK
        string leadId FK
        string service
        string status
        json requestPayload
        json responsePayload
        string errorMessage
        datetime createdAt
    }

    AuditLog {
        string id PK
        string userId FK
        string action
        string entityType
        string entityId
        json oldValue
        json newValue
        string ip
        string userAgent
        datetime createdAt
    }
```

## Описание ключевых связей

- `Lead -> OperatorComment` — один лид может содержать несколько внутренних комментариев менеджера.
- `Lead -> LeadEvent` — один лид может иметь историю событий жизненного цикла.
- `Lead -> IntegrationLog` — один лид может иметь несколько записей по внешним интеграциям.
- `Lead -> ChatSession` — лид может быть создан из одной или нескольких связанных чат-сессий.
- `ChatSession -> Message` — одна чат-сессия содержит множество сообщений.
- `User -> AuditLog` — один пользователь может инициировать множество аудируемых действий.
- `User -> ChatSession.assignedOperatorId` — оператор может быть назначен на множество чат-сессий.

## Целевая модель развития

Следующие сущности были спроектированы концептуально, но в текущем MVP не реализованы физически как отдельные таблицы:

- `LeadStatus`
- `IntegrationJob`
- `Visitor`
- `LeadSource/UTM`
- `AnalyticsEvent`
- `Settings`

```mermaid
flowchart LR
    Lead --> LeadStatus
    Lead --> LeadSourceUTM
    Lead --> IntegrationJob
    Visitor --> ChatSession
    AnalyticsEvent --> Lead
    AnalyticsEvent --> ChatSession
    Settings --> IntegrationJob
    Settings --> AnalyticsEvent
```

## Назначение целевых сущностей

### LeadStatus

Справочник статусов лида с возможностью:

- управлять статусами без правки кода
- хранить порядок, SLA и правила переходов

### IntegrationJob

Очередь задач интеграций для:

- retry
- фоновой отправки
- контроля числа попыток и причин ошибки

### Visitor

Отдельная сущность посетителя нужна для:

- повторных визитов
- склейки chat sessions
- накопления поведенческого контекста

### LeadSource / UTM

Нормализованная маркетинговая модель нужна для:

- чистой аналитики
- единых источников / кампаний
- построения отчётности без денормализации по полям `Lead`

### AnalyticsEvent

Внутренние события нужны для:

- продуктовой аналитики
- расчёта воронок
- анализа UX чата и конверсии

### Settings

Централизованные настройки нужны для:

- токглов функционала
- правил handoff
- параметров интеграций
- текстов и сценариев
