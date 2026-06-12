# Permissions — MigrationOS

## 1. Назначение документа

Документ описывает набор permissions для платформы MigrationOS.

Permissions — это детальные права, которые определяют, какие действия пользователь может выполнять с конкретными ресурсами системы.

Документ нужен, чтобы:

- связать ролевую модель с backend authorization;
- детализировать матрицу доступа;
- определить permission-коды для API и UI;
- показать, какие действия должны логироваться;
- подготовить тестирование прав доступа;
- снизить риск неявных или противоречивых правил доступа.

Документ является продолжением:

- [Role Model](./role-model.md)
- [Access Matrix](./access-matrix.md)

---

## 2. Принципы permissions

- Permission описывает конкретное действие над конкретным ресурсом.
- Роль получает набор permissions.
- Permission не всегда дает доступ ко всем данным ресурса: дополнительно проверяется контекст.
- Контекст доступа определяется правилами `own`, `org`, `assigned`, `agency`, `technical`.
- Backend должен проверять permission и контекст сущности.
- Frontend может использовать permissions для скрытия разделов и кнопок.
- UI-ограничения не заменяют backend-проверку.
- Критичные действия должны попадать в audit log.
- Попытка выполнить действие без permission должна возвращать `403 Forbidden`.

---

## 3. Формат permission-кода

Permission-код имеет формат:

```text
resource.action
```

Примеры:

- `document.read`
- `document.upload`
- `document.approve`
- `request.create`
- `request.update_status`
- `payment.read`
- `role.manage`
- `audit_log.read`

| Часть | Значение |
|---|---|
| `resource` | Сущность или модуль системы |
| `action` | Разрешенное действие |

---

## 4. Контексты доступа

| Контекст | Описание | Пример |
|---|---|---|
| `own` | Пользователь работает только со своими данными | Мигрант видит только свои документы |
| `org` | Пользователь работает с данными своей организации | Работодатель видит только своих мигрантов |
| `assigned` | Пользователь работает с назначенными или доступными по правилам агентства сущностями | Менеджер видит назначенные заявки |
| `agency` | Пользователь работает с данными всего агентства | Руководитель видит все критичные риски |
| `technical` | Технический доступ для администрирования или расследования | Superadmin смотрит integration log |

---

## 5. Permissions по ресурсам

### 5.1. Auth / Session

| Permission | Описание | Критичность | Audit log |
|---|---|---|---|
| `auth.login` | Вход в систему | High | Да, при ошибках и успешном входе внутренних ролей |
| `auth.logout` | Выход из системы | Low | Нет |
| `auth.otp_request` | Запрос OTP-кода | Medium | Да, при превышении лимитов |
| `auth.otp_confirm` | Подтверждение OTP-кода | High | Да, при ошибках |
| `auth.2fa_confirm` | Подтверждение второго фактора | High | Да |
| `auth.refresh_token` | Обновление сессии | Medium | Нет |

### 5.2. User

| Permission | Описание | Критичность | Audit log |
|---|---|---|---|
| `user.read` | Просмотр пользователя | Medium | Нет |
| `user.create` | Создание пользователя | High | Да |
| `user.update` | Изменение пользователя | High | Да |
| `user.block` | Блокировка пользователя | High | Да |
| `user.unblock` | Разблокировка пользователя | High | Да |
| `user.delete` | Удаление или архивирование пользователя | Critical | Да |
| `user.change_role` | Изменение роли пользователя | Critical | Да |
| `user.reset_2fa` | Сброс 2FA | Critical | Да |

### 5.3. Migrant

| Permission | Описание | Критичность | Audit log |
|---|---|---|---|
| `migrant.read` | Просмотр карточки мигранта | High | Да, для внутренних ролей |
| `migrant.create` | Создание карточки мигранта | High | Да |
| `migrant.update` | Изменение карточки мигранта | High | Да |
| `migrant.archive` | Архивирование карточки мигранта | Critical | Да |
| `migrant.search` | Поиск мигрантов | Medium | Нет |
| `migrant.filter` | Фильтрация списка мигрантов | Low | Нет |
| `migrant.assign_manager` | Назначение менеджера | High | Да |
| `migrant.assign_project` | Назначение проекта | High | Да |

### 5.4. Document

| Permission | Описание | Критичность | Audit log |
|---|---|---|---|
| `document.read` | Просмотр документа | High | Да, для внутренних ролей |
| `document.upload` | Загрузка документа | High | Да |
| `document.update` | Изменение метаданных документа | High | Да |
| `document.approve` | Подтверждение документа | High | Да |
| `document.reject` | Отклонение документа | High | Да |
| `document.change_status` | Смена статуса документа | High | Да |
| `document.download_file` | Скачивание файла документа | Critical | Да |
| `document.delete_file` | Удаление или архивирование файла | Critical | Да |
| `document.view_history` | Просмотр истории документа | Medium | Нет / Да для внутренних расследований |

