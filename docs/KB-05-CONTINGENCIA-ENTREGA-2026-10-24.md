# KB-05 — Contingência da entrega — 24/10/2026

## Inventário anterior às alterações desta tarefa

Auditoria local de `order-operations.js`, `courier-assignment.js`,
`operational-contingency.js`, `order-cancellation.js`, do resolver de reserva em
`index.js`, das Rules e de `chamae_admin/lib/operational_contingency.dart`.
Alterações anteriores preservadas; cópias dos arquivos afetados em `tool/kb05/before`.

| Item | Estado anterior | Evidência / lacuna |
| --- | --- | --- |
| Fluxo principal | IMPLEMENTADO | Separação, atribuição, despacho e conclusão transacionais; financeiro oficial e motoboy cadastrado exigidos. |
| Contingência administrativa | PARCIAL | Superadmin, motivo, confirmação digitada e auditoria; somente atribuir/despachar/concluir. |
| Tentativa frustrada | AUSENTE | Sem contrato para ausência, endereço incorreto, recusa, falha de cobrança ou transporte. |
| Confirmação física e cobrança | PARCIAL | A conclusão exige estado/financeiro/estoque, mas não declaração explícita de entrega integral e cobrança efetiva. Resolver legado infere cobrança de `Concluído`. |
| Retorno físico | PARCIAL | KB-04 autoriza RESTOCK local após COMMIT; não registra condição física intacta/parcial/não retornável. |
| Cancelamento em rota | PARCIAL | KB-04 pode liberar reserva local em cancelamento mesmo após saída, sem comprovar retorno físico. |
| Reentrega | AUSENTE | Sem agenda, novo despacho, transferência ou cobrança autorizada específica. |
| Idempotência | PARCIAL | Ledgers existentes protegem atribuição, conclusão e compensação; faltam versão e recibo para incidentes. |
| Conectividade | PARCIAL | Transações e reexecução existentes; painel não congela o comando durante resultado incerto. |
| Privacidade | IMPLEMENTADO | Orders sem escrita SDK; auditorias privadas por padrão. Novos motivos devem permanecer privados. |
| App motoboy / resgate | AUSENTE | Contrato de fila preparado; sem integração de ofertas, GPS, presença ou resgate. |
| Painel | PARCIAL | Área exclusiva de contingência existe; faltam tentativa, condição de retorno, pendência e proteção da conclusão. |

## Resultado

**KB-05: PARCIAL.** Controles locais implementados e testados. Não há aprovação
operacional física, implantação ou integração de reembolso/estoque externo nesta tarefa.
Data-base do documento: 24/10/2026; validações locais encerradas na virada para 25/10/2026.

## Contrato implementado

`chamaeRegistrarContingenciaEntrega`, região `southamerica-east1`, exige Auth
não anônimo, role `superadmin`, ausência de perfil de entregador para o ator,
motivo de 10–500 caracteres e `CONFIRMAR {orderId}`. Não aceita valores,
pagamento, estoque, coordenadas ou timestamp enviados pelo painel.

Campos comuns: `orderId`, `requestId` (16–100 caracteres), `action`,
`expectedStatus`, `expectedRevision`, `contingencyReason`, `confirmation`.

| Ação | Dados específicos | Resultado |
| --- | --- | --- |
| `attempt` | `reasonCode` enumerado | Pendência `pending`, tentativa não entregue, sem concluir/cancelar/cobrar/movimentar estoque. |
| `return` | `returnCondition`: `intact`, `partial` ou `nonreturnable`; `returnAuthorized: true` | `returned`: registra a condição conferida fisicamente e declarada pelo superadmin. Não executa RESTOCK. |
| `redelivery` | Nenhum valor/horário adicional | `redelivery_pending`, `redeliveryMode: manual_pending`. Somente registro de intenção futura. |

Motivos: `customer_not_located`, `wrong_address`, `no_answer`, `refused`,
`no_change`, `payment_refused`, `courier_problem`, `vehicle_broken`,
`delivery_interrupted`. Não são alterações do endereço validado ou do motoboy.
Transferência, resgate, GPS, ETA e presença continuam indisponíveis.

