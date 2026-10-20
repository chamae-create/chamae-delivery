# Chamaê — Homologação visual por capturas

Data: 20/10/2026. Projeto: `C:\Users\DELL\chamae_delivery`.

**Resultado: homologação parcial dos layouts; homologação integral pendente.** As imagens originais foram geradas por testes de widgets com fixtures. Elas não demonstram uma sessão autenticada do app com catálogo, fotos, pagamentos e entrega reais. O freeze anterior estava pronto para entrar em homologação; esta revisão não transforma essa preparação em aprovação integral.

As sete referências e o README de `design/references/customer_app/official/` foram consultados. As regras funcionais e comerciais prevaleceram. Não houve redesign amplo, deploy, instalação de APK no aparelho, commit ou push.

**CAPTURAS ANALISADAS**

As 35 imagens originais foram localizadas em `tool/visual_freeze/screenshots/`, inspecionadas individualmente e preservadas. Cada arquivo tem 1000 px de altura, com larguras de 320, 390, 430, 768 e 1440 px. Os nomes identificam as telas; não há necessidade de renomeá-las.

| Tela / referência oficial | 320 px | 390 px | 430 px | 768 px | 1440 px |
|---|---|---|---|---|---|
| Home — `02_home_reference.jpeg` | [home_320.0.png](../tool/visual_freeze/screenshots/home_320.0.png) | [home_390.0.png](../tool/visual_freeze/screenshots/home_390.0.png) | [home_430.0.png](../tool/visual_freeze/screenshots/home_430.0.png) | [home_768.0.png](../tool/visual_freeze/screenshots/home_768.0.png) | [home_1440.0.png](../tool/visual_freeze/screenshots/home_1440.0.png) |
| Categorias — `01_categories_reference.jpeg` | [categories_320.0.png](../tool/visual_freeze/screenshots/categories_320.0.png) | [categories_390.0.png](../tool/visual_freeze/screenshots/categories_390.0.png) | [categories_430.0.png](../tool/visual_freeze/screenshots/categories_430.0.png) | [categories_768.0.png](../tool/visual_freeze/screenshots/categories_768.0.png) | [categories_1440.0.png](../tool/visual_freeze/screenshots/categories_1440.0.png) |
| Produto — `06_product_reference.jpeg` | [product_320.0.png](../tool/visual_freeze/screenshots/product_320.0.png) | [product_390.0.png](../tool/visual_freeze/screenshots/product_390.0.png) | [product_430.0.png](../tool/visual_freeze/screenshots/product_430.0.png) | [product_768.0.png](../tool/visual_freeze/screenshots/product_768.0.png) | [product_1440.0.png](../tool/visual_freeze/screenshots/product_1440.0.png) |
| Carrinho — `03_cart_reference.jpeg` | [cart_320.0.png](../tool/visual_freeze/screenshots/cart_320.0.png) | [cart_390.0.png](../tool/visual_freeze/screenshots/cart_390.0.png) | [cart_430.0.png](../tool/visual_freeze/screenshots/cart_430.0.png) | [cart_768.0.png](../tool/visual_freeze/screenshots/cart_768.0.png) | [cart_1440.0.png](../tool/visual_freeze/screenshots/cart_1440.0.png) |
| Checkout — `04_checkout_reference.jpeg` | [checkout_320.0.png](../tool/visual_freeze/screenshots/checkout_320.0.png) | [checkout_390.0.png](../tool/visual_freeze/screenshots/checkout_390.0.png) | [checkout_430.0.png](../tool/visual_freeze/screenshots/checkout_430.0.png) | [checkout_768.0.png](../tool/visual_freeze/screenshots/checkout_768.0.png) | [checkout_1440.0.png](../tool/visual_freeze/screenshots/checkout_1440.0.png) |
| Tracking — `05_tracking_reference.jpeg` | [tracking_320.0.png](../tool/visual_freeze/screenshots/tracking_320.0.png) | [tracking_390.0.png](../tool/visual_freeze/screenshots/tracking_390.0.png) | [tracking_430.0.png](../tool/visual_freeze/screenshots/tracking_430.0.png) | [tracking_768.0.png](../tool/visual_freeze/screenshots/tracking_768.0.png) | [tracking_1440.0.png](../tool/visual_freeze/screenshots/tracking_1440.0.png) |
| Perfil — `07_profile_reference.jpeg` | [profile_320.0.png](../tool/visual_freeze/screenshots/profile_320.0.png) | [profile_390.0.png](../tool/visual_freeze/screenshots/profile_390.0.png) | [profile_430.0.png](../tool/visual_freeze/screenshots/profile_430.0.png) | [profile_768.0.png](../tool/visual_freeze/screenshots/profile_768.0.png) | [profile_1440.0.png](../tool/visual_freeze/screenshots/profile_1440.0.png) |

