# Access Matrix — MigrationOS

## 1. Назначение документа

Документ описывает матрицу доступа для ролей платформы MigrationOS.

Матрица доступа определяет:

- какие роли имеют доступ к модулям системы;
- какие действия разрешены каждой роли;
- какие ограничения применяются к данным;
- какие проверки должны выполняться на backend;
- какие элементы интерфейса должны быть доступны или скрыты;
- какие сценарии нужно покрыть тестами доступа.

Документ является продолжением [Role Model](./role-model.md) и основой для [Permissions](./permissions.md).

---

## 2. Обозначения прав

| Обозначение | Значение |
|---|---|
| `none` | Нет доступа |
| `read` | Просмотр данных |
| `create` | Создание сущности |
| `update` | Изменение сущности |
| `delete` | Удаление или архивирование |
| `approve` | Подтверждение, проверка или согласование |
| `manage` | Полное управление сущностью или модулем в рамках роли |
| `technical` | Технический доступ для администрирования или расследования |
| `limited` | Ограниченный доступ по контексту |
| `own` | Только свои данные |
| `org` | Только данные своей организации |
| `assigned` | Только назначенные или доступные по правилам агентства данные |
| `agency` | Данные в рамках всего агентства |

---

## 3. Принципы матрицы доступа

- Все защищенные действия должны проверяться на backend.
- UI может скрывать недоступные действия, но не заменяет backend authorization.
- Доступ проверяется не только по роли, но и по контексту сущности.
- `migrant` видит только свои данные.
- `employer` видит только данные своей организации.
- `manager` видит данные согласно назначению, проекту или правилам агентства.
- `supervisor` имеет расширенный доступ в рамках агентства.
- `superadmin` имеет административный и технический доступ, но его действия также логируются.
- Доступ к документам, платежам, ролям и настройкам считается критичным.
- Попытка доступа к запрещенной сущности должна возвращать `403 Forbidden`.
- Ошибка доступа не должна раскрывать чувствительные данные.

---

## 4. Матрица доступа к модулям

| Модуль / роль | migrant | employer | manager | supervisor | superadmin |
|---|---|---|---|---|---|
| Мобильное приложение | `manage own` | `none` | `none` | `none` | `none` |
| ЛК работодателя | `none` | `manage org` | `none` | `none` | `none` |
| Админ-панель | `none` | `none` | `read/update assigned` | `read/update agency` | `manage technical` |
| Профиль пользователя | `read/update own limited` | `read/update own limited` | `read/update own` | `read/update own` | `manage` |
| Карточка мигранта | `read own limited` | `read org limited` | `read/update assigned` | `read/update agency` | `technical` |
| Документы мигранта | `read/create own` | `read org limited` | `read/update/approve assigned` | `read/approve agency` | `technical` |
| Запросы | `create/read own` | `read/update org` | `read/update assigned` | `read/update agency` | `technical` |
| Заявки на услуги | `create/read own` | `create/read org` | `read/update assigned` | `read/update agency` | `technical` |
| Маркетплейс услуг | `read/create own` | `read/create org` | `read/manage assigned` | `read agency` | `manage` |
| Платежи и счета | `read own limited` | `read/create org` | `read assigned` | `read agency` | `technical` |
| Риск-дашборд | `none/limited` | `read org` | `read assigned` | `read agency` | `technical` |
| РКЛ-проверки | `none` | `read org limited` | `read assigned` | `read agency` | `technical` |
| Уведомления | `read own` | `read org/own` | `read assigned` | `read agency` | `technical` |
| Чаты | `read/create own` | `read/create org` | `read/create assigned` | `read agency limited` | `technical limited` |
| Audit log | `none` | `none` | `read assigned limited` | `read agency` | `read/manage technical` |
| Integration log | `none` | `none` | `read assigned limited` | `read agency` | `read/manage technical` |
| Пользователи | `none` | `read/update org limited` | `none` | `read agency limited` | `manage` |
| Роли и права | `none` | `none` | `none` | `none/limited` | `manage` |
| Справочники | `none` | `none` | `read` | `read/update limited` | `manage` |
| Системные настройки | `none` | `none` | `none` | `none` | `manage` |

---

## 5. Матрица доступа к сущностям

