# Home Chamaê — auditoria da tela visual OFICIAL

21/10/2026. Escopo: registro, auditoria e plano. Nenhuma implementação Flutter ou outra tela foi alterada.

## 1. Autoridade e conclusão

As sete imagens do proprietário SÃO AS SETE TELAS VISUAIS OFICIAIS. Registro normativo: `design/references/customer_app/official/README.md`; identidade, SHA-256 e mapeamento: `baseline_manifest.json` na mesma pasta. Nomes históricos com “reference” foram mantidos, sem reduzir sua autoridade.

A Home atual NÃO está homologada sob o novo critério. A sequência de seções e os quatro destinos aprovados são uma base, não equivalência visual. “PRÓXIMO” não satisfaz o aceite. A meta é fidelidade máxima / 100%, com exceções inevitáveis explicitadas e homologadas, nunca presumidas.

Correção do diagnóstico anterior: as diferenças NÃO dependem apenas de assets. Header, densidade, caixas, posição vertical, atalhos, cards, etiquetas, ícones, preços, contornos e tipografia exigem trabalho Flutter/layout. Assets oficiais continuam necessários, mas não substituem esse trabalho. Não reinterpretar ou modernizar o design.

## 2. Mapeamento das sete telas

| Ordem | Imagem oficial | Implementação existente |
| --- | --- | --- |
| 1 Home | `02_home_reference.jpeg` | `lib/screens/home_screen.dart`: DeliveryHomeScreen, _buildHeader, _buildCatalogContent, _buildOfferCard, _buildProductCard, _categoryPreview, _buildBottomNavigation; hero: `lib/widgets/sponsor_video_banner.dart` |
| 2 Categorias | `01_categories_reference.jpeg` | Estado _categoryOverview e métodos _buildCategoryOverview/_buildCategories na própria Home; não há tela independente |
| 3 Carrinho | `03_cart_reference.jpeg` | `lib/screens/cart_screen.dart`: CartScreen, entrada _openCart |
| 4 Checkout | `04_checkout_reference.jpeg` | `lib/screens/checkout_screen.dart`: CheckoutScreen, entrada _openCheckout |
| 5 Acompanhamento | `05_tracking_reference.jpeg` | `lib/screens/tracking_screen.dart`: TrackingScreen; `tracking_view.dart`: TrackingView |
| 6 Produto/combo | `06_product_reference.jpeg` | _showProduct em `lib/screens/home_screen.dart`, atualmente modal bottom sheet |
| 7 Perfil | `07_profile_reference.jpeg` | `lib/screens/customer_profile_screen.dart`: CustomerProfileScreen, entrada _abrirMenuApple |

Mesmo arquivo não significa mesmo escopo: na correção da landing Home não redesenhar o overview Categorias ou o modal Produto. Sequência: Home → Categorias → Carrinho → Checkout → Acompanhamento → Produto → Perfil, uma por vez.

## 3. Método e medição

Oficial Home: JPEG 900×1600. Capturas existentes: `docs/home_visual_sprint_2026-10-21/`, PNG 720×1280, NUU M2, 360×640 lógicos, Android 7/API24, densidade320, fonte1.0. Analisados home, promotions, popular, categories-preview, catalog, cart-state e estados auxiliares. Fixtures LOCAL não são fotos comerciais.

Para igualar somente largura física: coordenada oficial ×0,8. Para expressar a arte em largura lógica360: ×0,4. Isso mede composição, não autoriza fonte ilegível ou alvos de toque minúsculos. Captura tem 48px superiores pretos e faixa do harness até aproximadamente y82: descontar/alinha-las na comparação, sem remover SafeArea do app. O harness reduz a área útil; futura captura deve reproduzir o viewport real, com identificação rastreável no pacote.

Medição SOMENTE LEITURA por linha: pixels com R/G/B<110, faixa escura >42% da largura, excluindo pequenas margens. Primeiro marcador escuro largo do card promocional: oficial y861; captura inicial y1057. Após normalizar largura, oficial y≈689; descontando≈82px externos da captura, atual y≈975. Diferença acumulada≈286px físicos/143dp. É marcador diagnóstico influenciado pela imagem/cantos, NÃO borda exata ou score de fidelidade. Confirma deslocamento vertical substancial.

