# Execução do checkpoint Git local — app cliente

Data: 2026-10-20. Repositório: C:/Users/DELL/chamae_delivery. Branch: main.

Fonte principal: docs/git_checkpoint_audit_2026-10-20.md, incluindo seu fechamento final. HEAD inicial: f7abe483e900b2fc93b83c5f3176cd54446dafbb. Não houve alteração no repositório chamae_admin nesta execução.

## RESULTADO

Os sete commits de conteúdo abaixo preservam o trabalho auditado. O fechamento tem **pendência de validação integrada de backend**: 40 testes do piloto E2E falharam por pré-condição ausente no setup. O cliente passou na validação final. Nenhuma correção funcional foi realizada para mascarar ou contornar falhas.

## COMMITS CRIADOS

| Hash curto | Mensagem | Arquivos |
|---|---|---:|
| 21efe4e | feat: consolidar identificadores oficiais e configuracao Firebase nativa | 16 |
| b19f187 | feat: consolidar contratos de entrega e seguranca do backend | 31 |
| 5650036 | feat: consolidar modelos e dados de sessao endereco e compra | 26 |
| 6cb51e8 | feat: integrar sessao endereco e compra na identidade visual do cliente | 38 |
| db8c488 | test: preservar referencias e homologacao visual do cliente | 88 |
| 3afab14 | docs: consolidar auditorias e readiness do app cliente | 15 |
| fdc03f5 | chore: preservar ferramentas de homologacao e higiene do cliente | 5 |

Este relatório é registrado em um **oitavo commit documental de fechamento**, posterior aos sete da tabela. Seu hash não pode constar literalmente em seu próprio conteúdo sem autorreferência; consultar git log -1 --format=%h -- docs/git_checkpoint_execution_2026-10-20.md. O hash desse fechamento também é informado na resposta final. Não houve amend, rebase ou squash.

### Ordem e agrupamento por dependências

1. Identificadores Android/iOS, configuração Firebase, dependência Google Sign-In e teste de configuração; Firebase config e índices acompanhados para evitar referência a arquivo ausente.
2. Backend/Rules, elegibilidade, PIN, despacho/contingência e frete/Routes no mesmo contrato atômico. index.js integra todos esses módulos e customer-security depende de delivery-service; separar somente por diretório/assunto criaria prefixos incompletos. Testes e docs técnicas acompanharam o contrato.
3. Bases de modelos, catálogo, sessão, endereço, workspace, frete, notificações e tentativa de pedido, com testes unitários e doubles.
4. Integração de telas e design system: sessão/endereço/home/perfil/compra/tracking têm importações cruzadas e foram preservados como integração atômica, com os testes correspondentes. Nenhum código foi reescrito para diminuir commits.
5. Referências oficiais, quatro arquivos de testes visuais e seleção de evidências aprovada: 29 capturas físicas finais, 14 responsivas 320/1440 e 15 estados supplementary. Sete JPEG oficiais e README preservados.
6. Readiness, auditorias e rascunho documental com published=false/draft=true; nenhum aceite jurídico ou publicação.
7. Higiene/ignore, suporte local a testes Chrome e harness de captura isolado por kDebugMode. Nenhuma execução ADB nesta etapa.

Testes não foram adiados integralmente para um commit final: acompanharam cada funcionalidade; o commit visual contém apenas a verificação visual adicional e evidências.

## STAGING E REVISÃO

Antes de cada commit foram consultados git diff --cached --stat e git diff --cached, com conferência de caminhos, triagem de credenciais e importações entre arquivos da árvore do índice. Patches completos de revisão com chaves cliente redigidas ficaram somente na pasta temporária local. Nenhum secret privado detectado no staged. Arquivos ignorados não foram forçados ao índice.

Git add -p foi executado nos **16 caminhos obrigatórios**:

- firebase.json
- pubspec.yaml
- pubspec.lock
- firestore.rules
- functions/index.js
- functions/order-operations.js
- lib/core/models.dart
- lib/core/utils.dart
- lib/main.dart
- lib/order_chat.dart
- lib/screens/address_map_screen.dart
- lib/screens/checkout_screen.dart
- lib/screens/home_screen.dart
- lib/screens/splash_screen.dart
- lib/screens/tracking_screen.dart
- lib/screens/tracking_view.dart

