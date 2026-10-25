# Checkpoint Git pré-homologação — 25/10/2026

## WORKTREE

Repositório: C:\Users\DELL\chamae_delivery. Branch **main**, HEAD local **f03689d**.
Auditoria inicial sem staging. Etapa posterior: staging seletivo aprovado e
executado, conforme resultado ao final. Nenhum commit, push, deploy ou acesso a produção.
Alterações anteriores preservadas. Nenhum reset, checkout, restore, descarte,
remoção de arquivo ou desrastreamento foi executado. O relatório não homologa
operação real, Google Play, provedores, estoque físico ou iOS.

Antes de criar qualquer arquivo desta tarefa foram executados os quatro comandos
abaixo. Saídas iniciais integrais, incluindo avisos de finais de linha, estão
registradas localmente em `tool/checkpoint_git_2026-10-25/`:

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

- `lib/screens/admin_screen.dart`
- `lib/screens/registration_screen.dart`
- `lib/widgets/chamae_logo.dart`
- `lib/widgets/real_web_map.dart`

## ARQUIVOS NOVOS

As 282 entradas NOVO constam integralmente no mesmo inventário. Há módulos de
backend/cliente, testes/fixtures, documentação, assets necessários ao produto,
e grande volume de backups/capturas que não deve ser incluído por seleção ampla.
Este relatório é um novo arquivo C, recomendado para inclusão após revisão.
Os arquivos produzidos agora sob `tool/checkpoint_git_2026-10-25/` são F/G, locais e excluídos da proposta.

## CLASSIFICAÇÃO A–I

Grupo principal exclusivo para contagem; grupos secundários aparecem entre
parênteses por linha (ex.: F/E para registrantes nativos gerados). H é examinado
também fora dos candidatos versionáveis, sem abrir arquivos de segredo.

| Grupo | Significado | Quantidade inicial |
| --- | --- | ---: |
| A | código funcional e configuração versionável | 51 |
| B | testes e fixtures | 38 |
| C | documentação | 17 |
| D | assets visuais do produto | 3 |
| E | Android/iOS nativo | 10 |
| F | arquivos gerados | 2 |
| G | arquivos locais fora do checkpoint | 178 |
| H | sensíveis/credenciais | 0 |
| I | inclusão duvidosa ou pendente de revisão | 44 |

O grupo H tem zero candidatos versionáveis, mas existe um arquivo sensível
local ignorado, `android/key.properties`, tratado explicitamente abaixo.

## ARQUIVOS A INCLUIR

**115 arquivos do inventário inicial**, mais este relatório:
116 caminhos propostos. Cada caminho tem decisão INCLUIR no inventário.
Lista exata auxiliar: `tool/checkpoint_git_2026-10-25/include-paths.txt`; não é script de staging.

- A: app, Functions, Rules, configuração de frete inicial inativa e configurações de projeto alteradas.
- B: testes Flutter/Functions, fixtures sintéticas e arquivos de configuração de emuladores locais.
- C: relatórios KB, homologação, correções e diretrizes/manifesto das referências oficiais.
- D: os três assets de home/splash exigidos pelo pubspec.
- E: Gradle de assinatura sem fallback debug, template vazio e recursos de splash Android/iOS.

Listas são propostas para revisão humana, não comandos executados. Não incluir
uma pasta inteira apenas porque contém algum arquivo aprovado.

## ARQUIVOS A EXCLUIR

**228 arquivos do inventário inicial** estão marcados EXCLUIR.
Lista auxiliar: `tool/checkpoint_git_2026-10-25/exclude-paths.txt`.
Excluir aqui significa não selecionar suas alterações para o checkpoint;
**não significa apagar, restaurar ou retirar arquivos do índice nesta tarefa**.

- `android/local.properties`: SDK/caminhos e modo/versão locais; já rastreado.
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
| Upload key oficial | Caminho informado: C:\Users\DELL\LoumakSecure\Android\chamae-upload.jks; resolvido fora da raiz do repositório. Não foi aberta. Busca por nomes jks/keystore no workspace, incluindo ignorados e excluindo dependências/.git, não encontrou arquivos. | Permanecer fora do Git. Não copiar, mover ou gerar chave. |
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
Scanner em **375 arquivos de texto** existentes/candidatos:
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
sensível identificado. Na auditoria inicial nada foi staged; o staging seletivo
posterior está documentado ao final. Uma seleção ampla invalidaria esta conclusão.
O exame por padrões não é prova universal de ausência de segredo,
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
Registro: `tool/checkpoint_git_2026-10-25/flutter-analyze.log`.

## FLUTTER TEST

**209/209 aprovados. Exit 0**, aproximadamente 59 s.
Executado flutter test --no-pub --reporter expanded pelo SDK local.
Mensagens de vídeo não implementado no ambiente de widget test não causaram falhas.
Registro: `tool/checkpoint_git_2026-10-25/flutter-test.log`.

## FUNCTIONS TEST

**414/414 aprovados, 0 falhas, 0 skipped. Exit 0**.
Suíte npm test já definida em functions/package.json, executada com
`npm.cmd --offline --no-update-notifier test`. NODE_OPTIONS carregou o guard
local no-network.cjs: fetch, HTTP/HTTPS, net/TLS e DNS bloqueados; projetos demo
e hosts loopback definidos no processo filho. Não foram usadas credenciais reais.
O teste financeiro carrega index.js com VM/doubles; os provedores usam mocks.
Não executados serve/shell/deploy, testes contra provedores ou emulador nesta
tarefa. Não é necessário ampliar para testes externos para preparar o checkpoint.
Registro: `tool/checkpoint_git_2026-10-25/functions-test.log`.

## INTEGRIDADE E VERIFICAÇÕES ADICIONAIS

- **612/612 arquivos de referência inalterados** após analyze/testes; nenhuma lógica de negócio editada.
- Nenhuma dependência atualizada; pubspec.lock e functions/package-lock.json sem diff substantivo.
- git diff --check: exit 0, sem erros de whitespace.
- Na auditoria inicial, nenhum arquivo staged antes/depois das verificações;
  o staging da lista aprovada foi autorizado e executado em etapa posterior, abaixo.
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
116 caminhos propostos (incluindo este relatório), sem outputs de build,
chaves/credenciais, gerados da máquina ou capturas não revisadas. Não liberar
gates nem alterar o estado de homologação dos KBs pela existência do checkpoint.
Manter backups, evidências e alterações excluídas no disco para revisão posterior.

