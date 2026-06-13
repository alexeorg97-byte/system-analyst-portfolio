-- ============================================================
-- MigrationOS — Sample SQL Queries
-- PostgreSQL
-- ============================================================
--
-- Назначение:
-- Демонстрационные SQL-запросы для портфолио системного аналитика.
--
-- Файл показывает, как аналитик может работать с данными MigrationOS:
-- - проверять бизнес-правила;
-- - анализировать документы и риски;
-- - строить выборки для дашбордов;
-- - проверять интеграционные события;
-- - готовить запросы для QA и backend-разработки.
--
-- Связанные артефакты:
-- - schema.sql
-- - ../erd.md
-- - ../entities.md
-- - ../data-dictionary.md
-- - ../status-models.md
-- ============================================================


-- ============================================================
-- 1. Мигранты работодателя
-- ============================================================
-- Сценарий:
-- Работодатель открывает кабинет и видит только мигрантов своей организации.
-- Запрос демонстрирует фильтрацию по employer_id.

SELECT
    m.id AS migrant_id,
    m.full_name,
    m.citizenship,
    m.status AS migrant_status,
    e.name AS employer_name,
    p.name AS project_name
FROM migrants m
JOIN employers e ON e.id = m.employer_id
LEFT JOIN projects p ON p.id = m.project_id
WHERE m.employer_id = :employer_id
ORDER BY m.full_name;


-- ============================================================
-- 2. Документы мигранта с ближайшим сроком окончания
-- ============================================================
-- Сценарий:
-- Менеджер проверяет документы мигранта и видит, какие документы скоро истекают.

SELECT
    m.id AS migrant_id,
    m.full_name,
    d.document_type,
    d.number,
    d.status,
    d.expiration_date,
    d.expiration_date - CURRENT_DATE AS days_left
FROM documents d
JOIN migrants m ON m.id = d.migrant_id
WHERE d.expiration_date IS NOT NULL
  AND d.status IN ('approved', 'expires_soon', 'expired')
  AND m.id = :migrant_id
ORDER BY d.expiration_date ASC;


-- ============================================================
-- 3. Мигранты с документами, истекающими в ближайшие 30 дней
-- ============================================================
-- Сценарий:
-- Дашборд менеджера показывает мигрантов, у которых скоро истекают документы.

SELECT
    m.id AS migrant_id,
    m.full_name,
    e.name AS employer_name,
    d.document_type,
    d.expiration_date,
    d.expiration_date - CURRENT_DATE AS days_left
FROM documents d
JOIN migrants m ON m.id = d.migrant_id
LEFT JOIN employers e ON e.id = m.employer_id
WHERE d.expiration_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days'
  AND d.status IN ('approved', 'expires_soon')
ORDER BY d.expiration_date ASC;


-- ============================================================
-- 4. Количество мигрантов по работодателям
-- ============================================================
-- Сценарий:
-- Supervisor смотрит распределение мигрантов по работодателям.

SELECT
    e.id AS employer_id,
    e.name AS employer_name,
    COUNT(m.id) AS migrants_count
FROM employers e
LEFT JOIN migrants m ON m.employer_id = e.id
GROUP BY e.id, e.name
ORDER BY migrants_count DESC;


-- ============================================================
-- 5. Количество мигрантов по проектам
-- ============================================================
-- Сценарий:
-- Агентство анализирует внутренние проекты и нагрузку менеджеров.

SELECT
    p.id AS project_id,
    p.name AS project_name,
    COUNT(m.id) AS migrants_count
FROM projects p
LEFT JOIN migrants m ON m.project_id = p.id
GROUP BY p.id, p.name
ORDER BY migrants_count DESC;


-- ============================================================
-- 6. Последняя РКЛ-проверка по каждому мигранту
-- ============================================================
-- Сценарий:
-- Менеджер или supervisor видит последний результат РКЛ-проверки.
-- Используется оконная функция ROW_NUMBER.

