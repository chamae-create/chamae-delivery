# KB-04 — Cancelamento e compensações — 24/10/2026

## Inventário antes de alterar código

Inspeção local de chamae_delivery e leitura do Painel em chamae_admin. Nenhum acesso Firebase produção, Oracle/GrandChef ou pagamento real. Alterações anteriores, inclusive KB-03, presentes e preservadas.

| Item/caminho | Classificação | Comportamento encontrado |
| --- | --- | --- |
| Descarte de proposta | IMPLEMENTADO | chamaeDescartarPropostaPedido só descarta tentativa sem pedido. Tombstone impede write atrasado; pedido existente não é cancelado. |
| Cancelamento de pedido | AUSENTE | Nenhuma callable completa autorizada de cancelamento, motivo, ator ou compensação. Rules negam update direto de orders. |
| RESERVE Firebase existente | IMPLEMENTADO | Trigger de entrega valida financeiro e incrementa reservedStock. Não é comprovação de decremento físico Oracle no RESERVE. |
| RELEASE existente | PARCIAL | resolverReservaNaTransacao reage a status contendo cancel; reduz reservedStock uma vez e marca released. Não há comando oficial que leve o pedido a Cancelado atomicamente com essa liberação. |
| COMMIT/finalização Firebase | IMPLEMENTADO | Finalização reduz stock/reservedStock e aumenta salesCount; PIX pago baixa stock no webhook. Não equivale ao COMMIT físico lógico do modelo integrado. Preservar sem mudar arquitetura nesta tarefa. |
| Integração física RESERVE/RELEASE/COMMIT/RESTOCK | AUSENTE NESTES MÓDULOS | Bridge/ledger/ACK não localizados; produtos mapeados usam PRO_CODIGO. Não inferir ACK nem alterar Oracle. |
| RESTOCK | AUSENTE | Não há fluxo autorizado e idempotente de devolução após baixa comprovada. |
| PIX antes de emissão/reserva tardia | PARCIAL | KB-03 guarda horário/país, mas não cancelamento. Triggers podem executar após Cancelado; nova cobrança/reserva não tem trava de cancelamento. |
| PIX em criação concorrente | PARCIAL | POST ocorre fora de transação. Salvamento posterior pode sobrescrever status/pagamento, inclusive reabrir cancelado ou reverter confirmação chegada antes da resposta. |
| Webhook pago tardio | LEGADO A SUBSTITUIR NESTE CASO | Confere vínculo/valor/assinatura e deduplica Pago, mas não trata cancelamento antes de baixar estoque. Pode debitar pedido cancelado. |
| PIX expirado/cancelado no provedor | PARCIAL | Eventos não pagos retornam sem conciliar cancelamento/liberação. Nenhuma política completa de expiração/compensação. |
| Refund/void PSP | AUSENTE | Não há integração homologada de refund ou cancelamento remoto. Não declarar estorno/void confirmado nem inventar chamada externa. |
| Pedido Concluído | PARCIAL | Operações sequenciais preservam fluxo atual, mas não há devolução separada. Cancelamento simples de concluído deve falhar fechado. |
| Snapshots financeiros | IMPLEMENTADO | orderFinancials congela taxas/total/IDs; cancelamento não pode apagá-los/recalculá-los. Campo canônico totalBRL, financialValidationStatus. |
| Comissão 3% | PARCIAL | merchantFee é calculada em centavos e congelada. Não foi localizado ledger autônomo de comissão pendente/recolhida. Painel exclui Cancelado do fechamento e CSV. Não confundir courierPaid (repasse de entregador) com comissão. |
| Auditoria de cancelamento/compensação | AUSENTE | Há trilhas de outras operações, mas não um ledger específico deste ciclo. |
| Segurança | IMPLEMENTADO/PARCIAL | Allowlist de criação e default deny protegem campos/coleções internas. Faltam contratos backend de cancelamento/devolução. |

## Escopo de implementação derivado do inventário

Comandos backend autorizados e idempotentes, com motivo/ator/tempo/antes/depois; cancelamento pré-COMMIT com RELEASE local na mesma transação; pós-baixa exige devolução separada; concluído não é cancelado. Refund e cancelamento remoto do PIX ficam como necessidade explícita, sem confirmação fictícia. Corrigir somente os pontos comprovados de concorrência: nova criação/reserva, salvamento tardio de PIX e webhook pago depois do cancelamento.

