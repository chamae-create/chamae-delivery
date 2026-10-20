# Chamaê — homologação visual em aparelho real — 20/10/2026

**Escopo vigente:** homologação visual com dados locais/controlados, autorizada expressamente durante esta tarefa. Não é homologação de integração de produção. São cenários visuais independentes, sem simular uma compra ponta a ponta. Os widgets reais foram executados no NUU M2; PIX, Chat, Perfil, histórico e checkout usam fixtures em memória. As primeiras capturas integradas foram preservadas como diagnóstico anterior às correções.

As referências oficiais e seu README em `design/references/customer_app/official/` orientaram a comparação. Nenhum preço, endereço, produto ou dado pessoal foi copiado das referências para o catálogo. Funcionalidade e políticas aprovadas continuam prevalecendo.

**NUU M2**

- Android 7.0 / API 24, 720×1280 físicos, 320 dpi, 360×640 lógicos, fonte do aparelho em 1,0.
- Capturas físicas por `adb shell screencap` e `adb pull`; não são imagens de emulador ou capturas de testes de widgets.
- Entrada normal: `lib/main.dart`. Entrada local isolada: `tool/visual_device/main.dart`, bloqueada fora de `kDebugMode`, sem chamada a `Firebase.initializeApp`, Auth, Firestore ou Functions pelo harness. O aplicativo normal não importa o harness.
- Ao encerrar, o APK normal foi restaurado por atualização, sem limpar dados nem abrir a conta real; manter tela ligada por USB foi devolvido ao valor original 0. Evidência: `device_final_state.json` e `restore_normal_apk.log`.
- A faixa “HOMOLOGAÇÃO LOCAL • DEBUG • DADOS CONTROLADOS” identifica as fixtures e reduz um pouco o espaço disponível. Essa faixa e o header de seleção de cenário não integram o produto.
- Validado layout, vídeo existente, scroll, barras, botões e teclado real. Texto ampliado a 1,6 foi validado nos testes; não foi aplicada mudança permanente de fonte no aparelho.
- Inicialização fria do debug foi lenta neste hardware e algumas imagens brancas foram repetidas. A amostra Android `gfxinfo_debug.txt` é pequena e não mede adequadamente frames Flutter; não constitui benchmark nem aprovação de desempenho de release.

| Tela/fluxo | Classificação | Evidência principal |
|---|---|---|
| Home | APROVADA COM AJUSTE COSMÉTICO | `local_home.png` |
| Catálogo/Categorias | APROVADA | `local_catalog.png`, `local_categories.png` |
| Produto | APROVADA COM AJUSTE COSMÉTICO | `local_product.png`, `local_product-footer.png` |
| Carrinho | APROVADA | `local_cart.png`, `local_cart-footer.png` |
| Checkout | APROVADA COM AJUSTE COSMÉTICO | `local_checkout.png`, `local_checkout-footer.png` |
| PIX | APROVADA | `local_pix-*.png` |
| Chat | APROVADA | `local_chat.png`, `local_chat-merchant.png`, `local_chat-keyboard-footer.png` |
| Mapa | APROVADA | `local_map.png`, `local_map-footer.png` |
| Perfil | APROVADA | `local_profile.png`, `local_profile-footer.png` |
| Pedidos | APROVADA no escopo visual local | `local_history.png`, `local_orders.png` |

**HOME**

Referência principal: `design/references/customer_app/official/02_home_reference.jpeg`.

Logo, endereço controlado, “Delivery até 00:00”, moeda, cotação local, banner comercial existente, atalhos e bottom navigation foram conferidos no aparelho. A Home integrada anterior demonstrou o banner real e um estado de erro da cotação; isso não foi ocultado nem corrigido alterando frete.

Foi corrigida a sobreposição de conteúdo rolado com a barra de status por `SafeArea` superior no corpo da Home. A composição mantém off-white, carvão e dourado das referências. Os subtítulos dos atalhos ainda usam reticências na largura pequena; é diferença cosmética, sem ocultar as ações principais. Não foram criadas novas campanhas ou seções de ofertas com dados inventados.

**CATÁLOGO**

Referência principal: `design/references/customer_app/official/01_categories_reference.jpeg`.

Fixtures incluem nome extenso, ausência de imagem, preço de quatro dígitos, promoção local e produto sem estoque. A grade mantém proporções, fallback de imagem, preço e estado indisponível. O título abre integralmente no Produto; reticências da grade são intencionais. A captura integrada inicial também mostrou fotografias e categorias do catálogo existente.

A grade de categorias conserva hierarquia, cards escuros e rótulos com quebra de linha. Categorias bloqueadas não foram adicionadas. Busca e chips permanecem como componentes existentes; filtros não foram alterados.

**PRODUTO**

Referência principal: `design/references/customer_app/official/06_product_reference.jpeg`.

