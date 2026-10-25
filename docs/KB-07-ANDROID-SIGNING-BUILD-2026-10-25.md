# KB-07 — Assinatura e build Android — 25/10/2026

## Inventário anterior às alterações

Conferidos git status/diff e os arquivos Android antes das alterações.
Worktree anterior preservado; cópias e hashes em `tool/kb07/`.
Este inventário registra a auditoria inicial, anterior à criação autorizada da
upload key e ao build informados pelo responsável no fechamento abaixo. Ausência
de chave/AAB nesta seção não representa o estado atual.

| Item | Estado auditado |
| --- | --- |
| applicationId / namespace / MainActivity | `br.com.loumak.chamae`, coerentes; não alterar. |
| Versão | pubspec `1.0.0+1`: versionName 1.0.0, versionCode 1. |
| Flutter / Dart | 3.47.5 stable, revisão 6a19cca56475dbfba1478ee68d7bd0c2ef891da1 / 3.13.4. |
| min / target / compile SDK | 24 / 36 / 36, derivados do FlutterExtension local; valores 24/36 também presentes nos manifests debug/profile anteriores. |
| Gradle / AGP / KGP | Wrapper 9.3.1 / Android Gradle Plugin 9.1.0 / Kotlin Gradle Plugin 2.4.0. Kotlin embutido do Gradle é 2.2.21, componente diferente. |
| Java | JBR 25.0.3 disponível; source/target Java e Kotlin JVM configurados para 17. |
| SDK local | Plataformas 34, 35, 36 e 37.0; Build Tools 36.0.0; NDK 28.2.13676358 presente. Nenhuma atualização solicitada. |
| Firebase Android | JSON local tem um cliente exato do applicationId oficial e três clientes legados/adicionais; plugin google-services 4.4.4. Sem consulta remota. |
| Manifest | Activity exportada somente como launcher, embedding Flutter 2, Maps por placeholder CHAMAE_MAPS_API_KEY; label chamae_delivery. |
| Ícone | Flutter padrão, inspecionado visualmente; cinco densidades 48–192 px. Branding de launcher pendente; não substituir nesta tarefa. |
| Splash | Arte dourada e temas light/night e Android 12+ já customizados; preservar. |
| Release/debug | **D — configuração insegura/incompleta**: release aponta para signingConfigs debug. Não há signingConfig de release própria. |
| Keystore / key.properties | Nenhuma keystore de release ou key.properties encontrada no workspace; nenhuma referência de assinatura configurada por ambiente. Existe apenas keystore debug padrão fora do repo. Chave legítima externa não foi comprovada. |
| Segredos/Git | Nenhum arquivo de assinatura/credencial privada encontrado como rastreado. Gitignores já cobrem key.properties, jks/keystore, envs e formatos comuns de credenciais privadas. |
| R8/ProGuard | Sem regra própria; plugin Flutter ativa shrink/minify release por padrão e inclui suas regras e proguard-android-optimize.txt. Não desabilitar para obter build. |
| Artefatos existentes | Apenas APKs debug/profile locais encontrados; não são evidência de release assinado nem distribuição. Nenhum AAB/release novo gerado. |

Não foram exibidos senhas, alias de assinatura, conteúdo de keystore, chaves
privadas ou valores de variáveis sensíveis. `google-services.json` contém
identificadores/configuração pública do cliente; não equivale a service account.

## Resultado

**KB-07: RESOLVIDO LOCALMENTE / PENDENTE HOMOLOGAÇÃO GOOGLE PLAY.**

**AAB release: GERADO E ASSINADO LOCALMENTE.** Fechamento documental com base nas
novas evidências fornecidas pelo responsável: upload key oficial criada, backup
local com hash idêntico, `android/key.properties` configurado e build release
concluído. A conferência com `keytool -printcert -jarfile` confirmou o mesmo
certificado da upload key no AAB.

