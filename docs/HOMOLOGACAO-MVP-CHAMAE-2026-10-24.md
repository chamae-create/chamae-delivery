# Homologação oficial do MVP Chamaê Delivery — manual operacional

Data-base: 24/10/2026. Revisão documental 7 — fechamento KB-07 em 25/10/2026 com novas evidências fornecidas pelo responsável. Escopo: Pit Stop V8, single-store, Ponta Porã-MS ↔ Pedro Juan Caballero-Amambay. Este documento define critérios de aceite; **não declara o MVP homologado nem autoriza execução em produção**. As proteções locais de horário/país ([KB-03](KB-03-HORARIO-PAIS-BACKEND-2026-10-24.md)), cancelamento/compensações ([KB-04](KB-04-CANCELAMENTO-COMPENSACOES-2026-10-24.md)), contingência ([KB-05](KB-05-CONTINGENCIA-ENTREGA-2026-10-24.md)) e privacidade/conta ([KB-06](KB-06-PRIVACIDADE-APPLE-CONTA-2026-10-24.md)) permanecem PARCIAIS por dependências reais. [KB-07](KB-07-ANDROID-SIGNING-BUILD-2026-10-25.md): **RESOLVIDO LOCALMENTE / PENDENTE HOMOLOGAÇÃO GOOGLE PLAY**. Upload key oficial e backup com hash idêntico, configuração local e AAB release de 65.7 MB com certificado coincidente foram informados. Sem acesso operacional a produção; upload, Play App Signing e teste fechado não executados, gate Google Play não liberado.

Documento de campo: [checklist compacta](HOMOLOGACAO-MVP-CHAMAE-CHECKLIST-2026-10-24.md). Os mesmos 196 IDs aparecem nos dois arquivos. As repetições BR/PY, valores de fronteira, estados ou dispositivos descritos dentro de um caso são subexecuções desse ID: registrar uma linha de evidência por variação. Não somar subexecuções como novos cenários.

## 1. Estado atual e limites da evidência

| Área | Evidência local atual | Consequência para a homologação |
| --- | --- | --- |
| App Cliente | Flutter; Google/Apple; workspace por UID; consentimentos versionados; perfil e exclusão; checkout e tracking. pubspec declara 1.0.0+1. | Registrar o artefato efetivamente instalado e seu hash. Versão declarada não prova qual build está no aparelho. |
| Painel Lojista | Flutter Web/Desktop no repositório irmão; pubspec 1.0.0+1; Kanban, catálogo/estoque, frete, financeiro, caixa e ticket. | Conferir build/cache na máquina da Pit Stop; não usar só a aparência para identificar versão. |
| Backend | Functions Node 24; contratos na região southamerica-east1; Rules e financeiro privado em orderFinancials. | Identificar revisão/manifest de Functions, Rules e índices do ambiente de ensaio. Nada remoto foi consultado aqui. |
| Frete | Contrato schema 2 compartilhado com o painel; Google Routes; cotações privadas e snapshots congelados. Novos financeiros sem tabela válida falham. | Origem, preços, travelMode, segredo/API e rotas reais ainda precisam evidência externa. Relatos antigos de frete fixo não descrevem a implementação atual. |
| Estoque local | Pagamento na entrega incrementa reservedStock na reserva; liberação reduz reserva; finalização baixa stock. Webhook PIX confirmado pode baixar stock e marcar stockProcessingStatus processed. | Isso **não comprova** RESERVE físico/ACK Oracle. Há risco de dupla baixa ao combinar espelho Firebase e ponte física sem contrato demonstrado. |
| GrandChef/Oracle | Painel exibe PRO_CODIGO persistido e protege quantidade de produtos mapeados contra edição pelo formulário. Ponte/ledger físico não foi localizada nos módulos funcionais dos dois repositórios inspecionados. | RESERVE/RELEASE/COMMIT/RESTOCK abaixo são critérios obrigatórios do contrato solicitado, não uma afirmação de que o bridge já os cumpre. Identificar componente/revisão responsável antes dos testes E. |
| Operação da entrega | Kanban normal permite iniciar separação. Outbox courierDispatchRequests fica awaiting_integration. Área superadmin registra tentativa, retorno físico e reentrega manual pendente, com revisão/recibos/auditoria. Conclusão exige entrega integral e cobrança confirmadas; retorno/reentrega bloqueiam conclusão; reserva em rota e RESTOCK exigem retorno intacto autorizado. | Sem app motoboy no MVP, aprovar responsável real, conferência física e reconciliação. Reentrega executável, parcial/não retornável, refund/ACK externo continuam pendentes. Sem procedimento real aprovado, a cadeia está BLOQUEADA. |
| Financeiro | Painel usa Concluído + Pago + financialValidationStatus validated, com campos oficiais completos. Não reconstrói taxas históricas. | Legado sem validação continua legível e excluído do fechamento. “Compatível” não significa incluir qualquer legado. |
| Exclusão | Worker existente preservado; requisito Apple anterior ao apagamento, com recibo privado ligado à solicitação. Sem adaptador real, bloqueia Apple. UID/link e limpeza global reforçados; cache descartado após completed observado, com reinício do app. | Homologar provedores reais, evento implantado/retry e cache sem callback/app fechado. Recibo simulado não é revogação real. Pseudonimização não é anonimização irreversível. |
| Dispositivos/lojas | Android applicationId e iOS bundle ID br.com.loumak.chamae. Release sem fallback debug; upload key oficial fora do repo, backup com hash idêntico e key.properties configurado/protegido. Responsável informou AAB release de 65.7 MB e coincidência do certificado com a upload key via keytool -printcert -jarfile. Revogação Apple real permanece pendente. | KB-07 resolvido localmente; homologação Google Play pendente. Sem upload, Play App Signing ou teste fechado; gates Android/Google Play e Apple não liberados. Build local não comprova instalação ou aprovação de loja. |
| Histórico de testes | Antecedente: 174/174 Flutter completos e 3/3 + 8/8 conta. KB-06 registrou 414 Functions, 403 emulador completo, revalidação de 20 casos de conta/revogação e 74 Flutter afetados. As duas fixtures de checkout foram corrigidas em tarefa própria; KB-07 reexecutou pub get com lockfile, analyze sem issues e **209/209 Flutter completos**. | Evidência local não é execução física da rodada. As execuções antigas de 207/209 permanecem nos relatórios históricos; [correção das fixtures](CORRECAO-TESTES-CHECKOUT-2026-10-25.md). Nenhum resultado de campo/gate é preenchido por esses totais. |

Fontes locais principais, consultadas sem acessar bancos/serviços operacionais:

- [Frete de ponta a ponta](frete_ponta_a_ponta_2026-10-24.md), [consolidação cliente](APP-CLIENTE-CONSOLIDACAO-FINAL-2026-10-24.md) e [relatório de conta existente](EXCLUSAO-CONTA-E-CONFIRMACAO-PEDIDO-2026-10-24.md).
- [Contrato operacional](../functions/docs/operational-flow.md), [chat/impressão](../functions/docs/order-chat-and-printing.md), [Functions](../functions/index.js), [frete](../functions/delivery-service.js), [exclusão](../functions/customer-account.js), [Rules](../firestore.rules).
- [Horário](../lib/core/store_hours.dart), [checkout](../lib/screens/checkout_screen.dart), [critério de confirmação](../lib/core/order_confirmation_policy.dart), [workspace](../lib/data/customer_workspace.dart).
- [Consolidação do painel](../../chamae_admin/docs/consolidacao_painel_2026-10-24.md), [OrderFinance](../../chamae_admin/lib/order_finance.dart), [operações](../../chamae_admin/lib/order_operation.dart), [caixa](../../chamae_admin/lib/courier_settlements.dart), [ticket](../../chamae_admin/lib/thermal_ticket.dart) e [identidade de produto](../../chamae_admin/lib/product_identity.dart).

Os relatórios antigos registram o estado na data em que foram produzidos. Não copiar suas tarifas legadas, pressupostos de Auth anônimo ou instruções de deploy para esta sessão. A presente tarefa não altera nem finaliza relatórios anteriores.

## 2. Classificação de recursos e ambientes

| Classe | Significado | Quantidade de IDs |
| --- | --- | ---: |
| A | Pode ser executado integralmente só no notebook, com fixtures, doubles ou emuladores locais. Nenhum serviço real necessário. | 87 |
| B | Precisa do computador/ambiente operacional da Pit Stop V8. | 63 |
| C | Precisa de Android/iPhone real; simulador/teste widget não substitui. | 39 |
| D | Precisa de serviço externo real, por exemplo Google Routes, IdP, Mercado Pago ou console das lojas. Sandbox do provedor é serviço real de teste. | 51 |
| E | Precisa de Oracle/GrandChef/bridge real de homologação e de evidência física/ledger. | 32 |
| F | Precisa de impressora física/driver/papel. PDF/preview não aprovam esta classe. | 19 |
| G | Pós-MVP; fora dos gates atuais. | 4 |

Total: **196 cenários**, sendo 192 no escopo de lançamento e 4 pós-MVP. B–F podem se acumular no mesmo ID; a soma por classe não é o total de cenários. A é exclusiva e usa somente ambiente local. G não dispensa segurança básica e reconexão do MVP.

Ambientes devem constar em cada execução:

1. **LOCAL**: notebook, projeto demo, Firestore/Auth Emulator, preços e rotas sintéticos identificados como teste. Confirmar hosts locais antes de iniciar SDKs. Nenhum fallback para projeto real.
2. **HOMOLOGAÇÃO**: Firebase isolado explicitamente identificado, builds de ensaio e contas descartáveis; Google Routes autorizado; Mercado Pago **SANDBOX/TESTE**; Oracle/bridge de homologação apenas quando o operador autorizar. Registrar quais componentes são simulados.
3. **PRODUÇÃO CONTROLADA**: sessão futura separada, após sandbox e revisão, com autorização específica, operador presente, limite financeiro/quantidade e plano de compensação. PIX-13 pertence exclusivamente a essa sessão. **Não executar produção nesta tarefa.**

Não misturar token/conta Mercado Pago de teste com cobrança real, nem Firebase de ensaio com estoque produtivo por conveniência. Se não houver arranjo sandbox compatível com o fluxo PIX atual, marcar BLOQUEADO; não trocar silenciosamente por produção. Não alterar relógio, dados, regras, credenciais, integrações ou saldos de produção para simular falhas.

## 3. Pré-condições obrigatórias

Preencher antes de executar qualquer cenário. Um campo não comprovado bloqueia os casos que dependem dele.

- [ ] **PC-01 — Sessão**: ID da rodada, operador responsável, aprovador, contatos de suporte autorizados, data/hora de início, janela de término e escopo de países/plataformas. Registrar timestamps com offset e UTC; horário da loja é MS no contrato atual.
- [ ] **PC-02 — Artefatos**: versão/build do App Cliente, Painel, backend/Rules/índices e bridge; commit existente de referência, estado dirty, hash/manifest dos artefatos. Não criar commit para preencher o campo.
- [ ] **PC-03 — Ambiente**: projeto Firebase explícito, canais de distribuição/URLs, separação LOCAL/HOMOLOGAÇÃO/PRODUÇÃO CONTROLADA e prova de que a sessão não usa alias default inadvertidamente.
- [ ] **PC-04 — Acesso**: contas de cliente BR/PY, Google/Apple quando aplicável, operações, finance, catálogo e superadmin; matriz de autorização. Anotar só referências dos responsáveis; não inserir senha, token, chave, cookie, certificado privado ou credencial.
- [ ] **PC-05 — Frete**: versão/id da tabela ativa, published, schema 2, origem real aprovada Pit Stop V8, faixas/preços reais escolhidos pelo administrador, cobertura máxima vigente e travelMode explícito. Nada de preços fictícios ou origem deduzida do centro do mapa.
- [ ] **PC-06 — Serviços**: Google Routes/API/modo, Geocoding de país no servidor (KB-03) e Mercado Pago sandbox, webhook e correlação identificados por responsável. Não imprimir secrets. Distinguir API de mapa nativo, API Routes e comprovação de país; uma funcionar não comprova as outras.
- [ ] **PC-07 — Produtos**: IDs Firestore, PRO_CODIGO canônico, nomes, preços, ativo/inativo, produto restrito permitido para ensaio, quantidades aprovadas, estoque inicial físico/espelho/reservado e timestamp. Produto mapeado sem PRO_CODIGO explícito não está apto.
- [ ] **PC-08 — Operação**: horário MS 08:00 até a fronteira 00:00; dispositivos BR/PY, destinos consentidos dentro/fora da cobertura, método de recebimento/troco, regras de câmbio vigentes aprovadas e entregador real identificado. Sem cadastro real, não inventar courier.
- [ ] **PC-09 — Hardware/rede**: PC da loja e navegador/versão/zoom/resolução; Android intermediário e iPhone com modelo/SO/build; impressora 80 mm, 58 mm se suportada, driver/corte; Wi-Fi e conexão BR/PY quando aplicável.
- [ ] **PC-10 — Oracle restrito**: autorização escrita para a janela e produtos/quantidades; dono do bridge e revisão do protocolo; backup/snapshot feito pelo responsável do banco e sua evidência/recuperabilidade; baseline por PRO_CODIGO e controle das vendas de balcão concorrentes; ledger/ACK consultável. **Sem DDL.** Esta tarefa não acessou Oracle/GrandChef nem criou backup real.
- [ ] **PC-11 — Cancelamento/compensação**: contratos backend chamaeCancelarPedido e chamaeAutorizarDevolucaoPedido revisados/integrados ao procedimento autorizado; responsáveis e caminhos reais para cancelamento PSP/refund e estoque físico/ACK. Comandos locais não comprovam efeito no provedor ou Oracle. Não depender de edição livre de Firestore/SQL.
- [ ] **PC-12 — Aceite e interrupção**: metas de desempenho aprovadas antes de medir (inicialização, navegação, resposta de checkout, recursos de aparelho); critérios de parada e custódia de evidências; revisores financeiro/estoque/segurança. Sem meta aprovada, não inventar aprovação de performance.
- [ ] **PC-13 — Privacidade e publicação**: política pública aprovada, termos/consentimentos ativos, regras de idade por destino e abordagem de conferência na entrega aprovadas pela operação; política de retenção/revogação; signing e contas das lojas. Conferir regra vigente na submissão.

