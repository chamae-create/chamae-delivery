# Leitura de pedidos no app cliente

`CustomerOrders` centraliza as leituras usadas pelo tracking e pelo
acompanhamento do pedido no checkout. O UID vem exclusivamente da sessão
Firebase Auth, inclusive das sessões anônimas usadas pelo app cliente.

- Tracking: `customerUid == auth.currentUser.uid` e `id == orderId`.
- Checkout: `customerUid == auth.currentUser.uid` e
  `FieldPath.documentId == orderReference.id`.
- Sem sessão, nenhuma consulta é criada. Logout, troca de conta e erro de
  autenticação cancelam a assinatura anterior e retiram seus dados da tela.
- A resposta ainda é validada pelo `customerUid` antes de chegar à interface.
- IDs desconhecidos, pedidos de outra conta e documentos antigos sem
  `customerUid` não são exibidos.

A estrutura de criação de pedidos, valores, estoque, geração e processamento
do PIX não foram alterados. No diálogo de pagamento foi modificada somente a
assinatura de leitura e a autorização da sessão que pode receber seus dados
ou concluir a navegação após o pagamento. A cobrança real não é simulada pelos
testes de interface.

## Protótipo de entregadores

Motoboy não acessa orders.
Dados de entrega serão fornecidos por courierDeliveries sanitizado.

`MotoboyAppScreen` é uma tela indisponível, sem dependência do Firestore, sem
consultas, QR de retirada ou atualização de status. Não há integração com
`courierDeliveries` enquanto seu backend sanitizado não existir. Não são
exibidos telefone, WhatsApp, e-mail, finanças, IDs Mercado Pago ou histórico.

A auditoria não encontrou rotas, imports ou botões de entrada para os
protótipos `MotoboyAppScreen` e `AdminScreen` no app atual. O arquivo legado
`admin_screen.dart` ainda contém operações administrativas em `orders`, mas
não faz parte da navegação do cliente. Não foi alterado nesta tarefa; qualquer
reativação exigirá autorização administrativa e revisão específica.

## Validação e publicação futura

Executar `flutter analyze`, `flutter test` e
`flutter test --platform chrome test/checkout_web_test.dart`.
O teste de checkout é exclusivo de navegador porque sua árvore de imports
inclui `dart:js_interop`. Os demais testes executam sem conexão Firebase.

A leitura por UID no cliente complementa as Security Rules; a proteção contra
um cliente adulterado depende das regras no servidor. Nenhuma regra foi
alterada ou publicada nesta tarefa. Preservar a restrição de propriedade nas
regras e a proibição de acesso de entregadores a `orders`.

As novas consultas usam filtros de igualdade existentes (`customerUid` e
`id`/ID documental). Se os índices necessários estiverem desabilitados no
projeto remoto, sua configuração deverá ser conferida antes da publicação.
Limpar o armazenamento de uma sessão anônima pode gerar outro UID; pedidos
da identidade anterior não passam a pertencer à nova sessão.

## Resultado desta integração

- `flutter analyze`: zero erros; cinco infos e um warning já presentes antes
  da integração. O comando retorna código 1 por esses apontamentos existentes.
- `flutter test`: 14 testes de autorização, sessão, tracking e motoboy.
- Smoke funcional Web: um teste de checkout, incluindo carrinho, total e
  botão de PIX, executado no Chrome. Não efetua cobrança nem cria pedidos.
- Não havia testes Flutter no projeto antes desta tarefa. Os testes de Rules
  existentes foram preservados, assim como regras e Functions.

Limitação do runner Web deste SDK no Windows: o servidor de testes retorna
404 para `canvaskit/chromium/canvaskit.js` e `canvaskit.wasm`, embora os arquivos
existam no cache do Flutter. Para concluir esta validação foi necessário
fornecer esses mesmos arquivos originais à instância temporária de Chrome por
automação de depuração. O SDK e o aplicativo não foram alterados para isso.
Uma repetição simples do comando Web neste ambiente pode voltar a bloquear no
carregamento até que o runner seja corrigido.

O smoke funcional usa a largura padrão de testes (800 px), tema do aplicativo
e a fonte de testes do Flutter. Ele não é um teste visual de responsividade:
com Ahem, a fixture estreita de 440 px apresentou overflow de texto na linha
preexistente de taxa da plataforma. Nenhuma exceção é ignorada no teste final.
O layout real e os cálculos foram preservados por comparação com a cópia
original do checkout.