Nesta retomada foram alterados somente este relatório e os dois documentos de
homologação. Não foram executados novamente build, testes ou comandos sobre a
keystore; não foram lidos senhas, alias ou conteúdo de `key.properties`.
As evidências novas são declaradas pelo responsável, distinguindo-se das
validações anteriores executadas pelo agente em `tool/kb07/`.

| Evidência de release | Resultado |
| --- | --- |
| AAB | Build release concluído com sucesso, conforme evidência fornecida. |
| Caminho / tamanho do AAB | `build/app/outputs/bundle/release/app-release.aab` / **65.7 MB**, tamanho informado. |
| SHA-256 do AAB | Não fornecido; não confundir com o hash do arquivo da keystore abaixo. |
| Assinatura / certificado | Certificado do AAB coincide com o da upload key segundo `keytool -printcert -jarfile`, conforme conferência informada. |
| APK release | Não executado na auditoria inicial; nenhuma nova evidência de APK fornecida. |
| Identidade/versão pretendidas | br.com.loumak.chamae / versionCode 1 / versionName 1.0.0. |
| Keystore | Upload key oficial existente fora do repositório: `C:\Users\DELL\LoumakSecure\Android\chamae-upload.jks`. |
| Backup | Backup local criado; hash idêntico ao arquivo original, conforme evidência fornecida. Caminho do backup não informado. |
| key.properties / Git | Configurado localmente, conforme evidência fornecida. `git check-ignore -v -- android/key.properties` confirmou proteção por `android/.gitignore`, sem leitura de credenciais. |
| Console/Play App Signing | Não acessado; upload, configuração/aceitação da chave no Play App Signing e teste fechado não executados. |

### Identificadores públicos de integridade e certificado

Fornecidos pelo responsável; não incluem senha, alias ou chave privada:

- SHA-256 **do arquivo da keystore**: `79C7DAAE3F362EC7D2601BF54E2B77D1E4429BB882FFF2BAADEECDB28F372615`.
- SHA-1 **do certificado da upload key**: `0E:03:1C:84:41:E4:ED:5C:2A:FC:CF:AE:6E:59:0F:3C:5E:13:C0:B0`.
- SHA-256 **do certificado da upload key**: `DD:BA:BC:35:6D:74:32:34:81:5C:A0:90:69:D4:42:D3:39:97:53:6A:33:2B:0C:1F:9A:91:C8:04:44:C6:73:E3`.

O hash do arquivo verifica a identidade da keystore e de seu backup; os
fingerprints identificam o certificado. Nenhum deles é hash do AAB. A coincidência
do certificado local não demonstra aceitação pelo Google Play nem identifica a
assinatura final que a loja usará. **Gate Google Play/Android não liberado**:
upload, Play App Signing, teste fechado e demais critérios AND/GPL pendentes.

## Preparação implementada

`android/app/build.gradle.kts` deixa de usar `signingConfigs.debug` em release.
Agora usa uma configuração release própria, lendo o contrato Flutter padrão
de `android/key.properties`: `storeFile`, `storePassword`, `keyAlias`,
`keyPassword`. O exemplo `android/key.properties.example` contém os quatro
valores **vazios**; nenhum arquivo de credenciais real foi criado pelo agente.
No fechamento, o responsável informou ter configurado o arquivo real localmente.

O caminho de storeFile pode ser absoluto ou relativo a `android/app`. No Windows,
usar barras `/` ou escapes corretos de Properties; não copiar um caminho com
barras invertidas sem escapes. A assinatura nova não lê variáveis arbitrárias
de keystore: nesta configuração a fonte é o arquivo local. Um CI autorizado
pode fornecer esse arquivo por seu gerenciador de segredos, sem imprimi-lo.

`validateChamaeReleaseSigning` é dependência das tarefas release, inclusive quando
chamadas por tarefas agregadas. Debug/profile e clean não exigem credenciais
release. A pré-validação:

- bloqueia campos ausentes/vazios e keystore inexistente;
- prepara leitura local do keystore, senha/entrada de chave privada e validade
  do certificado, sem exibir credencial, alias, caminho ou exceção do provedor;
