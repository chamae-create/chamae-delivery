# Identificadores oficiais de produção — fechamento 02 — 18/10/2026

> Registro histórico da etapa 02. As pendências de novos apps Firebase, opções móveis e inclusão do plist foram tratadas na [etapa 03](flutterfire_mobile_configuration_2026-10-18.md); consultar esse relatório para a situação atual. As contagens e os bloqueios descritos abaixo representam o fechamento da etapa 02.

## IDENTIFICADOR OFICIAL

`br.com.loumak.chamae`

## Auditoria prévia e arquivos afetados

A busca antes de alterar configurações encontrou 18 ocorrências do prefixo temporário: 2 no Gradle Android, 1 no package Kotlin, 6 no Xcode, 1 nas opções Firebase iOS, 1 no JSON Google Services, 2 no checklist das lojas e 5 na auditoria Google anterior. Também foram auditados firebase.json, manifests main/debug/profile, Info.plist, AppDelegate, registrantes Flutter, testes/scripts e configurações desktop. Nenhum AGENTS.md aplicável foi encontrado.

Arquivos alterados nesta etapa:

- `android/app/build.gradle.kts`: applicationId, namespace e comentário de identificação.
- `android/app/src/main/kotlin/br/com/loumak/chamae/MainActivity.kt`: movida do diretório anterior e package atualizado; continua estendendo FlutterActivity.
- `ios/Runner.xcodeproj/project.pbxproj`: três configurações Runner e três RunnerTests.
- `lib/firebase_options.dart`: removidas opções móveis vinculadas aos apps antigos; inicialização móvel bloqueada com instrução explícita até gerar as configurações oficiais. Opções Web/desktop preservadas.
- `firebase.json`: removidos somente mapeamentos FlutterFire Android/iOS antigos. Configurações de Functions, Rules e índices não foram alteradas por esta etapa.
- `docs/config/firebase_legacy/android/google-services.json`: arquivo anterior movido sem modificar o conteúdo; README marca incompatibilidade e proíbe uso no build.
- `docs/app_cliente_store_checklist_2026-10-18.md`: atualizados somente os dois itens de identificadores Android/iOS.
- `docs/google_authentication_audit_2026-10-18.md`: aviso no início identifica o conteúdo como auditoria histórica substituída pela etapa 02.
- `test/production_firebase_configuration_test.dart`: testes da recusa de configuração móvel legada e preservação do Firebase Web.
- Este relatório e logs locais de validação em `tool/production_identifiers_*.log`.

## ANDROID

- applicationId final: **br.com.loumak.chamae**.
- namespace final: **br.com.loumak.chamae**.
- MainActivity/package final: **br.com.loumak.chamae.MainActivity**, arquivo em `android/app/src/main/kotlin/br/com/loumak/chamae/MainActivity.kt`.
- Existe `android/app/build.gradle.kts`; não existe build.gradle alternativo no app.
- Manifest usa `.MainActivity`, resolvida pelo novo namespace. Não havia package fixo, authorities ou callback com o identificador antigo. MAIN/LAUNCHER, permissões, metadados e Flutter embedding 2 foram preservados. Registrante em io.flutter.plugins não representa o package do aplicativo e não deve ser renomeado.
- Release continua usando assinatura debug preexistente; distribuição exige assinatura oficial e fingerprints reais.

## IOS

- Bundle ID final Runner: **br.com.loumak.chamae**, nas configurações Debug/Profile/Release.
- RunnerTests: **br.com.loumak.chamae.RunnerTests**, nas três configurações.
- `Info.plist` já usa `$(PRODUCT_BUNDLE_IDENTIFIER)`; não precisou de edição. AppDelegate e registro de plugins preservados.
- Não foram encontrados URL schemes Google, entitlements, Associated Domains, universal links, capability Sign in with Apple ou Team ID configurado no projeto auditado. Nenhum desses valores foi inventado.

## FIREBASE

Projeto mantido: **chamae-delivery**, número **302882774102**. Web permanece no app `1:302882774102:web:ebcfd1d1c59a7cc3b92ff7`, authDomain `chamae-delivery.firebaseapp.com`. Não é necessário trocar o Firebase Project ID por causa do novo identificador nativo. Console não acessado nem alterado.

Registrar manualmente dois novos apps nesse mesmo projeto:

1. Android, package **br.com.loumak.chamae**.
2. iOS, Bundle ID **br.com.loumak.chamae**.