Os três arquivos gerados/locais já rastreados exigem decisão explícita sobre
eventual saneamento futuro; este trabalho só recomenda não selecionar seus diffs.
Em outro clone, regenerar o tooling a partir dos lockfiles e fornecer segredos
por custódia local autorizada. A auditoria inicial não executou staging; a etapa
posterior autorizada adicionou somente a lista aprovada, conforme registro abaixo.
Nenhum commit foi executado.

## COMMIT RECOMENDADO

**sim**, para o checkpoint seletivo após revisão humana da lista e do diff.
**Não** para inclusão total do worktree. Esta recomendação não é execução nem
autorização para commit nesta tarefa; aguardar revisão.

## MENSAGEM DE COMMIT SUGERIDA

`chore: checkpoint local pré-homologação do Chamaê Delivery`

Descrição sugerida: preservar visual, frete, ciclo de conta, proteções e
contingências backend, preparação Android e testes/documentação acumulados;
manter pendências de homologação externa e excluir credenciais/artefatos locais.

## INVENTÁRIO EXAUSTIVO INICIAL — ARQUIVOS A INCLUIR

M = modificado já rastreado; NOVO = não rastreado. Cada um dos 343 arquivos
iniciais aparece exatamente uma vez nas duas tabelas abaixo.

| Estado | Arquivo | Grupo principal (secundário) | Proposta | Motivo |
| --- | --- | --- | --- | --- |
| M | `android/app/build.gradle.kts` | E | INCLUIR | Configuração/recursos nativos do produto; preservar junto do splash/assinatura. |
| NOVO | `android/app/src/main/res/drawable-nodpi/splash_gold.png` | E (D) | INCLUIR | Imagem nativa de splash referenciada pelos recursos XML; preservar junto dos temas. |
| M | `android/app/src/main/res/drawable-v21/launch_background.xml` | E | INCLUIR | Configuração/recursos nativos do produto; preservar junto do splash/assinatura. |
| M | `android/app/src/main/res/drawable/launch_background.xml` | E | INCLUIR | Configuração/recursos nativos do produto; preservar junto do splash/assinatura. |
| NOVO | `android/app/src/main/res/values-night-v31/styles.xml` | E | INCLUIR | Configuração/recursos nativos do produto; preservar junto do splash/assinatura. |
| M | `android/app/src/main/res/values-night/styles.xml` | E | INCLUIR | Configuração/recursos nativos do produto; preservar junto do splash/assinatura. |
| NOVO | `android/app/src/main/res/values-v31/styles.xml` | E | INCLUIR | Configuração/recursos nativos do produto; preservar junto do splash/assinatura. |
| M | `android/app/src/main/res/values/styles.xml` | E | INCLUIR | Configuração/recursos nativos do produto; preservar junto do splash/assinatura. |
| NOVO | `android/key.properties.example` | E | INCLUIR | Template de assinatura com campos vazios; não é o key.properties real. |
| NOVO | `assets/images/home/commerce_backdrop.png` | D | INCLUIR | Asset usado pelo produto e declarado no pubspec; inspecionado visualmente, sem dados pessoais aparentes. |
| NOVO | `assets/images/home/logo_transparent.png` | D | INCLUIR | Asset usado pelo produto e declarado no pubspec; inspecionado visualmente, sem dados pessoais aparentes. |
| NOVO | `assets/images/splash/chamae_official_gold_2026_10_21.jpeg` | D | INCLUIR | Asset usado pelo produto e declarado no pubspec; inspecionado visualmente, sem dados pessoais aparentes. |
| NOVO | `design/references/customer_app/official/baseline_manifest.json` | C | INCLUIR | Relatório, diretriz ou manifesto de referências oficiais, sem credencial privada detectada. |
| M | `design/references/customer_app/official/README.md` | C | INCLUIR | Relatório, diretriz ou manifesto de referências oficiais, sem credencial privada detectada. |
| NOVO | `docs/APP-CLIENTE-CONSOLIDACAO-FINAL-2026-10-24.md` | C | INCLUIR | Relatório, diretriz ou manifesto de referências oficiais, sem credencial privada detectada. |
| NOVO | `docs/CORRECAO-TESTES-CHECKOUT-2026-10-25.md` | C | INCLUIR | Relatório, diretriz ou manifesto de referências oficiais, sem credencial privada detectada. |
| NOVO | `docs/EXCLUSAO-CONTA-E-CONFIRMACAO-PEDIDO-2026-10-24.md` | C | INCLUIR | Relatório, diretriz ou manifesto de referências oficiais, sem credencial privada detectada. |
| NOVO | `docs/frete_ponta_a_ponta_2026-10-24.md` | C | INCLUIR | Relatório, diretriz ou manifesto de referências oficiais, sem credencial privada detectada. |
| NOVO | `docs/home_official_visual_audit_2026-10-21.md` | C | INCLUIR | Relatório, diretriz ou manifesto de referências oficiais, sem credencial privada detectada. |
| NOVO | `docs/home_visual_sprint_2026-10-21/README.md` | C | INCLUIR | Relatório, diretriz ou manifesto de referências oficiais, sem credencial privada detectada. |
| NOVO | `docs/HOMOLOGACAO-MVP-CHAMAE-2026-10-24.md` | C | INCLUIR | Relatório, diretriz ou manifesto de referências oficiais, sem credencial privada detectada. |
| NOVO | `docs/HOMOLOGACAO-MVP-CHAMAE-CHECKLIST-2026-10-24.md` | C | INCLUIR | Relatório, diretriz ou manifesto de referências oficiais, sem credencial privada detectada. |
| NOVO | `docs/KB-03-HORARIO-PAIS-BACKEND-2026-10-24.md` | C | INCLUIR | Relatório, diretriz ou manifesto de referências oficiais, sem credencial privada detectada. |
| NOVO | `docs/KB-04-CANCELAMENTO-COMPENSACOES-2026-10-24.md` | C | INCLUIR | Relatório, diretriz ou manifesto de referências oficiais, sem credencial privada detectada. |
| NOVO | `docs/KB-05-CONTINGENCIA-ENTREGA-2026-10-24.md` | C | INCLUIR | Relatório, diretriz ou manifesto de referências oficiais, sem credencial privada detectada. |
| NOVO | `docs/KB-06-PRIVACIDADE-APPLE-CONTA-2026-10-24.md` | C | INCLUIR | Relatório, diretriz ou manifesto de referências oficiais, sem credencial privada detectada. |
| NOVO | `docs/KB-07-ANDROID-SIGNING-BUILD-2026-10-25.md` | C | INCLUIR | Relatório, diretriz ou manifesto de referências oficiais, sem credencial privada detectada. |
| NOVO | `docs/splash_final_correction_2026-10-21/README.md` | C | INCLUIR | Relatório, diretriz ou manifesto de referências oficiais, sem credencial privada detectada. |
| NOVO | `docs/splash_official_validation_2026-10-21/README.md` | C | INCLUIR | Relatório, diretriz ou manifesto de referências oficiais, sem credencial privada detectada. |
| NOVO | `firebase.account-test.json` | B | INCLUIR | Teste/fixture ou configuração de emulador loopback, necessária à reprodução local. |
| NOVO | `firebase.frete-test.json` | B | INCLUIR | Teste/fixture ou configuração de emulador loopback, necessária à reprodução local. |
| M | `firestore.rules` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| M | `functions/.eslintrc.js` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| M | `functions/config/delivery-pricing-initial.json` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| M | `functions/courier-assignment.js` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| NOVO | `functions/customer-account-state.js` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| NOVO | `functions/customer-account.js` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| M | `functions/customer-onboarding.js` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| NOVO | `functions/customer-provider-revocation.js` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| M | `functions/customer-security.js` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| NOVO | `functions/delivery-contingency-state.js` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| NOVO | `functions/delivery-contingency.js` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| M | `functions/delivery-pricing.js` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| M | `functions/delivery-service.js` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| NOVO | `functions/destination-country.js` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| M | `functions/index.js` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| M | `functions/operational-contingency.js` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| NOVO | `functions/order-acceptance.js` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| NOVO | `functions/order-cancellation-state.js` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| NOVO | `functions/order-cancellation.js` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| M | `functions/order-chat.js` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| M | `functions/order-operations.js` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| M | `functions/package.json` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| M | `functions/test/backend-fixture.js` | B | INCLUIR | Teste/fixture ou configuração de emulador loopback, necessária à reprodução local. |
| NOVO | `functions/test/customer-account.emulator.spec.js` | B | INCLUIR | Teste/fixture ou configuração de emulador loopback, necessária à reprodução local. |
| NOVO | `functions/test/customer-account.spec.js` | B | INCLUIR | Teste/fixture ou configuração de emulador loopback, necessária à reprodução local. |
| NOVO | `functions/test/customer-privacy.emulator.spec.js` | B | INCLUIR | Teste/fixture ou configuração de emulador loopback, necessária à reprodução local. |
| NOVO | `functions/test/customer-provider-revocation.spec.js` | B | INCLUIR | Teste/fixture ou configuração de emulador loopback, necessária à reprodução local. |
| NOVO | `functions/test/delivery-contingency.emulator.spec.js` | B | INCLUIR | Teste/fixture ou configuração de emulador loopback, necessária à reprodução local. |
| NOVO | `functions/test/delivery-contingency.spec.js` | B | INCLUIR | Teste/fixture ou configuração de emulador loopback, necessária à reprodução local. |
| M | `functions/test/delivery-contracts.spec.js` | B | INCLUIR | Teste/fixture ou configuração de emulador loopback, necessária à reprodução local. |
| NOVO | `functions/test/delivery-fixture.js` | B | INCLUIR | Teste/fixture ou configuração de emulador loopback, necessária à reprodução local. |
| M | `functions/test/delivery-official.spec.js` | B | INCLUIR | Teste/fixture ou configuração de emulador loopback, necessária à reprodução local. |
| NOVO | `functions/test/delivery-pricing-fixture.json` | B | INCLUIR | Teste/fixture ou configuração de emulador loopback, necessária à reprodução local. |
| M | `functions/test/delivery-radius.emulator.spec.js` | B | INCLUIR | Teste/fixture ou configuração de emulador loopback, necessária à reprodução local. |
| M | `functions/test/final-operations.emulator.spec.js` | B | INCLUIR | Teste/fixture ou configuração de emulador loopback, necessária à reprodução local. |
| M | `functions/test/financial.spec.js` | B | INCLUIR | Teste/fixture ou configuração de emulador loopback, necessária à reprodução local. |
| M | `functions/test/firestore.rules.spec.js` | B | INCLUIR | Teste/fixture ou configuração de emulador loopback, necessária à reprodução local. |
| NOVO | `functions/test/operational-fixture.js` | B | INCLUIR | Teste/fixture ou configuração de emulador loopback, necessária à reprodução local. |
| NOVO | `functions/test/order-acceptance.emulator.spec.js` | B | INCLUIR | Teste/fixture ou configuração de emulador loopback, necessária à reprodução local. |
| NOVO | `functions/test/order-acceptance.spec.js` | B | INCLUIR | Teste/fixture ou configuração de emulador loopback, necessária à reprodução local. |
| NOVO | `functions/test/order-cancellation.emulator.spec.js` | B | INCLUIR | Teste/fixture ou configuração de emulador loopback, necessária à reprodução local. |
| NOVO | `functions/test/order-cancellation.spec.js` | B | INCLUIR | Teste/fixture ou configuração de emulador loopback, necessária à reprodução local. |
| M | `functions/test/pilot.emulator.spec.js` | B | INCLUIR | Teste/fixture ou configuração de emulador loopback, necessária à reprodução local. |
| M | `ios/Runner/Base.lproj/LaunchScreen.storyboard` | E | INCLUIR | Configuração/recursos nativos do produto; preservar junto do splash/assinatura. |
| M | `lib/core/models.dart` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| NOVO | `lib/core/order_confirmation_policy.dart` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| NOVO | `lib/data/customer_account.dart` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| M | `lib/data/customer_auth.dart` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| M | `lib/data/customer_bootstrap.dart` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| NOVO | `lib/data/customer_local_privacy.dart` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| M | `lib/data/customer_orders.dart` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| M | `lib/data/customer_workspace.dart` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| M | `lib/data/delivery_quote.dart` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| M | `lib/screens/cart_screen.dart` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| M | `lib/screens/checkout_screen.dart` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| NOVO | `lib/screens/customer_account_closure_screen.dart` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| M | `lib/screens/customer_profile_screen.dart` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| M | `lib/screens/customer_session_gate.dart` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| M | `lib/screens/home_screen.dart` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| M | `lib/screens/splash_screen.dart` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| M | `lib/screens/tracking_screen.dart` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| M | `lib/screens/tracking_view.dart` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| NOVO | `lib/widgets/customer_feedback.dart` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| NOVO | `lib/widgets/order_confirmation.dart` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| M | `lib/widgets/pix_payment_dialog.dart` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| M | `lib/widgets/product_image.dart` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| M | `lib/widgets/sponsor_video_banner.dart` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| NOVO | `lib/widgets/store_hours_builder.dart` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| M | `pubspec.yaml` | A | INCLUIR | Código/regra/configuração funcional, necessário ao conjunto acumulado. |
| NOVO | `test/app_client_final_test.dart` | B | INCLUIR | Teste/fixture ou configuração de emulador loopback, necessária à reprodução local. |
| NOVO | `test/app_client_final_visual_test.dart` | B | INCLUIR | Teste/fixture ou configuração de emulador loopback, necessária à reprodução local. |
| M | `test/checkout_delivery_contract_test.dart` | B | INCLUIR | Teste/fixture ou configuração de emulador loopback, necessária à reprodução local. |
| M | `test/checkout_web_test.dart` | B | INCLUIR | Teste/fixture ou configuração de emulador loopback, necessária à reprodução local. |
| M | `test/client_readiness_test.dart` | B | INCLUIR | Teste/fixture ou configuração de emulador loopback, necessária à reprodução local. |
| NOVO | `test/customer_account_cycle_test.dart` | B | INCLUIR | Teste/fixture ou configuração de emulador loopback, necessária à reprodução local. |
| M | `test/customer_auth_test.dart` | B | INCLUIR | Teste/fixture ou configuração de emulador loopback, necessária à reprodução local. |
| M | `test/customer_orders_test.dart` | B | INCLUIR | Teste/fixture ou configuração de emulador loopback, necessária à reprodução local. |
| NOVO | `test/customer_privacy_test.dart` | B | INCLUIR | Teste/fixture ou configuração de emulador loopback, necessária à reprodução local. |
| M | `test/customer_visual_freeze_test.dart` | B | INCLUIR | Teste/fixture ou configuração de emulador loopback, necessária à reprodução local. |
| M | `test/customer_visual_homologation_test.dart` | B | INCLUIR | Teste/fixture ou configuração de emulador loopback, necessária à reprodução local. |
| M | `test/delivery_quote_state_test.dart` | B | INCLUIR | Teste/fixture ou configuração de emulador loopback, necessária à reprodução local. |
| NOVO | `test/home_visual_sprint_test.dart` | B | INCLUIR | Teste/fixture ou configuração de emulador loopback, necessária à reprodução local. |
| NOVO | `test/order_acceptance_test.dart` | B | INCLUIR | Teste/fixture ou configuração de emulador loopback, necessária à reprodução local. |
| NOVO | `test/splash_official_test.dart` | B | INCLUIR | Teste/fixture ou configuração de emulador loopback, necessária à reprodução local. |