Persistência:

- `orders/{id}`: somente marcador público de fase/revisão do incidente; sem motivo ou observação privados.
- `orderDeliveryIncidents/{id}`: estado auxiliar versionado, necessidade de resolução/revisão de refund e condição de retorno, quando registrada.
- `orderDeliveryIncidents/{id}/events/{id}`: trilha com pedido, ator, timestamp do servidor, ação/motivo/resultado, status anterior/resultante, pagamento, ação de estoque e necessidade operacional. Eventos não são sobrescritos.
- `deliveryIncidentRequests/{sha256(actor:requestId)}`: recibo privado com fingerprint e resultado original.
- `operationalContingencyAudit`: conclusão inclui declarações de entrega/cobrança e ação de estoque; ledgers anteriores de operação/compensação permanecem.

Rules permitem leitura de incidentes/eventos apenas a superadmin não entregador;
nenhum SDK escreve neles, nos recibos, no pagamento ou nos marcadores de orders.
Observações limitadas a 500 caracteres; painel orienta não registrar telefone,
documento, endereço ou dados de cartão. O backend não copia PII do cliente para os eventos.

## Estados e conclusão

Permanece `Novo → Em Separação → Saiu para Entrega → Concluído`. Incidente não
retrocede o estado, não muda vínculo do motoboy, não conclui e não cancela.
`attempt` só opera em separação/rota; retorno também pode registrar recebimento
posterior de pedido cancelado/concluído, preservando seu status/pagamento.
Nova tentativa após retorno, conclusão ou reentrega planejada é rejeitada.

Uma pendência bloqueia atribuição e despacho. Conclusão exige todos os controles
anteriores de financeiro oficial, estoque, motoboy real ativo e timestamps,
acrescidos de `deliveryConfirmed: true`, `expectedDeliveryRevision` atual e
`collectionConfirmed: true` quando ainda não Pago. Pagamento desconhecido ou
COMMIT sem recebimento verificável exige revisão. Retorno/reentrega pendente
bloqueiam conclusão mesmo com checkbox/payload verdadeiro.

Se houve somente tentativa frustrada e posteriormente a entrega integral
ocorreu, a conclusão explícita resolve `pending` na mesma transação e preserva
o evento anterior. Não existe botão genérico de “resolvido” para ignorar retorno.
O resolver legado não infere cobrança apenas do texto `Concluído`: reserva
exige confirmação persistida de entrega/cobrança ou chamada interna já validada.
Histórico finalizado não é migrado. Recibo de conclusão anterior ao KB-05
continua reproduzível como leitura, sem nova conclusão/baixa.

## Pagamento, retorno e vínculo com KB-04

| Situação | Comportamento |
| --- | --- |
| Ausência, endereço incorreto, recusa, falta de troco, cartão recusado | Registra tentativa não entregue. Sem Pago, conclusão, nova cobrança ou movimento de estoque. |
| PIX Pago + falha operacional | Continua Pago/COMMIT. Incidente registra resolução e revisão de refund; não confirma reembolso. Cancelamento KB-04 mantém a necessidade financeira separada. |
| Dinheiro/cartão não recebido | Permanece pendente. Conclusão recusada sem confirmação explícita do recebimento integral. |
| Split | Preserva as partes persistidas e os snapshots originais; não redistribui valores nem cria compensação. Recebimento na conclusão refere-se a todas as partes pendentes. |
| Reserva antes da saída, sem incidente | Cancelamento segue RELEASE local vigente da KB-04. |
| Reserva em rota ou com incidente | Cancelamento exige registro atual de retorno integral intacto e autorizado antes de RELEASE. Trigger legado também relê essa evidência antes de liberar. |
| COMMIT | Incidente/retorno nunca recompõe estoque. RESTOCK permanece comando KB-04 separado, superadmin, quantidades oficiais e ledger, agora também exigindo retorno intacto autorizado. |
| Parcial / não retornável | Não autoriza compensação integral de estoque nem conclusão. Quantidades parciais/descarte/acerto exigem procedimento externo revisado; não há endpoint parcial nesta tarefa. |
| Concluído | Não admite cancelamento simples. Devolução separada preserva status, timestamps, pagamento, snapshots e salesCount históricos. |

