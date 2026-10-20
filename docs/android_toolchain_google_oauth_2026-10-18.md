# Android toolchain + Google OAuth — fechamento 04 — 18/10/2026

Projeto: `C:\Users\DELL\chamae_delivery`. Package oficial: **br.com.loumak.chamae**. Nenhuma instalação, download de ferramentas, alteração global de ambiente, alteração no Console, deploy, commit ou push foi executado nesta etapa.

## ANDROID SDK

**Não localizado.** `flutter doctor -v` informa `Unable to locate Android SDK`.

| Componente | Evidência local |
| --- | --- |
| SDK padrão | `C:\Users\DELL\AppData\Local\Android\Sdk` não existe |
| Android Studio | Ausente nos caminhos padrão em Program Files e LocalAppData/Programs; não encontrado nos registros de desinstalação consultados |
| sdk.dir | Não definido; android/local.properties contém somente flutter.sdk apontando para C:\flutter |
| adb / platform-tools | Não encontrados no PATH; SDK ausente |
| emulator / AVD | Executável não encontrado no PATH; diretório .android do usuário ausente; nenhum dispositivo Android listado pelo Flutter |
| sdkmanager / command-line tools | Não encontrados no PATH; SDK ausente |
| build-tools / plataformas / NDK | Nenhuma instalação encontrada no SDK padrão; não há SDK alternativo configurado no Flutter ou nas variáveis consultadas |
| ANDROID_HOME / ANDROID_SDK_ROOT | Não definidas nos escopos Process, User e Machine |

A auditoria consultou PATH, caminhos padrão, variáveis de ambiente persistentes, configuração Flutter, local.properties e registros de instalação. Não pressupõe varredura integral de todos os discos por instalações portáteis não configuradas.

O Flutter instalado resolve compileSdk/targetSdk **36** e NDK **28.2.13676358**, conforme `C:/flutter/packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt`.

## JDK

**JDK completo não encontrado/configurado.**

- JAVA_HOME vazio nos escopos Process, User e Machine.
- java, javac e keytool não encontrados no PATH.
- Não foram encontrados JDKs nos caminhos padrão Oracle/Temurin/Microsoft consultados nem nas entradas JavaSoft/Adoptium e registros de instalação consultados.
- Existe o JRE portátil já instalado anteriormente: `.dart_tool/customer_validation_tools/jdk-21.0.12.1+1-jre`.
- `java.exe -version` nesse caminho confirma **Temurin OpenJDK Runtime Environment 21.0.12.1+1**. Há java.exe e keytool.exe; **não há javac.exe**. O nome da pasta não o torna um JDK completo. Não foi configurado como JAVA_HOME/JDK Flutter.

Gradle: o projeto contém gradlew.bat, gradle-wrapper.jar e configuração de distribuição **9.3.1-all**. AGP **9.1.0**, Kotlin plugin **2.4.0**, Google Services plugin **4.4.4**. A compilação Java/Kotlin está configurada para nível 17. O cache `%USERPROFILE%\.gradle\wrapper\dists` não existe e gradle não está no PATH; a distribuição Gradle ainda precisará ser obtida pelo wrapper quando o operador preparar o ambiente. Não é necessário instalar Gradle globalmente.

O wrapper não foi iniciado nesta auditoria: o pré-requisito de Java configurado não é atendido, e não houve autorização para downloads da distribuição/toolchain. Não foi forçado o uso do JRE como substituto de JDK.

## FLUTTER DOCTOR

Executado **flutter doctor -v** nesta etapa, log `tool/android_stage04_doctor.log`:

- Flutter **3.47.5**, Dart **3.13.4**, SDK `C:\flutter`: reconhecidos.
- Windows e Chrome: reconhecidos.
- Android toolchain: **falha — SDK não localizado**.
- Android conectado/emulador: nenhum listado; apenas Windows, Chrome e Edge.
- Visual Studio ausente: problema separado para desktop Windows, não um requisito para construir Android.

`flutter config --list` não mostrou diretório customizado de SDK/JDK. Nenhuma preferência Flutter foi modificada.

## DEBUG KEYSTORE

**Ausente:** `C:\Users\DELL\.android\debug.keystore`. O próprio diretório `.android` não existe.

O ambiente ainda não satisfaz a condição de gerar a chave pela toolchain. Nenhum keystore debug foi fabricado e nenhum keystore release foi criado. Depois da instalação manual, o build debug deverá gerar a chave padrão normalmente; então o signingReport poderá fornecer os fingerprints reais.

## SHA-1

**PENDENTE — não existe certificado debug local para extrair o valor.**

## SHA-256

**PENDENTE — não existe certificado debug local para extrair o valor.**

## Preparação manual exata — não executada

