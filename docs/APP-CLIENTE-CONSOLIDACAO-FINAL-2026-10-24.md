# App Cliente — consolidação final — 24/10/2026

Refinamento local concluído e validado: 164 testes Flutter completos e 41 testes Chrome aprovados; análise estática sem apontamentos; build Web release atualizado. Pronto para revisão humana e testes oficiais com as pendências externas abaixo declaradas. Não se declara prontidão de publicação enquanto a exclusão de conta e as homologações reais permanecerem pendentes.

## Inventário anterior às alterações desta etapa

Auditoria do código local e das sete telas oficiais em `design/references/customer_app/official/`, antes de alterar implementação. O workspace já contém trabalhos de Home, Splash e frete; sua preservação integra esta tarefa. Referências são visuais: não autorizam copiar valores, categorias bloqueadas, avaliações, prazo, GPS ou contatos ilustrativos. A restrição histórica do README a uma etapa de auditoria da Home é superada pela solicitação explícita atual de refinamento do app inteiro; a identidade e a estrutura aprovadas continuam preservadas.

| TELA/FUNCIONALIDADE | ESTADO ANTES | EVIDÊNCIA / REFINAMENTO NECESSÁRIO |
| --- | --- | --- |
| Splash | IMPLEMENTADO E PRONTO | Arte oficial, sequência finita, redução de movimento, erro/retry e restauração de sessão. Preservar. |
| Home/header/loja/destino/busca/carrinho | IMPLEMENTADO E PRONTO | `home_screen.dart`: endereço real, busca, moeda de exibição, badge, navegação e persistência. Preservar geometria aprovada. |
| Hero/promoções/mais pedidos | IMPLEMENTADO MAS PRECISA REFINAMENTO | Promoções/ranking dependem de dados reais. Fundo `commerce_backdrop.png` contém gelo e é aplicado a todo produto/oferta, inclusive Snacks e Conveniência. Corrigir associação visual sem gerar imagens/preços. |
| Categorias | IMPLEMENTADO E PRONTO | Mesmo stream do catálogo, cards com contagens reais, busca e filtros. Política comercial oculta itens/categorias incompatíveis. Grid interno é pequeno e não rolável; catálogo usa SliverGrid lazy. |
| Produto | IMPLEMENTADO MAS PRECISA REFINAMENTO | Modal com foto grande, nome/preço/descrição, quantidade e CTA; não expõe Oracle/PRO_CODIGO. Sem recomendações implementadas; não criar recomendações fictícias. Melhorar rótulo de disponibilidade/quantidade. |
| Imagens | IMPLEMENTADO MAS PRECISA REFINAMENTO | `ProductImage` possui loading/erro, mas placeholder é bebida para qualquer produto; base64 é decodificado a cada rebuild e não há limite de decodificação. |
| Carrinho | IMPLEMENTADO MAS PRECISA REFINAMENTO | Quantidade/remoção, subtotal/taxa/cotação, vazio e bloqueio já funcionam. SingleChildScrollView constrói todos os itens; refinar carregamento lazy, feedback e clareza do preview. |
| Checkout/frete/pagamentos | IMPLEMENTADO MAS PRECISA REFINAMENTO | Frete ponta a ponta homologado localmente, BR/PY, BRL contábil, moedas/troco, retries e proposta idempotente. Preservar lógica; melhorar somente apresentação de progresso/loading e mensagem de revisão pendente. |
| Confirmação de pedido | PARCIAL | Pagamento PIX tem estado aprovado, mas checkout navega direto a TrackingScreen. Falta momento de marca com número/resumo/status e CTA, condicionado à confirmação oficial do backend. |
| Acompanhamento | IMPLEMENTADO MAS PRECISA REFINAMENTO | Stream real, resumo, status, pagamento, chat/PIN. Linha do tempo com etapa extra de retirada; ausência de endereço vira `Centro - Ponta Porã`. Loading/erro/vazio secos. Não há mapa/GPS ou ETA real no fluxo cliente. |
| Chat e suporte por pedido | IMPLEMENTADO E PRONTO | Entrada vinculada ao pedido validado, unread e isolamento existentes. Não criar telefone de suporte nem contato do entregador. |
| PIN | IMPLEMENTADO E PRONTO | Máscara, revelar/ocultar, orientações e reset protegido existentes. Preservar. |
| Perfil | IMPLEMENTADO MAS PRECISA REFINAMENTO | Dados reais, provedor/DOB, endereço, pedidos, documentos e logout. FutureBuilder não apresenta loading contextual; erro tem retry sem explicação. Documentos de fallback são DRAFT explícitos. |
| Cadastro/onboarding/login/sessão | IMPLEMENTADO E PRONTO | Gate de sessão, vínculo de sessão anônima preexistente, consentimentos e documentos versionados. Não enfraquecer nem criar auth anônimo novo. Homologação dos provedores reais é externa. |
| Endereço/mapa | IMPLEMENTADO E PRONTO | Destino confirmado separado da posição do telefone, escolha manual/GPS, edição e gerenciamento de salvos. Fallback de centro de mapa não é rota financeira. |
| Histórico de pedidos | IMPLEMENTADO E PRONTO | Consulta por UID, limite/paginação, cards compartilhados e acesso ao tracking. Sem repetição automática de compra. |
| Exclusão da conta | AUSENTE | Não existe ação/contrato de exclusão no cliente/backend de identidade atual. Exige definição de retenção, reautenticação e execução segura; registrar como pendência real, não simular botão. |
| Loja aberta/fechada | IMPLEMENTADO MAS PRECISA REFINAMENTO | Regra 08:00–00:00 MS existente. Home atualiza a cada minuto; carrinho/checkout avaliam em build/callback, mas indicador pode ficar desatualizado se a tela permanecer parada na virada do horário. Refino de apresentação sem alterar cálculo de horário. |
| Erros/offline/recuperação | IMPLEMENTADO MAS PRECISA REFINAMENTO | Carrinho preservado, tentativas idempotentes, mensagens de PIX/frete/estoque/sessão sem expor exceções. Falta uniformizar estados visuais em tracking/perfil e explicar que falha de atualização não confirma cancelamento. |
| Identidade visual | IMPLEMENTADO E PRONTO | Tema claro oficial, amarelo/dourado, carvão, off-white, painéis e artes existentes. Dark mode não é oferecido no app atual. Não redesenhar as sete telas. |
| Performance | IMPLEMENTADO MAS PRECISA REFINAMENTO | Catálogo lazy e assinaturas estáveis; imagens base64/rebuilds e carrinho eager merecem correção. GIF de 18,7 MB existe em disco, mas não está no bundle declarado. Vídeo comercial existente 1,75 MB, sem benchmark em Android real nesta etapa. |
| Acessibilidade | IMPLEMENTADO MAS PRECISA REFINAMENTO | Tema com botões de 48 px, texto escalável e labels em vários controles; faltam labels de voltar/quantidade, anúncio de progresso e contraste consistente em textos cinza do tracking. |
| GPS/ETA/dados do entregador ao vivo | DEPENDE DE BACKEND/FUTURA VERSÃO | Sem integração real no app do motoboy. Não fabricar rota, prazo, placa, contato, avaliações nem posição. |
| Push real | DEPENDE DE BACKEND/FUTURA VERSÃO | Adaptador atual informa indisponibilidade; manter acompanhamento/chat dentro do app. |
| Termos finais, OAuth real e publicação | DEPENDE DE BACKEND/FUTURA VERSÃO | Exigem documentos e configuração operacional reais/homologação externa. Não consultar produção nesta tarefa. |

