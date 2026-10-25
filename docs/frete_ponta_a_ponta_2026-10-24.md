# Frete por distância — auditoria e implementação

Data: 24/10/2026. Inventário abaixo concluído antes de alterar código funcional. Escopo: código local de `chamae_delivery` e leitura do contrato consolidado em `../chamae_admin/lib/delivery_settings.dart`. Não houve consulta nem alteração de configuração de produção. Modificações já presentes no workspace são de outras tarefas e devem ser preservadas.

## Inventário inicial

| Item | Classificação inicial | Evidência e diagnóstico |
| --- | --- | --- |
| DeliveryCalculator | AUSENTE | Não existe classe/arquivo com esse nome no código atual. O cálculo vigente está em `functions/delivery-pricing.js`, não em Dart. |
| Haversine | AUSENTE | Nenhuma implementação/referência encontrada no app/backend atual; nenhum cálculo geodésico autoriza o financeiro. Não há motivo para introduzir estimativa. |
| Origem Pit Stop V8 | PARCIAL | Painel solicita coordenadas reais; publicação exige `table.origin`. Backend usa essa origem. Template local contém `origin: null`; coordenadas reais/configuração externa não verificadas. Mapa ilustrativo `real_web_map.dart` e centro inicial `address_map_screen.dart` não são origem financeira. |
| Endereço e localização do cliente | IMPLEMENTADO | `DeliveryAddress`, telas de destino/mapa, workspace e Rules exigem destino confirmado BR/PY e coordenadas. Cotação associa coordenadas/país/UID; falta reforçar confirmação também no aceite privado. Centro de mapa em falha de GPS é referência de seleção, não rota calculada. |
| Checkout | PARCIAL | Reconsulta antes de enviar, invalida ao trocar endereço e compara preço; quando `quoter` é omitido, não inicia consulta, mostra R$ 10 e libera botão. A Home injeta quoter, mas o componente isolado permite esse comportamento. |
| Criação do pedido | PARCIAL | Cliente cria proposta com `deliveryQuoteId`; financeiro/estoque oficiais são assíncronos. Rejeição financeira impede aceite. Valores de frete/distância/versão do cliente não determinam financeiro no caminho por rota. Caminho legado ainda permite aprovação sem cotação. |
| Firebase Functions | PARCIAL | Callables de salvar/publicar e cotar; `prepareDelivery` revalida cotação privada e versão ativa. `mode: legacy` cotado por R$ 10 e pedidos antigos sem configuração usam tarifa fixa. |
| Google Routes | IMPLEMENTADO | `google-routes-provider.js`, segredo dedicado `CHAMAE_ROUTES_API_KEY`, timeout, distância retornada em metros, rejeição de `fallbackInfo`. Modo DRIVE/TWO_WHEELER obrigatório; ausência de segredo/modo bloqueia. Disponibilidade real externa não verificada. |
| Tabela, limites e faixas | IMPLEMENTADO | Mesmo schema 2 do painel; centavos inteiros, sequência sem lacuna/sobreposição, até 300 faixas/30.000 m, suporte a 100 m; seleção sem arredondar distância. |
| Status/ponteiro ativo | PARCIAL | Ponteiro ativo transacional e `published` conferido; status explicitamente inativo/draft com `published: true` e ponteiro inválido precisam rejeição consistente. |
| Order financials | PARCIAL | `orderFinancials` congela frete, metros, versão, origem, destino, provedor e instante; replica em `orders`. Falta unidade explícita, natureza de rota e faixa aplicada. Financeiro já existente é reutilizado antes de ler tabela atual. |
| R$ 10 fixos | LEGADO A SUBSTITUIR | Getter do checkout, resposta legacy em `quoteDelivery`, `legacyFeeCents=1000` em `prepareDelivery`, constante `FRETE_PEDIDO_CENTAVOS=1000` em `index.js`. |
| Piso R$ 8 | LEGADO A SUBSTITUIR | `floor800` em `priceForDistance` lê versões históricas; novas publicações já rejeitam. Não é necessário para preservar snapshots já congelados. Mensagens sobre piso apenas explicam rejeição, não são preço novo. |
| Outros preços predefinidos | LEGADO A SUBSTITUIR | `functions/config/delivery-pricing-initial.json`: 28 faixas habilitadas com preços entre 600 e 4000 centavos. Importado somente por teste, mas localização sugere configuração utilizável. Isolar valores como fixture de teste e deixar template sem preço e desabilitado, como o painel atual. |
| Fallbacks | LEGADO A SUBSTITUIR | Fallback financeiro R$ 10 sem configuração/legacy; ausência de rota já falha com segurança. Cliente usa zero internamente durante ausência de cotação quando há injeção; não deve exibir total final nem permitir compra nesse estado. |
| Frete calculado somente no cliente | LEGADO A SUBSTITUIR | Único valor financeiro autônomo identificado é o fallback de R$ 10 no checkout. Não existe tabela de distâncias/preços paralela no Dart. |
| Duplicação app/backend | PARCIAL | Painel valida formulário e backend revalida o mesmo payload (defesa necessária). Cliente soma prévia de itens/taxas; backend recalcula financeiro. Duplicação indevida é a tarifa fixa cliente/backend. Não criar calculadora de faixas no app. |
| Permissões/histórico | IMPLEMENTADO | Somente superadmin não anônimo, sem cadastro courier, salva/publica via callable. Rules bloqueiam escrita direta em config/versões; cotações e financeiros privados. Versões imutáveis com autor/datas, rascunho separado, publicação atômica e retry não reativa versão superada. |
| Testes existentes | PARCIAL | Cobrem limites, adulteração, concorrência, expiração, isolamento de rascunho e congelamento. Algumas fixtures financeiras/piloto dependem do fallback legado e precisam passar a fornecer cotações de teste explícitas. |

