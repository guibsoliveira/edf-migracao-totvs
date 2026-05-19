-- =====================================================================
-- gennera_stg.item_to_sservico — mapeia cada item Gennera para 1 dos
-- 4 SSERVICOs genéricos do TOTVS (ou 'Variável' para itens diversos)
-- =====================================================================
-- Estratégia: usar categoria do Gennera (mais confiável) primeiro,
-- depois regex na descrição como fallback ou para distinguir
-- 1ª Mensalidade vs Mensalidade regular.
--
-- Categorias Gennera mapeadas:
--   Mensalidade UN1/UN2/-PS, Matrícula -PS → distinguir por padrão "1º MENS"
--   Materiais / Materiais UN2 / Material Didático -TX → Material Didático
--   Alimentação / Alimentação UN2                    → Alimentação
--   Variável / Atividades Extras / Taxas Diversas    → Variável
-- =====================================================================

CREATE OR REPLACE VIEW gennera_stg.item_to_sservico AS
SELECT
    ai.id_item,
    ai.id_institution,
    ai.description,
    ai.price,
    ai.item_category_name,
    CASE
        -- Material Didático (categoria explícita)
        WHEN ai.item_category_name ILIKE '%material%'
          OR ai.item_category_name ILIKE '%materia%'
          OR ai.item_category_name ILIKE 'Materiais%'
            THEN 'Material Didático'

        -- Alimentação (categoria explícita)
        WHEN ai.item_category_name ILIKE 'Aliment%'
            THEN 'Alimentação'

        -- Mensalidade / 1ª Mensalidade (categoria de cobrança)
        WHEN ai.item_category_name ILIKE 'Mensalidade%'
          OR ai.item_category_name ILIKE 'Matrícula%'
          OR ai.item_category_name ILIKE 'Matricula%'
        THEN
            CASE
                -- Padrão "1º MENS" / "1ª MENS" / "1aMENS"
                WHEN ai.description ~* '(^|\s)1\s*[º°.ª]?\s*(MENS|PARC|MEN)' THEN '1ª mensalidade'
                WHEN ai.description ~* '\b(rematr|matr[íi]cula)\b'           THEN '1ª mensalidade'
                ELSE 'Mensalidade'
            END

        -- Categorias legadas (Atividades Extras - PS, etc) usam descrição
        -- com sufixo "(Alimentação)" / "(Mensalidade)" / "(Material...)"
        WHEN ai.description ~* '\(\s*alimenta'                    THEN 'Alimentação'
        WHEN ai.description ~* '\(\s*1[ªa]\s*mensalidade'         THEN '1ª mensalidade'
        WHEN ai.description ~* '\(\s*mensalidade\s*\)'            THEN 'Mensalidade'
        WHEN ai.description ~* '\(\s*material'                    THEN 'Material Didático'
        WHEN ai.description ~* '\(\s*livro'                       THEN 'Material Didático'
        WHEN ai.description ~* 'material\s*did'                   THEN 'Material Didático'

        -- Resto (Variável / Atividades Extras / Taxas Diversas)
        ELSE 'Variável'
    END AS sservico_nome
FROM gennera_stg.api_items ai;