## 4. Execução segura e registro

Ordem sugerida: PC → casos A → provedores sandbox e endereço/rota reais autorizados → PC da loja/aparelhos/impressão → estoque físico controlado → ensaios E2E → conciliações → revisão dos gates → eventual PIX-13 em sessão de produção controlada especificamente autorizada → distribuição por plataforma.

Em cada caso: conferir a pré-condição; capturar baseline; executar passos uma vez; coletar resposta/estado; repetir apenas quando o cenário pedir idempotência; comparar antes/depois; preencher resultado e evidências. Caso negativo **PASSOU** quando a tentativa inválida foi recusada sem efeito indevido.

Falhas/ataques/replays usam harness local, sandbox ou mecanismo de laboratório autorizado, nunca edição oportunista do pedido real. Não incluir comandos de deploy/SQL/DDL ou credenciais nos anexos. Reenvio de webhook deve usar instrumento autorizado do provedor/harness; não forjar assinatura contra produção. Não simular pagamento duplicado fazendo duas cobranças reais.

Interromper imediatamente ao detectar dupla cobrança/baixa, estoque negativo, PII exposta, total divergente, pedido pago sem atendimento/compensação, DDL inesperado ou mistura de ambientes. Anotar IDs/horários, preservar logs saneados e acionar responsáveis. Não “corrigir” saldo por edição direta ou restaurar backup por cima de vendas ocorridas: compensação/recuperação precisa reconciliação e autorização do dono do sistema.

### Ficha por execução (copiar por ID/subvariação)

| Campo | Preenchimento |
| --- | --- |
| Cenário e subvariação | ID deste manual; país/moeda/limite/estado testado |
| Rodada/data/hora | Início/fim com offset e UTC |
| Responsável/revisor | Identidades funcionais; sem credenciais |
| Ambiente | LOCAL / HOMOLOGAÇÃO / PRODUÇÃO CONTROLADA; projeto e componente simulado/real |
| Build/commit | Cliente, painel, Functions/Rules/índices e bridge; hashes e dirty quando aplicável |
| Dispositivo | Modelo, SO, navegador, resolução/zoom e rede; para testes A, notebook/runner |
| Correlação | ID documental e amigável do pedido, quoteId/versão/faixa, requestId, PSP/evento e ledger/ACK quando aplicável |
| Resultado esperado | Critério desta linha e baseline de valor/quantidade aprovados |
| Resultado observado | Estados e deltas efetivos; não preencher apenas “ok” |
| Resultado | **PASSOU / FALHOU / BLOQUEADO / NÃO APLICÁVEL** |
| Evidência | Referência a screenshot, papel fotografado, log saneado, resposta oficial e comparação antes/depois |
| Observação/severidade | Motivo, ticket de falha, P0/P1/P2/P3, responsável e próxima ação; no N/A, justificativa/aprovador |

O campo de resultado começa em branco até a execução; isso não é um quinto status. Falta de acesso/equipamento/serviço/implementação/autoridade é **BLOQUEADO**, não PASSOU nem N/A. Marcar **FALHOU** quando o comportamento observado contrariar o esperado. N/A exige justificativa de escopo e aprovação; não encobre risco financeiro/estoque/segurança.

- **P0**: bloqueia lançamento; risco financeiro, estoque ou segurança/dados críticos.
- **P1**: bloqueia fluxo principal.
- **P2**: problema relevante com workaround explícito e aprovado.
- **P3**: cosmético/melhoria.

A severidade nas tabelas é a referência se o critério falhar. Ajuste somente com revisão e registro; não rebaixar para liberar gate. P0 ou P1 aberto bloqueia lançamento.

### Pacotes mínimos de evidência

**EV-UI**: captura da tela e estado, build/aparelho/horário; screenshot sem dados pessoais de terceiros. **EV-PED**: antes/depois de orders e orderFinancials via acesso autorizado, campos relevantes e IDs saneados; cliente não ganha acesso privado para testar. **EV-ROT**: origem/destino consentidos em anexo restrito, request/response de rota sem chave, metros, transporte, quoteId, versão/faixa/preço. **EV-PIX**: modo TESTE/REAL explícito, IDs oficiais e eventos, status/valor/assinatura validada pelo servidor; não anexar token. **EV-EST**: PRO_CODIGO em anexo interno, saldo físico/espelho/reserva antes/depois, q, timestamps, chave e ACK/ledger de cada operação. **EV-IMP**: foto do papel com largura/driver/via e legibilidade, além de preview se útil.

Toda linha exige a ficha completa; adicionar pacote compatível com a ação (UI → EV-UI; pedido/financeiro/conta → EV-PED; rota → EV-ROT; pagamento → EV-PIX; estoque físico → EV-EST; impressão → EV-IMP). Guardar anexos pessoais, pedidos e códigos internos em acesso restrito; compartilhar versões saneadas.

## 5. Contratos que o operador deve conferir

### Frete

Coleções: deliveryConfiguration/current com mode routeBands, activeVersion e travelMode operacional; deliveryPricingVersions/{id} com versão/publicação/autor/tabela; deliveryConfiguration/draft não autoriza preço. Faixas: minExclusiveMeters, maxInclusiveMeters, priceCents, enabled, order; tabela schemaVersion 2, minimumPolicy replace, origin e maxDistanceMeters. Cobertura até 30.000 m, escolhida pela operação; não assumir que todos os 30 km estão servidos.

A primeira faixa inclui 0; demais (mínimo, máximo]. As fronteiras exatas são ensaiadas **localmente** com metros sintéticos; não fabricar resposta real de Google Routes nem escolher endereço só para alegar que retornou exatamente o limite. Preço zero somente quando explicitamente aprovado na tabela; nunca fallback.

Snapshot oficial em orders/orderFinancials: deliveryFee, deliveryDistanceMeters, deliveryDistanceUnit m, deliveryDistanceSource route, deliveryPricingVersion, deliveryAppliedBand, routingProvider, deliveryQuotedAtMs e deliverySnapshot com configurationVersion, origin, destination e appliedBand. Após exclusão de conta, destination pode ser removido pela minimização sem mudar os campos financeiros de rota.

Cotação privada é temporária (validade atual de cinco minutos), vinculada ao UID/destino e usada por um pedido. O backend revalida a versão ativa e a faixa no aceite. Não confiar em distance/fee/version enviados pelo app. Tabela nova ou erro de Routes não recalculam pedido já congelado.

### Horário, país e pagamentos

Contrato local: horário MS baseado em UTC-4, aberto a partir de 08:00 e fechado em 00:00. Isso descreve o código, não uma conclusão sobre a legislação/fuso do PY. Para bordas, usar relógio injetado/harness/testes existentes no notebook; não mudar relógio de produção nem o relógio do banco.

Endereço confirmado BR/PY e coordenadas válidas devem atravessar quote, pedido e elegibilidade. A lacuna de autoridade de servidor encontrada na auditoria inicial recebeu implementação local no [relatório KB-03](KB-03-HORARIO-PAIS-BACKEND-2026-10-24.md): Rules e guard no preparo compartilhado de PIX/reserva; relógio America/Campo_Grande; prova privada de país obtida por Geocoding, vinculada ao ponto/UID/pedido. Também são recusados deliveryLocation e aliases country contraditórios. Houve 374 testes Functions, 343 de emulador e 42 Flutter afetados aprovados; analyze sem issues. **KB-03 permanece PARCIAL**: serviço/segredo geográfico real, destinos BR/PY/fronteira e revisão implantada ainda não foram homologados. HOR-07/END-09/DIN-08 têm evidência automática local no relatório; seus campos de execução operacional continuam sem aprovação nesta rodada.

Split atual suporta **duas ou três parcelas de dinheiro**, em BRL/PYG/USD; não oferece split PIX/cartão como contrato aprovado. As conversões já codificadas e taxas distintas de troco devem ser registradas/aprovadas para a rodada; não criar cotação comercial nova neste documento. Conferir campos cashCurrency, cashTendered, changeBRL e paymentParts/splitChangeBRL no pedido. Total contábil canônico continua BRL.

“Pedido confirmado” de dinheiro não significa dinheiro recebido: exige financeiro aceito; permanece Pendente na entrega até recebimento/conclusão validada. PIX precisa confirmação oficial e estado coerente; QR gerado, write local, clique em pagar e total da prévia não provam pagamento. _hasPendingWrites é metadado local de bloqueio, não campo financeiro a gravar.

### Estoque físico e cancelamento

O contrato a homologar é:

1. **RESERVE**: debita q fisicamente uma vez, com chave estável e ACK.
2. **RELEASE**: antes de COMMIT, devolve a reserva uma vez.
3. **COMMIT**: exclusivamente lógico; **não debita fisicamente outra vez**.
4. **RESTOCK**: somente após COMMIT válido, devolução autorizada e quantidade conferida; retorna uma vez.

Identificar a chave real do bridge/ledger e seu vínculo pedido + PRO_CODIGO + operação + revisão antes do ensaio. Não inventar nomes de coleções Oracle, colunas ou formato de ACK. Se o componente não estiver disponível, os casos E ficam BLOQUEADOS.

Evidenciar conservação do saldo: saldo final = saldo inicial − RESERVEs físicos únicos + RELEASEs físicos únicos + RESTOCKs físicos únicos − vendas de balcão independentes autorizadas, acrescido de outros movimentos reais que o responsável registrar. COMMIT tem delta físico zero. reservedStock/salesCount e espelho Firebase precisam ser interpretados pelo dono da integração; não somar dois saldos como se fossem dois estoques físicos.

No código atual, PIX automático prepara financeiro antes de chamar Mercado Pago e a baixa Firebase aparece no webhook confirmado; não foi demonstrada uma reserva física anterior à cobrança. Portanto, “PIX pago e requires_review depois” **não satisfaz** o requisito de não cobrar quando a reserva necessária falhou. FAL-01 e EST/FAL reais são bloqueadores até a garantia estar comprovada.

Descarte de proposta não cancela pedido já criado. A etapa KB-04 acrescentou callables administrativas de cancelamento e devolução integral, ledger/auditoria e proteção contra webhook/POST tardios. RELEASE/RESTOCK locais têm evidência transacional; produtos PRO_CODIGO e estados físicos não comprovados falham fechados. PIX pendente registra verificação no PSP; PIX pago permanece Pago e requer restituição separada. Concluído não admite cancelamento simples; devolução preserva a venda histórica. **388 testes Functions, 364 de emulador e 40 Flutter afetados aprovados, analyze sem issues**, conforme [relatório KB-04](KB-04-CANCELAMENTO-COMPENSACOES-2026-10-24.md). Cancelar PSP, cancelar pedido, RELEASE, estorno e RESTOCK permanecem efeitos distintos: refund/void real, ponte/ACK, comissão externa e procedimento/painel ainda pendem. Não liberar gate nem testar editando status/SQL.

### Kanban, entrega e caixa