## Contrato compartilhado preservado

- `deliveryConfiguration/current`: `mode: routeBands`, `activeVersion`; `travelMode` operacional opcional no documento, obrigatório para chamar o provedor real. Sem modo escolhido, não inferir transporte. Publicação preserva campos operacionais existentes.
- `deliveryConfiguration/draft`: `draftVersion`, `updatedAt`, `updatedBy`; não autoriza cotação.
- `deliveryPricingVersions/{id}`: `version`, `status: draft|published`, `published`, `table`, `maxDistanceMeters`, `fingerprint`, `authorUid`, `createdBy`, `createdAt`, `updatedAt`, `publishedAt`, `publishedBy`.
- `table`: `schemaVersion: 2`, `minimumPolicy: replace`, `origin: {latitude, longitude}`, `maxDistanceMeters`, `bands`.
- Cada faixa: `minExclusiveMeters`, `maxInclusiveMeters`, `priceCents`, `enabled`, `order`. Primeira inclui zero; seguintes representam `(min, max]`. Exatamente 1.000 m pertence à faixa que termina em 1.000 m. Faixas começam em zero e terminam no alcance configurado, até 30.000 m. Limites e preços são inteiros seguros; zero só é preço válido quando escolhido explicitamente pelo administrador.
- `chamaeSalvarConfiguracaoEntrega({table,publish,requestId})` retorna versão/publicação/ativação. Editor do painel usa aliases internos `fromMeters/toMeters/feeCents/status`, mas envia schema 2 com `deliveryTablePayload`; não há divergência nesse mapeamento.
- Configuração ativa é exclusivamente a versão publicada apontada por `current`. Versões antigas publicadas permanecem no histórico; não representam várias tabelas ativas. Não existe comando independente de desativação no painel; modo inválido, ausência de ponteiro ou versão não publicada deve bloquear.
- `chamaeCotarEntrega({destination,requestId})` consulta rota no servidor e grava `deliveryQuotes/{id}` privado com TTL de cinco minutos. Pedido referencia a cotação; não escolhe a versão financeira.
- Rules em `chamae_delivery/firestore.rules` são autoritativas; painel não possui um ruleset alternativo de frete a publicar.

## Correções planejadas a partir do inventário

Eliminar autorização de novos financeiros por tarifa fixa, inclusive pedidos sem `customerFlowVersion`. Preservar exclusivamente financeiros já congelados. Remover piso histórico do cálculo de novas rotas; manter leitura de pedidos históricos sem recalcular. Completar snapshot com unidade, natureza da distância e faixa aplicada. Validar status e ponteiro no backend. Checkout deve sempre solicitar cotação e ocultar total/frete numérico enquanto indisponíveis. Configuração local inicial deve seguir rascunho vazio de preço do painel. Adaptar testes legados para usar tabelas/cotações explicitamente sintéticas.

## Resultado implementado

