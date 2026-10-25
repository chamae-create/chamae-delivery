# KB-03 — Horário e país no backend — 24/10/2026

## Auditoria anterior às alterações

Escopo local: chamae_delivery. Alterações anteriores de frete, conta e aplicativo presentes e preservadas. Nenhum acesso Firebase produção, Oracle/GrandChef, pagamento, commit, push ou deploy.

| Caminho / item | Estado encontrado | Risco / encaminhamento |
| --- | --- | --- |
| Horário cliente | `lib/core/store_hours.dart`: UTC-4, abre às 08:00 e fecha às 00:00; checkout consulta o relógio do aparelho. | Interface não é autoridade. Usar relógio do backend e fuso explícito. |
| Criação direta de proposta | Rules exigem createdAt=request.time e contrato de endereço/consentimento, mas não horário nem método por país. | Adicionar bloqueio temporal e de métodos na criação; catálogo continua público. |
| PIX automático | `chamaeCriarPixAutomatico` prepara financeiro antes de chamar Mercado Pago, sem bloqueio operacional de horário/país. | Guardar entrada no preparo compartilhado antes de qualquer write/POST. |
| PIX manual direto | `chamaeCriarPix` é IAM-private e exige cabeçalho existente, mas usa o mesmo preparo sem as regras de horário/país. | Aplicar o mesmo guard; IAM não substitui regra comercial. |
| Dinheiro/maquininha/split | Trigger de reserva prepara financeiro e depois reserva estoque. Split vigente somente dinheiro. | Bloquear antes de gravar financeiro ou reservar; preservar métodos BR existentes. |
| Reuso de financeiro/retry | Financeiro já existente retorna antes das demais validações de compra. | Nova emissão de PIX/reserva ainda não executada deve revalidar o guard, inclusive após fechar; eventos já emitidos precisam reconciliar. |
| Origem temporal | Não há clock/fuso operacional no backend atual. Payload pode conter dados que não devem definir o horário. | `America/Campo_Grande` no Node; fonte temporal de servidor, nunca payload/createdAt cliente. |
| País/destino | `prepareDelivery` valida dono, coordenadas/país e cotação privada, mas `quoteDelivery` copia countryCode do cliente. | Cotação privada sozinha não prova geograficamente o país. Não inferir país por longitude nem nome de cidade. |
| Provedor de rota | Google Routes retorna metros/duração, sem comprovação de país. | Verificação geográfica de país no servidor, separada da precificação; ausência/erro/ambiguidade falha fechada. |
| Legados | Preparação de elegibilidade pula fluxo antigo; guarda de frete já exige cotação para financeiro novo. | Guard operacional sem exceção por customerFlowVersion; snapshots históricos não serão recalculados. |
| Webhook, liberação/conclusão e acerto | Processam efeitos de pedidos já emitidos/aceitos; não são criação de compra nova. | Não bloquear reconciliação de pagamento, liberação de reserva, entrega ou fechamento histórico por loja fechada. |
| Endpoints diagnósticos | `chamaePixTeste` e `chamaeMercadoPagoTeste` são IAM-private, não criam pedidos do checkout. | Não ampliar/alterar escopo diagnóstico nem pagamentos; registrar esse limite. |

Regra a aplicar: todos os dias, **[08:00:00, 24:00:00)** em Mato Grosso do Sul; 07:59 e 00:00 bloqueados; 08:00 e 23:59 permitidos. Catálogo e reconciliação de pedidos já aceitos permanecem disponíveis.

## Plano limitado ao KB-03

Guard compartilhado de horário/destino/método antes de novo financeiro e de novas tentativas de emissão/reserva; Rules protegendo propostas diretas. País verificado no servidor a partir das coordenadas e associado à cotação privada. Métodos PY: PIX/dinheiro e split vigente somente dinheiro; métodos BR atuais preservados. Códigos determinísticos, sem lógica dependente de mensagem.

A verificação geográfica real requer serviço/credencial de servidor autorizado. Não existe essa comprovação no contrato atual de rota. Integração pode ser preparada e testada localmente; não declarar KB-03 resolvido operacionalmente sem evidência externa. Nenhum preço/rota/país de produção será inventado.

## Implementação

