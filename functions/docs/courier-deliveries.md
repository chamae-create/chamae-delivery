ATUALIZAÇÃO DO PILOTO (15/10/2026): este documento inclui histórico anterior. A política atual está em pilot_readiness.md/pilot_validation.md no chamae_admin e functions/docs/pilot.md no chamae_delivery. Todas as mutações SDK de orders/acertos foram fechadas; conclusão e acertos agora usam callables; o caixa agrupa por UID; cadastro inativo revoga leitura. Nada foi deployado.

# Projeção sanitizada de entregas

## Auditoria do backend anterior

Functions que acessam os pedidos Firestore:

- `chamaeMercadoPagoWebhook`: atualiza confirmação do pagamento/pedido.
- `chamaeCriarPix`: criação manual do PIX para um pedido.
- `chamaeCriarPixAutomatico`: `onDocumentCreated` de `orders`.
- `chamaeReservarEstoquePagamentoEntrega`: reserva na criação de `orders`.
- `chamaeResolverReservaEstoque`: resolve a reserva em alterações de `orders`.

Os endpoints de diagnóstico não atribuem entregadores. Não havia código de
atribuição, leitura ou escrita de `courierUid` nas Functions. `courierName`
não é uma identidade Firebase e não há conversão de nomes para UIDs.

O resolvedor de estoque reconhece `Concluído` e status contendo `cancel`;
outros fluxos também usam `Novo`, `Aguardando pagamento`, `Revisão de estoque`
e `Revisão financeira`. Nenhuma dessas Functions ou transições foi alterada.

## Novo produtor

`chamaeSincronizarCourierDelivery` observa criação, atualização e exclusão de
`orders/{orderId}`, na região `southamerica-east1`, com retry habilitado.
O handler reconcilia o pedido **atual** em transação; não utiliza o snapshot
possivelmente atrasado do evento. Escreve somente em `courierDeliveries` e
`courierDeliveryAudit`, sem HTTP de pagamento, secrets ou escrita no pedido.

Para produzir uma entrega utilizável, exige:

1. `orders/{orderId}.courierUid` explícito, válido e sem caminhos/normalização.
2. Cadastro backend correspondente em `couriers/{courierUid}`.
3. Nome, endereço e coordenadas válidos; complemento/referência, se presentes,
   devem ser textos limitados. Mapas livres e contatos reconhecíveis embutidos
   nesses textos impedem a publicação; não são convertidos ou truncados.
4. Status operacional conhecido. Cancelamentos são reduzidos a `Cancelado`,
   sem replicar motivos privados. Status de pagamento/revisão não são expostos.

O produtor não cria usuários, cadastros nem vínculos. O provisionador futuro
deve garantir que o ID do cadastro corresponda ao UID real do Firebase Auth.
A presença do cadastro é validada; não há nova API de atribuição nesta tarefa.

## Esquema de courierDeliveries/{orderId}

`orderId` é o ID documental Firestore, não `order.id` amigável.

| Campo | Tipo | Origem/finalidade |
| --- | --- | --- |
| orderId | string | ID documental |
| courierUid | string | Vínculo explícito validado |
| customerName | string | Nome necessário à entrega |
| address | string | deliveryAddress.addressText, ou address legado |
| deliveryLocation | GeoPoint | Coordenadas explícitas, sem copiar mapas |
| complement | string opcional | Complemento de rota |
| reference | string opcional | Referência de rota |
| status | string | Novo, Em Separação, Saiu para Entrega, Concluído, Cancelado |
| createdAt | timestamp | Primeira criação da projeção |
| assignedAt | timestamp | Observação do vínculo atual pelo produtor |
| pickedUpAt | timestamp opcional | Observação de Saiu para Entrega |
| completedAt | timestamp opcional | Observação de Concluído |
| updatedAt | timestamp | Commit da última alteração operacional efetiva |

Os timestamps registram observações do produtor, não datas históricas
inventadas. Se o produtor observar diretamente `Concluído`, não inventa um
`pickedUpAt` intermediário. O `completedAt` permanece estável em reexecuções.

Não existem valores a cobrar, formas de pagamento ou dados financeiros na
projeção. Telefone, WhatsApp, e-mail, `customerUid`, taxas, Mercado Pago IDs,
itens, histórico do cliente e novos campos desconhecidos **não são copiados**.
Nenhum objeto do pedido é espalhado, serializado integralmente ou mesclado.
Coordenadas são reconstruídas campo a campo em um GeoPoint.

## Atualização, revogação e auditoria

A escrita substitui integralmente a projeção, inclusive removendo eventuais
campos privados legados. Alterações apenas financeiras não causam novas
escritas. Execuções duplicadas e concorrentes não renovam timestamps/auditoria.

