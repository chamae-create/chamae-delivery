ATUALIZAÇÃO DO PILOTO (15/10/2026): este documento inclui histórico anterior. A política atual está em pilot_readiness.md/pilot_validation.md no chamae_admin e functions/docs/pilot.md no chamae_delivery. Todas as mutações SDK de orders/acertos foram fechadas; conclusão e acertos agora usam callables; o caixa agrupa por UID; cadastro inativo revoga leitura. Nada foi deployado.

# Auditoria e proposta local de Firestore Security Rules

## Escopo e resultado

Arquivos de destino: `firestore.rules`,
`functions/test/firestore.rules.spec.js` e este relatório. Nenhum código de
Cloud Functions, PIX, estoque, financeiro ou aplicativo foi alterado. Nenhum
deploy foi executado. A produção continua com as regras anteriormente publicadas
até que haja uma publicação explícita, fora desta tarefa.

**Não publicar antes de resolver os bloqueadores de compatibilidade abaixo.**

## Regra anterior insegura

A regra genérica permitia ler e escrever qualquer coleção, exceto `products`
e `orderFinancials`, até 02/11/2026. Isso incluía pedidos com dados pessoais,
pagamentos, UID, status, exclusões, acertos e subcoleções, inclusive sem Auth.
O comentário de que o cliente não tinha Auth estava desatualizado: o cliente
atual inicializa Firebase Auth anônimo e cria pedidos com `customerUid`.

A nova proposta remove a exceção por data e usa deny by default. Não existe
superadmin genérico capaz de anular a proteção de documentos backend-only.

## Política por coleção

| Coleção | Leitura de cliente SDK | Escrita de cliente SDK |
| --- | --- | --- |
| `products` | Pública, como no catálogo atual | `catalog_admin` ou `superadmin` |
| `orders` | Cliente lê somente o próprio UID; `operations_admin`, `finance` e `superadmin` leem pedidos | Cliente cria proposta própria; operações/superadmin alteram apenas o fluxo permitido abaixo; exclusão negada |
| `orderFinancials` e descendentes | Negada a todos, inclusive finance/superadmin | Negada a todos |
| `courierSettlements` | Operações, finance e superadmin | Somente criação atômica de acerto avulso por operações/superadmin; atualização/exclusão negadas |
| `couriers` | Superadmin | Negada: ações no painel ainda não são implementadas |
| `reviews` | Superadmin | Negada: respostas/ações no painel ainda não são implementadas |
| `courierDeliveries` | Somente `get` por ID para motoboy não anônimo provisionado e atribuído pelo próprio UID, com esquema sanitizado; listagens negadas | Negada: exige produtor backend futuro |
| Demais caminhos, `users` e subcoleções não declaradas | Negada | Negada |

Claims administrativas exigem `roles` como lista e conta não anônima. Uma
role ausente/desconhecida não concede acesso administrativo. O cliente anônimo
autenticado continua podendo criar/ler seu próprio pedido, sem privilégios admin.
As permissões de múltiplas roles se somam; `finance` isolado não grava pedidos.

## Checkout auditado

Fonte: `lib/screens/checkout_screen.dart`, `_montarDadosPedido`.
Preservados os campos reais de endereço/localização, itens, propostas de valores,
exibição BRL/PYG/USD, câmbio, dinheiro, maquininha, PIX e pagamento dividido.

A criação exige UID próprio, itens não vazios, total positivo, timestamp do
servidor, `courierPaid: false` e status iniciais (`Novo`/`Aguardando pagamento`).
`paymentStatus` inicial admite somente `Aguardando confirmação`,
`Pendente na entrega` ou `Pendente`. Não é possível criar já como `Pago`,
concluído, validado financeiramente, com estoque autoritativo ou IDs Mercado Pago.
As chaves aceitas são explicitamente listadas nas Rules; nenhuma atualização
ou exclusão posterior é permitida ao cliente comum, mesmo no próprio pedido.

Os valores enviados no checkout continuam sendo **propostas não confiáveis**.
A validação do backend existente, preços oficiais e `orderFinancials` permanecem
necessários e não foram substituídos por cálculos nas Rules.

## Escritas operacionais realmente usadas

Fonte: `chamae_admin/lib/main.dart` e `lib/courier_settlements.dart`.

- Transições: `Novo` → `Em Separação` → `Saiu para Entrega` → `Concluído`.
  Só `status` muda nas duas primeiras; a conclusão exige também `completedAt`
  igual ao timestamp do servidor. Não se permite pular, reabrir ou cancelar.
- O pedido deve estar validado pelo backend, sem revisão/erro de estoque.
  PIX exige pagamento confirmado e estoque processado; reserva exigida de
  pedido não PIX deve estar confirmada. Legados sem `customerUid` e sem campo
  de validação mantêm o tratamento legado; não podem ser fabricados pelo cliente.
- Acerto: somente `courierPaid`, `courierPaidAt` e `courierSettlementId`;
  exige recibo novo e correspondente na mesma operação atômica. Não é possível
  marcar pago isoladamente, desfazer pagamento ou trocar recibo.
- Recibo avulso: somente `courierName`, `orderDocumentIds`, `orders`, `total`,
  `orderCount`, `createdAt`, `status`. O único item deve corresponder ao pedido,
  ao nome do motoboy e ao frete persistido. A soma é exatamente esse frete.
  Pedido concluído, pagamento confirmado e validação/estoque elegíveis são
  conferidos. `getAfter()` valida o vínculo nas duas direções.

Operador não pode modificar `totalBRL`, `itemsTotal`, `deliveryFee`, `customerFee`,
`merchantFee`, `merchantNet`, `platformFee`, `paymentStatus`, `customerUid`,
`itemsList`, IDs Mercado Pago, validação financeira ou estado autoritativo de estoque.
`courierName` não foi liberado para atualização: o painel atual não o grava.