Operações de estoque local serão identificadas como modelo Firebase existente. Para produtos mapeados PRO_CODIGO ou estado integrado não comprovado, falhar fechado até existir adaptador/ledger/ACK real; não criar um segundo decremento físico nem apresentar o estoque do emulador como Oracle homologado.

## Implementação local

Novos módulos [order-cancellation.js](../functions/order-cancellation.js) e [order-cancellation-state.js](../functions/order-cancellation-state.js); conexões limitadas em [index.js](../functions/index.js). Não houve alteração de UI, Rules, contratos de frete, preços, câmbio, fórmulas financeiras ou arquitetura física Oracle/GrandChef. A rotina existente de RELEASE é reutilizada em modo estrito na mesma transação do cancelamento.

### Contratos administrativos

| Callable | Permissão | Payload permitido | Efeito |
| --- | --- | --- | --- |
| chamaeCancelarPedido | operations_admin/superadmin; pedido já Pago exige superadmin; conta courier negada | orderId, requestId, reason, confirmation igual a CANCELAR {ID documental} | Cancela operação, libera reserva local comprovada antes da baixa e registra compensações. Não cancela cobrança no PSP nem estorna dinheiro. |
| chamaeAutorizarDevolucaoPedido | Somente superadmin, sem cadastro courier | Mesmos campos; confirmation igual a DEVOLVER {ID documental} | Autoriza e **aplica** uma devolução local integral após baixa comprovada. Executar somente após conferência humana do retorno dos produtos. Não é mera intenção futura de devolver. |

IDs documentais aceitos: letras/números/underscore/hífen, 1–128 caracteres. requestId: 16–100 caracteres, mesmo alfabeto, estável nos retries. reason: 10–500 caracteres após trim; não inserir dados pessoais desnecessários. Valores, quantidades devolvidas, país, paymentStatus, refundStatus, compensationStatus, ator e timestamps **não são campos de entrada**. Não há cancelamento final autoritativo por cliente comum nem escrita direta de SDK.

Retorno contém orderId, operation e replayed; isso **não é comprovante de cancelamento remoto/refund**. Resultado financeiro/estoque e motivos ficam em registros privados, inspecionáveis somente por backend/Admin autorizado. Nenhum botão/integração de painel foi acrescentado nesta tarefa; integração operacional desses contratos permanece pendente de revisão.

### Persistência, auditoria e idempotência

- orderCancellations/{orderId}: uma decisão de cancelamento, motivo, ator, timestamp de servidor, estado anterior, estado final, ação de estoque e financeira.
- orderReturns/{orderId}: uma devolução integral autorizada/aplicada; mesmos elementos de auditoria. Devolução parcial não foi implementada nem inferida.
- orderCompensationRequests/{hash(ator:requestId)}: recibo/fingerprint de operação + pedido + motivo. Reuso da chave com outra operação/pedido/motivo é recusado. ACK perdido e novo processador consultam o mesmo recibo durável.
- orderCompensations/{orderId}: necessidade financeira e estado de estoque local; originalMerchantFee e officialTotalBRL apenas referenciam valores congelados. Não é um novo motor de taxas/comissão.
- orderCompensationAudit: confirmação de pagamento tardio e conflitos entre IDs de transação, com ator técnico, ações e data. IDs conflitantes não substituem silenciosamente a transação original do pedido.

Essas coleções ficam sob default deny das Rules existentes. SDK cliente não lê razões/ledgers nem altera compensação/refund/estoque. Em orders só entram resumos de estado/tempo (Cancelado, cancellationStatus, compensationStatus ou returnStatus); motivo, ator e instruções internas não são expostos ao cliente.

Cancelamento/RELEASE/registro são um commit Firestore. RESTOCK/registro de devolução/recibo são outro commit atômico. Falha dentro do callback não deixa devolução parcial; timeout após commit não repete efeito. Uma nova chave para pedido já processado também não libera/devolve outra vez. O histórico original não é apagado.

### Máquina de estados: distinguir o contrato integrado do legado local