## INVENTÁRIO EXAUSTIVO INICIAL — ARQUIVOS A EXCLUIR

| Estado | Arquivo | Grupo principal (secundário) | Proposta | Motivo |
| --- | --- | --- | --- | --- |
| M | `android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java` | F (E) | EXCLUIR | Autogerado, já rastreado apesar do ignore; regenerável pelo Flutter. |
| M | `android/local.properties` | G (F) | EXCLUIR | Configuração da máquina já rastreada; não incluir este diff. |
| NOVO | `docs/app_cliente_final_2026-10-24/carrinho.png` | I (D/F) | EXCLUIR | Evidência visual não revisada individualmente para PII/metadados nesta tarefa; manter local. |
| NOVO | `docs/app_cliente_final_2026-10-24/categorias.png` | I (D/F) | EXCLUIR | Evidência visual não revisada individualmente para PII/metadados nesta tarefa; manter local. |
| NOVO | `docs/app_cliente_final_2026-10-24/checkout.png` | I (D/F) | EXCLUIR | Evidência visual não revisada individualmente para PII/metadados nesta tarefa; manter local. |
| NOVO | `docs/app_cliente_final_2026-10-24/confirmacao.png` | I (D/F) | EXCLUIR | Evidência visual não revisada individualmente para PII/metadados nesta tarefa; manter local. |
| NOVO | `docs/app_cliente_final_2026-10-24/home.png` | I (D/F) | EXCLUIR | Evidência visual não revisada individualmente para PII/metadados nesta tarefa; manter local. |
| NOVO | `docs/app_cliente_final_2026-10-24/perfil.png` | I (D/F) | EXCLUIR | Evidência visual não revisada individualmente para PII/metadados nesta tarefa; manter local. |
| NOVO | `docs/app_cliente_final_2026-10-24/produto.png` | I (D/F) | EXCLUIR | Evidência visual não revisada individualmente para PII/metadados nesta tarefa; manter local. |
| NOVO | `docs/app_cliente_final_2026-10-24/tracking-progresso.png` | I (D/F) | EXCLUIR | Evidência visual não revisada individualmente para PII/metadados nesta tarefa; manter local. |
| NOVO | `docs/app_cliente_final_2026-10-24/tracking.png` | I (D/F) | EXCLUIR | Evidência visual não revisada individualmente para PII/metadados nesta tarefa; manter local. |
| NOVO | `docs/home_visual_sprint_2026-10-21/capture_inventory.json` | I (C/F) | EXCLUIR | Inventário/validação/comparação gerada de captura; revisão de metadados pendente. |
| NOVO | `docs/home_visual_sprint_2026-10-21/cart-state.png` | I (D/F) | EXCLUIR | Evidência visual não revisada individualmente para PII/metadados nesta tarefa; manter local. |
| NOVO | `docs/home_visual_sprint_2026-10-21/catalog.png` | I (D/F) | EXCLUIR | Evidência visual não revisada individualmente para PII/metadados nesta tarefa; manter local. |
| NOVO | `docs/home_visual_sprint_2026-10-21/categories-preview.png` | I (D/F) | EXCLUIR | Evidência visual não revisada individualmente para PII/metadados nesta tarefa; manter local. |
| NOVO | `docs/home_visual_sprint_2026-10-21/empty.png` | I (D/F) | EXCLUIR | Evidência visual não revisada individualmente para PII/metadados nesta tarefa; manter local. |
| NOVO | `docs/home_visual_sprint_2026-10-21/error.png` | I (D/F) | EXCLUIR | Evidência visual não revisada individualmente para PII/metadados nesta tarefa; manter local. |
| NOVO | `docs/home_visual_sprint_2026-10-21/home.png` | I (D/F) | EXCLUIR | Evidência visual não revisada individualmente para PII/metadados nesta tarefa; manter local. |
| NOVO | `docs/home_visual_sprint_2026-10-21/large-text.png` | I (D/F) | EXCLUIR | Evidência visual não revisada individualmente para PII/metadados nesta tarefa; manter local. |
| NOVO | `docs/home_visual_sprint_2026-10-21/no-address.png` | I (D/F) | EXCLUIR | Evidência visual não revisada individualmente para PII/metadados nesta tarefa; manter local. |
| NOVO | `docs/home_visual_sprint_2026-10-21/popular.png` | I (D/F) | EXCLUIR | Evidência visual não revisada individualmente para PII/metadados nesta tarefa; manter local. |
| NOVO | `docs/home_visual_sprint_2026-10-21/promotions.png` | I (D/F) | EXCLUIR | Evidência visual não revisada individualmente para PII/metadados nesta tarefa; manter local. |
| NOVO | `docs/home_visual_sprint_2026-10-21/quote-error.png` | I (D/F) | EXCLUIR | Evidência visual não revisada individualmente para PII/metadados nesta tarefa; manter local. |
| NOVO | `docs/home_visual_sprint_2026-10-21/search.png` | I (D/F) | EXCLUIR | Evidência visual não revisada individualmente para PII/metadados nesta tarefa; manter local. |
| NOVO | `docs/splash_final_correction_2026-10-21/actual_app_splash.png` | I (D/F) | EXCLUIR | Evidência visual não revisada individualmente para PII/metadados nesta tarefa; manter local. |
| NOVO | `docs/splash_final_correction_2026-10-21/cold_01_metrics.png` | I (D/F) | EXCLUIR | Evidência visual não revisada individualmente para PII/metadados nesta tarefa; manter local. |
| NOVO | `docs/splash_final_correction_2026-10-21/cold_01_start.txt` | G (F) | EXCLUIR | Log/marcador de captura ou dispositivo; preservar local, sem inclusão. |
| NOVO | `docs/splash_final_correction_2026-10-21/cold_02_metrics.png` | I (D/F) | EXCLUIR | Evidência visual não revisada individualmente para PII/metadados nesta tarefa; manter local. |
| NOVO | `docs/splash_final_correction_2026-10-21/cold_02_start.txt` | G (F) | EXCLUIR | Log/marcador de captura ou dispositivo; preservar local, sem inclusão. |
| NOVO | `docs/splash_final_correction_2026-10-21/cold_sequence.mp4` | I (D/F) | EXCLUIR | Evidência visual não revisada individualmente para PII/metadados nesta tarefa; manter local. |
| NOVO | `docs/splash_final_correction_2026-10-21/error_retry.png` | I (D/F) | EXCLUIR | Evidência visual não revisada individualmente para PII/metadados nesta tarefa; manter local. |
| NOVO | `docs/splash_final_correction_2026-10-21/official_splash.png` | I (D/F) | EXCLUIR | Evidência visual não revisada individualmente para PII/metadados nesta tarefa; manter local. |
| NOVO | `docs/splash_final_correction_2026-10-21/reduced_motion.png` | I (D/F) | EXCLUIR | Evidência visual não revisada individualmente para PII/metadados nesta tarefa; manter local. |
| NOVO | `docs/splash_final_correction_2026-10-21/reopen_no_replay.png` | I (D/F) | EXCLUIR | Evidência visual não revisada individualmente para PII/metadados nesta tarefa; manter local. |
| NOVO | `docs/splash_final_correction_2026-10-21/reopen_start.txt` | G (F) | EXCLUIR | Log/marcador de captura ou dispositivo; preservar local, sem inclusão. |
| NOVO | `docs/splash_final_correction_2026-10-21/sequence_start.txt` | G (F) | EXCLUIR | Log/marcador de captura ou dispositivo; preservar local, sem inclusão. |
| NOVO | `docs/splash_final_correction_2026-10-21/validation.json` | I (C/F) | EXCLUIR | Inventário/validação/comparação gerada de captura; revisão de metadados pendente. |
| NOVO | `docs/splash_official_validation_2026-10-21/cold_01_metrics.png` | I (D/F) | EXCLUIR | Evidência visual não revisada individualmente para PII/metadados nesta tarefa; manter local. |
| NOVO | `docs/splash_official_validation_2026-10-21/cold_01_start.txt` | G (F) | EXCLUIR | Log/marcador de captura ou dispositivo; preservar local, sem inclusão. |
| NOVO | `docs/splash_official_validation_2026-10-21/cold_02_metrics.png` | I (D/F) | EXCLUIR | Evidência visual não revisada individualmente para PII/metadados nesta tarefa; manter local. |
| NOVO | `docs/splash_official_validation_2026-10-21/cold_02_start.txt` | G (F) | EXCLUIR | Log/marcador de captura ou dispositivo; preservar local, sem inclusão. |
| NOVO | `docs/splash_official_validation_2026-10-21/cold_sequence.mp4` | I (D/F) | EXCLUIR | Evidência visual não revisada individualmente para PII/metadados nesta tarefa; manter local. |
| NOVO | `docs/splash_official_validation_2026-10-21/comparison.html` | I (C/F) | EXCLUIR | Inventário/validação/comparação gerada de captura; revisão de metadados pendente. |
| NOVO | `docs/splash_official_validation_2026-10-21/error_retry.png` | I (D/F) | EXCLUIR | Evidência visual não revisada individualmente para PII/metadados nesta tarefa; manter local. |
| NOVO | `docs/splash_official_validation_2026-10-21/official_splash.png` | I (D/F) | EXCLUIR | Evidência visual não revisada individualmente para PII/metadados nesta tarefa; manter local. |
| NOVO | `docs/splash_official_validation_2026-10-21/reduced_motion.png` | I (D/F) | EXCLUIR | Evidência visual não revisada individualmente para PII/metadados nesta tarefa; manter local. |
| NOVO | `docs/splash_official_validation_2026-10-21/reopen_no_replay.png` | I (D/F) | EXCLUIR | Evidência visual não revisada individualmente para PII/metadados nesta tarefa; manter local. |
| NOVO | `docs/splash_official_validation_2026-10-21/reopen_start.txt` | G (F) | EXCLUIR | Log/marcador de captura ou dispositivo; preservar local, sem inclusão. |
| NOVO | `docs/splash_official_validation_2026-10-21/sequence_start.txt` | G (F) | EXCLUIR | Log/marcador de captura ou dispositivo; preservar local, sem inclusão. |
| M | `ios/Runner/GeneratedPluginRegistrant.m` | F (E) | EXCLUIR | Autogerado, já rastreado apesar do ignore; regenerável pelo Flutter. |
| M | `lib/screens/admin_screen.dart` | A (I) | EXCLUIR | Status M sem diff substantivo; normalização/estatística do Git, sem mudança a selecionar. |
| M | `lib/screens/registration_screen.dart` | A (I) | EXCLUIR | Status M sem diff substantivo; normalização/estatística do Git, sem mudança a selecionar. |
| M | `lib/widgets/chamae_logo.dart` | A (I) | EXCLUIR | Status M sem diff substantivo; normalização/estatística do Git, sem mudança a selecionar. |
| M | `lib/widgets/real_web_map.dart` | A (I) | EXCLUIR | Status M sem diff substantivo; normalização/estatística do Git, sem mudança a selecionar. |
| NOVO | `tool/account_cycle/before/firestore.rules.before` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/account_cycle/before/functions__customer-onboarding.js.before` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/account_cycle/before/functions__customer-security.js.before` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/account_cycle/before/functions__delivery-service.js.before` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/account_cycle/before/functions__index.js.before` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/account_cycle/before/functions__order-chat.js.before` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/account_cycle/before/lib__data__customer_auth.dart.before` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/account_cycle/before/lib__data__customer_orders.dart.before` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/account_cycle/before/lib__data__customer_workspace.dart.before` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/account_cycle/before/lib__screens__customer_profile_screen.dart.before` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/account_cycle/before/lib__screens__tracking_screen.dart.before` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/account_cycle/before/lib__widgets__order_confirmation.dart.before` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/account_cycle/before/lib__widgets__pix_payment_dialog.dart.before` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/account_cycle/protected-before.json` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/assets-contrast.json` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/before/lib__screens__cart_screen.dart.before` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/before/lib__screens__checkout_screen.dart.before` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/before/lib__screens__customer_profile_screen.dart.before` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/before/lib__screens__home_screen.dart.before` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/before/lib__screens__tracking_screen.dart.before` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/before/lib__screens__tracking_view.dart.before` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/before/lib__widgets__product_image.dart.before` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/build-proof.json` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/address_empty_360.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/cart_1440.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/cart_320.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/cart_360.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/cart_390.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/cart_430.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/cart_768.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/cart_empty_360.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/categories_1440.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/categories_320.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/categories_360.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/categories_390.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/categories_430.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/categories_768.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/checkout_1440.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/checkout_320.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/checkout_360.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/checkout_390.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/checkout_430.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/checkout_768.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/confirmation_390.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/confirmation_cta_390.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/home_1440.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/home_320.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/home_360.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/home_390.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/home_430.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/home_768.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/home_empty_360.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/home_error_360.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/home_loading_360.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/login_360.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/login_error_360.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/onboarding_360.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/onboarding_footer_360.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/product_1440.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/product_320.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/product_360.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/product_390.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/product_430.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/product_768.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/product_footer_360.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/profile_1440.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/profile_320.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/profile_360.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/profile_390.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/profile_430.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/profile_768.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/profile_footer_360.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/splash_error_360.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/splash_loading_360.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/tracking_1440.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/tracking_320.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/tracking_360.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/tracking_390_final.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/tracking_390.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/tracking_430.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/tracking_768.0.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/tracking_error_360.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/tracking_footer_360.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/tracking_loading_360.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/tracking_progress_390.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/captures/tracking_unavailable_360.png` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/own-changes.diff` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/preservation.json` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/app_cliente_final/preserved-before.json` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/checkout_test_fixes_2026-10-25/checkout_delivery_contract_test.before.dart.txt` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/checkout_test_fixes_2026-10-25/client_readiness_test.before.dart.txt` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/checkout_test_fixes_2026-10-25/final-evidence.json` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/checkout_test_fixes_2026-10-25/protected-after.json` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/checkout_test_fixes_2026-10-25/protected-before.json` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb03/before/docs__HOMOLOGACAO-MVP-CHAMAE-2026-10-24.md.before` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb03/before/docs__HOMOLOGACAO-MVP-CHAMAE-CHECKLIST-2026-10-24.md.before` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb03/before/firestore.rules.before` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb03/before/functions__.eslintrc.js.before` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb03/before/functions__delivery-service.js.before` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb03/before/functions__index.js.before` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb03/before/functions__test__delivery-fixture.js.before` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb03/before/functions__test__delivery-official.spec.js.before` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb03/before/functions__test__delivery-radius.emulator.spec.js.before` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb03/before/functions__test__final-operations.emulator.spec.js.before` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb03/before/functions__test__financial.spec.js.before` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb03/before/functions__test__firestore.rules.spec.js.before` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb03/before/functions__test__pilot.emulator.spec.js.before` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb03/protected-before.json` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb04/before/docs__HOMOLOGACAO-MVP-CHAMAE-2026-10-24.md.before` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb04/before/docs__HOMOLOGACAO-MVP-CHAMAE-CHECKLIST-2026-10-24.md.before` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb04/before/functions__.eslintrc.js.before` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb04/before/functions__index.js.before` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb04/before/functions__package.json.before` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb04/before/functions__test__financial.spec.js.before` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb04/protected-before.json` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb05/before/docs/HOMOLOGACAO-MVP-CHAMAE-2026-10-24.md` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb05/before/docs/HOMOLOGACAO-MVP-CHAMAE-CHECKLIST-2026-10-24.md` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb05/before/firestore.rules` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb05/before/functions/.eslintrc.js` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb05/before/functions/courier-assignment.js` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb05/before/functions/index.js` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb05/before/functions/operational-contingency.js` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb05/before/functions/order-cancellation.js` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb05/before/functions/order-operations.js` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb05/before/functions/package.json` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb05/before/functions/test/final-operations.emulator.spec.js` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb05/before/functions/test/financial.spec.js` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb05/before/functions/test/order-cancellation.emulator.spec.js` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb05/before/panel-operational_contingency.dart.txt` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb05/before/pilot.emulator.spec.js` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb05/checklist-consistency.json` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb05/delivery_contingency_test.dart.txt` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb05/operational_contingency.dart.txt` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb05/protected-after.json` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb05/protected-before.json` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb06/before/docs/HOMOLOGACAO-MVP-CHAMAE-2026-10-24.md` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb06/before/docs/HOMOLOGACAO-MVP-CHAMAE-CHECKLIST-2026-10-24.md` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb06/before/functions/.eslintrc.js` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb06/before/functions/customer-account-state.js` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb06/before/functions/customer-account.js` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb06/before/functions/package.json` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb06/before/functions/test/customer-account.emulator.spec.js` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb06/before/lib/core/models.dart.txt` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb06/before/lib/data/customer_account.dart.txt` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb06/before/lib/data/customer_auth.dart.txt` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb06/before/lib/data/customer_bootstrap.dart.txt` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb06/before/lib/main.dart.txt` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb06/before/lib/screens/customer_account_closure_screen.dart.txt` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb06/before/lib/screens/customer_session_gate.dart.txt` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb06/checklist-consistency.json` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb06/final-evidence.json` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb06/protected-after.json` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb06/protected-before.json` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb06/retomada-2026-10-25/checklist-consistency.json` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb06/retomada-2026-10-25/code-after.json` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb06/retomada-2026-10-25/code-before.json` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb06/retomada-2026-10-25/final-evidence.json` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb06/retomada-2026-10-25/protected.json` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb07/before/app.build.gradle.kts.txt` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb07/before/HOMOLOGACAO-MVP-CHAMAE-2026-10-24.md` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb07/before/HOMOLOGACAO-MVP-CHAMAE-CHECKLIST-2026-10-24.md` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb07/checklist-consistency.json` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb07/final-evidence.json` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb07/gradle-validation.json` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb07/guard-evidence.json` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb07/protected-after.json` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb07/protected-before.json` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb07/secrets-audit.json` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/kb07/signing-preflight-result.json` | G (F) | EXCLUIR | Backups, comparações, hashes, harness ou captura local; preservar fora do checkpoint. |
| NOVO | `tool/visual_device/capture.ps1` | I (G) | EXCLUIR | Harness/captura de ensaio; caminhos locais ou fixtures históricas. Revisar separadamente. |
| NOVO | `tool/visual_home/capture.ps1` | I (G) | EXCLUIR | Harness/captura de ensaio; caminhos locais ou fixtures históricas. Revisar separadamente. |
| NOVO | `tool/visual_home/main.dart` | I (G) | EXCLUIR | Harness/captura de ensaio; caminhos locais ou fixtures históricas. Revisar separadamente. |
| NOVO | `tool/visual_splash/capture.ps1` | I (G) | EXCLUIR | Harness/captura de ensaio; caminhos locais ou fixtures históricas. Revisar separadamente. |
| NOVO | `tool/visual_splash/main.dart` | I (G) | EXCLUIR | Harness/captura de ensaio; caminhos locais ou fixtures históricas. Revisar separadamente. |