| Item corrigido | Classificação final | Resultado |
| --- | --- | --- |
| Cotação e novos financeiros sem tabela válida | IMPLEMENTADO | Ausência de configuração, modo legacy, ponteiro inválido, rascunho/inativo ou schema desconhecido bloqueiam. Nenhuma geração de financeiro novo recebe tarifa de contingência. |
| Checkout sem dependência injetada | IMPLEMENTADO | Sempre consulta `FirebaseDeliveryQuoter`; falha oculta frete/total numérico e bloqueia finalização. Zero interno é apenas placeholder aritmético, não frete aprovado. |
| Contrato de resposta do servidor | IMPLEMENTADO | Cliente aceita somente routeBands com ID/versão, distância finita dentro do limite técnico, origem de distância `route`, unidade `m`, provedor identificado e validade temporal. Resposta antiga legacy/incompleta/expirada falha com segurança. |
| Faixa e unidade no financeiro/pedido | IMPLEMENTADO | Persistidos pelo backend nos dois documentos, associados à cotação privada e tabela revalidadas. |
| Tarifas R$ 10 e piso R$ 8 | IMPLEMENTADO | Removidos dos cálculos de novos pedidos; `floor800` não precifica novas rotas. Referências monetárias restantes em mensagens de rejeição, histórico documental e testes não constituem tarifa operacional. |
| Template com preços predefinidos | IMPLEMENTADO | `functions/config/delivery-pricing-initial.json` agora contém origem nula, preço nulo e faixa desabilitada, igual ao rascunho inicial do painel. Valores anteriores foram isolados em `functions/test/delivery-pricing-fixture.json`, importado apenas por testes. |
| Compatibilidade com painel | IMPLEMENTADO | Coleções, callable de salvar/publicar, schema 2 e estrutura das faixas preservados. Publicação do painel existente continua válida. Nenhuma mudança no repositório admin foi necessária. |
| Operação com Routes real e origem real | PARCIAL | Adaptador e contrato implementados, mas disponibilidade/configuração externas não verificadas nesta auditoria local. Sem elas, a entrega falha com segurança. |

### Registro congelado

`deliverySnapshot` guarda `deliveryFee` em BRL, `distanceMeters`, `distanceUnit: m`, `distanceSource: route`, `configurationVersion`, `quotedAtMs`, `origin`, `destination`, `routingProvider` e `appliedBand`. A faixa contém os mesmos campos canônicos da tabela (`minExclusiveMeters`, `maxInclusiveMeters`, `priceCents`, `enabled`, `order`).

Em `orderFinancials/{orderId}` e `orders/{orderId}`, o backend também grava os campos de consulta `deliveryFee`, `deliveryDistanceMeters`, `deliveryDistanceUnit`, `deliveryDistanceSource`, `deliveryPricingVersion`, `deliveryAppliedBand`, `routingProvider` e `deliveryQuotedAtMs`. Esses campos não foram adicionados à lista de campos permitidos na criação pelo cliente; continuam pertencendo ao backend. O cliente envia apenas a proposta financeira e a referência `deliveryQuoteId`.

`prepareDelivery` exige dono/destino/país/confirmação, validade da cotação privada, vínculo de uso único ao pedido, unidade e natureza da distância; resolve a versão ativa no servidor, valida origem e tabela, seleciona a faixa sem arredondamento e compara preço/versão. O financeiro e o vínculo da cotação são gravados pela mesma transação de estoque/financeiro já existente.

Versões publicadas antigas sem campo opcional `status`/`version` continuam legíveis quando o ponteiro fornece a identidade e `published` é estritamente verdadeiro. Status explícito diferente de `published` ou ID explicitamente divergente bloqueia. Aliases históricos de faixas com política `replace` continuam normalizados para o contrato canônico; não é um segundo modelo de publicação. Novas publicações sempre gravam schema 2.

### Compatibilidade e ativação

- Financeiro já congelado é retornado antes da consulta à configuração atual, preservando valores após redução de cobertura, desativação ou indisponibilidade do provedor. Snapshots antigos sem os campos novos não são migrados nem recalculados. PIX já emitido e reservas históricas conservam os caminhos existentes de reconciliação, sem uma nova tarifa automática.
- Pedidos antigos ainda sem financeiro congelado passam a exigir cotação válida. `mode: legacy` deixa de autorizar compras novas. Isso é uma restrição intencional: ausência de tabela não representa aprovação de R$ 10.
- Cotações privadas emitidas pela versão anterior, sem `distanceUnit`/`distanceSource`, exigem atualização. Seu prazo normal é cinco minutos. Publicar o backend compatível antes do app novo evita resposta incompleta; pedidos já confirmados não dependem dessa atualização.
- Para ativação real: confirmar coordenadas Pit Stop V8 no painel e publicar os preços efetivamente escolhidos pelo administrador; provisionar/habilitar Google Routes e o segredo dedicado no backend; configurar explicitamente `deliveryConfiguration/current.travelMode` como DRIVE ou TWO_WHEELER conforme decisão operacional; disponibilizar backend e cliente compatíveis e homologar rotas reais BR/PY, fronteiras das faixas, cobertura, indisponibilidade e conferência de pedidos/financeiros. O painel preserva esse campo operacional ao publicar, mas não oferece editor dele nesta versão.
- O mapa ilustrativo de acompanhamento não fornece distância ao frete. O centro de referência do mapa em falha de GPS tampouco fornece origem Pit Stop V8. Não foram convertidos em fonte de distância de rota.
- Nenhuma origem, chave, rota real ou preço comercial foi inventado. Nenhum deploy, alteração de Firestore de produção, commit ou push foi executado.