Cadeia a observar: Novo → Em Separação → (Aguardando Retirada quando atribuído, ainda em separação) → Saiu para Entrega → Concluído. “Aguardando retirada” pode ser apresentação do vínculo/estado de despacho, não uma quinta coluna obrigatória. PIX só separa após Pago e stockProcessingStatus processed; dinheiro que exige reserva precisa reserved; revisão financeira/estoque bloqueia.

Não exigir app motoboy/GPS/ETA no MVP, nem criar entregador fictício. A contingência atual exige superadmin, cadastro real ativo, motivo de 10–500 caracteres, confirmation igual a CONFIRMAR {ID documental} e confirmação final; deixa operationalContingencyAudit e ledger de operação. Operador comum não deve ganhar acesso amplo para viabilizar teste.

KB-05 acrescentou tentativas frustradas e condições de retorno em `orderDeliveryIncidents`, com eventos privados e recibos transacionais. País/endereço, frete e financeiro original não são alterados. `deliveryConfirmed` e, se ainda não Pago, `collectionConfirmed` são exigidos na conclusão com revisão corrente. Reserva em rota não é liberada antes de retorno integral intacto autorizado; RESTOCK KB-04 também exige essa declaração física separada. Parcial/não retornável falham fechados para compensação integral. Reentrega futura é somente pendência manual, sem novo despacho/frete/cobrança. Painel congela comando no retry e reconsulta histórico após reinício. Os testes locais constam do [relatório KB-05](KB-05-CONTINGENCIA-ENTREGA-2026-10-24.md); não comprovam atendimento físico, entrega, refund ou estoque externo. Homologar ausência/endereço/recusa/cobrança/transporte, retorno, perda de rede e concorrência como subexecuções de KAN-09/10 e E2E-04, sem marcar resultados por evidência apenas unitária.

courierPaid significa repasse do motoboy; paymentStatus é recebimento do cliente. Acerto relê valores oficiais e mesmo UID real; um lote inválido não pode ser parcialmente ignorado. Registro de impressão conta solicitações, não comprova saída de papel.

### Mapeamento financeiro e privacidade

| Conceito solicitado | Campo/contrato atual a conferir |
| --- | --- |
| Subtotal / frete | itemsTotal / deliveryFee |
| Taxa cliente / lojista | customerFee / merchantFee |
| Líquido lojista / plataforma | merchantNet / platformFee |
| grandTotal conceitual | totalBRL; totalCentavos privado quando disponível. Não introduzir grandTotal no banco. |
| validationStatus conceitual | financialValidationStatus, com validated; não criar alias persistido. |
| Recebimento e conclusão | paymentStatus Pago + status Concluído, campos oficiais completos |
| Estoque PIX / dinheiro | processed no processamento PIX; reserved, released ou finalized na reserva de entrega, conforme transição |
| Preservação de legado | Ler snapshots existentes; sem retrocalcular taxa, rota, câmbio ou total. Sem validated, não alargar fechamento. |

Exclusão é limpeza/minimização de PII conhecida, remoção de subcoleções e pseudonimização do vínculo de pedidos fechados, preservando valores/itens/distância/faixa/versão e trilhas financeiras/operacionais. Tombstone de controle por UID e dados retidos permanecem privados. Não chamar isso de anonimização irreversível ou inventar prazo legal. Política de retenção, backups/logs/cache de aparelho e revogação do vínculo Apple precisam validação própria.

PIN nunca em papel, QR de rota, log, chat, payload de projeção ou tela pública. O fluxo existente de **revelar o próprio PIN após autenticação** é uma exceção funcional de acesso do titular; não declarar falsamente que nenhum PIN pode ser visto pelo próprio cliente. PRO_CODIGO pode constar em evidência interna de estoque e no painel, nunca cliente/ticket.

## 6. Catálogo executável de cenários

Pré-condições PC e ficha da seção 4 valem em todas as linhas. Resultado: preencher **PASSOU/FALHOU/BLOQUEADO/NÃO APLICÁVEL** na coluna R e apontar evidência na ficha por ID. Os casos D/B/E/F exigem recursos reais descritos; uma fixture local não os aprova. Cabeçalho “sandbox” não autoriza produção; PIX-13 é explicitamente separado.

### HOM — Home e navegação

| ID / cenário | Classe | Pré-condição específica | Executar | Critério de PASSOU (anexar evidência) | Sev. | R |
| --- | --- | --- | --- | --- | --- | --- |
| HOM-01 — Carregamento e falha recuperável | A | Catálogo local e resposta de erro controlada | Abrir Home vazia, carregada, offline e acionar retry | Estados claros, sem espera infinita; retry recupera sem duplicar itens | P1 | ____ |
| HOM-02 — Categorias e busca | A | Catálogo sintético com categorias e nomes distintos | Filtrar, pesquisar com/sem resultado e limpar busca | Resultados coerentes; categorias comerciais bloqueadas não expostas | P1 | ____ |
| HOM-03 — Promoções e produtos | A | Produtos promocionais e comuns de teste | Percorrer seções e abrir detalhes | Preço e identidade do produto correspondem ao catálogo; sem oferta inventada | P2 | ____ |
| HOM-04 — Imagens e vídeo indisponíveis | A | URLs simuladas válidas, quebradas e lentas | Carregar cards e detalhes e falhar mídia | Fallback visual preserva ações; falha de mídia não bloqueia compra | P2 | ____ |
| HOM-05 — Aberta e fechada na Home | A | Instantes controlados de HOR-01 a HOR-05 | Navegar nas duas condições | Sinalização e catálogo coerentes; CTA não promete atendimento fechado | P1 | ____ |
| HOM-06 — Carrinho e navegação de retorno | A | Sacola com dois produtos sintéticos | Abrir sacola/perfil, voltar e reabrir | Seleção e quantidades preservadas; rotas sem tela perdida | P1 | ____ |
| HOM-07 — Tela pequena e texto ampliado | A | Viewport 320 px e escala 1,6/2,0 | Percorrer Home, produto, sacola e perfil | Sem overflow impeditivo; ações alcançáveis por rolagem | P2 | ____ |
| HOM-08 — Uso em aparelho intermediário | C | Modelo e SO reais registrados | Rolar catálogo, abrir imagens, alternar telas e retomar app | Sem crash/ANR ou bloqueio; medir tempos observados contra meta aprovada em PC-12 | P1 | ____ |

### PRO — Produto

| ID / cenário | Classe | Pré-condição específica | Executar | Critério de PASSOU (anexar evidência) | Sev. | R |
| --- | --- | --- | --- | --- | --- | --- |
| PRO-01 — Disponível e preço oficial | A | Produto ativo com estoque e preço conhecidos | Abrir detalhe, adicionar uma unidade | Nome, imagem, preço e quantidade consistentes | P1 | ____ |
| PRO-02 — Estoque zero e insuficiente | A | Produto com disponibilidade 0 e depois 1 | Tentar comprar e exceder disponibilidade | Interface bloqueia/explica; aceite definitivo depende do backend | P0 | ____ |
| PRO-03 — Ativo/inativo e removido | A | Fixture muda estado após detalhe aberto | Desativar/remover na fonte local e tentar adicionar | Produto indisponível não entra silenciosamente no pedido | P1 | ____ |
| PRO-04 — Quantidade máxima | A | Limite efetivamente aplicado e estoque registrados | Aumentar até o limite e tentar ultrapassar | Limite respeitado, sem quantidade negativa ou estouro | P1 | ____ |
| PRO-05 — Adicionar/remover e identidade | A | Dois produtos com nomes parecidos e IDs distintos | Adicionar ambos e remover um | Quantidades alteram apenas o produto correto; PRO_CODIGO não aparece ao cliente | P1 | ____ |

### CAR — Carrinho

| ID / cenário | Classe | Pré-condição específica | Executar | Critério de PASSOU (anexar evidência) | Sev. | R |
| --- | --- | --- | --- | --- | --- | --- |
| CAR-01 — Adicionar, retirar e alterar quantidade | A | Sacola local vazia | Adicionar dois produtos, editar e zerar um | Subtotal e quantidades corretos; estado vazio recuperável | P1 | ____ |
| CAR-02 — Subtotal e taxas da prévia | A | Preços e cotação sintéticos explícitos | Conferir itens, frete, taxa e total exibidos | Prévia identificável e coerente; nenhum preço de teste vira configuração comercial | P0 | ____ |
| CAR-03 — Atualização de estoque | A | Disponibilidade muda durante a sacola | Reduzir estoque antes de confirmar | Quantidade inválida exige ajuste; falha não se apresenta como sucesso | P0 | ____ |
| CAR-04 — Produto indisponível após inclusão | A | Produto desativado/removido após inclusão | Reabrir sacola e tentar checkout | Problema e ação de remoção claros; nenhuma compra silenciosa | P1 | ____ |
| CAR-05 — Recuperação de sacola/proposta | A | Workspace isolado com tentativa pendente | Fechar/reabrir processo e repetir confirmação | Mesma tentativa reconciliada; sacola não consumida antes do aceite oficial | P1 | ____ |
| CAR-06 — Consumo idempotente da sacola | A | Pedido aceito e novas unidades adicionadas depois | Repetir completeOrder e eventos de confirmação | Compra descontada uma vez; adições posteriores preservadas | P0 | ____ |

### PER — Perfil, autenticação e documentos

| ID / cenário | Classe | Pré-condição específica | Executar | Critério de PASSOU (anexar evidência) | Sev. | R |
| --- | --- | --- | --- | --- | --- | --- |
| PER-01 — Google e vínculo de sessão antiga | C+D | Conta de teste Google; UID anterior anotado se houver | Entrar, sair e vincular sessão antiga quando aplicável | Identidade correta e UID preservado no vínculo; nenhuma mistura entre clientes | P1 | ____ |
| PER-02 — Apple e retorno da sessão | C+D | iPhone e Sign in with Apple autorizados | Entrar, cancelar e retornar do provedor | Cancelamento não cria sucesso; sessão pertence à conta escolhida | P1 | ____ |
| PER-03 — Perfil, termos e privacidade | A | Política versionada e perfil em ambiente isolado | Abrir documentos, aceitar, atualizar política e repetir | Consentimento/DOB/versionamento coerentes; documento ausente bloqueia compra necessária | P1 | ____ |
| PER-04 — Retry, logout e sessão expirada | A | Auth/Firestore com erro e troca de UID simulados | Falhar carregamento, tentar novamente e trocar conta | Erro acionável; dados antigos limpos; nenhuma consulta de pedido alheio | P1 | ____ |
| PER-05 — Elegibilidade BR/PY e produto restrito | A | Política de teste com mínimos por país aprovados para o ensaio | Testar abaixo/acima do mínimo e ausência de configuração | Backend usa política do país do destino; ausência falha segura; DOB declarada não é documento verificado | P0 | ____ |

### HOR — Loja aberta/fechada — relógio operacional MS

| ID / cenário | Classe | Pré-condição específica | Executar | Critério de PASSOU (anexar evidência) | Sev. | R |
| --- | --- | --- | --- | --- | --- | --- |
| HOR-01 — 07:59 fechada | A | Instante 2026-10-24T11:59:00Z, correspondente a 07:59 MS no contrato local | Simular relógio na harness existente e tentar checkout | Catálogo navegável; checkout bloqueado; abre às 08:00 (MS) | P1 | ____ |
| HOR-02 — 08:00 abertura | A | Instante 2026-10-24T12:00:00Z | Repetir a navegação com demais pré-requisitos válidos | Bloqueio de horário removido; nenhum bloqueio financeiro é dispensado | P1 | ____ |
| HOR-03 — Durante a operação | A | Instante de meio de turno MS aprovado | Navegar e iniciar checkout | Loja aberta e fluxo normal | P1 | ____ |
| HOR-04 — 23:59 ainda aberta | A | Instante 2026-10-25T03:59:00Z | Abrir checkout antes do fechamento | Contrato atual permite iniciar compra até a fronteira de 00:00 | P1 | ____ |
| HOR-05 — 00:00 fechada | A | Instante 2026-10-25T04:00:00Z | Tentar nova compra e retomar pedido anterior | Nova compra bloqueada; pedido já aceito continua rastreável | P1 | ____ |
| HOR-06 — Virada com checkout aberto e fuso do aparelho | A | Tela aberta às 23:59; relógios simulados em fusos distintos | Avançar para 00:00 antes de confirmar | Confirmação reavalia horário MS; relógio do dispositivo não redefine a operação | P1 | ____ |
| HOR-07 — Tentativa de contornar horário pela API | A | Emulador isolado e proposta idêntica à válida | Enviar proposta fora do horário sem passar pela UI | Bloqueio de servidor antes de PIX/reserva/financeiro; evidência automática local no relatório KB-03; registrar build e execução desta rodada | P1 | ____ |

### END — Endereço Brasil/Paraguai