WITH ranked_rkl AS (
    SELECT
        rc.*,
        ROW_NUMBER() OVER (
            PARTITION BY rc.migrant_id
            ORDER BY rc.checked_at DESC
        ) AS rn
    FROM rkl_checks rc
)
SELECT
    m.id AS migrant_id,
    m.full_name,
    rr.checked_at,
    rr.matched,
    rr.raw_status
FROM ranked_rkl rr
JOIN migrants m ON m.id = rr.migrant_id
WHERE rr.rn = 1
ORDER BY rr.checked_at DESC;


-- ============================================================
-- 7. Мигранты с критичным риском
-- ============================================================
-- Сценарий:
-- Supervisor открывает список критичных мигрантов.

SELECT
    m.id AS migrant_id,
    m.full_name,
    e.name AS employer_name,
    rs.score,
    rs.level,
    rs.reason,
    rs.calculated_at
FROM risk_scores rs
JOIN migrants m ON m.id = rs.migrant_id
LEFT JOIN employers e ON e.id = m.employer_id
WHERE rs.level = 'critical'
ORDER BY rs.score DESC, rs.calculated_at DESC;


-- ============================================================
-- 8. Риск по работодателям
-- ============================================================
-- Сценарий:
-- Дашборд показывает, у каких работодателей больше всего мигрантов с риском.
-- Используются FILTER и агрегаты.

SELECT
    e.id AS employer_id,
    e.name AS employer_name,
    COUNT(m.id) AS total_migrants,
    COUNT(*) FILTER (WHERE rs.level = 'attention') AS attention_count,
    COUNT(*) FILTER (WHERE rs.level = 'critical') AS critical_count
FROM employers e
LEFT JOIN migrants m ON m.employer_id = e.id
LEFT JOIN risk_scores rs ON rs.migrant_id = m.id
GROUP BY e.id, e.name
ORDER BY critical_count DESC, attention_count DESC;


-- ============================================================
-- 9. Открытые запросы мигрантов к работодателю
-- ============================================================
-- Сценарий:
-- Работодатель видит список запросов, которые еще требуют обработки.

SELECT
    r.id AS request_id,
    r.request_type,
    r.status,
    r.created_at,
    m.full_name AS migrant_name,
    e.name AS employer_name
FROM requests r
JOIN migrants m ON m.id = r.migrant_id
JOIN employers e ON e.id = r.employer_id
WHERE r.employer_id = :employer_id
  AND r.status IN ('created', 'in_progress', 'need_info')
ORDER BY r.created_at ASC;


-- ============================================================
-- 10. Просроченные запросы в работе
-- ============================================================
-- Сценарий:
-- Менеджер ищет запросы, которые долго находятся в работе.
-- Условный SLA: больше 3 дней в статусе in_progress.

SELECT
    r.id AS request_id,
    r.request_type,
    r.status,
    r.created_at,
    now() - r.created_at AS age,
    m.full_name AS migrant_name,
    e.name AS employer_name
FROM requests r
LEFT JOIN migrants m ON m.id = r.migrant_id
LEFT JOIN employers e ON e.id = r.employer_id
WHERE r.status = 'in_progress'
  AND r.created_at < now() - INTERVAL '3 days'
ORDER BY r.created_at ASC;


-- ============================================================
-- 11. Заявки на услуги, ожидающие оплаты
-- ============================================================
-- Сценарий:
-- Менеджер проверяет заявки, которые зависли на оплате.

SELECT
    so.id AS service_order_id,
    s.name AS service_name,
    so.status,
    so.total_amount,
    so.created_at,
    m.full_name AS migrant_name,
    e.name AS employer_name
FROM service_orders so
JOIN services s ON s.id = so.service_id
LEFT JOIN migrants m ON m.id = so.migrant_id
LEFT JOIN employers e ON e.id = so.employer_id
WHERE so.status = 'waiting_payment'
ORDER BY so.created_at ASC;


