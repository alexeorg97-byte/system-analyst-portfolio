-- ============================================================
-- MigrationOS — SQL Schema
-- PostgreSQL
-- ============================================================
--
-- Назначение:
-- Демонстрационная SQL-схема для портфолио системного аналитика.
-- Схема отражает ключевые сущности MigrationOS:
-- пользователи, роли, мигранты, работодатели, проекты, документы,
-- запросы, маркетплейс, платежи, РКЛ-проверки, риск-статусы,
-- уведомления, чаты, audit log и integration log.
--
-- Связанные артефакты:
-- - ../erd.md
-- - ../entities.md
-- - ../data-dictionary.md
-- - ../status-models.md
--
-- Примечание:
-- Это логическая SQL-схема, а не production migration.
-- ============================================================


-- ============================================================
-- 1. Extensions
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";


-- ============================================================
-- 2. Roles and users
-- ============================================================

CREATE TABLE roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT chk_roles_code
        CHECK (code IN ('migrant', 'employer', 'manager', 'supervisor', 'superadmin'))
);

COMMENT ON TABLE roles IS 'Системные роли пользователей MigrationOS.';


CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_id UUID NOT NULL REFERENCES roles(id),

    email VARCHAR(255) UNIQUE,
    phone VARCHAR(32) UNIQUE,
    password_hash TEXT,

    status VARCHAR(30) NOT NULL DEFAULT 'pending',
    last_login_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ,

    CONSTRAINT chk_users_status
        CHECK (status IN ('active', 'blocked', 'pending', 'archived')),

    CONSTRAINT chk_users_login_identifier
        CHECK (email IS NOT NULL OR phone IS NOT NULL)
);

COMMENT ON TABLE users IS 'Учетные записи пользователей платформы.';
COMMENT ON COLUMN users.password_hash IS 'Хэш пароля. Пароль в открытом виде не хранится.';


CREATE INDEX idx_users_role_id ON users(role_id);
CREATE INDEX idx_users_status ON users(status);


-- ============================================================
-- 3. Employers and projects
-- ============================================================

CREATE TABLE employers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name VARCHAR(255) NOT NULL,
    inn VARCHAR(20) NOT NULL UNIQUE,

    verification_status VARCHAR(50) NOT NULL DEFAULT 'pending_verification',
    contact_email VARCHAR(255),
    contact_phone VARCHAR(32),

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ,

    CONSTRAINT chk_employers_verification_status
        CHECK (verification_status IN ('pending_verification', 'verified', 'rejected', 'blocked'))
);

COMMENT ON TABLE employers IS 'Компании-работодатели. Работодатель не является tenant.';


CREATE INDEX idx_employers_verification_status ON employers(verification_status);


CREATE TABLE projects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(30) NOT NULL DEFAULT 'active',

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT chk_projects_status
        CHECK (status IN ('active', 'archived'))
);

COMMENT ON TABLE projects IS 'Внутренняя группировка мигрантов в агентстве. Project не является организацией.';


CREATE INDEX idx_projects_status ON projects(status);


-- ============================================================
-- 4. Migrants
-- ============================================================

CREATE TABLE migrants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID UNIQUE REFERENCES users(id),
    employer_id UUID REFERENCES employers(id),
    project_id UUID REFERENCES projects(id),
    manager_id UUID REFERENCES users(id),

    full_name VARCHAR(255) NOT NULL,
    birth_date DATE NOT NULL,
    phone VARCHAR(32),
    passport_number VARCHAR(100),
    citizenship VARCHAR(100),

    status VARCHAR(30) NOT NULL DEFAULT 'pending',

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ,

    CONSTRAINT chk_migrants_status
        CHECK (status IN ('active', 'pending', 'blocked', 'archived')),

    CONSTRAINT chk_migrants_birth_date
        CHECK (birth_date <= CURRENT_DATE)
);

COMMENT ON TABLE migrants IS 'Карточка иностранного работника.';
COMMENT ON COLUMN migrants.passport_number IS 'ПДн. Доступ должен ограничиваться ролями и контекстом.';


CREATE INDEX idx_migrants_user_id ON migrants(user_id);
CREATE INDEX idx_migrants_employer_id ON migrants(employer_id);
CREATE INDEX idx_migrants_project_id ON migrants(project_id);
CREATE INDEX idx_migrants_manager_id ON migrants(manager_id);
CREATE INDEX idx_migrants_status ON migrants(status);


-- ============================================================
-- 5. Documents
-- ============================================================