## ARQUIVOS DESTA TAREFA

- Este relatório: C, INCLUIR após revisão.
- Todos os arquivos em `tool/checkpoint_git_2026-10-25/`: F/G, EXCLUIR. Contêm registros,
  inventário, hashes de preservação, scripts locais de auditoria/guard e listas
  propostas. Não são parte de código de negócio nem autorização para staging.
- Registros já produzidos: `audit.cjs`, `classification.json`, `exclude-paths.txt`, `flutter-analyze-exit.txt`, `flutter-analyze.log`, `flutter-test-exit.txt`, `flutter-test.log`, `functions-test-exit.txt`, `functions-test.log`, `git-diff-check.log`, `git-diff-name-status.txt`, `git-diff-stat.txt`, `git-status-short.txt`, `git-untracked.txt`, `include-paths.txt`, `inventory-before.json`, `no-network.cjs`, `preservation.json`, `report.cjs`.
  classification.json, include-paths.txt e exclude-paths.txt detalham as decisões;
  verificações finais adicionais nessa mesma pasta também permanecem locais.

COMMIT: não realizado. PUSH: não realizado. DEPLOY: não realizado.
Na auditoria inicial, git add/reset/checkout/restore/Discard Changes não foram
executados. O git add seletivo foi posteriormente autorizado e executado como abaixo.
Firebase produção, Oracle/GrandChef, Mercado Pago produção, Google Play e
Apple/Google produção: não acessados. Nenhuma instalação ou upload executado.

