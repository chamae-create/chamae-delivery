# Ciclo de conta e confirmação de pedidos — 24/10/2026

## Estado confirmado na retomada

Os arquivos do refinamento anterior e do frete estão presentes, inclusive modificações não commitadas. Não foi encontrado código de exclusão de conta nem este relatório no início da retomada. Portanto, não houve descarte/recriação de uma implementação de exclusão existente. Backups desta etapa: `tool/account_cycle/before`; hashes de contratos protegidos: `tool/account_cycle/protected-before.json`. O usuário confirmou pub get e analyze normalizados; nenhuma atualização de dependências foi solicitada ou realizada nesta etapa.

Auth atual: Google/Apple via Firebase, vínculo de sessão anônima antiga preservando UID, refresh/logout e reautenticação já disponíveis. Não há criação nova de sessão anônima no bootstrap oficial. Perfil contém consentimentos/DOB; workspace contém contato, endereços, sacola e proposta pendente. Pedidos, cotações, snapshots de destino, projeções de entregador, PIN e mensagens também podem conter dados pessoais.

Auditoria da confirmação: a tela de marca já exige financeiro validado e PIX pago. Contudo, `FirebaseCustomerWorkspace.completeOrder` ainda podia consumir a sacola de dinheiro apenas por encontrar um pedido; o acompanhamento repetia essa condição. O diálogo PIX finalizava com `paymentStatus: Pago` sem repetir os demais critérios da confirmação. São correções necessárias de aceite no cliente, sem mudar cálculos, pagamento, cotação ou estoque do servidor.

## Contrato de exclusão a implementar

- A solicitação deve usar exclusivamente o UID do token autenticado, identidade recente e confirmação explícita. Recusar perfis administrativos/entregadores, UID externo e payload livre.
- Um registro privado por UID deve servir de trava e controle idempotente, com estados requested/processing/completed/blocked. Rules e callables devem impedir recriação de dados/novas compras enquanto a exclusão estiver ativa.
- Antes de apagar dados, conferir todos os pedidos do UID, incluindo status desconhecidos, pagamentos em andamento e reservas/revisões de estoque. Se existir pendência, não apagar dados; devolver estado bloqueado acionável.
- Processamento durável por evento Firestore com retry, independente de o app permanecer aberto. Operações paginadas e repetíveis, sem cobrança, estorno, baixa ou reserva de estoque.
- Remover perfil, workspace, segredo/PIN, consentimentos com DOB, propostas/cotações, mensagens e dados pessoais conhecidos dos pedidos encerrados. Remover coordenadas do destino dos snapshots privados; preservar preço, distância, unidade, faixa, versão, valores financeiros, produtos, datas e estados operacionais. Manter um identificador pseudônimo para o vínculo documental, sem expor dados da conta.
- Excluir o usuário Firebase Auth ao final; user-not-found em retry não é erro. Concluir o controle somente após todas as etapas. A conta Google/Apple externa não é excluída.

Esta é minimização/pseudonimização operacional, não uma declaração de anonimização irreversível. O controle técnico por UID e os registros financeiros/operacionais necessários permanecem restritos. Não se inventa prazo de retenção legal nem se apagam livros financeiros. A política de retenção/backups, logs, documentos fiscais e revogação no provedor Apple/Google precisam revisão operacional/jurídica antes de produção; nenhuma conformidade de loja é presumida.

## Referências técnicas

O Admin SDK permite [excluir usuário por UID](https://firebase.google.com/docs/auth/admin/manage-users). Exclusão de documento não elimina automaticamente subcoleções; a limpeza deve contemplá-las explicitamente, conforme a [documentação de exclusão Firestore](https://firebase.google.com/docs/firestore/manage-data/delete-data). O processamento por evento deve suportar reexecução e [retry de funções assíncronas](https://firebase.google.com/docs/functions/retries). Foram consultadas apenas páginas públicas de documentação, sem Firebase de produção.

## Implementação e validação

A preencher com o resultado final da implementação e dos testes locais. Nenhuma exclusão de dados reais, commit, push ou deploy é autorizada por esta etapa de implementação local.