CREATE TABLE documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    migrant_id UUID NOT NULL REFERENCES migrants(id),

    document_type VARCHAR(100) NOT NULL,
    number VARCHAR(100),
    issue_date DATE,
    expiration_date DATE,

    status VARCHAR(30) NOT NULL DEFAULT 'draft',
    rejection_reason TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ,

    CONSTRAINT chk_documents_status
        CHECK (status IN ('draft', 'under_review', 'approved', 'rejected', 'expires_soon', 'expired', 'archived')),

    CONSTRAINT chk_documents_dates
        CHECK (expiration_date IS NULL OR issue_date IS NULL OR issue_date <= expiration_date),

    CONSTRAINT chk_documents_rejection_reason
        CHECK (status <> 'rejected' OR rejection_reason IS NOT NULL)
);

COMMENT ON TABLE documents IS 'Документы мигранта: паспорт, патент, регистрация, миграционная карта и др.';


CREATE INDEX idx_documents_migrant_id ON documents(migrant_id);
CREATE INDEX idx_documents_status ON documents(status);
CREATE INDEX idx_documents_expiration_date ON documents(expiration_date);


CREATE TABLE document_files (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    document_id UUID NOT NULL REFERENCES documents(id),
    storage_key TEXT NOT NULL UNIQUE,
    file_name VARCHAR(255) NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    file_size INTEGER NOT NULL,
    uploaded_by UUID NOT NULL REFERENCES users(id),

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT chk_document_files_size
        CHECK (file_size > 0)
);

COMMENT ON TABLE document_files IS 'Файлы документов в защищенном хранилище.';
COMMENT ON COLUMN document_files.storage_key IS 'Ключ файла в S3 или совместимом хранилище. Не публичный URL.';


CREATE INDEX idx_document_files_document_id ON document_files(document_id);
CREATE INDEX idx_document_files_uploaded_by ON document_files(uploaded_by);


-- ============================================================
-- 6. Requests
-- ============================================================

CREATE TABLE requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    request_type VARCHAR(100) NOT NULL,

    migrant_id UUID REFERENCES migrants(id),
    employer_id UUID REFERENCES employers(id),

    created_by UUID NOT NULL REFERENCES users(id),
    assignee_id UUID REFERENCES users(id),

    status VARCHAR(30) NOT NULL DEFAULT 'created',

    comment TEXT,
    internal_comment TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ,

    CONSTRAINT chk_requests_status
        CHECK (status IN ('created', 'in_progress', 'need_info', 'completed', 'rejected', 'cancelled'))
);

COMMENT ON TABLE requests IS 'Запросы между мигрантом, работодателем и агентством.';
COMMENT ON COLUMN requests.internal_comment IS 'Внутренний комментарий агентства. Не должен возвращаться внешним ролям.';


CREATE INDEX idx_requests_migrant_id ON requests(migrant_id);
CREATE INDEX idx_requests_employer_id ON requests(employer_id);
CREATE INDEX idx_requests_created_by ON requests(created_by);
CREATE INDEX idx_requests_assignee_id ON requests(assignee_id);
CREATE INDEX idx_requests_status ON requests(status);
CREATE INDEX idx_requests_created_at ON requests(created_at);


-- ============================================================
-- 7. Marketplace and service orders
-- ============================================================

CREATE TABLE services (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,

    price NUMERIC(12, 2),
    is_paid BOOLEAN NOT NULL DEFAULT false,
    is_active BOOLEAN NOT NULL DEFAULT true,

    available_for_role VARCHAR(255) NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT chk_services_price
        CHECK (price IS NULL OR price >= 0),

    CONSTRAINT chk_services_paid_price
        CHECK (is_paid = false OR price > 0)
);

COMMENT ON TABLE services IS 'Каталог услуг маркетплейса MigrationOS.';


CREATE INDEX idx_services_is_active ON services(is_active);


CREATE TABLE service_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    service_id UUID NOT NULL REFERENCES services(id),

    migrant_id UUID REFERENCES migrants(id),
    employer_id UUID REFERENCES employers(id),

    created_by UUID NOT NULL REFERENCES users(id),
    assignee_id UUID REFERENCES users(id),

    status VARCHAR(30) NOT NULL DEFAULT 'draft',
    total_amount NUMERIC(12, 2),

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ,

    CONSTRAINT chk_service_orders_status
        CHECK (status IN ('draft', 'created', 'waiting_payment', 'paid', 'in_progress', 'need_info', 'completed', 'rejected', 'cancelled')),

    CONSTRAINT chk_service_orders_total_amount
        CHECK (total_amount IS NULL OR total_amount >= 0)
);

