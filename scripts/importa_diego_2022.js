// Orquestrador: importa toda estrutura Diego 2022 seguindo roadmap
// Le views export.* e faz SaveRecord usando SmartSaver
const { smartSave, rv, rawSave } = require('./smart_saver.js');
const { exec } = require('child_process');

// Credenciais via env (DB_HOST, DB_USER, DB_PASS) - ver CLAUDE.local.md (gitignored)
const PSQL_BIN = process.env.PSQL_BIN || '"C:\\Program Files\\PostgreSQL\\18\\bin\\psql.exe"';
const DB_HOST = process.env.DB_HOST || '192.168.1.91';
const DB_USER = process.env.DB_USER || 'postgres';
const DB_PASS = process.env.DB_PASS || (() => {
    try { return require('fs').readFileSync(require('path').join(__dirname, '..', 'CLAUDE.local.md'), 'utf8').match(/Password:\*\*\s*(\S+)/)[1]; }
    catch { console.error('Defina DB_PASS ou preencha CLAUDE.local.md'); process.exit(1); }
})();
const PSQL = `${PSQL_BIN} -h ${DB_HOST} -U ${DB_USER} -d Edf_bd_legado`;
const ENV = `PGCLIENTENCODING=LATIN1 PGPASSWORD=${DB_PASS} `;

function psql(q) {
    return new Promise(resolve => {
        const cmd = `${ENV}${PSQL} -c "${q.replace(/"/g, '\\"')}"`;
        exec(cmd, { maxBuffer: 100 * 1024 * 1024, shell: 'bash' }, (e, out) => {
            resolve(out || (e ? e.message : ''));
        });
    });
}

function psqlJSON(q) {
    return new Promise(resolve => {
        const cmd = `${ENV}${PSQL} -A -F"|" -t -c "${q.replace(/"/g, '\\"')}"`;
        exec(cmd, { maxBuffer: 100 * 1024 * 1024, shell: 'bash' }, (e, out) => {
            if (!out) return resolve([]);
            const rows = out.trim().split('\n').filter(l => l.length > 0).map(l => l.split('|'));
            resolve(rows);
        });
    });
}

const STATUS = [];
function log(step, name, status, details) {
    STATUS.push({ step, name, status, details });
    const icon = status === 'OK' ? '✓' : status === 'EXISTS' ? '·' : status === 'SKIP' ? '~' : '✗';
    console.log(`${icon} [${step}] ${name.padEnd(28)} ${status} ${details || ''}`);
}