## Escopo de implementação derivado do inventário

Refinamentos limitados a apresentação, acessibilidade e custo de renderização: imagem/fundo coerente com categoria; estados de loading/erro/vazio; confirmação de marca a partir dos dados confirmados do pedido; progresso legível sem GPS/ETA inventados; clareza de loja fechada; lista lazy no carrinho; testes de regressão/pequenas telas/redução de movimento. Nenhuma nova forma de pagamento, cupom, favorito, recomendação, exclusão insegura ou funcionalidade grande será criada.

Frete, PIX, estoque, cálculos financeiros, regras de segurança e backend não devem mudar. A navegação da confirmação usará o mesmo pedido/stream do acompanhamento; apresentação de sucesso exige validação financeira oficial e PIX pago quando aplicável.

## Matriz final

"Pronto" abaixo significa verificado localmente para a jornada disponível. Não equivale à aprovação das lojas, de produção ou de pixels por revisão humana.

| TELA/FUNCIONALIDADE | ESTADO ANTES | ALTERAÇÃO | TESTES | ESTADO FINAL | PENDÊNCIA |
| --- | --- | --- | --- | --- | --- |
| Home | IMPLEMENTADO E PRONTO | Estrutura, header, hero, navegação e catálogo preservados; formatação monetária com vírgula; timer só reconstrói ao mudar abertura. | Home sprint, readiness, visual freeze, catálogo. | IMPLEMENTADO E PRONTO | Revisão humana das capturas com catálogo/fotos reais. |
| Categorias | IMPLEMENTADO E PRONTO | Preservadas navegação, busca, filtros e contagens reais; sem adicionar categorias comerciais. | Catálogo, sprint, freeze em 320–1440 px. | IMPLEMENTADO E PRONTO | Nenhuma funcional local identificada. |
| Cards/ofertas | IMPLEMENTADO MAS PRECISA REFINAMENTO | Fundo de gelo limitado às categorias explicitamente compatíveis; Snacks, Conveniência e categorias mistas usam gradiente carvão/dourado. Nenhuma alegação nova de temperatura. | Regressão de oferta sem gelo e Home sprint. | IMPLEMENTADO E PRONTO | Fotos/temperatura comercial continuam dependentes dos dados reais. |
| Produto | IMPLEMENTADO MAS PRECISA REFINAMENTO | Mantida disponibilidade explícita sem texto repetido; quantidade anunciada; foto grande, descrição, preços e CTA mantidos. Sem identificadores técnicos, personalizações ou recomendações fictícias. | Freeze, fluxo de produto e limites de estoque. | IMPLEMENTADO E PRONTO | Recomendações não existem no MVP; não adicionadas. |
| Imagens | IMPLEMENTADO MAS PRECISA REFINAMENTO | Placeholder neutro e rotulado; loading distinto de erro; provider/base64 reaproveitado por URL; decode dimensionado ao espaço/DPR, limitado a 1600 px. | Imagem inválida, componentes e capturas. | IMPLEMENTADO E PRONTO | Limite reduz decode/RAM, não reduz bytes baixados da origem. |
| Carrinho | IMPLEMENTADO MAS PRECISA REFINAMENTO | SliverList lazy; footer alcançável por scroll; vazio contextual, resumo e mensagem de conferência do total. Fórmulas, callbacks e cotação preservados. | 35 itens a 320 px/texto 1,6; readiness, freeze, frete. | IMPLEMENTADO E PRONTO | Nenhuma funcional local identificada. |
| Checkout | IMPLEMENTADO MAS PRECISA REFINAMENTO | Loading humano, proposta pendente rolável, erro de cotação responsivo e itens com moeda consistente; indicador de horário se atualiza. | Checkout/frete, BR/PY, teclado, PIX e freeze. | IMPLEMENTADO E PRONTO | Homologação operacional real do frete/pagamento continua externa. |
| Confirmação | PARCIAL | Momento de marca com número, resumo oficial, pagamento, estado inicial, endereço e CTA; fade/escala de 320 ms, dispensados com redução de movimento. | Novos casos de validação pendente/rejeitada, PIX não pago, cancelamento, atualizações do stream e texto ampliado. | IMPLEMENTADO E PRONTO | Aprovação visual humana; nenhuma confirmação simulada. |
| Tracking | IMPLEMENTADO MAS PRECISA REFINAMENTO | Quatro marcos oficiais, compatibilidade com Aguardando Retirada no marco de separação; progresso sem etapa concluída para status desconhecido. Erro/loading/vazio acionáveis; endereço ausente não vira endereço fictício. | Isolamento por UID/logout, tracking terminal, erros e novos testes. | IMPLEMENTADO E PRONTO | GPS/ETA real e dados completos do entregador dependem da integração. |
| Perfil | IMPLEMENTADO MAS PRECISA REFINAMENTO | Loading e erro contextual; retry recuperável; modal de saída rolável. Corrigido retorno de Future dentro de setState no retry/retorno de consentimento. | Perfil, componentes premium, jornada, recuperação e freeze. | IMPLEMENTADO E PRONTO | Exclusão da conta continua ausente. |
| Onboarding/login/sessão | IMPLEMENTADO E PRONTO | Nenhuma alteração em autenticação, vínculo de sessão anônima preexistente, consentimentos ou autorização. | Auth, Google login com doubles, flow e componentes. | IMPLEMENTADO E PRONTO | OAuth real, documentos finais e configurações externas não consultados. |
| Endereços/mapa | IMPLEMENTADO E PRONTO | Serviços e fluxo preservados. | Address flow, localização, componentes e estados. | IMPLEMENTADO E PRONTO | Permissões e mapa real precisam homologação em aparelhos. |
| Histórico/chat/PIN | IMPLEMENTADO E PRONTO | Contratos e ações preservados; tracking só usa chat de pedido real elegível. | Customer orders, order chat, notificações e componentes. | IMPLEMENTADO E PRONTO | Push real e integração do entregador fora desta etapa. |
| Loja aberta/fechada | IMPLEMENTADO MAS PRECISA REFINAMENTO | Carrinho/checkout atualizam apresentação a cada 30 s e ao retomar o app; só há rebuild quando o estado muda. Mensagem mantém catálogo disponível e informa abertura 08:00 MS. | Virada 23:59→00:00→08:00, retomada e readiness. | IMPLEMENTADO E PRONTO | Regra continua baseada no relógio cliente existente; não foi criada regra de horário nova no servidor. |
| Erros/offline | IMPLEMENTADO MAS PRECISA REFINAMENTO | Feedback com ícone/texto/retry, sem detalhe de SDK; erro de atualização não é apresentado como cancelamento; carrinho preservado. | Falhas de cotação, sessão, perfil, tracking, PIX e tentativas de pedido. | IMPLEMENTADO E PRONTO | Sem modo de compra offline; pedidos exigem confirmação de servidor. |
| Visual | IMPLEMENTADO E PRONTO | Identidade oficial preservada, sem redesenho completo ou novas artes. Gradiente neutro substitui gelo inadequado. | Capturas das sete telas e novos estados. | IMPLEMENTADO E PRONTO | Revisão humana; não se declara fidelidade pixel a pixel aprovada. |
| Performance | IMPLEMENTADO MAS PRECISA REFINAMENTO | Carrinho lazy, base64 por URL, decode limitado, backdrop redimensionado e timer de Home sem rebuild incondicional. | Lista longa, imagens e regressões. | IMPLEMENTADO E PRONTO | FPS/memória em Android intermediário não medidos; otimização de payload de imagens depende da origem. |
| Acessibilidade | IMPLEMENTADO MAS PRECISA REFINAMENTO | Labels de imagem/quantidade/voltar, live regions de status, texto além de cor, cinza legível no tracking, scroll e redução de movimento. | Toque CTA ≥48 px, 320 px/texto 1,6; Home até 2,0; teclado/SafeArea e contraste dos tokens. | IMPLEMENTADO E PRONTO | TalkBack/VoiceOver e contraste sobre fotos reais precisam revisão em aparelho. |
| Dark mode | AUSENTE | Mantido tema claro oficial, inclusive quando SO usa aparência escura. Não criada segunda identidade. | AppTheme/lightTheme e layouts existentes. | DEPENDE DE BACKEND/FUTURA VERSÃO | Decisão de produto futura; não prometido no MVP. |
| Exclusão de conta | AUSENTE | Nenhum botão falso ou exclusão parcial foi criado. | Inventário de auth/perfil/backend. | AUSENTE | Definir e implementar exclusão segura/retenção/reautenticação antes de publicar. |
| GPS/ETA/push real | DEPENDE DE BACKEND/FUTURA VERSÃO | Nenhum dado fabricado; acompanhamento explica ausência de posição ao vivo. | Tracking e notificações indisponíveis. | DEPENDE DE BACKEND/FUTURA VERSÃO | App do motoboy, integração de eventos/localização, notificações e homologação. |