`tool/visual_homologation/original_capture_inventory.json` registra nomes, tamanhos e SHA-256. A comparação confirmou que os 35 originais não foram alterados.

Novas evidências foram geradas separadamente: 44 capturas após correções e 15 complementares, além dos 35 originais.

- `tool/visual_homologation/after/`: repetição das sete telas nas cinco larguras originais, mais 360×640, com capturas adicionais dos rodapés do Produto e Tracking em 360 px.
- `tool/visual_homologation/supplementary/`: Splash/loading e erro; Login inicial e erro; Onboarding inicial e rodapé; Endereço sem salvos; Perfil/rodapé; Home vazia, erro e loading; Carrinho vazio; Tracking indisponível, erro e loading.
- As capturas complementares usam widgets reais do projeto alimentados por fixtures. Mapa, PIX e Chat não passaram a ter evidência visual integrada por causa desses testes.
- As telas de 768/1440 px são componentes isolados. O app completo conserva seu painel de até 440 px; essas imagens não aprovam o enquadramento do app real no desktop.

Comparação por tela, incluindo composição, hierarquia, cores, fonte, espaços, radius, sombras, alinhamento, proporções, ícones, CTAs, header e navegação:

| Tela | Avaliação visual e limites |
|---|---|
| Home | Off-white, carvão, amarelo, cards claros e CTA preservados. Logo/endereço/horário/carrinho continuam no header; o horário usa a regra existente. Banner apresenta o vídeo existente ou a arte de fallback. Ícone com glifo ausente e textos de atalhos/chips foram corrigidos. A referência tem blocos comerciais separados de promoções e mais pedidos; o app mantém atalhos/filtros e uma grade de destaque. As fixtures não validam fotos ou ofertas reais. |
| Categorias | Busca, chips horizontais e grade funcionam com os mesmos filtros. Cards escuros, bordas douradas, títulos brancos e setas são consistentes. Rótulos ficaram maiores e com duas linhas. As fotos são placeholders nas fixtures; contagens vêm dos dados de teste. Categorias bloqueadas continuam excluídas. |
| Produto | Foto em painel claro, nome forte, preço dourado, quantidade, descrição, total e CTA legíveis. Em 360×640 é necessário rolar para ver o CTA inteiro; acesso e área segura foram testados. A referência usa um hero mais rico e recomendações/opções/observações; não foram acrescentados controles sem suporte funcional existente. Fotografia real e combinações reais de conteúdo permanecem pendentes. |
| Carrinho | Itens, quantidade, preço unitário e total do item são legíveis; subtotal/serviço/entrega/CTA mantêm os contratos existentes. Foi corrigida a coluna de valores e o encontro visual entre rótulo e valor em 320 px. Espaçamento, cards e sombras estáveis foram preservados. Nenhum cupom, desconto ou prazo fictício foi inserido. |
| Checkout | Endereço, lista de produtos, seleção de pagamento, resumo e CTA permanecem na mesma sequência. Valores passaram a terminar na mesma margem direita. Nome/telefone e CTA foram exercitados com teclado simulado. Cartão continua condicionado a BR; PY preserva as opções existentes. O recorte das capturas pode começar após o endereço devido ao scroll do teste. |
| Tracking | Status atual forte em carvão/dourado; timeline vertical mantém cinco estados reais, inclusive aguardando retirada. Informação ausente do entregador não é mais apresentada como atribuição pendente em pedido encerrado. O snapshot original contém apenas pedido concluído, sem mapa, rota ou entregador real. A timeline horizontal e o mapa da referência não foram simulados com dados inventados. |
| Perfil | Dados disponíveis, endereço, pedidos, PIN, documentos e saída permanecem acessíveis por scroll. Hero simples, cards claros e ícones são consistentes com o freeze. A referência tem composição fotográfica e atalhos em duas colunas; a lista estável não foi refeita por preferência estética. A captura de rodapé mostra o estado da fixture sem serviço de autenticação, com saída desabilitada. Sessão real e dados longos reais exigem revisão integrada. |

**DIFERENÇAS CRÍTICAS**

Não foi confirmado defeito visual crítico restante nas capturas inspecionadas e nos cenários de layout aprovados. Isso não cobre a execução física da versão atual nem estados integrados sem captura.

Os testes intermediários identificaram excesso de altura após aumentar os rótulos. O ajuste de categorias recebeu espaço suficiente; a navegação inferior voltou à tipografia estável do freeze para preservar seu comportamento com texto 2,0. Não ficou um overflow conhecido desses ajustes nos testes finais.