Modal real aberto por toque ADB. Hero/fallback, nome completo, preço, descrição, quantidade, total e CTA foram conferidos. O botão “Adicionar ao carrinho” fica totalmente acessível após scroll no NUU M2. Não foram inventadas opções, recomendações ou dados de estoque.

Diferença cosmética mantida: alguns preços de Home/Produto e itens do Checkout usam ponto decimal, enquanto os resumos usam vírgula. Os valores não foram modificados; a padronização editorial pode ser tratada separadamente, sem bloquear uso ou leitura.

**CARRINHO**

Referência principal: `design/references/customer_app/official/03_cart_reference.jpeg`.

Itens locais com nome longo, imagens ausentes e quantidades diferentes permanecem legíveis. Controles, subtotal, taxa e indicação de entrega a calcular foram conferidos. O resumo não apresenta frete inventado e o CTA “Continuar para entrega” é alcançável por scroll. Também foi preservada captura do carrinho integrado anterior, sem editar seus itens para melhorar o visual.

**CHECKOUT**

Referência principal: `design/references/customer_app/official/04_checkout_reference.jpeg`.

Endereço, itens, resumo, taxa, total, pagamento e CTA final foram capturados usando cotação e verificação locais pelas interfaces já existentes. A fixture não concede verificação a uma conta real. Nenhum pedido foi finalizado nem cobrança solicitada.

O resumo de quatro dígitos permanece alinhado e o botão final fica integralmente visível no rodapé. A captura principal usa destino BR; regras BR/PY, bloqueio de cartão, horário e cálculos não foram modificados e continuam cobertos pela suíte existente. Teclado/rodapé do Checkout também têm os testes de responsividade existentes.

**PIX**

| Estado local | Evidência |
|---|---|
| Criando | `local_pix-creating.png` |
| QR disponível | `local_pix-qr.png` |
| Aguardando pagamento | `local_pix-waiting.png`, `local_pix-footer.png` |
| Copia e cola visível | `local_pix-footer.png` |
| Pago | `local_pix-paid.png` |
| Expirado | `local_pix-expired.png` |
| Erro | `local_pix-error.png` |
| Retry | `local_pix-retry.png` |

O QR codifica somente `LOCAL-VISUAL-NOT-A-PAYMENT`; não é PIX nem pode gerar cobrança. O estado pago é uma fixture explicitamente identificada, não confirmação real do Mercado Pago. Copiar foi avaliado visualmente; o callback de retry foi exercitado nos testes sem servidor.

A apresentação foi extraída para `PixPaymentPresentation`, reutilizada pelo diálogo real e pelo harness. O título agora pode quebrar linha em largura pequena/texto ampliado. Textos auxiliares, sucesso e erro usam cores semânticas mais legíveis. Listener, autorização, timeout, confirmação, fechamento automático e retry real não foram alterados: a comparação do runtime anterior ao `build`, ignorando espaços, permaneceu idêntica.

**CHAT**

Conversa local com 12 mensagens, textos curtos e longos, papéis cliente/loja, badge de três não lidas e timestamps controlados. A tela cliente e a tela loja foram capturadas; a resposta rápida da loja continua no componente existente. Nenhuma mensagem foi enviada a pessoas ou pedidos reais.

Horários `HH:mm` agora são apresentados somente quando `createdAt` existe como `Timestamp` ou `DateTime`. Não se cria horário para mensagem sem dado. Essa alteração é de apresentação; envio, leitura, autorização, isolamento da conta e encerramento da conversa permanecem intactos. Foi acrescentado espaçamento entre a lista e os campos para impedir contato do rótulo flutuante com a última mensagem visível.

Teclado Android real confirmado aberto pelo sistema. A captura `local_chat-keyboard-footer.png` mostra o campo focado, rótulo separado das mensagens e botão Enviar integralmente acima do teclado. O rodapé da visão loja também foi alcançado por scroll (`local_chat-merchant-footer.png`). Não foi digitada nem enviada mensagem; os callbacks continuam locais nos testes.

**MAPA**

Layout do `AddressMapScreen` existente executado no aparelho: busca, pin, botão de localização, card inferior, campos e CTA. O rodapé é rolável e “Confirmar localização” continua desabilitado quando o endereço não está confirmado.

Foi corrigido somente o contraste do título e do ícone voltar sobre o AppBar preto. Widget Google Maps, GPS, geocoding, Routes, coordenadas, confirmação e regras não foram alterados.

A superfície Google ficou cinza nas primeiras capturas e carregou tiles na repetição final (`local_map.png`), com pin e controles legíveis. Foi usada somente a configuração existente e o centro padrão do aplicativo, sem cadastrar endereço, acionar GPS ou confirmar destino. Não foram inseridas chaves nem permissões. A aprovação inclui o mapa base carregado e o layout; geocoding, Routes, confirmação de endereço e falhas de provedor continuam fora desta validação visual controlada.

**PERFIL**

Referência principal: `design/references/customer_app/official/07_profile_reference.jpeg`.