## Preservação dos fluxos homologados

- `tool/app_cliente_final/preservation.json` verifica SHA-256 de 55 arquivos de Functions, Rules e serviços/modelos sensíveis: nenhum mudou em relação ao início desta etapa. A comparação do checkout antes de `_summaryLine`, normalizando apenas espaços, dois imports de UI e três flags de navegação `showConfirmation`, também permaneceu idêntica.
- Nenhum cálculo de subtotal, taxa, conversão BRL/PYG/USD, troco, frete, faixa ou financeiro foi alterado. A troca de ponto por vírgula é exclusivamente apresentação.
- As três navegações existentes do checkout continuam usando o mesmo ID e o mesmo `TrackingScreen`. A flag nova solicita apresentação da confirmação. O stream real só libera o momento de sucesso com `financialValidationStatus: validated`, pagamento PIX `Pago` quando indicado por flag ou método, e status operacional conhecido e não cancelado/em revisão.
- Recebimento da escrita de proposta, falha, revisão ou PIX pendente não gera celebração. O CTA apenas passa ao acompanhamento do mesmo pedido; não escreve pedido, pagamento, estoque nem financeiro e não cria cobrança. Após o CTA, atualizações do stream não repetem a confirmação.
- A atribuição/nome do entregador continuam condicionados aos campos reais. Endereço/total ausentes são informados como ausentes/em confirmação. Não foi acrescentado mapa, cronômetro, promessa de prazo ou contato fictício.
- `RegistrationScreen`, telas administrativas e `RealWebMap` são arquivos legados sem importação na jornada oficial do cliente. O mapa ilustrativo legado não foi ligado ao tracking nem ao frete. A navegação de produção continua passando pelo gate oficial de sessão.

