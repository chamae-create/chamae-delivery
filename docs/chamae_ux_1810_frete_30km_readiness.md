# CHAMAE-UX-1810 + CHAMAE-FRETE-30KM

Data: 18/10/2026. Implementação local nos projetos `chamae_delivery` e `chamae_admin`. Sem deploy, commit ou push. O novo modo de cobrança por rota permanece inativo.

## ESTADO INICIAL AUDITADO

A inspeção dos dois projetos foi concluída antes das alterações desta etapa: [auditoria inicial](chamae_ux_1810_frete_30km_auditoria.md). Já havia alterações locais em ambos os projetos; foram preservadas.

O cliente abria diretamente no catálogo após inicializar Firebase e uma sessão anônima. Já existiam mapa ajustável, geocoding, país estruturado, histórico por `customerUid`, acompanhamento, chat, PIX, pagamentos na entrega, horário MS e financeiro autoritativo. Endereço/carrinho estavam em memória. Não havia conta verificada, PIN, tabela por distância nem provedor de rotas. O frete efetivamente implementado era R$ 10 no cliente/backend. Não foi localizada origem aprovada da Pit Stop V8; o ponto inicial do mapa não foi convertido em origem comercial.

O admin já tinha autenticação por claims e áreas protegidas. Foi identificado que os repasses existentes usam `deliveryFee`; por isso a tabela nova não pode ser ativada sem separar a remuneração do motoboy. Nenhuma remuneração nova foi implementada.

## UX IMPLEMENTADA

- Splash oficial preservado, sem espera mínima artificial. Após inicialização e sessão, abre “Onde vamos entregar?”.
- GPS por escolha explícita, entrada manual, revisão, endereços salvos e exploração sem endereço.
- Endereço compacto na Home com ação Alterar. O carrinho informa que a entrega será calculada na confirmação do destino.
- Checkout permite alterar destino, invalida a cotação anterior, limpa valores de pagamento que dependiam daquele total e mantém itens.
- Cotação possui carregamento, erro, fora da área e retry; falha não apresenta um frete zero como preço definitivo.
- Convite contextual a notificações apenas no acompanhamento do pedido. Nenhuma permissão é solicitada na abertura. O adaptador real de push continua pendente: o componente informa isso e mantém o acompanhamento dentro do app.

## ENDEREÇOS

Entrada manual com rua, número/sem número, bairro e cidade, seguida do mapa com marcador central ajustável. GPS e busca sugerem o ponto; a confirmação das coordenadas depende do cliente.

A revisão permite corrigir rua, número, bairro, cidade, complemento e referência. O destino tem flag explícita `confirmed`; checkout e Rules exigem confirmação, coordenadas válidas e campos essenciais para novas compras.

`customerWorkspaces/{uid}` guarda último endereço confirmado, Casa/Trabalho/Outro, carrinho e proposta pendente. O acesso é restrito ao próprio cliente. A inicialização habilita persistência Firestore; o app oferece o último destino para revisão, sem aplicá-lo silenciosamente. Falhas de sincronização são exibidas e o estado em memória é mantido.

Limites práticos: cache depende do suporte do navegador/dispositivo e da sessão Firebase; limpar dados do navegador remove a sessão/cache local. Não foi criada migração entre UIDs. A futura verificação deve vincular a identidade ao UID existente. Não há promessa de resolução de edição simultânea do carrinho em vários dispositivos.

## BRASIL/PARAGUAI

Country code vem dos campos estruturados de geocoding para as coordenadas confirmadas, sem inferência por texto livre. A revisão mostra Brasil/Paraguai e mantém país sem edição no caso normal. Só oferece escolha excepcional quando o país não foi identificado; país estruturado fora de BR/PY impede confirmação.

Foram mantidos PIX/dinheiro/cartão na entrega para BR e PIX/dinheiro para PY, contabilidade BRL, moedas BRL/PYG/USD e regras existentes de troco em BRL. Horário preservado: diariamente 08h–00h em Mato Grosso do Sul; catálogo continua navegável fora do horário.

O futuro adaptador de rota deve validar cobertura e país do ponto com fontes confiáveis no servidor; o país recebido do app não substitui essa validação geográfica. Não foi inventada uma geofence ou escolhido um serviço externo.

## CONTA VERIFICADA

`AccountVerification` separa contrato e implementação externa. Navegação anônima permanece disponível. Novas compras exigem identidade não anônima e claim confiável `customerVerified == true`, também nas Rules. O cliente não pode conceder essa claim por gravar o workspace.

O estado de verificação é atualizado a partir do token. Clientes já verificados não repetem o convite. `chamaeEstadoVerificacao` informa que nenhum canal está configurado. Não foram escolhidos SMS, WhatsApp, e-mail ou provedor.

