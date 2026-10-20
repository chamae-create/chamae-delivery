# Chamaê — Visual freeze com referências oficiais

Data: 20/10/2026. Projeto: `C:\Users\DELL\chamae_delivery`.

## Referências e precedência

Foram lidos o README e as sete imagens de `design/references/customer_app/official/` antes de editar as telas. Elas orientaram a apresentação; os dados continuam vindo das fontes e contratos existentes.

Não foram importados preços, fretes, estimativas, clientes, contatos, placas, avaliações, produtos ou contagens das imagens. Nenhuma categoria comercialmente bloqueada foi acrescentada. Os arquivos de referência foram preservados.

## Auditoria e aplicação por tela

| Tela | Diferenças encontradas | Ajustes aplicados |
|---|---|---|
| Home | Header e navegação escuros; atalhos pretos; banner pequeno; superfícies com bordas frias. | Header off-white com logo, destino, carrinho e moeda; navegação clara; atalhos claros; banner proporcional; área clara com gradiente para as fotos dos cards; dimensões adaptadas ao texto ampliado. |
| Categorias | O destino da navegação apenas reposicionava os filtros horizontais. | Visão de categorias com cards em carvão e dourado, imagem do catálogo, contagem calculada e acesso ao filtro existente. Busca por categoria ou produto; sem duplicar a assinatura do catálogo. |
| Produto | Foto pequena e pouca hierarquia entre nome, preço e ações. | Sheet com largura limitada no desktop, foto maior em painel claro, preço dourado, total da quantidade selecionada e respiros maiores. Quantidade, estoque e callbacks mantidos. |
| Carrinho | Fotos pequenas; resumo sem agrupamento; conteúdo abaixo da dobra de difícil acesso. | Fotos maiores, totais destacados, cabeçalhos e resumo em painel. Remover item, alterar quantidade, cotação e bloqueios de continuação mantidos. |
| Checkout | Pouco destaque para os itens e escolhas; resumos estouravam em telas estreitas. | Fotos dos itens, hierarquia de seções, seleção de pagamento dourada, bordas quentes e resumo com quebra de linha. Nome, quantidade e total dos itens passam a caber com texto ampliado. |
| Acompanhamento | Status apresentado como texto simples; pouco destaque para o pedido. | Hero em carvão/dourado com status e identificador reais, linha do tempo com destaque dourado, painéis claros e resumo adaptável à largura. Todos os estados existentes, PIX, chat, PIN e notificações preservados. |
| Perfil | Apresentação simples, com ícone solto e lista sem identidade visual. | Hero de identificação com os dados disponíveis, seção de conta, opções em superfícies claras e ícones dourados. Login, endereço, histórico, documentos, PIN e saída preservados. |

Splash, Login, Onboarding, Endereço, Mapa, PIX e Chat seguem usando o tema compartilhado. Seus serviços, navegação de negócio e regras de acesso não foram reescritos. Os testes existentes desses fluxos integram a validação de regressão.

## Design system

- Fundo off-white `#FAF7F0`, carvão `#141414` e texto `#191816`.
- Amarelo Chamaê `#FFCC00`; dourado de texto `#886000` para contraste em superfícies claras.
- Bordas quentes `#ECE2CF`, cartões claros, sombras discretas e raios de 12/20/28 px.
- Hierarquia tipográfica com títulos fortes e corpo secundário de cor neutra.
- `CustomerVisual`, `CustomerSectionTitle` e `CustomerHero` centralizam painéis, espaçamento, gradientes e cabeçalhos.
- O painel principal continua limitado a 440 px no app. O `MediaQuery` interno agora recebe a dimensão efetiva desse painel, evitando cálculos pela largura total do navegador.
- Grids, modais e páginas também foram exercitados isoladamente em larguras maiores. Botões mantêm seus estados desabilitados e alvos de toque existentes.
- O vídeo comercial existente foi preservado. No carregamento ou erro, uma arte já existente (`splash_bg.png`) mantém o banner visualmente preenchido. Nenhuma arte das referências foi usada como tela ou imagem de produto.

## Decisões de compatibilidade

A navegação inferior mantém o acesso adicional ao Carrinho, além de Início, Categorias, Pedidos e Perfil. Ofertas continuam acessíveis no atalho da Home. O seletor de moeda existente permanece no header.

Não foram criados favoritos, avaliações, cupons, personalizações de produto, meios de pagamento, contatos de entregador ou mapa ilustrativo para imitar controles das imagens sem suporte funcional existente. Nenhuma promessa de prazo ou disponibilidade foi inserida.

Categorias e contagens usam apenas o catálogo permitido pela política comercial existente. O modal de produto continua consultando disponibilidade e respeitando as mesmas limitações de estoque. Os campos e ramos BR/PY do checkout permanecem condicionados pelas regras originais.

## Preservação e rastreabilidade

O repositório já continha alterações e arquivos não rastreados antes desta tarefa. Eles não foram revertidos. As versões anteriores dos arquivos editados foram preservadas em `tool/visual_freeze/before/`, com extensão `.before` para não interferir no analisador.

