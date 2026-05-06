# Realtime chat UX

## Что добавлено в UX real-time чата

Для MVP поверх Socket.IO добавлены:

- typing indicator
- presence online/offline
- закрытие чата оператором
- назначение оператора
- более устойчивое создание новой `ChatSession` после `Начать сначала`
- быстрые кнопки сценария теперь существуют только как элементы текущего шага UI

## Typing indicator

Используются события:

- `chat:typing`
- `typing:update`

Логика:

- посетитель отправляет `chat:typing` во время ввода сообщения оператору
- оператор делает то же самое в админке
- противоположная сторона получает `typing:update`

В UI это отображается как:

- `Оператор печатает...`
- `Посетитель печатает...`

Для debounce используется обычный `setTimeout` / `useRef`, без дополнительных библиотек.

## Presence online/offline

Presence хранится только in-memory в `server/socket-server.js`.

Используется структура вида:

- `sessionId -> visitors Set(socketId)`
- `sessionId -> operators Set(socketId)`

Сервер отправляет:

`presence:update`

с payload:

```json
{
  "visitorOnline": true,
  "operatorOnline": false
}
```

Это позволяет показывать:

- в виджете:
  - `Оператор онлайн`
  - `Ожидаем оператора`
  - `Соединение...`
- в админке:
  - `Посетитель онлайн`
  - `Посетитель не в сети`

После рестарта socket server presence сбрасывается, и для MVP это нормально.

## Закрытие чата

Используется admin API:

`POST /api/admin/chats/[id]/close`

Route:

- проверяет `admin_session`
- обновляет `ChatSession.status = "closed"`
- ставит `closedAt`
- создаёт system message:
  `Чат закрыт оператором`

После этого admin client дополнительно отправляет socket event:

`admin:chat_closed`

Сервер рассылает:

`chat:closed`

Посетитель видит сообщение:

`Чат закрыт оператором. Если нужно, начните новый диалог.`

И поле ввода для этой сессии блокируется.
Новые сообщения в закрытую сессию больше не принимаются:

- `chat:message` на socket-server
- `operator:message` на socket-server
- публичный HTTP route `/api/chat/session/[id]/messages`
- admin HTTP route `/api/admin/chats/[id]/messages`

## Назначение оператора

В `ChatSession` есть поля:

- `assignedOperator String?`
- `assignedOperatorId String?`

Если оператор назначен через админку, имя берётся из `assignedOperatorUser.name` или `assignedOperator`.

Используется API:

`POST /api/admin/chats/[id]/assign`

Route:

- проверяет `admin_session`
- записывает `assignedOperator` и `assignedOperatorId`
- создаёт system message:
  `Оператор взял чат в работу`

В админке видно:

- назначенного оператора
- статус чата
- действия `Взять в работу` / `Закрыть чат`

## Статусы ChatSession

Сейчас используются:

- `active`
- `waiting_operator`
- `operator_replied`
- `lead_created`
- `closed`

Русские подписи:

- `active` — `Активен`
- `waiting_operator` — `Ожидает оператора`
- `operator_replied` — `Оператор ответил`
- `lead_created` — `Заявка создана`
- `closed` — `Закрыт`

## Quick replies

Быстрые кнопки сценария не входят в постоянную историю UI чата. Они рендерятся отдельно как `currentQuickReplies` / `currentOptions` для текущего шага и не должны оставаться в потоке сообщений после перехода дальше.

В постоянной истории UI остаются только сообщения:

- `bot`
- `visitor`
- `operator`
- `system`

После выбора quick reply кнопки текущего шага сразу исчезают и заменяются следующим состоянием сценария.

Quick replies показываются только на текущем активном шаге. В режимах:

- `waiting_operator`
- `operator_replied`
- `closed`

старые сценарные кнопки очищаются и больше не должны оставаться внизу чата.

В operator mode виджет показывает только:

- историю сообщений
- статус оператора / соединения
- textarea для сообщения оператору, если чат не `closed`
- кнопку `Начать новый диалог`

## Оформление сообщений

В клиентском виджете сообщения разделяются визуально:

- `visitor` — синие сообщения справа
- `bot` — светлые сообщения слева
- `system` — нейтральные приглушённые сообщения
- `operator` — отдельный светло-синий блок слева

Для сообщений оператора сверху показывается подпись:

- `Оператор Юрий`, если имя известно
- `Оператор`, если имя недоступно

Имя оператора берётся:

- из realtime payload `message:new`
- или из `assignedOperator` / `assignedOperatorUser.name` при восстановлении истории через `GET /api/chat/session/[id]`

После закрытия чата пользователь видит кнопку:

- `Начать новый диалог`

## Ограничения MVP

- presence не сохраняется в БД

## Что дальше

Следующий естественный этап:

- `User` / `roles`
- аудит действий операторов
- более точное распределение чатов
- online/offline по пользователям
- более формальный handoff workflow
