# Primeiro build iOS no Codemagic

## Preparado

- `codemagic.yaml`: workflow manual `ios-unsigned`, macOS M2, Flutter **3.47.5** (mesma versão do SDK local), Xcode mais recente e CocoaPods disponível. Checkout automático do Codemagic, `pub get --enforce-lockfile`, análise, teste focado de configuração Firebase e `flutter build ios --debug --no-codesign --no-pub`.
- Artefato: `build/ios/iphoneos/Runner.app` sem assinatura; serve para provar compilação, não para instalar em iPhone ou enviar ao TestFlight/App Store. Não há publicação nem gatilhos automáticos.
- Bundle ID **`br.com.loumak.chamae`**, consistente em Debug/Release/Profile, plist Firebase e `firebase_options.dart`. Plist Firebase já incluído nos recursos do Runner; credenciais existentes preservadas.
- Projeto/workspace/scheme compartilhado, AppDelegate/SceneDelegate e integração Swift Package Manager presentes. `Podfile` de fallback e includes CocoaPods preparados para plugins que ainda precisam de pods. O próprio `flutter build ios` resolve a integração nativa; não executar `pod install` antes do Flutter preparar o projeto.
- Deployment target **iOS 15.0**. Firebase requer iOS 15; as dependências nativas finais serão resolvidas e verificadas no macOS. Localização em uso já declarada; fallback geolocator configurado para dispensar permissão permanente. Catálogos de ícones/launch assets presentes; aprovação visual dos ícones fica para a publicação.
- Nenhuma dependência direta exclusivamente Android identificada. Windows não valida compilação Swift, resolução de pods/SPM ou linkedição; o primeiro build macOS é a confirmação.

## Pendências externas futuras (não bloqueiam o build sem assinatura)

- Google Sign-In: o plist atual não contém `CLIENT_ID`/`REVERSED_CLIENT_ID` e o Info.plist não declara o URL scheme de retorno. Obter os IDs oficiais do app iOS; configurar o scheme real. O Dart já aceita `GOOGLE_IOS_CLIENT_ID` e `GOOGLE_SERVER_CLIENT_ID` por `--dart-define`; nenhum valor foi criado nesta rodada.
- Apple: o código usa `AppleAuthProvider`, mas falta configurar capability/entitlement Sign in with Apple, App ID e provedor no Firebase. Não houve acesso nem alteração no Firebase de produção.
- Maps: `Info.plist`/AppDelegate já leem a build setting Xcode `CHAMAE_MAPS_API_KEY`; falta fornecer a chave autorizada para Maps SDK for iOS e restringi-la ao Bundle ID. Uma variável no painel não basta: futuramente passá-la explicitamente ao Xcode ou gerar um xcconfig privado. Não confundir com `--dart-define`.
- Assinatura/publicação: Apple Team ID, certificados, provisioning profiles e App Store Connect API key/IDs serão fornecidos pelo titular, armazenados no Codemagic e integrados em outro workflow. Nada disso é exigido aqui.

## Conectar GitHub e iniciar

1. Os arquivos estão apenas locais. Após revisão e autorização do responsável, versionar e enviar ao GitHub todos os arquivos necessários, inclusive assets referenciados e o lockfile. Esta rodada não faz commit nem push.
2. No Codemagic, conectar GitHub, autorizar o repositório e adicionar o aplicativo. Selecionar configuração por **codemagic.yaml** na raiz.
3. Selecionar a branch que contém esses arquivos e **Start new build → ios-unsigned → Start new build**. Não cadastrar assinatura ou variáveis secretas para este workflow.
4. Conferir análise, testes, resolução de dependências e etapa de compilação. Baixar `Runner.app` e logs em Artifacts. Registrar a versão de Xcode usada pelo primeiro build verde para eventual fixação posterior.

## Depois: Apple Developer / App Store Connect

1. Ativar a conta Apple Developer; registrar/confirmar o App ID `br.com.loumak.chamae` e habilitar Sign in with Apple.
2. Configurar os provedores e retorno OAuth oficiais; validar login, localização e mapas em dispositivo com assinatura de desenvolvimento.
3. Criar o app no App Store Connect, preparar certificados/perfis e API key com permissões adequadas. Só então criar e autorizar um workflow assinado para TestFlight/App Store.

Referências: [Flutter no Codemagic](https://docs.codemagic.io/yaml-quick-start/building-a-flutter-app/) e [Swift Package Manager e fallback CocoaPods](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers).