## RESULTADO DO STAGING SELETIVO APROVADO — 25/10/2026

A revisão humana aprovou a proposta deste relatório e autorizou somente staging
da lista de inclusão. Antes de alterar o índice, a lista auxiliar foi comparada
com todas as linhas INCLUIR do relatório, mais o próprio relatório: **116 caminhos
idênticos, únicos e existentes**, sem sobreposição com os 228 EXCLUIR.
Os 612 arquivos de referência permaneciam idênticos à auditoria aprovada.
O índice estava vazio. A lista foi congelada em arquivo NUL local, sem diretórios,
curingas ou pathspecs amplos; seus dados não contêm credenciais.

Comando seletivo executado:

```text
git --literal-pathspecs add --pathspec-from-file=tool/checkpoint_git_2026-10-25/staging/approved-paths.nul --pathspec-file-nul
```

Após atualizar este relatório, somente ele foi adicionado novamente pelo caminho
explícito já aprovado. Não foram usados git add ponto, -A ou --all. Nada foi
retirado do índice por segurança: nenhum arquivo staged apresentou risco real
que exigisse essa ação. Nenhum arquivo do workspace foi apagado/restaurado.

### Contagem e comandos de conferência

| Métrica final | Resultado |
| --- | ---: |
| STAGED TOTAL | **116** |
| STAGED MODIFICADOS | **54** |
| STAGED NOVOS | **62** |
| STAGED DELETADOS | **0** |
| STAGED RENOMEADOS | **0** |
| Outros estados staged | **0** |
| Excluídos da proposta encontrados staged | **0** |
| Arquivos removidos do staging por segurança | **0** |

