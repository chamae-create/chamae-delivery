POLITICA ATUAL (17/10/2026): consulte [operational-flow.md](operational-flow.md). Atribuir, despachar e concluir agora exigem contingencia superadmin com motivo, confirmacao e auditoria. O texto abaixo e historico e nao concede permissoes atuais.

ATUALIZAÇÃO DO PILOTO (15/10/2026): este documento inclui histórico anterior. A política atual está em pilot_readiness.md/pilot_validation.md no chamae_admin e functions/docs/pilot.md no chamae_delivery. Todas as mutações SDK de orders/acertos foram fechadas; conclusão e acertos agora usam callables; o caixa agrupa por UID; cadastro inativo revoga leitura. Nada foi deployado.

# Atribuição autenticada de motoboys

## Auditoria e contrato

O Kanban alterava status por transação Firestore e mostrava `courierName`,
inclusive um fallback visual de motoboy padrão. Não havia atribuidor por UID.
A administração de motoboys é uma visão de leitura, com `name` e
`administrativeState` (`active`, `suspended`, `blocked`), além de metadados
administrativos. Ela já reconhecia `courierId` legado; passa a preferir
`courierUid` ao associar um pedido a um perfil. Cálculos/acertos não mudaram.

O contrato autoritativo é `couriers/{firebaseAuthUid}` com:

```text
name: string não vazia, até 120 caracteres
administrativeState: "active" | "suspended" | "blocked"
```

Somente `active` habilita atribuição/despacho. Estado ausente ou desconhecido
não concede habilitação. Flags legadas `enabled`, `isActive` ou `active`
explicitamente falsas também impedem uso. Não há estado de presença online
ou capacidade de entregas implementado; não se inventou disponibilidade.
O cadastro deve ser provisionado por backend confiável usando o UID real do
Firebase Auth. Estas Functions não criam contas, UIDs ou cadastros.

## Callables

Todas usam `southamerica-east1`, Auth obrigatório e custom claim **roles em
lista**, contendo `operations_admin` ou `superadmin`. Anônimos são rejeitados,
inclusive se portarem roles. Cliente comum, finance e catalog_admin não são
autorizados. A autorização ocorre antes de consultar pedidos ou cadastros.

### chamaeListarMotoboysAtribuiveis

Entrada: `{cursor?: string}`. Retorna até 50 pares `{uid, name}` e
`nextCursor`, somente de cadastros habilitados. Não retorna telefone, e-mail,
metadados financeiros ou o documento completo do cadastro. Isso atende o
Kanban operacional sem abrir a coleção nas Rules.

### chamaeAtribuirMotoboy

Entrada:

```text
orderId: ID documental de orders, nunca o código amigável
courierUid: UID cadastrado; "" ou null para remover
expectedCourierUid?: UID anterior esperado, "" quando sem vínculo
requestId?: identificador único de intenção (16–100 caracteres alfanuméricos/-/_)
```

O painel sempre fornece uma chave aleatória estável durante retries e a
precondição de vínculo. Sem chave, o backend gera uma; a proteção de replay
entre chamadas distintas exige que o chamador reuse a mesma chave.
Campos extras, inclusive `courierName`, são rejeitados. O nome vem somente
do cadastro oficial, nunca do navegador. IDs/caminhos inválidos são rejeitados.

Permite mudança apenas em `Novo` ou `Em Separação`, sem repasse/acerto já
registrado. Não altera histórico de pedidos em rota, concluídos ou cancelados.
Escreve somente `courierUid`, `courierName`, `courierAssignedAt` e `updatedAt`
na atribuição. Remoção grava UID/nome vazios, retira `courierAssignedAt` e
registra `courierUnassignedAt`/`updatedAt`. Repetir o mesmo vínculo não renova
timestamps sem necessidade.

### chamaeDespacharPedido