### 5.5. Request

| Permission | Описание | Критичность | Audit log |
|---|---|---|---|
| `request.read` | Просмотр запроса | Medium | Нет |
| `request.create` | Создание запроса | Medium | Да |
| `request.update` | Изменение запроса | Medium | Да |
| `request.update_status` | Смена статуса запроса | High | Да |
| `request.comment` | Добавление комментария | Medium | Да |
| `request.assign` | Назначение ответственного | High | Да |
| `request.view_history` | Просмотр истории запроса | Medium | Нет |

### 5.6. Service / Marketplace

| Permission | Описание | Критичность | Audit log |
|---|---|---|---|
| `service.read` | Просмотр каталога услуг | Low | Нет |
| `service.create` | Создание услуги | High | Да |
| `service.update` | Изменение услуги | High | Да |
| `service.archive` | Архивирование услуги | High | Да |
| `service_order.read` | Просмотр заявки на услугу | Medium | Нет |
| `service_order.create` | Создание заявки на услугу | Medium | Да |
| `service_order.update` | Изменение заявки на услугу | Medium | Да |
| `service_order.update_status` | Смена статуса заявки | High | Да |
| `service_order.assign` | Назначение ответственного | High | Да |
| `service_order.attach_document` | Прикрепление документа к заявке | High | Да |

### 5.7. Payment / Invoice

| Permission | Описание | Критичность | Audit log |
|---|---|---|---|
| `payment.read` | Просмотр платежа | High | Да, для внутренних ролей |
| `payment.create` | Создание платежа | High | Да |
| `payment.update_status` | Смена статуса платежа | Critical | Да |
| `payment.refund` | Возврат платежа | Critical | Да |
| `payment.view_history` | Просмотр истории платежа | High | Нет / Да по политике |
| `invoice.read` | Просмотр счета | Medium | Нет |
| `invoice.create` | Формирование счета | High | Да |
| `invoice.download` | Скачивание счета | Medium | Нет |
| `invoice.send_email` | Отправка счета на email | Medium | Да |

### 5.8. RKL / Risk

| Permission | Описание | Критичность | Audit log |
|---|---|---|---|
| `rkl_check.read` | Просмотр результата РКЛ-проверки | High | Да, для внутренних ролей |
| `rkl_check.receive_webhook` | Прием результата РКЛ от SHERPA RPA | Critical | Да / integration log |
| `rkl_check.view_history` | Просмотр истории РКЛ-проверок | High | Нет |
| `risk_score.read` | Просмотр риск-статуса | Medium | Нет |
| `risk_score.recalculate` | Пересчет риск-статуса | High | Да |
| `risk_score.override` | Ручная корректировка риска | Critical | Да |

### 5.9. Notification

| Permission | Описание | Критичность | Audit log |
|---|---|---|---|
| `notification.read` | Просмотр уведомлений | Low | Нет |
| `notification.create` | Создание уведомления | Medium | Да, если критичное |
| `notification.send` | Отправка уведомления | Medium | Да / delivery log |
| `notification.mark_read` | Отметить уведомление прочитанным | Low | Нет |
| `notification.manage_template` | Управление шаблонами уведомлений | High | Да |

### 5.10. Chat

| Permission | Описание | Критичность | Audit log |
|---|---|---|---|
| `chat.read` | Просмотр чата | Medium | Нет |
| `chat.create` | Создание чата | Medium | Да |
| `chat.send_message` | Отправка сообщения | Medium | Да |
| `chat.attach_file` | Прикрепление файла к сообщению | High | Да |
| `chat.view_internal_notes` | Просмотр внутренних заметок | High | Да |
| `chat.moderate` | Модерация или техническое управление чатом | High | Да |

### 5.11. Audit log / Integration log

| Permission | Описание | Критичность | Audit log |
|---|---|---|---|
| `audit_log.read` | Просмотр audit log | Critical | Да |
| `audit_log.export` | Выгрузка audit log | Critical | Да |
| `integration_log.read` | Просмотр integration log | High | Да |
| `integration_log.retry_event` | Повторная обработка интеграционного события | Critical | Да |
| `integration_log.export` | Выгрузка integration log | Critical | Да |

### 5.12. Roles / Settings / Dictionaries