**Bloqueador funcional:** enquanto o canal não for integrado e emitir a claim após verificação confiável, novas compras ficam bloqueadas por design. Não publicar as novas Rules isoladamente esperando que o checkout anônimo antigo continue comprando. Histórico pertencente ao UID e navegação continuam acessíveis.

## PIN

Perfil e pedido em andamento têm componente para revelar o PIN por ação explícita e texto para informá-lo somente ao receber. O valor é retirado da tela ao mudar sessão ou colocar o app em segundo plano.

Backend gera quatro dígitos com fonte criptográfica, preserva zeros iniciais e mantém valor fixo criptografado com AES-256-GCM, vinculado ao UID. A chave `CHAMAE_DELIVERY_PIN_KEY` deve conter 32 bytes em hexadecimal e ser provisionada fora do código. Nenhuma chave real foi criada ou gravada no repositório.

Redefinição exige conta verificada, autenticação recente e ausência de pedidos nos estados ativos usados pelo sistema; erros da consulta falham fechados. Nova revisão e evento de auditoria são gravados atomicamente, sem PIN em texto. O novo PIN difere do anterior. Callables recusam perfis de motoboy.

O contrato de verificador por pedido usa HMAC com segredo exclusivo do servidor e salt por pedido, até cinco tentativas e estado de reconciliação. Registros inválidos são recusados. PIN, segredo e verificador não são projetados para `courierDeliveries` e as coleções privadas não admitem leitura direta por cliente, motoboy ou admin.

**Integração futura pendente:** emissão do verificador no ciclo do pedido, endpoint transacional de conferência do entregador, autorização por atribuição, persistência atômica de tentativas/auditoria e política de limitação por ator. A função pura de verificação não é um endpoint de entrega nem um limitador distribuído completo.

Contrato offline futuro: um dispositivo pode enfileirar evento com ID idempotente, pedido, entregador e horário declarado; o estado será `pendingReconciliation`. Entrega somente será definitiva após o servidor validar atribuição, estado, tentativas e evidências. Não enviar HMAC/segredo ao aparelho nem confiar em limite local. A captura e reconciliação offline dependem do app do motoboy, fora desta etapa. Não foi implementada validação offline fictícia nem substituído o fluxo operacional já existente.

## FRETE

Faixas contíguas em metros inteiros, até 30.000 m e no máximo 300 linhas. Primeira começa em zero. Limite superior inclusivo, inferior exclusivo nas seguintes. A distância real da rota é comparada antes de qualquer arredondamento: 1100 m pertence à faixa até 1100; 1100,01 m e 1101 m à seguinte. O preço é completo, sem soma progressiva.

Validações recusam lacunas, sobreposição, negativos, inversões, limites acima de 30 km, preço inválido e faixa em rascunho na publicação. A última faixa define o alcance. Subdividir em 100 m mantém o preço anterior e gera rascunhos para revisão.

Nenhum preço real foi preenchido. Valores sintéticos aparecem somente nos testes. A política de mínimo começa pendente; publicação exige escolha explícita entre substituição e piso de R$ 8. Nenhuma escolha foi tomada pelo código.

O modo legado continua cobrando o valor existente de R$ 10 e não foi removido. Publicar uma versão não muda a configuração corrente. A callable de ativação recusa a operação enquanto rota real e separação de remuneração não estiverem implementadas.

## CONFIGURAÇÃO ADMIN

Nova área “Configurações de entrega”, protegida para superadmin. Outros perfis não receberam permissão adicional. Editor em tabela com limites em metros, preço completo em reais, status, adicionar/remover e subdividir em 100 m. Permite salvar rascunho e publicar versão válida para revisão, sem ativar cobrança.

Origem comercial inicia vazia e deve ser preenchida com coordenadas aprovadas. Lista versões recentes com autor/data e permite carregar uma cópia para editar. Retry reutiliza requestId; alterações produzem nova tentativa. Campos são desabilitados durante salvamento.

## ROTA

`RoutingProvider.route({origin, destination})` retorna status, distância em metros, duração opcional e metadado mínimo de provedor. Adapter padrão retorna erro de não configuração. Fake existe apenas nos testes.

Falha, resposta inválida ou distância fora da tabela impedem cotação. Sem Haversine, estimativa silenciosa, tarifa inventada ou zero por falha. Origem não usa coordenadas fictícias. O adaptador real e as credenciais ainda precisam ser definidos e homologados, inclusive cobertura BR/PY.

## BACKEND

Novas callables na região `southamerica-east1`: salvar versão, cotar entrega, ativação bloqueada, estado de verificação, obter/redefinir PIN e descartar proposta ainda não criada.