- [order-acceptance.js](../functions/order-acceptance.js): guard compartilhado de horário, comprovação do país e método. Não há exceção por customerFlowVersion, timestamp, timezone, storeOpen ou horário enviado pelo cliente.
- [destination-country.js](../functions/destination-country.js): adaptador de Geocoding no servidor, com timeout e falha fechada. A consulta usa as coordenadas, sem region/country bias informado pelo cliente, e exige resultado de nível country BR/PY inequívoco, sem partial_match. Resultado ausente, múltiplos países, país diferente do declarado, serviço indisponível ou chave ausente retornam DESTINATION_COUNTRY_UNVERIFIED.
- [delivery-service.js](../functions/delivery-service.js): comprovação privada destinationVerification na cotação existente; não cria outro modelo de tabela/preço. Cache antigo sem prova é recusado; quote novo requer verificação antes de consultar a rota. Segredo dedicado de servidor CHAMAE_GEOCODING_API_KEY declarado junto ao segredo Routes na callable de cotação; nenhum valor foi consultado/configurado.
- [index.js](../functions/index.js): guard no preparo financeiro compartilhado, antes de qualquer escrita de financeiro/reserva. Revalida também quando já existe financeiro e ainda se tenta iniciar um novo efeito. PIX automático e manual têm uma segunda checagem de horário imediatamente antes do POST ao Mercado Pago.
- [firestore.rules](../firestore.rules): criação direta de propostas exige horário do servidor e método compatível com país; não restringe leitura do catálogo. O país declarado passa ainda pelo guard de comprovação privada antes do aceite financeiro.

Auditoria complementar: o ticket e a projeção de entrega podem usar deliveryLocation; o ticket pode ler aliases country. O guard agora exige que deliveryLocation, quando presente, coincida com o ponto confirmado da cotação e que os aliases não contradigam o país comprovado. Rules também conferem o GeoPoint e o alias do endereço. Não houve alteração em ticket, QR, projeções ou UI.

### Intervalo e timezone

Todos os dias, intervalo **[08:00:00.000, 24:00:00.000)**. O Node usa relógio de servidor (Date.now), Intl.DateTimeFormat com timeZone **America/Campo_Grande** e hourCycle h23. Não depende do timezone local do processo nem do aparelho.

Rules usam request.time, timestamp UTC de servidor. Como essa linguagem não resolve zonas IANA, o predicado explicita a regra atual MS UTC-4: hora UTC >=12 ou <4. Não usa timezone da máquina. Se houver mudança oficial futura do offset/DST operacional, esse espelho de Rules deve ser revisto junto da zona IANA; não é uma configuração enviada pelo cliente.

| MS | UTC usado no teste | Resultado |
| --- | --- | --- |
| 07:59 (incluindo 07:59:59.999 no unitário) | 24/10 11:59Z | Bloqueado |
| 08:00:00.000 | 24/10 12:00Z | Permitido, sujeitos aos demais requisitos |
| 12:00 | 24/10 16:00Z | Permitido |
| 23:59 (incluindo 23:59:59.999 no unitário) | 25/10 03:59Z | Permitido |
| 00:00:00.000 | 25/10 04:00Z | Bloqueado |

### Destino e métodos

Na coleção privada deliveryQuotes, destinationVerification contém schemaVersion 1, provider google-geocoding, countryCode, latitude, longitude e verifiedAtMs. Campos são gravados pelo servidor; não são aceitos do payload de cotação como evidência. Quotes continuam sem leitura/escrita por SDK cliente nas Rules. Coordenadas/país devem coincidir com destination, e a cotação deve manter vínculo válido de UID, pedido e destino conforme validateQuote existente.

| País comprovado | Métodos preservados |
| --- | --- |
| BR | PIX; Dinheiro; Maquininha; variantes legadas Débito/Crédito à vista já aceitas pelo backend; split vigente de duas/três parcelas exclusivamente Dinheiro. |
| PY | PIX; Dinheiro; split vigente exclusivamente Dinheiro. Maquininha e variantes recusadas. |
| Ausente/inválido/não comprovado/divergente | Nenhum aceite novo; falha fechada. |

Método, pixRequested, splitPayment e parcelas devem ser coerentes. Parcelas ocultas em pedido não dividido e cartão/PIX dentro do split não ampliam a política. Moedas, conversões, troco, preços, cobertura e cálculo de rota não foram alterados. A verificação certifica o país do ponto consultado; a homologação real da fronteira ainda é necessária, sem inferir país por texto/longitude ou fabricar resultado.

### Ordem e efeitos colaterais

