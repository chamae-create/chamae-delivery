# CHAMAÊ — raio operacional e comunicação de horário

Data: 19/10/2026. Projetos locais `chamae_delivery` e `chamae_admin`. Firebase: `chamae-delivery`.

## RAIO OPERACIONAL

Implementação local concluída. A distância de rota de até 14.500 m é elegível; 14.501 m é rejeitada para a tabela inicial. A seleção da faixa usa a distância original em metros, antes da formatação visual. O adaptador Google Routes exige metros inteiros válidos.

As 28 faixas e seus preços iniciais permanecem intactos: primeira faixa até 1.000 m por R$ 6,00; última até 14.500 m por R$ 40,00. Nenhum piso adicional de R$ 8,00 foi introduzido. O limite técnico continua em 30.000 m, sem exigir faixas até esse limite.

## FONTE DO RAIO

`serviceRadiusMeters = deliveryPricingVersions[deliveryConfiguration/current.activeVersion].table.maxDistanceMeters`.

Esse é um valor derivado, sem campo independente de raio persistido ou editável. A validação exige que `maxDistanceMeters` coincida com o limite da última faixa, sem lacunas, sobreposições ou faixas desabilitadas na publicação.

## CONFIGURAÇÃO ATIVA

Mudança solicitada nesta etapa: `chamaeSalvarConfiguracaoEntrega`, com `publish: true`, agora grava a versão imutável e atualiza `deliveryConfiguration/current.activeVersion` atomicamente. O modo passa a `routeBands`; demais parâmetros da configuração são preservados. Apenas superadmin não anônimo, sem cadastro de entregador, pode publicar.

Publicar 20.000 m expande o alcance; publicar 12.000 m o reduz. Repetir o identificador de uma publicação anterior não reativa uma versão já substituída. Uma configuração publicada por essa ação passa a ser ativa; versões anteriores permanecem como histórico imutável.

Isso altera a semântica anterior de publicação inativa. Não houve chamada a esse endpoint em produção. O antigo endpoint separado de ativação permanece bloqueado e orienta usar a publicação explícita.

Consulta somente leitura ao Firestore nesta etapa: `deliveryConfiguration/current` retornou HTTP 404. Portanto, 14,5 km é o alcance do modelo inicial e dos cenários de teste, e não uma afirmação de que existe tabela ativa em produção.

## DRAFT

Salvar rascunho grava sua versão e o ponteiro `deliveryConfiguration/draft`, sem alterar a configuração corrente, a elegibilidade ou os preços operacionais. Alterações locais, subdivisões e descarte também não publicam automaticamente.

## PAINEL

A seção Frete por distância mostra Configuração ativa, raio atual derivado da tabela ativa, quantidade de faixas, versão e data legível de publicação. Sem configuração ativa, o alcance aparece como não configurado.

O editor mostra separadamente `Raio após publicação: X km`. A confirmação explica que publicar torna a versão ativa para novas cotações. Foram preservados edição, remoção, subdivisão em 100 m, adição de faixas e expansão até 30 km; a adição é desabilitada quando a última faixa já alcança esse limite. Nenhum campo independente chamado raio foi criado.

## CLIENTE

O fluxo existente continua consumindo a cotação autoritativa do backend. Fora da área, exibe exatamente:

> Este endereço está fora da área de entrega disponível no momento.

O estado remove a cotação anterior; não mostra frete numérico e bloqueia a continuação do carrinho. Alterar o endereço invalida a cotação imediatamente; respostas antigas não sobrescrevem o destino atual. A confirmação de compra mantém a atualização de cotação existente.

## BACKEND

Além da validação na cotação, o aceite financeiro revalida a distância da cotação privada contra a tabela ativa publicada, recalcula a faixa e confere preço, versão e origem. Campos de distância, versão e frete enviados pelo cliente não têm autoridade. Uma cotação anterior à redução não permite comprar fora do novo alcance. Se a versão mudar, é necessária nova cotação mesmo que o destino continue atendido.

A publicação concorrente com uma consulta Routes invalida o resultado em andamento antes de gravar a cotação. A idempotência por usuário/identificador continua preservada. Não foi mantida uma exceção baseada apenas na data de criação de propostas, que permitiria contornar o alcance atual.

Pedidos já confirmados continuam retornando o financeiro congelado antes de consultar a nova tabela. Distância, frete, versão e provedor não são recalculados em uma repetição da operação financeira.

## GOOGLE ROUTES

Arquitetura preservada: `RoutingProvider` → `GoogleRoutesProvider`, exclusivamente no backend. A distância oficial continua sendo `routes.distanceMeters`. Não existe fallback silencioso para Haversine, linha reta ou frete zero.

Falha de rota mantém a mensagem:

> Não foi possível calcular a entrega agora. Tente novamente.

Consulta somente leitura nesta etapa: Routes API não apareceu nos serviços habilitados do projeto e o segredo `CHAMAE_ROUTES_API_KEY` retornou NOT_FOUND. Nenhuma chave foi criada, lida ou exposta. Nenhuma API, segredo ou configuração do Cloud foi modificada.