-- ============================================================
-- 12. Последний платеж по каждой заявке
-- ============================================================
-- Сценарий:
-- Аналитик проверяет текущий платежный статус заявок.
-- Используется оконная функция ROW_NUMBER.

WITH ranked_payments AS (
    SELECT
        p.*,
        ROW_NUMBER() OVER (
            PARTITION BY p.service_order_id
            ORDER BY p.created_at DESC
        ) AS rn
    FROM payments p
)
SELECT
    so.id AS service_order_id,
    s.name AS service_name,
    rp.status AS last_payment_status,
    rp.amount,
    rp.currency,
    rp.created_at AS payment_created_at,
    rp.paid_at
FROM service_orders so
JOIN services s ON s.id = so.service_id
LEFT JOIN ranked_payments rp
    ON rp.service_order_id = so.id
   AND rp.rn = 1
ORDER BY so.created_at DESC;


-- ============================================================
-- 13. Платежи без подтверждения дольше 30 минут
-- ============================================================
-- Сценарий:
-- Backend/support проверяет платежи, по которым не пришел webhook.

SELECT
    p.id AS payment_id,
    p.provider,
    p.provider_payment_id,
    p.amount,
    p.currency,
    p.status,
    p.created_at,
    so.id AS service_order_id
FROM payments p
JOIN service_orders so ON so.id = p.service_order_id
WHERE p.status = 'pending'
  AND p.created_at < now() - INTERVAL '30 minutes'
ORDER BY p.created_at ASC;


-- ============================================================
-- 14. Интеграционные события с ошибками
-- ============================================================
-- Сценарий:
-- Support или backend анализирует ошибки интеграций.

SELECT
    il.id AS integration_log_id,
    il.integration_name,
    il.event_id,
    il.direction,
    il.status,
    il.entity_type,
    il.entity_id,
    il.created_at
FROM integration_logs il
WHERE il.status IN ('validation_error', 'unmatched', 'failed')
ORDER BY il.created_at DESC;


-- ============================================================
-- 15. Повторные webhook-события
-- ============================================================
-- Сценарий:
-- Проверка идемпотентности интеграций.

SELECT
    il.integration_name,
    il.event_id,
    COUNT(*) AS events_count,
    MIN(il.created_at) AS first_seen_at,
    MAX(il.created_at) AS last_seen_at
FROM integration_logs il
WHERE il.event_id IS NOT NULL
GROUP BY il.integration_name, il.event_id
HAVING COUNT(*) > 1
ORDER BY events_count DESC, last_seen_at DESC;


-- ============================================================
-- 16. Уведомления, которые не доставились
-- ============================================================
-- Сценарий:
-- Проверка проблем с push/email-уведомлениями.

SELECT
    n.id AS notification_id,
    n.user_id,
    n.type,
    n.title,
    n.status,
    n.created_at
FROM notifications n
WHERE n.status = 'failed'
ORDER BY n.created_at DESC;


-- ============================================================
-- 17. Последние действия пользователя в audit log
-- ============================================================
-- Сценарий:
-- Проверка активности пользователя или расследование инцидента.

SELECT
    al.id AS audit_log_id,
    al.actor_user_id,
    al.action,
    al.entity_type,
    al.entity_id,
    al.created_at
FROM audit_logs al
WHERE al.actor_user_id = :user_id
ORDER BY al.created_at DESC
LIMIT 50;


-- ============================================================
-- 18. Поиск изменений по конкретной сущности
-- ============================================================
-- Сценарий:
-- Расследование изменений карточки мигранта, заявки или документа.

SELECT
    al.id AS audit_log_id,
    al.actor_user_id,
    al.action,
    al.before_state,
    al.after_state,
    al.created_at
FROM audit_logs al
WHERE al.entity_type = :entity_type
  AND al.entity_id = :entity_id
ORDER BY al.created_at ASC;


-- ============================================================
-- 19. Мигранты без актуального RiskScore
-- ============================================================
-- Сценарий:
-- QA или backend проверяет целостность риск-расчетов.