`deliveryPricingVersions` mantém versões imutáveis com autor/data/fingerprint e idempotência. `deliveryConfiguration/current` selecionará o modo e versão ativa no futuro; não foi escrito nem ativado nesta execução.

No modo por rota, cotação privada vincula UID, origem, destino, país, versão, distância real, preço em centavos e validade de cinco minutos. Financeiro autoritativo ignora o frete enviado pelo cliente, valida cotação e consome sua referência atomicamente com a criação do financeiro. Uma cotação não pode financiar dois pedidos.

`orderFinancials` e espelho do pedido congelam `deliverySnapshot` com distância, deliveryFee, versão, timestamp, origem e destino. Pedidos com financeiro existente não são recalculados quando a tabela muda. Distância realmente percorrida pelo motoboy não altera a cobrança congelada.

Foi adicionado índice de `orders(customerUid, status)` para a consulta usada na redefinição do PIN e referência no `firebase.json`. Precisa ser criado no ambiente de homologação; não foi publicado.

## SEGURANÇA

Rules exigem conta verificada e destino confirmado nas novas compras; preservam leitura do histórico próprio e bloqueios de financeiro/estoque já existentes. Novas configurações não aceitam escrita direta do SDK. Workspace tem lista de campos permitidos e limites de tamanho, sem autoridade financeira ou de identidade.

O carrinho é persistido por UID. Antes da escrita, a proposta recebe documento único e fica persistida; retry ou reinício faz leitura do servidor antes de repetir uma escrita incerta. Falha dessa leitura impede a repetição. Uma proposta ainda não enviada revalida seus itens, estoque e frete; cotação vencida pode ser renovada pelo mesmo preço e ID de pedido. Se o preço divergir, bloqueia envio para revisão, sem cobrar a diferença silenciosamente.

Somente quantidades do pedido confirmado são retiradas do carrinho, preservando adições posteriores. A limpeza do carrinho e da proposta ocorre na mesma transação Firestore e só uma vez, vinculada ao documento/UID do pedido. PIX pendente mantém itens/proposta até confirmação. O acompanhamento também reconcilia a persistência quando observa o PIX pago, inclusive após reinício. Abrir a sacola/checkout recarrega o workspace para refletir essa confirmação. Sem conexão, o app mostra erro e retry; não usa cache como validação final de estoque.

Se uma proposta ainda não enviada tiver preço alterado, envio fica bloqueado para revisão. “Revisar sacola antes de enviar” consulta o backend: se o pedido já existe, mantém sua recuperação; se não existe, grava marca de descarte e limpa apenas a proposta, preservando itens. As Rules impedem que uma escrita atrasada crie essa proposta descartada. A operação é idempotente e transacional. Leitura de pedido com escrita local ainda pendente não é tratada como confirmação do servidor.

Essa nova integração de descarte/reconciliação precisa de homologação com Rules/emulador e aparelhos reais, além dos testes unitários. Não foi simulada aprovação de uma integração sem o ambiente local necessário.

## TESTES

- Cliente: suíte VM final com 53 testes aprovados, incluindo conta, cotação/retry, endereço, notificações, recuperação após reinício e preservação de adições ao carrinho.
- Cliente Chrome/Web: suíte completa com 54 testes aprovados, incluindo o smoke específico Web. As execuções intermediárias também passaram (48 na primeira suíte e 10 no grupo de contratos).
- Após retirar a persistência redundante durante recuperação de pedido já recebido, os 9 testes afetados de retry, carrinho e checkout passaram novamente; `flutter analyze` permaneceu limpo e o build Web final foi atualizado.
- Admin: 40 testes afetados aprovados em VM e 40 no Chrome, incluindo autenticação e configuração de entrega.
- Backend: `npm test` com 236 testes aprovados, incluindo 12 contratos novos de faixas/rota/PIN/descarte e integração real do financeiro em PIX automático, PIX manual e reserva na entrega. `npm run lint` aprovado.
- `flutter analyze` cliente sem ocorrências na última execução concluída. Admin com 22 diagnósticos preexistentes (2 warnings e 20 infos), sem erros e sem diagnósticos no novo editor; inclui `dart:html`, APIs depreciadas e estilo de código anterior.
- Rules: testes atualizados para conta verificada e destino confirmado; adicionados casos de isolamento de workspace, configurações e segredos/PIN. Execução local tentada com projeto `demo-chamae-rules`; emulador bloqueado por `spawn java ENOENT`. **Não aprovados por execução nesta máquina.**
- Mapas/GPS reais e prompt nativo de permissão ainda precisam de teste em aparelho/navegador com credenciais válidas. Os testes do fluxo usam resposta de mapa injetada; não equivalem a homologação do SDK do mapa ou permissão do sistema.

