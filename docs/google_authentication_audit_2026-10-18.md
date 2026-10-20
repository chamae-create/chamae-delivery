# Google Authentication — fechamento 01 — 18/10/2026

> Auditoria histórica anterior à migração dos identificadores. Os packages, caminhos ativos e instruções de seleção dos apps abaixo foram substituídos pela etapa 02. Para a configuração atual, siga [a migração de produção](production_identifiers_migration_2026-10-18.md). O JSON antigo está arquivado em docs/config/firebase_legacy/android e não deve ser reutilizado para produção.

## Auditoria antes de alterações

Nenhuma configuração Firebase, Android, iOS ou Web foi alterada nesta etapa. Console não acessado; o operador informou anteriormente que Google ainda não está habilitado. Nenhum deploy, commit ou push.

| Item | Encontrado localmente |
| --- | --- |
| Android applicationId | `com.example.chamae_delivery` |
| Android namespace / package Kotlin | `com.example.chamae_delivery` |
| iOS Bundle ID Runner (Debug/Profile/Release) | `com.example.chamaeDelivery` |
| Firebase Project ID / project number | `chamae-delivery` / `302882774102` |
| Android Firebase app ID em firebase_options.dart | `1:302882774102:android:621044625161ed6cb92ff7` |
| iOS Firebase app ID | `1:302882774102:ios:dfb16d465c042541b92ff7` |
| Web Firebase app ID | `1:302882774102:web:ebcfd1d1c59a7cc3b92ff7` |
| Web authDomain | `chamae-delivery.firebaseapp.com` |
| firebase_auth | restrição `^6.7.0`, resolvido `6.7.0` |
| google_sign_in | restrição `^7.2.0`, resolvido `7.2.0` |

`android/app/google-services.json` existe e corresponde ao projeto e ao appId/package Android efetivamente compilado. Contém também outro cliente `com.chamae.delivery`, que não é o applicationId atual. Ambos têm `oauth_client: []`; não fornecem o cliente OAuth Web necessário ao Google nativo. Não trocar o package por suposição.

`ios/Runner/GoogleService-Info.plist` não existe e não há outro arquivo com esse nome no projeto. `Info.plist` não declara `GIDClientID` nem `CFBundleURLTypes` para o reversed client ID Google. O Bundle ID do Runner coincide com firebase_options.dart; o ID macOS é diferente e não deve ser reutilizado para iOS.

Web inicializa Firebase com DefaultFirebaseOptions.web. Usa GoogleAuthProvider + Firebase popup; não depende do botão/SDK Google Identity Services no HTML. Persistência `LOCAL` é configurada antes de aguardar a primeira sessão restaurada. Domínios efetivamente autorizados no Console não podem ser inferidos do código.

## Código e fluxo de identidade

- Android/iOS: `google_sign_in` initialize → authenticate → ID token → `GoogleAuthProvider.credential(idToken: ...)` → Firebase Authentication.
- Web: `linkWithPopup(GoogleAuthProvider)` se existe sessão aproveitável; `signInWithPopup` quando não existe. O popup executa a obtenção da credencial no SDK Firebase.
- Android/iOS com sessão: `old.linkWithCredential` mantém o UID; sem sessão: `signInWithCredential`. Após sucesso o adapter valida UID no linking, recarrega usuário e força renovação do ID token.
- Windows/Linux/macOS nativos não possuem fluxo Google implementado neste adapter; retornam mensagem amigável. A presença de opções Firebase para desktop não significa suporte Google nativo.
- Inicialização aguarda restauração Firebase; não cria uma conta anônima nova. Sessões anônimas preexistentes seguem disponíveis para linking. O gate acompanha idTokenChanges, faz refresh e descarta rotas privadas ao mudar UID/logout.
- Cancelamento Google nativo e popup, falha de rede, provedor indisponível e credencial em uso recebem mensagens próprias/amigáveis, sem expor Firebase exception.message. Loading desabilita ambos os botões; a guarda `_busy` impede reentrada.

O adapter já atendia ao linking; não foi reescrito nem trocado o mecanismo de autenticação.

### Dados preservados pelo UID