Valores Flutter abaixo são do código, em fonte1.0. Não foi atribuída família tipográfica ou raio exato ao JPEG sem fonte editável. Não foi feito percentual global de pixels: mídia, fontes, dados e viewport ainda não são equivalentes. As 12 imagens conferem com inventário SHA-256. A revisão anterior confirmou fontes atuais no kernel do APK capturado e assets correspondentes.

## 4. Diferenças observáveis — inventário aberto

L=Flutter/layout; A=asset; D=dado real; F=função/alegação pendente; R=responsividade/acessibilidade. Todo item exige correção evidenciada ou exceção inevitável homologada. Não presumir equivalência de pixels não descritos.

### Composição, header e marca

| ID | Diferença atual | Dependência / correção |
| --- | --- | --- |
| G01 | Densidade e distribuição vertical não equivalem; no topo atual só começa Promoções | L/R: régua geométrica, não apenas troca de mídia |
| G02 | Header alto e retangular, separado do hero; falta integração sob a marca | L/A: caixa, curva e encaixe oficiais |
| G03 | Mais espaço entre blocos; ausência da faixa de benefícios e dos indicadores | L/F: reproduzir apenas com conteúdo/funcionalidade reais |
| G04 | Cerca de quatro atalhos, uma oferta e dois populares visíveis, contra seis/dois/quatro na arte | L/R: medir alternativas com legibilidade; não declarar adaptação inevitável sem testar |
| G05 | Catálogo completo adicional após categorias não aparece na porção oficial | D/L: preservar acesso e integrar continuação |
| G06 | Área preta/faixa DEBUG não existem na arte; wrapper real limita440, harness isolado permite mais | R/harness: alinhar área útil e testar composição real, sem mudar main.dart |
| H01 | Posição/tamanho óptico da marca, endereço, busca e carrinho diferem | L/A: medir centros e baselines |
| H02 | Marca em caixa100×64dp (84×64 abaixo350), com proporção visual distinta | L/A: ajustar pelos limites visíveis, mantendo proporção |
| H03 | logo_transparent.png é derivação gerada anteriormente, não export oficial validado | A: obter original aprovado, sem interpretação generativa definitiva |
| H04 | Volume, reflexos, brilho, relevo, contorno e sombras metálicas da marca ausentes/diferentes | A: asset oficial isolado |
| H05 | Faltam separadores verticais oficiais entre marca/endereço/ações | L: posição, cor, espessura e altura |
| H06 | “Entregar em” + endereço truncado difere da identificação/endereço/cidade da arte | L/D: usar campos reais, sem confundir loja com destino ou copiar endereço ilustrativo |
| H07 | Pin, chevron, busca e carrinho têm formas, pesos, cores e escala diferentes | L/A: iconografia oficial e áreas interativas preservadas |
| H08 | Badge Material diverge em posição, tamanho, fonte, raio e acabamento | L/D: quantidade real, nunca o3 da arte |
| H09 | Horário, frete e moeda em linha separada acrescentam altura sem equivalente direto | L/D/R: compactar apresentação sem ocultar dados ou mudar cálculos |
| H10 | Borda inferior, sombra e curva sob a marca não coincidem | L/A: desenho e acabamento locais |

### Hero