O Chrome precisou do contorno local documentado em `tool/chrome_test_assets.mjs` para os caminhos CanvasKit do runner Flutter 3.47 no Windows. Usa somente arquivos instalados no SDK via CDP no navegador de teste; não altera aplicação ou SDK e não utiliza serviço remoto de assets.

## BUILDS

Builds Web release finais concluídos em ambos os projetos:

- Cliente: `flutter build web --release --no-wasm-dry-run`, 50,0 s; artefatos em `C:\Users\DELL\chamae_delivery\build\web`.
- Admin: `flutter build web --release`, 286,7 s; artefatos em `C:\Users\DELL\chamae_admin\build\web`.

Os builds geraram JavaScript/CanvasKit. O dry run Wasm do cliente passou nas compilações anteriores desta etapa; a última repetição desabilitou apenas esse diagnóstico opcional. O admin avisa sobre incompatibilidade Wasm de `dart:html`, já existente, mas gerou seu build JavaScript com sucesso. Não é uma homologação de build Wasm.

Android continua sem SDK/Java utilizáveis nesta máquina. Build iOS requer macOS/Xcode. Não há APK/AAB/IPA novo validado nesta etapa.

## ARQUIVOS ALTERADOS

Cliente, dentro de `C:\Users\DELL\chamae_delivery`:

- `lib/main.dart`, `lib/core/models.dart`;
- `lib/screens/splash_screen.dart`, `address_destination_screen.dart`, `address_map_screen.dart`, `home_screen.dart`, `cart_screen.dart`, `checkout_screen.dart`, `customer_profile_screen.dart`, `tracking_screen.dart`, `tracking_view.dart`;
- `lib/data/customer_workspace.dart`, `customer_verification.dart`, `delivery_quote.dart`, `order_notifications.dart`, `order_attempt.dart`, `geocoded_address.dart`, `reverse_geocode_native.dart`, `reverse_geocode_web.dart`;
- `lib/widgets/delivery_pin_card.dart`, `order_notification_card.dart`;
- `test/address_flow_test.dart`, `checkout_delivery_contract_test.dart`, `order_notification_test.dart`, `order_attempt_test.dart`, `workspace_cart_test.dart`, `client_readiness_test.dart`;
- `functions/delivery-pricing.js`, `delivery-service.js`, `delivery-pin.js`, `customer-security.js`, integração pontual em `index.js`;
- `functions/test/delivery-contracts.spec.js`, `financial.spec.js`, `firestore.rules.spec.js`, fixtures afetadas em `pilot.emulator.spec.js`;
- `functions/.eslintrc.js`, `functions/package.json`, `firestore.rules`, `firestore.indexes.json`, `firebase.json`;
- esta documentação e a auditoria inicial.

Admin, dentro de `C:\Users\DELL\chamae_admin`: novo `lib/delivery_settings.dart`, integração da área/rota/menu em `lib/main.dart` e política `AdminAccess` em `lib/admin_auth.dart`, além de `test/delivery_settings_test.dart`. Alterações anteriores de outras tarefas não são atribuídas a esta entrega.

## DECISÕES PENDENTES

1. Preços reais de todas as faixas e alcance operacional inicial.
2. Tabela substitui o mínimo anterior ou respeita piso de R$ 8.
3. Provedor real de rota e suas credenciais/cobertura BR/PY.
4. Um único canal/provedor inicial de verificação da conta, com vinculação ao UID existente.
5. Coordenadas comerciais aprovadas da Pit Stop V8.

Pendências técnicas para liberação: separar remuneração do motoboy antes de ativar o novo frete, integrar push real, provisionar segredo do PIN, completar conferência por pedido no futuro app do entregador, homologar retry/revisão de proposta e PIX após reinício com backend/Rules, executar Rules em emulador com Java e testar mapas/permissões em dispositivos reais.

## DEPLOY NECESSÁRIO

Nenhum deploy realizado. Não foi feito commit ou push.

Após decisões e integrações, executar primeiro a homologação local/emulador das Rules e fluxos financeiros. Provisionar segredo do PIN, índices, Functions e Rules em ambiente de homologação, em conjunto com o cliente compatível e o canal de conta verificada. Validar permissões do superadmin e isolamento dos clientes/motoboys.

Publicar uma tabela somente com origem, preços e política aprovados. Ativar o modo por rota apenas depois de adapter real homologado e remuneração separada. Testar pedido antigo, PIX já emitido, dinheiro, cartão BR, bloqueio cartão PY, mudança de tabela e falha de rede. Definir plano de retorno ao modo legado antes de qualquer liberação de produção.

**AINDA EXISTEM BLOQUEADORES**