| Permission | Описание | Критичность | Audit log |
|---|---|---|---|
| `role.read` | Просмотр ролей | High | Да |
| `role.manage` | Управление ролями | Critical | Да |
| `permission.read` | Просмотр permissions | High | Да |
| `permission.manage` | Управление permissions | Critical | Да |
| `settings.read` | Просмотр системных настроек | High | Да |
| `settings.update` | Изменение системных настроек | Critical | Да |
| `dictionary.read` | Просмотр справочников | Low | Нет |
| `dictionary.update` | Изменение справочников | High | Да |

---

## 6. Permissions по ролям

### 6.1. `migrant`

| Permission | Контекст |
|---|---|
| `auth.login` | `own` |
| `auth.logout` | `own` |
| `auth.otp_request` | `own` |
| `auth.otp_confirm` | `own` |
| `user.read` | `own` |
| `user.update` | `own limited` |
| `migrant.read` | `own` |
| `document.read` | `own` |
| `document.upload` | `own` |
| `document.download_file` | `own` |
| `document.view_history` | `own` |
| `request.read` | `own` |
| `request.create` | `own` |
| `service.read` | `own` |
| `service_order.read` | `own` |
| `service_order.create` | `own` |
| `service_order.attach_document` | `own` |
| `payment.read` | `own limited` |
| `invoice.read` | `own limited` |
| `notification.read` | `own` |
| `notification.mark_read` | `own` |
| `chat.read` | `own` |
| `chat.create` | `own` |
| `chat.send_message` | `own` |
| `chat.attach_file` | `own` |

### 6.2. `employer`

| Permission | Контекст |
|---|---|
| `auth.login` | `own` |
| `auth.logout` | `own` |
| `user.read` | `own/org limited` |
| `user.update` | `own/org limited` |
| `migrant.read` | `org` |
| `migrant.search` | `org` |
| `migrant.filter` | `org` |
| `document.read` | `org limited` |
| `document.download_file` | `org limited` |
| `request.read` | `org` |
| `request.create` | `org` |
| `request.update_status` | `org limited` |
| `service.read` | `org` |
| `service_order.read` | `org` |
| `service_order.create` | `org` |
| `service_order.attach_document` | `org limited` |
| `payment.read` | `org` |
| `payment.create` | `org` |
| `invoice.read` | `org` |
| `invoice.download` | `org` |
| `invoice.send_email` | `org` |
| `rkl_check.read` | `org limited` |
| `risk_score.read` | `org` |
| `notification.read` | `own/org` |
| `notification.mark_read` | `own/org` |
| `chat.read` | `org` |
| `chat.create` | `org` |
| `chat.send_message` | `org` |
| `chat.attach_file` | `org` |

### 6.3. `manager`

| Permission | Контекст |
|---|---|
| `auth.login` | `own` |
| `auth.logout` | `own` |
| `auth.2fa_confirm` | `own` |
| `user.read` | `own` |
| `migrant.read` | `assigned` |
| `migrant.create` | `assigned` |
| `migrant.update` | `assigned` |
| `migrant.search` | `assigned` |
| `migrant.filter` | `assigned` |
| `migrant.assign_manager` | `assigned limited` |
| `migrant.assign_project` | `assigned limited` |
| `document.read` | `assigned` |
| `document.upload` | `assigned` |
| `document.update` | `assigned` |
| `document.approve` | `assigned` |
| `document.reject` | `assigned` |
| `document.change_status` | `assigned` |
| `document.download_file` | `assigned` |
| `document.view_history` | `assigned` |
| `request.read` | `assigned` |
| `request.create` | `assigned` |
| `request.update` | `assigned` |
| `request.update_status` | `assigned` |
| `request.comment` | `assigned` |
| `request.assign` | `assigned limited` |
| `request.view_history` | `assigned` |
| `service.read` | `assigned` |
| `service_order.read` | `assigned` |
| `service_order.update` | `assigned` |
| `service_order.update_status` | `assigned` |
| `service_order.assign` | `assigned limited` |
| `service_order.attach_document` | `assigned` |
| `payment.read` | `assigned` |
| `invoice.read` | `assigned` |
| `invoice.create` | `assigned` |
| `invoice.download` | `assigned` |
| `invoice.send_email` | `assigned` |
| `rkl_check.read` | `assigned` |
| `rkl_check.view_history` | `assigned` |
| `risk_score.read` | `assigned` |
| `risk_score.recalculate` | `assigned` |
| `notification.read` | `assigned` |
| `notification.create` | `assigned` |
| `notification.send` | `assigned` |
| `chat.read` | `assigned` |
| `chat.create` | `assigned` |
| `chat.send_message` | `assigned` |
| `chat.attach_file` | `assigned` |
| `audit_log.read` | `assigned limited` |
| `integration_log.read` | `assigned limited` |
| `dictionary.read` | `assigned` |

