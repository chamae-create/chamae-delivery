# FlutterFire oficial — fechamento 03 — 18/10/2026

## Auditoria antes da regeneração

O arquivo localizado foi `lib/firebase_options.dart`. Android/iOS ainda estavam bloqueados de forma explícita pela etapa 02, sem opções móveis antigas ativas. Web já estava correta no projeto `chamae-delivery` e deveria ser preservada; macOS e Windows tinham opções próprias que também foram preservadas.

Os arquivos oficiais recebidos foram lidos localmente. Consulta somente de leitura com Firebase CLI (`apps:list --project chamae-delivery --json`) confirmou a existência dos dois novos apps e do app Web existente. Nenhum app foi criado, removido ou alterado por esta etapa. Snapshots dos arquivos anteriores foram salvos em `.dart_tool/flutterfire_stage03_before` antes da regeneração.

## ANDROID FIREBASE APP

- Package: **br.com.loumak.chamae**.
- appId: **1:302882774102:android:4c5058e95fed7870b92ff7**.
- projectId: **chamae-delivery**.
- Project number / messagingSenderId: **302882774102**.
- Arquivo oficial: `android/app/google-services.json`.

O JSON inclui exatamente um cliente correspondente ao package oficial. A seleção confere package, appId, API key pública do SDK, projectId, número e storage bucket contra as opções Dart finais. Clientes adicionais de outros apps continuam no JSON fornecido pelo Firebase; não foram escolhidos nem editados. Nenhum arquivo legado foi restaurado.

## IOS FIREBASE APP

- Bundle ID: **br.com.loumak.chamae**.
- appId: **1:302882774102:ios:e4e61ce4ae1ffcbfb92ff7**.
- projectId: **chamae-delivery**.
- Messaging sender ID: **302882774102**.
- Arquivo oficial: `ios/Runner/GoogleService-Info.plist`.

Bundle ID, GOOGLE_APP_ID, PROJECT_ID, API_KEY, GCM_SENDER_ID e STORAGE_BUCKET do plist coincidem com as opções Dart. O Bundle ID do Runner já é o oficial nas três configurações de build.

O arquivo existia no disco, mas não estava referenciado pelo Xcode. O FlutterFire executado no Windows não modificou o projeto iOS. Foram adicionadas localmente as referências PBXFileReference/PBXBuildFile, o item no grupo Runner e a entrada na fase Resources do target Runner. Isso inclui o plist no pacote do app ao compilar no Xcode. Nenhum Team ID, signing, entitlement ou OAuth scheme foi inventado.

## WEB

**Preservada.**

- appId: **1:302882774102:web:ebcfd1d1c59a7cc3b92ff7**.
- projectId: **chamae-delivery**.
- authDomain: **chamae-delivery.firebaseapp.com**.
- storageBucket: **chamae-delivery.firebasestorage.app**.

A CLI recebeu o app Web por ID explícito. Todos os valores do bloco Web foram comparados com o snapshot anterior e permaneceram iguais. A configuração de persistência Firebase Auth LOCAL e o fluxo Web existente não foram alterados. As opções e os mapeamentos desktop preexistentes foram preservados.

## FIREBASE_OPTIONS

**Regenerado com FlutterFire CLI 1.4.1**, já instalado no cache global Dart. O executável não estava no PATH; foi chamado pelo caminho completo.

Comando executado em PowerShell na raiz do projeto:

```powershell
& "$env:LOCALAPPDATA/Pub/Cache/bin/flutterfire.bat" configure --project=chamae-delivery --platforms=android,ios,web --android-package-name=br.com.loumak.chamae --ios-bundle-id=br.com.loumak.chamae --web-app-id=1:302882774102:web:ebcfd1d1c59a7cc3b92ff7 --out=lib/firebase_options.dart --yes
```

Resultado da CLI: sucesso, código 0, com os três app IDs oficiais listados. Não foram montadas FirebaseOptions a partir de cadastros antigos, inventados IDs ou alterado o Firebase Project.

Pós-processamento local:

- Corrigido o comentário histórico de bloqueio que a CLI preservou no cabeçalho; o arquivo agora identifica a geração FlutterFire.
- Preservados os mapeamentos macOS/Windows que a CLI deixou fora da seleção solicitada.
- Incluído o mapeamento iOS/default no firebase.json com o appId do plist validado e `uploadDebugSymbols:false` (sem integração Crashlytics). O mapeamento Android/default e as três opções Dart vieram da CLI.
- Formatados apenas o arquivo de opções e os testes de configuração alterados.
- Verificado que as seções Functions, Firestore Rules e índices em firebase.json não foram alteradas.

Os dois arquivos nativos oficiais permaneceram idênticos aos recebidos, sem edições de conteúdo.

Logs da auditoria/geração: `tool/flutterfire_apps_audit.log` e `tool/flutterfire_stage03_configure.log`.

## INICIALIZAÇÃO MÓVEL

**Liberada na configuração local.**

`DefaultFirebaseOptions.currentPlatform` agora retorna `android` ou `ios` com os app IDs oficiais. Os bloqueios temporários foram removidos pela regeneração somente após confirmar os cadastros e a consistência dos arquivos. `initializeCustomerSession` continua inicializando Firebase com essas opções e aguardando restauração da sessão; não foi modificado para criar identidade anônima nova.

Os testes temporários que esperavam o bloqueio foram substituídos por testes de correspondência aos arquivos oficiais, seleção de plataforma, mapeamentos e inclusão do plist no Runner. A inicialização efetiva dos SDKs em aparelho não foi executada no Windows e requer homologação nativa.

## TESTES

- Configuração/init (seleção de opções), autenticação, sessão e diálogo Google: **31 testes aprovados**. Comando: `flutter test test/production_firebase_configuration_test.dart test/customer_auth_test.dart test/customer_flow_test.dart test/google_login_test.dart --reporter expanded`. Log: `tool/flutterfire_stage03_targeted.log`.
- Suíte Flutter completa: **95 testes aprovados**, nenhuma falha (`flutter test --concurrency=2 --reporter expanded`). Log: `tool/flutterfire_stage03_suite.log`.
- `flutter analyze`: **No issues found**, 52,3 segundos. Log: `tool/flutterfire_stage03_analyze.log`.
- `git diff --check`: aprovado.
- Android: `flutter build apk --debug` executado; código 1, **No Android SDK found. Try setting the ANDROID_HOME environment variable.** Nenhum APK foi gerado. Log: `tool/flutterfire_stage03_build_android.log`.
- iOS: não compilado neste ambiente Windows; depende de macOS/Xcode.
- `flutter build web --release`: **aprovado**, código 0; gerado `build/web` em 115,4 segundos. Artefato somente local, sem deploy. Log: `tool/flutterfire_stage03_build_web.log`.

Os testes usam SDKs/dados simulados para o fluxo de autenticação; conferem os arquivos oficiais reais para os testes de configuração. Não representam execução dos SDKs Firebase nativos em aparelho nem login Google real.

## BLOQUEADORES

**Não há inconsistência conhecida que impeça a geração das opções FlutterFire ou exija manter o bloqueio temporário móvel.** Permanecem pendências para executar e homologar as plataformas e autenticação real:

- Android SDK não localizado neste ambiente; sem build Android concluído. JRE portátil não substitui a toolchain Android/JDK completa.
- iOS exige macOS/Xcode para resolver dependências nativas, compilar, assinar e testar a inicialização real.
- Google Auth: listas `oauth_client` do JSON oficial continuam vazias; plist não contém CLIENT_ID/REVERSED_CLIENT_ID e Info.plist não declara o URL scheme Google. A flag IS_SIGNIN_ENABLED do plist não comprova habilitação do provedor Google no Firebase Console. Configurar o provedor, certificados reais e OAuth, baixar os arquivos atualizados e homologar o login Google.
- Keystore debug/fingerprints e assinatura de distribuição continuam pendentes conforme auditoria Android anterior. Nenhum SHA/OAuth ID foi fabricado.
- A troca de package/bundle não transfere automaticamente o armazenamento local das instalações antigas; a transição de usuários anônimos requer o cuidado descrito na etapa 02.

Essas pendências não foram confundidas com incompatibilidade dos novos Firebase app IDs. Não foram alterados Apple Auth externo, Routes, frete, documentos jurídicos, pagamentos, estoque, chat, catálogo ou jornada UX. Nenhum deploy, commit ou push.

**FLUTTERFIRE MÓVEL CONFIGURADO**
