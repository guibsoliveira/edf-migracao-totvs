CREATE OR REPLACE VIEW export.setapas AS
WITH etapas (codetapa, descricao) AS (
    VALUES
        (1, '1' || U&'\00BA' || ' Trimestre'::text),
        (2, '2' || U&'\00BA' || ' Trimestre'::text),
        (3, '3' || U&'\00BA' || ' Trimestre'::text),
        (4, 'Recupera' || U&'\00E7' || U&'\00E3' || 'o Anual'::text)
)
SELECT
    COALESCE(sd."CODCOLIGADA", s."CODCOLIGADA")                     AS "CODCOLIGADA",
    s."CODCURSO",
    s."CODHABILITACAO",
    s."CODGRADE",
    s."TURNO",
    s."CODFILIAL",
    s."CODTIPOCURSO",
    s."CODPERLET",
    sd."CODTURMA",
    sd."CODDISC",
    e.codetapa                                                      AS "CODETAPA",
    'N'::character varying(1)                                       AS "TIPOETAPA",
    e.descricao::character varying(60)                              AS "DESCRICAO",
    NULL::numeric                                                   AS "PONTDIST",
    NULL::numeric                                                   AS "MEDIA",
    NULL::numeric                                                   AS "FREQMIN",
    NULL::date                                                      AS "DTINICIO",
    NULL::date                                                      AS "DTFIM",
    NULL::date                                                      AS "DTINICIODIGITACAO",
    NULL::date                                                      AS "DTLIMITEDIGITACAO",
    'N'::character varying(1)                                       AS "DIGAULASDADAS",
    (COALESCE(sp."EXIBIRPORTAL", 'S'::text))::character varying(1)  AS "EXIBENANWEB",
    'N'::character varying(1)                                       AS "ETAPAFINAL",
    NULL::text                                                      AS "TITULO",
    NULL::integer                                                   AS "AULASDADAS",
    NULL::integer                                                   AS "AULASPREVISTAS",
    NULL::character varying(1)                                      AS "CONCEITOGRAFICO",
    NULL::character varying(1)                                      AS "EXIBENOGRAFICO",
    NULL::date                                                      AS "DTLIMITECONTPREVISTO",
    NULL::date                                                      AS "DTLIMITECONTEFETIVO",
    NULL::character varying(1)                                      AS "DISPONIVELALUNOS",
    NULL::character varying(1)                                      AS "ETAPAENCERRADA"
FROM (
    (export.sturmadisc sd
        JOIN export.sturma s
            ON (    s."CODTURMA" = (sd."CODTURMA")::text
                AND s."CODPERLET" = sd."CODPERLET"    ))
        LEFT JOIN export.spletivo sp
            ON (sp."CODPERLET" = s."CODPERLET")
)
CROSS JOIN etapas e;