| ID / cenário | Classe | Pré-condição específica | Executar | Critério de PASSOU (anexar evidência) | Sev. | R |
| --- | --- | --- | --- | --- | --- | --- |
| END-01 — Brasil válido | C+D | Destino BR real consentido, dentro da área; origem aprovada | Confirmar rua, número, cidade, referência e ponto no mapa | País BR, endereço e coordenadas persistidos correspondem ao destino confirmado | P1 | ____ |
| END-02 — Incompleto ou país ausente | A | Fixtures de endereço incompleto e país desconhecido | Tentar confirmar/endereço e criar proposta | Solicitar correção; não adivinhar país ou coordenadas | P1 | ____ |
| END-03 — Coordenadas inválidas | A | NaN, limites excedidos e confirmed false no emulador | Tentar cotação e aceite | Servidor recusa; nenhuma rota/frete inventado | P0 | ____ |
| END-04 — Brasil fora de cobertura | D | Destino BR real além do alcance ativo | Solicitar rota e tentar checkout | Fora da área, sem aceite ou tarifa fixa alternativa | P0 | ____ |
| END-05 — Mudança após cotação | A | Dois destinos/paises e quote privado local | Trocar destino após preview e reenviar quote antigo | Cotação invalidada; servidor rejeita vínculo antigo e exige nova rota | P0 | ____ |
| END-06 — Paraguai válido | C+D | Destino PY real autorizado dentro da cobertura | Confirmar endereço e concluir pedido de ensaio | País PY preservado em endereço, snapshot de destino e elegibilidade | P1 | ____ |
| END-07 — Rota transfronteiriça real | B+C+D | Origem Pit Stop e destino PY com trajeto aprovado | Comparar resposta de Routes com mapa e percurso operacional autorizado | Rota utilizável pela fronteira; registrar rota/metros; ausência de rota bloqueia, sem linha reta | P1 | ____ |
| END-08 — Paraguai fora da cobertura | D | Destino PY real além do alcance | Cotar e tentar confirmar | Mesmo bloqueio seguro de cobertura do BR | P0 | ____ |
| END-09 — Troca de país e meios de pagamento | A | Checkout BR com maquininha selecionada | Trocar BR para PY e voltar; tentar payload PY com cartão no emulador | PY não admite cartão na entrega; preservar regras BR; ausência de defesa servidor gera KB-03 | P1 | ____ |

### FRT — Frete e Google Routes

| ID / cenário | Classe | Pré-condição específica | Executar | Critério de PASSOU (anexar evidência) | Sev. | R |
| --- | --- | --- | --- | --- | --- | --- |
| FRT-01 — Origem oficial e transporte | B+D | Coordenadas reais aprovadas da Pit Stop e travelMode explícito | Conferir painel, versão publicada e request de rota autorizado | Mesma origem no contrato/snapshot; mapa ilustrativo não é origem financeira | P0 | ____ |
| FRT-02 — Distância real e faixa publicada | D | Tabela válida com preços reais aprovados, provedor real autorizado | Cotar destino e comparar metros retornados, faixa e frete | Preço da faixa ativa; distância de rota, unidade m e provedor identificados | P0 | ____ |
| FRT-03 — Primeira faixa e distância zero | A | Tabela sintética local com primeiro limite conhecido | Ensaiar 0 e primeiro valor positivo no resolvedor | Zero pertence à primeira faixa se rota válida; zero não substitui erro do provedor | P0 | ____ |
| FRT-04 — Início, fim e transição de faixas | A | Limites sintéticos M e próxima faixa | Testar M-1, M e M+1 metros e mínimo de cada faixa | Primeira inclui 0; demais (minExclusive,maxInclusive]; M pertence à faixa que termina em M | P0 | ____ |
| FRT-05 — Granularidade e limite técnico | A | Fixtures locais de 100 m e faixas maiores até 30.000 m | Validar publicação/seleção e lacunas/sobreposições | Até 300 faixas; sem arredondar rota para trocar faixa; tabela incoerente recusada | P0 | ____ |
| FRT-06 — Máximo e acima da área | A | Alcance ativo L de teste | Testar L e L+1 no servidor | L aceito na última faixa; L+1 rejeitado; limite pode ser menor que 30 km | P0 | ____ |
| FRT-07 — Tabela ausente/inativa/inválida | A | Configuração isolada sem ponteiro, não publicada, faixa desabilitada ou preço inválido | Cotar e criar financeiro novo em cada estado | Falha segura sem total final ou checkout liberado; não criar toggle inexistente no painel | P0 | ____ |
| FRT-08 — Versão antiga/rascunho | A | Versão anterior publicada e rascunho isolado | Reusar quote de versão superada e salvar sem publicar | Rascunho não altera cobrança; versão antiga não impõe autoridade ao servidor | P0 | ____ |
| FRT-09 — Tabela alterada entre prévia e aceite | A | Quote local válido e nova versão publicada no ensaio | Confirmar proposta antiga após publicação | Exigir nova cotação; financeiro antigo já congelado não é recalculado | P0 | ____ |
| FRT-10 — Indisponibilidade e timeout reais | D | Sandbox/homologação com injeção de falha do provedor autorizada | Simular timeout/erro sem alterar chave de produção | Erro recuperável, nenhuma distância/frete fabricado; retry cria resultado rastreável | P0 | ____ |
| FRT-11 — Sem Haversine ou tarifa fixa | A | Provedor local lança erro e configuração ausente | Executar fluxos de cotação e criação financeira novos | Nenhum fallback silencioso Haversine, R$ 8/R$ 10 ou outro preço legado | P0 | ____ |
| FRT-12 — Adulteração e uso único de quote | A | Dois clientes/destinos e cotações privadas isoladas | Alterar fee/distância/versão e reusar quote em outro pedido/UID | Backend rejeita ou usa seus dados oficiais; cotação não autoriza outro dono/destino/pedido | P0 | ____ |
| FRT-13 — Snapshot congelado e preservação | A | Pedido aceito com financeiro oficial local | Conferir campos, publicar nova tabela e reabrir pedido | orders e orderFinancials preservam fee, metros, m, route, versão, faixa, origem e provedor; histórico intacto | P0 | ____ |
| FRT-14 — Publicação, permissões e histórico | A | Painel isolado com superadmin e perfis negados | Salvar rascunho, publicar explicitamente e repetir requestId | Autor/data/versão confiáveis; retry sem nova ativação indevida; cliente/finance/catálogo não publicam | P0 | ____ |

### PIX — PIX Mercado Pago — sandbox

| ID / cenário | Classe | Pré-condição específica | Executar | Critério de PASSOU (anexar evidência) | Sev. | R |
| --- | --- | --- | --- | --- | --- | --- |
| PIX-01 — Criação após validações exigidas | D | Conta e aplicação Mercado Pago de TESTE isoladas; FRT e FAL aprovados | Criar proposta PIX com total oficial | Uma cobrança vinculada ao pedido; não confundir financeiro validado com ACK de reserva física; ver KB-02 | P0 | ____ |
| PIX-02 — QR e copia e cola | C+D | PIX de sandbox gerado | Exibir QR, copiar código e validar leitura em aparelho | Código corresponde à cobrança e valor oficial; sem QR de outra conta | P1 | ____ |
| PIX-03 — Ticket de PIX pendente | B+D+F | Pedido PIX ainda pendente e impressora | Imprimir antes de pagamento | Ticket não declara PAGO; não despachar/separar como PIX confirmado | P0 | ____ |
| PIX-04 — Pagamento e webhook oficial | D | Cobrança de sandbox e notificação de teste pelo canal autorizado do provedor | Confirmar pagamento e acompanhar consulta oficial do servidor | paymentStatus Pago só após confirmação oficial de valor/identidade; registrar origem e IDs de correlação | P0 | ____ |
| PIX-05 — Confirmação do cliente | A | Snapshots locais: pendente, Pago sem financeiro, revisão e aceito | Emitir cada snapshot, incluindo pendingWrites e mudança de UID | Celebração/callback/sacola somente no aceite oficial; snapshot incompleto não confirma compra | P0 | ____ |
| PIX-06 — Retry de criação | D | Mesma tentativa e chave de idempotência no sandbox | Repetir solicitação após perda da resposta | Mesmo vínculo financeiro/cobrança; sem nova cobrança por clique repetido | P0 | ____ |
| PIX-07 — Webhook duplicado e fora de ordem | D | Entrega de eventos controlada em sandbox, IDs anotados | Reentregar notificação e evento antigo depois de confirmado | Pagamento/estoque aplicados uma vez; evento velho não regride estado aceito | P0 | ____ |
| PIX-08 — Tentativa de pagamento/cobrança duplicada | D | Cobrança sandbox já confirmada | Repetir ação suportada de pagamento/criação com mesma tentativa | Sem débito/baixa local em duplicidade; não pedir segundo pagamento real; divergência exige revisão | P0 | ____ |
| PIX-09 — Expirado e cancelado | D | Cobranças de teste expiradas e canceladas pelo fluxo autorizado | Aguardar notificação e reabrir checkout/tracking | Não pagos, sem falsa confirmação; cancelar pedido e estornar são operações distintas | P0 | ____ |
| PIX-10 — Valor/identidade incorretos | A | Respostas oficiais simuladas com total, moeda, external_reference ou ID divergente | Entregar eventos à harness local | Rejeição/revisão; não marcar Pago nem movimentar estoque como venda válida | P0 | ____ |
| PIX-11 — Assinatura e erro temporário do webhook | A | Harness local com assinatura inválida e falha consultando provedor | Enviar notificação e repetir entrega legítima | Inválida não muda pedido; erro temporário não vira sucesso financeiro; retry seguro | P0 | ____ |
| PIX-12 — Conferência final dos quatro eixos | B+D+E | PIX sandbox homologado e bridge/estoque controlado autorizado | Conferir pagamento, status, financeiro privado e razão de estoque físico/Firebase | Total único; PIX processed quando aplicável; sem dupla baixa; sem avanço se revisão | P0 | ____ |
| PIX-13 — PIX em produção controlada — sessão separada | B+C+D+E+F | Sandbox aprovado, gates prévios e autorização humana específica para produção futura | Executar futuramente um único pagamento real com limite/contas/operador aprovados e reconciliação | Confrontar comprovante do provedor, pedido, ledger físico e financeiro; não executar nesta tarefa | P0 | ____ |

### DIN — Dinheiro e pagamento na entrega

| ID / cenário | Classe | Pré-condição específica | Executar | Critério de PASSOU (anexar evidência) | Sev. | R |
| --- | --- | --- | --- | --- | --- | --- |
| DIN-01 — BRL valor exato | A | Financeiro local válido e declaração BRL exata | Confirmar dinheiro e conferir proposta/aceite | Pedido aceito com Pendente na entrega, reserva exigida e sacola consumida uma vez | P0 | ____ |
| DIN-02 — Valor insuficiente e inválido | A | Total oficial local conhecido | Testar abaixo do total, zero, negativo e valor não finito | Interface e backend recusam insuficiente/inválido; nenhuma cobrança/baixa indevida | P0 | ____ |
| DIN-03 — BRL com troco | B+F | Pedido de teste e numerário autorizado | Declarar cédula maior; conferir ticket e troco operacional | Troco em BRL e valor a receber claros; total financeiro não aumenta | P0 | ____ |
| DIN-04 — PYG e arredondamento | B+C+F | Conversões vigentes do build aprovadas pela operação | Declarar PYG exato e excedente, imprimir e conferir troco | Conversão/arredondamento conforme contrato persistido; troco em BRL, sem buscar câmbio inventado | P0 | ____ |
| DIN-05 — USD e troco | B+C+F | Conversões de compra e troco aprovadas | Repetir exato, insuficiente e excedente USD | Compra e devolução aplicam regras atuais distintas quando previstas; troco em BRL | P0 | ____ |
| DIN-06 — Split permitido | A | Total local e duas/três parcelas exclusivamente dinheiro | Dividir entre BRL/PYG/USD, editar/remover parcelas | Soma oficial suficiente; teto três parcelas; sem marcar Pago antes de recebimento | P0 | ____ |
| DIN-07 — Split proibido/inconsistente | A | Payload local com PIX/cartão em split, uma/quatro parcelas ou soma menor | Tentar validação por servidor | Recusar combinações não suportadas; UI não amplia contrato backend | P0 | ____ |
| DIN-08 — PY sem cartão e BR preservado | A | Destinos BR/PY isolados | Selecionar pagamentos nos dois países e enviar cartão PY por harness | Cartão na entrega ausente em PY; opções BR preservadas; falha autoritativa documentada em KB-03 | P1 | ____ |
| DIN-09 — Reserva e conclusão operacional | B+E | Pedido dinheiro validado, entregador real e contingência autorizada | Reservar, separar, entregar e concluir após recebimento conferido | ACK único físico; finalizar sem segundo decremento; só então Pago/Concluído no fluxo vigente | P0 | ____ |
| DIN-10 — Retomada após desconexão | A | Tentativa local dinheiro com resposta perdida | Reabrir e reconciliar sem gerar novo ID | Um pedido/reserva; nenhuma confirmação antes de financeiro validado | P0 | ____ |