A comprovação operacional implementada é a declaração de conferência física
do superadmin, auditada pelo backend. Ela **não prova** recebimento físico real
durante esta sessão nem ACK Oracle. Produtos mapeados/estoque integrado continuam
falhando fechado conforme KB-04. Fórmulas de preço/frete/taxas e algoritmos de
RESERVE/RELEASE/COMMIT/RESTOCK não foram substituídos; foram acrescentadas
pré-condições antes dos efeitos.

## Reentrega, conectividade e painel

O painel irmão recebeu somente ações no formulário de contingência existente:
tentativa com motivo enumerado, retorno com condição e declaração de conferência,
pendência de reentrega, confirmações separadas de entrega/cobrança, fase/revisão
e histórico privado dos últimos 30 eventos. Não houve redesign ou App Motoboy.

Reentrega pode ser registrada depois de tentativa/retorno. O pedido conserva
estado principal e financeiro original. Não há agenda executável, retorno à
separação, troca/resgate ou novo despacho/cobrança. A execução futura permanece
bloqueada até procedimento/implementação autorizados; o registro não promete
que o entregador já saiu novamente.

Transação compara status e revisão; concorrência reavalia essas pré-condições.
Recibo é consultado primeiro: mesmo comando retorna resultado original após
ACK perdido, mesmo com estado atual diferente. requestId com payload diferente
é rejeitado; comando atrasado com novo ID/revisão antiga é rejeitado.
Não há fila offline de alterações.

No painel, resultado incerto congela ID e payload; retry usa exatamente o
comando anterior, sem adotar a revisão nova do stream. Campos ficam bloqueados
até confirmação ou encerramento explícito da tentativa local. Ao reiniciar,
o painel consulta estado/histórico e não envia comando automaticamente.
O token pendente não é persistido no navegador após reinício: é obrigatório
reconciliar o histórico antes de registrar outra tentativa. Reabrir não é prova
de uma nova tentativa física. Retorno duplicado e eventos fora de ordem falham
fechado; nova tentativa intencional exige nova confirmação e revisão corrente.

## Evidências locais

| Verificação | Evidência |
| --- | --- |
| Functions | **403/403 aprovados**, incluindo 15 novos unitários. `tool/kb05/functions-final.log`. |
| Firestore/Auth Emulator | **391/391 aprovados** na rodada final, incluindo 27 cenários KB-05 e a regressão anterior de 364. `tool/kb05/emulator-final-after-review.log`. Rodada inicial: 387/387. |
| Flutter cliente | **40/40 aprovados**, aceite/pedidos/chat/conta/consolidação. `tool/kb05/flutter-affected.log`. |
| Flutter analyze cliente | **No issues found**. `tool/kb05/flutter-analyze.log`. Nenhum Dart de lib/test do cliente alterado. |
| Flutter painel afetado | **14/14 aprovados**, incluindo seis testes novos de formulário. `tool/kb05/panel-tests.log`. |
| Flutter analyze painel | Dois infos anteriores em `lib/main.dart:7`: `deprecated_member_use` e `avoid_web_libraries_in_flutter`. Sem novos apontamentos nos arquivos alterados. `tool/kb05/panel-analyze-final.log`. |
| ESLint do escopo | Aprovado. `tool/kb05/lint-scoped.log` e `lint-final-extra.log`. |
| Preservação | 12 arquivos protegidos com SHA-256 inalterado, incluindo dependências/locks, frete/configuração, horário/país, conta e confirmação. `tool/kb05/protected-before.json` e `protected-after.json`. |
| Checklist | Mesmos 196 IDs nos dois documentos; resultados operacionais em branco e gates preservados. `tool/kb05/checklist-consistency.json`. |