## Bloqueadores antes de publicar

1. **Tracking do cliente:** `tracking_screen.dart` usa `where('id', ...)` sem
   `where('customerUid', isEqualTo: uid)`. Essa query será negada, mesmo que
   atualmente retorne apenas pedido próprio. Ajustar a query ou usar o documento
   criado, mantendo a checagem de dono. Nenhum app foi alterado nesta tarefa.
2. **Motoboy legado:** `motoboy_screen.dart` lista todos os `orders` e altera
   status diretamente. Isso será bloqueado por projeto. Não conceder role
   operacional ao motoboy para contornar a proteção.
3. **Acertos em lote:** o serviço atual permite até 400 pedidos num único recibo.
   A proposta só permite acerto avulso verificável integralmente. Lotes falham
   atomicamente, sem marcar pedidos como pagos. Migrar acertos para backend
   autenticado/idempotente, validando itens, fretes, elegibilidade, concorrência
   e total; depois ajustar o painel em tarefa própria. Não usar apenas uma
   whitelist de campos para aceitar somas/itens arbitrários do cliente.
4. **Financeiro somente leitura:** o botão atual de acertar também grava
   `courierPaid`. `finance` isolado não pode executá-lo, conforme a política
   solicitada; leitura e impressão de recibos existentes continuam permitidas.
   A criação deve migrar para uma operação backend autorizada explicitamente.
5. **Pedidos sem validação:** pedidos com `customerUid`, mas sem validação
   financeira confirmada, não avançam operacionalmente. Revisar legados e o
   funcionamento das Functions em staging, sem ampliar escrita do operador.
6. **Admin antigo dentro do cliente:** `admin_screen.dart` não ganha privilégio
   pelo nome da tela. Precisa de conta/claims operacionais; Auth anônimo não basta.
7. **Storage e Hosting:** estas são somente Rules Firestore. Não garantem permissão
   de upload de imagens nem configuram domínio, Hosting ou instalação de atalho.

## Arquitetura futura do motoboy

O backend deverá provisionar `couriers/{auth.uid}` como marcador de identidade
do motoboy, antes de criar entregas. Esse cadastro não é gravável pelo cliente.
Uma conta com esse marcador é bloqueada em `orders`, mesmo se houver UID de
cliente coincidente ou role administrativa. Contas administrativas devem ser
distintas de contas de entrega. Sem provisionamento backend, não existe mecanismo
para as Rules adivinharem a função de uma conta genérica; esse contrato é obrigatório.

O produtor backend ainda não foi implementado. Ele deve emitir apenas a projeção
`courierDeliveries/{id}`: `orderId`, `courierUid`, `customerName`, `deliveryLocation`
(GeoPoint), `address`, `complement`, `reference`, `status` e timestamps operacionais
de criação/atribuição/retirada/conclusão/atualização. Endereços/complementos são
strings, não mapas arbitrários. Nunca copiar telefone, WhatsApp, e-mail, histórico,
pagamentos, valores internos ou IDs Mercado Pago. Higienizar também o texto livre.

Somente o UID atribuído pode ler a projeção por ID. Nesta preparação, listagens
continuam negadas, inclusive com filtro de `courierUid`: o emulador não consegue
comprovar os tipos/campos sanitizados exigidos para uma query potencial.
O backend futuro deve fornecer os IDs atribuídos ou oferecer endpoint de listagem
autorizado/sanitizado, a ser auditado junto da implementação do app do motoboy.
Se um documento contiver uma chave sensível/inesperada, a leitura inteira é
negada: Firestore não faz ocultação parcial de campos. Escritas de entrega
continuam negadas até que exista o fluxo backend auditado.

## Testes e reprodução

Validação em 15/10/2026:
- Firestore Emulator local: **164 testes aprovados**, zero falhas/cancelamentos
  ou testes ignorados, com o projeto isolado `demo-chamae-rules`.
- ESLint do arquivo de testes, usando a configuração existente: sem problemas.
- Painel `chamae_admin`: **138 testes Flutter aprovados** na suíte completa.
- `flutter analyze` no painel: zero erros; 13 informativos e 1 warning já
  existentes em `main.dart`. O comando retorna 1 por esses apontamentos.
- Nenhum Dart foi alterado nesta tarefa. O cliente não possui pasta `test`;
  não se inventou alteração de aplicativo para testar as Rules.

Usar somente Firestore Emulator local, projeto `demo-chamae-rules` e Java 21.
O próprio teste exige `FIRESTORE_EMULATOR_HOST` local antes de iniciar; não há
fallback para produção. As fixtures são sintéticas. Os testes antigos de proteção
de produtos/financeiro foram preservados; o teste que exigia acesso temporário
público foi substituído pelo bloqueio explícito desse acesso.

Na raiz de `chamae_delivery`, com Java/Node/Firebase CLI instalados:

```powershell
firebase emulators:exec --only firestore --project demo-chamae-rules "npm --prefix functions run test:rules"
```

Os testes cobrem checkout real, UID, queries, Auth anônimo sem privilégios,
roles, transições, campos protegidos, backend-only, privacidade do motoboy,
acertos atômicos, fraude, replay, imutabilidade e rejeição de lotes não suportados.
O setup com Rules desabilitadas demonstra fixtures backend; o Admin SDK continua
fora da avaliação das Rules e depende de IAM/credenciais do backend.

Referências oficiais:
- https://firebase.google.com/docs/firestore/security/rules-fields
- https://firebase.google.com/docs/firestore/manage-data/transactions
- https://firebase.google.com/docs/firestore/security/test-rules-emulator