## Chamaê Delight aplicado

O cliente recebe feedback imediato ao alterar a sacola; a adição conserva o haptic existente. A confirmação usa uma animação finita curta, sem confete, som, atraso artificial, autoplay novo ou permissão adicional. Redução de movimento elimina essa animação. Botões reais e estados vazios substituem expectativas vagas; o progresso de entrega é ligado aos estados recebidos, sem GPS/ETA inventados.

O checkout normal mantém destino/contato já conhecidos compactos e editáveis; sem nova etapa de formulário ou autenticação. Erros mostram um caminho de recuperação. Foi comprovado e corrigido overflow no banner de falha de frete com texto ampliado; a cotação e o callback de retry continuam os mesmos.

## Performance e acessibilidade verificadas

Não foram encontrados assets exatamente duplicados por SHA-256 em `assets/images`. O GIF legado de 18,7 MB não é declarado no bundle; ele não foi adicionado ao app. O vídeo comercial existente de 1,75 MB foi preservado. Nenhuma dependência, SDK de coleta ou permissão nova foi incluída.

Contraste matemático dos tokens verificados: dourado escuro sobre off-white **5,28:1**, texto secundário sobre off-white **5,42:1**, carvão sobre amarelo **12,18:1**. Evidência: `tool/app_cliente_final/assets-contrast.json`. Isso não é uma certificação global de acessibilidade: fotos, vídeos, leitores de tela e performance de hardware continuam exigindo homologação real.