Nome extenso, e-mail `example.test`, dados locais, endereço, PIN mascarado, documentos, vinculação e saída foram conferidos por scroll. Nenhum PIN real foi revelado ou redefinido. Não houve aceite jurídico nem registro de Termos/Privacidade no Firebase. A data de nascimento exibida pertence ao double de teste existente, somente em memória; não foi gravada no Firebase.

O histórico usa o mesmo card `lib/widgets/customer_order_history_card.dart` do aplicativo real com estados localmente controlados de separação, entregue e cancelado. Consulta autenticada, filtro por usuário, paginação e abertura de pedido real permanecem no código existente. A captura de acompanhamento usa um pedido local coerente com o modelo, sem inventar localização de entregador.

**CORREÇÕES**

| Correção | Motivo comprovado | Escopo |
|---|---|---|
| Rótulo flutuante em carvão; erro preservado | Amarelo claro sobre campo branco no NUU M2 | Tema de inputs |
| SafeArea superior da Home | Conteúdo rolado sob barra de status | Layout |
| Título PIX flexível | Overflow reproduzido em teste 360 px e texto ampliado | Apresentação |
| Contraste de textos PIX | Cinza/verde/vermelho claros nas capturas físicas | Apresentação |
| Espaço entre lista e campos do Chat | Rótulo flutuante encostando na mensagem com teclado aberto | Apresentação |
| Horário do Chat quando existente | Timestamp recebido não aparecia | Apresentação |
| Título e voltar brancos no Mapa | Texto/ícone escuros no AppBar preto | Apresentação |
| Apresentação PIX e card de histórico compartilhados | Exercitar widgets reais com fixtures sem acessar backend | Separação de apresentação |

Não houve redesign amplo. O `preservation.json` registra 75 arquivos funcionais monitorados: 74 continuam com hash idêntico; a exceção é a extração da apresentação PIX, cujo runtime foi comparado separadamente. O gateway do Chat e os métodos anteriores ao `build` do Mapa também foram comparados e permanecem idênticos, ignorando formatação. Auth, frete, estoque, pagamentos/servidor, Rules, Functions, PIN, política BR/PY e horários não foram alterados. As mudanças adicionais em Chat e Mapa são as apresentações descritas acima, não mudanças das integrações.

**CAPTURAS**

Pasta: `docs/visual_homologation_real_device_2026-10-20/`.

- 29 arquivos `local_*.png`: capturas finais controladas, com faixa de debug, todas em 720×1280 físicos.
- `before/`: registros integrados/diagnósticos anteriores às correções; não são evidência de aprovação final.
- `capture_inventory.json`: arquivos, tamanho e SHA-256.
- `device_and_artifacts.json`: hardware e identificação dos artefatos normal e local.
- `tool/visual_device/README.md`: reprodução, isolamento, rotas e limites.
- `source_changes.diff` e `before/*.before`: comparação das mudanças desta etapa.
- `device_final_state.json`: restauração do APK normal e configuração do aparelho.

As imagens foram capturadas progressivamente após cada correção relevante. A inclusão posterior do card de histórico e o ajuste de espera do teclado pertencem ao harness/apresentação indicada e não redesenham as outras telas. Capturas brancas transitórias não são contabilizadas como telas aprovadas. As 35 capturas anteriores de testes não foram reutilizadas como prova de aparelho físico.

**TESTES**

| Validação final | Resultado | Evidência |
|---|---|---|
| `flutter test --reporter expanded` | 122 aprovados | `tests.log`, `tests_result.txt` |
| PIX nos sete estados, 360×640 e texto 1,0/1,6 | Aprovado, incluindo retry e ausência de overflow | `test/pix_payment_presentation_test.dart` |
| `flutter analyze` | Limpo | `analyze.log`, `analyze_result.txt` |
| `flutter build apk --debug` — entrada normal | Aprovado | `build_apk.log`, `build_apk_result.txt` |
| APK de captura debug local | Aprovado e executado no NUU M2 | `build_harness.log` e screenshots |

A contagem 122 já inclui os dois novos testes PIX; não deve ser somada às execuções direcionadas. O teste de vídeo informa ausência de implementação de plugin no ambiente de widgets; o banner foi observado no dispositivo. Build Web não foi reexecutado nesta etapa, pois o escopo atual exige APK debug; o resultado Web anterior não é apresentado como nova validação deste código.

**PENDÊNCIAS**

Não restam pendências visuais impeditivas no escopo controlado aprovado. Foram mantidas apenas diferenças cosméticas identificadas de formatação monetária e reticências dos atalhos, sem perda de valor ou ação. A aprovação não exige redesign de telas estáveis.

Permanecem fora do escopo aprovado: homologação de cobrança/webhooks Mercado Pago, mensagens remotas, Firebase/conta de produção, geocoding/Routes e benchmark de performance de release. Fixtures não comprovam essas integrações. Houve somente instalação local via ADB para teste. Não houve publicação/deploy remoto, commit ou push.

VISUAL HOMOLOGADO EM APARELHO REAL