**DIFERENÇAS IMPORTANTES**

| ID | Diferença | Situação |
|---|---|---|
| I-01 | Carrinho e Checkout: valores sem terminação na mesma margem; rótulo e valor visualmente próximos em 320 px. | Corrigida, sem alterar cálculos. |
| I-02 | Home/Categorias: rótulos pequenos e truncamento dos títulos dos atalhos em largura compacta. | Corrigida: chips maiores, duas linhas e altura compatível com texto ampliado. Subtítulos auxiliares ainda podem usar reticências. |
| I-03 | Busca: placeholder com contraste baixo. | Corrigida para a cor secundária do design system. |
| I-04 | Tracking concluído/cancelado sem nome: texto sugeria atribuição ainda pendente. | Corrigida para “Entregador não informado”, sem criar nome, contato ou placa. |
| I-05 | Home: composição comercial mais simples que a referência, sem seções separadas de promoções e mais pedidos. | Registrada; reorganização comercial ampla não foi feita nesta revisão. Requer decisão visual sobre o layout já existente e dados reais. |
| I-06 | Imagens de produto ausentes nas fixtures; vídeo usa fallback no teste VM. | Pendente evidência com mídia real. Não foi classificado como falha comprovada do carregamento em produção. |
| I-07 | Falta de capturas integradas de PIX, Chat, Mapa e tracking ativo com dados reais. | Pendente; bloqueia a homologação integral desses fluxos. |
| I-08 | NUU M2 está conectado com instalação anterior ao freeze e tela apagada. | Pendente execução da versão atual no hardware. Não houve instalação nesta tarefa. |

**DIFERENÇAS COSMÉTICAS**

- C-01 — Emoji de fogo sem glifo na Home: substituído por ícone Material já existente no app.
- C-02 — As referências têm brilho/gradiente mais intenso nos CTAs; os botões dourados estáveis foram mantidos.
- C-03 — O logo existente tem fundo preto; não foi recortado ou redesenhado para imitar o logo da referência.
- C-04 — Há diferenças de radius entre cards de produto, painéis e modais, conforme seus componentes existentes; não motivaram refatoração global.
- C-05 — A navegação mantém o acesso adicional ao Carrinho. Quantidade de destinos e acesso existentes foram preservados.

**CORREÇÕES APLICADAS**

| Arquivo | Alteração restrita |
|---|---|
| `lib/screens/home_screen.dart` | Ícone de destaque; cor do placeholder; títulos de atalhos em duas linhas; chips de 100 px, texto de 11 px e espaço para duas linhas. Navegação estável preservada. |
| `lib/screens/cart_screen.dart` | Espaço explícito entre rótulo e valor e expansão da coluna de valores para alinhamento à direita. |
| `lib/screens/checkout_screen.dart` | Coluna de valores do resumo expandida e alinhada à direita. |
| `lib/screens/tracking_view.dart` | Mensagem visual coerente quando não há entregador informado em pedido encerrado. |
| Testes visuais | Captura aguarda decodificação das imagens; saída configurável para preservar originais; cenários de 360×640, barras do sistema, teclado, rodapés e estados complementares. |

Não foram modificados tema global, composição das telas estáveis, Auth, Maps, Routes, cotação, estoque, pagamento, Firebase, Rules, Functions, PIN, política BR/PY ou horários. Os 75 arquivos funcionais monitorados continuam com os mesmos hashes. Baseline em `tool/visual_homologation/before/`, diff em `tool/visual_homologation/changes.diff` e evidência em `tool/visual_homologation/preservation.json`.

**TELAS APROVADAS**

Aprovação limitada à apresentação dos estados capturados e ao layout simulado:

- Home/Categorias: legibilidade dos controles, busca, chips e navegação, com a ressalva I-05 de composição comercial e I-06 de mídia real.
- Produto: nome, preço, quantidade, descrição e acesso ao CTA por scroll.
- Carrinho e Checkout: alinhamento, hierarquia dos resumos, leitura de valores e acesso aos controles.
- Tracking encerrado: status, timeline e comunicação de ausência de informação.
- Perfil: estrutura, PIN/documentos existentes e acesso ao rodapé por scroll.
- Splash, Login, Onboarding e Endereço sem salvos: consistência das capturas complementares de 360 px, com fixtures.
- Vazio/erro/loading capturados: mensagens legíveis, estados de espera e tentativas de recuperação onde já existentes.

Essas aprovações não equivalem a aprovação visual ponta a ponta de uma sessão de produção.

**TELAS PENDENTES**