## TEXTO DELIVERY ATÉ 00:00

O texto compartilhado em `lib/core/store_hours.dart` passou de `Loja aberta • até 00:00` para `Delivery até 00:00`. Busca em `lib` não encontrou o texto antigo equivalente.

Somente a comunicação mudou. Regra 08:00–00:00 MS/UTC−4, catálogo navegável fora do horário e bloqueio de checkout foram preservados. Texto de loja fechada permanece com seu significado original.

## TESTES

| Validação | Resultado |
| --- | --- |
| Backend `npm test` | 274 aprovados |
| Backend `npm run lint` | aprovado, sem erros |
| Firestore Rules + operações finais + raio, emulador local | 227 aprovados; saída 0 |
| Cliente Flutter, suíte completa VM | 102 aprovados |
| Cliente `flutter analyze` | sem problemas |
| Painel: frete, autorização e responsividade | 56 aprovados |
| Painel: análise dos arquivos alterados | sem problemas |

Cobertura inclui 14.500/14.501 m, draft de 20 km ignorado, publicação para 20 km, redução para 12 km, limite inclusivo de 12.000 m, tentativa de forçar frete, cotação anterior à redução, corrida de publicação com Routes e preservação financeira de pedido confirmado. O emulador também exercita a transação com Firestore real local. Nenhum teste de integração usa Firestore de produção.

Os testes do painel cobrem separação ativo/rascunho, atualização do raio por publicação, expansão para 30 km, redução, subdivisão e data legível. Os testes do cliente cobrem a mensagem exata, remoção do valor, botão desabilitado, invalidação por mudança de endereço e a comunicação de horário sem mudar os limites de funcionamento.

## BUILDS

| Artefato local | Resultado |
| --- | --- |
| Cliente `flutter build web --release` | aprovado |
| Cliente `flutter build apk --debug` | aprovado |
| Painel `flutter build web --release`, versão final | aprovado |

Saídas: `chamae_delivery/build/web`, `chamae_delivery/build/app/outputs/flutter-apk/app-debug.apk` e `chamae_admin/build/web`. APK não instalado por esta etapa. Builds não publicados.

Logs: cliente/backend em `chamae_delivery/tool/raio_*.log`; painel em `chamae_admin/tools/raio_*.log`. Resultados finais do backend são `raio_backend_tests_final.log` e `raio_backend_lint_final.log`; a primeira execução de lint foi corrigida antes da validação final.

## ARQUIVOS DESTA ETAPA

Cliente/backend:

- `functions/delivery-pricing.js`: verificação explícita do alcance da tabela.
- `functions/delivery-service.js`: publicação/ponteiro ativo atômicos e revalidação no aceite.
- `functions/google-routes-provider.js`: exige distância inteira válida do Google.
- `functions/test/delivery-official.spec.js`, `delivery-contracts.spec.js`, `financial.spec.js`: regressões de alcance, publicação, idempotência e congelamento.
- `functions/test/delivery-radius.emulator.spec.js`: novo teste de transação local.
- `lib/core/store_hours.dart`: texto compartilhado.
- `test/client_readiness_test.dart`, `test/delivery_quote_state_test.dart`: horário e bloqueio visual de entrega.

Painel:

- `lib/delivery_settings.dart`: raio ativo/rascunho, confirmação de publicação e data legível.
- `test/delivery_settings_test.dart`: cobertura correspondente.

Nenhuma alteração manual nesta etapa em Auth, documentos jurídicos, PIN, PIX, estoque, chat, comissão, taxa de serviço, regras de remuneração, Maps Android, catálogo ou onboarding. A regra existente de repasse permanece como estava; esta etapa não define uma nova política financeira.

## BLOQUEADORES

Para homologar com Google Routes real: habilitar Routes API no projeto correto; provisionar o segredo dedicado e suas restrições adequadas de API; definir/aprovar a origem real Pit Stop V8 e o modo de transporte na configuração; disponibilizar os endpoints atualizados no ambiente de homologação; executar rotas reais BR/PY, limites de alcance, falhas/retry e conferência financeira. As coordenadas dos testes são sintéticas e jamais configuram a loja.

Não há configuração ativa em produção no documento consultado. A ausência de Routes/segredo/configuração continua falhando de forma fechada. Nenhuma chamada real de cálculo Google Routes foi realizada nesta etapa.

## DEPLOY NECESSÁRIO

Sim, para que estas mudanças locais tenham efeito no ambiente servido: backend de entrega, painel web e cliente web/Android, após preparação da infraestrutura e aprovação da homologação. Não há alteração de Rules nesta etapa. Publicar uma tabela válida no painel implantado passa a alterar o alcance e o modo operacional imediatamente para novas cotações; a ação deve ocorrer de forma explícita no ambiente pretendido.

Nenhum deploy, commit, push ou publicação de tabela em produção foi realizado.

**AINDA EXISTEM BLOQUEADORES**