### EST — Estoque físico — execução restrita

| ID / cenário | Classe | Pré-condição específica | Executar | Critério de PASSOU (anexar evidência) | Sev. | R |
| --- | --- | --- | --- | --- | --- | --- |
| EST-01 — Baseline e identidade canônica | B+E | Autorização Oracle, responsável e backup/evidência PC-10 completos | Anotar PRO_CODIGO, ID Firestore, quantidade e timestamp antes de ação | Mapeamento explícito único; sem deduzir por nome/barcode; saldo físico e espelho conhecidos | P0 | ____ |
| EST-02 — RESERVE único e ACK | B+E | Baseline conhecido; bridge homologado e quantidade q aprovada | Criar um pedido autorizado e acompanhar operação/ACK | Uma única subtração física q; operação ligada ao pedido/PRO_CODIGO; ACK persistido | P0 | ____ |
| EST-03 — RESERVE repetido e ACK perdido | B+E | Mesma operação já aplicada e chave estável | Reentregar exatamente a operação; simular perda do ACK só em laboratório autorizado | Nenhuma segunda subtração; ACK recuperado pela mesma identidade | P0 | ____ |
| EST-04 — RELEASE antes do COMMIT | B+E | Reserva confirmada, sem COMMIT | Cancelar pelo caminho autorizado e repetir a liberação | Retorno físico q uma vez; release sem reserva válida não cria estoque | P0 | ____ |
| EST-05 — COMMIT somente lógico | B+E | Reserva física confirmada e venda apta à conclusão | Concluir e repetir o COMMIT | Saldo físico não muda no COMMIT; ledger encerra reserva uma vez | P0 | ____ |
| EST-06 — RESTOCK autorizado após COMMIT | B+E | Venda com COMMIT, devolução aprovada e quantidade conferida | Executar compensação autorizada e repetir a mesma chave | Retorno físico uma vez; sem RESTOCK em venda não commitada ou sem autorização | P0 | ____ |
| EST-07 — Sem dupla subtração Firebase/Oracle | B+E | Timeline completa da mesma venda | Conciliar saldo físico, espelho Firebase, reserva, COMMIT e eventos do sincronizador | Somente RESERVE debita fisicamente; espelho/commit não debitam novamente nem sobrescrevem saldo divergente | P0 | ____ |
| EST-08 — Sem relançar Chamaê no GrandChef | B+E | Operador GrandChef e política MVP registrados | Acompanhar pedido Chamaê até conclusão e razão operacional | Não registrar a venda Chamaê como venda normal de balcão; não usar isso como workaround | P0 | ____ |
| EST-09 — Venda normal de balcão independente | B+E | Produto de ensaio e venda de balcão separada autorizada | Efetuar uma venda normal GrandChef e conciliar separadamente | Baixa normal do balcão preservada; não se confunde com operação Chamaê nem duplica o pedido | P0 | ____ |

### FAL — Falhas e concorrência de estoque

| ID / cenário | Classe | Pré-condição específica | Executar | Critério de PASSOU (anexar evidência) | Sev. | R |
| --- | --- | --- | --- | --- | --- | --- |
| FAL-01 — Zero/insuficiente antes do PIX | A | Emulador com produto 0 e q maior que disponível | Tentar PIX e dinheiro antes de reserva necessária | Nenhuma cobrança/PIX antes das validações/reserva exigidas; se trigger emite PIX sem essa garantia, registrar FALHOU KB-02 | P0 | ____ |
| FAL-02 — Produto removido/inativo | A | Proposta válida e produto removido/inativado antes do backend | Prosseguir a preparação | Sem financeiro aceito, cobrança ou reserva indevida | P0 | ____ |
| FAL-03 — Disputa da última unidade | B+E | Uma unidade física liberada para ensaio, dois pedidos autorizados | Concorrer reservas de clientes distintos | Um vencedor; perdedor não é cobrado; saldo nunca negativo | P0 | ____ |
| FAL-04 — Retry de operação em falha transitória | B+E | Falha injetada na ponte de laboratório e chave registrada | Repetir evento sem mudar sua identidade | No máximo um efeito físico e resposta reconciliável | P0 | ____ |
| FAL-05 — Timeout do bridge | B+E | Ambiente controlado sem clientes reais | Induzir atraso reversível aprovado e observar pedido | Sem assumir falha definitiva ou sucesso; consulta/reconciliação antes de repetir efeito | P0 | ____ |
| FAL-06 — ACK perdido após efeito físico | B+E | Operação aplicada e confirmação suprimida no laboratório | Reenviar mesma chave e consultar ledger/saldo | Retornar resultado original, sem novo decremento | P0 | ____ |
| FAL-07 — Bridge offline | B+E | Janela autorizada e mecanismo seguro de suspensão de laboratório | Parar somente bridge de ensaio e tentar pedido | Pedido bloqueado/pendente explícito; nenhum PIX precoce ou baixa em duplicidade | P0 | ____ |
| FAL-08 — Oracle indisponível | B+E | Falha de conexão simulada em ambiente de ensaio | Interromper acesso de teste e restaurar | Falha segura sem DDL, sem assumir ACK e sem correção manual de saldo | P0 | ____ |
| FAL-09 — GrandChef indisponível | B+E | Indisponibilidade de laboratório autorizada | Reproduzir indisponibilidade do componente realmente necessário e retomar | Estado explicado e reconciliado; se não é dependência técnica, provar e justificar N/A | P1 | ____ |
| FAL-10 — Reconciliação posterior e evento tardio | B+E | Fila e saldos fotografados antes da recuperação | Restaurar serviço, processar eventos tardios e confrontar total esperado | Todos eventos reconciliados uma vez; divergência interrompe sessão e impede lançamento | P0 | ____ |

### KAN — Painel/Kanban e contingência

| ID / cenário | Classe | Pré-condição específica | Executar | Critério de PASSOU (anexar evidência) | Sev. | R |
| --- | --- | --- | --- | --- | --- | --- |
| KAN-01 — Chegada em tempo real e alerta | B | Painel homologação identificado e pedido moderno validado | Criar pedido, ativar som e observar sem F5; enviar chat | Card/contador/badge e alerta coerentes; baseline antigo não alerta como novo | P1 | ____ |
| KAN-02 — Muitos cartões e scroll independente | A | Fixture local com 60 cards por coluna, incluindo últimos identificáveis | Rolar cada coluna com mouse e alcançar o último card | Cabeçalho fixo; rolagem de uma coluna não move outra; todos acessíveis | P1 | ____ |
| KAN-03 — Resoluções da loja | B | PC Pit Stop, zoom e resolução registrados | Usar janela completa/baixa e modal longo | Botões, filtros e rodapé alcançáveis; sem overflow que impeça operar | P1 | ____ |
| KAN-04 — Contadores, cronômetro e detalhe | A | Cards locais de datas/estados conhecidos | Conferir contagem, tempo, itens e totais do detalhe | Mesma seleção em card/detalhe; sem cronômetro negativo ou total reconstruído | P2 | ____ |
| KAN-05 — Filtros e pendências anteriores | A | Pedidos antigos abertos, concluídos de hoje e de ontem | Alternar data/filtro e limpar | Pendência anterior não desaparece por ser de outro dia; encerrados seguem contrato atual | P1 | ____ |
| KAN-06 — Iniciar separação uma vez | B | Novo validado, PIX processed ou dinheiro reserved | Conferir e repetir início de separação | Uma transição/outbox; Novo → Em Separação; sem mutação direta SDK | P0 | ____ |
| KAN-07 — Bloquear PIX/estoque não prontos | A | Fixtures pendentes, rejected e requires_review | Tentar separar na UI e na callable isolada | Bloqueio de servidor e mensagem útil; cliente/painel não forçam avanço | P0 | ____ |
| KAN-08 — Atribuição/retirada sem app motoboy | B | Cadastro real de entregador e superadmin autorizado | Verificar aviso awaiting_integration e área de contingência separada | Sem oferta/aceite inventado; atribuição mantém separação/Aguardando retirada | P1 | ____ |
| KAN-09 — Despacho e conclusão por contingência | B+E | Entregador real ativo, recebimento conferido e cadeia de estoque válida | Superadmin confirma motivo/ID, entrega e cobrança; ensaiar ausência, recusa, falha de cobrança, transporte, retorno intacto/parcial e reentrega pendente | Concluir só após entrega integral/cobrança e revisão corrente; sem RELEASE/RESTOCK automático; sem novo frete; histórico e PIX preservados | P0 | ____ |
| KAN-10 — Perfis negados e auditoria de retry | A | Emulador com operations_admin, finance, cliente e superadmin | Tentar sem role/motivo/confirmação; simular ACK perdido, reinício, duplicata, revisão antiga e concorrência com cancelamento/conclusão | Negados sem efeitos; replay do comando original; eventos privados/ordenados por revisão; nenhuma baixa, cobrança ou conclusão duplicada | P0 | ____ |

### IMP — Impressão e ticket físico

| ID / cenário | Classe | Pré-condição específica | Executar | Critério de PASSOU (anexar evidência) | Sev. | R |
| --- | --- | --- | --- | --- | --- | --- |
| IMP-01 — 80 mm e duas vias | B+F | Driver e largura 80 mm configurados; pedido longo de teste | Imprimir separação e entrega e medir papel | Sem truncamento/overflow; duas vias completas e legíveis, sem página extra indevida | P1 | ____ |
| IMP-02 — 58 mm quando adotada | B+F | Impressora/driver 58 mm disponível ou exclusão de suporte aprovada | Imprimir mesmos casos em 58 mm | Mesma legibilidade; N/A somente se 58 mm não faz parte da operação declarada | P1 | ____ |
| IMP-03 — Corte e margens | B+F | Driver validado sem alterar código | Testar corte por página e alternativas Só separação/Só entrega | Nada de conteúdo cortado; comportamento de auto-cut documentado, não presumido por HTML | P1 | ____ |
| IMP-04 — Pago — não cobrar | B+F | Pedido oficialmente Pago | Imprimir e conferir ambas as vias | PAGO — NÃO COBRAR em destaque; não solicitar recebimento duplicado | P0 | ____ |
| IMP-05 — A receber e hierarquia | B+F | Dinheiro/maquininha pendente com endereço/referência/observações | Imprimir e conferir com operador | Pagamento, valor/troco, endereço, observações, itens e QR rota nessa prioridade visual | P0 | ____ |
| IMP-06 — Split, BR e PY | B+F | Pedidos válidos de cada moeda/split e país | Imprimir e conferir soma, moeda e troco | Parcelas e valores coerentes com persistidos; PY não exibe cartão permitido | P0 | ____ |
| IMP-07 — QR de rota e dados proibidos | B+C+F | Ticket físico e câmera de aparelho real | Escanear QR e inspecionar todas as linhas | Abre destino correto; não despacha pedido; nenhum PIN ou PRO_CODIGO no papel/QR | P0 | ____ |
| IMP-08 — Reimpressão e falha do log | B+F | Pedido já impresso e falha de log só em homologação | Reimprimir e repetir ação explicitamente | Segunda via identificável; falha de log não bloqueia impressão; contagem não prova saída física | P1 | ____ |

### TRA — Status e acompanhamento do cliente

| ID / cenário | Classe | Pré-condição específica | Executar | Critério de PASSOU (anexar evidência) | Sev. | R |
| --- | --- | --- | --- | --- | --- | --- |
| TRA-01 — Cadeia completa de estados | B+C | Pedido de ensaio e contingência autorizada | Observar Novo, Em Separação, Aguardando Retirada, Saiu para Entrega e Concluído | UI acompanha estados persistidos; não inventa GPS ou ETA | P1 | ____ |
| TRA-02 — Reabrir tracking e recuperar | A | Stream local com pedido próprio | Fechar/reabrir, falhar stream e usar retry | Mesmo pedido e estado mais recente; sem celebração repetida que reconsuma sacola | P1 | ____ |
| TRA-03 — Perder internet e reconectar | C | Pedido de homologação visível no aparelho | Desconectar/retomar rede e retornar à tela | Estado antigo não vira confirmação nova; atualização/erro acionável | P1 | ____ |
| TRA-04 — Status desconhecido | A | Fixture com estado não reconhecido | Abrir tracking | Mensagem segura, sem crash nem marcar concluído/pago | P1 | ____ |
| TRA-05 — Cancelado | A | Pedido próprio cancelado em fixture | Reabrir confirmação e tracking | Cancelamento claro; sem selo de compra aceita ou pedido em rota | P1 | ____ |
| TRA-06 — Isolamento entre contas | A | Dois UIDs e ID documental/amigável conhecido | Trocar sessão e consultar ID alheio | Dados/QR anteriores removidos; consulta combina ID e UID autenticado | P0 | ____ |