Pedidos/histórico usam `orders.customerUid`, workspace usa `customerWorkspaces/{uid}` (endereços, contato, carrinho e destino), perfil usa `customerProfiles/{uid}`, PIN privado usa `customerDeliverySecrets/{uid}`. Chat depende do pedido e de sua autorização pelo proprietário. O linking mantém o mesmo UID, portanto não precisa copiar, apagar ou reatribuir esses registros. Nenhuma migração desses dados é executada pelo login.

Os testes locais verificam chamadas ao adapter/SDK simulado e identidade da sessão; não substituem homologação com os dados reais de todas essas coleções. Após habilitar Google, conferir cada recurso com uma conta anônima de teste já preenchida.

### Credencial Google já vinculada a outro UID

`credential-already-in-use`, `account-exists-with-different-credential` e `email-already-in-use` produzem conflito explícito. Não existe fallback automático para signIn, merge ou exclusão. Cancelar mantém o UID original.

Problema confirmado e corrigido nesta etapa: o diálogo não explicitava que sair de uma sessão anônima pode tornar os dados antigos inacessíveis. Agora o aviso informa essa consequência e exige escolher **Trocar de conta**. Somente essa escolha chama signIn com `useExistingAccount:true`; os registros antigos permanecem no UID antigo e não aparecem na conta de destino. Uma sessão anônima abandonada pode não ser recuperável. Quem precisa preservar acesso deve escolher **Voltar** e vincular uma identidade Google ainda não utilizada; atendimento/migração eventual exige processo separado, sem automação destrutiva. Perfil já impede essa troca e permite apenas linking.

`account-exists-with-different-credential` também pode exigir autenticar pelo provedor original da conta; repetir Google não garante resolução. Não apresentar isso como conta mesclada ou recuperação concluída.

## Checklist manual do operador

1. Abrir o projeto **chamae-delivery** no Firebase Console. Em **Authentication → Sign-in method → Google**, habilitar Google, selecionar o e-mail de suporte válido e salvar. Conferir as configurações reais de OAuth do projeto; não criar IDs fictícios.
2. Em **Project settings → General → Your apps**, selecionar o Android **com.example.chamae_delivery** (não o outro cadastro). Registrar SHA-1 e SHA-256 do certificado realmente usado em cada ambiente. Adicionar certificado debug quando existir; antes da distribuição, adicionar os certificados release/Play App Signing correspondentes. Cada certificado tem fingerprints diferentes.
3. Baixar novamente `google-services.json` depois da habilitação/registro e substituir o arquivo local somente após conferir project ID, package e appId. Confirmar cliente OAuth do tipo Web (`client_type:3`) para o plugin gerar `default_web_client_id`. Alternativamente o adapter recebe `GOOGLE_SERVER_CLIENT_ID` via dart-define, usando exclusivamente o Web Client ID real desse projeto. Não usar o Android client ID nesse campo.
4. Em **Authentication → Settings → Authorized domains**, conferir o domínio efetivo da versão Web e, para teste, localhost se necessário. Não presumir que localhost está autorizado. Conferir `chamae-delivery.firebaseapp.com` usado como authDomain. Usar apenas URLs de retorno fornecidas pela configuração oficial do Firebase/OAuth, se houver necessidade de ajustar OAuth no Google Cloud. Não foi inventado redirect URI.
5. Para Google no iOS, selecionar o app **com.example.chamaeDelivery** no Firebase, obter seu `GoogleService-Info.plist` oficial e adicionar ao target Runner. Configurar o client ID iOS e URL scheme com o `REVERSED_CLIENT_ID` real; o adapter também aceita `GOOGLE_IOS_CLIENT_ID` e `GOOGLE_SERVER_CLIENT_ID` por dart-define. O URL scheme continua necessário. Conferir target membership/configurações no Xcode. Isso é Google no iOS; nenhuma configuração Apple Auth faz parte desta etapa.
6. Homologar login Google real no Web/Android/iOS pretendidos: conta nova sem sessão, conta anônima com dados → mesmo UID, restauração após reinício, cancelamento, rede indisponível, credencial de outro UID → voltar/trocar explicitamente. Confirmar pedidos, histórico, endereços, perfil, carrinho, chat e PIN antes/depois do linking. Revogar sessão e conferir retorno seguro ao login.