1. Instalar [Android Studio estável oficial](https://developer.android.com/studio). No assistente, instalar o SDK; manter ou anotar o caminho real. Os comandos abaixo usam o destino padrão `%LOCALAPPDATA%\Android\Sdk` e validam sua existência antes de configurar qualquer coisa.
2. No Android Studio: **More Actions → SDK Manager** (ou **Tools → SDK Manager**). Em **SDK Platforms**, instalar **Android API 36**. Em **SDK Tools**, habilitar **Show Package Details** e instalar **Build-Tools 36.0.0**, **Platform-Tools**, **Command-line Tools (latest)**, **Android Emulator**, **NDK (Side by side) 28.2.13676358** e CMake recomendado pelo SDK Manager. Essas versões de plataforma/NDK correspondem ao Flutter local; não atualizar o projeto/Gradle por suposição.
3. Preparar um **JDK completo 17**, por exemplo pelo [instalador oficial Temurin](https://adoptium.net/temurin/releases/?version=17), e anotar o diretório real que contém bin/java.exe e bin/javac.exe. A documentação de compatibilidade do AGP 9.1 indica JDK 17 e Build-Tools 36.0.0; o wrapper do projeto já está em Gradle 9.3.1. Também é possível avaliar o JDK completo incluído no Android Studio, conferindo antes sua compatibilidade com esse wrapper; não confundir com o JRE portátil existente.
4. Para emulador: **More Actions → Virtual Device Manager** (ou **Tools → Device Manager**) → criar um dispositivo com imagem **Google Play** API 36 apropriada ao computador. Ativar virtualização/aceleração conforme o assistente. Alternativa: aparelho Android com Google Play Services, depuração USB habilitada, driver USB apropriado e autorização da conexão no aparelho.

Após instalar manualmente, abrir PowerShell na raiz e executar, substituindo o caminho do JDK pela instalação real:

```powershell
Set-Location 'C:\Users\DELL\chamae_delivery'
$jdkPath = (Read-Host 'Diretório real do JDK 17 completo').Trim('"')
$androidSdkPath = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
# Se o SDK foi instalado em outro local, definir androidSdkPath com esse caminho real.
if (-not (Test-Path -LiteralPath "$jdkPath\bin\javac.exe")) { throw 'JDK completo não encontrado' }
if (-not (Test-Path -LiteralPath "$androidSdkPath\cmdline-tools\latest\bin\sdkmanager.bat")) { throw 'SDK/Command-line Tools não encontrados' }
if (-not (Test-Path -LiteralPath "$androidSdkPath\platform-tools\adb.exe")) { throw 'Platform-Tools não encontrados' }
$env:JAVA_HOME = $jdkPath
$env:ANDROID_HOME = $androidSdkPath
$env:Path = "$jdkPath\bin;$androidSdkPath\platform-tools;$androidSdkPath\emulator;$env:Path"
# ANDROID_SDK_ROOT está vazia hoje; não definir um caminho divergente de ANDROID_HOME.
& "$jdkPath\bin\java.exe" -version
& "$jdkPath\bin\javac.exe" -version
C:\flutter\bin\flutter.bat config --jdk-dir "$jdkPath"
C:\flutter\bin\flutter.bat config --android-sdk "$androidSdkPath"
C:\flutter\bin\flutter.bat doctor --android-licenses
C:\flutter\bin\flutter.bat doctor -v
& "$androidSdkPath\platform-tools\adb.exe" devices
& "$androidSdkPath\emulator\emulator.exe" -list-avds
```

Revisar/aceitar pessoalmente as licenças apresentadas. As variáveis acima são somente da sessão PowerShell; os comandos flutter config persistem a escolha de SDK/JDK no Flutter. Se houver escolha de Gradle JDK no Android Studio, apontá-la ao mesmo JDK validado para evitar Java diferente entre IDE e terminal. Nenhum desses comandos de configuração foi executado pelo agente nesta etapa.

## BUILD ANDROID

**Bloqueado por pré-requisitos.** APK, AAB e signingReport não executados nesta etapa: SDK/JDK ainda não estão funcionais, distribuição Gradle não está em cache e keystore ausente. Não foram reivindicados artefatos Android. Não foi configurada assinatura release; a configuração release preexistente continua fora do escopo.

Depois de `flutter doctor -v` reconhecer a toolchain Android, executar os comandos abaixo em sequência e interromper se algum falhar. Eles podem baixar dependências/distribuição Gradle; são instruções para a fase posterior à instalação autorizada, não ações realizadas nesta auditoria.

```powershell
Set-Location 'C:\Users\DELL\chamae_delivery'
C:\flutter\bin\flutter.bat pub get
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test test/production_firebase_configuration_test.dart test/customer_auth_test.dart test/customer_flow_test.dart test/google_login_test.dart
C:\flutter\bin\flutter.bat build apk --debug
# O build debug deverá gerar a chave padrão, se ela ainda não existir.
Push-Location 'C:\Users\DELL\chamae_delivery\android'
try {
    .\gradlew.bat signingReport | Tee-Object -FilePath '..\tool\android_stage04_signing_report.log'
} finally {
    Pop-Location
}
# Opcional, depois de APK e assinatura debug validados:
C:\flutter\bin\flutter.bat build appbundle --debug
```

No relatório real, copiar **SHA1** e **SHA-256** da variante **debug**, com Store apontando para o debug.keystore esperado e Alias androiddebugkey. Não confundir certificados de plugins, outros módulos ou assinatura release. Se o APK falhar antes de gerar o keystore, resolver o erro de build e repetir; não preencher os campos por estimativa.

Validação adicional do mesmo certificado após ele existir:

```powershell
& "$env:JAVA_HOME\bin\keytool.exe" -list -v -alias androiddebugkey -keystore "$env:USERPROFILE\.android\debug.keystore" -storepass android
```

`android` nessa chamada é a senha padrão do keystore debug, não uma credencial release.

## GOOGLE AUTH

**Código pronto; configuração externa e homologação pendentes.** O adapter Firebase/Google e account linking não foram alterados nesta etapa.

O arquivo oficial seleciona package **br.com.loumak.chamae**, appId **1:302882774102:android:4c5058e95fed7870b92ff7**, projectId **chamae-delivery**. As listas OAuth desse cliente continuam vazias. Nenhum Client ID, SHA, secret ou redirect foi inserido.

Checklist do operador no Firebase Console, depois de obter o signingReport real:

1. Abrir **chamae-delivery → Project settings → General → Your apps**, selecionar o Android **br.com.loumak.chamae**, appId acima.
2. Em **SHA certificate fingerprints → Add fingerprint**, adicionar exatamente o **SHA-1 debug real** e o **SHA-256 debug real** desse relatório. Ambos ainda estão pendentes, portanto **não há valor para cadastrar agora**.
3. Em **Authentication → Sign-in method → Google**, habilitar o provedor, escolher e-mail de suporte real e salvar. O estado remoto do provedor não foi consultado nem alterado nesta etapa; o último estado informado pelo operador era pendente.
4. Baixar o novo **google-services.json** após configurar e substituir `android/app/google-services.json`. Conferir package, projeto e appId; conferir também o cliente OAuth Web necessário ao Google Sign-In. Não usar o JSON arquivado. Não inventar serverClientId.
5. Em aparelho/emulador Android com Google Play Services, executar `flutter run -d <id real mostrado por flutter devices>` e testar login real, cancelamento, rede, restauração e anônimo → Google mantendo UID e dados. Testar conflito com outro UID sem merge automático. Registrar resultado e aparelho.

Google OAuth **não está homologado** enquanto faltarem a confirmação do provedor habilitado, os fingerprints registrados, o novo JSON e o login real no Android. Testes de SDK simulado ou build isolado não comprovam OAuth real.

## Verificações independentes concluídas

Sem instalar ferramentas e sem resolver novas dependências (`--no-pub`):

- `flutter test --no-pub test/production_firebase_configuration_test.dart test/customer_auth_test.dart test/customer_flow_test.dart test/google_login_test.dart --reporter expanded`: **31 aprovados**. Log `tool/android_stage04_auth.log`.
- `flutter analyze --no-pub`: **No issues found**, 15,2 segundos. Log `tool/android_stage04_analyze.log`.
- Não executado pub get nesta etapa: a preparação do ambiente não foi concluída e os testes existentes puderam rodar com as dependências já disponíveis.
- Nenhum código funcional ou configuração de build/Firebase foi alterado nesta etapa; somente relatório e logs de auditoria/verificação.

## BLOQUEADORES

1. Android SDK e seus componentes ausentes/não configurados; Android Studio não localizado nos caminhos/registros consultados.
2. JDK completo e JAVA_HOME ausentes; JRE portátil não fornece javac.
3. Distribuição Gradle ainda não obtida pelo wrapper; não iniciada para evitar downloads não autorizados.
4. Debug keystore ausente; SHA-1/SHA-256 reais ainda não podem ser informados.
5. Fingerprints no Firebase, habilitação Google confirmada, JSON OAuth atualizado e teste Android real pendentes.

## Fontes oficiais consultadas

- [Flutter — instalação Android e SDK Manager](https://docs.flutter.dev/platform-integration/android/setup).
- [Android — compatibilidade da família AGP 9.1](https://developer.android.com/build/releases/agp-9-1-0-release-notes).
- [Firebase — fingerprints, provedor Google e novo JSON](https://firebase.google.com/docs/auth/android/google-signin).

**ANDROID TOOLCHAIN AINDA POSSUI BLOQUEADORES**