| Estado lógico do ciclo | Evidência no Firebase atual | Cancelamento/devolução nesta entrega |
| --- | --- | --- |
| pending | Sem reserva/processamento comprovado e pagamento em estado conhecido | Cancelar sem alteração de stock/reservedStock. Pedido rejeitado financeiramente, sem efeitos, também pode ser encerrado. |
| reserved | stockReservationStatus reserved, origem firestore_order_trigger e financeiro oficial com quantidades coerentes | RELEASE estrito: reservedStock reduzido uma vez; stock não aumenta, pois esse modelo local ainda não o reduziu no RESERVE. |
| released | Reserva já liberada | Nenhuma nova liberação; evento de conclusão atrasado não reabre nem baixa o cancelado. |
| committed (somente mapeamento local) | finalized/processado, stockProcessed true e origem backend stock_reservation_finalizer ou mercado_pago_webhook | Cancelamento operacional não devolve estoque automaticamente. Precisa da operação separada de devolução autorizada. |
| restocked | orderReturns e compensação inventoryState restocked | stock local recebe as quantidades oficiais uma vez. salesCount e histórico da venda original permanecem; não inventar uma venda negativa. |

O contrato **físico integrado** continua sendo pending → reserved → released ou reserved → committed → restocked, com RESERVE como único decremento físico e COMMIT lógico sem segundo decremento. Este repositório não comprovou bridge/ACK para esse contrato. A baixa Firebase existente no webhook/finalização **não foi renomeada como uma reserva Oracle** nem migrada nesta tarefa.

Produtos com PRO_CODIGO ou modelo de estoque externo não reconhecido são recusados antes de compensar. Reserva sem origem comprovada, estoque em revisão/inconsistente, item removido para RESTOCK, quantidade oficial divergente e saldo não inteiro/seguro falham fechados. Não há chamada Oracle nem novo decremento físico. Nada no emulador comprova estoque físico real. Esse ponto mantém KB-04 PARCIAL em conjunto com a dependência do KB-02.

### Pré-pagamento, PIX pendente e expiração

Cancelamento anterior à emissão/reserva bloqueia a preparação financeira, triggers atrasados e a nova tentativa de POST. KB-03 permanece intacto para compras novas; cancelar/compensar não depende de a loja estar aberta nem recalcula cotação antiga.

PIX com ID, chave/timestamp de tentativa ou resultado de criação incerto fica com refundStatus verification_required e ação verify_and_cancel_provider_charge. Não se assume que timeout/error signifique ausência de cobrança. paymentStatus pendente permanece pendente; IDs e snapshot continuam preservados. A emissão tem uma leitura adicional de estado imediatamente antes do POST.

Um POST pode já estar em voo quando o cancelamento confirma: não há transação distribuída capaz de recolher a requisição enviada. A resposta tardia preserva Cancelado/Pago/Concluído, grava os IDs e mantém necessidade de verificação. Se o ID retornar diferente do já salvo, preserva a transação original e registra ambos os IDs privadamente. Não declarar cancelamento financeiro concluído nessa janela.

Notificações de expiração/cancelamento usam a **consulta oficial já existente**, com assinatura/vínculo/método/valor conferidos: canceled com detail canceled/expired ou failed com detail expired. Estado action_required não basta para cancelar. Para snapshot e estoque locais coerentes, a operação cancela e libera uma vez. providerCancellationStatus confirmed nesse caso significa **somente que o provedor confirmou o estado terminal sem pagamento**, não refund de um PIX pago. Falta de snapshot oficial, estado legado ambíguo ou integração física desconhecida exige reconciliação; não fabricar uma liberação.

