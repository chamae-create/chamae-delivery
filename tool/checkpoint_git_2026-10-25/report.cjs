const fs = require('fs');
const path = require('path');
const cp = require('child_process');
const root = 'tool/checkpoint_git_2026-10-25';
const report = 'docs/CHECKPOINT-GIT-PRE-HOMOLOGACAO-2026-10-25.md';
const data = JSON.parse(fs.readFileSync(`${root}/inventory-before.json`, 'utf8'));
const cleanText = p => { const b = fs.readFileSync(p); return b[0] === 255 && b[1] === 254 ? b.subarray(2).toString('utf16le') : b.toString('utf8'); };
const analyze = cleanText(`${root}/flutter-analyze.log`);
const flutter = cleanText(`${root}/flutter-test.log`);
const functions = cleanText(`${root}/functions-test.log`);
for (const name of ['flutter-analyze', 'flutter-test', 'functions-test']) {
  if (cleanText(`${root}/${name}-exit.txt`).trim() !== '0') throw Error(`Failed validation: ${name}`);
}
if (!/No issues found/.test(analyze) || !/\+209: All tests passed!/.test(flutter) || !/pass 414/.test(functions) || !/fail 0/.test(functions)) throw Error('Unexpected test totals');
const groups = {A:'código funcional e configuração versionável',B:'testes e fixtures',C:'documentação',D:'assets visuais do produto',E:'Android/iOS nativo',F:'arquivos gerados',G:'arquivos locais fora do checkpoint',H:'sensíveis/credenciais',I:'inclusão duvidosa ou pendente de revisão'};
const nativeGenerated = new Set(['android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java','ios/Runner/GeneratedPluginRegistrant.m']);
function classify(entry) {
  const p = entry.path;
  let group, also='', include=true, reason;
  if (p === 'android/local.properties') { group='G';also='F';include=false;reason='Configuração da máquina já rastreada; não incluir este diff.'; }
  else if (nativeGenerated.has(p)) { group='F';also='E';include=false;reason='Autogerado, já rastreado apesar do ignore; regenerável pelo Flutter.'; }
  else if (data.summary.noSubstantive.includes(p)) { group='A';also='I';include=false;reason='Status M sem diff substantivo; normalização/estatística do Git, sem mudança a selecionar.'; }
  else if (p.startsWith('tool/')) { group='G';also='F';include=false;reason='Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint.'; if (/\.(ps1|dart)$/.test(p)) { group='I';also='G';reason='Harness/captura de ensaio; caminhos locais ou fixtures históricas. Revisar separadamente.'; } }
  else if (p.startsWith('docs/') && /\.(png|mp4)$/i.test(p)) { group='I';also='D/F';include=false;reason='Evidência visual não revisada individualmente para PII/metadados nesta tarefa; manter local.'; }
  else if (p.startsWith('docs/') && /\.txt$/i.test(p)) { group='G';also='F';include=false;reason='Log/marcador de captura ou dispositivo; preservar local, sem inclusão.'; }
  else if (p.startsWith('docs/') && /\.(json|html)$/i.test(p)) { group='I';also='C/F';include=false;reason='Inventário/validação/comparação gerada de captura; revisão de metadados pendente.'; }
  else if (p.startsWith('docs/') || p.startsWith('design/')) { group='C';reason='Relatório, diretriz ou manifesto de referências oficiais, sem credencial privada detectada.'; }
  else if (p.startsWith('test/') || p.startsWith('functions/test/') || /^firebase\..*-test\.json$/.test(p)) { group='B';reason='Teste/fixture ou configuração de emulador loopback, necessária à reprodução local.'; }
  else if (p.startsWith('assets/')) { group='D';reason='Asset usado pelo produto e declarado no pubspec; inspecionado visualmente, sem dados pessoais aparentes.'; }
  else if (p.startsWith('android/') || p.startsWith('ios/')) { group='E';reason=p.endsWith('.example') ? 'Template de assinatura com campos vazios; não é o key.properties real.' : /\.png$/.test(p) ? 'Imagem nativa de splash referenciada pelos recursos XML; preservar junto dos temas.' : 'Configuração/recursos nativos do produto; preservar junto do splash/assinatura.';if (/\.png$/.test(p)) also='D'; }
  else { group='A';reason='Código/regra/configuração funcional, necessário ao conjunto acumulado.'; }
  return {...entry,group,also,include,reason,bytes:fs.statSync(p).size};
}
const rows=data.status.map(classify).sort((a,b)=>a.path.localeCompare(b.path));
const include=rows.filter(r=>r.include),exclude=rows.filter(r=>!r.include);
fs.writeFileSync(`${root}/classification.json`,JSON.stringify(rows,null,2));
fs.writeFileSync(`${root}/include-paths.txt`,[...include.map(r=>r.path),report].sort().join('\n')+'\n');
fs.writeFileSync(`${root}/exclude-paths.txt`,exclude.map(r=>r.path).join('\n')+'\n');
const counts=Object.fromEntries(Object.keys(groups).map(k=>[k,rows.filter(r=>r.group===k).length]));
const line = r => `| ${r.status === '??' ? 'NOVO' : 'M'} | \`${r.path}\` | ${r.group}${r.also ? ' ('+r.also+')' : ''} | ${r.include ? 'INCLUIR' : 'EXCLUIR'} | ${r.reason} |`;
const preservation=JSON.parse(fs.readFileSync(`${root}/preservation.json`,'utf8'));
if (preservation.changedSinceAudit.length || preservation.stagedNames) throw Error('Unexpected source or index changes');
const localArtifacts=fs.readdirSync(root).sort();
const text=`# Checkpoint Git pré-homologação — 25/10/2026

## WORKTREE

Repositório: C:\\Users\\DELL\\chamae_delivery. Branch **${data.summary.branch}**, HEAD local **${data.summary.head}**.
Auditoria/preparação apenas; nenhum commit, staging, push, deploy ou acesso a produção.
Alterações anteriores preservadas. Nenhum reset, checkout, restore, descarte,
remoção de arquivo ou desrastreamento foi executado. O relatório não homologa
operação real, Google Play, provedores, estoque físico ou iOS.

Antes de criar qualquer arquivo desta tarefa foram executados os quatro comandos
abaixo. Saídas iniciais integrais, incluindo avisos de finais de linha, estão
registradas localmente em \`${root}/\`:

| Comando executado | Registro local | Resultado inicial |
| --- | --- | --- |
| git status --short | git-status-short.txt | **61 modificados**, diretórios novos compactados no formato short; índice vazio. |
| git diff --stat | git-diff-stat.txt | **57 arquivos com diff**, 2717 inserções e 1504 remoções. Não contabiliza arquivos novos. |
| git diff --name-status | git-diff-name-status.txt | 57 modificados com diff substantivo. |
| git ls-files --others --exclude-standard | git-untracked.txt | **282 arquivos novos** detalhados por caminho. |

Inventário expandido complementar: **343 arquivos** (61 M + 282 novos), sem staged,
renomeados ou excluídos. Quatro entradas M não apresentam diff substantivo; não
foram normalizadas ou restauradas. Avisos LF/CRLF não motivaram mudança de conteúdo.
Os totais são anteriores ao relatório e aos artefatos locais desta própria auditoria.

## ARQUIVOS MODIFICADOS

As 61 entradas M constam integralmente no inventário ao fim deste relatório.
As quatro entradas sem diff substantivo são:

${data.summary.noSubstantive.map(p=>'- `'+p+'`').join('\n')}

## ARQUIVOS NOVOS

As 282 entradas NOVO constam integralmente no mesmo inventário. Há módulos de
backend/cliente, testes/fixtures, documentação, assets necessários ao produto,
e grande volume de backups/capturas que não deve ser incluído por seleção ampla.
Este relatório é um novo arquivo C, recomendado para inclusão após revisão.
Os arquivos produzidos agora sob \`${root}/\` são F/G, locais e excluídos da proposta.

## CLASSIFICAÇÃO A–I

Grupo principal exclusivo para contagem; grupos secundários aparecem entre
parênteses por linha (ex.: F/E para registrantes nativos gerados). H é examinado
também fora dos candidatos versionáveis, sem abrir arquivos de segredo.

| Grupo | Significado | Quantidade inicial |
| --- | --- | ---: |
${Object.entries(groups).map(([k,v])=>`| ${k} | ${v} | ${counts[k]} |`).join('\n')}

O grupo H tem zero candidatos versionáveis, mas existe um arquivo sensível
local ignorado, \`android/key.properties\`, tratado explicitamente abaixo.

## ARQUIVOS A INCLUIR

**${include.length} arquivos do inventário inicial**, mais este relatório:
${include.length+1} caminhos propostos. Cada caminho tem decisão INCLUIR no inventário.
Lista exata auxiliar: \`${root}/include-paths.txt\`; não é script de staging.

- A: app, Functions, Rules, configuração de frete inicial inativa e configurações de projeto alteradas.
- B: testes Flutter/Functions, fixtures sintéticas e arquivos de configuração de emuladores locais.
- C: relatórios KB, homologação, correções e diretrizes/manifesto das referências oficiais.
- D: os três assets de home/splash exigidos pelo pubspec.
- E: Gradle de assinatura sem fallback debug, template vazio e recursos de splash Android/iOS.

Listas são propostas para revisão humana, não comandos executados. Não incluir
uma pasta inteira apenas porque contém algum arquivo aprovado.

## ARQUIVOS A EXCLUIR

**${exclude.length} arquivos do inventário inicial** estão marcados EXCLUIR.
Lista auxiliar: \`${root}/exclude-paths.txt\`.
Excluir aqui significa não selecionar suas alterações para o checkpoint;
**não significa apagar, restaurar ou retirar arquivos do índice nesta tarefa**.

- \`android/local.properties\`: SDK/caminhos e modo/versão locais; já rastreado.
- Ambos os GeneratedPluginRegistrant: gerados, já rastreados, com regras de ignore existentes.
- Quatro entradas M sem diff substantivo.
- Backups before, diffs, hashes, saídas JSON de auditorias, harness/capturas locais em tool listados no inventário.
- PNGs/vídeos de evidência em docs não revisados individualmente para PII/metadados; logs de captura e comparações geradas.
- Arquivos reais de ambiente, credenciais, logs, temporários, build, cache, node_modules,
  AAB/APK, key.properties, jks/keystore, mesmo quando ignorados e ausentes do inventário Git.

Alguns relatórios citam capturas/logs excluídos: essas referências continuam
como evidência local, não como promessa de anexos presentes no futuro checkpoint.
Uma seleção posterior de evidências saneadas deve ser revisada separadamente.

## ARQUIVOS GERADOS

| Arquivo | Auditoria | Decisão para este checkpoint |
| --- | --- | --- |
| android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java | Acrescenta GoogleSignInPlugin. Autogerado e já rastreado; android/.gitignore contém GeneratedPluginRegistrant.java. | Não incluir diff; regenerável pelas dependências existentes. |
| ios/Runner/GeneratedPluginRegistrant.m | Acrescenta import/registro GoogleSignInPlugin. Autogerado e já rastreado; ios/.gitignore contém Runner/GeneratedPluginRegistrant.*. | Não incluir diff; não foi compilado/homologado em macOS/Xcode nesta tarefa. |
| android/local.properties | Propriedades SDK Flutter/Android e buildMode/versionName/versionCode. Valores locais não reproduzidos. Há quatro propriedades alteradas. | Não incluir diff; configuração específica da máquina. |
| build, .dart_tool, .gradle, node_modules e logs | Saídas/caches locais cobertos pelos padrões auditados de ignore. | Não incluir. Nenhum clean/remoção foi executado. |
| tool/** e evidências geradas do inventário | Backups e registros de auditoria/captura, não fontes de autoridade comercial. | Preservar no disco fora da proposta. Não extrapolar para remover arquivos tool já versionados. |

**Ignore não remove um arquivo já rastreado.** Os três arquivos destacados
continuam rastreados e suas versões anteriores em HEAD continuarão no histórico
se apenas seus diffs forem deixados de fora. Qualquer decisão de desrastreamento
é trabalho separado, após revisão; não foi executada. Regenerar registrantes
com Flutter/pub get em uma máquina autorizada faz parte da reprodução do projeto.

## ARQUIVOS SENSÍVEIS

| Item | Evidência segura | Proposta |
| --- | --- | --- |
| Upload key oficial | Caminho informado: C:\\Users\\DELL\\LoumakSecure\\Android\\chamae-upload.jks; resolvido fora da raiz do repositório. Não foi aberta. Busca por nomes jks/keystore no workspace, incluindo ignorados e excluindo dependências/.git, não encontrou arquivos. | Permanecer fora do Git. Não copiar, mover ou gerar chave. |
| android/key.properties | Arquivo existe; não rastreado. git check-ignore confirmou android/.gitignore:12. Nenhum conteúdo foi aberto/lido pela auditoria. | Excluir sempre. |
| android/key.properties.example | Quatro campos vazios; template versionável, sem senha/alias. | Incluir somente o template. |
| Service accounts, PEM/P12/PFX/private keys, envs reais | Nenhum nome correspondente rastreado/candidato; busca de nomes locais sem leitura de credenciais. | Excluir qualquer ocorrência futura, mesmo fora de padrões usuais. |
| Configuração pública de cliente Firebase/Maps | Chaves de API de cliente já presentes em arquivos rastreados, sem alterações nesta tarefa; valores não reproduzidos. Não são credenciais Admin nem chave privada de assinatura. | Não tratar como prova de restrições remotas: configuração/restrições exigem homologação autorizada. |
| Logs, imagens, vídeos e snapshots de evidência | Podem carregar dados de usuário, dispositivo ou ambiente. Nenhuma garantia de saneamento individual das capturas históricas nesta tarefa. | Fora da lista de inclusão. |

## ANDROID NATIVO

ApplicationId/namespace oficial **br.com.loumak.chamae** preservado. Incluir
configuração release e recursos de splash como conjunto, inclusive a PNG nativa
referenciada pelos XMLs e estilos Android 12/night. O template está vazio;
key.properties real e upload key não entram. Não foi gerado novo AAB/APK nesta tarefa.
KB-07 mantém **RESOLVIDO LOCALMENTE / PENDENTE HOMOLOGAÇÃO GOOGLE PLAY**, baseado
nas evidências anteriores fornecidas pelo responsável. Upload/Play App Signing/
teste fechado e gate Google Play continuam pendentes. O AAB local não deve ser commitado.

## IOS NATIVO

Incluir somente a mudança funcional em LaunchScreen.storyboard. Não incluir
o registrante gerado. Nenhuma atualização de Pods, bundle ID, credenciais,
capability, archive, TestFlight ou validação Apple real. Não presumir
homologação iOS a partir do teste Flutter no Windows.

## SEGREDOS

Verificações por nome/metadados em arquivos locais e por padrões no texto
versionável, sem abrir key.properties/keystores/envs/credenciais reconhecidas.
Scanner em **${data.summary.scanned} arquivos de texto** existentes/candidatos:
nenhum marcador de chave privada, private_key de service account, token de
produção reconhecido ou JWT literal encontrado. Apenas nomes/regras/linhas,
sem valores, foram registrados em inventory-before.json.

Achados revisados: API keys públicas do cliente Firebase/Maps preexistentes;
chaves fictícias explícitas TEST_ONLY/TEST-ONLY/PRIVATE_TEST_KEY em testes;
e-mails de integração no index.js idênticos aos de HEAD (não reproduzidos),
e-mails de fixtures e máscara de documento no cadastro; nomes @2x de imagens
causaram falsos positivos do detector de e-mail. Não foram identificadas novas
credenciais privadas nos candidatos a incluir. Os três assets visuais Flutter
novos foram inspecionados: fundo/logos institucionais, sem dados pessoais aparentes.

A proposta de inclusão não contém segredo de assinatura ou arquivo de produção
sensível identificado. Nada foi staged: uma seleção ampla posterior invalidaria
esta conclusão. O exame por padrões não é prova universal de ausência de segredo,
nem auditoria de todo o histórico Git. Capturas/logs não revisados ficam excluídos.

## COERÊNCIA DAS MUDANÇAS ACUMULADAS

| Conjunto | Evidência local e limite |
| --- | --- |
| Visual | Assets declarados no pubspec, referências oficiais/manifesto preservados; temas e imagem de splash incluídos junto dos recursos nativos. Capturas antigas não são autoridade de dados comerciais. |
| Frete | App/backend usam contrato routeBands, deliveryConfiguration/current e versões deliveryPricingVersions; template inicial inativo sem preços fictícios. Fixtures com valores sintéticos ficam em testes. Nada de tarifa/rota de produção foi alterado nesta tarefa. |
| Conta / KB-06 | Módulos de conta, revogação e limpeza local acompanhados de testes; dependências novas de arquivo estão na lista de inclusão. Apple/Google reais e demais pendências permanecem conforme relatório KB-06. |
| KB-03 | Guard backend America/Campo_Grande e prova de país preservados, com testes de horário/método/destino. Regra 08:00 inclusive até 00:00 exclusivo preservada. |
| KB-04 / KB-05 | Cancelamento/compensação e contingência acompanhados de estados, handlers e testes. Não há ensaio PSP, bridge/estoque físico ou operação real nesta tarefa. |
| Backend e testes | Módulos novos exigidos pelos requires e testes/fixtures respectivos incluídos como conjunto. npm test local passou com rede bloqueada e provedores simulados. |
| Documentação | 196 IDs iguais nos dois documentos oficiais, resultados em branco e gates sem liberação. KB-07 tem o fechamento local mais recente; 207/209 em KB-06 é registro histórico, sucedido pela correção de fixtures e 209/209 atuais. |
| Android/iOS | Recursos nativos necessários incluídos; gerados e configurações da máquina ficam fora dos diffs propostos. Dependências e lockfiles não foram atualizados. Sem homologação Apple/Google real. |

É auditoria de coerência estrutural, classificação e testes locais, não revisão
formal de cada ramo de negócio nem homologação ponta a ponta com serviços reais.
Harness antigos de captura podem usar contratos/valores históricos de fixture;
não entram na proposta nem são usados como evidência de frete/checkout atual.

## FLUTTER ANALYZE

**No issues found. Exit 0**, 51.3 s. Comando equivalente a flutter analyze,
executado com --no-pub para preservar resolução de dependências. SDK local
invocado via dart.exe/flutter_tools.snapshot --no-version-check --suppress-analytics.
Registro: \`${root}/flutter-analyze.log\`.

## FLUTTER TEST

**209/209 aprovados. Exit 0**, aproximadamente 59 s.
Executado flutter test --no-pub --reporter expanded pelo SDK local.
Mensagens de vídeo não implementado no ambiente de widget test não causaram falhas.
Registro: \`${root}/flutter-test.log\`.

## FUNCTIONS TEST

**414/414 aprovados, 0 falhas, 0 skipped. Exit 0**.
Suíte npm test já definida em functions/package.json, executada com
\`npm.cmd --offline --no-update-notifier test\`. NODE_OPTIONS carregou o guard
local no-network.cjs: fetch, HTTP/HTTPS, net/TLS e DNS bloqueados; projetos demo
e hosts loopback definidos no processo filho. Não foram usadas credenciais reais.
O teste financeiro carrega index.js com VM/doubles; os provedores usam mocks.
Não executados serve/shell/deploy, testes contra provedores ou emulador nesta
tarefa. Não é necessário ampliar para testes externos para preparar o checkpoint.
Registro: \`${root}/functions-test.log\`.

## INTEGRIDADE E VERIFICAÇÕES ADICIONAIS

- **${preservation.baselineFiles}/${preservation.baselineFiles} arquivos de referência inalterados** após analyze/testes; nenhuma lógica de negócio editada.
- Nenhuma dependência atualizada; pubspec.lock e functions/package-lock.json sem diff substantivo.
- git diff --check: exit 0, sem erros de whitespace.
- Nenhum arquivo staged antes/depois das verificações; a lista de inclusão é apenas documental.
- Nenhum arquivo removido/restaurado; segredos não foram impressos, movidos ou regravados.

## RISCO DE COMMIT

**MÉDIO para o checkpoint seletivo proposto; ALTO para inclusão indiscriminada do worktree.**
Há alterações amplas de vários KBs, arquivos gerados/locais já rastreados e
evidências volumosas ainda não saneadas individualmente. Testes verdes reduzem
risco de regressão local, não de publicar credenciais ou homologar produção.
Mitigação: revisar a lista INCLUIR, manter todas as exclusões, conferir o diff
selecionado e nomes/segredos novamente antes de qualquer commit autorizado.

## PROPOSTA DE CHECKPOINT

Um checkpoint local do estado funcional acumulado, contendo exclusivamente os
${include.length+1} caminhos propostos (incluindo este relatório), sem outputs de build,
chaves/credenciais, gerados da máquina ou capturas não revisadas. Não liberar
gates nem alterar o estado de homologação dos KBs pela existência do checkpoint.
Manter backups, evidências e alterações excluídas no disco para revisão posterior.

Os três arquivos gerados/locais já rastreados exigem decisão explícita sobre
eventual saneamento futuro; este trabalho só recomenda não selecionar seus diffs.
Em outro clone, regenerar o tooling a partir dos lockfiles e fornecer segredos
por custódia local autorizada. Nenhum comando de staging/commit é executado aqui.

## COMMIT RECOMENDADO

**sim**, para o checkpoint seletivo após revisão humana da lista e do diff.
**Não** para inclusão total do worktree. Esta recomendação não é execução nem
autorização para commit nesta tarefa; aguardar revisão.

## MENSAGEM DE COMMIT SUGERIDA

\`chore: checkpoint local pré-homologação do Chamaê Delivery\`

Descrição sugerida: preservar visual, frete, ciclo de conta, proteções e
contingências backend, preparação Android e testes/documentação acumulados;
manter pendências de homologação externa e excluir credenciais/artefatos locais.

## INVENTÁRIO EXAUSTIVO INICIAL — ARQUIVOS A INCLUIR

M = modificado já rastreado; NOVO = não rastreado. Cada um dos 343 arquivos
iniciais aparece exatamente uma vez nas duas tabelas abaixo.

| Estado | Arquivo | Grupo principal (secundário) | Proposta | Motivo |
| --- | --- | --- | --- | --- |
${include.map(line).join('\n')}

## INVENTÁRIO EXAUSTIVO INICIAL — ARQUIVOS A EXCLUIR

| Estado | Arquivo | Grupo principal (secundário) | Proposta | Motivo |
| --- | --- | --- | --- | --- |
${exclude.map(line).join('\n')}

## ARQUIVOS DESTA TAREFA

- Este relatório: C, INCLUIR após revisão.
- Todos os arquivos em \`${root}/\`: F/G, EXCLUIR. Contêm registros,
  inventário, hashes de preservação, scripts locais de auditoria/guard e listas
  propostas. Não são parte de código de negócio nem autorização para staging.
- Registros já produzidos: ${localArtifacts.map(n=>'`'+n+'`').join(', ')}.
  classification.json, include-paths.txt e exclude-paths.txt detalham as decisões;
  verificações finais adicionais nessa mesma pasta também permanecem locais.

COMMIT: não realizado. PUSH: não realizado. DEPLOY: não realizado.
Git add/reset/checkout/restore/Discard Changes: não executados.
Firebase produção, Oracle/GrandChef, Mercado Pago produção, Google Play e
Apple/Google produção: não acessados. Nenhuma instalação ou upload executado.

**Parado para revisão humana.**
`;
fs.writeFileSync(report,text);
console.log(JSON.stringify({report,initialFiles:rows.length,groups:counts,includeInitial:include.length,includeWithReport:include.length+1,excludeInitial:exclude.length,reportLines:text.split('\n').length},null,2));
