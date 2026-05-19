# 10 - Scripts Node.js Reutilizaveis - SOAP Educacional

**Versao:** 1.0 | **Data:** 2026-05-19

---

## 1. Autenticacao e Validacao Token

### Funcao autenticar()

`javascript
// arquivo: auth.js
const https = require('https');

function getAuth() {
  const user = process.env.TOTVS_USER;
  const pass = process.env.TOTVS_PASS;
  
  if (!user || !pass) {
    throw new Error('TOTVS_USER e TOTVS_PASS nao definidas');
  }
  
  return Buffer.from(\\:\\).toString('base64');
}

function autenticaAcesso(callback) {
  const auth = getAuth();
  const xml = \<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" 
               xmlns:tot="http://www.totvs.com/IwsBase/">
  <soap:Header/>
  <soap:Body>
    <tot:AutenticaAcesso/>
  </soap:Body>
</soap:Envelope>\;

  const options = {
    hostname: 'associacaoescola200767.rm.cloudtotvs.com.br',
    port: 10207,
    path: '/wsConsultaSQL/IwsBase',
    method: 'POST',
    headers: {
      'Content-Type': 'text/xml; charset=UTF-8',
      'Authorization': \Basic \\,
      'SOAPAction': 'http://www.totvs.com/IwsBase/AutenticaAcesso',
      'Content-Length': Buffer.byteLength(xml)
    }
  };

  const req = https.request(options, (res) => {
    let data = '';
    res.on('data', chunk => data += chunk);
    res.on('end', () => {
      if (res.statusCode === 200) {
        console.log('[AUTH] Autenticacao OK');
        callback(null, true);
      } else {
        callback(new Error(\HTTP \\), false);
      }
    });
  });

  req.on('error', (e) => callback(e, false));
  req.write(xml);
  req.end();
}

module.exports = { autenticaAcesso, getAuth };
`

**Como rodar:**
`ash
export TOTVS_USER="user@escoladofuturo.com.br"
export TOTVS_PASS="senha123456"
node auth.js
`

---

## 2. ReadView com Tratamento de Erro

### Funcao readView()

`javascript
// arquivo: readview.js
const https = require('https');
const { getAuth } = require('./auth');

function readView(dataServerName, filtro, callback) {
  if (!filtro || filtro.trim() === '') {
    return callback(new Error('Filtro nao pode estar vazio'));
  }

  const auth = getAuth();
  const xml = \<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" 
               xmlns:tot="http://www.totvs.com/IwsDataServer/">
  <soap:Header/>
  <soap:Body>
    <tot:ReadView>
      <tot:DataServerName>\</tot:DataServerName>
      <tot:Contexto>CODCOLIGADA=1;CODFILIAL=1;CODNIVELENSINO=1</tot:Contexto>
      <tot:Filtro>\</tot:Filtro>
    </tot:ReadView>
  </soap:Body>
</soap:Envelope>\;

  const options = {
    hostname: 'associacaoescola200767.rm.cloudtotvs.com.br',
    port: 10207,
    path: '/wsDataServer/IwsDataServer',
    method: 'POST',
    headers: {
      'Content-Type': 'text/xml; charset=UTF-8',
      'Authorization': \Basic \\,
      'SOAPAction': 'http://www.totvs.com/IwsDataServer/ReadView',
      'Content-Length': Buffer.byteLength(xml)
    }
  };

  const req = https.request(options, (res) => {
    let data = '';
    res.on('data', chunk => data += chunk);
    res.on('end', () => {
      if (res.statusCode !== 200) {
        return callback(new Error(\HTTP \\));
      }
      
      if (data.includes('<soap:Fault>')) {
        const faultMatch = data.match(/<faultstring>(.*?)<\\/faultstring>/);
        const fault = faultMatch ? faultMatch[1] : 'Erro desconhecido';
        return callback(new Error(\SOAP Fault: \\));
      }

      callback(null, data);
    });
  });

  req.on('error', (e) => callback(e));
  req.write(xml);
  req.end();
}

module.exports = { readView };
`

**Como usar:**
`javascript
const { readView } = require('./readview');

readView('EduContratoData', "SCONTRATO.RA='20101529'", (err, result) => {
  if (err) {
    console.error('Erro:', err.message);
  } else {
    console.log('Resultado:', result);
  }
});
`

---

## 3. SaveRecord - Template Generalizavel

### Funcao saveRecord()