### CAN — Cancelamento e compensações

| ID / cenário | Classe | Pré-condição específica | Executar | Critério de PASSOU (anexar evidência) | Sev. | R |
| --- | --- | --- | --- | --- | --- | --- |
| CAN-01 — Proposta antes de existir pedido | A | Workspace local pendente e write atrasado | Descartar proposta pela callable e reenviar write atrasado | Tombstone impede criar pedido depois do descarte; não equivale a cancelar pedido existente | P0 | ____ |
| CAN-02 — Antes do pagamento e antes da reserva | B+D | Pedido não pago e sem efeito de estoque; caminho administrativo autorizado | Solicitar cancelamento suportado e acompanhar provedor | Estado Cancelado e nenhum débito; se fluxo real não existe, BLOQUEADO KB-04 | P0 | ____ |
| CAN-03 — PIX pendente | B+D | Cobrança sandbox emitida não paga | Cancelar cobrança/pedido pelos caminhos autorizados e observar evento tardio | Não confundir cancelamento local com cancelamento PSP; sem cobrança/estoque soltos | P0 | ____ |
| CAN-04 — PIX expirado | B+D | Cobrança expirada de teste | Reconciliar e encerrar pedido | Sem marcar Pago, sem cancelar outra cobrança nem alterar financeiro histórico | P0 | ____ |
| CAN-05 — Depois de RESERVE e antes de COMMIT | B+E | Reserva física ACK e nenhuma conclusão | Cancelar e repetir evento | RELEASE único devolve q; financeiro não entra no fechamento; trilha preservada | P0 | ____ |
| CAN-06 — Depois de COMMIT | B+D+E | Venda commitada; devolução/estorno autorizados | Seguir procedimento aprovado de compensação e reconciliar pagamento | Sem RELEASE tardio; RESTOCK só autorizado; estorno PSP comprovado quando necessário | P0 | ____ |
| CAN-07 — Pedido já concluído | B+E | Pedido Concluído/Pago com ledger encerrado | Tentar cancelamento simples e verificar caminho de devolução | Negar mudança destrutiva; preservar evidência e compensar por fluxo próprio autorizado | P0 | ____ |
| CAN-08 — Retry e concorrência | A | Harness local com evento/chave de cancelamento estáveis | Repetir cancelamento simultâneo e evento antigo de conclusão | Sem dupla liberação/baixa, sem regressão indevida | P0 | ____ |
| CAN-09 — Pagamento confirmado após cancelamento | D+E | Sandbox e estoque de laboratório; evento tardio autorizado | Entregar confirmação oficial depois de cancelamento | Revisão/compensação explícita; nenhuma venda ou estoque duplicado; sem reabrir silenciosamente | P0 | ____ |

### FIN — Financeiro, CSV e fechamento

| ID / cenário | Classe | Pré-condição específica | Executar | Critério de PASSOU (anexar evidência) | Sev. | R |
| --- | --- | --- | --- | --- | --- | --- |
| FIN-01 — Matriz de elegibilidade | A | Fixtures Pago+Concluído+validated e variações | Testar pago não concluído, concluído não pago, rejected, vazio e cancelado | Só tripla elegível com campos oficiais completos entra no fechamento | P0 | ____ |
| FIN-02 — Campos canônicos persistidos | A | Pedido e orderFinancials isolados aceitos | Conferir itens, frete, customerFee, merchantFee, merchantNet, platformFee e totalBRL | Mesmos valores oficiais e centavos; grandTotal é conceito, não novo campo; validationStatus mapeia financialValidationStatus | P0 | ____ |
| FIN-03 — Legado compatível sem recalcular | A | Snapshots antigos sem validação/rota e compatíveis com validação existente | Abrir detalhe/relatório e simular tabela atual diferente | Histórico legível; legado sem validated continua excluído do fechamento; sem backfill ou fórmula nova | P0 | ____ |
| FIN-04 — CSV versus indicadores | A | Conjunto local com elegíveis e inelegíveis | Exportar CSV e comparar IDs, filtros e somas | Mesmos pedidos/valores dos indicadores; nenhuma reconstrução de taxa histórica | P0 | ____ |
| FIN-05 — Fechamento real de ensaio | B | Operador financeiro, janela e pedidos identificados | Conferir totais por dia, valor líquido e comprovantes | Somente valores persistidos elegíveis; ausência de valor não tratada como zero | P0 | ____ |
| FIN-06 — Comissão pendente | B | Contratos de comissão e estados atuais identificados | Conferir pendente/pago no painel e recibos | Separar taxa de plataforma, líquido lojista e repasse do motoboy; não inventar comissão | P0 | ____ |
| FIN-07 — Cancelado/revisão não contam | A | Fixtures canceladas ou em revisão | Filtrar vendas/financeiro e exportar | Não entram em fechamento por estarem pagos ou terem total numérico | P0 | ____ |
| FIN-08 — Imutabilidade e leitura privada | A | Emulador com financeiro congelado e cliente/painel | Tentar alterar/ler orderFinancials por SDK e reprocessar pedido | Coleção privada; valores não sobrescritos por cliente ou tabela nova | P0 | ____ |
| FIN-09 — Conciliação PIX/dinheiro/estoque | B+D+E | Vendas de ensaio concluídas com comprovantes e ledger | Conciliar por ID, meio de pagamento e efeitos de estoque | Sem diferença de valor/quantidade; divergência interrompe liberação e não se corrige recalculando histórico | P0 | ____ |

### CAI — Caixa do motoboy no painel

| ID / cenário | Classe | Pré-condição específica | Executar | Critério de PASSOU (anexar evidência) | Sev. | R |
| --- | --- | --- | --- | --- | --- | --- |
| CAI-01 — Agrupamento por identidade real | B | Entregador real cadastrado e pedidos atribuídos | Abrir caixa, conferir nome/UID e pedidos sem vínculo | Agrupamento não paga por nome inventado; sem UID real pedido não fica elegível | P0 | ____ |
| CAI-02 — Pendentes e pagos | B | Pedidos concluídos/pagos elegíveis e já acertados | Comparar listas/contadores/valores | courierPaid é repasse, distinto de paymentStatus do cliente; valores de frete congelados | P0 | ____ |
| CAI-03 — Fechamento individual | B | Um pedido elegível do entregador e perfil autorizado | Conferir valor e confirmar acerto | Recibo imutável e atualização atômica; sem soma enviada pelo navegador como autoridade | P0 | ____ |
| CAI-04 — Lote e item inelegível | B | Mesmo UID real, lote até limite vigente e um caso inválido separado | Fechar lote válido; tentar misturar UID/inelegível | Servidor rejeita lote inválido integralmente; não ignora silenciosamente nem paga duas vezes | P0 | ____ |
| CAI-05 — Recibo e impressão | B+F | Acerto real de ensaio concluído | Reabrir recibo e imprimir | IDs, quantidade e total batem com registro; recibo não expõe dados pessoais desnecessários | P0 | ____ |
| CAI-06 — Retry e concorrência de acerto | A | Harness com mesma chave de acerto e lote | Repetir, concorrer e reutilizar chave com lote diferente | Um recibo/repasse; chave conflitante recusada | P0 | ____ |

### EXC — Exclusão da conta

| ID / cenário | Classe | Pré-condição específica | Executar | Critério de PASSOU (anexar evidência) | Sev. | R |
| --- | --- | --- | --- | --- | --- | --- |
| EXC-01 — Solicitação e confirmação explícita | A | Conta cliente isolada, documentos e job ausente | Abrir Perfil, aceitar ciência, reautenticar e solicitar | Sem ação antes da confirmação; UID vem do token e expectedUid somente confere sessão | P0 | ____ |
| EXC-02 — Pedido ativo/pagamento/revisão bloqueiam | A | Pedidos Novo, desconhecido, PIX pendente e revisão de estoque | Solicitar/processar exclusão | Sem remoção quando preflight bloqueia; orientação para resolver pendência | P0 | ____ |
| EXC-03 — Conta BR com pedidos fechados | C+D | Conta descartável BR em homologação, somente pedidos seguros encerrados | Excluir e acompanhar requested/processing/completed | Auth excluído ao final; sessão encerrada; nenhum pedido ativo apagado | P0 | ____ |
| EXC-04 — Conta PY com pedidos fechados | C+D | Conta descartável PY equivalente | Repetir exclusão e conferir snapshots | Mesma proteção no PY; regra do país não permite apagar financeiro | P0 | ____ |
| EXC-05 — Retry, falha parcial e app fechado | A | Emuladores Auth/Firestore e mais de 100 documentos sintéticos | Falhar entre ordens e antes de Auth; repetir/processar concorrente | Limpeza retoma sem pular dados; completed só no fim; erro transitório não anuncia sucesso | P0 | ____ |
| EXC-06 — Sessão expirada e conta privilegiada | A | Token antigo/trocado, role administrativa ou cadastro courier | Tentar excluir UID externo e conta privilegiada | Negar antes de remoção; reautenticação recente obrigatória; outra sessão não é encerrada | P0 | ____ |
| EXC-07 — Dados pessoais versus preservação | A | Baseline isolado de perfil, endereços, PIN, consentimentos, chats e financeiros | Executar limpeza e comparar documentos/subcoleções | PII conhecida removida, destinos minimizados, UID pseudonimizado; valores/itens/faixa/versão/ledger preservados | P0 | ____ |
| EXC-08 — Login posterior e privacidade residual | C+D | Exclusão concluída de conta descartável | Voltar ao provedor e entrar novamente; tentar token antigo e pedido anterior | Não restaura workspace/histórico antigo; novo acesso segue cadastro/termos; comprovar revogação Apple quando aplicável e revisar cache/retenção | P0 | ____ |

### SEG — Segurança e permissões

| ID / cenário | Classe | Pré-condição específica | Executar | Critério de PASSOU (anexar evidência) | Sev. | R |
| --- | --- | --- | --- | --- | --- | --- |
| SEG-01 — Preços e quantidade adulterados | A | Emulador e payload de proposta manipulável | Enviar preço unitário/subtotal falso e quantidade inválida | Servidor usa produto oficial e recusa quantidade inválida | P0 | ____ |
| SEG-02 — Frete, taxa, distância e versão adulterados | A | Cotação privada local e outro UID | Alterar fee/taxas/metros/unidade/versão e ID da cotação | Backend decide financeiro e alcance; sem aceitar autoridade do cliente | P0 | ____ |
| SEG-03 — Estoque e status por SDK | A | Cliente e perfis administrativos em emulador | Tentar write direto em produtos mapeados/estoque e status de orders | Cliente não escreve preço/estoque; nenhum perfil atualiza status de orders por SDK. Estoque mapeado no formulário do painel permanece somente consulta. | P0 | ____ |
| SEG-04 — Financeiro privado | A | Cliente, courier, finance e operações isolados | Tentar get/list/write e subcoleção de orderFinancials | Sem leitura indevida nem escrita SDK; painel usa campos oficiais expostos em orders | P0 | ____ |
| SEG-05 — Autenticação e isolamento | A | Sem login, anônimo antigo, dois UIDs e sessão revogada | Tentar criar pedido moderno e ler pedido alheio | Autenticação/consentimento vigentes exigidos; nenhum vazamento entre contas | P0 | ____ |
| SEG-06 — Roles do painel | A | Matriz superadmin/operations_admin/finance/catalog_admin/cliente/courier | Abrir áreas e tentar callables proibidas | Menus e servidor concordam; acesso não depende só de esconder botão | P0 | ____ |
| SEG-07 — Projeção do motoboy mínima | A | Pedido atribuído em emulador | Inspecionar projeção e acesso de courier não atribuído/suspenso | Sem telefone, documentos, chat, financeiro ou PIN; somente dados mínimos de entrega autorizados | P0 | ____ |
| SEG-08 — PIN e PRO_CODIGO fora de saídas indevidas | B+F | Conta cliente e ticket/log de ensaio acessíveis ao auditor autorizado | Conferir tela comum, impressão, QR rota e logs saneados | Nenhum PIN em ticket/log/QR/courier; revelação autenticada do próprio PIN é exceção explícita; código só no painel interno | P0 | ____ |
| SEG-09 — Replay e payload livre | A | Callables locais de operação, frete, chat, conta e acerto | Repetir chave e acrescentar UID/valor/status arbitrários | Idempotência e allowlist; nenhum privilégio concedido pelo payload | P0 | ____ |
| SEG-10 — Catálogo restrito e idade | A | Produtos sintéticos bloqueados e política por destino | Buscar produto bloqueado e tentar comprar por API | Filtro e backend negam produto proibido/idade insuficiente; política ausente falha segura | P0 | ____ |