Entrada: `{orderId, requestId?, expectedCourierUid?}`.
Exige estado `Em Separação` (ou estado já despachado numa repetição), UID
atual válido e cadastro habilitado. Revalida os pré-requisitos de liberação
operacional existentes: validação financeira, pagamento PIX/processamento
e reserva de estoque quando exigida. São somente verificações, sem cálculo,
cobrança, reserva, baixa ou alteração de valores.

Atualiza `status: "Saiu para Entrega"`, `dispatchedAt` e `updatedAt`, com a
projeção no mesmo commit. Sem motoboy ou dados de rota válidos, não despacha.

## Atomicidade e reexecução

As operações leem ledger, pedido, projeção e cadastro em transação, antes de
escrever. Reutilizam `planCourierDelivery` e `writeCourierDelivery`, também
usados pelo trigger, mantendo uma única allowlist de sanitização.

A transação grava pedido, projeção/revogação, auditoria e ledger de intenção.
Na troca, o documento de entrega recebe o novo UID no mesmo commit. Na remoção,
recebe UID vazio e perde nome/endereço/localização/complemento/referência.
Assim o UID antigo perde autorização no próprio commit, sem esperar evento.
Isso não remove dados que já tenham sido recebidos/cacheados pelo dispositivo.

`courierAssignmentRequests/{hash(actorUid, requestId)}` é backend-only e guarda
somente ator, pedido, UID, operação, fingerprint e timestamp. Repetir uma
tentativa antiga não restaura um motoboy anterior. Reutilizar a chave com
outro payload é negado; `expectedCourierUid` impede sobrescrever modal antigo.
O trigger relê o pedido atual, portanto eventos atrasados não restauram acesso.

`courierDeliveryAudit` permanece backend-only, com ator opcional nas operações
explícitas. Não há telefone, WhatsApp, e-mail, customerUid, taxas, finanças,
Mercado Pago IDs ou histórico do cliente na projeção. Não se copia orders
integralmente, nem se usa merge para preservar possíveis campos privados.

## Limitações antes de produção

- Não houve deploy ou backfill. Publicar as três callables e o produtor
  atualizado deve ser coordenado com a versão do painel.
- Cadastros legados sem UID real/estado active precisam de provisionamento
  explícito. Nome, booleano ausente ou histórico de entregas não criam vínculo.
- As Rules atuais ainda permitem status direto por operadores. O painel novo
  usa a callable; bloquear o caminho Firestore alternativo requer a próxima
  revisão de Rules. Nenhuma Rule foi alterada nesta tarefa.
- Desabilitar um cadastro isoladamente não é um desatribuidor atômico. O
  despacho é negado e o produtor revoga numa nova alteração do pedido, mas
  um futuro fluxo de desprovisionamento deve tratar revogação imediatamente.
- Listagem para o futuro app do motoboy, presença e retenção permanecem fora
  desta etapa. As Rules atuais ainda negam listagem de courierDeliveries.
- Financeiro/acertos continuam no contrato legado por nome; não foram
  migrados para UID e homônimos exigem atenção nessa futura migração.

## Validação

`npm test`, `npm run lint` e `npm run test:couriers:emulator`.
O script de integração executa os arquivos sequencialmente para isolar suas
fixtures. Usar somente Firestore Emulator com projeto `demo-chamae-rules`;
não iniciar Functions de PIX/estoque para executar estes testes.

## Resultado da validação em 15/10/2026

- npm test: 170 aprovados, sem falhas ou skips, incluindo os 43 financeiros.
- npm run lint: zero erros e warnings.
- Integração Firestore Emulator: 31 aprovados (11 existentes + 20 novos).
- Rules existentes: 164 aprovados, sem alterações no arquivo de regras.
- Painel: flutter test com 146 aprovados (138 existentes + 8 novos).
- flutter analyze: zero erros; 13 infos e um warning preexistentes, exit 1.
- Total: 511 testes aprovados nos dois projetos, sem deploy/commit/push.

Comparações de conteúdo/hash confirmaram a preservação dos handlers antigos
em index.js, Rules, package-lock do backend e cliente. No painel, Catálogo,
Financeiro e impressão foram comparados integralmente com a cópia inicial.