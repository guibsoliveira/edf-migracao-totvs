// SmartSaver - SaveRecord no TOTVS RM com auto-correcao de erros conhecidos
// Imita comportamento do agente do Isac: tenta -> erra -> diagnostica -> corrige -> retenta

const https = require('https');
const fs = require('fs');
const path = require('path');

const HOST = 'associacaoescola200767.rm.cloudtotvs.com.br';
const PORT = 10207;
let USER = process.env.TOTVS_USER;
let PASS = process.env.TOTVS_PASS;
if (!USER || !PASS) {
    // Fallback: ler de CLAUDE.local.md (gitignored)
    try {
        const local = fs.readFileSync(path.join(__dirname, '..', 'CLAUDE.local.md'), 'utf8');
        const sec = local.split(/##\s*2\./)[1] || ''; // secao TOTVS
        const u = sec.match(/Usuario:\*\*\s*(\S+)/);
        const p = sec.match(/Senha:\*\*\s*(\S+)/);
        if (u) USER = u[1];
        if (p) PASS = p[1];
    } catch (_) {}
}
if (!USER || !PASS) { console.error('Defina TOTVS_USER/TOTVS_PASS ou preencha CLAUDE.local.md'); process.exit(1); }
const AUTH = 'Basic ' + Buffer.from(USER + ':' + PASS).toString('base64');

function soap(path, action, body) {
    return new Promise(resolve => {
        const xml = `<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tot="http://www.totvs.com/">
<s:Body>${body}</s:Body></s:Envelope>`;
        const o = {
            hostname: HOST, port: PORT, path, method: 'POST',
            headers: {
                'Content-Type': 'text/xml; charset=utf-8',
                'SOAPAction': '"' + action + '"',
                'Content-Length': Buffer.byteLength(xml),
                'Authorization': AUTH
            }
        };
        const req = https.request(o, res => {
            let d = '';
            res.on('data', c => d += c);
            res.on('end', () => resolve({ status: res.statusCode, body: d }));
        });
        req.on('error', e => resolve({ error: e.message }));
        req.write(xml); req.end();
    });
}

function ext(b, t) {
    if (!b) return null;
    const m = b.match(new RegExp(`<([a-z]:)?${t}[^>]*>([\\s\\S]*?)</([a-z]:)?${t}>`, 'i'));
    return m ? m[2] : null;
}
function dec(s) {
    return s.replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&amp;/g, '&').replace(/&#xD;/g, '');
}

// --- Diagnose e auto-fix ---

const DIAGNOSES = [
    {
        match: /Chave duplicada/i,
        type: 'already_exists',
        ok: true, // tratamos como sucesso (registro ja existe)
    },
    {
        match: /Column '([^']+)' does not belong to table/,
        type: 'missing_field_in_xml',
        extract: m => ({ field: m[1] }),
        fix: (xml, ctx, info) => addField(xml, info.field, '0'),
    },
    {
        match: /Contexto informado no XML é diferente do contexto da requisição/i,
        type: 'context_mismatch',
        fix: (xml, ctx) => syncContextToXml(xml, ctx),
    },
    {
        match: /There is no row at position 0/i,
        type: 'missing_child_rows',
        fix: null, // tratar caso a caso
        hint: 'XML precisa de child rows aninhadas',
    },
    {
        match: /Falha ao converver XML para Objeto DataSet/i,
        type: 'invalid_xml_format',
        fix: (xml) => wrapInDataSet(xml),
    },
    {
        match: /ORA-01400/,
        type: 'not_null_violation',
        extract: m => { const c = m.input.match(/"([^"]+)"/g); return { field: c ? c[c.length - 1].replace(/"/g,'') : null }; },
        fix: (xml, ctx, info) => info.field ? addField(xml, info.field, '0') : null,
    },
    {
        match: /ORA-02291/,
        type: 'fk_violation',
        fix: null,
        hint: 'Dependencia FK nao existe - criar antes',
    },
    {
        match: /Classe não encontrada/i,
        type: 'invalid_dataserver',
        fix: null,
        hint: 'Nome do DataServer errado',
    },
    {
        match: /Contexto inválido OU não foram configurados/i,
        type: 'invalid_context',
        fix: (xml, ctx) => ctx.replace(/;?CODSISTEMA=[^;]*/g, ''),
        target: 'context',
        hint: 'Contexto invalido - removendo CODSISTEMA',
    },
];