### 6.4. `supervisor`

| Permission | Контекст |
|---|---|
| `auth.login` | `own` |
| `auth.logout` | `own` |
| `auth.2fa_confirm` | `own` |
| `user.read` | `agency` |
| `migrant.read` | `agency` |
| `migrant.update` | `agency limited` |
| `migrant.search` | `agency` |
| `migrant.filter` | `agency` |
| `migrant.assign_manager` | `agency` |
| `migrant.assign_project` | `agency` |
| `document.read` | `agency` |
| `document.approve` | `agency limited` |
| `document.reject` | `agency limited` |
| `document.download_file` | `agency limited` |
| `document.view_history` | `agency` |
| `request.read` | `agency` |
| `request.update` | `agency` |
| `request.update_status` | `agency` |
| `request.assign` | `agency` |
| `request.view_history` | `agency` |
| `service.read` | `agency` |
| `service.update` | `agency limited` |
| `service_order.read` | `agency` |
| `service_order.update` | `agency` |
| `service_order.update_status` | `agency` |
| `service_order.assign` | `agency` |
| `payment.read` | `agency` |
| `payment.view_history` | `agency` |
| `invoice.read` | `agency` |
| `invoice.download` | `agency` |
| `rkl_check.read` | `agency` |
| `rkl_check.view_history` | `agency` |
| `risk_score.read` | `agency` |
| `risk_score.recalculate` | `agency` |
| `notification.read` | `agency` |
| `notification.create` | `agency` |
| `chat.read` | `agency limited` |
| `audit_log.read` | `agency` |
| `integration_log.read` | `agency` |
| `integration_log.retry_event` | `agency limited` |
| `dictionary.read` | `agency` |
| `dictionary.update` | `agency limited` |

### 6.5. `superadmin`

| Permission | Контекст |
|---|---|
| `auth.login` | `own` |
| `auth.logout` | `own` |
| `auth.2fa_confirm` | `own` |
| `user.read` | `technical` |
| `user.create` | `technical` |
| `user.update` | `technical` |
| `user.block` | `technical` |
| `user.unblock` | `technical` |
| `user.delete` | `technical` |
| `user.change_role` | `technical` |
| `user.reset_2fa` | `technical` |
| `migrant.read` | `technical` |
| `migrant.update` | `technical limited` |
| `document.read` | `technical` |
| `document.download_file` | `technical limited` |
| `payment.read` | `technical` |
| `invoice.read` | `technical` |
| `rkl_check.read` | `technical` |
| `risk_score.read` | `technical` |
| `notification.read` | `technical` |
| `chat.read` | `technical limited` |
| `audit_log.read` | `technical` |
| `audit_log.export` | `technical` |
| `integration_log.read` | `technical` |
| `integration_log.retry_event` | `technical` |
| `integration_log.export` | `technical` |
| `role.read` | `technical` |
| `role.manage` | `technical` |
| `permission.read` | `technical` |
| `permission.manage` | `technical` |
| `settings.read` | `technical` |
| `settings.update` | `technical` |
| `dictionary.read` | `technical` |
| `dictionary.update` | `technical` |

---

## 7. Permissions, требующие audit log