1. Criação por SDK: Rules avaliam request.time e método por país, além do contrato anterior. Escritas fora do horário são negadas; Admin SDK ignora Rules, por isso o guard de Functions também é necessário.
2. Cotação: resolver país no servidor → obter rota pelo provedor existente → gravar cotação privada com prova. Isso não é lançamento financeiro de pedido.
3. PIX/reserva: ler pedido e eventual financeiro → avaliar relógio de servidor → verificar prova privada, ponto, aliases, proprietário e vínculo → validar método → continuar validações/cálculos existentes → gravar financeiro/reserva na transação anterior.
4. PIX: reavaliar horário imediatamente antes do POST. Se fechar entre a transação e o POST, não emitir cobrança; financeiro que foi congelado durante abertura permanece intacto. A autorização é o instante do servidor antes de enviar, sem prometer controlar o instante interno de processamento do PSP.
5. Erro de bloqueio pode gravar metadados de rejeição/revisão no pedido pelo mecanismo existente. Não cria financeiro quando o guard falha antes da transação; não reserva/baixa estoque nem emite PIX. Não se confunde metadado de erro com efeito de venda.

### Códigos de erro

| Código | Retorno/persistência |
| --- | --- |
| STORE_CLOSED | Guard HttpsError failed-precondition com details.reason; no preparo financeiro segue o padrão já existente de código em financialValidationError ou mercadoPagoLastErrorCode. HTTP manual retorna 400 e erro com o código. |
| DESTINATION_COUNTRY_UNVERIFIED | Cotação/guard com details.reason; preparo registra o mesmo código determinístico, sem URL/chave/detalhe cru do provedor. |
| PAYMENT_METHOD_NOT_ALLOWED_FOR_COUNTRY | Guard de método com details.reason e código persistido/HTTP pelo fluxo existente. |

Negação de uma escrita SDK pelas Rules continua sendo permission-denied; Rules não produzem HttpsError personalizado. A interface existente segue conservada. Nenhuma lógica nova compara texto traduzido da mensagem.

### Retry e históricos

Retry transacional reexecuta a checagem; financeiro congelado sozinho não permite iniciar PIX/reserva novos após fechar. Repetição de reserva já reserved/finalized/released e de PIX já identificado continua nos atalhos idempotentes anteriores, sem novo efeito.

Webhook de cobrança já emitida, resolução/liberação de reserva, conclusão de entrega, acertos e leituras históricas não recebem o bloqueio de compra nova. Pagamento emitido antes do fechamento pode confirmar depois; não perder a conciliação por loja fechada. Valores congelados, fórmulas, métodos de liquidação e efeitos de estoque existentes não foram reescritos.

Clientes legados não ganham isenção no preparo compartilhado. Cotações antigas sem prova de país não autorizam novas emissões/reservas; exigir nova cotação compatível ou revisão do pedido pendente. Não inventar prova para snapshot antigo nem recalcular financeiro histórico. Não há backfill/migração de pedidos nesta tarefa.

## Evidências e testes locais

| Verificação | Resultado / evidência |
| --- | --- |
| npm test | **374/374 aprovados**, incluindo 87 casos novos KB-03: 68 de caminhos financeiros/PIX/reserva, 17 de política/provedor e 2 de cotação/cache. Log tool/kb03/node-final.log. |
| Unitários adicionais de conta | Três aprovados no conjunto complementar de 20, com 17 de política já contados no npm test. Log tool/kb03/guard-unit-final.log; não somar os 17 novamente. |
| Emuladores Firestore/Auth | **343/343 aprovados**, incluindo 9 cenários novos de aceitação com múltiplas variações por horário/caminho/país, e regressão Rules, piloto, operação, raio, entregadores, chat e conta. Log tool/kb03/emulator-final.log. Somente demo-chamae-rules em 127.0.0.1:8187/9099. |
| Flutter analyze | **No issues found**, tool/kb03/flutter-analyze.log. |
| Flutter afetados | **42/42 aprovados**, tool/kb03/flutter-affected.log: aceite de pedido, checkout/frete, readiness BR/PY, estado da cotação e consolidação cliente. Nenhum Dart foi alterado. |
| ESLint do escopo | Aprovado, tool/kb03/lint-scoped-final.log. |
| ESLint global | Dois problemas preexistentes em test/customer-account.emulator.spec.js (max-len linha 175 e curly linha 184). Arquivo não editado nesta tarefa; fora de KB-03. Log tool/kb03/lint-all-final.log. |

Os testes de caminho real invocam o código de index.js para PIX automático, HTTP manual e reserva; comprovam ausência de POST/financeiro/reserva em bloqueios, incluindo clientes sem customerFlowVersion novo, clock falso, retry transacional, fechamento entre commit e POST, país ausente/inválido/forjado, dono errado, coordenadas/aliases divergentes, cotação reutilizada ou sem atestação. Confirmação por webhook após fechamento preserva o fluxo existente.

O horário das Functions é injetado pela dependência de relógio apenas nas harnesses locais, sem parâmetro HTTP, claim ou variável de ambiente que abra a loja. O SDK/Admin e os timestamps do emulador não têm Date global substituído. Para fronteiras de Rules, a harness troca **em memória** somente o argumento request.time do predicado real pelo timestamp do ensaio; mantém corpo da regra, autenticação, allowlists e createdAt==request.time. Há também caso com Rules não modificadas e request.time real. Não publicar as Rules temporais de teste.

