# Captura visual local no NUU M2

Esta entrada é exclusiva de homologação visual em debug. Não chama Firebase.initializeApp/Auth/Firestore/Functions, não aceita documentos e não grava dados no backend. `main()` encerra com erro se `kDebugMode` for falso. O app normal continua usando `lib/main.dart` e não importa esta pasta.

As telas são os widgets de produção. Perfil usa o double de onboarding existente e doubles de conta em `test/support/customer_flow_fakes.dart` somente em memória. Preços, estoque, endereço, mensagens e estado pago são fixtures, não evidência de produção. O QR codifica `LOCAL-VISUAL-NOT-A-PAYMENT`, sem payload PIX.

```powershell
flutter build apk --debug --target tool/visual_device/main.dart
```

Rotas iniciais são selecionadas pelo extra `route` de FlutterActivity, por exemplo `/home`, `/categories`, `/product`, `/checkout-footer`, `/chat-keyboard`, `/map-footer`, `/pix-paid`. A faixa superior identifica dados controlados. A automação percorre widgets existentes e posiciona o scroll; Produto também foi aberto por toque ADB para conferir o modal real.

`capture.ps1` reinicia apenas o processo local e salva screenshots físicos via `adb shell screencap`/`adb pull`. O QR foi gerado com `qr` 3.0.2 já em cache; a matriz está versionável em `local_qr.dart`, sem adicionar dependências ao aplicativo.

O Maps usa o widget e configuração existentes, sem GPS automático. A ausência de tiles deve ser registrada como limite da integração. Não alterar chaves/Routes para embelezar a captura. Não acionar botões de login, PIN, pedido, pagamento ou chat remoto a partir do harness; as rotas de homologação usam dados locais.

Após as capturas, reconstruir o aplicativo normal com `flutter build apk --debug`. O relatório distingue screenshots anteriores integrados das capturas locais finais.
Artefatos desta execução: `build/visual_device/customer-normal-debug.apk` (entrada normal) e `build/visual_device/visual-debug.apk` (captura local). O artefato `build/app/outputs/flutter-apk/app-debug.apk` foi conferido como cópia do APK normal.