Executados e registrados após o staging: `git status --short`,
`git diff --cached --stat` e `git diff --cached --name-status`.
Registros locais em `tool/checkpoint_git_2026-10-25/staging/`:
`git-status-short.txt`, `git-diff-cached-stat.txt` e
`git-diff-cached-name-status.txt`. Os 116 caminhos staged correspondem exatamente
à lista aprovada; nenhuma deleção/renomeação ou inclusão extra foi identificada.

### Segredos e revisão do diff staged

Auditoria local dos blobs do índice, usando `git show :caminho`, limitada aos
**112 arquivos de texto e 4 imagens staged**. Nenhum conteúdo foi enviado a
serviço externo. As imagens correspondem aos assets aprovados; não há captura
histórica local na lista. Não foram abertos key.properties, keystore ou env real.

Foram procurados password, secret, token, private_key, client_secret,
BEGIN PRIVATE KEY, storePassword e keyPassword. Ocorrências foram revisadas como
nomes de propriedades/variáveis, documentação ou fixtures explícitas de teste.
O campo secret de um teste de Rules é um sentinela sintético preexistente em
HEAD, sem relação com credencial real. Nenhum valor de segredo foi impresso.
Nenhuma chave privada, credencial de service account, token de produção
reconhecido ou JWT literal foi encontrado. **SEGREDOS: nenhum encontrado nos
arquivos staged pelos critérios auditados**; varredura por padrões não equivale
a garantia universal sobre todo o histórico Git.

