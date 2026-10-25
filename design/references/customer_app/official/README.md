# Chamaê Delivery — baseline visual oficial

As sete imagens fornecidas pelo proprietário são as SETE TELAS VISUAIS OFICIAIS do Chamaê Delivery. Não são inspiração, exemplos, referências opcionais ou autorização para reinterpretar o design.

Diretriz formalizada em 21/10/2026: a implementação Flutter deve buscar FIDELIDADE VISUAL MÁXIMA / 100%, com desvios somente quando inevitáveis por responsividade, acessibilidade, dados reais ou ausência de funcionalidade real. Cada exceção deve ser identificada, justificada e submetida à homologação; não é aprovação automática. “PRÓXIMO” não satisfaz o aceite.

Os nomes históricos dos arquivos e desta pasta foram preservados. A palavra `reference` no caminho NÃO reduz sua autoridade como tela oficial. Os JPEGs originais não foram modificados. Identificação e SHA-256 estão em [baseline_manifest.json](baseline_manifest.json).

| Ordem de homologação | Tela oficial | Imagem original | Implementação existente |
| --- | --- | --- | --- |
| 1 | Home | [02_home_reference.jpeg](02_home_reference.jpeg) | `lib/screens/home_screen.dart` — `DeliveryHomeScreen` |
| 2 | Categorias | [01_categories_reference.jpeg](01_categories_reference.jpeg) | Mesmo arquivo — `_categoryOverview`, `_buildCategoryOverview`, `_buildCategories` |
| 3 | Carrinho | [03_cart_reference.jpeg](03_cart_reference.jpeg) | `lib/screens/cart_screen.dart` — `CartScreen` |
| 4 | Finalizar pedido / checkout | [04_checkout_reference.jpeg](04_checkout_reference.jpeg) | `lib/screens/checkout_screen.dart` — `CheckoutScreen` |
| 5 | Acompanhar pedido | [05_tracking_reference.jpeg](05_tracking_reference.jpeg) | `TrackingScreen` + `TrackingView`, em `lib/screens/tracking_screen.dart` e `tracking_view.dart` |
| 6 | Detalhe de produto/combo | [06_product_reference.jpeg](06_product_reference.jpeg) | `lib/screens/home_screen.dart` — `_showProduct`, atualmente modal |
| 7 | Perfil | [07_profile_reference.jpeg](07_profile_reference.jpeg) | `lib/screens/customer_profile_screen.dart` — `CustomerProfileScreen` |

A sequência é Home → Categorias → Carrinho → Checkout → Acompanhamento → Produto → Perfil, uma tela por vez. Nesta etapa somente a auditoria e o plano da Home estão autorizados; nenhuma tela está sendo implementada.

## Regras de reprodução

Reproduzir geometria, posição, dimensões relativas, margens, padding, espaçamentos, tipografia, pesos, tamanhos, cores, gradientes, dourado, preto, fundo claro, bordas, raios, sombras, ícones, header, logo, banners, cards, imagens, botões, navegação e hierarquia. A estrutura anteriormente aprovada da Home é uma base de trabalho, não homologação dos pixels atuais. Classificações e conclusões anteriores de aproximação não substituem esta regra.

Continuam reais e dinâmicos endereço, cliente, catálogo, preços, estoque, quantidade, pedido, status, prazo, frete, taxas, entregador e avaliações, quando estas existirem. Não copiar os valores ilustrativos dos JPEGs para o código ou para a base comercial.

Preservar pagamentos, PIX, BR/PY, estoque, autenticação, carrinho, cálculos financeiros, frete, horário, filtros comerciais, Firebase, Functions e segurança. A imagem não autoriza criar favorito, cupom, avaliação, contato com entregador ou qualquer função inexistente. Identificar a pendência antes de implementar, sem ação falsa ou controle meramente decorativo que pareça funcional.

Preservar escalabilidade de fonte, leitura, contraste, áreas de toque, privacidade e conteúdo permitido. Não adicionar permissões, SDKs ou coleta para reproduzir aparência. Não declarar conformidade Apple/Google ou aprovação de publicação com base apenas nesta reprodução visual.

## Auditoria atual

Ver [auditoria da Home e plano de correção](../../../../docs/home_official_visual_audit_2026-10-21.md). Os relatórios anteriores permanecem como histórico, não como novo critério de aceite.