- rejeita o nome debug.keystore e certificado com CN Android Debug;
- não aceita sucesso vindo de cache de configuração para essa validação.

Validado na sessão inicial: **ausência de configuração é bloqueada** e o guard está
ligado ao grafo correto. Leitura de uma chave real, credenciais incorretas,
certificado expirado e rejeição de certificado debug estão preparados em código,
mas não foram exercitados com keystore naquela sessão. O build assinado real foi
posteriormente informado pelo responsável; isso não equivale a novos testes
negativos de senha incorreta, certificado expirado ou chave debug. O guard não
prova propriedade da chave; sua legitimidade foi declarada pelo responsável.

R8/ProGuard, versões, SDKs, applicationId, manifest, permissões, ícones, splash,
Firebase, mapas e lógica do app não foram alterados. Não executado flutter clean.
O procedimento de assinatura local é baseado no [guia Flutter](https://docs.flutter.dev/deployment/android#sign-the-app).

## Segredos e proteção do worktree

Os gitignores já protegiam `key.properties`, `*.jks`, `*.keystore`, `.env`,
arquivos usuais de service account e chaves privadas. `git check-ignore`
confirmou esses padrões; o template vazio permanece versionável.
Nenhum arquivo de assinatura/credencial privada foi encontrado como rastreado
na árvore atual pelos padrões auditados. Isso não é auditoria de todo o histórico
Git nem prova de ausência de credenciais fora do repositório.

O JSON Firebase Android possui configuração de cliente, não credencial Admin.
Valores de API keys/OAuth IDs não foram reproduzidos. Os dois arquivos locais
de ambiente/credencial encontrados na busca não foram expostos, removidos ou
usados em produção. Nenhum alias/senha/chave privada foi incluído nos relatórios.

341 arquivos preexistentes de app, testes, Functions, Rules, dependências,
Android/iOS e relatórios KB foram comparados por SHA-256: **341/341 inalterados**,
fora dos três arquivos previamente separados para alteração intencional
(Gradle app e duas checklists). Evidências `protected-before.json` e
`protected-after.json`. Alterações anteriores de splash, plugins, privacidade,
checkout e testes permanecem preservadas.

## Firebase, mapas e identidade Android

Package Kotlin, namespace, applicationId e cliente exato no google-services.json
coincidem em `br.com.loumak.chamae`. O plugin Google Services é 4.4.4; não houve
consulta a projeto Firebase remoto, alteração do JSON ou remoção de clientes
legados/adicionais. Não há applicationIdSuffix novo para debug/release.

Ausência de CHAMAE_MAPS_API_KEY no ambiente auditado não prova que uma propriedade
Gradle externa esteja configurada. O build já lê Gradle property ou variável
com esse nome; a validade/restrição da chave não foi verificada remotamente.
Conferir fornecimento autorizado e restrições de package/certificado no ensaio
real. Não inserir valor de chave nos comandos públicos/relatório.

Os SHA-1/SHA-256 da upload key estão registrados no fechamento; sua configuração
e homologação para Google Sign-In/Firebase e restrições de mapas permanecem
pendentes em sessão externa autorizada. Quando Play App Signing
estiver ativo, o certificado que assina o aplicativo distribuído pode ser
distinto do certificado de upload. Coerência de package local não homologa login,
mapa ou configuração remota de release.

## Upload key, keystore e Play App Signing

Keystore é o arquivo local que guarda o ativo criptográfico. Credenciais locais
liberam seu uso; não são a chave por si. A chave de upload identifica quem envia
o AAB. Com Play App Signing habilitado, a loja pode gerenciar a chave que assina
o aplicativo distribuído. Estado dessa conta e relacionamento entre certificados
**não foram presumidos**, conforme os conceitos da [documentação Android](https://developer.android.com/studio/publish/app-signing).

Revisão futura no Console, em sessão separada autorizada:

1. Confirmar titularidade do package e se já há publicação/inscrição no serviço.
2. Identificar certificado de upload aceito e certificado de assinatura da loja.
3. Confirmar responsável/custódia e recuperação do backup já informado, sem
   substituir a upload key oficial criada.
4. Se um ativo foi perdido, revisar recuperação/reset oficial; não gerar chave
   substituta e presumir que atualizações continuarão aceitas.
5. Conferir versionCodes já usados antes de qualquer incremento/versionamento.

Nenhuma dessas ações ocorreu nesta tarefa. Nenhum upload ou acesso ao Console.

## Permissões

Manifest principal atual: INTERNET, ACCESS_COARSE_LOCATION e ACCESS_FINE_LOCATION.
Debug/profile acrescentam INTERNET para tooling. Não há solicitação direta de
localização de background, câmera, microfone ou armazenamento nos manifests
principais auditados.

Também foram lidos manifests mesclados **históricos debug/profile** já existentes
em build/app. Eles não substituem o manifest de um release futuro.

| Permissão | Classificação | Evidência / providência |
| --- | --- | --- |
| INTERNET | Necessária | Firebase/Auth, comunicação e mapas; permissão normal. |
| ACCESS_COARSE_LOCATION | Condicional | Uso da localização atual mediante consentimento; destino também pode ser informado pelo usuário. |
| ACCESS_FINE_LOCATION | Condicional | Precisão da localização solicitada; revisar UX/runtime e declaração de localização na publicação. |
| ACCESS_NETWORK_STATE | Necessária para SDKs de rede | Transitiva nos manifests históricos; conferir origem no release mesclado. |
| WAKE_LOCK | Condicional/transitiva | SDKs, não evidência de nova funcionalidade de background. |
| READ_GSERVICES | Condicional/transitiva | Integração Google nos manifests históricos; validar no release. |
| com.google.android.c2dm.permission.RECEIVE | Condicional/transitiva | Presente nos históricos; não comprova que o app ofereça push de negócio. Conferir cadeia SDK. |
| USE_BIOMETRIC / USE_FINGERPRINT | Condicional/transitiva | Presentes nos históricos; não foi identificado fluxo próprio de biometria no app. Revisar origem/necessidade no release. |
| br.com.loumak.chamae.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION | Necessária à proteção de receivers da biblioteca | Permissão de assinatura/transitiva; não é autorização de acesso a dados do usuário. |

Nenhuma permissão foi classificada como desnecessária com evidência suficiente
para remoção. Nenhuma adicionada/removida. Localização e coleta/compartilhamento
dos SDKs precisam coerência com Data Safety e política aprovada; não preenchidos
formulários da loja nesta tarefa. Reavaliar a lista no AAB final, não publicar
inferindo permissões de um APK debug/profile antigo.

## Procedimento reprodutível em máquina autorizada

O build assinado e a coincidência do certificado do AAB foram informados pelo
responsável. **Reprodutibilidade binária ainda não demonstrada**: não foi
fornecida comparação de duas compilações. Não há promessa de igualdade byte a
byte entre arquivos futuros sem comparação efetiva.

### 1. Ambiente e código

- Usar o mesmo snapshot revisado do worktree e os lockfiles, sem descartar suas
  alterações. Registrar revisão e estado dirty, quando aplicável.
- Flutter 3.47.5 stable, revisão 6a19cca56475dbfba1478ee68d7bd0c2ef891da1; Dart
  3.13.4. Gradle wrapper 9.3.1 e AGP/KGP existentes, sem upgrade.
- Nesta máquina o Gradle foi validado no JBR 25.0.3 do Android Studio; Java/Kotlin
  compilam para JVM 17. Registrar runtime exato na repetição. AGP 9.1 documenta
  mínimo JDK 17 e Gradle 9.3.1, não uma exigência de atualizar o projeto, conforme
  [matriz oficial AGP](https://developer.android.com/build/releases/agp-9-1-0-release-notes).
- Disponibilizar SDK API 36, Build Tools 36.0.0 e NDK 28.2.13676358, com licenças
  aprovadas pelo responsável. Configurar os caminhos locais; não versioná-los
  como configuração universal de outra máquina.

```powershell
# Exemplo do runtime já auditado; ajustar o caminho somente na máquina autorizada.
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
flutter --version
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub
```

`pub get --enforce-lockfile` falha se não puder respeitar a resolução existente;
não substituir por pub upgrade. Não executar clean sem causa técnica demonstrada.
O wrapper gerado localmente existe; em outra máquina, Flutter prepara seu
tooling durante o comando de build. Não usar flutter create para refazer este
projeto nem copiar configurações de outro package.

### 2. Assinatura — reutilizar a upload key oficial

Utilizar a upload key oficial registrada neste fechamento, sob custódia aprovada.
O `android/key.properties` já foi configurado; não recriar nem sobrescrever esse
arquivo. O exemplo abaixo serve somente para outra máquina autorizada onde o
arquivo ainda não exista. Revisar custódia/certificado/alias e seus backups.
Não enviar senhas ou alias sensível ao chat, issue, PR ou log.
Somente depois da revisão, preparar `android/key.properties` em editor seguro:

```powershell
if (Test-Path -LiteralPath android/key.properties) {
    throw 'Preserve e revise o arquivo existente; não sobrescrever.'
}
Copy-Item -LiteralPath android/key.properties.example -Destination android/key.properties
# Preencher localmente os quatro valores a partir da custódia autorizada.
git check-ignore android/key.properties
# No android/, com o wrapper disponível:
.\gradlew.bat :app:validateChamaeReleaseSigning --offline --console=plain --no-configuration-cache
```

Manter arquivo/keystore em armazenamento controlado, com acesso mínimo e backup
seguro; revisar política de custódia. Não utilizar signingReport, properties,
--debug, --info ou build scan para coletar evidências de credenciais. Não passar
senhas na linha de comando. O caminho storeFile e as credenciais permanecem locais.

A orientação inicial de considerar criação de chave foi superada pela evidência
da upload key oficial existente. Não gerar nova chave, substituir ou mover esse
ativo neste fechamento. Recuperação ou troca futura exige revisão humana e,
quando aplicável, procedimento oficial da loja.

### 3. Build — somente com preflight real aprovado

Fornecer também as configurações locais autorizadas de mapas/OAuth exigidas
pelo app e confirmar que a versão pode ser usada na loja. Manter 1.0.0+1 para
reproduzir o estado atual; não assumir que versionCode 1 ainda pode ser publicado.

```powershell
flutter build appbundle --release --no-pub
# Opcional, na mesma configuração legítima, sem instalação automática:
flutter build apk --release --no-pub
```

Caminhos para repetição em máquina autorizada:

- AAB já informado como gerado: `build/app/outputs/bundle/release/app-release.aab`.
- APK opcional, sem nova evidência: `build/app/outputs/flutter-apk/app-release.apk`.

### 4. Verificações complementares e repetição

Tamanho informado: 65.7 MB. O certificado do AAB já foi conferido pelo responsável
com `keytool -printcert -jarfile`. Para complementar as evidências, registrar
SHA-256 do AAB com `Get-FileHash`; esse hash ainda não foi fornecido.
Conferir integridade da assinatura AAB com `jarsigner -verify` e estrutura com
bundletool oficial, versão/checksum registrados. Self-signed é comum em Android;
integridade não substitui conferir a identidade do certificado aprovado.

```text
jarsigner -verify build/app/outputs/bundle/release/app-release.aab
java -jar <BUNDLETOOL_OFICIAL_VERIFICADO.jar> validate --bundle=build/app/outputs/bundle/release/app-release.aab
```

Usar `bundletool dump manifest` localmente para conferir package, versão,
min/target SDK, permissões e metadados; não anexar valores de API keys a logs.
Esperado neste snapshot: package br.com.loumak.chamae, versão 1.0.0 / código 1,
min 24 e target 36. Para APK, usar `apksigner verify` do Build Tools; AAB usa
assinatura JAR, não verificação APK. Conferir certificado/fingerprint com a
custódia aprovada e, depois, com o responsável do Play App Signing.

Registrar somente metadados permitidos, tamanho/hash e resultado. Uma segunda
compilação controlada é necessária para afirmar igualdade binária. Não instalar,
publicar, enviar AAB ou executar bundletool install-apks nesta tarefa.

## Validações anteriores realizadas pelo agente e limites

Tabela histórica da sessão inicial, anterior ao build assinado informado no
fechamento. Os logs/JSON em `tool/kb07/` não foram alterados para simular novos
resultados. Analyze e testes não foram reexecutados nesta retomada documental.

| Verificação | Evidência real |
| --- | --- |
| Gradle `help --offline` | BUILD SUCCESSFUL, Kotlin DSL configurado. `tool/kb07/gradle-help.log`. Não é build Android release. |
| Preflight sem credenciais | Exit 1 esperado, CHAMAE_RELEASE_SIGNING_MISSING. `signing-preflight.log` / `signing-preflight-result.json`. |
| Grafo bundleRelease | `--dry-run --offline`: guard antes das 61 tarefas app release identificadas; todas SKIPPED. `bundle-dry-run.log` / `guard-evidence.json`. Nenhum AAB. |
| Grafo assembleDebug | `--dry-run --offline`: sem guard de release. `debug-dry-run.log`. Nenhum APK novo. |
| Pub get | Concluído com --enforce-lockfile; lockfiles e pubspec inalterados. `pub-get.log`. |
| Flutter analyze | **No issues found**. `flutter-analyze.log`. |
| Flutter test completo | **209/209 aprovados**. `flutter-all.log`. |
| Integridade | **341/341 arquivos protegidos inalterados**, incluindo KB-03/04/05/06 e contratos comerciais. |
| Segredos/Git | Padrões de ignore conferidos; nenhum key.properties real criado; template vazio não ignorado. |

Todos os logs desta seção estão em `tool/kb07/`. Gradle foi invocado via wrapper
Java local para evitar eco do batch; Flutter via dart.exe/flutter_tools.snapshot,
--no-version-check e --suppress-analytics. Não foram atualizados SDK/dependências.
Os avisos de DSL antiga/flags android.newDsl e android.builtInKotlin e futuro
Gradle/AGP 10 permanecem: não justificam upgrade nesta tarefa. O build real
posteriormente informado não substitui homologação funcional em aparelho,
inspeção complementar do manifest final ou execução na trilha Google Play.

## Alterações e revisão humana

Na preparação inicial foram alterados `android/app/build.gradle.kts`, criado
`android/key.properties.example` e atualizados este relatório e as duas
checklists oficiais. **Neste fechamento, somente os três documentos foram
alterados**; código, dependências, credenciais e ativos de assinatura preservados.
196 IDs preservados; nenhum gate Android/Google Play liberado pelo build local.

Pendências:

1. Em sessão autorizada, conferir titularidade, versionCode e configuração do
   Play App Signing; validar a aceitação da upload key e identificar o
   certificado final de distribuição. Console não acessado neste fechamento.
2. Executar upload e teste fechado Google Play, com instalação e homologação
   funcional reais; registrar evidências AND/GPL e revisão humana do gate.
3. Homologar SHA/configuração Firebase/Google/Maps para os certificados de
   distribuição; build assinado local não comprova login/mapas reais.
4. Complementar evidências com hash/metadados do AAB, inspeção do manifest
   release e comportamento sob R8 em dispositivos. Backup com hash idêntico
   foi informado; ensaio de restauração não foi informado.
5. Rever ícone Flutter padrão e label técnico antes de distribuição. Nenhuma
   arte/identidade visual foi substituída nesta tarefa.

Google Play/Console, Firebase produção, Mercado Pago produção, Oracle/GrandChef:
**não acessados**. Nenhum upload, instalação externa, commit, push ou deploy.
Fechamento documental encerrado para revisão humana. KB-07 resolvido localmente;
homologação Google Play e seu gate permanecem pendentes.
