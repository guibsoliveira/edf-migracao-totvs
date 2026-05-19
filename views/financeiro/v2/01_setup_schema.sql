-- =====================================================================
-- export_v2 — schema paralelo para nova estrutura SSERVICO genérica
-- =====================================================================
-- Mantém o schema export atual intacto.
-- Quando aprovado, dropamos export.* e renomeamos export_v2 -> export.
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS export_v2;

-- ===== Tabela auxiliar: snapshot dos /items da API Gennera =====
-- Carregada via Node script (carga inicial + refresh manual)
CREATE TABLE IF NOT EXISTS gennera_stg.api_items (
    id_item               integer       NOT NULL,
    id_institution        integer       NOT NULL,
    description           text,
    type                  text,
    period                integer,
    price                 numeric(12,2),
    status                text,
    id_item_category      integer,
    item_category_name    text,
    created_at            timestamptz,
    updated_at            timestamptz,
    snapshot_at           timestamptz   DEFAULT now(),
    PRIMARY KEY (id_item, id_institution)
);

CREATE INDEX IF NOT EXISTS idx_api_items_desc ON gennera_stg.api_items (description);
CREATE INDEX IF NOT EXISTS idx_api_items_inst ON gennera_stg.api_items (id_institution);