| ID | Diferença atual | Dependência / correção |
| --- | --- | --- |
| V01 | Vídeo tem outra colagem, fachada, produtos, textos, iluminação e movimento | A: export oficial; padding não resolve conteúdo |
| V02 | Falta faixa escura inferior com três benefícios e divisores | L/A/F: geometria e conteúdo comercial validado |
| V03 | Onda inferior discreta/cantos arredondados não equivalem à onda e recorte oficiais | L/A: path e encaixe medidos |
| V04 | Margens, integração superior, limites e continuidade dourada diferem | L: reposicionar pintura/máscara, sem lifecycle |
| V05 | Altura width×0,56 clamp190–300 (201,6dp em360) não representa por si a geometria oficial mídia+faixa | L/A/R: especificar áreas e proporções pela arte |
| V06 | Cover corta conforme proporção do arquivo; ponto focal não especificado | A/L: safe area e enquadramento, conferir vídeo inteiro |
| V07 | Borda amarela plana1,5dp difere de espessura óptica, brilho e gradiente oficiais | L/A: separar borda de reflexos da arte |
| V08 | Halo/sombra atuais não reproduzem os oficiais e podem ser limitados pelo clipping | L: camada de sombra externa corretamente medida |
| V09 | Três dots/páginas ausentes | F: um vídeo sem carrossel real; não simular paginação |
| V10 | Fallback splash_bg e legenda não equivalem ao poster oficial do hero | A/L: poster correspondente sem perder fallback |
| V11 | Rapidez, temperatura e superioridade comercial da faixa não têm comprovação nesses campos do catálogo | F/D: validar alegações; não inventar prazo/garantia |

### Atalhos, títulos e promoções

| ID | Diferença atual | Dependência / correção |
| --- | --- | --- |
| T01 | Todos/Cervejas/Energéticos/Ofertas do Dia/Combos Festa/... difere de Bebidas/Conveniência/Energéticos/Gelo/Ofertas/Mais | L/F/D: mapear destinos reais, sem mudar filtros ou agrupamento comercial silenciosamente |
| T02 | Rail88dp e tiles76dp (fonte1.0) são proporcionalmente maiores que os seis atalhos oficiais | L/R: medir distribuição e labels com toque/leitura seguros |
| T03 | Raios17dp, borda, sombra, relevo e margens não coincidem | L: régua e acabamento locais |
| T04 | Grid, bateria, tag e taça diferem dos pictogramas oficiais | L/A: vetores/traços oficiais, sem SDK novo |
| T05 | Gradiente selecionado, creme normal, peso do label e distâncias ícone/texto diferem | L/R: tipografia e estados acessíveis |
| T06 | Medalha de Mais pedidos difere da coroa; chama e loja também diferem em desenho/cor | L/A: reprodução de ícones |
| T07 | Títulos19dp/w800, ações11dp e setas Material não equivalem aos tamanhos/pesos/baselines oficiais | L/A: especificação tipográfica e óptica |
| T08 | Padding títulos16/14/12/8, gaps entre seções e distância título/card diferem | L: alinhamentos comuns por régua |
| P01 | Oferta272×190dp em trilho mostra uma inteira; oficial mostra duas lado a lado | L/R: medir duas ofertas sem texto/touch ilegíveis |
| P02 | OFERTA DO DIA e nome do SKU diferem das chamadas comerciais e hierarquia do oficial | A/F/D: conteúdo real aprovado, sem hardcode das campanhas ilustradas |
| P03 | Foto, escala, posição e ocupação da embalagem divergem; LOCAL não demonstra resultado comercial | A/L: fotos reais e caixa/ponto focal especificados |
| P04 | Overlay preto atual cobre também a imagem, diferente da separação texto/foto oficial | L: leitura sem esconder produto |
| P05 | Fundo genérico gerado não é o fundo gráfico oficial da oferta | A: camada oficial sem preço/nome embutidos |
| P06 | Falta selo inclinado superior da campanha; texto superior atual é diferente | L/A/F: selo só com condição/campanha real, sem desconto inventado |
| P07 | Preço, textos secundários, alinhamento e hierarquia divergem | L/D: dados reais e tipografia correta |
| P08 | Aproveitar tem forma, dimensões, gradiente, sombra e seta diferentes | L: pintura fiel, toque e callback preservados |
| P09 | Raio18dp, contorno e halo não equivalem ao painel dourado oficial | L/A: medir borda/sombra e arte |
| P10 | BRL usa ponto decimal via toStringAsFixed, oficial usa vírgula; preços longos têm outro comportamento | L/D: formatter de apresentação da Home, sem alterar conversão, taxas ou valores |

### Cards e categorias da Home

