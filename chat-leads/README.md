# Chat Leads

Lead management система с сайтом, формой заявки, чат-ботом, real-time чатом с оператором, админкой, ролями, аудитом, Telegram-интеграцией и аналитикой.

## Роль

Системный аналитик + разработчик/интегратор.

## Контекст

Изначальная идея: сделать сайт с умным чатом, который помогает посетителю разобраться в услуге и довести его до заявки.

Задача была шире обычной формы: нужно было спроектировать систему, где заявка создаётся из формы или чата, сохраняется в базе, передаётся в уведомления, обрабатывается в админке и сопровождается историей событий.

## Вызов

Скоуп был хаотичным: лендинг, форма, чат-бот, real-time чат, CRM/Telegram-интеграции, аналитика, админка, роли и обработка заявок.

Нужно было выделить MVP, спроектировать модель данных, описать API/WebSocket-взаимодействие и реализовать production-прототип.

## Что реализовано

- публичный лендинг
- форма заявки
- серверная обработка `/api/lead`
- PostgreSQL + Prisma
- Telegram-уведомления
- IntegrationLog
- LeadEvent
- OperatorComment
- UTM tracking
- Яндекс Метрика и цели
- админка лидов
- карточка заявки
- смена статусов
- комментарии менеджера
- история событий
- фильтры заявок
- чат-виджет
- ChatSession и Message
- operator handoff
- real-time чат через Socket.IO
- User / роли admin, operator, viewer
- AuditLog
- User management UI
- production-деплой на VPS с HTTPS

## Архитектура

Для MVP выбран модульный монолит.

Основное приложение реализовано на Next.js. Внутри одной кодовой базы находятся публичный сайт, API, админка, чат, интеграции и аналитика.

Real-time часть вынесена в отдельный Socket.IO-процесс, который разворачивается рядом с Next.js-приложением и использует общую PostgreSQL-базу.

```txt
Пользователь
→ сайт / чат / форма
→ Next.js API
→ PostgreSQL
→ Telegram / CRM feature flag
→ админка

Оператор ↔ Socket.IO ↔ посетитель

```
Модель данных

Фактически реализованные сущности:

Lead
User
ChatSession
Message
LeadEvent
OperatorComment
IntegrationLog
AuditLog

Целевая модель развития:

LeadStatus
IntegrationJob
Visitor
LeadSource / UTM
AnalyticsEvent
Settings
API и WebSocket

REST API:

POST /api/lead
POST /api/chat/session
GET /api/chat/session/{id}
POST /api/chat/session/{id}/handoff
PATCH /api/admin/leads/{id}/status
POST /api/admin/leads/{id}/comments
POST /api/admin/chats/{id}/messages
POST /api/admin/chats/{id}/assign
POST /api/admin/chats/{id}/close
POST /api/admin/users
PATCH /api/admin/users/{id}

Socket.IO events:

chat:join
chat:message
operator:message
chat:typing
message:new
typing:update
presence:update
chat:closed
chat:error
Интеграции
Telegram

Заявка отправляется в Telegram после сохранения в PostgreSQL.
Результат отправки фиксируется в IntegrationLog.

CRM

Bitrix24-интеграция заложена через feature flag.
При наличии webhook заявка может быть передана в CRM, а результат будет зафиксирован в логах интеграций.

Аналитика

Сохраняются:

utm_source
utm_medium
utm_campaign
utm_content
utm_term
referrer
landingPage

Подключены цели Яндекс Метрики:

cta_click
lead_form_submit
lead_success
thanks_page_view
chat_open
chat_lead_submit
Админка

В админке реализовано:

список заявок
фильтры и поиск
карточка заявки
смена статуса
комментарии
история событий
логи интеграций
история чата
список чат-сессий
real-time панель оператора
управление пользователями
роли admin/operator/viewer
AuditLog
Безопасность и надёжность
HTTPS через Certbot
Nginx reverse proxy
PM2 для процессов Next.js и Socket.IO
PostgreSQL не открыт наружу
env-переменные не хранятся в Git
пароли пользователей хранятся в виде hash
роли ограничивают действия в админке
AuditLog фиксирует действия пользователей
IntegrationLog не хранит секреты
настроены firewall, fail2ban и бэкапы PostgreSQL
Документация

Для проекта подготовлена аналитическая документация:

architecture overview
ERD
OpenAPI
WebSocket contract
business process
functional requirements
non-functional requirements
test cases
user stories
backlog MoSCoW
edge cases
portfolio case
Результат

Получился production-прототип lead management системы: пользователь может оставить заявку через форму или чат, оператор может обработать обращение в админке, real-time чат сохраняет историю, а система фиксирует статусы, события, интеграции, UTM и действия пользователей.
