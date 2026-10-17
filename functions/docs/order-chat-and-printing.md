# Chat e registro de impressão do piloto

Módulos isolados: `order-chat.js` e `order-printing.js`. Não alteram pagamentos, estoque, operações de pedido ou acertos. Registro no `index.js` por factories, na região `southamerica-east1`.

## Contratos

- `chamaeEnviarMensagemPedido`: `{orderId, text, requestId}`. ID documental, texto de 1 a 2.000 caracteres, ID idempotente de 16 a 100 caracteres. Allowlist estrita; timestamps do servidor; caracteres de controle recusados.
- `chamaeMarcarChatLido`: `{orderId}`. Zera somente o contador do participante autenticado. Não cria conversa vazia.
- `chamaeRegistrarImpressaoPedido`: `{orderId, requestId, part, paperMm}`. `part`: both/separation/delivery. Papel: 58/80. Retorna count/replayed. Conta solicitações, nunca confirma saída física do papel.

Cliente autenticado, inclusive anônimo atual: somente seu pedido validado. Operação/superadmin: conta nominal. Conta presente em `couriers/{uid}` não acessa chat ou log, mesmo com claim administrativa. Financeiro/Catálogo isolados são recusados, inclusive se tentarem usar a propriedade do pedido para contornar a restrição.

`orderChats/{orderId}` contém somente metadados mínimos e contadores; subcoleção messages contém texto, autoria e data. Envios repetidos não incrementam contadores. Marcação de leitura e envio são transacionais. Mudança de texto com mesmo requestId é rejeitada. Nova mensagem é bloqueada na fronteira de 24 horas depois de completedAt; cancelamento encerra imediatamente. Histórico preservado. Metadados de fechamento são atualizados quando o chat encerrado é marcado como lido; a janela é validada independentemente deles.

Rules permitem leitura pelo proprietário ou operação e negam toda escrita SDK. Listagem de chats é exclusiva da operação; o proprietário consulta somente seu documento e suas mensagens. Registros auxiliares `orderPrintLogs` e `orderPrintStats` ficam sob a negação global de SDK. Não houve alteração adicional nas Rules de orders, financeiro, produtos ou courierDeliveries neste fechamento.

O painel limita a espera do log auxiliar a dois segundos. Falha/timeout não impede impressão; usa contagem local e comando explícito de segunda via. A janela de impressão abre na interação do usuário, antes do await. Não tratar contagem como comprovante financeiro ou de impressão física.

## Testes locais

`npm run test:chat:emulator` exige FIRESTORE_EMULATOR_HOST local. Nunca usa produção como fallback. Inclui isolamento entre clientes, papéis, motoboy com claims, anônimo, allowlist, limite de texto, controle de caracteres, idempotência, contadores, Rules de leitura/escrita, legado, janela de 24 horas e registro de impressão sem mutar o pedido. A suíte completa de Rules e a integração operacional também devem passar.

## Publicação manual

Depois da revisão do relatório do painel:

```powershell
Set-Location C:\Users\DELL\chamae_delivery
firebase deploy --project chamae-delivery --only 'functions:chamaeEnviarMensagemPedido,functions:chamaeMarcarChatLido,functions:chamaeRegistrarImpressaoPedido'
firebase deploy --project chamae-delivery --only firestore:rules
Set-Location C:\Users\DELL\chamae_admin
firebase deploy --project chamae-delivery --only hosting:chamae-admin
```

A configuração delivery atual não define Hosting para o cliente. O build web compatível deve seguir o canal de distribuição já usado para o cliente; não inventar target, não mudar IAM/Rules de Storage. Sem distribuição desse cliente, a entrada de chat não aparece para usuários do build anterior.

Não houve publicação automática. Para operação diária, checklist físico, revisão de fotos e rollback, consultar `C:\Users\DELL\chamae_admin\docs\pilot_final_homologation.md`.