Geocoding e Mercado Pago foram simulados por doubles/fetch de teste; não houve consulta geográfica, emissão de PIX ou pagamento reais. O emulador testa transações e negações de Rules reais; não valida IAM de uma implantação, segredo provisionado ou evento remoto. As primeiras execuções detectaram e corrigiram a invocação do wrapper HTTP na harness e o uso de propriedades em vez de métodos latitude()/longitude() no novo trecho de Rules; critérios de aceite não foram relaxados.

Comandos locais reproduzíveis, após preparar ferramentas e sem conexão a produção:

```powershell
# No diretório functions, sem instalar/atualizar dependências:
npm test
firebase emulators:exec --project demo-chamae-rules --only firestore,auth --config ../firebase.account-test.json "node --test --test-concurrency=1 test/order-acceptance.emulator.spec.js test/firestore.rules.spec.js test/pilot.emulator.spec.js test/final-operations.emulator.spec.js test/delivery-radius.emulator.spec.js test/courier-assignment.emulator.spec.js test/courier-deliveries.emulator.spec.js test/order-chat.emulator.spec.js test/customer-account.emulator.spec.js"
# Na raiz chamae_delivery:
flutter analyze --no-pub
flutter test --no-pub test/order_acceptance_test.dart test/checkout_delivery_contract_test.dart test/client_readiness_test.dart test/delivery_quote_state_test.dart test/app_client_final_test.dart
```

No ambiente desta tarefa o entrypoint local flutter_tools.snapshot do SDK foi chamado por dart.exe com --no-version-check --suppress-analytics para executar analyze/test; não houve pub get. Script test:acceptance:emulator também adicionado, para ser usado dentro do emulador local. package.json mudou somente scripts; versões de dependências e lockfiles permanecem iguais.

## Estado e pendências

**KB-03: PARCIAL.** Proteções implementadas e verificadas localmente; não são declaração de implantação/homologação real.

Pendências para encerrar o bloqueador:

1. Disponibilizar serviço Geocoding autorizado e segredo de servidor CHAMAE_GEOCODING_API_KEY, com API/restrições/cota adequadas. Nenhuma credencial foi criada ou consultada. Sem o serviço, novos quotes/compras falham fechados; não usar o país do cliente como fallback.
2. Homologar destinos BR/PY reais, incluindo proximidade/fronteira e respostas ambíguas, e compatibilidade do serviço com o ambiente de rotas. Confirmar orçamento de latência: timeout Geocoding 8 s + Routes existente 10 s pode exceder a espera atual de 15 s do cliente em falha/lentidão; cliente exige retry seguro, sem aceite financeiro. Nenhum timeout/layout Dart foi alterado nesta tarefa.
3. Em trabalho futuro autorizado, disponibilizar Functions e Rules compatíveis, invalidar/reemitir cotações sem prova de país e validar caminhos remotos/erros/horários na revisão implantada. Não há deploy nesta entrega.
4. Revisão humana de compatibilidade de pedidos pendentes/legados antes da ativação. Pedidos já pagos/reservados continuam conciliáveis; financeiro histórico não deve ser reconstruído para adicionar prova.

As checklists oficiais foram atualizadas somente no KB-03 e nas pré-condições diretamente dependentes da comprovação de país. Nenhum gate operacional foi marcado PASSOU nem outro KB foi encerrado.

## Preservação e fontes

Backups do estado anterior: tool/kb03/before. Hashes de contratos protegidos: tool/kb03/protected-before.json. Comparação final confirmou preservação de cálculo de faixas/Routes, configurações de preço, operações/atribuição, exclusão/onboarding, pubspec e lockfiles; a única diferença no conjunto protegido é package.json pelos scripts de teste. Não houve alteração de UI, modelos monetários ou regra de estoque físico.

Referências públicas consultadas: [Geocoding reverso v3](https://developers.google.com/maps/documentation/geocoding/guides-v3/requests-reverse-geocoding), [Timestamp Rules em UTC](https://firebase.google.com/docs/reference/rules/rules.Timestamp), [LatLng Rules](https://firebase.google.com/docs/reference/rules/rules.LatLng) e [Intl no Node](https://nodejs.org/api/intl.html). Consultas de documentação pública não acessam dados operacionais.

Firebase produção: não acessado. Oracle/GrandChef: não acessado. Commit: não realizado. Push: não realizado. Deploy: não realizado. Aguardar revisão humana.
