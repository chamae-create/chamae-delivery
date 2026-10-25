# Correção das duas fixtures de checkout — 25/10/2026

Escopo: somente as duas falhas da suíte Flutter 207/209. Alterações anteriores
do workspace preservadas. Nenhuma alteração em `lib/`, Functions, Rules,
dependências ou nos relatórios/checklists aprovados dos KB-03/04/05/06.

## Reprodução e classificação

Executados primeiro `checkout_delivery_contract_test.dart` e
`client_readiness_test.dart`: **19/21 aprovados, 2 falhas**, registradas em
`tool/checkout_test_fixes_2026-10-25/before.log` com erros e stacks completos.

### Falha 1

Teste: `checkout refuses an unconfirmed destination before any order write`.

Classificação: **A — fixture/teste desatualizado**, com dependência incidental
**C — horário**. Não foi identificada regressão de negócio.

A fixture `Quoter` retornava cotação válida para destino não confirmado. Isso
divergia do contrato de `chamaeCotarEntrega`, em `functions/delivery-service.js`,
que rejeita `confirmed !== true` com `invalid-argument` e razão
`DESTINATION_COUNTRY_UNVERIFIED`. O teste também esperava uma mensagem do
callback de finalização mesmo quando o botão estava desabilitado pelo horário
da loja. O erro reproduzido era ausência da mensagem esperada.

Correção somente no teste:

- O double de cotação reproduz a rejeição do backend para destino não confirmado,
  usando `FirebaseFunctionsException` do pacote já existente.
- A sessão de teste está verificada, para isolar o destino como causa do bloqueio.
- O teste verifica o destino enviado, a rejeição da cotação, o botão desabilitado,
  a preservação da sacola e ausência de nova cotação/limpeza após o toque.

O bloqueio agora decorre da ausência de cotação válida, independentemente do
horário corrente. Não foi usado skip, relógio adulterado, cotação fictícia para
destino inválido ou liberação do botão em produção. A asserção passou a refletir
o fluxo real de rejeição antes da criação do pedido.

### Falha 2

Teste: `país desconhecido usa confirmação excepcional`.

Classificação: **A — preparação incompleta do teste** e **D — visibilidade/layout
na fixture**. Não foi identificada regressão da regra BR/PY.

O erro completo informa que o toque em “Confirmar país da entrega” ocorria em
`Offset(255.3, 620.0)`, fora do viewport padrão `800 × 600`. O aviso/rodapé de loja
fechada alterava a área útil. O diálogo não abria porque o toque não atingia o
controle; o conteúdo continua acessível por rolagem no app.

Correção: `ensureVisible`, estabilização da rolagem e verificação
`hitTestable()` antes do toque. Mantidas as asserções de abertura do diálogo,
seleção de Paraguai e atualização do destino. Sem alterar viewport, UI, métodos
de pagamento ou lógica de país para acomodar o teste.

## Preservação

A regra backend permanece **08:00 inclusive até 00:00 exclusivo**, em
`America/Campo_Grande`. Nenhum guard, cálculo, regra comercial ou relógio de
produção foi alterado. PIX, frete, estoque, financeiro e BR/PY preservados.

Inventário SHA-256 de 247 arquivos preexistentes de `lib/`, `functions/`, `docs/`,
Rules e dependências em `tool/checkout_test_fixes_2026-10-25/protected-before.json`.
Comparação concluída: **247/247 inalterados**, em `protected-after.json`.

Arquivos corrigidos: `test/checkout_delivery_contract_test.dart` e
`test/client_readiness_test.dart`. Este relatório e logs são evidência adicional;
não alteram status/gates de homologação.

## Validação

- Direcionados após correção: **21/21 aprovados**, em `targeted-after.log`.
- `flutter analyze`: **No issues found**, em `flutter-analyze.log`.
- `flutter test` completo: **209/209 aprovados**, em `flutter-all.log`.
- `git diff --check` dos dois testes: aprovado.

Logs e resumo em `tool/checkout_test_fixes_2026-10-25/`. A quantidade de testes
permanece 209; nenhum foi removido, ignorado ou substituído por teste vazio.

Flutter é executado pelo entrypoint do SDK instalado, com `--no-pub`,
`--no-version-check` e `--suppress-analytics`; nenhuma dependência atualizada.

Firebase produção, Oracle/GrandChef, Apple/Google produção: não acessados.
Commit, push e deploy: não realizados. Validação concluída; aguardar revisão humana.