SELECT
    m.id AS migrant_id,
    m.full_name,
    m.status,
    m.created_at
FROM migrants m
LEFT JOIN risk_scores rs ON rs.migrant_id = m.id
WHERE rs.id IS NULL
  AND m.status = 'active'
ORDER BY m.created_at DESC;


-- ============================================================
-- 20. Проверка документов без файлов
-- ============================================================
-- Сценарий:
-- QA проверяет, что документы в статусе under_review имеют файл.

SELECT
    d.id AS document_id,
    d.migrant_id,
    d.document_type,
    d.status,
    d.created_at
FROM documents d
LEFT JOIN document_files df ON df.document_id = d.id
WHERE d.status = 'under_review'
  AND df.id IS NULL
ORDER BY d.created_at DESC;


-- ============================================================
-- 21. Последний документ каждого типа по мигранту
-- ============================================================
-- Сценарий:
-- Менеджер хочет видеть по мигранту последнюю запись по каждому типу документа.
-- Используется оконная функция для выбора актуальной записи.

WITH ranked_documents AS (
    SELECT
        d.*,
        ROW_NUMBER() OVER (
            PARTITION BY d.migrant_id, d.document_type
            ORDER BY d.created_at DESC
        ) AS rn
    FROM documents d
)
SELECT
    rd.migrant_id,
    m.full_name,
    rd.document_type,
    rd.status,
    rd.expiration_date,
    rd.created_at
FROM ranked_documents rd
JOIN migrants m ON m.id = rd.migrant_id
WHERE rd.rn = 1
  AND rd.migrant_id = :migrant_id
ORDER BY rd.document_type;


-- ============================================================
-- 22. Работодатели с наибольшим числом открытых заявок на услуги
-- ============================================================
-- Сценарий:
-- Supervisor анализирует, по каким работодателям сейчас наибольшая операционная нагрузка.

SELECT
    e.id AS employer_id,
    e.name AS employer_name,
    COUNT(so.id) AS open_service_orders_count
FROM employers e
JOIN service_orders so ON so.employer_id = e.id
WHERE so.status IN ('created', 'waiting_payment', 'paid', 'in_progress', 'need_info')
GROUP BY e.id, e.name
ORDER BY open_service_orders_count DESC, e.name;


-- ============================================================
-- 23. Среднее время обработки завершенных запросов
-- ============================================================
-- Сценарий:
-- Аналитик оценивает скорость обработки запросов работодателем или агентством.
-- В демонстрационной схеме используется разница между created_at и updated_at.

SELECT
    r.request_type,
    COUNT(*) AS completed_requests_count,
    AVG(r.updated_at - r.created_at) AS avg_processing_time
FROM requests r
WHERE r.status = 'completed'
  AND r.updated_at IS NOT NULL
GROUP BY r.request_type
ORDER BY completed_requests_count DESC, r.request_type;


-- ============================================================
-- 24. Сводка по статусам service order
-- ============================================================
-- Сценарий:
-- Дашборд маркетплейса показывает распределение заявок по статусам.

SELECT
    so.status,
    COUNT(*) AS orders_count,
    COALESCE(SUM(so.total_amount), 0) AS total_amount_sum
FROM service_orders so
GROUP BY so.status
ORDER BY orders_count DESC, so.status;


-- ============================================================
-- 25. Последние интеграционные события по РКЛ
-- ============================================================
-- Сценарий:
-- Support проверяет историю webhook-событий, связанных с РКЛ.

SELECT
    il.id AS integration_log_id,
    il.integration_name,
    il.event_id,
    il.status,
    il.entity_type,
    il.entity_id,
    il.created_at
FROM integration_logs il
WHERE il.integration_name ILIKE '%rkl%'
   OR il.entity_type = 'RklCheck'
ORDER BY il.created_at DESC
LIMIT 100;


-- ============================================================
-- End of sample queries
-- ============================================================
