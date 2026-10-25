# Home — homologação visual preliminar — 21/10/2026

Implementação local, sem commit, push ou deploy. Referência 02 como alvo estrutural; 01 e 03–07 como acabamento e consistência. Aprovação visual final pendente do responsável pelo produto.

## Arquivos da sprint

- `lib/screens/home_screen.dart`: header compacto, busca sob demanda, endereço/carrinho, horários/moeda/cotação, hierarquia comercial, cards, categorias e quatro destinos inferiores.
- `lib/widgets/sponsor_video_banner.dart`: proporção, margem, recorte curvo e borda. Inicialização, mute, loop, controller, fallback e descarte preservados.
- `assets/images/home/logo_transparent.png` e `commerce_backdrop.png`: exclusivos da Home; registro de uma pasta em `pubspec.yaml`, sem dependências novas.
- `test/home_visual_sprint_test.dart`: 17 testes novos. `test/client_readiness_test.dart` e `test/customer_visual_freeze_test.dart`: adaptação somente de seletores de nome/entrada do carrinho, mantendo asserts.
- `tool/visual_home/main.dart` e `capture.ps1`: harness debug isolado e captura em pasta nova.
- Esta pasta: relatório e evidências visuais.

Promoções usam exclusivamente `isOffer` real. Mais pedidos usa produtos com `salesCount > 0`, na ordenação existente. Categorias/produtos passam pela política comercial existente. Seções sem dados são omitidas; catálogo completo acessível. Nenhum preço, desconto, prazo, favorito ou avaliação da referência foi incorporado.

Métodos operacionais de carrinho, quantidade, estoque, detalhe, checkout, filtros e endereço foram comparados ao HEAD e preservados. Componentes compartilhados, outras telas e oito remanescentes anteriores permanecem intactos; 184 arquivos protegidos conferidos por SHA-256, com exceção das duas alterações de produção autorizadas.

## Validações

- `flutter analyze` e `flutter analyze --no-pub`: No issues found.
- Testes relacionados à Home: 48 aprovados.
- Suíte Flutter completa: 139 aprovados, incluindo os 17 novos.
- Chrome: 20 aprovados (Home e estados visuais), via bridge CanvasKit existente no painel; ferramenta não alterada. Encerramento com código zero, com aviso de SIGTERM/SIGKILL do Chromium.
- `git diff --check`: aprovado; avisos LF/CRLF do ambiente não são erros de whitespace.
- Build debug do harness aprovado. NUU M2: Android 7/API 24, 720×1280 físicos, densidade 320 dpi, 360×640 lógicos, font scale do sistema 1.0.
- Testes cobrem larguras 320/360/440/768, escalas 1.0/1.6/2.0, nomes/preços longos, estoque, remoção, carrinho, busca e acesso ao catálogo lazy.

Nos testes de widgets, o plugin de vídeo sem plataforma nativa registra init não implementado e usa o fallback existente. Vídeo conferido no aparelho. Build registra avisos existentes Java/Kotlin; nenhum SDK/plugin foi atualizado.

## Capturas e reprodução

Todas as PNGs desta pasta são novas, via `adb screencap`. A baseline `docs/visual_homologation_real_device_2026-10-20` não foi alterada. A faixa amarela identifica dados e imagens controlados. Endereço, cotação, nomes, preços, vendas e estoque são fixtures locais. As latas LOCAL são geradas em memória somente no harness; não são assets comerciais de produção.

Build: `flutter build apk --debug --target tool/visual_home/main.dart --no-pub`.
Com o harness instalado e aberto: `./tool/visual_home/capture.ps1 -Serial <serial-do-aparelho>`.
O script envia teclas de cena e captura: não instala APK, limpa dados ou altera configurações. Cada PNG exige inspeção. O harness falha intencionalmente fora de debug.