`javascript
// arquivo: saverecord.js
const https = require('https');
const { getAuth } = require('./auth');

function saveRecord(dataServerName, xmlContent, callback) {
  const auth = getAuth();
  
  const envelope = \<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" 
               xmlns:tot="http://www.totvs.com/IwsDataServer/">
  <soap:Header/>
  <soap:Body>
    <tot:SaveRecord>
      <tot:DataServerName>\</tot:DataServerName>
      <tot:Contexto>CODCOLIGADA=1;CODFILIAL=1;CODNIVELENSINO=1</tot:Contexto>
      <tot:XML>
        \
      </tot:XML>
    </tot:SaveRecord>
  </soap:Body>
</soap:Envelope>\;

  const options = {
    hostname: 'associacaoescola200767.rm.cloudtotvs.com.br',
    port: 10207,
    path: '/wsDataServer/IwsDataServer',
    method: 'POST',
    headers: {
      'Content-Type': 'text/xml; charset=UTF-8',
      'Authorization': \Basic \\,
      'SOAPAction': 'http://www.totvs.com/IwsDataServer/SaveRecord',
      'Content-Length': Buffer.byteLength(envelope)
    }
  };

  const req = https.request(options, (res) => {
    let data = '';
    res.on('data', chunk => data += chunk);
    res.on('end', () => {
      if (res.statusCode !== 200) {
        return callback(new Error(\HTTP \\), null);
      }
      
      if (data.includes('<soap:Fault>')) {
        const faultMatch = data.match(/<faultstring>(.*?)<\\/faultstring>/);
        const fault = faultMatch ? faultMatch[1] : 'Erro desconhecido';
        return callback(new Error(\SOAP Fault: \\), null);
      }

      callback(null, data);
    });
  });

  req.on('error', (e) => callback(e, null));
  req.write(envelope);
  req.end();
}

module.exports = { saveRecord };
`

**Como usar:**
`javascript
const { saveRecord } = require('./saverecord');

const xmlSPARCELA = \<SPARCELA>
  <CODCOLIGADA>1</CODCOLIGADA>
  <RA>20101529</RA>
  <CODCONTRATO>7572</CODCONTRATO>
  <SERVICO>MENS</SERVICO>
  <PARCELA>1</PARCELA>
  <COTA>1</COTA>
  <VALOR>1500,00</VALOR>
  <DTVENCIMENTO>2024-02-10</DTVENCIMENTO>
  <DTCOMPETENCIA>2024-02-01</DTCOMPETENCIA>
  <CODCOLCFO>1</CODCOLCFO>
  <CODCFO>1</CODCFO>
</SPARCELA>\;

saveRecord('EduParcelaData', xmlSPARCELA, (err, result) => {
  if (err) {
    console.error('Erro SaveRecord:', err.message);
  } else {
    console.log('Sucesso - IDPARCELA gerado:', result);
  }
});
`

---

## 4. DeleteRecord - Rollback

### Funcao deleteRecordByKey()

`javascript
// arquivo: deleterecord.js
const https = require('https');
const { getAuth } = require('./auth');

function deleteRecordByKey(dataServerName, primaryKey, callback) {
  const auth = getAuth();
  
  const xml = \<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" 
               xmlns:tot="http://www.totvs.com/IwsDataServer/">
  <soap:Header/>
  <soap:Body>
    <tot:DeleteRecordByKey>
      <tot:DataServerName>\</tot:DataServerName>
      <tot:Contexto>CODCOLIGADA=1;CODFILIAL=1;CODNIVELENSINO=1</tot:Contexto>
      <tot:PrimaryKey>\</tot:PrimaryKey>
    </tot:DeleteRecordByKey>
  </soap:Body>
</soap:Envelope>\;

  const options = {
    hostname: 'associacaoescola200767.rm.cloudtotvs.com.br',
    port: 10207,
    path: '/wsDataServer/IwsDataServer',
    method: 'POST',
    headers: {
      'Content-Type': 'text/xml; charset=UTF-8',
      'Authorization': \Basic \\,
      'SOAPAction': 'http://www.totvs.com/IwsDataServer/DeleteRecordByKey',
      'Content-Length': Buffer.byteLength(xml)
    }
  };

  const req = https.request(options, (res) => {
    let data = '';
    res.on('data', chunk => data += chunk);
    res.on('end', () => {
      if (res.statusCode === 200) {
        console.log('[DELETE] OK - PK:', primaryKey);
        callback(null, true);
      } else {
        callback(new Error(\HTTP \\), false);
      }
    });
  });

  req.on('error', (e) => callback(e, false));
  req.write(xml);
  req.end();
}

module.exports = { deleteRecordByKey };
`