| Tela/fluxo | Evidência ainda necessária |
|---|---|
| Home/Categorias/Produto | Catálogo e fotos reais, ofertas e mais vendidos reais; decisão sobre diferenças de composição I-05. |
| Carrinho/Checkout | Sessão real com endereço confirmado e cotação; cenários visuais BR/PY e teclado real. Testes de contrato não substituem as capturas integradas. |
| PIX | Tela de pagamento e estados reais/ambiente autorizado de criação, espera, confirmação e falha, sem efetuar pagamento nesta revisão. |
| Tracking/Mapa | Pedido ativo com dados verdadeiros, mapa/rota disponíveis, atribuição do entregador e seus estados. Nenhum trajeto, previsão ou contato fictício foi exibido. |
| Chat | Conversa, estados vazio/erro e teclado com sessão autorizada; sem enviar mensagens nesta tarefa. |
| Perfil e entrada | Sessão autenticada, dados reais e estado habilitado de saída; login/onboarding/endereço integrados. Capturas complementares usam fixtures. |
| Android pequeno | A mesma versão aprovada por build em NUU M2/API 24 com tela ativa, IME real, scroll, toque, barras e desempenho. |

Não se deve resolver essas lacunas copiando números ou controles das referências nem alterando regras comerciais.

**ANDROID PEQUENO**

- Dispositivo detectado: NUU M2, Android 7.0/API 24, resolução física 720×1280, densidade 320 dpi; equivalente lógico de 360×640. Escala de fontes configurada no aparelho: 1,0.
- Pacote instalado: `br.com.loumak.chamae`, versão 1.0.0 (1), atualização de 19/10/2026. Essa instalação não comprova o freeze de 20/10.
- O aparelho estava em `Asleep`, display `OFF`. A imagem `tool/visual_homologation/android/installed_api24.png` é preta e não foi contabilizada como evidência visual do app.
- Não houve instalação, reinstalação, desbloqueio, alteração de fonte/densidade, navegação em conta real ou mudança de configuração do telefone.
- Testes novos usam 360×640, barras superiores/inferiores simuladas de 24 px, texto 1,0 e 1,6, e teclado simulado de 260 px. O teste existente de 320 px e texto 2,0 foi preservado.
- Verificados por testes: ausência de exceções de layout, scroll até CTA do produto, campos e CTA do Checkout acima do teclado, acesso a termos/privacidade/saída e alinhamento dos valores. O teste do CTA do produto verifica sua visibilidade por toque e posição acima da área inferior segura.
- Ainda não verificados no hardware atual: rasterização de fontes, IME real, fluidez, desempenho de vídeo/imagens, plataforma de mapas e ergonomia de toque. Teste de widgets no Windows não emula essas características da API 24.

**TESTES**

| Verificação | Resultado | Evidência |
|---|---|---|
| `flutter test --reporter expanded` | 120 testes aprovados | `tool/visual_homologation/tests.log` |
| Matriz visual com geração de capturas | 12 cenários aprovados, incluindo 360×640 e texto 1,0/1,6 | `tool/visual_homologation/captures.log` |
| Teclado, rodapé, alinhamento e estados terminais | 3 testes aprovados | `tool/visual_homologation/keyboard_final.log` |
| Telas de entrada e estados complementares | 3 testes aprovados | `tool/visual_homologation/states.log` |
| `flutter analyze` | Sem apontamentos | `tool/visual_homologation/analyze.log` |

A contagem de 120 inclui os testes novos; não deve ser somada às execuções direcionadas. Foram mantidos os testes BR/PY, restrição de cartão, frete, estoque e sessão já existentes. Não foi feita nova aprovação de testes em Chrome nesta tarefa.

As capturas são do código de tela real com dados sintéticos injetados. Não são screenshots de um mockup desenhado nem demonstram dados de produção. As fixtures não são incluídas nos dados do app.

**BUILD**

| Comando | Resultado | Evidência |
|---|---|---|
| `flutter build web --release` | Aprovado, saída 0 | `tool/visual_homologation/build_web.log`; artefato `build/web/` |
| `flutter build apk --debug` | Aprovado, saída 0 | `tool/visual_homologation/build_apk.log`; artefato `build/app/outputs/flutter-apk/app-debug.apk` |

Os dois códigos de saída estão em `tool/visual_homologation/build_results.json`. Os logs contêm mensagens informativas de Wasm e avisos do toolchain Java/Kotlin, sem falha de build.

Build aprovado não comprova homologação visual do dispositivo físico. Os avisos do toolchain não motivaram alterações de SDK ou plugins. Não houve deploy, commit ou push.

A revisão foi concluída com correções pontuais e pendências de evidência claramente identificadas.

VISUAL AINDA POSSUI PENDÊNCIAS