`tool/visual_freeze/preservation_final.json` registra a comparação SHA-256 de 75 arquivos funcionais: nenhum mudou. A verificação inclui serviços de cliente, modelos, política comercial, estoque/validação, horários, Firebase, Rules, Functions, mapa, PIN, PIX e entrada do chat. A lógica do estado do checkout anterior ao método de apresentação foi comparada com a baseline, ignorando apenas espaços: sem diferenças.

O diff específico deste trabalho está em `tool/visual_freeze/visual_changes.diff`. Ele compara com a baseline desta sessão, separando estes ajustes das alterações anteriores do usuário.

Arquivos de implementação editados/criados:

- `lib/core/theme.dart`
- `lib/main.dart` — dimensão do painel no `MediaQuery`.
- `lib/widgets/customer_visual.dart`
- `lib/widgets/sponsor_video_banner.dart`
- `lib/screens/home_screen.dart`
- `lib/screens/cart_screen.dart`
- `lib/screens/checkout_screen.dart`
- `lib/screens/tracking_view.dart`
- `lib/screens/customer_profile_screen.dart`
- `pubspec.yaml` — declaração da arte visual já existente.
- `test/customer_visual_freeze_test.dart`

## Validação

| Validação | Resultado | Evidência |
|---|---|---|
| `flutter test --reporter expanded` | 112 testes aprovados | `tool/visual_freeze/flutter_test_final.log` |
| Teste visual com captura e fonte local do SDK | 10 cenários aprovados; 35 capturas geradas | `tool/visual_freeze/capture_final.log` |
| `flutter analyze` | Sem apontamentos | `tool/visual_freeze/analyze_final.log` |
| `flutter build web --release` | Build concluído | `tool/visual_freeze/build_web_release_final.log`, `build/web/` |
| `flutter build apk --debug` | Build concluído | `tool/visual_freeze/build_apk_debug_final.log`, `build/app/outputs/flutter-apk/app-debug.apk` |

Os builds emitiram mensagens informativas de Wasm e avisos de toolchain Java/Kotlin, sem impedir a compilação. Não foram feitas mudanças de dependências, SDK, plugins ou configuração Android para tratar esses avisos.

Uma tentativa adicional de `flutter test --platform chrome test/checkout_web_test.dart test/checkout_delivery_contract_test.dart` permaneceu na etapa de carregamento e foi interrompida sem resultado conclusivo. Não foi contabilizada como aprovação de testes em navegador. O log está em `tool/visual_freeze/chrome_test_final.log`; a revisão de comportamento real no navegador continua parte da homologação.

O teste novo cobre Home, Categorias, Produto, Carrinho, Checkout, Perfil e Acompanhamento, com larguras de 320, 390, 430, 768 e 1440 px e texto em escala 1,0 e 1,6. Valida alternância entre categorias e produto, exclusão de categorias bloqueadas, nomes longos e ausência de exceções de layout. A suíte existente também cobre Home em 320 px com texto 2,0 e área segura inferior.

Problemas identificados durante a execução foram corrigidos: altura da navegação com texto ampliado, assinatura do catálogo ao alternar telas, enquadramento do preço no card, quebra de linhas dos totais e composição dos itens no checkout. Backups de código foram isolados da análise Dart.

Foram geradas 35 capturas de componentes com dados sintéticos, fonte legível e ícones locais em `tool/visual_freeze/screenshots/`. Há uma captura de cada uma das sete telas por largura, em escala 1,0. As capturas foram inspecionadas visualmente. Não são sessões autenticadas nem evidência de fotos ou entregas de produção; itens sem foto usam o placeholder existente. O vídeo não é reproduzido no teste VM, que exercita o fallback visual.

Exemplos em 390 px:

- [Home](../tool/visual_freeze/screenshots/home_390.0.png)
- [Categorias](../tool/visual_freeze/screenshots/categories_390.0.png)
- [Produto](../tool/visual_freeze/screenshots/product_390.0.png)
- [Carrinho](../tool/visual_freeze/screenshots/cart_390.0.png)
- [Checkout](../tool/visual_freeze/screenshots/checkout_390.0.png)
- [Perfil](../tool/visual_freeze/screenshots/profile_390.0.png)
- [Acompanhamento](../tool/visual_freeze/screenshots/tracking_390.0.png)

## Limites da homologação

A aprovação estética final deve conferir uma sessão autenticada com catálogo e fotografias reais, reprodução do vídeo e os estados vivos de pedido/entregador em navegador e dispositivo Android. Os testes com fixtures e os builds não substituem essa revisão. Os layouts foram aproximados às referências mantendo os recursos e dados efetivamente suportados pelo app; não há alegação de reprodução pixel a pixel.

Não houve deploy, commit ou push. Nenhuma configuração de Auth, Maps, Routes, frete, estoque, pagamento, Firebase, Rules, Functions, PIN, política BR/PY ou horário foi alterada.

IDENTIDADE VISUAL PRONTA PARA HOMOLOGAÇÃO