## Evidência visual

Foram geradas 63 capturas com fixtures locais em `tool/app_cliente_final/captures`, incluindo 320/360/390/430/768/1440 px, texto ampliado, teclado, estados de erro e confirmação. As capturas das sete telas oficiais foram inspecionadas como apresentação local; produtos/preços de teste não representam configuração comercial. Nenhum JPEG oficial foi editado.

Capturas selecionadas, com dados exclusivamente de teste: [Home](app_cliente_final_2026-10-24/home.png), [Categorias](app_cliente_final_2026-10-24/categorias.png), [Produto](app_cliente_final_2026-10-24/produto.png), [Carrinho](app_cliente_final_2026-10-24/carrinho.png), [Checkout](app_cliente_final_2026-10-24/checkout.png), [Confirmação](app_cliente_final_2026-10-24/confirmacao.png), [Tracking](app_cliente_final_2026-10-24/tracking.png), [Progresso](app_cliente_final_2026-10-24/tracking-progresso.png), [Perfil](app_cliente_final_2026-10-24/perfil.png).

Na revisão das capturas, foram removidas a repetição do texto de disponibilidade no produto e a indicação de atribuição pendente quando o pedido já saiu, terminou ou possui estado desconhecido sem dados de entregador. Esses estados agora informam a ausência do entregador, preservando os dados reais quando disponíveis. O diff isolado desta etapa nos sete arquivos preexistentes está em `tool/app_cliente_final/own-changes.diff`; os componentes e testes novos constam no status do workspace. Alterações anteriores de outras tarefas não foram revertidas.

## Validação final

As execuções iniciais identificaram e permitiram corrigir: const indevido em Semantics; retry do perfil retornando Future dentro de setState; overflow do erro de cotação; e finders de teste que precisavam aguardar layout/rolar até itens lazy. O teste de privacidade de pedidos passou a esperar vírgula decimal, preservando todas as asserções de isolamento/logout. Não foram desabilitadas asserções de overflow, visibilidade, confirmação ou segurança.