**Como usar:**
`javascript
const { deleteRecordByKey } = require('./deleterecord');

// Rollback SPARCELA por IDPARCELA (PK = CODCOLIGADA,IDPARCELA)
deleteRecordByKey('EduParcelaData', '1,54321', (err, success) => {
  if (err) {
    console.error('Erro delete:', err.message);
  } else {
    console.log('Parcela deletada com sucesso');
  }
});
`

---

## 5. BulkSaveRecord - Pool Conexoes

### Funcao bulkSaveRecordParallel()

`javascript
// arquivo: bulksaverecord.js
const https = require('https');
const { getAuth } = require('./auth');

const MAX_PARALLEL = 5;

function bulkSaveRecordParallel(dataServerName, xmlArray, callback) {
  let completed = 0;
  let failed = 0;
  const results = [];
  let currentIndex = 0;

  function processNext() {
    if (currentIndex >= xmlArray.length) {
      if (completed + failed === xmlArray.length) {
        callback(null, { completed, failed, results });
      }
      return;
    }

    if (completed + failed < MAX_PARALLEL) {
      const idx = currentIndex++;
      const xml = xmlArray[idx];

      saveRecordSingle(dataServerName, xml, idx, (err, result) => {
        if (err) {
          failed++;
          results[idx] = { error: err.message };
          console.error(\[\] Erro: \\);
        } else {
          completed++;
          results[idx] = { success: true, data: result };
          console.log(\[\] OK\);
        }
        processNext();
      });

      processNext();
    }
  }

  processNext();
}

function saveRecordSingle(dataServerName, xmlContent, index, callback) {
  const auth = getAuth();
  
  const envelope = \<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" 
               xmlns:tot="http://www.totvs.com/IwsDataServer/">
  <soap:Body>
    <tot:SaveRecord>
      <tot:DataServerName>\</tot:DataServerName>
      <tot:Contexto>CODCOLIGADA=1;CODFILIAL=1;CODNIVELENSINO=1</tot:Contexto>
      <tot:XML>\</tot:XML>
    </tot:SaveRecord>
  </soap:Body>
</soap:Envelope>\;

  const options = {
    hostname: 'associacaoescola200767.rm.cloudtotvs.com.br',
    port: 10207,
    path: '/wsDataServer/IwsDataServer',
    method: 'POST',
    headers: {
      'Content-Type': 'text/xml; charset=UTF-8',
      'Authorization': \Basic \\,
      'SOAPAction': 'http://www.totvs.com/IwsDataServer/SaveRecord',
      'Content-Length': Buffer.byteLength(envelope)
    }
  };

  const req = https.request(options, (res) => {
    let data = '';
    res.on('data', chunk => data += chunk);
    res.on('end', () => {
      if (data.includes('<soap:Fault>')) {
        const faultMatch = data.match(/<faultstring>(.*?)<\\/faultstring>/);
        const fault = faultMatch ? faultMatch[1] : 'Erro desconhecido';
        return callback(new Error(fault));
      }
      callback(null, data);
    });
  });

  req.on('error', (e) => callback(e));
  req.write(envelope);
  req.end();
}

module.exports = { bulkSaveRecordParallel };
`

**Como usar:**
`javascript
const { bulkSaveRecordParallel } = require('./bulksaverecord');

const xmlArray = [
  '<SPARCELA>...',
  '<SPARCELA>...',
  '<SPARCELA>...'
];

bulkSaveRecordParallel('EduParcelaData', xmlArray, (err, result) => {
  console.log(\Completadas: \, Falhadas: \\);
});
`

---

## 6. Cross-Check Pos-Importacao

### Funcao verificaImportacao()

`javascript
// arquivo: crosscheck.js
const { readView } = require('./readview');

function verificaImportacao(dataServerName, filtro, expectedCount, callback) {
  readView(dataServerName, filtro, (err, xmlResult) => {
    if (err) {
      return callback(err);
    }

    const countMatch = xmlResult.match(/<SCONTRATO>|<SPARCELA>|<SBOLSAALUNO>/g);
    const actualCount = countMatch ? countMatch.length : 0;

    console.log(\Esperado: \, Encontrado: \\);

    if (actualCount === expectedCount) {
      callback(null, true);
    } else {
      callback(new Error(\Contagem mismatch: esperado \, encontrado \\), false);
    }
  });
}

module.exports = { verificaImportacao };
`