Emuladores usam somente projeto `demo-chamae-rules`, Firestore `127.0.0.1:8187`
e Auth local. Handlers/transações/Rules reais; nenhum PSP externo na suíte nova.
PIX Pago/COMMIT nessa suíte é fixture explícita: regressão KB-04 exercita
webhook/HMAC real do SDK contra provedor simulado. Não é comprovante de PIX real.
Perda de conexão é injetada antes/depois do commit, não um teste físico de rede.

Cobertura inclui os nove motivos, dinheiro/cartão não recebidos, PIX Pago,
split, retorno intacto/parcial/não retornável, reserva/COMMIT, cancelamento em
rota, RESTOCK autorizado, perda de ACK, reconstrução do handler, rollback,
duplicata, revisão atrasada, concorrência com conclusão/cancelamento,
pedido concluído, negação SDK/roles/perfil e leitura privada.

Comandos reproduzíveis, sem instalar dependências:

```text
# functions/
npm test
firebase emulators:exec --project demo-chamae-rules --only firestore,auth --config ../firebase.account-test.json "node --test --test-concurrency=1 test/delivery-contingency.emulator.spec.js test/order-cancellation.emulator.spec.js test/order-acceptance.emulator.spec.js test/firestore.rules.spec.js test/pilot.emulator.spec.js test/final-operations.emulator.spec.js test/delivery-radius.emulator.spec.js test/courier-assignment.emulator.spec.js test/courier-deliveries.emulator.spec.js test/order-chat.emulator.spec.js test/customer-account.emulator.spec.js"
# chamae_delivery/
flutter analyze --no-pub
flutter test --no-pub test/order_acceptance_test.dart test/customer_orders_test.dart test/order_chat_test.dart test/customer_account_cycle_test.dart test/app_client_final_test.dart
# chamae_admin/
flutter analyze --no-pub
flutter test --no-pub test/merchant_delivery_flow_test.dart test/delivery_contingency_test.dart
```

Flutter foi executado pelo entrypoint local `dart.exe flutter_tools.snapshot`,
com `--no-version-check --suppress-analytics`. Sem pub get/upgrade.

## Arquivos desta tarefa e pendências reais

Backend: novos `delivery-contingency.js`, `delivery-contingency-state.js` e
testes unitário/emulador. Integrações mínimas em `order-operations.js`,
`courier-assignment.js`, `operational-contingency.js`, `order-cancellation.js`,
`index.js`, Rules, scripts de teste e escopo ESLint. Fixtures positivas existentes
passaram a declarar confirmação/retorno; uma expectativa legada agora exige
falha segura sem confirmação. Snapshot financeiro e regras comerciais preservados.

Painel: `chamae_admin/lib/operational_contingency.dart` e novo
`test/delivery_contingency_test.dart`. Outros arquivos já modificados nos dois
repositórios foram preservados. Artefatos/cópias em `tool/kb05` usam `.dart.txt`
para não interferirem no analisador do App Cliente.

Pendências para revisão humana:

1. Aprovar responsável superadmin, disponibilidade, comunicação com entregador real e procedimento de conferência/retorno/reconciliação de rede.
2. Homologar sessão física na Pit Stop, build/cache do painel e revisão de backend/Rules autorizados. Nenhuma implantação foi feita aqui; painel novo depende da Function e das Rules correspondentes.
3. Reembolso/void PSP, ACK/estoque integrado e ajustes financeiros externos continuam nas dependências KB-02/KB-04. Não executar compensação física manual pelo espelho Firebase.
4. Entrega parcial/não retornável, descarte e recebimento parcial exigem revisão específica; não há compensação automática/integral liberada para esses casos.
5. Reentrega é intenção manual pendente. Sua execução completa/agenda/novo despacho/valor autorizado não está implementada; nenhuma taxa adicional foi criada.
6. Dois infos anteriores do painel permanecem fora do escopo. Nenhum gate ou resultado físico foi marcado como aprovado.

Firebase produção: **não acessado**. Oracle/GrandChef: **não acessados**.
Commit, push e deploy: **não realizados**. Trabalho encerrado para revisão humana.
