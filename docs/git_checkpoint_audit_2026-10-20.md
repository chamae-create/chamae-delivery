# Auditoria Git e plano de checkpoint — app cliente

Data: 2026-10-20. Repositório: C:/Users/DELL/chamae_delivery.

Auditoria somente leitura do Git e dos arquivos existentes. Nenhum add, commit, push, reset, clean, restore, checkout, exclusão ou ajuste de configuração foi executado. As únicas gravações nos repositórios nesta etapa são os dois relatórios solicitados. Inventários/scripts auxiliares ficaram no diretório temporário da máquina.

## STATUS DO WORKTREE

- Branch: main; HEAD: f7abe483e900b2fc93b83c5f3176cd54446dafbb.
- Antes deste relatório: 44 entradas rastreadas alteradas e 290 arquivos novos individuais; índice vazio.
- Diff efetivo: 40 arquivos, 3581 inserções e 3311 exclusões. Status e diff podem divergir por normalização LF/CRLF.
- Este relatório acrescenta um arquivo novo intencional de documentação.
- Não foi criada garantia de backup externo: trabalho não rastreado continua existindo somente no disco até um checkpoint autorizado.

Maiores diffs:

| Arquivo | Inserções | Exclusões |
|---|---:|---:|
| lib/screens/checkout_screen.dart | 913 | 1868 |
| lib/screens/home_screen.dart | 923 | 884 |
| lib/screens/address_map_screen.dart | 197 | 180 |
| functions/test/firestore.rules.spec.js | 262 | 4 |
| lib/order_chat.dart | 173 | 68 |
| lib/screens/tracking_view.dart | 126 | 82 |

Os totais medem linhas, não risco ou qualidade. Os arquivos grandes precisam de revisão por blocos antes de qualquer staging; não usar adição indiscriminada do worktree.

## ARQUIVOS SENSÍVEIS

Triagem de todos os arquivos alterados/novos textuais disponíveis e configurações cliente indicadas abaixo: padrões de chaves privadas, credenciais de serviço, tokens OAuth/provedores, atribuições literais de senha/token e URLs assinadas. Valores não são reproduzidos. Não houve correspondência de segredo de servidor nos padrões pesquisados. Isso não substitui revisão humana ou scanner completo do histórico Git; imagens/áudio não foram submetidos a OCR e segredos com formatos desconhecidos podem escapar.

| Arquivo | Tipo de risco | Versionamento recomendado |
|---|---|---|
| android/app/google-services.json | chave de API cliente (restrições precisam revisão) | precisa revisão das restrições; configuração cliente pode ser intencional |
| lib/firebase_options.dart | chave de API cliente (restrições precisam revisão) | precisa revisão das restrições; configuração cliente pode ser intencional |
| web/index.html | chave de API cliente (restrições precisam revisão) | precisa revisão das restrições; configuração cliente pode ser intencional |
| docs/config/firebase_legacy/android/google-services.json | chave de API cliente (restrições precisam revisão) | precisa revisão das restrições; configuração cliente pode ser intencional |
| ios/Runner/GoogleService-Info.plist | chave de API cliente (restrições precisam revisão) | precisa revisão das restrições; configuração cliente pode ser intencional |