Os caminhos absolutos identificados ficam em documentação de ambiente/custódia
e proveniência da arte aprovada. Não são usados pelo código para resolver
arquivos no aparelho de outro usuário. Ocorrências assets/images/home eram
falsos positivos da busca por /home/. Não foi identificado caminho pessoal de
execução desnecessário no código staged. Nenhum arquivo adicional foi julgado
duvidoso a ponto de exigir retirada do índice.

Revisados o diff funcional de Rules/backend, autenticação/limpeza, cotação,
checkout, assinatura Android e assets, além das dependências locais do conjunto.
**200 referências relativas verificadas, nenhuma ausente do índice**; quatro
assets novos necessários presentes. Nenhum marcador de conflito, deleção
acidental, arquivo gerado excluído ou regressão evidente identificado nessa
revisão. Isso não substitui revisão funcional completa ou homologação real.

Ressalva de formatação: `git diff --cached --check` retorna **exit 2**, com
avisos somente nos dois documentos oficiais de homologação: três linhas com
dois espaços finais usados como quebra Markdown e duas linhas vazias adicionais
no EOF. É diferença em relação ao check inicial, que não incluía esses arquivos
novos. Nenhum desses documentos foi editado nesta etapa para normalizar formato.
Detalhes locais em `git-diff-cached-check.txt`.