| ID | Diferença atual | Dependência / correção |
| --- | --- | --- |
| C01 | Popular164×242dp e dois visíveis, contra quatro cards proporcionalmente menores na arte | L/R: resolver densidade e leitura; justificar exceção com evidência |
| C02 | Relação foto/texto, altura da imagem, padding8dp e ocupação óptica diferem | L/A: caixa e packshot padronizados |
| C03 | Nome/embalagem têm hierarquia e linhas diferentes; modelo não tem embalagem estruturada separada | D/L/F: não inferir embalagem por parsing não homologado |
| C04 | Preço18dp/w900, dourado escuro, alinhamento e distâncias da ação diferem | L/D: medir pintura, respeitando preço longo |
| C05 | + atual pinta disco grande/plano com ícone grosso; oficial tem disco menor e relevo | L/R: área pintada pode ser menor que hit target>=48dp, sem sobreposição entre controles |
| C06 | Corações de favoritos ausentes | F: não há fluxo real identificado; não inserir controle falso |
| C07 | Selo PROMOÇÃO inferior atual não aparece nesses cards oficiais | L/D: rever apresentação preservando isOffer e filtros |
| C08 | Borda selecionada, badge de quantidade e diminuir sobre foto são estados extras existentes | L/D/R: harmonizar sem remover ações/feedback; exceção de estado explícita |
| C09 | Raio16dp, borda bege, elevation1 e sombra diferem | L: estilo local fiel |
| C10 | Fotos opacas/transparências e escalas variáveis não reproduzem packshots oficiais | A: padronização real, sem gerar foto ou remover fundo por truque de layout |
| C11 | Placeholder creme/ícone e indisponível não são mostrados na arte estática | L/D/R: manter estado honesto; aprovar acabamento separado |
| C12 | Nomes longos truncam e preços quebram, enquanto arte só tem textos curtos | L/D/R: testar extremos sem cortar preço ou congelar fonte |
| C13 | Ranking real salesCount>0, até seis itens, não garante SKUs ilustrados | D: preservar seleção real; nunca inventar vendas |
| K01 | Categorias178×120dp diferem da faixa baixa/compacta oficial | L/R: proporções/distribuição da landing, sem editar overview Categorias |
| K02 | Nome branco no rodapé sombreado difere da etiqueta clara superior com seta | L: posição, cor, padding e contraste |
| K03 | Uma foto de produto por categoria difere das colagens temáticas | A/D: composição oficial para categorias realmente permitidas |
| K04 | Seta circular amarela difere da seta/posição da etiqueta | L/A: desenho e callback preservados |
| K05 | Raios18dp, margens, gaps e sombras diferem | L: régua e acabamento |
| K06 | Rótulos oficiais não equivalem diretamente a todos os filtros atuais | D/F: mapear taxonomia, sem criar categoria silenciosamente |

### Tipografia, cores, navegação e estados

| ID | Diferença atual | Dependência / correção |
| --- | --- | --- |
| S01 | App usa Roboto; família/versão/pesos oficiais não foram fornecidos | A/L: obter fonte e licença; não declarar equivalência por semelhança |
| S02 | Tracking, entrelinha, peso, alinhamento óptico e quebras diferem em vários blocos | L: tipografia local por componente |
| S03 | #FFCC00, #886000 e gradientes atuais não equivalem a todos os tons/reflexos oficiais | L/A: medir UI separadamente de reflexos fotográficos |
| S04 | Fundo #FAF7F0 uniforme difere de luz, halo, vinheta e textura oficiais | L/A: camada/efeito oficial, sem textura autoral substituta |
| S05 | Preto/charcoal, branco, contornos e sombras precisam de comparação regional | L: um token “dourado” não reproduz todo acabamento |
| N01 | Quatro destinos/ordem coincidem; ícones, pesos, cores e tamanhos não são idênticos | L/A: pintura fiel, destinos/callbacks intactos |
| N02 | Barra64dp, raio28dp, linha bege e sombra diferem da curva/halo dourado oficiais | L/R: medir pintura/safe area, não reduzir toque |
| N03 | Posição de ícones/rótulos, gap e estado ativo diferem | L: baselines e seleção real |
| N04 | FAB com subtotal encobre parte de catálogo/categorias; arte mostra badge no header | L/D/R: preservar acesso homologado; estudar posição/pintura sem remoção automática |
| N05 | Espaço final100dp com carrinho/28dp sem carrinho não tem equivalente direto | L/R: adequar à área efetiva dos controles |
| E01 | Busca expandida, loading, vazio, erro, loja fechada, sem endereço, falha de cotação/persistência não aparecem na arte | D/L/R: preservar e aprovar acabamento; nunca ocultar erro real |
| E02 | Fórmulas fixas aumentam alturas em fonte1.6/2.0; wrapping requer homologação por bloco | L/R: preservar text scaler, sem comprimir texto para screenshot |
| E03 | Seções somem sem ofertas/vendas e categorias dependem do catálogo | D: exceção dinâmica legítima, sem inventar catálogo |

