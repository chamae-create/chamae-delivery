# Auditoria anterior à implementação

Os dois projetos foram inspecionados antes de qualquer alteração desta retomada. Ambos já possuem mudanças locais; elas serão preservadas. Sem AGENTS.md localizado nos projetos.

| Área | Estado encontrado |
| --- | --- |
| Abertura | Firebase/sessão anônima na splash, depois catálogo diretamente |
| Splash | Logo existente, Loumak, fade/escala curtos, sem atraso mínimo |
| Endereço | Google Maps, busca manual e reverse geocoding; GPS solicitado ao abrir a tela |
| Destino | Pino central ajustável, coordenadas confirmadas por ação explícita |
| País | Country code estruturado; fallback excepcional no checkout |
| Persistência | Endereço e carrinho em memória; sem último endereço salvo |
| Sessão | Firebase Auth anônimo; pedidos obrigatoriamente associados ao customerUid |
| Verificação | Não há canal nem contrato de conta verificada |
| Chat | Existente, por pedido, com Functions/regras e listeners próprios |
| Perfil | Dados em memória, endereço e histórico da própria sessão |
| Acompanhamento | Timeline, resumo, pagamento/PIX e chat; sem PIN |
| PIN | Nenhuma estrutura implementada |
| Frete | R$ 10 no checkout/carrinho e FRETE_PEDIDO_CENTAVOS=1000 no backend |
| Distância | Sem cálculo de rota para cobrança; sem provedor definido |
| Origem Pit Stop V8 | Não foi encontrada coordenada aprovada. O fallback do mapa não será adotado como origem |
| Validação | Financeiro congelado em orderFinancials pelo backend, sem confiar no preço de produtos enviado pelo cliente |
| Admin | Flutter Web, claims/ProtectedAreaGate, sidebar e áreas de operações/catálogo/financeiro/administração; sem configuração de entrega |
| Remuneração | Fluxos existentes utilizam deliveryFee em repasses. Ativar tabela nova exige separar explicitamente remuneração, sem usar a nova tarifa automaticamente |

Decisões não tomadas: preços das faixas, piso anterior de R$ 8, provedor real de rota, canal/provedor de verificação e coordenadas aprovadas da loja. A infraestrutura nova deve falhar de forma explícita quando essas dependências forem necessárias e não estiverem configuradas. O frete legado será mantido para histórico e modo legado; não haverá ativação automática da tabela.
