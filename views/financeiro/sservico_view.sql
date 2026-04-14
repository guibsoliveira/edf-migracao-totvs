CREATE OR REPLACE VIEW export.sservico AS
WITH por_aluno AS (
    SELECT
        TRIM(sh.item)                                                           AS item,
        sh.id_pessoa,
        sh.fatura_ano,
        SUM(
            REPLACE(REPLACE(REPLACE(TRIM(sh.valor_bruto),'$',''),'.',''),',','.')::numeric(10,4)
        )                                                                       AS valor_aluno
    FROM gennera_stg.servicos_historico sh
    WHERE (
           sh.item ~* '(MENSALIDADE|ALIMENTA|MATERIAIS|MAT\s+DIDAT|MDIDAT|MDIAT|MD\s+20[0-9]{2}|ANUIDADE)'
        OR sh.item ~* '\mMENS\M'
        OR sh.item ~* '\mANUID\M'
        OR sh.item ~* '1[^[:space:]]{0,3}\s*(PARC|MENS)'
    )
      AND sh.valor_bruto IS NOT NULL
      AND TRIM(sh.valor_bruto) NOT IN ('$0,00', '', '0', '0,00')
      AND sh.calendario_academico IS NOT NULL
      AND TRIM(sh.calendario_academico) >= '2021'
    GROUP BY TRIM(sh.item), sh.id_pessoa, sh.fatura_ano
)
SELECT
    1                                                               AS "CODCOLIGADA",
    LEFT(pa.item, 60)::character varying(60)                       AS "NOME",
    (mode() WITHIN GROUP (ORDER BY pa.valor_aluno))::numeric(10,4) AS "VALOR",
    1                                                              AS "CODTIPOCURSO",
    -- Caixa única da Escola do Futuro (Bradesco, coligada 1)
    1                                                              AS "CODCOLCXA",
    '237'::character varying(10)                                   AS "CODCXA",
    'N'::character varying(1)                                      AS "VERIFICAINADIMPLENCIA",
    NULL::integer                                                  AS "TIPOCONTABILLAN",
    NULL::character varying(10)                                    AS "CODTDO",
    -- Natureza financeira única já cadastrada no TOTVS (coligada 1)
    1                                                              AS "CODCOLNATFINANCEIRA",
    '111.111'::character varying(40)                               AS "NATFINANCEIRA",
    'N'::character varying(1)                                      AS "PERMITEACORDO",
    NULL::character varying(1)                                     AS "APROVEITACONTACORRENTE",
    NULL::character varying(1)                                     AS "CONSIDERAPARCELAFIXA",
    NULL::character varying(1)                                     AS "DISPONIVELEXTENSAO",
    NULL::character varying(1)                                     AS "DESCONSIDERACREDITORETROATIVO",
    -- Escola aceita cartão de débito e crédito
    'S'::character varying(1)                                      AS "PGCARTAODEBITO",
    'S'::character varying(1)                                      AS "PGCARTAOCREDITO",
    NULL::character varying(1)                                     AS "CONSIDERADESCANTECIPACAO"
FROM por_aluno pa
GROUP BY pa.item
ORDER BY pa.item;