Seleção efetivamente parcial de pubspec.yaml: dependência Google Sign-In no primeiro commit e lista explícita de assets no commit de integração. Nos outros arquivos, os hunks foram aceitos no grupo atômico correspondente após revisão; a ferramenta não foi usada para fabricar código intermediário. Manifest/lockfile permaneceram coerentes.

Validação de importações do índice: nenhuma dependência local ausente em cada grupo revisado. Não houve adição indiscriminada de todo o worktree.

## TESTES EXECUTADOS

| Verificação | Resultado | Contexto |
|---|---|---|
| Configuração Firebase nativa | 5 aprovados | Árvore staged isolada do primeiro commit |
| npm test (Functions) | 274 aprovados, 0 falhas | Árvore staged isolada, módulos reais e fakes existentes |
| Functions/Rules em Firestore Emulator | 326 testes: 286 aprovados, 40 falhas | Projeto demo-chamae-rules; 127.0.0.1:8187; sem produção |
| ESLint dos blobs JavaScript do índice | 35 arquivos, zero erros | Conteúdo LF exato a ser commitado |
| ESLint do worktree original | Saída 0, sem apontamentos | CLI instalado, formato JSON para resumo, sem --fix |
| Bases cliente | 25 aprovados | Árvore staged isolada |
| Integração das telas | Analyze limpo e 99 testes aprovados | Árvore staged isolada, sem untracked do repositório original |
| Quatro arquivos de testes visuais | 23 aprovados | Sobre a integração isolada, testes copiados do índice |
| flutter analyze — final | Saída 0, No issues found | Repositório cliente original após os sete commits de conteúdo |
| flutter test — final | Saída 0, 122 aprovados | Repositório cliente original após os sete commits de conteúdo |
| node --check tool/chrome_test_assets.mjs | Saída 0 | Verificação sintática, sem iniciar navegador |

As contagens intermediárias não devem ser somadas: há sobreposição entre prefixos e validação final. Mensagens de VideoPlayer UnimplementedError nos testes visuais foram tratadas pelo fallback já existente; a suíte encerrou com sucesso. Não houve build APK/Web adicional nesta execução, pois não foi solicitado no mínimo final desta etapa.

### Pendência reproduzida do piloto E2E

As 40 falhas pertencem a functions/test/pilot.emulator.spec.js. A função createOrder, na linha 101 da versão commitada, espera financialValidationStatus=validated, mas recebe rejected. O backend registra DELIVERY_CONFIGURATION_MISSING. O before do piloto limpa o banco e configura política/perfil/couriers, porém não cria deliveryConfiguration/current; pedidos customerFlowVersion=2 exigem essa configuração. A falha ocorre antes das asserções operacionais desses cenários.

A suíte completa foi repetida para capturar relatório TAP íntegro; ambas as execuções falharam no piloto. O resultado final registrado é 286/326 aprovados, 40/326 falhos. Não se injetou configuração para obter aprovação artificial, não se alteraram fixtures/testes nem o comportamento fail-closed do backend. Uma próxima etapa autorizada deve revisar o setup do piloto e repetir a suíte antes de considerar a validação integrada aprovada.

Comando de cobertura pesada, executado via firebase emulators:exec --project demo-chamae-rules --only firestore, usando configuração temporária isolada: node --test --test-concurrency=1 test/firestore.rules.spec.js test/courier-deliveries.emulator.spec.js test/courier-assignment.emulator.spec.js test/pilot.emulator.spec.js test/order-chat.emulator.spec.js test/delivery-radius.emulator.spec.js test/final-operations.emulator.spec.js. Na segunda execução o runner registrou TAP em arquivo temporário. Emulador encerrado pelo CLI ao fim dos testes; não houve Functions Emulator nem chamada Mercado Pago real.

O npm run lint inicialmente executado sobre a cópia exportada no Windows apontou 9823 ocorrências exclusivamente de linebreak-style (CRLF). Os blobs do índice usam LF; foram validados diretamente, e o lint no worktree original também passou. Portanto, a cópia temporária não exigiu nenhuma correção de fontes nem gerou pendência real de lint.