Este inventário cobre diferenças verificáveis nos fontes e capturas disponíveis. Não certifica que pixels não citados sejam iguais. Fonte exata, camadas, paths e tokens precisos não são recuperáveis com certeza de um JPEG; devem ser fornecidos ou medidos, não presumidos.

## 5. Pendências funcionais visíveis nas telas oficiais

Busca em lib e inspeção do Product: nenhum fluxo/estado de favoritos, avaliações ou cupons identificado no cliente. Isso não certifica inexistência absoluta de backend futuro; impede apresentá-los como funções atuais homologadas.

| Elemento oficial | Estado real identificado / encaminhamento |
| --- | --- |
| Favoritos na Home/Produto/Perfil | Sem modelo/serviço/fluxo identificado; pendência separada, sem botão falso |
| Dots/carrossel do hero | Um vídeo, sem paginação correspondente; não simular páginas |
| Atalhos Mais e agrupamentos de categorias | Taxonomia atual distinta; mapear acessos reais antes de mudar destino/rótulo |
| Rapidez, bebidas geladas e superioridade | Validar alegações comerciais; não inventar garantia/SLA |
| Cupom/desconto no Carrinho | Sem fluxo real identificado no cliente; ciclo Carrinho, fora da Home |
| Nota e contagem de avaliações | Product não possui esses campos/fluxo; não fixar4,9 ou contagens |
| Ligar/Mensagem ao entregador, veículo, placa, mapa ao vivo | Tracking tem status/dados e chat COM A LOJA via CustomerChatEntry; não equivale a contato/rastreamento real do entregador. MotoboyAppScreen informa integração futura |
| Temperatura/opções/composição do combo | Modal atual tem descrição, preço, disponibilidade e quantidade; opções estruturadas equivalentes não identificadas |
| Gestão de pagamentos/cartões/configurações no Perfil | Pagamentos no checkout não comprovam gestão de meios salvos no Perfil; auditar no ciclo próprio |
| Produtos/categorias comercialmente bloqueados presentes nas imagens | Preservar política de tabaco/vapes e demais bloqueios; aparência não autoriza venda ou exibição proibida |

Não implementar nenhuma dessas funções nesta auditoria ou silenciosamente na correção visual. A ausência funcional é exceção explícita a submeter, não licença para comportamento falso.

## 6. Assets oficiais necessários

1. **Marca isolada:** mestre vetorial e/ou PNG transparente exportado da identidade aprovada, incluindo relevo, volume, reflexos, contornos e assinatura. Sem fundo preto ou margens excessivas. Fornecer área de proteção e tamanho mínimo; não gerar interpretação definitiva. A derivação atual não é um export oficial homologado.
2. **Hero oficial em movimento:** vídeo composto para o enquadramento e a máscara extraídos da tela oficial, com zonas seguras para marca, produtos, fachada e textos. Entregar poster/fallback correspondente. Não substituir vídeo por JPEG nem sobrepor copy fictícia para disfarçar conteúdo diferente. Proporção final definida pela régua, não pela conveniência do arquivo atual.
3. **Camadas gráficas oficiais:** ondas, reflexos, bordas, brilho e fundos de hero/oferta/fotos/categorias separados de preços e nomes dinâmicos. Fundo gerado existente não é acabamento oficial aprovado.
4. **Fotos reais por SKU:** PNG/WebP transparente ou fundo oficial consistente, produto inteiro, resolução para2×/3×, escala óptica/iluminação equivalentes e vínculo ao ID real. Sem embalagem/volume inventado. LOCAL pertence apenas ao harness.
5. **Composições de categoria/campanha:** colagens oficiais para categorias permitidas e campanhas reais, com nomes/preços/selos dinâmicos separados. Não incorporar produto bloqueado ou não vendido.
6. **Fonte/ícones:** arquivos de fonte, versões/pesos/licença e SVGs oficiais ou especificação de traços. JPEG não identifica com certeza kerning, família, peso ou path.