| Permission | Причина логирования |
|---|---|
| `user.create` | Создание учетной записи |
| `user.update` | Изменение данных пользователя |
| `user.block` | Блокировка доступа |
| `user.unblock` | Разблокировка доступа |
| `user.delete` | Удаление или архивирование пользователя |
| `user.change_role` | Изменение прав доступа |
| `user.reset_2fa` | Сброс второго фактора |
| `migrant.create` | Создание карточки мигранта |
| `migrant.update` | Изменение персональных данных |
| `migrant.archive` | Архивирование карточки |
| `migrant.assign_manager` | Назначение ответственного |
| `migrant.assign_project` | Изменение проектной принадлежности |
| `document.upload` | Загрузка документа |
| `document.update` | Изменение метаданных документа |
| `document.approve` | Подтверждение документа |
| `document.reject` | Отклонение документа |
| `document.change_status` | Смена статуса документа |
| `document.download_file` | Доступ к чувствительному файлу |
| `document.delete_file` | Удаление или архивирование файла |
| `request.create` | Создание запроса |
| `request.update` | Изменение запроса |
| `request.update_status` | Смена статуса запроса |
| `request.comment` | Комментарий к запросу |
| `request.assign` | Назначение ответственного |
| `service.create` | Создание услуги |
| `service.update` | Изменение услуги |
| `service.archive` | Архивирование услуги |
| `service_order.create` | Создание заявки |
| `service_order.update` | Изменение заявки |
| `service_order.update_status` | Смена статуса заявки |
| `service_order.assign` | Назначение ответственного |
| `service_order.attach_document` | Прикрепление документа |
| `payment.create` | Создание платежа |
| `payment.update_status` | Смена статуса платежа |
| `payment.refund` | Возврат платежа |
| `invoice.create` | Создание счета |
| `invoice.send_email` | Отправка счета |
| `rkl_check.receive_webhook` | Получение критичного внешнего события |
| `risk_score.recalculate` | Пересчет риска |
| `risk_score.override` | Ручная корректировка риска |
| `notification.create` | Создание критичного уведомления |
| `notification.send` | Отправка уведомления |
| `notification.manage_template` | Изменение шаблонов |
| `chat.create` | Создание чата |
| `chat.send_message` | Отправка сообщения |
| `chat.attach_file` | Прикрепление файла |
| `chat.view_internal_notes` | Доступ к внутренним заметкам |
| `chat.moderate` | Модерация чата |
| `audit_log.read` | Просмотр журнала аудита |
| `audit_log.export` | Выгрузка журнала аудита |
| `integration_log.read` | Просмотр журнала интеграций |
| `integration_log.retry_event` | Повторная обработка события |
| `integration_log.export` | Выгрузка журнала интеграций |
| `role.read` | Просмотр ролей |
| `role.manage` | Управление ролями |
| `permission.read` | Просмотр permissions |
| `permission.manage` | Управление permissions |
| `settings.read` | Просмотр системных настроек |
| `settings.update` | Изменение системных настроек |
| `dictionary.update` | Изменение справочников |

---

## 8. Backend permission check

Для защищенного действия backend должен выполнять последовательную проверку:

1. Проверить наличие access token.
2. Определить пользователя.
3. Определить роль пользователя.
4. Проверить наличие permission у роли.
5. Определить контекст доступа.
6. Проверить принадлежность сущности контексту пользователя.
7. Проверить дополнительные бизнес-правила.
8. Выполнить действие или вернуть ошибку.
9. Если действие критичное — записать событие в audit log.

Пример логики:

```text
if not user.has_permission("document.download_file"):
    return 403

if not document.is_visible_for(user):
    return 403

return generate_presigned_url(document.file_id)
```

---

## 9. Ошибки доступа

| Ситуация | Код | Поведение |
|---|---|---|
| Нет access token | 401 Unauthorized | Пользователь должен пройти авторизацию |
| Token истек | 401 Unauthorized | Пользователь должен обновить сессию или войти снова |
| Нет permission | 403 Forbidden | Действие запрещено |
| Нет доступа к сущности по контексту | 403 Forbidden | Данные не возвращаются |
| Сущность не существует | 404 Not Found | Возвращается, если это безопасно |
| Сущность существует, но пользователь не имеет доступа | 403 Forbidden или безопасный 404 | Выбор зависит от политики защиты от enumeration |
| Недопустимый статусный переход | 409 Conflict | Действие противоречит статусной модели |
| Ошибка валидации | 422 Unprocessable Entity | Переданы некорректные данные |

---

## 10. Связь permissions с UI

Frontend может использовать permissions для:

- скрытия недоступных разделов;
- скрытия или disabled-состояния кнопок;
- настройки стартового экрана;
- ограничения доступных фильтров;
- ограничения доступных действий со строками таблиц;
- отображения понятных ошибок доступа.

Но backend остается источником истины.

| UI-сценарий | Permission |
|---|---|
| Показать кнопку “Загрузить документ” | `document.upload` |
| Показать кнопку “Подтвердить документ” | `document.approve` |
| Показать кнопку “Отклонить документ” | `document.reject` |
| Показать кнопку “Сформировать счет” | `invoice.create` |
| Показать кнопку “Назначить ответственного” | `request.assign` / `service_order.assign` |
| Показать раздел “Audit log” | `audit_log.read` |
| Показать раздел “Роли и права” | `role.read` |
| Показать системные настройки | `settings.read` |

---

## 11. Связанные артефакты

- [Role Model](./role-model.md)
- [Access Matrix](./access-matrix.md)
- [Functional Requirements](../01_requirements/functional-requirements.md)
- [Non-Functional Requirements](../01_requirements/non-functional-requirements.md)
- [Acceptance Criteria](../01_requirements/acceptance-criteria.md)
- [Error Model](../05_api/error-model.md)
- [Test Cases](../08_testing/test-cases.md)