O JSON anterior continha dois packages diferentes do oficial e listas OAuth vazias. Está **INCOMPATÍVEL PARA PRODUÇÃO APÓS A MUDANÇA** e foi retirado de `android/app`. Seu conteúdo original está em `docs/config/firebase_legacy/android/google-services.json`, somente para auditoria. O plist iOS nunca esteve presente. Nenhum ID interno Firebase foi editado para aparentar um novo cadastro.

Após registrar os novos apps:

1. Obter o novo `android/app/google-services.json` e conferir project ID, package e appId oficiais.
2. Obter `ios/Runner/GoogleService-Info.plist` do novo app e adicioná-lo ao target Runner no Xcode.
3. Regenerar `lib/firebase_options.dart` e os mapeamentos FlutterFire em `firebase.json` usando os apps oficiais; conferir os IDs gerados pelo Firebase. Preservar os apps Web/desktop já existentes. A regeneração deve substituir os bloqueios temporários Android/iOS; não basta copiar o JSON/plist.
4. Conferir que as opções Android correspondem ao JSON novo e que iosBundleId é o oficial. Não copiar IDs internos dos cadastros antigos nem fabricar FirebaseOptions. Atualizar os testes temporários de bloqueio móvel para validar a correspondência das novas opções oficiais quando a configuração for concluída.

Com o estado atual, o build Android não dispõe de JSON ativo e a inicialização móvel Firebase recusa as opções antigas. Isso torna o bloqueador explícito em vez de executar silenciosamente contra o cadastro incorreto. Web permanece utilizável com sua configuração existente.

## GOOGLE AUTH

O adapter não foi alterado: Firebase popup na Web; ID token Google → credencial Firebase no Android/iOS; linking da sessão existente mantém UID; conflitos exigem escolha explícita sem merge automático. Testes de autenticação e sessão continuam fazendo parte da validação.

Pendências externas:

- Habilitar **Authentication → Sign-in method → Google**, informar e-mail de suporte real e salvar.
- Adicionar SHA-1/SHA-256 dos certificados reais ao novo app Android. Fingerprints debug continuam indisponíveis: keystore padrão ausente. Não foram gerados valores fictícios.
- Baixar o JSON atualizado com cliente OAuth Web; configurar `GOOGLE_SERVER_CLIENT_ID` somente com o Web Client ID real se necessário. O ID Android OAuth não substitui esse valor.
- No iOS, obter client ID/reversed client ID reais do novo cadastro e configurar URL scheme e plist. `GOOGLE_IOS_CLIENT_ID`/`GOOGLE_SERVER_CLIENT_ID` continuam disponíveis no adapter para valores oficiais.
- Conferir domínios Web autorizados e configurações OAuth oficiais. O authDomain Web não mudou por causa da troca de package. Nenhum callback/redirect foi inventado.
- Homologar login, cancelamento, rede, restauração e linking no aparelho/browser após as configurações.

### Identidades existentes e armazenamento local

Mudar package/bundle produz outra identidade de aplicativo para o sistema operacional; dados de sessão locais do app antigo não devem ser presumidos disponíveis no novo. O código não cria nem transfere uma conta anônima para compensar isso.

Se houver usuários reais anônimos no app antigo, vincular primeiro uma identidade recuperável no aplicativo antigo e homologar o login no novo, mantendo o mesmo projeto Firebase. Conferir explicitamente UID e acesso aos registros antes de distribuir a mudança. Uma credencial que já pertença a outra conta continuará exigindo tratamento de conflito; não autoriza mesclar contas. Uma sessão anônima abandonada pode ficar inacessível. Não apagar os apps/cadastros Firebase antigos antes de avaliar a transição.

Não houve migração, reatribuição, exclusão ou alteração de pedidos, endereços, perfil, carrinho, chat, histórico ou PIN nesta etapa.

## APPLE

Impacto: o Bundle ID do app mudou. Um futuro cadastro Apple Developer/App Store Connect, App ID explícito, provisioning e configuração Apple/Firebase devem corresponder ao identificador oficial. Não foi configurado Apple Auth externo, Team ID, Service ID, chave, capability ou redirect.

Se existirem cadastros externos anteriores não presentes no repositório, o operador deverá auditar sua compatibilidade. Nenhuma configuração externa foi presumida.

## Deep links e callbacks