**Trabalho que independe desses assets:** alturas, margens, divisores, encaixe de caixas, proporção/ocupação de imagem, densidade, títulos, preços, ações, etiquetas, pintura de bordas/sombras e formatação monetária. A ausência de mídia não justifica deixar a geometria atual sem correção. Por outro lado, layout não recria marca/fotografia/vídeo oficial.

## 7. Plano de fidelidade máxima — somente Home

### A. Régua oficial, dados e exceções

- Extrair do JPEG coordenadas e dimensões de header/recorte/hero/faixa/atalhos/ofertas/populares/categorias/navbar. Registrar grade, margens, baselines, proporções e limites visíveis, com precisão documentada.
- Fixar viewport de comparação e alinhar safe areas. Retirar somente o viés do harness da medição, sem ocultar UI do produto. Para pixel-diff, controlar frame de vídeo e dados equivalentes autorizados apenas no harness; nunca hardcode em produção.
- Estabelecer tipografia oficial, paleta, paths/ícones e camadas fornecidas. Onde fonte editável não existir, medir raster e registrar incerteza, sem declarar 100% por palpite.
- Listar cada exceção inevitável: alvos>=48dp, fonte ampliada, conteúdo dinâmico, estados ausentes da arte, taxonomia real, dados BR/PY/USD, acesso extra homologado ao carrinho e funções inexistentes. Não chamar toda diferença de densidade inevitável antes de medir alternativas.
- Mapear os seis atalhos oficiais aos acessos já existentes. Se o agrupamento exigir mudar regra comercial ou inventar serviço, reportar pendência antes de implementar.

### B. Correção geométrica local na estrutura aprovada

1. Corrigir altura, centros e baselines do header; posição óptica da marca; divisores; endereço real; busca/carrinho/badge; apresentação compacta de horário/frete/moeda. Preservar campos, cálculos e ações.
2. Reproduzir encaixe header/hero, curva, máscara, proporções, faixa de informações reais aprovadas, bordas e sombra pela régua. Controller, init/mute/loop/dispose/fallback funcional intactos. Dots somente se existir funcionalidade real autorizada.
3. Ajustar rail de atalhos, tamanhos dos títulos e gaps. Medir seis acessos com labels/touch adequados, registrando exceções efetivas de360dp/texto ampliado.
4. Corrigir composição de ofertas para duas por linha quando viável e densidade dos populares conforme geometria oficial. Testar leitura/targets antes de escolher quantidade por breakpoint. Preservar isOffer/salesCount/callbacks e ordem das seções.
5. Corrigir proporções de imagem/texto, posição de preços/+ e desenho de etiquetas de categorias. Manter quantidade/decremento/indisponível e catálogo completo; registrar estados extras sem equivalente oficial.
6. Reproduzir navbar, raios, sombras, ícones, gradientes e pesos localmente, sem trocar componentes por preferência. Quatro destinos e acessos reais intactos.
7. Corrigir formatação de apresentação BRL/PYG/USD e valores longos, sem alterar taxa de câmbio, preço, cálculo financeiro ou pagamento. Não aplicar mudança indireta ao modal Produto por reutilização de helper.
8. Harmonizar FAB/feedback para não cobrir conteúdo, sem remover acesso homologado. Preservar avisos de persistência, erro, loja fechada e demais estados reais.

### C. Integração de assets oficiais