Na troca de entregador, o mesmo documento recebe o novo UID e um novo
`assignedAt`; o antigo UID deixa de corresponder ao documento após o commit.
Ao remover o vínculo, excluir o pedido, indicar cadastro inexistente ou dados
operacionais inválidos, uma projeção existente vira marcador revogado:
`courierUid: ""`, sem nome, endereço, localização, complemento ou referência.
Preserva somente ID, status conhecido e timestamps operacionais. Não se cria
marcador para um pedido que nunca teve projeção. Nenhum UID autenticado pode
corresponder ao UID vazio. Reatribuição válida pode reativar a projeção.

Cada alteração efetiva cria uma entrada atômica backend-only em
`courierDeliveryAudit/{autoId}` com apenas `orderId`, `previousCourierUid`,
`courierUid`, `previousStatus`, `status`, `reason` e `changedAt`.
O log não inclui nome, rota, contato ou financeiro do cliente; não é fonte
de dados do entregador. A trilha de vínculos/status não é apagada. Os pedidos
originais também são preservados pelo produtor; não há TTL ou expurgo aqui.

## Limitações e regras futuras

- O fluxo atual não fornece `courierUid`: os pedidos atuais, com apenas nomes,
  não gerarão entregas utilizáveis. É necessário um contrato futuro de
  atribuição por backend confiável e cadastro por UID real.
- Não há backfill automático de pedidos existentes: a reconciliação ocorre
  nas próximas escritas/exclusões do pedido após um eventual deploy.
- Triggers são assíncronos: a revogação ocorre no commit da reconciliação.
  Se o futuro atribuidor exigir revogação imediata, deve atualizar vínculo e
  projeção na mesma transação, sem esperar o evento. Desprovisionamento do
  cadastro isolado também exige um fluxo de revogação próprio; até lá a
  projeção só será reconciliada numa nova alteração do pedido.
- A retenção de dados operacionais após conclusão/cancelamento precisará de
  política antes de operar o app de entregadores; não se apagou histórico.
- As Rules não são sanitizador. Devem permitir somente a leitura por
  `request.auth.uid == resource.data.courierUid` e negar escrita de clientes.
  O log de auditoria deve continuar backend-only. As Rules atuais também
  exigem cadastro/não anonimato e negam listagem; descoberta de entregas e
  futura query por UID ainda precisam ser definidas. Nenhuma Rule foi alterada.

## Validação local

`npm test` executa testes financeiros existentes e testes unitários do novo
produtor. `npm run lint` verifica todo o backend.

Para todos os testes de integração, executar somente o emulador Firestore,
nunca o emulador de Functions (para não disparar PIX/estoque):

```text
firebase emulators:exec --only firestore --project demo-chamae-rules "npm --prefix functions run test:couriers:emulator && npm --prefix functions run test:rules"
```

Executar a partir da raiz Firebase. Os testes validam o host local e usam
exclusivamente o projeto demo; não acessam dados reais ou Mercado Pago.
O teste de concorrência/retry aborta uma transação real antes do commit e
altera o vínculo antes da nova tentativa, sem depender de locks temporizados.

## Resultado da validação em 15/10/2026

- Linha de base: lint sem erros e 43 testes financeiros aprovados.
- `npm test`: **149 aprovados** (43 financeiros preservados e 106 novos),
  zero falhas, cancelamentos ou testes ignorados.
- `npm run test:couriers:emulator`: **11 aprovados**, incluindo leitura real
  pelas Rules, revogação, concorrência e retry com rollback real.
- `npm run test:rules`: **164 aprovados**, suíte existente preservada.
- Total: **324 testes aprovados**. `npm run lint`: sem erros ou warnings.

A comparação binária confirmou que todos os bytes originais de `index.js`
foram preservados, com somente o registro do novo produtor acrescentado ao
final. Nos testes financeiros mudou apenas o resolver do módulo novo na
fixture; nenhuma asserção foi removida ou modificada. Hashes de Rules,
package-lock, testes existentes de Rules e arquivos do cliente foram
conferidos sem alterações desta tarefa. Não houve deploy, commit ou push.
## Atualização: atribuidor atômico implementado

A ausência de atribuidor descrita na auditoria acima foi resolvida pelas
callables documentadas em [courier-assignment.md](courier-assignment.md).
O produtor agora exige cadastro com administrativeState active e compartilha
planCourierDelivery/writeCourierDelivery com essas callables. Atribuição,
troca e remoção explícitas atualizam orders e projeção na mesma transação;
a revogação dessas ações não depende do trigger. Pedidos legados sem UID
continuam sem backfill. Desprovisionar cadastro isoladamente ainda exige
fluxo próprio de revogação. As Rules não foram alteradas.