(async () => {
    console.log('\n=== IMPORTACAO SISTEMATICA Diego 2022 (RA 20142166, EF2-8-UN1) ===\n');

    // Step 1: SCURSO EF2
    {
        const xml = `<SCurso>
  <CODCOLIGADA>1</CODCOLIGADA>
  <CODCURSO>EF2</CODCURSO>
  <NOME>Ensino Fundamental II</NOME>
  <CODTIPOCURSO>1</CODTIPOCURSO>
</SCurso>`;
        const r = await smartSave('EduCursoData', xml);
        log('3', 'SCURSO EF2', r.existed ? 'EXISTS' : (r.ok ? 'OK' : 'FAIL'), r.reason || '');
    }

    // Step 2: SHABILITACAO 8
    {
        const xml = `<SHabilitacao>
  <CODCOLIGADA>1</CODCOLIGADA>
  <CODCURSO>EF2</CODCURSO>
  <CODHABILITACAO>8</CODHABILITACAO>
  <NOME>8 Ano</NOME>
</SHabilitacao>`;
        const r = await smartSave('EduHabilitacaoData', xml);
        log('4', 'SHABILITACAO 8', r.existed ? 'EXISTS' : (r.ok ? 'OK' : 'FAIL'), r.reason || '');
    }

    // Step 3: SPLETIVO 2022
    {
        const xml = `<SPLETIVO>
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
</SPLETIVO>`;
        const r = await smartSave('EduPLetivoData', xml);
        log('5', 'SPLETIVO 2022', r.existed ? 'EXISTS' : (r.ok ? 'OK' : 'FAIL'), r.reason || '');
    }

    // Step 4: SGRADE EF2-8-2022
    {
        const xml = `<SGrade>
  <CODCOLIGADA>1</CODCOLIGADA>
  <CODCURSO>EF2</CODCURSO>
  <CODHABILITACAO>8</CODHABILITACAO>
  <CODGRADE>2022</CODGRADE>
  <DESCRICAO>8 Ano</DESCRICAO>
  <STATUS>0</STATUS>
  <REGIME>S</REGIME>
</SGrade>`;
        const r = await smartSave('EduGradeData', xml);
        log('14', 'SGRADE EF2-8-2022', r.existed ? 'EXISTS' : (r.ok ? 'OK' : 'FAIL'), r.reason || '');
    }

    // Step 5: SHABILITACAOFILIAL EF2-8-UN1-2022 (provavelmente IDHABFIL=24 ja)
    {
        const xml = `<SHabilitacaoFilial>
  <CODCOLIGADA>1</CODCOLIGADA>
  <CODFILIAL>1</CODFILIAL>
  <CODTIPOCURSO>1</CODTIPOCURSO>
  <CODCURSO>EF2</CODCURSO>
  <CODHABILITACAO>8</CODHABILITACAO>
  <CODGRADE>2022</CODGRADE>
  <CODTURNO>4</CODTURNO>
  <CODCCUSTO>0000000001</CODCCUSTO>
  <ATIVO>S</ATIVO>
</SHabilitacaoFilial>`;
        const r = await smartSave('EduHabilitacaoFilialData', xml);
        log('17', 'SHABILITACAOFILIAL EF2-8-2022', r.existed ? 'EXISTS (IDHABFIL=24)' : (r.ok ? 'OK' : 'FAIL'), r.reason || '');
    }

    // Step 6: STURMA 8A 2022
    {
        const xml = `<STurma>
  <CODCOLIGADA>1</CODCOLIGADA>
  <CODFILIAL>1</CODFILIAL>
  <CODTIPOCURSO>1</CODTIPOCURSO>
  <CODCURSO>EF2</CODCURSO>
  <CODHABILITACAO>8</CODHABILITACAO>
  <CODGRADE>2022</CODGRADE>
  <CODTURNO>4</CODTURNO>
  <CODPERLET>2022</CODPERLET>
  <CODTURMA>8A</CODTURMA>
  <NOME>8A</NOME>
  <NOMERED>8A</NOMERED>
  <MAXALUNOS>9999</MAXALUNOS>
</STurma>`;
        const r = await smartSave('EduTurmaData', xml);
        log('22', 'STURMA 8A 2022', r.existed ? 'EXISTS' : (r.ok ? 'OK' : 'FAIL'), r.reason || '');
    }

    // Step 7: STURMADISC x 13 disciplinas
    const disciplinas = await psqlJSON(`SELECT \"CODDISC\" FROM export.sturmadisc WHERE \"CODTURMA\"='8A' AND \"CODPERLET\"='2022' ORDER BY \"CODDISC\"::int`);
    let okDisc = 0, failDisc = 0;
    for (const [codDisc] of disciplinas) {
        const xml = `<STurmaDisc>
  <CODCOLIGADA>1</CODCOLIGADA>
  <CODFILIAL>1</CODFILIAL>
  <CODTIPOCURSO>1</CODTIPOCURSO>
  <CODCURSO>EF2</CODCURSO>
  <CODHABILITACAO>8</CODHABILITACAO>
  <CODGRADE>2022</CODGRADE>
  <CODTURNO>4</CODTURNO>
  <CODPERLET>2022</CODPERLET>
  <CODTURMA>8A</CODTURMA>
  <CODDISC>${codDisc}</CODDISC>
  <MAXALUNOS>101</MAXALUNOS>
</STurmaDisc>`;
        const r = await smartSave('EduTurmaDiscData', xml);
        if (r.ok) okDisc++; else failDisc++;
    }
    log('23', 'STURMADISC x ' + disciplinas.length, okDisc === disciplinas.length ? 'OK' : 'PARTIAL', `${okDisc}/${disciplinas.length} OK, ${failDisc} fail`);

    // Step 8: SHABILITACAOALUNO Diego 2022 (ja criada antes mas testa de novo)
    {
        const xml = `<SHabilitacaoAluno>
  <CODCOLIGADA>1</CODCOLIGADA>
  <IDHABILITACAOFILIAL>24</IDHABILITACAOFILIAL>
  <CODCURSO>EF2</CODCURSO>
  <CODHABILITACAO>8</CODHABILITACAO>
  <CODGRADE>2022</CODGRADE>
  <TURNO>Integral</TURNO>
  <CODFILIAL>1</CODFILIAL>
  <CODTIPOCURSO>1</CODTIPOCURSO>
  <RA>20142166</RA>
  <STATUS>Concluido</STATUS>
</SHabilitacaoAluno>`;
        const r = await smartSave('EduHabilitacaoAlunoData', xml);
        log('29', 'SHABILITACAOALUNO Diego 2022', r.existed ? 'EXISTS' : (r.ok ? 'OK' : 'FAIL'), r.reason || '');
    }

    // Resumo
    console.log('\n=== RESUMO ===');
    const okCount = STATUS.filter(s => s.status === 'OK' || s.status === 'EXISTS').length;
    const failCount = STATUS.filter(s => s.status === 'FAIL').length;
    console.log(`Sucessos: ${okCount}/${STATUS.length}, Falhas: ${failCount}`);

    if (failCount > 0) {
        console.log('\nFALHAS:');
        STATUS.filter(s => s.status === 'FAIL').forEach(s => {
            console.log(`  [${s.step}] ${s.name}: ${s.details}`);
        });
    }
})().catch(e => console.error('FATAL:', e.message));