| Сущность / роль | migrant | employer | manager | supervisor | superadmin |
|---|---|---|---|---|---|
| `User` | `read/update own limited` | `read/update own limited` | `read own` | `read agency` | `manage` |
| `Migrant` | `read own` | `read org` | `read/update assigned` | `read/update agency` | `technical` |
| `Employer` | `none` | `read/update own org limited` | `read/update assigned` | `read/update agency` | `technical` |
| `Project` | `none` | `none` | `read assigned` | `read/update agency` | `manage` |
| `Document` | `read/create own` | `read org limited` | `read/update/approve assigned` | `read/approve agency` | `technical` |
| `DocumentFile` | `read/create own` | `read org limited` | `read assigned` | `read agency` | `technical` |
| `Request` | `create/read own` | `read/update org` | `read/update assigned` | `read/update agency` | `technical` |
| `ServiceOrder` | `create/read own` | `create/read org` | `read/update assigned` | `read/update agency` | `technical` |
| `Service` | `read` | `read` | `read` | `read/update limited` | `manage` |
| `Payment` | `read own limited` | `read/create org` | `read assigned` | `read agency` | `technical` |
| `Invoice` | `read own limited` | `read/create org` | `read assigned` | `read agency` | `technical` |
| `Notification` | `read own` | `read own/org` | `read assigned` | `read agency` | `technical` |
| `ChatThread` | `read/create own` | `read/create org` | `read/create assigned` | `read agency limited` | `technical limited` |
| `ChatMessage` | `read/create own` | `read/create org` | `read/create assigned` | `read agency limited` | `technical limited` |
| `RklCheck` | `none` | `read org limited` | `read assigned` | `read agency` | `technical` |
| `RiskScore` | `read own limited` | `read org` | `read assigned` | `read agency` | `technical` |
| `AuditLog` | `none` | `none` | `read assigned limited` | `read agency` | `read/manage technical` |
| `IntegrationLog` | `none` | `none` | `read assigned limited` | `read agency` | `read/manage technical` |

---

## 6. Матрица действий

| Действие / роль | migrant | employer | manager | supervisor | superadmin |
|---|---|---|---|---|---|
| Войти в систему | Да | Да | Да | Да | Да |
| Пройти 2FA | Нет | Нет / optional | Да | Да | Да |
| Смотреть свой профиль | Да | Да | Да | Да | Да |
| Редактировать свой профиль | Ограниченно | Ограниченно | Да | Да | Да |
| Смотреть список мигрантов | Нет | Только своих | По правам | Все агентство | Технически |
| Открыть карточку мигранта | Только свою | Только своих | По правам | Все агентство | Технически |
| Редактировать карточку мигранта | Нет / ограниченно | Нет | По правам | По правам | Технически |
| Смотреть документы | Только свои | Только своих мигрантов | По правам | По правам | Технически |
| Загрузить документ | Да, свой | Нет / если разрешено | Да | Да | Технически |
| Подтвердить документ | Нет | Нет | Да | Да | Технически |
| Отклонить документ | Нет | Нет | Да | Да | Технически |
| Создать запрос | Да | Да | Да | Да | Технически |
| Изменить статус запроса | Нет | Ограниченно | Да | Да | Технически |
| Создать заявку на услугу | Да | Да | Да | Да | Технически |
| Изменить статус заявки | Нет | Нет / ограниченно | Да | Да | Технически |
| Создать платеж | Ограниченно | Да | Да | Да | Технически |
| Подтвердить оплату вручную | Нет | Нет | Нет / ограниченно | Ограниченно | Технически |
| Смотреть РКЛ-результат | Нет | Ограниченно | Да | Да | Технически |
| Изменить РКЛ-результат | Нет | Нет | Нет | Нет | Нет / только через интеграцию |
| Смотреть риск-дашборд | Нет / ограниченно | Своя организация | По правам | Все агентство | Технически |
| Создать сообщение в чате | Да | Да | Да | Да | Технически |
| Смотреть audit log | Нет | Нет | Ограниченно | Да | Да |
| Смотреть integration log | Нет | Нет | Ограниченно | Да | Да |
| Управлять пользователями | Нет | Ограниченно своей организацией | Нет | Ограниченно | Да |
| Управлять ролями | Нет | Нет | Нет | Нет / ограниченно | Да |
| Управлять системными настройками | Нет | Нет | Нет | Нет | Да |

---

## 7. Контекстные правила доступа

### 7.1. Правило `own`

Пользователь может получить доступ только к данным, связанным с его учетной записью.

Применяется для:

- профиля мигранта;
- документов мигранта;
- заявок мигранта;
- запросов мигранта;
- уведомлений мигранта;
- чатов мигранта.

Пример:

```text
migrant.user_id == current_user.id
или
document.migrant_id == current_user.migrant_id
```

### 7.2. Правило `org`

Пользователь может получить доступ только к данным своей организации.

Применяется для работодателя.

Пример:

```text
migrant.employer_id == current_user.employer_id
payment.employer_id == current_user.employer_id
request.employer_id == current_user.employer_id
```

### 7.3. Правило `assigned`

Пользователь может получить доступ к данным, назначенным ему или доступным по внутренним правилам агентства.

Применяется для менеджера.

Пример:

```text
migrant.manager_id == current_user.id
или
request.assignee_id == current_user.id
или
migrant.project_id in current_user.available_project_ids
```