## Android e fingerprints

`flutter doctor -v` confirma Flutter 3.47.5 / Dart 3.13.4 em `C:\flutter`; Android SDK não localizado. Não há Android Studio no caminho padrão nem SDK em `%LOCALAPPDATA%\Android\Sdk`. `android/local.properties` só informa flutter.sdk. JAVA_HOME, ANDROID_HOME e ANDROID_SDK_ROOT não estão definidos; java/keytool/adb/sdkmanager não estão no PATH.

Existe JRE portátil Temurin **21.0.12.1+1** em `.dart_tool/customer_validation_tools/jdk-21.0.12.1+1-jre`, com **java.exe e keytool.exe**, sem javac (não é JDK completo). O nome da pasta não significa JDK instalado. O keytool já está disponível por caminho completo; o impeditivo imediato à extração é a ausência de `%USERPROFILE%\.android\debug.keystore`. Nenhum keystore novo foi gerado por esta auditoria.

**SHA-1: indisponível. SHA-256: indisponível.** Não existe certificado debug local auditável no caminho padrão e não há keystore/jks no projeto.

Instalar/configurar Android SDK e JDK compatível com o Gradle/AGP atual (AGP 9.1.0, Java de compilação configurado 17), aceitar licenças e executar o build debug para produzir a chave debug padrão, caso ainda não exista. Depois, no PowerShell a partir da raiz:

```powershell
C:\flutter\bin\flutter.bat doctor -v
C:\flutter\bin\flutter.bat doctor --android-licenses
C:\flutter\bin\flutter.bat build apk --debug
& '.\.dart_tool\customer_validation_tools\jdk-21.0.12.1+1-jre\bin\keytool.exe' -list -v -alias androiddebugkey -keystore "$env:USERPROFILE\.android\debug.keystore" -storepass android
# Alternativa com o JDK configurado:
Push-Location android
.\gradlew.bat signingReport
Pop-Location
```

Se for usado outro keystore, ajustar o caminho/alias para os valores reais. A senha acima é apenas o padrão da chave debug Android. O comando keytool list informa SHA1 e SHA256; não cria fingerprint sem certificado.

A configuração release atual reutiliza signingConfigs.debug. Antes de publicação será necessário signing de distribuição e registro de seus certificados; não foi alterado nesta etapa.

## Validação local

- Testes específicos de autenticação, sessão e diálogo: **26 aprovados** (`flutter test test/customer_auth_test.dart test/customer_flow_test.dart test/google_login_test.dart --reporter expanded`).
- Suíte Flutter completa: **90 aprovados**, nenhuma falha (`flutter test --concurrency=2 --reporter expanded`).
- `flutter analyze`: **No issues found**.
- Chrome, os mesmos três arquivos: **25 aprovados, 1 ignorado** (cancelamento Google nativo, inaplicável no browser). Linking usa o caminho Firebase popup nos testes Web. Log: `tool/google_auth_chrome.log`. Foi usado o auxiliar local já existente `tool/chrome_test_assets.mjs` para servir CanvasKit do próprio SDK, contornando o servidor de testes Windows; nenhum SDK/app foi alterado para isso.
- Nove casos novos cobrem cancelamento Google nativo, erros Firebase de popup/rede/provedor, restauração sem novo login, escolha explícita após conflito, loading e as duas escolhas do diálogo.

Logs nesta etapa: `tool/google_auth_doctor.log`, `tool/google_auth_targeted.log`, `tool/google_auth_suite.log`, `tool/google_auth_analyze.log`. Testes usam doubles de SDK, sem contas/credenciais externas.

Não há como validar login OAuth real apenas com doubles de SDK; provider externo e plataformas precisam ser homologados após configuração. Documentos, frete, Routes e Apple Auth não foram alterados.

## Referências oficiais

- [Firebase: linking mantém o mesmo UID e usa linkWithCredential](https://firebase.google.com/docs/auth/flutter/account-linking).
- [Flutter Google Sign-In Android: configuração OAuth / server client ID](https://pub.dev/packages/google_sign_in_android).
- [Flutter Google Sign-In iOS: client IDs e URL scheme](https://pub.dev/packages/google_sign_in_ios).