function diagnose(text) {
    if (!text) return { type: 'no_response' };
    // Checa DIAGNOSES PRIMEIRO (lista positiva de erros conhecidos)
    for (const d of DIAGNOSES) {
        const m = text.match(d.match);
        if (m) {
            const info = d.extract ? d.extract(m) : {};
            return { type: d.type, ok: d.ok || false, fix: d.fix, target: d.target, hint: d.hint, info, raw: text.substring(0, 400) };
        }
    }
    // Stack trace generico = erro desconhecido
    if (text.match(/\bat\s+RM\.|\bat\s+System\.|Exception|fault|=====/i)) {
        return { type: 'unknown_error', raw: text.substring(0, 400) };
    }
    // Sem nada de erro = sucesso
    return { type: 'success' };
}

function addField(xml, field, defaultValue) {
    // Adiciona <FIELD>value</FIELD> antes do </ROOT>
    const rootMatch = xml.match(/<(\w+)>([\s\S]*)<\/\1>\s*$/);
    if (!rootMatch) return null;
    const root = rootMatch[1];
    // Verifica se ja existe
    if (xml.includes(`<${field}>`)) return null;
    return xml.replace(`</${root}>`, `  <${field}>${defaultValue}</${field}>\n</${root}>`);
}

function syncContextToXml(xml, ctx) {
    // Pega CODCOLIGADA, CODFILIAL, CODNIVELENSINO do contexto e tenta sincronizar no XML
    const parts = {};
    ctx.split(';').forEach(p => { const [k, v] = p.split('='); if (k && v) parts[k.trim()] = v.trim(); });
    let fixed = xml;
    let changed = false;
    for (const k of ['CODCOLIGADA', 'CODFILIAL', 'CODNIVELENSINO', 'CODTIPOCURSO']) {
        if (parts[k] && !xml.match(new RegExp(`<${k}>`))) {
            const root = xml.match(/<(\w+)>/)[1];
            fixed = fixed.replace(`<${root}>`, `<${root}>\n  <${k}>${parts[k]}</${k}>`);
            changed = true;
        }
    }
    return changed ? fixed : null; // null = nao consegui fix
}

function wrapInDataSet(xml) {
    // Se for multi-root, embrulha num pseudo DataSet
    if (xml.match(/<\/(\w+)>\s*<(\w+)>/)) {
        return `<NewDataSet>${xml}</NewDataSet>`;
    }
    return xml;
}

// --- Smart Save ---

async function rawSave(ds, xml, ctx) {
    const r = await soap('/wsDataServer/IwsDataServer', 'http://www.totvs.com/IwsDataServer/SaveRecord',
        `<tot:SaveRecord>
<tot:DataServerName>${ds}</tot:DataServerName>
<tot:XML><![CDATA[${xml}]]></tot:XML>
<tot:Contexto>${ctx}</tot:Contexto>
</tot:SaveRecord>`);
    if (!r.body) return { error: r.error || 'no body' };
    const fault = ext(r.body, 'faultstring');
    if (fault) return { fault: dec(fault) };
    const resp = ext(r.body, 'SaveRecordResult');
    if (resp) return { result: dec(resp) };
    return { raw: r.body };
}

async function smartSave(ds, xml, ctx, opts = {}) {
    const maxRetries = opts.maxRetries || 6;
    const attemptLog = [];
    let curXml = xml;
    let curCtx = ctx || 'CODCOLIGADA=1;CODFILIAL=1;CODNIVELENSINO=1';

    for (let i = 0; i < maxRetries; i++) {
        const r = await rawSave(ds, curXml, curCtx);
        const text = r.result || r.fault || r.raw || '';
        const diag = diagnose(text);
        attemptLog.push({ attempt: i + 1, diag: diag.type, hint: diag.hint, info: diag.info });

        // Sucesso explicito
        if (diag.type === 'success') {
            return { ok: true, attempts: i + 1, log: attemptLog, response: text.substring(0, 300) };
        }
        // Ja existe = sucesso
        if (diag.type === 'already_exists') {
            return { ok: true, existed: true, attempts: i + 1, log: attemptLog };
        }
        // Tem fix automatico
        if (diag.fix) {
            const target = diag.target || 'xml';
            const fixed = diag.fix(curXml, curCtx, diag.info);
            if (!fixed) {
                return { ok: false, reason: 'no_fix_available', diag, log: attemptLog };
            }
            if (target === 'context') {
                curCtx = fixed;
            } else {
                curXml = fixed;
            }
            continue;
        }
        // Sem fix: retorna o erro
        return { ok: false, reason: diag.type, hint: diag.hint, log: attemptLog, raw: diag.raw };
    }
    return { ok: false, reason: 'max_retries_exhausted', log: attemptLog };
}