### NET — Conectividade e recuperação

| ID / cenário | Classe | Pré-condição específica | Executar | Critério de PASSOU (anexar evidência) | Sev. | R |
| --- | --- | --- | --- | --- | --- | --- |
| NET-01 — Wi-Fi da Pit Stop | B+C | PC e aparelho identificados na rede autorizada | Executar navegação, cotação e tracking de ensaio | Conexão estável e latências registradas; sem credenciais nos anexos | P1 | ____ |
| NET-02 — Internet lenta | C | Limitação segura no aparelho/rede de ensaio | Abrir catálogo/mapa/checkout e repetir após timeout | Loading finito, retry acionável e sem toques duplicados | P1 | ____ |
| NET-03 — Desconexão durante checkout | C | Tentativa identificada antes/depois do write | Cortar rede e reabrir após restabelecer | Reconcilia mesmo documentId; sem pedido/reserva duplicados | P0 | ____ |
| NET-04 — Desconexão durante PIX | C+D | Cobrança sandbox vinculada | Desconectar app durante confirmação e retornar | Webhook independe do app; retorno consulta estado oficial e não cria nova cobrança | P0 | ____ |
| NET-05 — Clique duplo e timeout | A | Harness local com resposta perdida | Tocar confirmar repetidamente e tentar novamente | Uma tentativa; sacola não consumida em rejeição; nenhum novo efeito físico/financeiro | P0 | ____ |
| NET-06 — Reconexão e sessão trocada | C | Dois usuários de teste consentidos | Trocar conta durante reconexão | Pedidos, QR e dados anteriores deixam a tela; retry vinculado ao UID atual | P0 | ____ |
| NET-07 — Travessia BR/PY e retorno ao app | B+C+D | Rota e deslocamento autorizados; rede BR/PY registrada | Testar Wi-Fi/dados/roaming e retorno do app sem pagar duas vezes | Registrar operadora/lado da fronteira e comportamento; nenhum GPS/Border Mode fictício | P1 | ____ |

### AND — Android real

| ID / cenário | Classe | Pré-condição específica | Executar | Critério de PASSOU (anexar evidência) | Sev. | R |
| --- | --- | --- | --- | --- | --- | --- |
| AND-01 — Instalação, versão e splash | C | APK/AAB de ensaio autorizado com package e assinatura registrados | Instalar, atualizar versão anterior e abrir frio/quente | Versão correta, dados de conta isolados e splash sem travamento | P1 | ____ |
| AND-02 — Navegação e performance | C | Android intermediário real e PC-12 aprovado | Percorrer telas/teclado/voltar/segundo plano e medir | Sem crash/ANR, corte de botões ou perda indevida de sacola | P1 | ____ |
| AND-03 — Mapas e permissões | C+D | Chaves/APIs autorizadas para o build de ensaio | Aceitar aproximada/precisa, negar e negar permanentemente | Mapa utilizável ou seleção manual explicada; GPS negado não fabrica origem/destino/rota | P1 | ____ |
| AND-04 — Checkout, PIX e recuperação | B+C+D+E | Casos de backend/estoque aprovados e PIX sandbox | Comprar dinheiro e PIX, interromper e retomar | Mesmo aceite/estoque/financeiro dos cenários de domínio no aparelho real | P0 | ____ |

### IOS — iPhone real

| ID / cenário | Classe | Pré-condição específica | Executar | Critério de PASSOU (anexar evidência) | Sev. | R |
| --- | --- | --- | --- | --- | --- | --- |
| IOS-01 — Archive/TestFlight e identidade | C+D | Mac/CI autorizado, signing e build de teste identificados | Instalar build TestFlight aprovado e conferir bundle/version | Archive e distribuição de ensaio reais; teste Flutter Windows não substitui este caso | P1 | ____ |
| IOS-02 — Splash, navegação e performance | C | iPhone real, modelo/SO/meta registrados | Usar SafeArea, teclado, voltar, texto ampliado e retorno | Sem crash, controles escondidos ou perda de estado; medir contra PC-12 | P1 | ____ |
| IOS-03 — Mapas/permissões | C+D | APIs, usage descriptions e build de ensaio autorizados | Aceitar/negar localização e confirmar ponto manualmente | Sem mapa vazio silencioso; endereço confirmado consistente | P1 | ____ |
| IOS-04 — Checkout e PIX | B+C+D+E | Domínios de frete/estoque aprovados e MP sandbox | Completar dinheiro e PIX com perda/retorno de rede | Aceite oficial único e tracking correto; sem dependência do app aberto para webhook | P0 | ____ |
| IOS-05 — Apple e exclusão de conta | C+D | Conta Apple descartável e fluxo de exclusão homologado | Entrar, excluir, verificar revogação e tentar login posterior | Dados antigos inacessíveis; revogação do vínculo Apple comprovada quando exigida; KB-06 não fica presumido aprovado | P0 | ____ |

### GPL — Publicação Google Play — revisão documental futura

| ID / cenário | Classe | Pré-condição específica | Executar | Critério de PASSOU (anexar evidência) | Sev. | R |
| --- | --- | --- | --- | --- | --- | --- |
| GPL-01 — Registro, package e assinatura | D | Conta Play autorizada, sem segredo no documento | Conferir app record, br.com.loumak.chamae, certificados e App Signing | Release com chave de distribuição; configuração debug atual não aprova publicação | P1 | ____ |
| GPL-02 — Build e testes exigidos | C+D | AAB assinado e trilha interna/fechada autorizada | Conferir versionCode, target API e requisitos da conta no Console | Verificar regra vigente de API, duração/quantidade de testes; sem prazo presumido e sem enviar nesta tarefa | P1 | ____ |
| GPL-03 — Ficha e screenshots | C+D | Build real e identidade oficial | Revisar descrição, suporte, países e screenshots capturados em aparelho | Metadados representam MVP single-store; sem prometer app motoboy/GPS/ETA | P2 | ____ |
| GPL-04 — Privacidade, Data safety e exclusão | D | Inventário real de dados/SDKs e política aprovada | Validar URLs públicas e fluxo externo funcional de solicitação de exclusão | Declarações coerentes e recurso web acessível; não presumir que botão do app basta para Play | P0 | ____ |
| GPL-05 — Classificação, restritos e release | D | Responsável legal/comercial e gates aprovados | Conferir público/classificação, álcool/tabaco/nicotina e plano de release | Verificar regra vigente e catálogo/idade por território; liberação só com aprovação humana específica | P1 | ____ |

### APL — Publicação Apple — revisão documental futura

| ID / cenário | Classe | Pré-condição específica | Executar | Critério de PASSOU (anexar evidência) | Sev. | R |
| --- | --- | --- | --- | --- | --- | --- |
| APL-01 — App Store Connect e signing | D | Conta/equipe autorizada, Mac/CI e bundle aprovados | Conferir app record, bundle, certificados, provisioning e IPA/archive | Identidade/signing válidos; nenhuma senha/certificado privado anexado | P1 | ____ |
| APL-02 — TestFlight e regras de submissão | C+D | Archive de teste e convite autorizados | Validar IPA, upload/trilha e requisitos de Xcode/SDK no Console | Verificar regra vigente; aprovação TestFlight não significa aprovação final da loja | P1 | ____ |
| APL-03 — Ficha e review notes | C+D | Screenshots reais e conta de revisão descartável | Revisar descrição, suporte, screenshots e instruções de acesso/pagamento/endereço | Revisor consegue percorrer fluxo sem conta administrativa nem dados reais de clientes | P2 | ____ |
| APL-04 — App Privacy e account deletion | D | Política/inventário de SDKs, Sign in with Apple e exclusão implementada | Conferir privacy manifests, declarações e revogação Apple | Verificar regra vigente; iniciar exclusão no app e preservar somente dados justificados, sem prometer anonimização irreversível | P0 | ____ |
| APL-05 — Produtos restritos, classificação e release | D | Responsável e gates iOS aprovados | Revisar catálogo/metadados/idade e condições BR/PY com regras vigentes | Sem conteúdo comercial proibido ou promessa sem suporte; release requer aprovação humana futura | P1 | ____ |

### POS — Pós-MVP — fora dos gates atuais

| ID / cenário | Classe | Pré-condição específica | Executar | Critério de PASSOU (anexar evidência) | Sev. | R |
| --- | --- | --- | --- | --- | --- | --- |
| POS-01 — App motoboy e aceite de ofertas | G | Roadmap aprovado em tarefa futura | Especificar presença ON/OFF, fila/FCM e aceite atômico | Não exigido agora; outbox awaiting_integration não conta como app entregue | P2 | ____ |
| POS-02 — GPS e ETA reais | G | Integração futura de localização autorizada | Definir fonte/consentimento/precisão antes de implementar | Tracking atual não promete posição ou horário real de chegada | P2 | ____ |
| POS-03 — Border Mode completo | G | Estudo de rede e roadmap futuro | Planejar continuidade transfronteiriça avançada | Não bloqueia MVP; reconexão básica e ausência de duplicidade continuam obrigatórias em NET | P2 | ____ |
| POS-04 — Marketplace/múltiplas lojas | G | Decisão de negócio futura | Registrar fora do escopo atual | Pit Stop V8 single-store; nenhuma homologação multi-store exigida | P3 | ____ |

### E2E — Ensaios integrados na Pit Stop V8

| ID / cenário | Classe | Pré-condição específica | Executar | Critério de PASSOU (anexar evidência) | Sev. | R |
| --- | --- | --- | --- | --- | --- | --- |
| E2E-01 — Brasil dinheiro de ponta a ponta | B+C+D+E+F | Gates técnicos prévios e autorização física/estoque completos | Cliente → destino BR → Routes/frete → dinheiro → ACK → Kanban → ticket → separar → contingência → concluir → financeiro/caixa | Uma venda e um efeito físico; valores/país/versão preservados; recebimento e repasse conciliados | P0 | ____ |
| E2E-02 — Brasil PIX sandbox de ponta a ponta | B+C+D+E+F | Mercado Pago sandbox compatível com backend e estoque de ensaio | Repetir cadeia com QR, webhook e confirmação oficial antes da separação | Uma cobrança; estoque e financeiro corretos; ticket Pago não cobra novamente | P0 | ____ |
| E2E-03 — Paraguai e fronteira | B+C+D+E+F | Destino PY autorizado, rota real aprovada e meios permitidos | Repetir cadeia com dinheiro PYG/USD aprovado; ensaiar PIX só se disponível/autorizado no arranjo vigente | País PY e rota preservados; sem cartão; troco BRL; sem alegar suporte financeiro transfronteiriço não homologado | P0 | ____ |
| E2E-04 — Falha, cancelamento e reconciliação | B+C+D+E+F | Janela controlada e plano de interrupção/compensação aprovados | Introduzir uma falha segura, interromper pedido antes do COMMIT, liberar e recuperar; conferir evidências finais | Sem cobrança indevida/estoque duplicado; fila zerada ou pendências explicitamente bloqueadas; nenhum saldo corrigido no improviso | P0 | ____ |

## 7. Publicação — verificações de regra vigente

GPL e APL são checklists separadas. Nenhuma consulta autenticada a Console, upload, app record, submissão ou release na loja foi feita nesta retomada documental. A assinatura e o AAB locais do KB-07 foram informados pelo responsável; não equivalem a Play App Signing, teste fechado ou aprovação de loja.