- Integrar marca, mídia/poster, fundos, fotos e ícones aprovados sem novo desenho autoral. Se faltarem, registrar as regiões dependentes; não declarar homologação máxima nem fabricar substituto definitivo.
- Revalidar escala óptica de SKUs, foto opaca/transparente, recorte em todos os frames relevantes, textos comerciais verdadeiros, nomes/preços longos e todas as moedas.
- Não inserir frases, descontos, avaliações ou produtos ilustrativos como dados comerciais. Não criar SDK, permissões ou coleta para reproduzir efeito.

### D. Validação e evidências, em pasta nova

- flutter analyze; testes relacionados à Home; suíte Flutter de regressão necessária; Chrome Home/estados quando aplicável; git diff --check.
- NUU M2 real:360×640 lógicos,720×1280 físicos,API24,f1.0. Também320/360/440, fontes1.6/2.0 e demais tamanhos através do wrapper REAL do app.
- Produzir topo/header+hero; hero→atalhos; ofertas; populares; categorias; catálogo restante; carrinho com quantidade; busca/teclado/resultados; loading/vazio/erro; loja fechada; sem endereço; cotação loading/erro; imagem ausente/erro; nome/preço longo; fonte ampliada.
- Comparação integral, crops por região, overlay alinhado e registro de diferenças geométricas. Não confiar em score global cego de vídeo/fotos/textos distintos. Máscaras de análise apenas em conteúdo dinâmico justificado, nunca em bordas, caixas, posições ou overflow. Originais preservados e SHA/versão/fontes/assets/APK rastreáveis.
- Cada ID desta auditoria fecha como **corrigido e comparado**, **asset/funcionalidade pendente** ou **exceção inevitável homologada**. “PRÓXIMO” não fecha o item. Documentar o que ainda impede equivalência máxima.

### E. Aprovação da Home antes da próxima tela

O proprietário homologa primeiro a Home e suas exceções explícitas. Depois Categorias, Carrinho, Checkout, Acompanhamento, Produto e Perfil. A tarefa atual não inicia código de nenhuma dessas telas.

## 8. Arquivos previstos e riscos

Futura implementação: somente métodos visuais da landing em `lib/screens/home_screen.dart`; build/clipper/painter em `lib/widgets/sponsor_video_banner.dart`; assets exclusivos oficiais; `pubspec.yaml` apenas para assets/fontes necessários; testes Home e harness específico.

Não editar _showProduct ou _buildCategoryOverview por compartilharem o arquivo. Não mudar silenciosamente `theme.dart`, `customer_visual.dart`, `product_image.dart`, `main.dart` ou outras telas. Usar estilos locais; se um bloqueio real exigir compartilhado, parar e reportar. Preservar os oito remanescentes anteriores e todas as alterações legítimas. Não fazer refatoração arquitetural.

Riscos principais: regressão em métodos compartilhados no mesmo arquivo; mudanças indiretas no modal por formatter/imagem; colisão de targets em quatro cards; truncamento em fonte ampliada; diferenças de decode/rasterização em API24; recorte do vídeo; comparação enviesada pelo harness; dependência de fontes/artes oficiais; confundir chat lojista com entregador. Mitigar com limites de método, testes operacionais existentes, testes de bounds/toque, captura real e análise por região.

Apple/Google: preservar acessibilidade, contraste, privacidade, conteúdo permitido e ausência de alegações enganosas. Sem novas permissões/SDKs/coleta. Esta auditoria não certifica conformidade nem aprovação de publicação e não inicia auditoria completa de políticas.

## 9. Validação desta etapa documental

Nenhum aplicativo, asset, teste ou harness alterado. Não houve novo analyze/teste, instalação, captura, commit, push ou deploy: esta tarefa termina na auditoria/plano. Resultados anteriores (139 Flutter,20 Chrome,analyze sem issues) são histórico e não homologam a nova baseline. Conferir hashes originais, capturas, escopo documental e git diff --check antes de encerrar.

Conclusão: **HOME NÃO HOMOLOGADA COMO REPRODUÇÃO DA TELA OFICIAL**. Ordem proposta: régua e exceções → geometria local → assets oficiais → validação/comparação → aprovação da Home. Nenhuma correção foi executada nesta auditoria.
