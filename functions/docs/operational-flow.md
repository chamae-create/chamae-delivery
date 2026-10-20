# Contrato operacional — homologação 17/10/2026

Esta política substitui as descrições anteriores de atribuição/despacho pelo Kanban.

## Loja

O painel normal, inclusive superadmin, somente inicia `Novo → Em Separação`. `chamaeIniciarSeparacao` continua com as mesmas verificações de financeiro/estoque, fingerprint e idempotência. No mesmo commit cria `courierDispatchRequests/{orderId}` e grava `courierDispatchState: awaiting_integration` no pedido.

A solicitação tem versão 1, `phase: awaiting_integration`, primeira onda `longest_idle_first`, ofertas de 15 segundos, segunda onda `all_available`, aceite `atomic_first_valid_accept`, retirada `validated_app_qr_event` e conclusão `validated_app_delivery_event`. O timestamp de servidor não é renovado em retries. As Rules negam acesso de navegadores à solicitação pela negação padrão.

Isso prepara uma outbox para integração futura; não executa ofertas nem presume que cadastro administrativo ativo seja disponibilidade online. Não foram implementados FCM, GPS, ON/OFF ou Border Mode.

O futuro consumidor deve ordenar por última atribuição de entrega (nunca atribuídos primeiro, desempate por UID), usar prazo de servidor e revalidar disponibilidade, identidade, oferta, estado do pedido, financeiro/estoque e ausência de vencedor numa transação. A primeira aceitação válida deve gravar atribuição e relógio de justiça atomicamente. Uma rodada individual sem aceite habilita a onda simultânea. Cancelamentos invalidam ofertas.

Pedido atribuído ainda fica em separação e aparece como Aguardando retirada. Só um evento validado do app poderá iniciar a rota; só um evento de entrega validado, incluindo PIN, poderá concluir. Essas APIs futuras não foram criadas nesta tarefa. O QR atual abre mapas e não é autorização de mudança de status.

## Contingência superadmin

`chamaeAtribuirMotoboy`, `chamaeDespacharPedido` e `chamaeConcluirEntrega` deixam de ser ações normais da loja. Além dos parâmetros anteriores, exigem:

- Auth não anônimo com `roles` em lista contendo `superadmin`;
- `contingencyReason` com 10–500 caracteres após trim;
- `confirmation` exatamente `CONFIRMAR {orderId}` (ID documental).

`operations_admin` isolado, finance, catálogo e cliente não recebem essa capacidade. O cadastro real do motoboy, financeiro/estoque e estados permitidos continuam sendo revalidados. Listagem de motoboys conserva suas permissões anteriores, sem conceder mutações.

`operationalContingencyAudit/{id}` é escrito na mesma transação que pedido/projeção/ledger: ator, motivo, timestamp de servidor, operação, origem, estado anterior/novo de status/UID/nome. Confirmações sem mudança também deixam trilha; replay do mesmo `requestId` não duplica a auditoria. As Rules atuais negam leitura/escrita por navegadores; a inspeção fica no backend/console autorizado.

O painel oferece uma área separada para isso, sem botões de atribuir/despachar/concluir nos cards. Solicita motivo, confirmação digitada e confirmação adicional. Não usar essas callables como substituto das futuras APIs autenticadas de aceite/QR/PIN do motoboy.

## Publicação

Requer atualização das quatro Functions: `chamaeAtribuirMotoboy`, `chamaeDespacharPedido`, `chamaeIniciarSeparacao`, `chamaeConcluirEntrega`; depois Hosting do administrador. Rules e cliente não foram alterados. Nenhum deploy foi executado nesta tarefa.