### Exclusões e preservação

- KEY.PROPERTIES: não staged; ignorado por android/.gitignore.
- KEYSTORE: upload key oficial permanece fora do repositório; nenhuma jks/keystore staged.
- ANDROID.LOCAL.PROPERTIES: não staged.
- GENERATED PLUGIN REGISTRANTS: Java e Objective-C não staged.
- Build, backups, caches, temporários, logs e capturas/evidências excluídas: não staged.
- Nenhum arquivo local sensível ou credencial de produção identificado na seleção.
- **228/228 arquivos da lista de exclusão preservados byte a byte**, somente fora
  do checkpoint. Artefatos locais desta auditoria/staging também permanecem fora.
- Fontes e testes não alterados; somente este relatório foi atualizado. HEAD sem mudança.
- Os três gerados/locais já rastreados continuam rastreados em HEAD: não houve
  remoção, desrastreamento ou tentativa de limpar o histórico.

Os resultados anteriores continuam sendo analyze sem issues, 209/209 Flutter e
414/414 Functions. Testes não foram reexecutados nesta etapa exclusivamente de
staging; código idêntico ao estado aprovado. Gates e status de homologação externa
não foram alterados. `audit.json`, `structural-review.json` e a verificação final
local registram nomes, contagens e conclusões sem valores de credenciais.

DIFF STAGED: **coerente**, com ressalvas documentais de formatação descritas acima.
RISCO APÓS STAGING: **MÉDIO**, pelo volume e alcance dos KBs; os riscos de inclusão
ampla/credenciais foram mitigados pela seleção exata e conferência do índice.
COMMIT RECOMENDADO: **sim**, após revisão humana final; nenhuma autorização para
executar commit foi usada nesta etapa.

MENSAGEM RECOMENDADA: `chore: checkpoint local pré-homologação do Chamaê Delivery`.

GIT ADD: executado seletivamente. COMMIT: não realizado. PUSH: não realizado.
DEPLOY: não realizado. Produção/serviços externos: não acessados.

**Parado para revisão humana.**