Não há deep link/scheme OAuth/universal link/Associated Domain com o identificador antigo nos arquivos auditados. Android só declara MAIN/LAUNCHER e consulta PROCESS_TEXT; Info.plist não declara CFBundleURLTypes. As strings de fornecedores e plugins, como com.google.android.geo.API_KEY e io.flutter.plugins, são necessárias e não são identificadores temporários do app.

Google no iOS ainda precisa do URL scheme oficial. Redirects OAuth e domínios devem vir dos consoles oficiais quando configurados. Não foi feita substituição textual em URLs nem criado callback por suposição.

## TESTES

- Autenticação, sessão e configuração Firebase: **29 aprovados**, com `flutter test test/customer_auth_test.dart test/customer_flow_test.dart test/google_login_test.dart test/production_firebase_configuration_test.dart --reporter expanded`. Log: `tool/production_identifiers_auth.log`.
- Suíte Flutter completa: **93 aprovados**, com `flutter test --concurrency=2 --reporter expanded`. Log: `tool/production_identifiers_suite.log`.
- `flutter analyze`: **No issues found**, 14,6 segundos. Log: `tool/production_identifiers_analyze.log`.
- Android: `flutter build apk --debug` tentou compilar e terminou com código 1: **No Android SDK found. Try setting the ANDROID_HOME environment variable.** Não foi produzido APK. Log: `tool/production_identifiers_build_android.log`. Mesmo após instalar o SDK, o JSON oficial ainda será necessário.
- iOS: não compilado; ambiente Windows sem macOS/Xcode.
- Build Web release: **aprovado**, `flutter build web --release --no-wasm-dry-run`, gerado `build/web` em 57,2 segundos. Log: `tool/production_identifiers_build_web.log`. Artefato apenas local, sem deploy.

Os testes de autenticação usam doubles de SDK; não atestam OAuth externo nem transferência de sessões entre instalações. O novo teste verifica que as opções Firebase móveis antigas não são reutilizadas silenciosamente, e que o app Web segue com o mesmo cadastro.

## OCORRÊNCIAS DE COM.EXAMPLE

- Quantidade antes: **18** ocorrências em 7 arquivos.
- Quantidade depois: **6** ocorrências em 2 arquivos; **zero em configuração ativa Android/iOS/Dart**.
- Método: `rg --hidden -n` na raiz, buscando o prefixo temporário com ponto literal, respeitando .gitignore e excluindo .git. Contagem por ocorrência, não por arquivo. Evidência inicial em `.dart_tool/production_identifiers_before.json`.
- **Documentação, 5 ocorrências:** auditoria Google da etapa 01; dados históricos e instruções anteriores explicitamente marcados como substituídos no início do arquivo.
- **Legado, 1 ocorrência:** JSON original arquivado sob docs/config/firebase_legacy; não é consumido pelo Gradle nem mapeado em firebase.json.
- **Necessárias em configuração ativa:** nenhuma.
- **Erros a corrigir:** nenhum identificador temporário ativo encontrado.

Outra identificação anterior encontrada: o cadastro macOS nas opções Firebase usa o identificador próprio daquele app, diferente do novo Android/iOS. Foi preservado: esta etapa não migra macOS nem inventa outro cadastro Firebase. O segundo package do JSON arquivado também permanece somente como evidência histórica.

A busca adicional incluindo arquivos ignorados, mas excluindo dependências, caches, build e .git, encontrou os mesmos dois arquivos. Outra varredura incluiu caches e build e continuou encontrando somente esses dois arquivos; apenas .git e node_modules de terceiros foram excluídos. Exemplos internos de dependências não são identificadores deste aplicativo e não devem ser renomeados.

## BLOQUEADORES

- Registrar os dois apps Firebase oficiais e obter seus novos IDs/arquivos gerados.
- Regenerar opções Dart e mapeamentos FlutterFire; mobile permanece bloqueado até isso acontecer.
- Configurar Google OAuth/certificados/domínios e homologar Google real com o novo identificador.
- Instalar/configurar Android SDK/JDK; keystore debug ausente. Preparar assinatura release oficial.
- Build/archive iOS requer macOS/Xcode, signing/provisioning e arquivos Firebase oficiais.
- Avaliar transição de instalações antigas com sessões anônimas antes de distribuir o novo package/bundle.

Não foram alterados Google Routes, frete, Termos/Política, Apple Auth externo, regras financeiras, estoque, PIX, chat, jornada UX ou catálogo. Nenhum deploy, commit ou push.

**MIGRAÇÃO DE IDENTIFICADORES AINDA POSSUI BLOQUEADORES**