Referência pública: [status de Orders Mercado Pago](https://www.mercadopago.com.br/developers/pt/docs/checkout-api-orders/payment-management/status/order-status) e [notificações/expiração](https://www.mercadopago.com.br/developers/pt/docs/checkout-api-orders/notifications). Nenhuma API real foi chamada nesta tarefa.

### PIX pago, webhook tardio e concorrência

Cancelamento operacional de Pago exige superadmin e conserva Pago, valores, IDs e evidências. A compensação fica required com external_pix_refund_required ou revisão do recebimento externo. Não altera artificialmente o pagamento para Pendente/não pago.

Webhook pago após Cancelado continua passando pela validação de assinatura, consulta, vínculo e valor existente. Registra a confirmação verdadeira, muda paymentStatus para Pago e aponta restituição necessária, **sem baixar estoque nem reabrir a operação**. Webhook duplicado vê Pago e não repete efeito. Expiração antiga não regride um pagamento já confirmado.

Cancelamento e webhook disputam o mesmo documento em transação. Se cancelamento vencer antes da baixa, pagamento tardio não baixa. Se o webhook já tiver efetuado a baixa antes de cancelar, o ledger conserva committed e exige devolução autorizada; não executar RELEASE pós-COMMIT. Os estados operacionais/financeiros convergem para Cancelado + Pago + refund necessário, e a trajetória de estoque corresponde à ordem real dos commits. Uma devolução física não é presumida para forçar artificialmente saldo igual nas duas trajetórias.

### Pedido concluído e financeiro

Cancelamento simples de Concluído é recusado (COMPLETED_ORDER_REQUIRES_RETURN). A devolução integral separada preserva status Concluído, pagamento, completedAt, IDs, itens/valores e registro da venda. RESTOCK não confirma refund.

orderFinancials nunca é escrito/excluído pelos novos comandos. Não são recalculados itemsTotal, deliveryFee, customerFee, merchantFee, merchantNet, platformFee, totalBRL/totalCentavos, versão de frete ou faixas históricas. grandTotal conceitual corresponde a totalBRL; validationStatus conceitual corresponde a financialValidationStatus. Rejeição financeira prévia é mantida quando a operação é encerrada.

### Comissão pendente e pagamentos externos

A taxa lojista 3% continua como merchantFee oficial congelada, sem cálculo novo. Cancelado é excluído do fechamento/CSV pelo código existente do painel. A compensação registra originalMerchantFee e commissionAdjustmentStatus excluded_from_closing, de forma idempotente, sem zerar o snapshot original ou criar nova cobrança/comissão.

Não foi localizado ledger de dívida/quitação independente de comissão externa. Portanto, essa marca **não é quitação/estorno de dívida fora do repositório**. Dinheiro/maquininha já recebidos e devoluções de pedidos concluídos exigem revisão externa; retorno concluído usa return_review_required. O relatório bruto histórico do pedido concluído continua preservado; ajustes líquidos de devolução/refund e comissão precisam de conciliação em ledger financeiro homologado. Não afirmar que foram compensados fora do sistema.

## Validação local

| Verificação | Resultado / evidência |
| --- | --- |
| Functions npm test | **388/388 aprovados**, incluindo 7 novos testes de caminhos PIX/cancelamento/webhook e 7 unitários de política/autoridade/estoque/refund. Log tool/kb04/node-final.log. Os 374 casos anteriores permanecem aprovados. |
| Firestore/Auth Emulator | **364/364 aprovados**, incluindo 21 cenários novos de cancelamento/compensação e a regressão anterior de 343 casos (KB-03, Rules, piloto, operações, raio, entregadores, chat e conta). Log tool/kb04/emulator-final.log. |
| Flutter analyze | **No issues found**, tool/kb04/flutter-analyze.log. Nenhum Dart alterado. |
| Flutter afetados | **40/40 aprovados**, tool/kb04/flutter-affected.log: aceite de pedido, acesso/isolamento de pedidos, tracking/chat, ciclo de conta e consolidação cliente. |
| ESLint do escopo | Aprovado, tool/kb04/lint-scoped.log. |
| ESLint global | Dois problemas preexistentes em test/customer-account.emulator.spec.js (max-len 175 e curly 184), fora do KB-04 e sem alteração desse arquivo. Log tool/kb04/lint-all.log. |

Cobertura inclui sem reserva, dinheiro BR, cartão BR, dinheiro PY/split, reserva e RELEASE duplicados, pedido rejeitado antes de efeitos, PIX antes/durante criação, pendente, expirado, pago, webhook tardio/duplicado/concorrente, assinatura HMAC do SDK real com segredo fictício, valor incorreto, COMMIT tardio após RELEASE, devolução autorizada/duplicada, perda de ACK de cancelamento/RESTOCK, rollback após RELEASE enfileirado antes do commit, reconstrução do processador a partir de recibo, pedido concluído, produto mapeado/ausente/saldo inseguro, comissão/snapshots e segurança SDK/roles.

No teste de corrida existem duas serializações legítimas de estoque, descritas acima; a asserção exige saldo/ledger coerentes e retorno final correto somente quando autorizado. Não relaxa a exigência de uma única baixa/uma única devolução. O primeiro teste dirigido encontrou três reutilizações da mesma chave de teste entre pedidos diferentes; a fixture foi corrigida para chaves por pedido, mantendo a rejeição de chave conflitante.

Emuladores usam exclusivamente demo-chamae-rules, Firestore 127.0.0.1:8187 e Auth 127.0.0.1:9099. Respostas Mercado Pago são interceptadas por fetch de teste; Google/Oracle/GrandChef reais não são consultados. A assinatura HMAC usa TEST_ONLY no processo local e o validador SDK existente; nenhum segredo real foi obtido. Transações, concorrência e Rules são reais do emulador; não constituem homologação externa/implantação.

Comandos reproduzíveis após preparar SDKs, sem instalar/atualizar dependências:

```powershell
# Em functions:
npm test
firebase emulators:exec --project demo-chamae-rules --only firestore,auth --config ../firebase.account-test.json "node --test --test-concurrency=1 test/order-cancellation.emulator.spec.js test/order-acceptance.emulator.spec.js test/firestore.rules.spec.js test/pilot.emulator.spec.js test/final-operations.emulator.spec.js test/delivery-radius.emulator.spec.js test/courier-assignment.emulator.spec.js test/courier-deliveries.emulator.spec.js test/order-chat.emulator.spec.js test/customer-account.emulator.spec.js"
# Na raiz chamae_delivery:
flutter analyze --no-pub
flutter test --no-pub test/order_acceptance_test.dart test/customer_orders_test.dart test/order_chat_test.dart test/customer_account_cycle_test.dart test/app_client_final_test.dart
```

Neste ambiente Flutter foi executado via dart.exe/entrypoint flutter_tools.snapshot local, --no-version-check --suppress-analytics, sem pub get. package.json mudou apenas scripts de teste, incluindo test:cancellation:emulator. Versões/lockfiles não foram atualizados.

## Conclusão e pendências reais

**KB-04: PARCIAL.** Backend local seguro/idempotente para o modelo Firebase comprovado e contratos administrativos implementados; não é liberação de operação física ou financeira real.

1. Refund/void/cancelamento remoto Mercado Pago **não implementados/homologados**. Há registro da necessidade/incerteza, não estorno confirmado. Também falta conciliação ativa de casos em que a notificação não chega; webhook/retentativa do provedor não devem ser presumidos como SLA de worker novo.
2. Bridge Oracle/GrandChef, ledger/ACK e RESERVE físico/COMMIT lógico/RESTOCK físico continuam dependências externas. Produtos mapeados/estado desconhecido falham fechados. Não houve DDL nem retorno físico simulado como real.
3. Ledger de comissões/dívidas/ajustes externos e contabilização líquida após devolução/refund precisam identificação e homologação com o financeiro. Não alterar snapshots brutos para esconder a pendência.
4. Revisar/integrar os contratos no procedimento/painel autorizado, confirmar produtos recebidos antes de DEVOLVER, provisionar revisão compatível em tarefa futura autorizada e homologar casos reais controlados. Nenhum deploy nem alteração do painel nesta entrega.
5. Legados sem prova de reserva/baixa, sem snapshot, já cancelados sem ledger ou em estado incerto exigem revisão; não adotar automaticamente como se nunca tivessem tido compensação. Devolução parcial não faz parte deste contrato inicial.

As checklists oficiais foram atualizadas somente no KB-04 e em referências diretamente relacionadas, mantendo gates bloqueados onde dependências reais persistirem. KB-03 e seus serviços reais permanecem PARCIAIS; não foram modificados.

## Preservação

Inventário e cópias anteriores em tool/kb04/before; hashes em tool/kb04/protected-before.json. Regras, KB-03 (horário/Geocoding), delivery-service/pricing/Routes, operadores/atribuição, conta/onboarding, preços iniciais, pubspec e lockfiles preservados por hash. Ajustes em index.js limitam-se às travas/reconciliação comprovadas e ao compartilhamento estrito do RELEASE; não alteram fórmulas ou criam escrita física Oracle.

Firebase produção: não acessado. Oracle/GrandChef: não acessado. Commit: não realizado. Push: não realizado. Deploy: não realizado. Parar para revisão humana.