Configurações Firebase cliente (google-services.json, GoogleService-Info.plist e firebase_options.dart) são apropriadas para versionamento quando pertencem aos identificadores oficiais e não carregam credenciais de servidor. IDs OAuth cliente também não equivalem a client secret. A autorização depende de Rules/IAM; não classificar automaticamente estas configurações como vazamento de segredo. Ver [orientação oficial Firebase](https://firebase.google.com/docs/projects/api-keys). Chaves de Maps exigem restrições por API e aplicativo; a existência dessas restrições não é verificável somente pelos arquivos locais. Ver [orientação oficial Maps](https://developers.google.com/maps/api-security-best-practices).

O plist iOS existe como arquivo novo; deve acompanhar a migração nativa e a configuração Dart. O JSON Android legado em docs/config/firebase_legacy deve permanecer claramente documental, sem substituir o arquivo ativo; revisar necessidade antes de versioná-lo. O HTML Web contém chave cliente Maps e merece a mesma revisão de restrições.

A busca por nomes de .env, credenciais de serviço, keystores, PEM/P12 e crash logs excluiu .git, dependências e caches/builds. Foram encontrados android/hs_err_pid18532.log, android/hs_err_pid13296.log e hs_err_pid25640.log: logs locais ignorados, não versionar. Não reproduzir valores em mensagens de commit, relatórios, capturas ou logs.

## ARQUIVOS QUE NÃO DEVEM SER VERSIONADOS

Builds/APKs, caches, logs/crash logs, .env real, keystores, arquivos locais de SDK/IDE e credenciais privadas devem ficar locais. Os ignores atuais cobrem as famílias principais; não foram modificados. Ignorar um arquivo não remove uma versão já rastreada.

Há 12 arquivos já rastreados que correspondem aos ignores atuais:

- android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java
- android/local.properties
- ios/Flutter/Generated.xcconfig
- ios/Flutter/ephemeral/flutter_lldb_helper.py
- ios/Flutter/ephemeral/flutter_lldbinit
- ios/Flutter/ephemeral/flutter_native_integration.env
- ios/Flutter/flutter_export_environment.sh
- ios/Runner/GeneratedPluginRegistrant.h
- ios/Runner/GeneratedPluginRegistrant.m
- macos/Flutter/ephemeral/Flutter-Generated.xcconfig
- macos/Flutter/ephemeral/flutter_export_environment.sh
- macos/Flutter/ephemeral/flutter_native_integration.env

Revisar uma futura correção específica do índice, somente após autorização; não apagar arquivos. android/local.properties contém configuração específica da máquina. Os registrants Android/iOS e os arquivos ephemeral/export/Generated.xcconfig devem ser tratados conforme as regras das plataformas. O registrant macOS fora de ephemeral é rastreado pelo template e não deve ser removido por analogia: revisar a geração correspondente ao lockfile.

Backups *.before, patches *.diff e evidências intermediárias devem ficar locais por padrão. A captura tool/visual_homologation/android/installed_api24.png é evidência inválida anterior, não uma tela aprovada. Fotos/capturas finais e manifests de hashes são documentação possível, condicionada à revisão de privacidade, duplicidade, tamanho e caminhos locais. Pastas before podem conter conteúdo integrado anterior: não presumir que sejam fixtures anônimas. Logs ignorados referenciados em documentos podem produzir links quebrados quando clonados; preferir resumo sanitizado ou evidências explicitamente escolhidas.

## ARQUIVOS NOVOS IMPORTANTES

O inventário completo abaixo atribui categoria e destinação a cada arquivo novo, sem adicionar nenhum deles ao índice. “Deve entrar no Git” é recomendação para o futuro checkpoint do grupo completo, após revisão; não certifica individualmente o conteúdo nem autoriza push. “Precisa revisão” exige decisão explícita sobre conteúdo, privacidade/procedência ou configuração.

Preservar integralmente design/references/customer_app/official/: sete imagens e README são referências oficiais intencionais. São orientação visual, nunca catálogo ou regra comercial. Os novos módulos de dados, telas, widgets, Functions, Rules, testes e dependências precisam acompanhar seus consumidores.

## ARQUIVOS DELETADOS

Única exclusão: android/app/src/main/kotlin/com/example/chamae_delivery/MainActivity.kt. Há substituição em android/app/src/main/kotlin/br/com/loumak/chamae/MainActivity.kt, com classe MainActivity : FlutterActivity(), pacote compatível com namespace/applicationId e referência relativa .MainActivity no Manifest. A estrutura é consistente com migração intencional, sem indício de remoção da Activity principal; manter exclusão e inclusão no mesmo commit de migração. Confirmar também plist, projeto iOS e configurações Firebase juntos. A intenção final continua sujeita à revisão do autor.

## AGRUPAMENTO RECOMENDADO DE COMMITS

Plano para execução posterior. Cada grupo inclui seus testes e documentação técnica correspondente; não adiar todos os testes para um commit final. Não executar a divisão mecanicamente por diretório.

1. **Identificadores e integração Firebase nativa:** migração Android antiga/nova Activity, Gradle/Manifest, configurações Firebase Android/iOS/Dart, projeto iOS/AppDelegate/Info.plist e testes de configuração. Revisar dependências pubspec/lock em conjunto. Excluir configuração local da máquina deste grupo.
2. **Contratos comuns e segurança do backend:** identidade/bootstrap, política comercial/onboarding, customer-security, PIN, contingência, despacho e operações; Rules/índices/configurações Firebase necessárias; testes backend/Rules/emuladores. index.js importa módulos novos: só incluir cada export quando sua dependência já estiver presente. Se houver ciclo entre identidade, onboarding e frete, manter o mínimo conjunto compilável no mesmo commit.
3. **Frete e Routes:** delivery-pricing, configuração inicial, google-routes-provider, delivery-service e testes; depois contrato cliente delivery_quote/modelos/resumo e testes. Os trechos consumidores de index.js/checkout entram quando todas as dependências estiverem disponíveis. Segredos permanecem no mecanismo de ambiente/secret manager.
4. **Sessão, onboarding, endereço e workspace:** dados de auth/bootstrap/onboarding/verification, localização/geocoding, gate/login/onboarding/perfil/documentos/endereço/mapa, restauração de carrinho e testes correspondentes. Separar auth/endereço em commits menores somente quando suas importações puderem compilar isoladamente.
5. **Integração de compra e operação:** cart_validation/catalog/store_hours, carrinho/checkout, tentativa de pedido, PIX, notificações, tracking, chat e testes. Preservar contratos do backend dos grupos anteriores.
6. **Acabamento visual e homologação:** theme/componentes, ajustes estritamente visuais por tela, referências oficiais, testes visuais e documentação de homologação. O componente PIX extraído precisa acompanhar o diálogo que o importa; a mesma regra vale para o card de histórico/perfil. Harness debug isolado pode ficar em commit próprio após suas dependências e após curadoria das evidências.
7. **Documentação transversal auditada e higiene aprovada:** readiness/auditorias e somente evidências finais escolhidas. Limpeza de rastreamento de gerados é proposta separada e ainda não autorizada; nenhum arquivo deve ser apagado nesta etapa.

## DEPENDÊNCIAS ENTRE COMMITS

lib/main.dart depende de tema/splash; splash/gate/sessão conduzem ao fluxo novo. checkout importa componentes visuais, política comercial, frete, workspace, verificação, endereço, PIX e tentativa de pedido. home também mistura composição e novas fontes de dados. functions/index.js importa delivery-service, onboarding, política comercial, segurança e operações; delivery-service depende de Routes/identidade/pricing. Não é viável afirmar que um commit visual isolado contendo esses arquivos inteiros compilará contra o HEAD atual.

Os dois repositórios compartilham contratos de pedidos/chat, pagamentos, despacho/PIN, políticas comerciais, estoque e frete. O backend está em chamae_delivery/functions; uma alteração no painel não publica nem garante esse backend. Relacionar os SHAs dos dois checkpoints futuros e revisar compatibilidade de campos, callable names, permissões e migração antes de qualquer implantação. A ordem dos commits locais não autoriza deploy.

Antes de cada commit futuro, revisar o patch staged e validar uma árvore contendo somente aquele prefixo de commits, em ambiente isolado autorizado. Testar o worktree completo com arquivos não rastreados não prova que cada commit proposto compila. Se a separação exigir código intermediário ou refatoração, retornar para aprovação: esta auditoria não os produziu.

## RISCOS ANTES DO PUSH

- Índice vazio e muitos arquivos novos: commits apenas dos modificados perderiam módulos essenciais e testes.
- Mistura funcional/visual e diffs grandes impedem checkpoint confiável com seleção por arquivo inteira.
- Restrições das chaves Firebase/Maps e configuração OAuth no console não foram verificadas; não há autorização para alterá-las nesta tarefa.
- Triagem local não certifica histórico Git, binários/imagens ou proteção de branch/remoto. Nenhuma consulta autenticada a serviços ou push foi realizada.
- Gerados e configuração local já rastreados continuam sendo risco mesmo ignorados.
- O harness tool/visual_device/main.dart importa fakes de teste e rejeita execução fora de kDebugMode; não é importado pelo entrypoint normal. Não usar esse target para distribuir release. Os callsites de onboarding em lib usam o valor padrão kDebugMode; o parâmetro de override permanece ponto de revisão para evitar uso futuro indevido.
- Constantes de câmbio/frete legadas em functions/index.js são dados comerciais hardcoded, não credenciais. Revisar se ainda participam de caminhos ativos antes do checkpoint de contratos; não substituí-las por dados de referência visual.
- Quatro arquivos M não têm diff efetivo na leitura: lib/screens/admin_screen.dart, lib/screens/registration_screen.dart, lib/widgets/chamae_logo.dart e lib/widgets/real_web_map.dart. Revisar normalização antes de incluí-los como mudança funcional.
- Evidências visuais anteriores e cópias de fontes podem duplicar dados locais; não versionar em massa.

## CHECKLIST PRÉ-COMMIT

- [ ] Preservar snapshot/backup seguro de todos os arquivos, inclusive não rastreados, sem incluir credenciais em destinos inadequados.
- [ ] Aprovar os grupos e resolver os itens “precisa revisão” do inventário.
- [ ] Decidir política dos gerados/arquivos locais já rastreados sem apagar o trabalho.
- [ ] Revisar privacidade, licenças e tamanho das evidências e artefatos.
- [ ] Conferir restrições das chaves cliente e ausência de segredos no patch e no histórico a publicar.
- [ ] Preparar staging seletivo somente quando autorizado e conferir diff staged e lista de arquivos.
- [ ] Incluir dependências, pubspec/lock coerentes e testes junto da funcionalidade; validar árvore de cada checkpoint.
- [ ] Rodar testes Flutter relevantes e analyze; validar build da plataforma pertinente. Para backend, testes Node/Rules/emuladores com ambiente controlado.
- [ ] Revisar contratos entre os dois repositórios e registrar SHAs correspondentes.
- [ ] Obter autorização separada para commit/push/deploy; esta tarefa não os executa.

Testes/builds não foram reexecutados nesta auditoria somente leitura. Evidências anteriores de homologação não garantem a integridade de uma futura seleção parcial do Git.

## INVENTÁRIO COMPLETO DAS ALTERAÇÕES

Uma linha por entrada de git status --short --untracked-files=all no instante da auditoria. M = modificado no worktree, D = excluído no worktree, ?? = novo; nenhum arquivo estava staged. Categorias podem se sobrepor. Gerado não significa automaticamente descartável: referências oficiais prevalecem e evidências finais precisam de curadoria.

| Status | Arquivo | Classificação | Destinação proposta |
|---|---|---|---|
| M | android/app/build.gradle.kts | código funcional | deve entrar no Git |
| M | android/app/google-services.json | Firebase/Auth | precisa revisão |
| M | android/app/src/main/AndroidManifest.xml | arquivo gerado | precisa revisão |
| M | android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java | código funcional | precisa revisão |
| D | android/app/src/main/kotlin/com/example/chamae_delivery/MainActivity.kt | código funcional | deve entrar no Git (exclusão junto da substituição) |
| M | android/local.properties | configuração local | deve ficar local |
| M | firebase.json | Firebase/Auth | deve entrar no Git |
| M | firestore.rules | Firestore Rules | deve entrar no Git |
| M | functions/.eslintrc.js | Functions | deve entrar no Git |
| M | functions/courier-assignment.js | Functions | deve entrar no Git |
| M | functions/docs/courier-assignment.md | Functions, documentação | deve entrar no Git |
| M | functions/index.js | Functions | deve entrar no Git |
| M | functions/order-operations.js | Functions | deve entrar no Git |
| M | functions/package.json | Functions | deve entrar no Git |
| M | functions/test/courier-assignment.emulator.spec.js | testes | deve entrar no Git |
| M | functions/test/financial.spec.js | testes | deve entrar no Git |
| M | functions/test/firestore.rules.spec.js | testes, Firestore Rules | deve entrar no Git |
| M | functions/test/pilot.emulator.spec.js | testes | deve entrar no Git |
| M | ios/Runner.xcodeproj/project.pbxproj | código funcional | deve entrar no Git |
| M | ios/Runner/AppDelegate.swift | código funcional | deve entrar no Git |
| M | ios/Runner/GeneratedPluginRegistrant.m | código funcional | precisa revisão |
| M | ios/Runner/Info.plist | código funcional | deve entrar no Git |
| M | lib/core/models.dart | código funcional | deve entrar no Git |
| M | lib/core/theme.dart | visual/UX | deve entrar no Git |
| M | lib/core/utils.dart | código funcional | deve entrar no Git |
| M | lib/firebase_options.dart | Firebase/Auth | precisa revisão |
| M | lib/main.dart | código funcional, visual/UX, Firebase/Auth | deve entrar no Git |
| M | lib/order_chat.dart | código funcional, visual/UX, Firebase/Auth | deve entrar no Git |
| M | lib/screens/address_map_screen.dart | Maps, visual/UX | deve entrar no Git |
| M | lib/screens/admin_screen.dart | visual/UX | deve entrar no Git |
| M | lib/screens/checkout_screen.dart | código funcional, visual/UX, frete/Routes | deve entrar no Git |
| M | lib/screens/home_screen.dart | código funcional, visual/UX | deve entrar no Git |
| M | lib/screens/registration_screen.dart | visual/UX | deve entrar no Git |
| M | lib/screens/splash_screen.dart | visual/UX | deve entrar no Git |
| M | lib/screens/tracking_screen.dart | visual/UX | deve entrar no Git |
| M | lib/screens/tracking_view.dart | visual/UX | deve entrar no Git |
| M | lib/widgets/chamae_logo.dart | visual/UX | deve entrar no Git |
| M | lib/widgets/real_web_map.dart | Maps, visual/UX | deve entrar no Git |
| M | lib/widgets/sponsor_video_banner.dart | visual/UX | deve entrar no Git |
| M | macos/Flutter/GeneratedPluginRegistrant.swift | código funcional | precisa revisão |
| M | pubspec.lock | código funcional | deve entrar no Git |
| M | pubspec.yaml | código funcional | deve entrar no Git |
| M | test/checkout_web_test.dart | testes | deve entrar no Git |
| M | web/index.html | código funcional | precisa revisão |
| ?? | android/app/src/main/kotlin/br/com/loumak/chamae/MainActivity.kt | código funcional | deve entrar no Git |
| ?? | design/references/customer_app/official/01_categories_reference.jpeg | visual/UX | deve entrar no Git |
| ?? | design/references/customer_app/official/02_home_reference.jpeg | visual/UX | deve entrar no Git |
| ?? | design/references/customer_app/official/03_cart_reference.jpeg | visual/UX | deve entrar no Git |
| ?? | design/references/customer_app/official/04_checkout_reference.jpeg | visual/UX | deve entrar no Git |
| ?? | design/references/customer_app/official/05_tracking_reference.jpeg | visual/UX | deve entrar no Git |
| ?? | design/references/customer_app/official/06_product_reference.jpeg | visual/UX | deve entrar no Git |
| ?? | design/references/customer_app/official/07_profile_reference.jpeg | visual/UX | deve entrar no Git |
| ?? | design/references/customer_app/official/README.md | visual/UX, documentação | deve entrar no Git |
| ?? | docs/android_toolchain_google_oauth_2026-10-18.md | Firebase/Auth, documentação | deve entrar no Git |
| ?? | docs/app_cliente_final_readiness_2026-10-18.md | documentação | deve entrar no Git |
| ?? | docs/app_cliente_fluxo_oficial_auditoria_2026-10-18.md | documentação | deve entrar no Git |
| ?? | docs/app_cliente_store_checklist_2026-10-18.md | documentação | deve entrar no Git |
| ?? | docs/chamae_ux_1810_frete_30km_auditoria.md | frete/Routes, documentação | deve entrar no Git |
| ?? | docs/chamae_ux_1810_frete_30km_readiness.md | frete/Routes, documentação | deve entrar no Git |
| ?? | docs/config/customer_documents.draft.json | documentação | deve entrar no Git |
| ?? | docs/config/firebase_legacy/README.md | Firebase/Auth, documentação | precisa revisão |
| ?? | docs/config/firebase_legacy/android/google-services.json | Firebase/Auth, documentação | precisa revisão |
| ?? | docs/customer_visual_freeze_with_references_2026-10-20.md | visual/UX, documentação | deve entrar no Git |
| ?? | docs/customer_visual_homologation_2026-10-20.md | visual/UX, documentação | deve entrar no Git |
| ?? | docs/customer_visual_real_device_homologation_2026-10-20.md | visual/UX, documentação | deve entrar no Git |
| ?? | docs/flutterfire_mobile_configuration_2026-10-18.md | documentação | deve entrar no Git |
| ?? | docs/frete_google_routes_final_readiness_2026-10-19.md | frete/Routes, documentação | deve entrar no Git |
| ?? | docs/frete_raio_operacional_readiness_2026-10-19.md | frete/Routes, documentação | deve entrar no Git |
| ?? | docs/google_authentication_audit_2026-10-18.md | Firebase/Auth, documentação | deve entrar no Git |
| ?? | docs/post_login_firestore_audit_2026-10-19.md | documentação | deve entrar no Git |
| ?? | docs/production_identifiers_migration_2026-10-18.md | documentação | deve entrar no Git |
| ?? | docs/visual_homologation_real_device_2026-10-20/analyze_result.txt | visual/UX, documentação, arquivo gerado | deve entrar no Git |
| ?? | docs/visual_homologation_real_device_2026-10-20/before/03_login_awake.png | visual/UX, documentação, arquivo gerado | deve ficar local |
| ?? | docs/visual_homologation_real_device_2026-10-20/before/04_app_initial.png | visual/UX, documentação, arquivo gerado | deve ficar local |
| ?? | docs/visual_homologation_real_device_2026-10-20/before/05_onboarding_footer.png | visual/UX, documentação, arquivo gerado | deve ficar local |
| ?? | docs/visual_homologation_real_device_2026-10-20/before/06_onboarding_keyboard.png | visual/UX, documentação, arquivo gerado | deve ficar local |
| ?? | docs/visual_homologation_real_device_2026-10-20/before/07_onboarding_scroll.png | visual/UX, documentação, arquivo gerado | deve ficar local |
| ?? | docs/visual_homologation_real_device_2026-10-20/before/08_onboarding_focus.png | visual/UX, documentação, arquivo gerado | deve ficar local |
| ?? | docs/visual_homologation_real_device_2026-10-20/before/09_current_session.png | visual/UX, documentação, arquivo gerado | deve ficar local |
| ?? | docs/visual_homologation_real_device_2026-10-20/before/10_home_header.png | visual/UX, documentação, arquivo gerado | deve ficar local |
| ?? | docs/visual_homologation_real_device_2026-10-20/before/11_categories.png | visual/UX, documentação, arquivo gerado | deve ficar local |
| ?? | docs/visual_homologation_real_device_2026-10-20/before/12_cart.png | visual/UX, documentação, arquivo gerado | deve ficar local |
| ?? | docs/visual_homologation_real_device_2026-10-20/before/13_cart_open.png | visual/UX, documentação, arquivo gerado | deve ficar local |
| ?? | docs/visual_homologation_real_device_2026-10-20/before/address_map_screen.dart.before | Maps, visual/UX, documentação, arquivo gerado | deve ficar local |
| ?? | docs/visual_homologation_real_device_2026-10-20/before/chat_keyboard_before_spacing.png | visual/UX, documentação, arquivo gerado | deve ficar local |
| ?? | docs/visual_homologation_real_device_2026-10-20/before/customer_profile_screen.dart.before | visual/UX, documentação, arquivo gerado | deve ficar local |
| ?? | docs/visual_homologation_real_device_2026-10-20/before/device_and_artifacts_previous.json | visual/UX, documentação | deve ficar local |
| ?? | docs/visual_homologation_real_device_2026-10-20/before/home_screen.dart.before | visual/UX, documentação, arquivo gerado | deve ficar local |
| ?? | docs/visual_homologation_real_device_2026-10-20/before/local_pix_qr.png | visual/UX, documentação, arquivo gerado | deve ficar local |
| ?? | docs/visual_homologation_real_device_2026-10-20/before/local_product_manual.png | visual/UX, documentação, arquivo gerado | deve ficar local |
| ?? | docs/visual_homologation_real_device_2026-10-20/before/onboarding_ui.xml | visual/UX, documentação, arquivo gerado | deve ficar local |
| ?? | docs/visual_homologation_real_device_2026-10-20/before/order_chat.dart.before | visual/UX, documentação, arquivo gerado | deve ficar local |
| ?? | docs/visual_homologation_real_device_2026-10-20/before/pix_payment_dialog.dart.before | visual/UX, documentação, arquivo gerado | deve ficar local |
| ?? | docs/visual_homologation_real_device_2026-10-20/before/theme.dart.before | visual/UX, documentação, arquivo gerado | deve ficar local |
| ?? | docs/visual_homologation_real_device_2026-10-20/build_apk_result.txt | visual/UX, documentação, arquivo gerado | deve entrar no Git |
| ?? | docs/visual_homologation_real_device_2026-10-20/capture_inventory.json | visual/UX, documentação, arquivo gerado | precisa revisão |
| ?? | docs/visual_homologation_real_device_2026-10-20/device_and_artifacts.json | visual/UX, documentação | deve entrar no Git |
| ?? | docs/visual_homologation_real_device_2026-10-20/device_final_state.json | visual/UX, documentação | deve entrar no Git |
| ?? | docs/visual_homologation_real_device_2026-10-20/gfxinfo_debug.txt | visual/UX, documentação | deve entrar no Git |
| ?? | docs/visual_homologation_real_device_2026-10-20/local_cart-footer.png | visual/UX, documentação, arquivo gerado | precisa revisão |
| ?? | docs/visual_homologation_real_device_2026-10-20/local_cart.png | visual/UX, documentação, arquivo gerado | precisa revisão |
| ?? | docs/visual_homologation_real_device_2026-10-20/local_catalog.png | visual/UX, documentação, arquivo gerado | precisa revisão |
| ?? | docs/visual_homologation_real_device_2026-10-20/local_categories.png | visual/UX, documentação, arquivo gerado | precisa revisão |
| ?? | docs/visual_homologation_real_device_2026-10-20/local_chat-keyboard-footer.png | visual/UX, documentação, arquivo gerado | precisa revisão |
| ?? | docs/visual_homologation_real_device_2026-10-20/local_chat-keyboard.png | visual/UX, documentação, arquivo gerado | precisa revisão |
| ?? | docs/visual_homologation_real_device_2026-10-20/local_chat-merchant-footer.png | visual/UX, documentação, arquivo gerado | precisa revisão |
| ?? | docs/visual_homologation_real_device_2026-10-20/local_chat-merchant.png | visual/UX, documentação, arquivo gerado | precisa revisão |
| ?? | docs/visual_homologation_real_device_2026-10-20/local_chat.png | visual/UX, documentação, arquivo gerado | precisa revisão |
| ?? | docs/visual_homologation_real_device_2026-10-20/local_checkout-footer.png | visual/UX, documentação, arquivo gerado | precisa revisão |
| ?? | docs/visual_homologation_real_device_2026-10-20/local_checkout.png | visual/UX, documentação, arquivo gerado | precisa revisão |
| ?? | docs/visual_homologation_real_device_2026-10-20/local_history.png | visual/UX, documentação, arquivo gerado | precisa revisão |
| ?? | docs/visual_homologation_real_device_2026-10-20/local_home.png | visual/UX, documentação, arquivo gerado | precisa revisão |
| ?? | docs/visual_homologation_real_device_2026-10-20/local_home_products.png | visual/UX, documentação, arquivo gerado | precisa revisão |
| ?? | docs/visual_homologation_real_device_2026-10-20/local_map-footer.png | Maps, visual/UX, documentação, arquivo gerado | precisa revisão |
| ?? | docs/visual_homologation_real_device_2026-10-20/local_map.png | Maps, visual/UX, documentação, arquivo gerado | precisa revisão |
| ?? | docs/visual_homologation_real_device_2026-10-20/local_orders.png | visual/UX, documentação, arquivo gerado | precisa revisão |
| ?? | docs/visual_homologation_real_device_2026-10-20/local_pix-creating.png | visual/UX, documentação, arquivo gerado | precisa revisão |
| ?? | docs/visual_homologation_real_device_2026-10-20/local_pix-error.png | visual/UX, documentação, arquivo gerado | precisa revisão |
| ?? | docs/visual_homologation_real_device_2026-10-20/local_pix-expired.png | visual/UX, documentação, arquivo gerado | precisa revisão |
| ?? | docs/visual_homologation_real_device_2026-10-20/local_pix-footer.png | visual/UX, documentação, arquivo gerado | precisa revisão |
| ?? | docs/visual_homologation_real_device_2026-10-20/local_pix-paid.png | visual/UX, documentação, arquivo gerado | precisa revisão |
| ?? | docs/visual_homologation_real_device_2026-10-20/local_pix-qr.png | visual/UX, documentação, arquivo gerado | precisa revisão |
| ?? | docs/visual_homologation_real_device_2026-10-20/local_pix-retry.png | visual/UX, documentação, arquivo gerado | precisa revisão |
| ?? | docs/visual_homologation_real_device_2026-10-20/local_pix-waiting.png | visual/UX, documentação, arquivo gerado | precisa revisão |
| ?? | docs/visual_homologation_real_device_2026-10-20/local_product-footer.png | visual/UX, documentação, arquivo gerado | precisa revisão |
| ?? | docs/visual_homologation_real_device_2026-10-20/local_product.png | visual/UX, documentação, arquivo gerado | precisa revisão |
| ?? | docs/visual_homologation_real_device_2026-10-20/local_profile-footer.png | visual/UX, documentação, arquivo gerado | precisa revisão |
| ?? | docs/visual_homologation_real_device_2026-10-20/local_profile.png | visual/UX, documentação, arquivo gerado | precisa revisão |
| ?? | docs/visual_homologation_real_device_2026-10-20/preservation.json | visual/UX, documentação, arquivo gerado | precisa revisão |
| ?? | docs/visual_homologation_real_device_2026-10-20/references_inventory.json | visual/UX, documentação | deve entrar no Git |
| ?? | docs/visual_homologation_real_device_2026-10-20/source_changes.diff | visual/UX, documentação, arquivo gerado | deve ficar local |
| ?? | docs/visual_homologation_real_device_2026-10-20/test_result.txt | visual/UX, documentação, arquivo gerado | deve entrar no Git |
| ?? | docs/visual_homologation_real_device_2026-10-20/tests_result.txt | visual/UX, documentação, arquivo gerado | deve entrar no Git |
| ?? | firebase.post_login.json | Firebase/Auth | deve entrar no Git |
| ?? | firestore.indexes.json | código funcional | deve entrar no Git |
| ?? | functions/catalog-commercial-policy.js | Functions | deve entrar no Git |
| ?? | functions/config/delivery-pricing-initial.json | Functions | deve entrar no Git |
| ?? | functions/courier-dispatch-contract.js | Functions | deve entrar no Git |
| ?? | functions/customer-identity.js | Functions | deve entrar no Git |
| ?? | functions/customer-onboarding.js | Functions | deve entrar no Git |
| ?? | functions/customer-security.js | Functions | deve entrar no Git |
| ?? | functions/delivery-pin.js | Functions | deve entrar no Git |
| ?? | functions/delivery-pricing.js | Functions | deve entrar no Git |
| ?? | functions/delivery-service.js | Functions | deve entrar no Git |
| ?? | functions/docs/customer-auth-onboarding.md | Functions, Firebase/Auth, documentação | deve entrar no Git |
| ?? | functions/docs/operational-flow.md | Functions, documentação | deve entrar no Git |
| ?? | functions/google-routes-provider.js | Functions, frete/Routes | deve entrar no Git |
| ?? | functions/operational-contingency.js | Functions | deve entrar no Git |
| ?? | functions/test/customer-onboarding.spec.js | testes | deve entrar no Git |
| ?? | functions/test/customer-policy-fixture.js | testes | deve entrar no Git |
| ?? | functions/test/delivery-contracts.spec.js | testes | deve entrar no Git |
| ?? | functions/test/delivery-official.spec.js | testes | deve entrar no Git |
| ?? | functions/test/delivery-radius.emulator.spec.js | testes | deve entrar no Git |
| ?? | functions/test/final-operations.emulator.spec.js | testes | deve entrar no Git |
| ?? | ios/Runner/GoogleService-Info.plist | Firebase/Auth | precisa revisão |
| ?? | lib/core/cart_validation.dart | código funcional | deve entrar no Git |
| ?? | lib/core/catalog.dart | código funcional | deve entrar no Git |
| ?? | lib/core/catalog_commercial_policy.dart | código funcional | deve entrar no Git |
| ?? | lib/core/store_hours.dart | código funcional | deve entrar no Git |
| ?? | lib/data/customer_auth.dart | Firebase/Auth | deve entrar no Git |
| ?? | lib/data/customer_bootstrap.dart | Firebase/Auth | deve entrar no Git |
| ?? | lib/data/customer_location.dart | Maps | deve entrar no Git |
| ?? | lib/data/customer_onboarding.dart | código funcional | deve entrar no Git |
| ?? | lib/data/customer_verification.dart | código funcional | deve entrar no Git |
| ?? | lib/data/customer_workspace.dart | código funcional | deve entrar no Git |
| ?? | lib/data/delivery_quote.dart | frete/Routes | deve entrar no Git |
| ?? | lib/data/geocoded_address.dart | Maps | deve entrar no Git |
| ?? | lib/data/order_attempt.dart | código funcional | deve entrar no Git |
| ?? | lib/data/order_notifications.dart | código funcional | deve entrar no Git |
| ?? | lib/data/restore_customer_cart.dart | código funcional | deve entrar no Git |
| ?? | lib/data/reverse_geocode.dart | Maps | deve entrar no Git |
| ?? | lib/data/reverse_geocode_native.dart | Maps | deve entrar no Git |
| ?? | lib/data/reverse_geocode_web.dart | Maps | deve entrar no Git |
| ?? | lib/screens/address_destination_screen.dart | Maps, visual/UX | deve entrar no Git |
| ?? | lib/screens/cart_screen.dart | visual/UX | deve entrar no Git |
| ?? | lib/screens/customer_login_screen.dart | visual/UX | deve entrar no Git |
| ?? | lib/screens/customer_onboarding_screen.dart | visual/UX | deve entrar no Git |
| ?? | lib/screens/customer_profile_screen.dart | visual/UX | deve entrar no Git |
| ?? | lib/screens/customer_session_gate.dart | Firebase/Auth, visual/UX | deve entrar no Git |
| ?? | lib/screens/legal_document_screen.dart | visual/UX | deve entrar no Git |
| ?? | lib/widgets/customer_chat_entry.dart | visual/UX | deve entrar no Git |
| ?? | lib/widgets/customer_order_history_card.dart | visual/UX | deve entrar no Git |
| ?? | lib/widgets/customer_visual.dart | visual/UX | deve entrar no Git |
| ?? | lib/widgets/delivery_pin_card.dart | visual/UX | deve entrar no Git |
| ?? | lib/widgets/delivery_quote_summary.dart | frete/Routes, visual/UX | deve entrar no Git |
| ?? | lib/widgets/order_notification_card.dart | visual/UX | deve entrar no Git |
| ?? | lib/widgets/pix_payment_dialog.dart | visual/UX | deve entrar no Git |
| ?? | lib/widgets/pix_payment_presentation.dart | visual/UX | deve entrar no Git |
| ?? | lib/widgets/product_image.dart | visual/UX | deve entrar no Git |
| ?? | test/address_flow_test.dart | testes, Maps | deve entrar no Git |
| ?? | test/catalog_test.dart | testes | deve entrar no Git |
| ?? | test/checkout_delivery_contract_test.dart | testes | deve entrar no Git |
| ?? | test/client_readiness_test.dart | testes | deve entrar no Git |
| ?? | test/customer_auth_test.dart | testes, Firebase/Auth | deve entrar no Git |
| ?? | test/customer_flow_test.dart | testes | deve entrar no Git |
| ?? | test/customer_location_test.dart | testes, Maps | deve entrar no Git |
| ?? | test/customer_premium_components_test.dart | testes | deve entrar no Git |
| ?? | test/customer_visual_freeze_test.dart | testes, visual/UX | deve entrar no Git |
| ?? | test/customer_visual_homologation_test.dart | testes, visual/UX | deve entrar no Git |
| ?? | test/customer_visual_states_test.dart | testes, visual/UX | deve entrar no Git |
| ?? | test/delivery_quote_state_test.dart | testes, frete/Routes | deve entrar no Git |
| ?? | test/google_login_test.dart | testes | deve entrar no Git |
| ?? | test/order_attempt_test.dart | testes | deve entrar no Git |
| ?? | test/order_notification_test.dart | testes | deve entrar no Git |
| ?? | test/pix_payment_presentation_test.dart | testes | deve entrar no Git |
| ?? | test/production_firebase_configuration_test.dart | testes, Firebase/Auth | deve entrar no Git |
| ?? | test/restore_customer_cart_test.dart | testes | deve entrar no Git |
| ?? | test/support/customer_flow_fakes.dart | testes | deve entrar no Git |
| ?? | test/workspace_cart_test.dart | testes | deve entrar no Git |
| ?? | tool/chrome_test_assets.mjs | ferramenta auxiliar | deve entrar no Git |
| ?? | tool/visual_device/README.md | visual/UX, documentação, ferramenta auxiliar | deve entrar no Git |
| ?? | tool/visual_device/capture.ps1 | visual/UX, ferramenta auxiliar | precisa revisão |
| ?? | tool/visual_device/local_qr.dart | visual/UX, ferramenta auxiliar | deve entrar no Git |
| ?? | tool/visual_device/main.dart | visual/UX, ferramenta auxiliar | deve entrar no Git |
| ?? | tool/visual_freeze/before/lib/core/theme.dart.before | visual/UX, ferramenta auxiliar, arquivo gerado | deve ficar local |
| ?? | tool/visual_freeze/before/lib/main.dart.before | visual/UX, ferramenta auxiliar, arquivo gerado | deve ficar local |
| ?? | tool/visual_freeze/before/lib/screens/cart_screen.dart.before | visual/UX, ferramenta auxiliar, arquivo gerado | deve ficar local |
| ?? | tool/visual_freeze/before/lib/screens/checkout_screen.dart.before | visual/UX, ferramenta auxiliar, arquivo gerado | deve ficar local |
| ?? | tool/visual_freeze/before/lib/screens/customer_profile_screen.dart.before | visual/UX, ferramenta auxiliar, arquivo gerado | deve ficar local |
| ?? | tool/visual_freeze/before/lib/screens/home_screen.dart.before | visual/UX, ferramenta auxiliar, arquivo gerado | deve ficar local |
| ?? | tool/visual_freeze/before/lib/screens/tracking_view.dart.before | visual/UX, ferramenta auxiliar, arquivo gerado | deve ficar local |
| ?? | tool/visual_freeze/before/lib/widgets/sponsor_video_banner.dart.before | visual/UX, ferramenta auxiliar, arquivo gerado | deve ficar local |
| ?? | tool/visual_freeze/before/pubspec.yaml.before | visual/UX, ferramenta auxiliar, arquivo gerado | deve ficar local |
| ?? | tool/visual_freeze/build_results.json | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_freeze/check_results.json | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_freeze/preservation_final.json | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_freeze/protected_hashes.json | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_freeze/screenshots/cart_1440.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_freeze/screenshots/cart_320.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_freeze/screenshots/cart_390.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_freeze/screenshots/cart_430.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_freeze/screenshots/cart_768.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_freeze/screenshots/categories_1440.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_freeze/screenshots/categories_320.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_freeze/screenshots/categories_390.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_freeze/screenshots/categories_430.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_freeze/screenshots/categories_768.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_freeze/screenshots/checkout_1440.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_freeze/screenshots/checkout_320.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_freeze/screenshots/checkout_390.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_freeze/screenshots/checkout_430.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_freeze/screenshots/checkout_768.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_freeze/screenshots/home_1440.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_freeze/screenshots/home_320.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_freeze/screenshots/home_390.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_freeze/screenshots/home_430.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_freeze/screenshots/home_768.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_freeze/screenshots/product_1440.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_freeze/screenshots/product_320.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_freeze/screenshots/product_390.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_freeze/screenshots/product_430.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_freeze/screenshots/product_768.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_freeze/screenshots/profile_1440.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_freeze/screenshots/profile_320.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_freeze/screenshots/profile_390.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_freeze/screenshots/profile_430.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_freeze/screenshots/profile_768.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_freeze/screenshots/tracking_1440.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_freeze/screenshots/tracking_320.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_freeze/screenshots/tracking_390.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_freeze/screenshots/tracking_430.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_freeze/screenshots/tracking_768.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_freeze/visual_changes.diff | visual/UX, ferramenta auxiliar, arquivo gerado | deve ficar local |
| ?? | tool/visual_homologation/after/cart_1440.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/cart_320.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/cart_360.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/cart_390.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/cart_430.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/cart_768.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/categories_1440.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/categories_320.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/categories_360.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/categories_390.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/categories_430.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/categories_768.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/checkout_1440.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/checkout_320.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/checkout_360.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/checkout_390.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/checkout_430.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/checkout_768.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/home_1440.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/home_320.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/home_360.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/home_390.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/home_430.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/home_768.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/product_1440.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/product_320.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/product_360.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/product_390.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/product_430.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/product_768.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/product_footer_360.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/profile_1440.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/profile_320.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/profile_360.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/profile_390.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/profile_430.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/profile_768.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/tracking_1440.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/tracking_320.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/tracking_360.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/tracking_390.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/tracking_430.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/tracking_768.0.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/after/tracking_footer_360.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/android/device_info.json | visual/UX, ferramenta auxiliar, configuração local | deve ficar local |
| ?? | tool/visual_homologation/android/installed_api24.png | visual/UX, ferramenta auxiliar, arquivo gerado | deve ficar local |
| ?? | tool/visual_homologation/before/lib/screens/cart_screen.dart.before | visual/UX, ferramenta auxiliar, arquivo gerado | deve ficar local |
| ?? | tool/visual_homologation/before/lib/screens/checkout_screen.dart.before | visual/UX, ferramenta auxiliar, arquivo gerado | deve ficar local |
| ?? | tool/visual_homologation/before/lib/screens/home_screen.dart.before | visual/UX, ferramenta auxiliar, arquivo gerado | deve ficar local |
| ?? | tool/visual_homologation/before/lib/screens/tracking_view.dart.before | visual/UX, ferramenta auxiliar, arquivo gerado | deve ficar local |
| ?? | tool/visual_homologation/before/test/customer_visual_freeze_test.dart.before | visual/UX, ferramenta auxiliar, arquivo gerado | deve ficar local |
| ?? | tool/visual_homologation/build_results.json | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/changes.diff | visual/UX, ferramenta auxiliar, arquivo gerado | deve ficar local |
| ?? | tool/visual_homologation/check_results.json | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/original_capture_inventory.json | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/preservation.json | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/supplementary/address_empty_360.png | Maps, visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/supplementary/cart_empty_360.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/supplementary/home_empty_360.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/supplementary/home_error_360.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/supplementary/home_loading_360.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/supplementary/login_360.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/supplementary/login_error_360.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/supplementary/onboarding_360.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/supplementary/onboarding_footer_360.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/supplementary/profile_footer_360.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/supplementary/splash_error_360.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/supplementary/splash_loading_360.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/supplementary/tracking_error_360.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/supplementary/tracking_loading_360.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? | tool/visual_homologation/supplementary/tracking_unavailable_360.png | visual/UX, ferramenta auxiliar, arquivo gerado | precisa revisão |
| ?? (novo nesta auditoria) | docs/git_checkpoint_audit_2026-10-20.md | documentação | deve entrar no Git |

## CONCLUSÃO

Plano preparado para revisão, sem execução de checkpoint. Permanecem decisões de higiene, seleção de evidências/configurações e separação de dependências antes de um commit seguro.


## ATUALIZAÇÃO — RESOLUÇÃO DE RISCOS DO CHECKPOINT

Esta seção registra a segunda etapa, autorizada para ajustes de higiene e isolamento de debug. O inventário original acima é histórico: as decisões abaixo prevalecem para seleção futura. Nenhum staging ou commit foi executado. Arquivos locais e ignorados foram preservados no disco.

## RISCOS RESOLVIDOS

- .gitignore ganhou cobertura de dependências Node em qualquer nível, keystores fora de android, credenciais de serviço por nomes adicionais, dumps de memória e temporários de editor. Regras existentes para env/build/cache/IDE continuam válidas. Nenhum arquivo intencional de configuração cliente foi ignorado genericamente.
- Backups, patches de captura, metadados específicos do aparelho e capturas intermediárias foram excluídos do checkpoint com regras restritas aos caminhos conhecidos. O JSON Firebase legado fica local; seu README continua versionável.
- As sete referências oficiais JPEG e README em design/references/customer_app/official permanecem versionáveis. Não foi aplicada regra global para imagens, JSON ou diretórios tool/docs.
- Harness visual: tool/visual_device/main.dart possui bloqueio explícito quando kDebugMode é falso, cobrindo release e profile. O entrypoint normal não importa o harness/test doubles. Os callsites de onboarding no app usam o padrão kDebugMode; não há override true em lib. Fixtures continuam em teste/harness e não houve alteração em auth, onboarding, pagamentos ou backend. O override do modelo permite testes de matriz e não constitui entrada remota; sem mudança desnecessária.
- Conferência local de Firebase Android: existe cliente cujo package coincide com applicationId. O plist iOS corresponde ao bundle configurado no projeto; há entradas OAuth Android com certificado e cliente Web.
- Mapa de arquivos e staging parcial está abaixo. Nenhum arquivo foi reescrito para separar assuntos.

### Arquivos locais já rastreados — estratégia segura

.gitignore não bloqueia modificações em arquivo já rastreado. Para este checkpoint, **excluir explicitamente da seleção de staging** todos os caminhos abaixo e revisar a lista/diff staged antes de qualquer commit. Não usar add indiscriminado (ponto, all ou update) como atalho. Nenhuma alteração no índice foi feita.

Permanecem rastreados no cliente: android/local.properties; android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java; ios/Flutter/Generated.xcconfig; ios/Flutter/ephemeral/flutter_lldb_helper.py; ios/Flutter/ephemeral/flutter_lldbinit; ios/Flutter/ephemeral/flutter_native_integration.env; ios/Flutter/flutter_export_environment.sh; ios/Runner/GeneratedPluginRegistrant.h; ios/Runner/GeneratedPluginRegistrant.m; macos/Flutter/ephemeral/Flutter-Generated.xcconfig; macos/Flutter/ephemeral/flutter_export_environment.sh; macos/Flutter/ephemeral/flutter_native_integration.env. A consulta ao índice/ignores identificou esses 12 caminhos, mesmo que parte esteja sem modificação.

Em etapa separada e expressamente autorizada, a solução duradoura é deixar de rastrear apenas configurações locais/gerados selecionados, preservando cópias no disco e as regras de ignore; revisar o patch do índice e regeneração nas plataformas. Não foi executada nem é condição para adicionar código com uma allowlist correta. Não usar assume-unchanged/skip-worktree como proteção contra commits ou credenciais: são flags locais que escondem estado e não corrigem o rastreamento. Registrant macOS fora de ephemeral tem política própria de template e pode acompanhar alterações de plugins/lockfile; não é automaticamente excluído.

### Seleção de capturas, backups e artefatos

**Manter no Git:** as 29 capturas finais local_*.png na raiz de docs/visual_homologation_real_device_2026-10-20, capture_inventory.json, references_inventory.json, preservation.json e os resultados resumidos analyze_result.txt, build_apk_result.txt, tests_result.txt e test_result.txt. São estados distintos e complementos de scroll/teclado, sem duplicatas byte a byte (29 hashes únicos). A amostra visual de Perfil, Chat com teclado e PIX confirma faixa de fixture local; o QR do harness é não pagável. Datas/endereço/email nesses exemplos pertencem à fixture, não a registro de produção. Esta seleção não homologa integrações reais.

**Manter apenas seleção representativa:** de tool/visual_homologation/after, manter os sete fluxos em 320 e 1440 (14 PNG); conservar os 15 estados supplementary, que cobrem login/onboarding/loading/erro/vazio. Os demais tamanhos/footers dessa pasta e as 35 capturas anteriores de tool/visual_freeze/screenshots ficam locais. As referências oficiais não fazem parte dessa redução.

**Não versionar:** pastas before de docs/tool, *.diff dessas execuções, logs, dumps de UI/aparelho, device_and_artifacts.json, device_final_state.json, gfxinfo_debug.txt, tool/visual_homologation/android inteiro (inclui captura preta inválida), JSON Firebase legado duplicado e backups *.before. Nenhum foi removido. Os inventários históricos podem mencionar evidências mantidas locais; não são manifests portáteis completos. Relatórios antigos preservam links históricos a logs/antes locais: não interpretar esses links como evidência publicada no clone.

Capturas finais selecionadas, arquivo por arquivo:

- docs/visual_homologation_real_device_2026-10-20/local_cart-footer.png — manter no Git.
- docs/visual_homologation_real_device_2026-10-20/local_cart.png — manter no Git.
- docs/visual_homologation_real_device_2026-10-20/local_catalog.png — manter no Git.
- docs/visual_homologation_real_device_2026-10-20/local_categories.png — manter no Git.
- docs/visual_homologation_real_device_2026-10-20/local_chat-keyboard-footer.png — manter no Git.
- docs/visual_homologation_real_device_2026-10-20/local_chat-keyboard.png — manter no Git.
- docs/visual_homologation_real_device_2026-10-20/local_chat-merchant-footer.png — manter no Git.
- docs/visual_homologation_real_device_2026-10-20/local_chat-merchant.png — manter no Git.
- docs/visual_homologation_real_device_2026-10-20/local_chat.png — manter no Git.
- docs/visual_homologation_real_device_2026-10-20/local_checkout-footer.png — manter no Git.
- docs/visual_homologation_real_device_2026-10-20/local_checkout.png — manter no Git.
- docs/visual_homologation_real_device_2026-10-20/local_history.png — manter no Git.
- docs/visual_homologation_real_device_2026-10-20/local_home.png — manter no Git.
- docs/visual_homologation_real_device_2026-10-20/local_home_products.png — manter no Git.
- docs/visual_homologation_real_device_2026-10-20/local_map-footer.png — manter no Git.
- docs/visual_homologation_real_device_2026-10-20/local_map.png — manter no Git.
- docs/visual_homologation_real_device_2026-10-20/local_orders.png — manter no Git.
- docs/visual_homologation_real_device_2026-10-20/local_pix-creating.png — manter no Git.
- docs/visual_homologation_real_device_2026-10-20/local_pix-error.png — manter no Git.
- docs/visual_homologation_real_device_2026-10-20/local_pix-expired.png — manter no Git.
- docs/visual_homologation_real_device_2026-10-20/local_pix-footer.png — manter no Git.
- docs/visual_homologation_real_device_2026-10-20/local_pix-paid.png — manter no Git.
- docs/visual_homologation_real_device_2026-10-20/local_pix-qr.png — manter no Git.
- docs/visual_homologation_real_device_2026-10-20/local_pix-retry.png — manter no Git.
- docs/visual_homologation_real_device_2026-10-20/local_pix-waiting.png — manter no Git.
- docs/visual_homologation_real_device_2026-10-20/local_product-footer.png — manter no Git.
- docs/visual_homologation_real_device_2026-10-20/local_product.png — manter no Git.
- docs/visual_homologation_real_device_2026-10-20/local_profile-footer.png — manter no Git.
- docs/visual_homologation_real_device_2026-10-20/local_profile.png — manter no Git.

## RISCOS EXTERNOS/PENDENTES

| Configuração | Verificado localmente | Pendência externa |
|---|---|---|
| Firebase client config | Estrutura cliente e correspondência Android; sem troca de chave | Conferir APIs permitidas e restrições compatíveis com os SDKs; Rules/IAM/App Check independem de esconder a chave |
| Android / OAuth / Maps | Package da build; entrada de certificado OAuth presente | Conferir package + SHA-1/SHA-256 das assinaturas efetivamente distribuídas e cadastro OAuth; presença no JSON não comprova certificado da build |
| iOS / OAuth / Maps | Plist e bundle local coerentes | Conferir bundle, cliente OAuth/URL scheme e APIs habilitadas quando iOS for alvo |
| Web / OAuth / Maps | Configurações no código cliente | Conferir referrers/origens, domínios autorizados e redirects OAuth, APIs permitidas e separação de chaves por plataforma |

Não imprimir nem trocar chaves. Chaves cliente e IDs OAuth podem integrar o código versionado; não são private keys/client secrets. Restringir de forma específica para cada API/plataforma: SHA/package de OAuth não é a mesma configuração que restrição HTTP-referrer de Maps Web. Restrições excessivas também podem impedir SDKs legítimos. Conferência de console depende de acesso externo autorizado e permanece pendente. Fontes: [Firebase](https://firebase.google.com/docs/projects/api-keys), [Maps](https://developers.google.com/maps/api-security-best-practices).

Outras pendências: validar prefixos de commits em árvore isolada após staging autorizado; revisar compatibilidade de contratos entre repositórios; confirmar procedência de assets e dados de coleta; revisão de histórico/segredos antes de push. Nada disso foi resolvido alterando funcionalidade.

### Mapa de staging — arquivo, commit e seleção parcial

Grupos são os do plano anterior, abreviados no mapa. Para arquivo misto modificado, usar git add -p **somente na futura etapa autorizada**, incluindo imports e consumidores junto das dependências. Para arquivo novo, preferir inclusão integral em seu grupo; não criar estados parciais incompletos. Se um hunk inseparável cruzar assuntos, manter integração atômica maior. pubspec.yaml e pubspec.lock precisam permanecer coerentes. Nenhum comando de staging foi executado.

| Arquivo | Commit recomendado | Staging parcial / decisão |
|---|---|---|
| .gitignore | H — higiene/checkpoint | Não; arquivo inteiro no grupo |
| android/app/build.gradle.kts | I — identidade/configuração nativa | Não; arquivo inteiro no grupo |
| android/app/google-services.json | I — identidade/configuração nativa | Não; arquivo inteiro no grupo |
| android/app/src/main/AndroidManifest.xml | I — identidade/configuração nativa | Não; arquivo inteiro no grupo |
| android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java | Fora do commit | Não versionar; manter no disco |
| android/app/src/main/kotlin/com/example/chamae_delivery/MainActivity.kt | I — identidade/configuração nativa | Exclusão junto da nova MainActivity; não executar agora |
| android/local.properties | Fora do commit | Não versionar; manter no disco |
| firebase.json | Integração entre I/B/D/S/C/V conforme hunks | Sim — git add -p; revisar imports e ordem |
| firestore.rules | Integração entre I/B/D/S/C/V conforme hunks | Sim — git add -p; revisar imports e ordem |
| functions/.eslintrc.js | B — backend/contratos | Não; arquivo inteiro no grupo |
| functions/courier-assignment.js | B — backend/contratos | Não; arquivo inteiro no grupo |
| functions/docs/courier-assignment.md | B — backend/contratos | Não; arquivo inteiro no grupo |
| functions/index.js | Integração entre I/B/D/S/C/V conforme hunks | Sim — git add -p; revisar imports e ordem |
| functions/order-operations.js | Integração entre I/B/D/S/C/V conforme hunks | Sim — git add -p; revisar imports e ordem |
| functions/package.json | B — backend/contratos | Não; arquivo inteiro no grupo |
| functions/test/courier-assignment.emulator.spec.js | B — backend/contratos | Inteiro com a funcionalidade; parcial se cobrir vários grupos |
| functions/test/financial.spec.js | B — backend/contratos | Inteiro com a funcionalidade; parcial se cobrir vários grupos |
| functions/test/firestore.rules.spec.js | B — backend/contratos | Inteiro com a funcionalidade; parcial se cobrir vários grupos |
| functions/test/pilot.emulator.spec.js | B — backend/contratos | Inteiro com a funcionalidade; parcial se cobrir vários grupos |
| ios/Runner.xcodeproj/project.pbxproj | I — identidade/configuração nativa | Não; arquivo inteiro no grupo |
| ios/Runner/AppDelegate.swift | I — identidade/configuração nativa | Não; arquivo inteiro no grupo |
| ios/Runner/GeneratedPluginRegistrant.m | Fora do commit | Não versionar; manter no disco |
| ios/Runner/Info.plist | I — identidade/configuração nativa | Não; arquivo inteiro no grupo |
| lib/core/models.dart | Integração entre I/B/D/S/C/V conforme hunks | Sim — git add -p; revisar imports e ordem |
| lib/core/theme.dart | V — visual | Não; arquivo inteiro no grupo |
| lib/core/utils.dart | Integração entre I/B/D/S/C/V conforme hunks | Sim — git add -p; revisar imports e ordem |
| lib/firebase_options.dart | I — identidade/configuração nativa | Não; arquivo inteiro no grupo |
| lib/main.dart | Integração entre I/B/D/S/C/V conforme hunks | Sim — git add -p; revisar imports e ordem |
| lib/order_chat.dart | Integração entre I/B/D/S/C/V conforme hunks | Sim — git add -p; revisar imports e ordem |
| lib/screens/address_map_screen.dart | Integração entre I/B/D/S/C/V conforme hunks | Sim — git add -p; revisar imports e ordem |
| lib/screens/admin_screen.dart | Sem mudança efetiva identificada | Fora; reconferir normalização antes de staging |
| lib/screens/checkout_screen.dart | Integração entre I/B/D/S/C/V conforme hunks | Sim — git add -p; revisar imports e ordem |
| lib/screens/home_screen.dart | Integração entre I/B/D/S/C/V conforme hunks | Sim — git add -p; revisar imports e ordem |
| lib/screens/registration_screen.dart | Sem mudança efetiva identificada | Fora; reconferir normalização antes de staging |
| lib/screens/splash_screen.dart | Integração entre I/B/D/S/C/V conforme hunks | Sim — git add -p; revisar imports e ordem |
| lib/screens/tracking_screen.dart | Integração entre I/B/D/S/C/V conforme hunks | Sim — git add -p; revisar imports e ordem |
| lib/screens/tracking_view.dart | Integração entre I/B/D/S/C/V conforme hunks | Sim — git add -p; revisar imports e ordem |
| lib/widgets/chamae_logo.dart | Sem mudança efetiva identificada | Fora; reconferir normalização antes de staging |
| lib/widgets/real_web_map.dart | Sem mudança efetiva identificada | Fora; reconferir normalização antes de staging |
| lib/widgets/sponsor_video_banner.dart | V — visual | Não; arquivo inteiro no grupo |
| macos/Flutter/GeneratedPluginRegistrant.swift | I — identidade/configuração nativa | Não; arquivo inteiro no grupo |
| pubspec.lock | Integração entre I/B/D/S/C/V conforme hunks | Sim — git add -p; revisar imports e ordem |
| pubspec.yaml | Integração entre I/B/D/S/C/V conforme hunks | Sim — git add -p; revisar imports e ordem |
| test/checkout_web_test.dart | C — compra/operação e integração | Inteiro com a funcionalidade; parcial se cobrir vários grupos |
| web/index.html | C — compra/operação e integração | Não; arquivo inteiro no grupo |
| android/app/src/main/kotlin/br/com/loumak/chamae/MainActivity.kt | I — identidade/configuração nativa | Não; arquivo inteiro com dependências |
| design/references/customer_app/official/01_categories_reference.jpeg | V — visual/evidências | Não; arquivo inteiro com dependências |
| design/references/customer_app/official/02_home_reference.jpeg | V — visual/evidências | Não; arquivo inteiro com dependências |
| design/references/customer_app/official/03_cart_reference.jpeg | V — visual/evidências | Não; arquivo inteiro com dependências |
| design/references/customer_app/official/04_checkout_reference.jpeg | V — visual/evidências | Não; arquivo inteiro com dependências |
| design/references/customer_app/official/05_tracking_reference.jpeg | V — visual/evidências | Não; arquivo inteiro com dependências |
| design/references/customer_app/official/06_product_reference.jpeg | V — visual/evidências | Não; arquivo inteiro com dependências |
| design/references/customer_app/official/07_profile_reference.jpeg | V — visual/evidências | Não; arquivo inteiro com dependências |
| design/references/customer_app/official/README.md | V — visual/evidências | Não; arquivo inteiro com dependências |
| docs/android_toolchain_google_oauth_2026-10-18.md | I — identidade/configuração nativa | Não; arquivo inteiro com dependências |
| docs/app_cliente_final_readiness_2026-10-18.md | R — documentação transversal | Não; arquivo inteiro com dependências |
| docs/app_cliente_fluxo_oficial_auditoria_2026-10-18.md | R — documentação transversal | Não; arquivo inteiro com dependências |
| docs/app_cliente_store_checklist_2026-10-18.md | R — documentação transversal | Não; arquivo inteiro com dependências |
| docs/chamae_ux_1810_frete_30km_auditoria.md | D — frete/cliente | Não; arquivo inteiro com dependências |
| docs/chamae_ux_1810_frete_30km_readiness.md | D — frete/cliente | Não; arquivo inteiro com dependências |
| docs/config/customer_documents.draft.json | R — documentação transversal | Não; arquivo inteiro com dependências |
| docs/config/firebase_legacy/README.md | R — documentação transversal | Não; arquivo inteiro com dependências |
| docs/config/firebase_legacy/android/google-services.json | Fora do commit | Não versionar; manter no disco |
| docs/customer_visual_freeze_with_references_2026-10-20.md | V — visual/evidências | Não; arquivo inteiro com dependências |
| docs/customer_visual_homologation_2026-10-20.md | V — visual/evidências | Não; arquivo inteiro com dependências |
| docs/customer_visual_real_device_homologation_2026-10-20.md | V — visual/evidências | Não; arquivo inteiro com dependências |
| docs/flutterfire_mobile_configuration_2026-10-18.md | I — identidade/configuração nativa | Não; arquivo inteiro com dependências |
| docs/frete_google_routes_final_readiness_2026-10-19.md | D — frete/cliente | Não; arquivo inteiro com dependências |
| docs/frete_raio_operacional_readiness_2026-10-19.md | D — frete/cliente | Não; arquivo inteiro com dependências |
| docs/git_checkpoint_audit_2026-10-20.md | H — higiene/checkpoint | Não; arquivo inteiro com dependências |
| docs/google_authentication_audit_2026-10-18.md | S — sessão/endereço/workspace | Não; arquivo inteiro com dependências |
| docs/post_login_firestore_audit_2026-10-19.md | B — backend/contratos | Não; arquivo inteiro com dependências |
| docs/production_identifiers_migration_2026-10-18.md | I — identidade/configuração nativa | Não; arquivo inteiro com dependências |
| docs/visual_homologation_real_device_2026-10-20/analyze_result.txt | V — visual/evidências | Não; arquivo inteiro com dependências |
| docs/visual_homologation_real_device_2026-10-20/before/03_login_awake.png | Fora do commit | Não versionar; manter no disco |
| docs/visual_homologation_real_device_2026-10-20/before/04_app_initial.png | Fora do commit | Não versionar; manter no disco |
| docs/visual_homologation_real_device_2026-10-20/before/05_onboarding_footer.png | Fora do commit | Não versionar; manter no disco |
| docs/visual_homologation_real_device_2026-10-20/before/06_onboarding_keyboard.png | Fora do commit | Não versionar; manter no disco |
| docs/visual_homologation_real_device_2026-10-20/before/07_onboarding_scroll.png | Fora do commit | Não versionar; manter no disco |
| docs/visual_homologation_real_device_2026-10-20/before/08_onboarding_focus.png | Fora do commit | Não versionar; manter no disco |
| docs/visual_homologation_real_device_2026-10-20/before/09_current_session.png | Fora do commit | Não versionar; manter no disco |
| docs/visual_homologation_real_device_2026-10-20/before/10_home_header.png | Fora do commit | Não versionar; manter no disco |
| docs/visual_homologation_real_device_2026-10-20/before/11_categories.png | Fora do commit | Não versionar; manter no disco |
| docs/visual_homologation_real_device_2026-10-20/before/12_cart.png | Fora do commit | Não versionar; manter no disco |
| docs/visual_homologation_real_device_2026-10-20/before/13_cart_open.png | Fora do commit | Não versionar; manter no disco |
| docs/visual_homologation_real_device_2026-10-20/before/address_map_screen.dart.before | Fora do commit | Não versionar; manter no disco |
| docs/visual_homologation_real_device_2026-10-20/before/chat_keyboard_before_spacing.png | Fora do commit | Não versionar; manter no disco |
| docs/visual_homologation_real_device_2026-10-20/before/customer_profile_screen.dart.before | Fora do commit | Não versionar; manter no disco |
| docs/visual_homologation_real_device_2026-10-20/before/device_and_artifacts_previous.json | Fora do commit | Não versionar; manter no disco |
| docs/visual_homologation_real_device_2026-10-20/before/home_screen.dart.before | Fora do commit | Não versionar; manter no disco |
| docs/visual_homologation_real_device_2026-10-20/before/local_pix_qr.png | Fora do commit | Não versionar; manter no disco |
| docs/visual_homologation_real_device_2026-10-20/before/local_product_manual.png | Fora do commit | Não versionar; manter no disco |
| docs/visual_homologation_real_device_2026-10-20/before/onboarding_ui.xml | Fora do commit | Não versionar; manter no disco |
| docs/visual_homologation_real_device_2026-10-20/before/order_chat.dart.before | Fora do commit | Não versionar; manter no disco |
| docs/visual_homologation_real_device_2026-10-20/before/pix_payment_dialog.dart.before | Fora do commit | Não versionar; manter no disco |
| docs/visual_homologation_real_device_2026-10-20/before/theme.dart.before | Fora do commit | Não versionar; manter no disco |
| docs/visual_homologation_real_device_2026-10-20/build_apk_result.txt | V — visual/evidências | Não; arquivo inteiro com dependências |
| docs/visual_homologation_real_device_2026-10-20/capture_inventory.json | V — visual/evidências | Não; arquivo inteiro com dependências |
| docs/visual_homologation_real_device_2026-10-20/device_and_artifacts.json | Fora do commit | Não versionar; manter no disco |
| docs/visual_homologation_real_device_2026-10-20/device_final_state.json | Fora do commit | Não versionar; manter no disco |
| docs/visual_homologation_real_device_2026-10-20/gfxinfo_debug.txt | Fora do commit | Não versionar; manter no disco |
| docs/visual_homologation_real_device_2026-10-20/local_cart-footer.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| docs/visual_homologation_real_device_2026-10-20/local_cart.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| docs/visual_homologation_real_device_2026-10-20/local_catalog.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| docs/visual_homologation_real_device_2026-10-20/local_categories.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| docs/visual_homologation_real_device_2026-10-20/local_chat-keyboard-footer.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| docs/visual_homologation_real_device_2026-10-20/local_chat-keyboard.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| docs/visual_homologation_real_device_2026-10-20/local_chat-merchant-footer.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| docs/visual_homologation_real_device_2026-10-20/local_chat-merchant.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| docs/visual_homologation_real_device_2026-10-20/local_chat.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| docs/visual_homologation_real_device_2026-10-20/local_checkout-footer.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| docs/visual_homologation_real_device_2026-10-20/local_checkout.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| docs/visual_homologation_real_device_2026-10-20/local_history.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| docs/visual_homologation_real_device_2026-10-20/local_home.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| docs/visual_homologation_real_device_2026-10-20/local_home_products.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| docs/visual_homologation_real_device_2026-10-20/local_map-footer.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| docs/visual_homologation_real_device_2026-10-20/local_map.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| docs/visual_homologation_real_device_2026-10-20/local_orders.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| docs/visual_homologation_real_device_2026-10-20/local_pix-creating.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| docs/visual_homologation_real_device_2026-10-20/local_pix-error.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| docs/visual_homologation_real_device_2026-10-20/local_pix-expired.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| docs/visual_homologation_real_device_2026-10-20/local_pix-footer.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| docs/visual_homologation_real_device_2026-10-20/local_pix-paid.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| docs/visual_homologation_real_device_2026-10-20/local_pix-qr.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| docs/visual_homologation_real_device_2026-10-20/local_pix-retry.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| docs/visual_homologation_real_device_2026-10-20/local_pix-waiting.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| docs/visual_homologation_real_device_2026-10-20/local_product-footer.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| docs/visual_homologation_real_device_2026-10-20/local_product.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| docs/visual_homologation_real_device_2026-10-20/local_profile-footer.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| docs/visual_homologation_real_device_2026-10-20/local_profile.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| docs/visual_homologation_real_device_2026-10-20/preservation.json | V — visual/evidências | Não; arquivo inteiro com dependências |
| docs/visual_homologation_real_device_2026-10-20/references_inventory.json | V — visual/evidências | Não; arquivo inteiro com dependências |
| docs/visual_homologation_real_device_2026-10-20/source_changes.diff | Fora do commit | Não versionar; manter no disco |
| docs/visual_homologation_real_device_2026-10-20/test_result.txt | V — visual/evidências | Não; arquivo inteiro com dependências |
| docs/visual_homologation_real_device_2026-10-20/tests_result.txt | V — visual/evidências | Não; arquivo inteiro com dependências |
| firebase.post_login.json | B — backend/contratos | Não; arquivo inteiro com dependências |
| firestore.indexes.json | B — backend/contratos | Não; arquivo inteiro com dependências |
| functions/catalog-commercial-policy.js | B — backend/contratos | Não; arquivo inteiro com dependências |
| functions/config/delivery-pricing-initial.json | D — frete/backend | Não; arquivo inteiro com dependências |
| functions/courier-dispatch-contract.js | B — backend/contratos | Não; arquivo inteiro com dependências |
| functions/customer-identity.js | B — backend/contratos | Não; arquivo inteiro com dependências |
| functions/customer-onboarding.js | B — backend/contratos | Não; arquivo inteiro com dependências |
| functions/customer-security.js | B — backend/contratos | Não; arquivo inteiro com dependências |
| functions/delivery-pin.js | B — backend/contratos | Não; arquivo inteiro com dependências |
| functions/delivery-pricing.js | D — frete/backend | Não; arquivo inteiro com dependências |
| functions/delivery-service.js | D — frete/backend | Não; arquivo inteiro com dependências |
| functions/docs/customer-auth-onboarding.md | B — backend/contratos | Não; arquivo inteiro com dependências |
| functions/docs/operational-flow.md | B — backend/contratos | Não; arquivo inteiro com dependências |
| functions/google-routes-provider.js | D — frete/backend | Não; arquivo inteiro com dependências |
| functions/operational-contingency.js | B — backend/contratos | Não; arquivo inteiro com dependências |
| functions/test/customer-onboarding.spec.js | B — backend/contratos | Inteiro com a funcionalidade; parcial se cobrir vários grupos |
| functions/test/customer-policy-fixture.js | B — backend/contratos | Inteiro com a funcionalidade; parcial se cobrir vários grupos |
| functions/test/delivery-contracts.spec.js | D — frete/backend | Inteiro com a funcionalidade; parcial se cobrir vários grupos |
| functions/test/delivery-official.spec.js | D — frete/backend | Inteiro com a funcionalidade; parcial se cobrir vários grupos |
| functions/test/delivery-radius.emulator.spec.js | D — frete/backend | Inteiro com a funcionalidade; parcial se cobrir vários grupos |
| functions/test/final-operations.emulator.spec.js | B — backend/contratos | Inteiro com a funcionalidade; parcial se cobrir vários grupos |
| ios/Runner/GoogleService-Info.plist | I — identidade/configuração nativa | Não; arquivo inteiro com dependências |
| lib/core/cart_validation.dart | C — compra/operação e integração | Não; arquivo inteiro com dependências |
| lib/core/catalog.dart | C — compra/operação e integração | Não; arquivo inteiro com dependências |
| lib/core/catalog_commercial_policy.dart | C — compra/operação e integração | Não; arquivo inteiro com dependências |
| lib/core/store_hours.dart | C — compra/operação e integração | Não; arquivo inteiro com dependências |
| lib/data/customer_auth.dart | S — sessão/endereço/workspace | Não; arquivo inteiro com dependências |
| lib/data/customer_bootstrap.dart | S — sessão/endereço/workspace | Não; arquivo inteiro com dependências |
| lib/data/customer_location.dart | S — sessão/endereço/workspace | Não; arquivo inteiro com dependências |
| lib/data/customer_onboarding.dart | S — sessão/endereço/workspace | Não; arquivo inteiro com dependências |
| lib/data/customer_verification.dart | S — sessão/endereço/workspace | Não; arquivo inteiro com dependências |
| lib/data/customer_workspace.dart | S — sessão/endereço/workspace | Não; arquivo inteiro com dependências |
| lib/data/delivery_quote.dart | D — frete/cliente | Não; arquivo inteiro com dependências |
| lib/data/geocoded_address.dart | S — sessão/endereço/workspace | Não; arquivo inteiro com dependências |
| lib/data/order_attempt.dart | C — compra/operação e integração | Não; arquivo inteiro com dependências |
| lib/data/order_notifications.dart | C — compra/operação e integração | Não; arquivo inteiro com dependências |
| lib/data/restore_customer_cart.dart | S — sessão/endereço/workspace | Não; arquivo inteiro com dependências |
| lib/data/reverse_geocode.dart | S — sessão/endereço/workspace | Não; arquivo inteiro com dependências |
| lib/data/reverse_geocode_native.dart | S — sessão/endereço/workspace | Não; arquivo inteiro com dependências |
| lib/data/reverse_geocode_web.dart | S — sessão/endereço/workspace | Não; arquivo inteiro com dependências |
| lib/screens/address_destination_screen.dart | S — sessão/endereço/workspace | Não; arquivo inteiro com dependências |
| lib/screens/cart_screen.dart | C — compra/operação e integração | Não; arquivo inteiro com dependências |
| lib/screens/customer_login_screen.dart | S — sessão/endereço/workspace | Não; arquivo inteiro com dependências |
| lib/screens/customer_onboarding_screen.dart | S — sessão/endereço/workspace | Não; arquivo inteiro com dependências |
| lib/screens/customer_profile_screen.dart | C — compra/operação e integração | Não; arquivo inteiro com dependências |
| lib/screens/customer_session_gate.dart | S — sessão/endereço/workspace | Não; arquivo inteiro com dependências |
| lib/screens/legal_document_screen.dart | C — compra/operação e integração | Não; arquivo inteiro com dependências |
| lib/widgets/customer_chat_entry.dart | C — compra/operação e integração | Não; arquivo inteiro com dependências |
| lib/widgets/customer_order_history_card.dart | C — compra/operação e integração | Não; arquivo inteiro com dependências |
| lib/widgets/customer_visual.dart | V — visual/evidências | Não; arquivo inteiro com dependências |
| lib/widgets/delivery_pin_card.dart | C — compra/operação e integração | Não; arquivo inteiro com dependências |
| lib/widgets/delivery_quote_summary.dart | D — frete/cliente | Não; arquivo inteiro com dependências |
| lib/widgets/order_notification_card.dart | C — compra/operação e integração | Não; arquivo inteiro com dependências |
| lib/widgets/pix_payment_dialog.dart | C — compra/operação e integração | Não; arquivo inteiro com dependências |
| lib/widgets/pix_payment_presentation.dart | V — visual/evidências | Não; arquivo inteiro com dependências |
| lib/widgets/product_image.dart | V — visual | Não; arquivo inteiro com dependências |
| test/address_flow_test.dart | S — sessão/endereço/workspace | Inteiro com a funcionalidade; parcial se cobrir vários grupos |
| test/catalog_test.dart | C — compra/operação e integração | Inteiro com a funcionalidade; parcial se cobrir vários grupos |
| test/checkout_delivery_contract_test.dart | C — compra/operação e integração | Inteiro com a funcionalidade; parcial se cobrir vários grupos |
| test/client_readiness_test.dart | C — compra/operação e integração | Inteiro com a funcionalidade; parcial se cobrir vários grupos |
| test/customer_auth_test.dart | S — sessão/endereço/workspace | Inteiro com a funcionalidade; parcial se cobrir vários grupos |
| test/customer_flow_test.dart | C — compra/operação e integração | Inteiro com a funcionalidade; parcial se cobrir vários grupos |
| test/customer_location_test.dart | S — sessão/endereço/workspace | Inteiro com a funcionalidade; parcial se cobrir vários grupos |
| test/customer_premium_components_test.dart | V — visual/evidências | Inteiro com a funcionalidade; parcial se cobrir vários grupos |
| test/customer_visual_freeze_test.dart | V — visual/evidências | Inteiro com a funcionalidade; parcial se cobrir vários grupos |
| test/customer_visual_homologation_test.dart | V — visual/evidências | Inteiro com a funcionalidade; parcial se cobrir vários grupos |
| test/customer_visual_states_test.dart | V — visual/evidências | Inteiro com a funcionalidade; parcial se cobrir vários grupos |
| test/delivery_quote_state_test.dart | D — frete/cliente | Inteiro com a funcionalidade; parcial se cobrir vários grupos |
| test/google_login_test.dart | S — sessão/endereço/workspace | Inteiro com a funcionalidade; parcial se cobrir vários grupos |
| test/order_attempt_test.dart | C — compra/operação e integração | Inteiro com a funcionalidade; parcial se cobrir vários grupos |
| test/order_notification_test.dart | C — compra/operação e integração | Inteiro com a funcionalidade; parcial se cobrir vários grupos |
| test/pix_payment_presentation_test.dart | V — visual/evidências | Inteiro com a funcionalidade; parcial se cobrir vários grupos |
| test/production_firebase_configuration_test.dart | I — identidade/configuração nativa | Inteiro com a funcionalidade; parcial se cobrir vários grupos |
| test/restore_customer_cart_test.dart | S — sessão/endereço/workspace | Inteiro com a funcionalidade; parcial se cobrir vários grupos |
| test/support/customer_flow_fakes.dart | C — compra/operação e integração | Inteiro com a funcionalidade; parcial se cobrir vários grupos |
| test/workspace_cart_test.dart | S — sessão/endereço/workspace | Inteiro com a funcionalidade; parcial se cobrir vários grupos |
| tool/chrome_test_assets.mjs | C — compra/operação e integração | Não; arquivo inteiro com dependências |
| tool/visual_device/README.md | V — visual/evidências | Não; arquivo inteiro com dependências |
| tool/visual_device/capture.ps1 | V — visual/evidências | Não; arquivo inteiro com dependências |
| tool/visual_device/local_qr.dart | V — visual/evidências | Não; arquivo inteiro com dependências |
| tool/visual_device/main.dart | V — visual/evidências | Não; arquivo inteiro com dependências |
| tool/visual_freeze/before/lib/core/theme.dart.before | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/before/lib/main.dart.before | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/before/lib/screens/cart_screen.dart.before | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/before/lib/screens/checkout_screen.dart.before | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/before/lib/screens/customer_profile_screen.dart.before | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/before/lib/screens/home_screen.dart.before | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/before/lib/screens/tracking_view.dart.before | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/before/lib/widgets/sponsor_video_banner.dart.before | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/before/pubspec.yaml.before | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/build_results.json | V — visual/evidências | Não; arquivo inteiro com dependências |
| tool/visual_freeze/check_results.json | V — visual/evidências | Não; arquivo inteiro com dependências |
| tool/visual_freeze/preservation_final.json | V — visual/evidências | Não; arquivo inteiro com dependências |
| tool/visual_freeze/protected_hashes.json | V — visual/evidências | Não; arquivo inteiro com dependências |
| tool/visual_freeze/screenshots/cart_1440.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/screenshots/cart_320.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/screenshots/cart_390.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/screenshots/cart_430.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/screenshots/cart_768.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/screenshots/categories_1440.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/screenshots/categories_320.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/screenshots/categories_390.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/screenshots/categories_430.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/screenshots/categories_768.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/screenshots/checkout_1440.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/screenshots/checkout_320.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/screenshots/checkout_390.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/screenshots/checkout_430.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/screenshots/checkout_768.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/screenshots/home_1440.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/screenshots/home_320.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/screenshots/home_390.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/screenshots/home_430.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/screenshots/home_768.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/screenshots/product_1440.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/screenshots/product_320.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/screenshots/product_390.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/screenshots/product_430.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/screenshots/product_768.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/screenshots/profile_1440.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/screenshots/profile_320.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/screenshots/profile_390.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/screenshots/profile_430.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/screenshots/profile_768.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/screenshots/tracking_1440.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/screenshots/tracking_320.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/screenshots/tracking_390.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/screenshots/tracking_430.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/screenshots/tracking_768.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_freeze/visual_changes.diff | Fora do commit | Não versionar; manter no disco |
| tool/visual_homologation/after/cart_1440.0.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| tool/visual_homologation/after/cart_320.0.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| tool/visual_homologation/after/cart_360.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_homologation/after/cart_390.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_homologation/after/cart_430.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_homologation/after/cart_768.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_homologation/after/categories_1440.0.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| tool/visual_homologation/after/categories_320.0.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| tool/visual_homologation/after/categories_360.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_homologation/after/categories_390.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_homologation/after/categories_430.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_homologation/after/categories_768.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_homologation/after/checkout_1440.0.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| tool/visual_homologation/after/checkout_320.0.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| tool/visual_homologation/after/checkout_360.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_homologation/after/checkout_390.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_homologation/after/checkout_430.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_homologation/after/checkout_768.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_homologation/after/home_1440.0.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| tool/visual_homologation/after/home_320.0.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| tool/visual_homologation/after/home_360.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_homologation/after/home_390.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_homologation/after/home_430.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_homologation/after/home_768.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_homologation/after/product_1440.0.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| tool/visual_homologation/after/product_320.0.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| tool/visual_homologation/after/product_360.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_homologation/after/product_390.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_homologation/after/product_430.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_homologation/after/product_768.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_homologation/after/product_footer_360.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_homologation/after/profile_1440.0.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| tool/visual_homologation/after/profile_320.0.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| tool/visual_homologation/after/profile_360.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_homologation/after/profile_390.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_homologation/after/profile_430.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_homologation/after/profile_768.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_homologation/after/tracking_1440.0.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| tool/visual_homologation/after/tracking_320.0.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| tool/visual_homologation/after/tracking_360.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_homologation/after/tracking_390.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_homologation/after/tracking_430.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_homologation/after/tracking_768.0.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_homologation/after/tracking_footer_360.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_homologation/android/device_info.json | Fora do commit | Não versionar; manter no disco |
| tool/visual_homologation/android/installed_api24.png | Fora do commit | Não versionar; manter no disco |
| tool/visual_homologation/before/lib/screens/cart_screen.dart.before | Fora do commit | Não versionar; manter no disco |
| tool/visual_homologation/before/lib/screens/checkout_screen.dart.before | Fora do commit | Não versionar; manter no disco |
| tool/visual_homologation/before/lib/screens/home_screen.dart.before | Fora do commit | Não versionar; manter no disco |
| tool/visual_homologation/before/lib/screens/tracking_view.dart.before | Fora do commit | Não versionar; manter no disco |
| tool/visual_homologation/before/test/customer_visual_freeze_test.dart.before | Fora do commit | Não versionar; manter no disco |
| tool/visual_homologation/build_results.json | V — visual/evidências | Não; arquivo inteiro com dependências |
| tool/visual_homologation/changes.diff | Fora do commit | Não versionar; manter no disco |
| tool/visual_homologation/check_results.json | V — visual/evidências | Não; arquivo inteiro com dependências |
| tool/visual_homologation/original_capture_inventory.json | V — visual/evidências | Não; arquivo inteiro com dependências |
| tool/visual_homologation/preservation.json | V — visual/evidências | Não; arquivo inteiro com dependências |
| tool/visual_homologation/supplementary/address_empty_360.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| tool/visual_homologation/supplementary/cart_empty_360.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| tool/visual_homologation/supplementary/home_empty_360.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| tool/visual_homologation/supplementary/home_error_360.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| tool/visual_homologation/supplementary/home_loading_360.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| tool/visual_homologation/supplementary/login_360.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| tool/visual_homologation/supplementary/login_error_360.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| tool/visual_homologation/supplementary/onboarding_360.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| tool/visual_homologation/supplementary/onboarding_footer_360.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| tool/visual_homologation/supplementary/profile_footer_360.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| tool/visual_homologation/supplementary/splash_error_360.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| tool/visual_homologation/supplementary/splash_loading_360.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| tool/visual_homologation/supplementary/tracking_error_360.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| tool/visual_homologation/supplementary/tracking_loading_360.png | V — visual/evidências | Não; arquivo inteiro com dependências |
| tool/visual_homologation/supplementary/tracking_unavailable_360.png | V — visual/evidências | Não; arquivo inteiro com dependências |

### Resumo operacional inequívoco

**Fora do commit:** todos os itens marcados “Fora” na tabela, gerados locais já rastreados, secrets/keystores/env/dumps/logs/builds/caches; no cliente, artefatos de captura excluídos acima; no painel, manifests de coleta até curadoria. Não usar regra de ignore como prova de remoção do índice.

**Podem ser versionados:** código real, testes e ferramentas isoladas, configs cliente oficiais coerentes, documentação, referências oficiais, seleção de evidências descrita acima e alterações de higiene. Incluir dependências de cada grupo; não incluir JSON legado duplicado. Pendências de console devem estar registradas e resolvidas antes de distribuição/push pertinente.

**Exigem git add -p no plano de separação:** lib/main.dart; lib/core/models.dart; lib/core/utils.dart; lib/screens/home_screen.dart; lib/screens/checkout_screen.dart; lib/screens/address_map_screen.dart; lib/screens/splash_screen.dart; lib/screens/tracking_screen.dart; lib/screens/tracking_view.dart; lib/order_chat.dart; functions/index.js; functions/order-operations.js; firestore.rules; firebase.json; pubspec.yaml; pubspec.lock. Testes transversais modificados podem exigir hunks correspondentes. Arquivos novos entram inteiros; evitar staging parcial de lockfile sem atualizar manifest junto.

**Dependem do externo:** restrições de chaves/API, package/SHA de assinatura real, bundle, origens/domínios/redirects OAuth; procedência/licenças de assets quando não comprovadas no repositório.

### Validação desta etapa

Não houve mudança em código executável do cliente; somente .gitignore e este relatório. Não foram reexecutados testes/builds do cliente por esta alteração documental/de seleção. No painel, a única mudança executável foi validada com **50 testes existentes aprovados**; flutter analyze registrou **20 apontamentos preexistentes nos trechos inspecionados**, sem erros. Esses resultados não substituem validar árvores parciais dos futuros commits.

As regras de ignore foram conferidas com check-ignore --no-index nos arquivos novos e em caminhos sintéticos das famílias locais. Conferência final de hashes, índice e HEAD registra somente as mudanças autorizadas (.gitignore, relatórios e guarda de diagnóstico do painel). Nenhum arquivo foi apagado.


## FECHAMENTO FINAL — MANIFESTS E RESTRIÇÕES EXTERNAS

Esta decisão final substitui as reservas anteriores sobre curadoria de imagens e sobre restrições externas impedirem commits locais. Não houve alteração funcional, coleta, download/aplicação de imagens, troca de chave, execução de serviços externos ou alteração de índice.

### Curadoria definitiva dos arquivos de product images

O conjunto canônico e seus registros de origem ficam em chamae_admin. O cliente não contém um manifesto concorrente; lib/widgets/product_image.dart é código de apresentação versionável, não artefato de coleta. A tabela abaixo identifica arquivos do repositório irmão para evitar cópias divergentes.

| Arquivo em chamae_admin | Decisão | Motivo |
|---|---|---|
| docs/product_image_manifest.json | **COMMITAR** | Manifesto canônico: caminho padrão do CLI e do README; 351 linhas, 201 candidatos a conferir, 150 sem candidato; zero aprovados. |
| docs/product_image_manifest_2026-10-17.json | **COMMITAR** | Base histórica anterior ao enriquecimento, 351 linhas; registra o estado inicial da mesma coleta e é distinta do canônico. |
| docs/product_image_manifest_2026-10-17.snapshot.json | **COMMITAR** | Projeção histórica de 464 produtos, somente id/nome/categoria/estoque/ativo/bloqueio/imagem; sem dados de clientes. Permite conferir a base da auditoria. |
| docs/product_image_sources_2026-10-17.json | **COMMITAR** | Lista final de 1302 fontes, com fingerprint igual ao registrado no canônico; preserva procedência dos candidatos. |
| docs/product_image_candidates_2026-10-17.json | **NÃO COMMITAR** | Primeira coleta intermediária: 29 candidatos; substituída pela consolidação canônica. |
| docs/product_image_candidates_2026-10-17.sources.json | **NÃO COMMITAR** | 137 fontes intermediárias da primeira coleta; manter local. |
| docs/product_image_candidates_coleta2_2026-10-17.json | **NÃO COMMITAR** | Segunda coleta intermediária: 209 candidatos; anterior à revisão comercial/final. |
| docs/product_image_candidates_coleta2_2026-10-17.sources.json | **NÃO COMMITAR** | 1303 fontes intermediárias; substituídas pela lista final de 1302. |
| docs/product_image_candidates_final_2026-10-17.json | **NÃO COMMITAR** | Duplicata byte a byte do manifesto canônico. |
| docs/product_image_candidates_final_2026-10-17.sources.json | **NÃO COMMITAR** | Duplicata byte a byte de product_image_sources_2026-10-17.json. |
| docs/product_image_manifest_pilot_2026-10-16.json | **REVISAR FUTURAMENTE** | Piloto de 446 linhas, anterior ao retrato final; valor histórico possível, mas fora deste checkpoint. Não é fonte ativa nem autorização de aplicação. |

**Arquivos relacionados — COMMITAR:** tools/product-images/README.md, cli.mjs, pipeline.mjs, pipeline.test.mjs, review.html, commercial-policy.cjs, discover.mjs, discovery.mjs e sources.json; docs/auditoria_exclusoes_comerciais_95.csv e .json; docs/catalogo_homologacao_2026-10-17.md e demais relatórios técnicos já classificados. sources.json da ferramenta configura fontes e limites; não é duplicata da lista de resultados em docs. Ferramentas e testes entram junto do grupo Catálogo/Estoque; os quatro JSON escolhidos podem formar um commit documental próprio após o contrato da ferramenta.

Os seis intermediários/duplicados marcados NÃO COMMITAR ganharam regras exatas no .gitignore do painel. Não foi ignorado o piloto histórico por padrão, nem novos manifests em geral: o piloto fica fora por seleção explícita e novos resultados exigirão curadoria. Backups e artefatos de captura continuam com as decisões da etapa anterior; nenhum arquivo foi apagado.

Validação local: todos os JSON foram parseados; o canônico é idêntico à cópia final excluída; as duas listas finais de fontes são idênticas; o fingerprint da lista escolhida corresponde ao manifesto; os IDs/nomes das 351 linhas correspondem à projeção histórica. Nenhuma linha candidata é comercialmente bloqueada pela política atual; exclusões históricas permanecem apenas como auditoria. **Zero linhas aprovadas**, sem visualVerified/usageAuthorized verdadeiros. A classificação COMMITAR preserva documentação de candidatos e não concede licença, não aprova fotografias e não autoriza importação remota. Conferência de qualidade/licença é requisito de uma futura aplicação de imagens, não impedimento para versionar este inventário de URLs.

### Separação de configuração cliente e secrets — verificação local

- Reexaminados todos os arquivos textuais rastreados e novos não ignorados no estado atual: **254 no painel e 230 no cliente**. Triagem por padrões de chaves privadas/contas de serviço, credenciais OAuth/provedores, atribuições literais sensíveis e URLs com tokens/assinaturas: **nenhuma correspondência**. Não foram impressos valores. Configurações Firebase cliente já examinadas são públicas por desenho, distintas de credenciais administrativas.
- Não foi encontrado arquivo de credencial privada entre os caminhos versionáveis examinados. Build/cache/arquivos privados ignorados não são candidatos deste checkpoint; a checagem não certifica blobs binários, formatos desconhecidos ou todo o histórico Git. Não há indício local concreto de secret a bloquear o commit.
- Routes permanece backend-only: functions/google-routes-provider.js chama a API Routes; functions/delivery-service.js recebe o secret por defineSecret e o declara nas opções da callable antes de fornecer seu valor ao provider. O valor não consta do repositório. Não há referência ao secret Routes nem chamada direta à API Routes em lib/web nativos do cliente ou painel.
- Maps cliente usa integração Flutter/Web e configuração cliente, sem importar o provider/secret de Routes. Não foi encontrada chave backend literal nesse caminho. A prova de que as chaves no console não foram indevidamente reutilizadas ou liberadas para APIs adicionais depende da conferência externa abaixo.
- Firebase Android e configurações Dart cliente continuam versionáveis; plist iOS do cliente acompanha bundle/migração. Configuração legada duplicada fica local, conforme ignore anterior. IDs OAuth cliente não equivalem a client secret. Nenhuma chave foi alterada.

### Checklist externo separado — pré-produção/publicação

**NÃO BLOQUEIAM O COMMIT LOCAL, MAS BLOQUEIAM PRODUÇÃO/PUBLICAÇÃO ATÉ VERIFICAÇÃO EXTERNA**

- [ ] Android: package e SHA-1/SHA-256 das assinaturas usadas; diferenciar debug, distribuição e Play App Signing.
- [ ] iOS quando alvo: bundle ID, cadastro OAuth/URL scheme e restrições da chave apropriada à plataforma.
- [ ] Maps: restrições de aplicação por plataforma e APIs permitidas; separar cliente de backend.
- [ ] Routes: secret no serviço correto, acesso do runtime e restrição à API/backend pertinente; não usar chave de navegador.
- [ ] Firebase: allowlist de APIs compatível com SDKs usados, configuração do app e domínios autorizados; Rules/IAM e App Check são controles independentes.
- [ ] OAuth Web: origens, redirect URIs e domínio/configuração corretos; Android/iOS conforme plataforma efetivamente distribuída.

O painel não tem OAuth Android certificado nem plist iOS no estado examinado; não há motivo para fabricar configuração nativa para o uso Web. Se distribuição nativa com essas integrações for pretendida, a configuração correspondente integra o checklist externo. Esta etapa não acessou console nem recebeu secrets.

### Lista final para execução futura do checkpoint

**Explicitamente fora dos commits:**

- chamae_admin/docs/product_image_candidates_2026-10-17.json — NÃO COMMITAR.
- chamae_admin/docs/product_image_candidates_2026-10-17.sources.json — NÃO COMMITAR.
- chamae_admin/docs/product_image_candidates_coleta2_2026-10-17.json — NÃO COMMITAR.
- chamae_admin/docs/product_image_candidates_coleta2_2026-10-17.sources.json — NÃO COMMITAR.
- chamae_admin/docs/product_image_candidates_final_2026-10-17.json — NÃO COMMITAR.
- chamae_admin/docs/product_image_candidates_final_2026-10-17.sources.json — NÃO COMMITAR.
- chamae_admin/docs/product_image_manifest_pilot_2026-10-16.json — REVISAR FUTURAMENTE.
- Cliente: android/local.properties e os onze gerados locais já rastreados relacionados na seção “Arquivos locais já rastreados”; não alterar o índice deles nesta tarefa.
- Cliente: before/ das execuções visuais, patches *.diff de captura, logs/dumps/metadados locais do aparelho, captura Android inválida, JSON Firebase legado duplicado e screenshots intermediários excluídos pelo ignore. Builds/caches/IDE/env/keystores/secrets continuam fora de ambos.
- Preservar no commit visual somente a seleção anterior: 29 capturas físicas finais local_*.png, 14 responsivas 320/1440 e 15 estados supplementary, manifests/resultados resumidos escolhidos e referências oficiais. Demais evidências ficam no disco. Não foi feita redução por exclusão física.

**Manifests que entram:** docs/product_image_manifest.json; docs/product_image_manifest_2026-10-17.json; docs/product_image_manifest_2026-10-17.snapshot.json; docs/product_image_sources_2026-10-17.json, todos em chamae_admin.

**Arquivos que exigem git add -p para a divisão por assuntos proposta neste repositório:**

- lib/main.dart
- lib/core/models.dart
- lib/core/utils.dart
- lib/screens/home_screen.dart
- lib/screens/checkout_screen.dart
- lib/screens/address_map_screen.dart
- lib/screens/splash_screen.dart
- lib/screens/tracking_screen.dart
- lib/screens/tracking_view.dart
- lib/order_chat.dart
- functions/index.js
- functions/order-operations.js
- firestore.rules
- firebase.json
- pubspec.yaml
- pubspec.lock

Manter imports/consumidores e dependências juntos; pubspec/lock devem permanecer coerentes. Se um hunk for inseparável, usar integração atômica em vez de refatorar para staging. Arquivos novos entram inteiros com seu grupo. Para docs/product_image_manifest.json, **não fracionar linhas de JSON para simular separação de assuntos**: incluir inteiro no commit de curadoria/documentação de imagens. Nada foi adicionado ao índice.

### Risco local real restante e validação final

**Nenhum risco local concreto restante identificado no escopo destes últimos dois itens.** Gerados locais rastreados continuam fisicamente presentes e exigem exclusão explícita do staging, como já autorizado/documentado; isso não impede commits seletivos corretos. A conclusão depende de respeitar o mapa e a lista de exclusões, não de executar adição em massa. As verificações externas são gates de produção/publicação, não de commit local.

Sem mudança executável nesta etapa: não se repetiram builds/testes Flutter; permanecem os 50 testes aprovados e os 20 apontamentos sem errors do analyze da etapa anterior. Foram feitas validações estáticas/estruturais dos JSON, fingerprints, duplicatas, elegibilidade, ausência de aprovação e pesquisa de credenciais/consumo de APIs. Revisar diff staged e validar cada prefixo de commits continua sendo procedimento normal da futura execução autorizada, não risco local novo. Não houve commit, push, deploy ou comando destrutivo.

CHECKPOINT GIT PRONTO PARA COMMITS LOCAIS