### 7.4. Правило `agency`

Пользователь может получить доступ к данным в рамках всего агентства.

Применяется для `supervisor`.

Пример:

```text
entity.agency_id == current_user.agency_id
```

### 7.5. Правило `technical`

Технический доступ используется для администрирования, расследования ошибок и настройки системы.

Применяется для `superadmin`.

Ограничения:

- технический доступ не должен использоваться для обхода бизнес-процессов;
- действия должны логироваться;
- доступ к чувствительным данным должен быть регламентирован;
- для production-данных могут действовать дополнительные ограничения.

---

## 8. Backend authorization rules

| ID | Правило | Ожидаемое поведение |
|---|---|---|
| AZ-001 | Запрос без access token | Backend возвращает 401 Unauthorized |
| AZ-002 | Пользователь авторизован, но роль не имеет доступа к модулю | Backend возвращает 403 Forbidden |
| AZ-003 | Пользователь имеет роль, но сущность не входит в его контекст доступа | Backend возвращает 403 Forbidden |
| AZ-004 | Employer запрашивает мигранта другой организации | Backend возвращает 403 Forbidden |
| AZ-005 | Migrant запрашивает чужой документ | Backend возвращает 403 Forbidden |
| AZ-006 | Manager запрашивает сущность вне зоны ответственности | Backend возвращает 403 Forbidden или требует расширенное право |
| AZ-007 | Supervisor запрашивает данные вне агентства | Backend возвращает 403 Forbidden |
| AZ-008 | Superadmin меняет роль пользователя | Backend выполняет действие только при наличии права manage_roles и пишет audit log |
| AZ-009 | Пользователь меняет статус сущности | Backend проверяет право на действие и допустимость статусного перехода |
| AZ-010 | Пользователь пытается скачать файл документа | Backend проверяет роль, контекст и право на файл |
| AZ-011 | Ошибка доступа | Backend не должен раскрывать чувствительные данные запрещенной сущности |
| AZ-012 | Массовая операция | Backend должен проверять права на каждую сущность в наборе |

---

## 9. UI visibility rules

| ID | Правило | Описание |
|---|---|---|
| UI-001 | Недоступные разделы скрываются | Пользователь не видит модули, к которым у него нет доступа |
| UI-002 | Недоступные действия скрываются или disabled | Кнопки редактирования, подтверждения, удаления скрыты или недоступны |
| UI-003 | UI не заменяет backend authorization | Даже скрытое действие должно быть защищено на API |
| UI-004 | Списки фильтруются по контексту доступа | Employer видит только своих мигрантов, manager — доступных по правам |
| UI-005 | Ошибка 403 отображается понятным сообщением | Пользователь видит безопасное сообщение без технических деталей |
| UI-006 | Разные роли могут иметь разные стартовые экраны | Migrant — мобильный dashboard, employer — risk dashboard, manager — queue/tasks |
| UI-007 | Внутренние комментарии не показываются внешним ролям | Employer и migrant не видят internal notes |
| UI-008 | Технические логи показываются только внутренним ролям | Integration log и audit log недоступны внешним пользователям |

---

## 10. Критичные сценарии для тестирования доступа

| ID | Сценарий | Ожидаемый результат |
|---|---|---|
| AT-001 | Employer открывает карточку чужого мигранта прямым URL | 403 Forbidden |
| AT-002 | Migrant запрашивает файл чужого документа | 403 Forbidden |
| AT-003 | Employer пытается открыть audit log | 403 Forbidden |
| AT-004 | Manager пытается изменить системные настройки | 403 Forbidden |
| AT-005 | Supervisor пытается управлять ролями без разрешения | 403 Forbidden |
| AT-006 | Superadmin меняет роль пользователя | Действие выполняется и пишется audit log |
| AT-007 | Пользователь без токена открывает защищенный endpoint | 401 Unauthorized |
| AT-008 | Employer открывает список мигрантов | В списке только мигранты его организации |
| AT-009 | Migrant открывает список документов | В списке только его документы |
| AT-010 | Manager открывает список заявок | В списке только доступные по правилам заявки |
| AT-011 | Пользователь пытается скачать файл без прав | 403 Forbidden |
| AT-012 | Массовая операция содержит часть недоступных сущностей | Недоступные сущности не изменяются, операция возвращает безопасный результат |

---

## 11. Связанные артефакты

- [Role Model](./role-model.md)
- [Permissions](./permissions.md)
- [Functional Requirements](../01_requirements/functional-requirements.md)
- [Non-Functional Requirements](../01_requirements/non-functional-requirements.md)
- [Acceptance Criteria](../01_requirements/acceptance-criteria.md)
- [API Overview](../05_api/api-overview.md)
- [Error Model](../05_api/error-model.md)
- [Test Cases](../08_testing/test-cases.md)