// ReadView util
async function rv(ds, filtro, ctx) {
    ctx = ctx || 'CODCOLIGADA=1;CODFILIAL=1;CODNIVELENSINO=1';
    const r = await soap('/wsDataServer/IwsDataServer', 'http://www.totvs.com/IwsDataServer/ReadView',
        `<tot:ReadView><tot:DataServerName>${ds}</tot:DataServerName><tot:Filtro>${filtro}</tot:Filtro><tot:Contexto>${ctx}</tot:Contexto></tot:ReadView>`);
    if (!r.body) return { error: 'no body' };
    const fault = ext(r.body, 'faultstring');
    if (fault) return { fault: dec(fault) };
    const v = ext(r.body, 'ReadViewResult');
    return { xml: v ? dec(v) : null };
}

// Conta ocorrencias de uma tabela no XML, case-insensitive (root vem PascalCase: SCurso, FCfo, etc)
function countTable(xml, table) {
    if (!xml || !table) return 0;
    const re = new RegExp(`<${table}>`, 'gi');
    return (xml.match(re) || []).length;
}

// Extrai todos os registros de uma tabela como array de objetos {campo: valor}
function extractRows(xml, table) {
    if (!xml || !table) return [];
    const re = new RegExp(`<${table}>([\\s\\S]*?)</${table}>`, 'gi');
    const rows = [];
    let m;
    while ((m = re.exec(xml)) !== null) {
        const obj = {};
        const fieldRe = /<([A-Z][A-Z0-9_]+)>([\s\S]*?)<\/\1>/g;
        let f;
        while ((f = fieldRe.exec(m[1])) !== null) obj[f[1]] = f[2];
        rows.push(obj);
    }
    return rows;
}

module.exports = { smartSave, rv, rawSave, diagnose, countTable, extractRows };

// Self-test se rodado diretamente
if (require.main === module) {
    (async () => {
        console.log('=== SmartSaver self-test ===\n');

        // Teste: SPLETIVO 2022 (ja existe, deve retornar "already_exists" como sucesso)
        const r1 = await smartSave('EduPLetivoData', `<SPLETIVO>
  <CODCOLIGADA>1</CODCOLIGADA>
  <CODFILIAL>1</CODFILIAL>
  <CODTIPOCURSO>1</CODTIPOCURSO>
  <CODPERLET>2022</CODPERLET>
  <DESCRICAO>2022</DESCRICAO>
  <ENCERRADO>N</ENCERRADO>
  <DTINICIO>2022-01-01T00:00:00</DTINICIO>
  <DTPREVISTA>2022-12-31T00:00:00</DTPREVISTA>
  <EXIBIRPORTAL>S</EXIBIRPORTAL>
  <EXIBIRPORTALALUNO>S</EXIBIRPORTALALUNO>
</SPLETIVO>`);
        console.log('SPLETIVO 2022 Filial 1:', JSON.stringify(r1, null, 2));

        // Teste: SPLETIVO 2022 Filial 2 (novo, deve criar)
        const r2 = await smartSave('EduPLetivoData', `<SPLETIVO>
  <CODCOLIGADA>1</CODCOLIGADA>
  <CODFILIAL>2</CODFILIAL>
  <CODTIPOCURSO>1</CODTIPOCURSO>
  <CODPERLET>2022</CODPERLET>
  <DESCRICAO>2022</DESCRICAO>
  <ENCERRADO>N</ENCERRADO>
  <DTINICIO>2022-01-01T00:00:00</DTINICIO>
  <DTPREVISTA>2022-12-31T00:00:00</DTPREVISTA>
  <EXIBIRPORTAL>S</EXIBIRPORTAL>
  <EXIBIRPORTALALUNO>S</EXIBIRPORTALALUNO>
</SPLETIVO>`, 'CODCOLIGADA=1;CODFILIAL=2;CODNIVELENSINO=1');
        console.log('SPLETIVO 2022 Filial 2:', JSON.stringify(r2, null, 2));

        // Teste 3: SHABILITACAOFILIAL EF2-8-UN1-2022
        const r3 = await smartSave('EduHabilitacaoFilialData', `<SHABILITACAOFILIAL>
  <CODCOLIGADA>1</CODCOLIGADA>
  <CODFILIAL>1</CODFILIAL>
  <CODTIPOCURSO>1</CODTIPOCURSO>
  <CODCURSO>EF2</CODCURSO>
  <CODHABILITACAO>8</CODHABILITACAO>
  <CODGRADE>2022</CODGRADE>
  <CODTURNO>Integral</CODTURNO>
  <ATIVO>S</ATIVO>
</SHABILITACAOFILIAL>`);
        console.log('SHABILITACAOFILIAL EF2-8-UN1-2022:', JSON.stringify(r3, null, 2));
    })();
}