---

## 7. Log Estruturado em data/audit/

### Funcao logAudit()

`javascript
// arquivo: audit.js
const fs = require('fs');
const path = require('path');

function logAudit(action, dataServerName, result, idGerado) {
  const timestamp = new Date().toISOString();
  const auditDir = path.join(__dirname, '..', 'data', 'audit');
  
  if (!fs.existsSync(auditDir)) {
    fs.mkdirSync(auditDir, { recursive: true });
  }

  const logEntry = {
    timestamp,
    action,
    dataServerName,
    status: result ? 'OK' : 'FAIL',
    idGerado: idGerado || null
  };

  const filename = path.join(auditDir, \\-audit.jsonl\);
  
  fs.appendFileSync(filename, JSON.stringify(logEntry) + '\\n');
  console.log(\[AUDIT] \ \ -> \\);
}

module.exports = { logAudit };
`

---

## 8. Mascarar Credenciais em Log

### Funcao maskSensitiveData()

`javascript
// arquivo: mask.js
function maskSensitiveData(str) {
  // Mascarar JWT
  str = str.replace(/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g, 
    (match) => match.substring(0, 8) + '...' + match.substring(match.length - 4));
  
  // Mascarar CPF
  str = str.replace(/\\d{3}\\.\\d{3}\\.\\d{3}-\\d{2}/g, 'XXX.XXX.XXX-XX');
  
  // Mascarar Basic Auth
  str = str.replace(/Basic [A-Za-z0-9+/=]+/g, 'Basic ****');
  
  return str;
}

module.exports = { maskSensitiveData };
`

---

## 9. Orquestracao Completa

### Script main.js

`javascript
// arquivo: main.js
const { autenticaAcesso } = require('./auth');
const { saveRecord } = require('./saverecord');
const { bulkSaveRecordParallel } = require('./bulksaverecord');
const { logAudit } = require('./audit');

console.log('[INICIO] Migracao TOTVS RM');

autenticaAcesso((err, autenticado) => {
  if (err || !autenticado) {
    console.error('Falha autenticacao');
    process.exit(1);
  }

  // Importar 1 parcela teste
  const xmlParcela = '<SPARCELA>...</SPARCELA>';

  saveRecord('EduParcelaData', xmlParcela, (err, result) => {
    if (err) {
      console.error('Erro SaveRecord:', err.message);
      logAudit('SaveRecord', 'EduParcelaData', false);
      process.exit(1);
    }

    const idParcelaMatch = result.match(/<IDPARCELA>(\\d+)<\\/IDPARCELA>/);
    const idParcela = idParcelaMatch ? idParcelaMatch[1] : null;

    logAudit('SaveRecord', 'EduParcelaData', true, idParcela);
    console.log('[FIM] Migracao OK');
  });
});
`

**Como rodar:**
`ash
export TOTVS_USER="user@escoladofuturo.com.br"
export TOTVS_PASS="senha123456"
node main.js
`

---

## 10. Validacao XML Antes de Envio

### Funcao validateXML()

`javascript
// arquivo: validate.js
const DOMParser = require('@xmldom/xmldom').DOMParser;

function validateXML(xmlString) {
  try {
    const doc = new DOMParser().parseFromString(xmlString);
    
    if (doc.getElementsByTagName('parsererror').length > 0) {
      return { valid: false, error: 'XML invalido' };
    }

    // Validacoes customizadas
    const valor = doc.getElementsByTagName('VALOR')[0];
    if (valor) {
      const text = valor.textContent;
      if (!text.match(/^\\d+,\\d{2}$/)) {
        return { valid: false, error: 'VALOR deve ser NUMERICO(10,4) com virgula' };
      }
    }

    return { valid: true };
  } catch (e) {
    return { valid: false, error: e.message };
  }
}

module.exports = { validateXML };
`

---

## Resumo - Quick Reference

| Tarefa | Arquivo | Funcao |
|--------|---------|--------|
| Autenticar | auth.js | autenticaAcesso() |
| ReadView | readview.js | readView() |
| SaveRecord 1 | saverecord.js | saveRecord() |
| SaveRecord lote | bulksaverecord.js | bulkSaveRecordParallel() |
| DeleteRecord | deleterecord.js | deleteRecordByKey() |
| Audit log | audit.js | logAudit() |
| Mascarar dados | mask.js | maskSensitiveData() |

---

**Proximos:** 11_estrategia_filtro_perfil.md