- **Google Play**: verificar app record/package, assinatura/App Signing, artefato e versionamento, API e testes exigidos para a conta, screenshots/descrição/suporte, países, classificação, conteúdo restrito, política de privacidade e Data safety. Para apps com criação de conta, conferir caminho no app e recurso web funcional de solicitação de exclusão; a [orientação oficial de exclusão Google Play](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en) exige conferir ambos no fluxo aplicável. Número de testadores, duração de testes e prazos de API: **verificar regra vigente** no Console; não há número ou prazo presumido neste manual.
- **Apple**: verificar App Store Connect, bundle/signing/provisioning, IPA/archive, TestFlight, SDK/Xcode exigidos, screenshots/descrição, App Privacy/manifests, review notes e acesso de revisão. Conferir exclusão iniciável no app e revogação do vínculo Sign in with Apple conforme a [orientação oficial Apple sobre exclusão](https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion/) e a [nota técnica de revogação](https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple). Excluir somente Firebase Auth não demonstra revogação Apple. Requisitos de distribuição/submissão: **verificar regra vigente**.
- **Catálogo e territórios**: revisar conteúdo de bebidas, imagens, promoções, idade e conferência de entrega com o responsável competente para BR/PY. Conferir as regras vigentes de [conteúdo Google Play](https://support.google.com/googleplay/android-developer/answer/9878810?hl=en) e [App Review Apple](https://developer.apple.com/app-store/review/guidelines/); não pressupor que produto disponível no estoque possa ser vendido pelo app. Não declarar aprovação jurídica ou das lojas.

Essas páginas são documentação pública consultada; isso não é acesso ao Firebase de produção, Mercado Pago operacional, Oracle/GrandChef ou contas das lojas. Revalidar as políticas na data efetiva de submissão.

## 8. Bloqueadores e pendências conhecidos

“Conhecido” distingue evidência de código de comportamento externo ainda não verificado. Nenhuma linha abaixo é um teste novo executado nem uma acusação de falha já observada em produção. A coluna de severidade indica o impacto caso não seja resolvida; manter os cenários dependentes BLOQUEADOS até evidência suficiente.

| Ref. | Pendência / evidência | Impacto e responsável a designar | Casos de resolução |
| --- | --- | --- | --- |
| KB-01 | Origem real, tabela comercial ativa, travelMode e Routes real BR/PY não verificados; configuração externa e revisão implantada não consultadas. | P0 frete; responsável backend/administrador da loja. | PC-02/05/06; END e FRT. |
| KB-02 | Ponte física/ledger/ACK não comprovados nestes repos. PIX automático inspecionado prepara financeiro antes da emissão, sem demonstração de RESERVE físico prévio; baixa Firebase no webhook não prova a garantia solicitada. | P0 estoque/cobrança e risco de dupla subtração; dono da integração/estoque/backend. Não homologar como pronto. | EST completo, FAL-01 e falhas reais; PIX-01/12; E2E. |
| KB-03 | **PARCIAL**: Rules e guard backend de horário/país/método implementados; 374 Functions, 343 emulador e 42 Flutter afetados aprovados; analyze sem issues. País exige prova geográfica privada; sem ela falha fechado. Nenhuma implantação/consulta geográfica real nesta tarefa. | P1 fluxo/regras comerciais; backend e operação. Configurar Geocoding/segredo de servidor em sessão autorizada; homologar BR/PY/fronteira, latência e revisão implantada. | [Relatório KB-03](KB-03-HORARIO-PAIS-BACKEND-2026-10-24.md); HOR-07, END-09, DIN-08 e SEG. |
| KB-04 | **PARCIAL**: comandos administrativos, RELEASE/RESTOCK locais idempotentes, snapshots preservados, ledger e proteção contra eventos tardios implementados. 388 Functions, 364 emulador e 40 Flutter afetados aprovados; analyze sem issues. Sem refund/void ou estoque físico reais homologados. | P0 compensação financeira/estoque; operação, PSP e integração. Pendem bridge/ACK físico, cancelamento/refund PSP, ledger de comissão/ajustes externos e integração operacional/painel. Nenhum gate liberado. | [Relatório KB-04](KB-04-CANCELAMENTO-COMPENSACOES-2026-10-24.md); PC-11; CAN e EST-04/06; E2E-04. |
| KB-05 | **PARCIAL**: tentativas/retornos/reentrega pendente, revisões/recibos e confirmações de entrega/cobrança implementados; bloqueio de RELEASE em rota e RESTOCK sem retorno intacto. 403 Functions, 391 emulador, 40 Flutter cliente e 14 painel aprovados; analyze cliente limpo; painel com dois infos anteriores em main.dart. | P1 fechamento da cadeia; Pit Stop/superadmin. Aprovar responsável/procedimento, ensaio físico/build implantado; reentrega executável, compensação parcial e refund/ACK externo pendem. Nenhum gate liberado. | [Relatório KB-05](KB-05-CONTINGENCIA-ENTREGA-2026-10-24.md); KAN-08/09/10, TRA-01, CAI, NET e E2E-04. App completo permanece POS-01. |
| KB-06 | **PARCIAL**: contrato/guard Apple no worker, recibo por solicitação, UID/link/refresh, limpeza global/cache e logs minimizados. Retomada: 414 Functions, 20 emulador de conta/revogação e 74 Flutter afetados aprovados; analyze limpo. Emulador completo anterior: 403/403. Completo Flutter 207/209 (duas fixtures de checkout pendentes). Código existente preservado. | P0 privacidade/publicação; pendem adaptador/credencial Apple real, Google/Apple reais, OAuth/capability iOS, documentos/URLs/suporte/recurso web, retenção/backups/texto livre e cache sem callback. Apple bloqueia sem revogação confirmada; nenhum gate liberado. | [Relatório/matriz/checklists KB-06](KB-06-PRIVACIDADE-APPLE-CONTA-2026-10-24.md); EXC-08, IOS-05, GPL-04 e APL-04. |
| KB-07 | **RESOLVIDO LOCALMENTE / PENDENTE HOMOLOGAÇÃO GOOGLE PLAY**: release sem fallback debug; upload key oficial criada fora do repo, backup local com hash idêntico e key.properties configurado/protegido. Responsável informou AAB release em build/app/outputs/bundle/release/app-release.aab, 65.7 MB, com certificado idêntico ao da upload key confirmado por keytool -printcert -jarfile. Hashes do arquivo da keystore e do certificado registrados no relatório; não são hash do AAB. Histórico: analyze limpo e 209/209 Flutter; sem nova execução nesta etapa documental. | P1 publicação Android; responsável de release. Upload, Play App Signing e teste fechado não executados; homologar certificados de distribuição/Google/Maps, permissões/funcionamento em aparelho e identidade visual. Nenhum gate Google Play/Android liberado. | [Relatório KB-07](KB-07-ANDROID-SIGNING-BUILD-2026-10-25.md); GPL-01/02 e AND. |
| KB-08 | Build instalado/cache do painel, archive/TestFlight, aparelhos, impressoras, rede fronteiriça e homologação física ainda dependem de sessão real. Nenhum acesso realizado aqui. | P1 nos fluxos principais dependentes; P2 somente em opcionais justificados; operação/QA. | PC-02/09/12; B/C/F, AND, IOS, NET-07 e E2E. |

Não mudar código, taxas, credenciais ou configuração nesta tarefa para resolver essas pendências. Abrir trabalho separado após revisão. Ausência de evidência não autoriza marcar PASSOU; existência de testes anteriores não fecha gate físico.

## 9. Gates objetivos de lançamento

| Gate | Escopo por IDs | Condição necessária de liberação |
| --- | --- | --- |
| GATE 1 — App Cliente | HOM, PRO, CAR, PER, HOR, END, TRA, NET | Todos os casos aplicáveis desses grupos PASSOU; compra, recuperação, país/horário e sessão sem bloqueio principal. KB-03 resolvido por evidência, sem confiar somente na UI. |
| GATE 2 — Painel | KAN, IMP | Kanban de loja, scroll/último cartão, filtros/pendências, perfis e ticket físico PASSOU; KAN-08/09 comprovam contingência aprovada e auditada para completar a entrega. |
| GATE 3 — Frete | FRT | Todos FRT PASSOU e END-01/04/06/07/08 PASSOU; origem/tabela reais aprovadas, Routes real, fronteiras locais, cobertura, indisponibilidade e snapshots comprovados. |
| GATE 4 — PIX | PIX | PIX-01 a PIX-12 PASSOU em sandbox compatível e FAL-01/EST-02/07 sem risco aberto; PIX-13 PASSOU antes de liberar recebimentos reais, somente em sessão futura explicitamente autorizada. Sem isso, gate restrito a sandbox. |
| GATE 5 — Estoque | EST, FAL | Todos EST/FAL PASSOU, DIN-09 e CAN-05/06/07/08/09 aplicáveis PASSOU; ledger/ACK físico, concorrência, COMMIT zero e nenhuma dupla baixa comprovados. Falta de bridge é BLOQUEADO. |
| GATE 6 — Financeiro | DIN, FIN, CAI, CAN | Todos aplicáveis desses grupos PASSOU; recebimento, cancelamento/estorno/devolução, snapshot histórico, CSV, líquido/comissão e acertos conciliados sem diferença. |
| GATE 7 — Segurança | SEG, EXC | Todos SEG/EXC PASSOU, PER-03/04/05 e políticas de GPL-04/APL-04 aplicáveis PASSOU; isolamento, roles, PII, privacidade/retenção e exclusão/revogação comprovados. |
| GATE 8 — Android | AND, GPL | Todos AND/GPL aplicáveis PASSOU; assinatura de distribuição, AAB/trilha, aparelho intermediário, permissões, políticas e regra vigente do Console comprovados. |
| GATE 9 — iOS | IOS, APL | Todos IOS/APL aplicáveis PASSOU; archive/signing, TestFlight e iPhone reais, Apple/login/exclusão/revogação e metadados aprovados. N/A só se iOS formalmente excluído desta liberação; não autoriza publicar iOS. |
| GATE 10 — Operação real Pit Stop V8 | E2E | Todos E2E PASSOU; gates 1–7 e gate de cada plataforma lançada aprovados; PC-01 a PC-13 completos; atendimento, estoque físico, recibos, financeiro e encerramento da rodada conciliados; zero P0/P1 aberto. |

Estado inicial dos dez gates nesta nova rodada: **BLOQUEADO — execução/evidência/aprovação ainda não registradas**. Isso não altera os resultados históricos de testes locais.

Para cada gate registrar revisor, data/hora, builds/ambiente, IDs/evidências PASSOU, N/A formalmente aprovados, falhas/compensações abertas e decisão. Um caso obrigatório pode ser dispensado apenas por exclusão real de escopo formalizada (ex.: 58 mm não ofertado); risco P0/P1 não pode ser dispensado como workaround. **Qualquer P0 ou P1 aberto, inclusive BLOQUEADO por pré-requisito crítico, impede lançamento.**

Casos G não bloqueiam a liberação atual. P2 exige aceite escrito do workaround e responsável/prazo; P3 entra no backlog. Não prometer GPS/ETA, oferta automática de entregador, Border Mode completo ou marketplace como funcionalidades do MVP.

Aprovação de sandbox não é liberação de pagamentos reais. Aprovação Android não libera iOS, e vice-versa. Se um canal/plataforma não for lançado, registrar escopo excluído/aprovador; manter seu gate N/A para essa rodada, sem chamar de PASSOU. A decisão final exige revisão humana da Pit Stop, financeiro, estoque e responsável técnico.

## 10. Fechamento da rodada

- [ ] Conciliar cada ID de pedido/cobrança/quote/ledger/ACK e cada movimento físico; filas pendentes resolvidas ou claramente bloqueadas com responsável.
- [ ] Confrontar estoque inicial/final, vendas de balcão independentes e compensações autorizadas; nenhuma diferença sem explicação.
- [ ] Conferir pagamentos/estornos, snapshots, CSV/indicadores, repasse e recibos sem recalcular histórico.
- [ ] Recolher tickets, fotos e logs saneados; guardar dados sensíveis em custódia restrita, sem anexar secrets.
- [ ] Documentar falhas por severidade, reteste necessário, campos N/A e aprovação dos gates por plataforma/país.
- [ ] Registrar horário de término, operador/revisores, escopo e decisão **liberar / não liberar**. Sem assinatura/aprovação, não publicar.
- [ ] Qualquer limpeza de dados de teste, compensação de estoque, liberação de credencial, submissão ou deploy futuro exige seu fluxo autorizado próprio. Não apagar evidências financeiras necessárias.

## 11. Integridade da entrega documental original

Na entrega documental original somente este manual e a checklist compacta foram criados; os 505 arquivos preexistentes foram preservados naquela etapa. As alterações posteriores de código/testes KB-03 e KB-04 e suas comparações de contratos estão registradas nos relatórios específicos; o hash original abaixo não afirma que o código permaneceu igual após essas implementações autorizadas. Nenhuma etapa acessou Firebase de produção ou Oracle/GrandChef, nem realizou impressão física, pagamento real, commit, push ou deploy. Os resultados operacionais deste catálogo permanecem para preenchimento na homologação.

O inventário/hash agregado dos 505 arquivos Git presentes (rastreados e não ignorados, incluindo arquivos locais novos), excluindo apenas estes dois documentos, foi registrado em memória antes da redação para comparação final. Arquivos ignorados de cache/build não compõem esse inventário. Nenhuma consulta externa operacional foi usada para preencher resultado.

Baseline SHA-256 agregado antes da redação: `9a7cba973353f95fb2752c389567058b25db1aa5982a493e155783f0e3a88973` (505 arquivos, fora estes dois documentos).

