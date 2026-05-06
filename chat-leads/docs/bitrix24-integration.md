# Bitrix24 Integration

## Зачем нужна CRM-интеграция

Интеграция с Bitrix24 нужна, чтобы заявки с сайта автоматически попадали в CRM и не терялись между маркетингом и продажами. Это позволяет быстрее обрабатывать лиды и дальше строить воронку внутри CRM.

## Какие env-переменные используются

- `BITRIX24_ENABLED`
- `BITRIX24_WEBHOOK_URL`

## Почему webhook хранится только на backend

Webhook содержит чувствительные данные доступа к Bitrix24, поэтому он должен использоваться только на сервере. Его нельзя передавать в клиентский код и нельзя сохранять в публичных логах или UI.

## Какой REST-метод используется

Для создания лида используется метод:

- `crm.lead.add`

Endpoint собирается из базового incoming webhook URL и вызывается как:

- `.../crm.lead.add.json`

## Маппинг полей Lead → Bitrix24

- `Lead.need` → `TITLE`
- `Lead.name` → `NAME`
- `Lead.contact` → `PHONE`, если это телефон
- `Lead.contact` → `COMMENTS`, если это Telegram
- `Lead.comment`, `source`, UTM, `landingPage`, `referrer` → `COMMENTS`
- `SOURCE_ID` → `WEB`

## Как логируется success/failed через IntegrationLog

Каждая попытка отправки в Bitrix24 пишет `IntegrationLog`:

- `service: "bitrix24"`
- `status: "success"` или `status: "failed"`
- безопасный `requestPayload` без webhook URL и токенов
- `responsePayload`, если он доступен
- `errorMessage`, если произошла ошибка

## Какие события создаются в LeadEvent

При успешной отправке создаётся событие:

- `crm_sent`

При ошибке создаётся событие:

- `crm_failed`

## Как обрабатывается ошибка CRM

Если CRM-интеграция падает, заявка всё равно остаётся сохранённой в базе. Если Telegram уже отправлен успешно, пользователь не получает ошибку формы, а проблема CRM фиксируется во внутренних полях `crmSent`, `crmError`, в `IntegrationLog` и в `LeadEvent`.

## Что можно добавить позже

Позже можно добавить:

- `crm.item.add`
- сделки вместо лидов
- ответственного менеджера
- кастомные поля UTM
- повторную отправку через `IntegrationJob` / retry