COMMENT ON TABLE service_orders IS 'Заявки на услуги маркетплейса.';


CREATE INDEX idx_service_orders_service_id ON service_orders(service_id);
CREATE INDEX idx_service_orders_migrant_id ON service_orders(migrant_id);
CREATE INDEX idx_service_orders_employer_id ON service_orders(employer_id);
CREATE INDEX idx_service_orders_created_by ON service_orders(created_by);
CREATE INDEX idx_service_orders_assignee_id ON service_orders(assignee_id);
CREATE INDEX idx_service_orders_status ON service_orders(status);
CREATE INDEX idx_service_orders_created_at ON service_orders(created_at);


-- ============================================================
-- 8. Payments and invoices
-- ============================================================

CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    service_order_id UUID NOT NULL REFERENCES service_orders(id),

    provider VARCHAR(50) NOT NULL,
    provider_payment_id VARCHAR(255) UNIQUE,

    amount NUMERIC(12, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'RUB',

    status VARCHAR(30) NOT NULL DEFAULT 'pending',

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    paid_at TIMESTAMPTZ,

    CONSTRAINT chk_payments_amount
        CHECK (amount > 0),

    CONSTRAINT chk_payments_status
        CHECK (status IN ('pending', 'paid', 'failed', 'cancelled', 'refunded')),

    CONSTRAINT chk_payments_paid_at
        CHECK (status <> 'paid' OR paid_at IS NOT NULL)
);

COMMENT ON TABLE payments IS 'Платежи по заявкам. Источник подтверждения оплаты — payment webhook.';


CREATE INDEX idx_payments_service_order_id ON payments(service_order_id);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_provider_payment_id ON payments(provider_payment_id);


CREATE TABLE invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    service_order_id UUID NOT NULL REFERENCES service_orders(id),

    invoice_number VARCHAR(100) NOT NULL UNIQUE,
    amount NUMERIC(12, 2) NOT NULL,

    status VARCHAR(30) NOT NULL DEFAULT 'created',
    file_id UUID,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT chk_invoices_amount
        CHECK (amount > 0),

    CONSTRAINT chk_invoices_status
        CHECK (status IN ('created', 'paid', 'cancelled', 'expired'))
);

COMMENT ON TABLE invoices IS 'Счета на оплату по заявкам.';


CREATE INDEX idx_invoices_service_order_id ON invoices(service_order_id);
CREATE INDEX idx_invoices_status ON invoices(status);


-- ============================================================
-- 9. RKL checks and risk score
-- ============================================================

CREATE TABLE rkl_checks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    migrant_id UUID NOT NULL REFERENCES migrants(id),

    event_id VARCHAR(255) NOT NULL UNIQUE,
    external_check_id VARCHAR(255) NOT NULL UNIQUE,

    source VARCHAR(50) NOT NULL DEFAULT 'SHERPA_RPA',
    checked_at TIMESTAMPTZ NOT NULL,

    matched BOOLEAN NOT NULL,
    raw_status VARCHAR(255) NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT chk_rkl_checks_source
        CHECK (source = 'SHERPA_RPA')
);

COMMENT ON TABLE rkl_checks IS 'Результаты РКЛ-проверок, полученные от SHERPA RPA.';
COMMENT ON COLUMN rkl_checks.checked_at IS 'Дата проверки. Должна валидироваться на backend: не позже текущего времени.';


CREATE INDEX idx_rkl_checks_migrant_id ON rkl_checks(migrant_id);
CREATE INDEX idx_rkl_checks_event_id ON rkl_checks(event_id);
CREATE INDEX idx_rkl_checks_checked_at ON rkl_checks(checked_at);


CREATE TABLE risk_scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    migrant_id UUID NOT NULL UNIQUE REFERENCES migrants(id),

    score INTEGER NOT NULL,
    level VARCHAR(30) NOT NULL,
    reason JSONB,

    calculated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT chk_risk_scores_score
        CHECK (score BETWEEN 0 AND 100),

    CONSTRAINT chk_risk_scores_level
        CHECK (level IN ('normal', 'attention', 'critical'))
);

COMMENT ON TABLE risk_scores IS 'Текущий риск-статус мигранта.';


CREATE INDEX idx_risk_scores_migrant_id ON risk_scores(migrant_id);
CREATE INDEX idx_risk_scores_level ON risk_scores(level);


-- ============================================================
-- 10. Notifications
-- ============================================================

CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL REFERENCES users(id),

    type VARCHAR(100) NOT NULL,
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,

    status VARCHAR(30) NOT NULL DEFAULT 'created',

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    read_at TIMESTAMPTZ,

    CONSTRAINT chk_notifications_status
        CHECK (status IN ('created', 'sent', 'delivered', 'read', 'failed')),

    CONSTRAINT chk_notifications_read_at
        CHECK (status <> 'read' OR read_at IS NOT NULL)
);

COMMENT ON TABLE notifications IS 'Уведомления пользователей.';


CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_status ON notifications(status);
CREATE INDEX idx_notifications_created_at ON notifications(created_at);


-- ============================================================
-- 11. Chats
-- ============================================================

CREATE TABLE chat_threads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    migrant_id UUID REFERENCES migrants(id),
    employer_id UUID REFERENCES employers(id),
    request_id UUID REFERENCES requests(id),
    service_order_id UUID REFERENCES service_orders(id),

    status VARCHAR(30) NOT NULL DEFAULT 'active',

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT chk_chat_threads_status
        CHECK (status IN ('active', 'closed', 'archived')),

    CONSTRAINT chk_chat_threads_context
        CHECK (
            migrant_id IS NOT NULL
            OR employer_id IS NOT NULL
            OR request_id IS NOT NULL
            OR service_order_id IS NOT NULL
        )
);

COMMENT ON TABLE chat_threads IS 'Диалоги между участниками процесса.';


CREATE INDEX idx_chat_threads_migrant_id ON chat_threads(migrant_id);
CREATE INDEX idx_chat_threads_employer_id ON chat_threads(employer_id);
CREATE INDEX idx_chat_threads_request_id ON chat_threads(request_id);
CREATE INDEX idx_chat_threads_service_order_id ON chat_threads(service_order_id);
CREATE INDEX idx_chat_threads_status ON chat_threads(status);


CREATE TABLE chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    thread_id UUID NOT NULL REFERENCES chat_threads(id),
    sender_id UUID NOT NULL REFERENCES users(id),

    message_text TEXT,
    attachment_file_id UUID,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT chk_chat_messages_content
        CHECK (message_text IS NOT NULL OR attachment_file_id IS NOT NULL)
);

COMMENT ON TABLE chat_messages IS 'Сообщения в чатах.';


CREATE INDEX idx_chat_messages_thread_id ON chat_messages(thread_id);
CREATE INDEX idx_chat_messages_sender_id ON chat_messages(sender_id);
CREATE INDEX idx_chat_messages_created_at ON chat_messages(created_at);


-- ============================================================
-- 12. Audit log
-- ============================================================

CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    actor_user_id UUID NOT NULL REFERENCES users(id),

    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(100) NOT NULL,
    entity_id UUID NOT NULL,

    before_state JSONB,
    after_state JSONB,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE audit_logs IS 'Append-only журнал критичных пользовательских действий.';
COMMENT ON COLUMN audit_logs.before_state IS 'Не должен содержать лишние чувствительные данные без необходимости.';
COMMENT ON COLUMN audit_logs.after_state IS 'Не должен содержать лишние чувствительные данные без необходимости.';


CREATE INDEX idx_audit_logs_actor_user_id ON audit_logs(actor_user_id);
CREATE INDEX idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at);


-- ============================================================
-- 13. Integration log
-- ============================================================

CREATE TABLE integration_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    integration_name VARCHAR(100) NOT NULL,
    event_id VARCHAR(255),

    direction VARCHAR(30) NOT NULL,
    status VARCHAR(50) NOT NULL,

    entity_type VARCHAR(100),
    entity_id UUID,

    payload_hash VARCHAR(255),

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT chk_integration_logs_direction
        CHECK (direction IN ('inbound', 'outbound')),

    CONSTRAINT chk_integration_logs_status
        CHECK (status IN ('received', 'processed', 'validation_error', 'duplicate', 'unmatched', 'failed'))
);

COMMENT ON TABLE integration_logs IS 'Журнал интеграционных событий: webhook, sync, callback.';
COMMENT ON COLUMN integration_logs.payload_hash IS 'Хэш payload. Полный raw payload хранится только при необходимости и с учетом безопасности.';


CREATE INDEX idx_integration_logs_integration_name ON integration_logs(integration_name);
CREATE INDEX idx_integration_logs_event_id ON integration_logs(event_id);
CREATE INDEX idx_integration_logs_status ON integration_logs(status);
CREATE INDEX idx_integration_logs_entity ON integration_logs(entity_type, entity_id);
CREATE INDEX idx_integration_logs_created_at ON integration_logs(created_at);


-- ============================================================
-- End of schema
-- ============================================================
