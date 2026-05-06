# WebSocket Contract

## Назначение

`Socket.IO` используется для real-time обмена сообщениями между посетителем сайта и оператором админки. История сообщений при этом сохраняется в PostgreSQL через `ChatSession` и `Message`.

## Архитектурный контекст

- клиент сайта и админка подключаются к отдельному `Socket.IO` процессу
- сообщения маршрутизируются по комнатам вида `chat:{sessionId}`
- каждое сообщение перед отправкой участникам сохраняется в БД

## Room naming

Для каждой чат-сессии используется отдельная комната:

`chat:{sessionId}`

Пример:

`chat:cmabc123xyz`

## Роли

Поддерживаются две runtime-роли подключения:

- `visitor`
- `operator`

Роль передаётся в `chat:join` и используется для presence и валидации отдельных действий.

## Client → Server

### `chat:join`

Назначение:

- подключить сокет к комнате чат-сессии
- зарегистрировать presence участника

Кто отправляет:

- `visitor`
- `operator`

Payload:

```json
{
  "sessionId": "cmabc123xyz",
  "role": "visitor"
}
```

или

```json
{
  "sessionId": "cmabc123xyz",
  "role": "operator"
}
```

Валидация:

- `sessionId` обязателен
- `role` должен быть `visitor` или `operator`
- `ChatSession` должна существовать

Ошибки:

- `Invalid chat session`
- `Chat session not found`

### `chat:message`

Назначение:

- отправить visitor-сообщение в operator mode

Кто отправляет:

- `visitor`

Payload:

```json
{
  "sessionId": "cmabc123xyz",
  "text": "Здравствуйте, подскажите стоимость"
}
```

Логика:

- проверка длины текста
- проверка существования `ChatSession`
- запрет отправки в `closed`
- сохранение `Message(sender="visitor")`
- отправка `message:new` в комнату

Ошибки:

- `Chat session is required`
- `Message text is required`
- `Message text is too long`
- `Chat session not found`
- `Чат закрыт`

### `operator:message`

Назначение:

- отправить операторское сообщение из админки

Кто отправляет:

- `operator`

Payload:

```json
{
  "sessionId": "cmabc123xyz",
  "text": "Здравствуйте, меня зовут Юрий. Чем могу помочь?"
}
```

Логика:

- проверка длины текста
- проверка существования `ChatSession`
- запрет отправки в `closed`
- сохранение `Message(sender="operator")`
- если статус `waiting_operator`, перевод в `operator_replied`
- в payload `message:new` добавляется `operatorName`

Ошибки:

- `Chat session is required`
- `Message text is required`
- `Message text is too long`
- `Chat session not found`
- `Чат закрыт`

### `chat:typing`

Назначение:

- показать, что другая сторона печатает сообщение

Кто отправляет:

- `visitor`
- `operator`

Payload:

```json
{
  "sessionId": "cmabc123xyz",
  "role": "visitor",
  "isTyping": true
}
```

или

```json
{
  "sessionId": "cmabc123xyz",
  "role": "operator",
  "isTyping": false
}
```

Валидация:

- `sessionId` обязателен
- `role` должен быть `visitor` или `operator`

Ошибки:

- `Invalid typing payload`

### `admin:chat_closed`

Назначение:

- уведомить всех участников комнаты о закрытии чата оператором

Кто отправляет:

- `operator`

Payload:

```json
{
  "sessionId": "cmabc123xyz"
}
```

Валидация:

- `sessionId` обязателен
- сокет должен быть присоединён как `operator`

Ошибки:

- `Chat session is required`
- `Only operator can close chat`

## Server → Client

### `message:new`

Назначение:

- доставить новое сообщение всем участникам чат-комнаты

Кто отправляет:

- `server`

Payload:

```json
{
  "id": "cmmsg123",
  "sessionId": "cmabc123xyz",
  "sender": "operator",
  "text": "Здравствуйте, меня зовут Юрий. Чем могу помочь?",
  "createdAt": "2026-05-06T12:00:00.000Z",
  "operatorName": "Юрий"
}
```

Особенности:

- `operatorName` присутствует для сообщений оператора
- сообщение уже сохранено в PostgreSQL к моменту отправки

### `typing:update`

Назначение:

- передать состояние набора сообщения другой стороне

Кто отправляет:

- `server`

Payload:

```json
{
  "role": "visitor",
  "isTyping": true
}
```

### `presence:update`

Назначение:

- показать online/offline состояние участников комнаты

Кто отправляет:

- `server`

Payload:

```json
{
  "visitorOnline": true,
  "operatorOnline": false
}
```

### `chat:closed`

Назначение:

- сообщить клиентам, что чат закрыт оператором

Кто отправляет:

- `server`

Payload:

```json
{
  "sessionId": "cmabc123xyz",
  "message": "Чат закрыт оператором"
}
```

### `chat:error`

Назначение:

- сообщить клиенту о валидационной или технической ошибке WebSocket-операции

Кто отправляет:

- `server`

Payload:

```json
{
  "message": "Chat session not found"
}
```

## Сохранение сообщений в PostgreSQL

- visitor-сообщения сохраняются как `Message(sender="visitor")`
- operator-сообщения сохраняются как `Message(sender="operator")`
- системные изменения фиксируются как `Message(sender="system")`

Таким образом WebSocket-слой отвечает за доставку, а PostgreSQL — за долговременное хранение истории.

## Ошибки и ограничения

- максимальная длина сообщения ограничена на сервере
- закрытый чат не принимает новые сообщения
- presence хранится in-memory и сбрасывается при рестарте socket-процесса
- Socket.IO не заменяет HTTP API, а дополняет его

## Fallback

Если WebSocket временно недоступен:

- сценарный чат продолжает работать через HTTP API
- история, уже сохранённая в БД, остаётся доступной
- админка и клиентский виджет могут отображать состояние деградации соединения

## Работа через Nginx proxy

Для production требуется проксирование `/socket.io/` на отдельный процесс.

Пример:

```nginx
location /socket.io/ {
    proxy_pass http://localhost:3001;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_cache_bypass $http_upgrade;
}
```

## Процессы на сервере

- `Next.js app` — сайт, админка, REST API
- `Socket.IO server` — real-time слой
- оба процесса управляются через `PM2`