| PNG | Estado local |
| --- | --- |
| home.png | Header, vídeo, atalhos e início das promoções |
| promotions.png | Promoções e continuidade para Mais pedidos |
| popular.png | Cards, preço, adicionar e categorias |
| categories-preview.png | Categorias permitidas e transição ao catálogo |
| catalog.png | Catálogo, nome/preço longo, fallback e indisponibilidade |
| cart-state.png | Quantidade, diminuir, borda selecionada e acesso flutuante ao carrinho |
| search.png | Busca e teclado |
| empty.png | Catálogo vazio |
| error.png | Erro e tentar novamente |
| large-text.png | Header e navegação com fonte 1.6 apenas no harness |
| quote-error.png | Erro de cotação sem preço inventado |
| no-address.png | Ausência de endereço sem localização inventada |

Durante a preparação, o harness foi corrigido para localizar apenas a rota visível, manter uma única Home inicial e aguardar dimensões do viewport. A Home recebeu teste de Ver todos alcançando o catálogo lazy sem erro de layout. Capturas intermediárias inválidas não compõem a evidência final.

## Comparação com as sete referências

| Referência | Aplicação na Home | Diferença restante |
| --- | --- | --- |
| 01 Categorias | Navegação, fundo claro e categorias escuras/douradas com imagens | Política real exclui categorias bloqueadas; sem contagens ou colagens fictícias |
| 02 Home | Ordem Promoções → Mais pedidos → Compre por categoria → catálogo; header, hero, atalhos e quatro destinos | Duas colunas e trilhos em 360 dp, preservando alvos de toque em vez de comprimir a densidade de 900×1600 |
| 03 Carrinho | Creme, dourado, raios, CTA e continuidade do acesso | Tela do carrinho preservada; sem descontos/prazos inventados |
| 04 Checkout | Contraste, preços e hierarquia consistentes | Checkout, pagamentos e PIX intactos |
| 05 Acompanhamento | Identidade, recortes, ícones e navegação | Sem criar rastreamento, entregador ou promessa de prazo |
| 06 Produto | Foto protagonista, fundo escuro/dourado e ação circular | Sem avaliações, favoritos ou opções inexistentes; detalhe preservado |
| 07 Perfil | Quatro destinos e acabamento claro/dourado | Acesso existente preservado; sem criar funções fictícias de conta |

## Divergências e riscos residuais

1. Vídeo existente preservado: arte, enquadramento e movimento diferem do hero estático da referência. Curva/proporção aproximadas sem mudar lifecycle.
2. Marca transparente mantém a composição existente, mas não reproduz integralmente o acabamento metálico das referências. Os dois assets foram produzidos com o skill imagegen: marca derivada do asset existente e fundo decorativo sem produto/oferta fictícios. Originais preservados.
3. Aparência final depende das fotos reais do catálogo. Fotos opacas continuam com seu fundo; componente compartilhado e imagens reais não foram alterados.
4. Horário, moeda e cotação reais acrescentam altura ao header. Fonte ampliada aumenta alturas; nomes longos usam reticências e continuam completos no detalhe. Preços longos podem quebrar linha.
5. Espaçamentos, ícones Material e sombras aproximados, sem equivalência de fonte/ilustração/efeitos proprietários. Assets novos totalizam cerca de 3,1 MiB; sem benchmark de release.
6. Homologação física com fixtures isoladas: não valida catálogo de produção, checkout, autenticação, rede, performance de release ou iOS físico.
7. Sem permissões, SDKs, coleta ou integrações novas. Configurações Android/iOS/privacidade intactas. Esta etapa não certifica aprovação Apple/Google nem substitui revisão de publicação e materiais comerciais.

Também foram conferidos por toque físico adicionar, diminuir e abrir o carrinho: quantidade final 1 e item correto no carrinho, sem prosseguir ao checkout. Nenhuma exceção Flutter foi registrada na conferência final.

APK normal anterior reinstalado com sucesso (install -r), sem limpar armazenamento. Opção de permanecer acordado por USB restaurada para 0 e aparelho novamente em repouso. Não foi aberta conta de produção.
