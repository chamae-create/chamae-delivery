# Backend operacional do piloto

Contrato atualizado: consultar também
C:/Users/DELL/chamae_admin/docs/pilot_readiness.md e pilot_validation.md.

Novas callables (southamerica-east1): chamaeIniciarSeparacao,
chamaeConcluirEntrega e chamaeRegistrarAcertoMotoboy. Somente contas nomeadas
com roles explícitas. Separação/conclusão: operations_admin/superadmin.
Acertos: finance, superadmin e operations_admin, mantendo o caixa existente.
Auth inválido é recusado antes de leituras; payload possui allowlist.

Todas as mutações de orders por SDK cliente foram fechadas nas Rules, inclusive
para superadmin. courierSettlements também só aceita escrita Admin SDK.
Atribuição e despacho existentes continuam no backend; o despacho exige
courierUid real ativo, validação e registro financeiro oficial coerentes.

Conclusão usa resolverReservaNaTransacao extraído do trigger EXISTENTE, com
mesmos cálculos e efeitos: baixa stock/reservedStock, incrementa salesCount e
confirma pagamento na entrega quando cabível. Modo estrito falha antes de
qualquer commit em inconsistência. status/completedAt/projeção/estoque e ledger
são atômicos. PIX já processado não debita novamente. O trigger permanece
idempotente para eventos atrasados. Nenhuma fórmula financeira foi modificada.

Acerto recebe orderDocumentIds (1..400 únicos) e requestId (16..100 caracteres,
A-Z/a-z/0-9/_/-). Não aceita nome, total nem taxa enviados pelo painel. Relê cada
pedido e orderFinancials, confere itens/quantidades e valores oficiais, soma
centavos inteiros de deliveryFee congelado e exige mesmo courierUid em todo lote.
Concluído/Pago, completedAt, estoque consistente e ausência de acerto prévio
são obrigatórios. Nenhum item inelegível é silenciosamente ignorado.

courierSettlements/{sha256(actorUid:requestId)}:
courierUid, courierName (cadastro oficial), orderDocumentIds, orders com
{documentId,id,deliveryFee}, total, orderCount, status=paid, createdAt,
actorUid, fingerprint e version=1. Recibo imutável por SDK. As atualizações dos
pedidos courierPaid/courierPaidAt/courierSettlementId e o recibo são atômicos.
Replay da chave com outro lote falha; concorrentes não pagam em duplicidade.
Lote está sujeito aos limites normais de tamanho/tempo do Firestore.

orderOperationRequests é ledger backend-only por ator/chave, sem dados pessoais
do cliente. courierDeliveryAudit continua mínimo e a projeção usa EXATAMENTE o
helper compartilhado de sanitização já existente, sem contatos/financeiro.
Cancelamento externo já existente continua sincronizado pelo trigger; não se
criou cancelamento público nem autoridade para motoboy nesta etapa.

couriers/{uid} mínimo: name, administrativeState=active. UID real vem do Auth;
o novo provisionador local valida a conta e não copia contatos. Sem motor de
presença, oferta, FCM ou fila. Suspensão bloqueia get da projeção nas Rules,
mesmo antes do trigger de reconciliação, além de bloquear novas atribuições.

chamaeCriarPix legado manual tornou-se IAM-private, sem mudar seu algoritmo,
headers/secrets nem PIX automático/webhook. Os endpoints diagnósticos PIX e
MercadoPago já eram privados. chamaeStatus continua público sem dados pessoais.
Nenhum secret foi modificado. Testes de pagamento existentes foram preservados.

Scripts:
- npm test: financeiros, projeção, atribuição e novas operações.
- npm run lint: fontes e testes.
- test:couriers:emulator: projeção, atribuição e E2E do piloto.
- test:rules: isolamento e negação de escritas diretas.
- scripts/audit-orders.js: leitura paginada de legados, nunca escreve.
- ../firebase.pilot.json: apenas Firestore local, projeto demo-chamae-rules.

Não houve deploy, backfill ou alteração de credenciais/dados reais.