## ARQUIVOS DEIXADOS PROPOSITALMENTE FORA

### Rastreados e modificados

- android/local.properties — caminhos/configuração da máquina, não staged.
- android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java — gerado local já rastreado, não staged.
- ios/Runner/GeneratedPluginRegistrant.m — gerado local já rastreado, não staged.
- lib/screens/admin_screen.dart — status M preexistente sem diff efetivo.
- lib/screens/registration_screen.dart — status M preexistente sem diff efetivo.
- lib/widgets/chamae_logo.dart — status M preexistente sem diff efetivo.
- lib/widgets/real_web_map.dart — status M preexistente sem diff efetivo.

Os quatro últimos permanecem fora conforme o mapa de auditoria (revisão de normalização/CRLF). Não foi feito staging apenas para limpar indicadores de status. Os outros gerados locais já rastreados listados na auditoria ficaram intocados, inclusive os sem modificação. Nenhuma remoção do índice.

### Novo ainda não rastreado

- tool/visual_device/capture.ps1 — marcado “precisa revisão” na auditoria. A inspeção confirmou caminho ADB absoluto específico desta máquina; ficou local em cumprimento à regra de não incluir configuração de máquina. Não foi parametrizado nem reescrito nesta etapa. O harness debug e sua documentação foram versionados, mas o script de automação continua disponível somente neste worktree.

### Ignorados e preservados no disco

Backups before/*.before; patches de captura *.diff; capturas intermediárias fora da seleção; captura Android inválida; dumps/metadados do aparelho; logs; builds/APKs/caches; JSON Firebase legado duplicado; env/keystores/secrets. Não foram adicionados nem apagados. Nenhum manifesto piloto/intermediário de product images foi copiado do painel para o cliente. Os quatro manifests aprovados de imagens pertencem ao painel, que não recebeu commits nesta execução.

## STATUS FINAL DO WORKTREE

Após o commit documental deste relatório, o índice deve estar vazio e o worktree conserva apenas as oito entradas intencionais abaixo, verificadas também no fechamento:

```text
 M android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java
 M android/local.properties
 M ios/Runner/GeneratedPluginRegistrant.m
 M lib/screens/admin_screen.dart
 M lib/screens/registration_screen.dart
 M lib/widgets/chamae_logo.dart
 M lib/widgets/real_web_map.dart
?? tool/visual_device/capture.ps1
```

Este arquivo será adicionado e commitado separadamente no fechamento; por isso não integra a lista de remanescentes acima. Todas as entradas remanescentes correspondem a exclusões/revisões já descritas na auditoria, com a decisão específica do script de captura documentada nesta execução. O worktree **não está limpo**, intencionalmente.

## PRESERVAÇÃO E PENDÊNCIAS

- Comparação SHA-256 dos arquivos existentes na abertura: **zero arquivos de conteúdo alterados pela execução**, zero arquivos desaparecidos. Git add/commit preservou todos os bytes locais; a única criação intencional no repositório é este relatório. Cópia de recuperação dos arquivos alterados/novos e logs de validação ficaram somente em diretório temporário local, sem exposição no Git.
- Staging parcial: 16/16 caminhos obrigatórios usados; zero caminho proibido presente no diff dos commits de conteúdo.
- Pendente: setup do piloto E2E, com 40 falhas reproduzidas. Checkpoint local preservado não equivale a aprovação funcional integrada.
- Pendente de revisão local futura: capture.ps1 e normalização dos quatro M sem diff; gerados/configuração local continuam rastreados conforme decisão anterior de não alterar o índice deles.
- Firebase/Maps/OAuth: restrições externas não bloqueiam estes commits locais, mas bloqueiam produção/publicação até verificação de package/SHA, Play signing, bundle, APIs permitidas, origens/domínios/redirects. Nenhuma chave trocada, nenhum secret solicitado.
- Nenhum push, deploy, reset, clean, restore, checkout destrutivo, rebase, squash, exclusão ou correção funcional foi realizado.

CHECKPOINT LOCAL DO APP CLIENTE POSSUI PENDÊNCIAS