Os comandos Flutter usam o SDK já instalado e acesso autorizado aos seus caches. A consulta de atualização/telemetria do SDK foi suprimida nos comandos finais, e as verificações foram sequenciadas após disputa do startup lock. Testes não inicializam Firebase real; usam repositórios/doubles e dados sintéticos. O aviso de vídeo não implementado no runner VM é esperado e exercita o fallback existente.

| VERIFICAÇÃO | RESULTADO | EVIDÊNCIA |
| --- | --- | --- |
| Suíte Flutter completa, com readiness/visual freeze | **164 testes aprovados**, zero falhas, após os últimos ajustes | `tool/app_cliente_final/flutter-final-review.log` |
| Chrome/Web relevante | **41 testes aprovados**, zero falhas | `tool/app_cliente_final/chrome-approved.log` |
| Flutter analyze completo | **Sem apontamentos**; saída 0, execução final em 19,8 s | `tool/app_cliente_final/analyze-final-review.log` |
| Build Web release | **Aprovado**, saída 0; artefato atualizado em `build/web`, compilação em 113,2 s; Wasm dry run também passou | `tool/app_cliente_final/build-web-final-review.log` |
| Preservação de serviços, backend e regras | 55 hashes preservados; fluxo do checkout antes da apresentação preservado | `tool/app_cliente_final/preservation.json` |
| Capturas finais | 63 geradas; 9 selecionadas no relatório | `tool/app_cliente_final/captures` e `docs/app_cliente_final_2026-10-24` |

Chrome executou `app_client_final_test.dart`, `checkout_web_test.dart`, `checkout_delivery_contract_test.dart`, `delivery_quote_state_test.dart`, `home_visual_sprint_test.dart` e `pix_payment_presentation_test.dart`. Cobriu confirmação, recuperação, perfil, lista longa, Home, limites de estoque, cotação inválida/fora da cobertura/troca de destino, BRL/PIX, texto ampliado e layout. Brasil/Paraguai e moedas/troco continuam também na suíte completa de readiness/fluxos.

Foi usado o runner-fonte do SDK para contornar o snapshot que referencia `host.dart.js` no caminho da máquina de build do Flutter. O auxiliar preexistente `tool/chrome_test_assets.mjs` entregou somente CanvasKit do SDK ao navegador local via CDP, com validação de origem/caminho. Não altera o SDK, o app ou as asserções; encerra junto do navegador. Não foi utilizado Firebase real para executar o build ou os testes.

Comandos finais: `flutter --no-version-check --suppress-analytics analyze --no-pub`; `flutter --no-version-check --suppress-analytics test --no-pub --dart-define=VISUAL_FONT_PATH=C:/flutter/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf --dart-define=CAPTURE_VISUAL=true --dart-define=VISUAL_CAPTURE_DIR=tool/app_cliente_final/captures --reporter expanded`; `flutter --no-version-check --suppress-analytics build web --release --no-pub`. No Chrome, o mesmo comando de teste foi iniciado por `dart --packages=C:\flutter\packages\flutter_tools\.dart_tool\package_config.json C:\flutter\packages\flutter_tools\bin\flutter_tools.dart`, com `--platform chrome` e os seis arquivos acima.

## Pendências reais para homologação/publicação

1. Revisão humana das telas e testes oficiais em Android intermediário e iPhone, com teclado, TalkBack/VoiceOver, latência, consumo de memória/FPS e catálogo/fotos reais.
2. Exclusão de conta ainda não implementada: exige desenho seguro, retenção/reautenticação e backend adequado. Esta tarefa não simula nem declara esse recurso concluído.
3. Verificar no ambiente apropriado OAuth Google/Apple e documentos finais/consentimentos; seu estado real não foi consultado. Preservado o vínculo de sessão anônima preexistente, sem criar login anônimo novo.
4. Homologar a configuração real de frete/origem Pit Stop V8/Google Routes e os pagamentos/estoque integrados no ambiente autorizado. Esta auditoria de UX não publica ou substitui a configuração financeira recém-validada.
5. GPS/ETA de rota, placa/contato/avaliação do motoboy e push não são inventados no MVP. Dependem de integrações e dados reais, além das decisões de produto. Chat por pedido e PIN existentes permanecem disponíveis conforme autorização.

## Acessos e operações

FIREBASE PRODUÇÃO: não acessado. ORACLE/GRANDCHEF: não acessado. COMMIT: não realizado. PUSH: não realizado. DEPLOY: não realizado. Após concluir as verificações locais, parar para revisão humana.