## Validação local

| Verificação | Resultado | Evidência local |
| --- | --- | --- |
| Suite padrão Node/backend | 287 aprovados, zero falhas | `tool/frete_backend_tests_final.log` |
| ESLint completo de functions | Aprovado | `tool/frete_backend_lint.log` |
| Flutter: cotação, checkout e readiness | 26 aprovados | `tool/frete_flutter_verified.log` |
| Checkout Web no Chrome | 1 aprovado | `tool/frete_checkout_chrome_verified.log` |
| Flutter analyze dos 5 arquivos Dart alterados | Sem apontamentos | `tool/frete_flutter_analyze.log` |
| Firestore Emulator: Rules, piloto de pedido, raio e operação | 268 aprovados, zero falhas | `tool/frete_emulator_final.log` |

A suíte do emulador usa exclusivamente `demo-chamae-rules`, host local `127.0.0.1:8187`, configuração `firebase.frete-test.json` e fixtures de preço/rota privadas de teste. Comando: `firebase emulators:exec --project demo-chamae-rules --only firestore --config firebase.frete-test.json "node --test --test-concurrency=1 functions/test/firestore.rules.spec.js functions/test/pilot.emulator.spec.js functions/test/delivery-radius.emulator.spec.js functions/test/final-operations.emulator.spec.js"`.

Cobertura nova inclui 300 faixas de 100 m até 30 km, limites inclusivos/exclusivos, preço/faixa/unidade/natureza persistidos, rejeição de modo legado em todos os criadores de financeiro, status inativo/draft inconsistente, schema desconhecido, origem alterada, expiração, cotação reutilizada, dados adulterados e preservação de financeiro mesmo sem configuração atual. As fixtures de integração do piloto e da operação foram atualizadas para cotações explícitas, sem depender do fallback removido.

Os primeiros comandos Flutter/Firebase sob sandbox não puderam abrir caches fora do workspace; a revisão automática autorizou as execuções locais com acesso aos respectivos SDKs. O primeiro arquivo de configuração do emulador em subdiretório foi rejeitado pelo CLI por referência às Rules fora de sua raiz; a configuração final fica na raiz do projeto e a execução acima passou. Ajustes de estilo detectados pelo lint foram corrigidos. Os avisos de vídeo sem implementação no runner Flutter e as recusas de escrita esperadas dos testes de Rules não causaram falhas. Não houve Functions Emulator, pagamento externo nem chamada Google Routes real.

O teste Chrome encontrou dois problemas de infraestrutura do SDK local: o snapshot pré-compilado referencia `host.dart.js` em um caminho da máquina de build do Flutter; o servidor de teste não entrega CanvasKit em Windows, retornando 404 apesar dos arquivos presentes no cache. A execução aprovada usou `dart --packages=C:\flutter\packages\flutter_tools\.dart_tool\package_config.json C:\flutter\packages\flutter_tools\bin\flutter_tools.dart test --no-pub --platform chrome test/checkout_web_test.dart --reporter expanded`. Para entregar os arquivos estáticos, duas cópias exatas do SDK (`canvaskit/chromium/canvaskit.js` e `.wasm`) ficaram temporariamente em `test/canvaskit/chromium`, servido pelo próprio runner. O iframe da suíte foi recarregado antes da execução das asserções, após verificar HTTP 200 dos recursos locais. O caso executou e passou; arquivos/diretórios auxiliares foram removidos ao final. Nenhuma alteração permanente no SDK, no código do app ou nas asserções foi usada para contornar esses problemas de ambiente.

Este relatório substitui, para o comportamento atual, as descrições históricas de modo legacy, piso e tabela inicial predefinida nos relatórios anteriores. Eles permanecem como histórico, sem autoridade para configurar preços de produção.
