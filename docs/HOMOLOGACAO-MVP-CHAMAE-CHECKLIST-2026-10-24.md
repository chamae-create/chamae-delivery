# Homologação MVP Chamaê — checklist de campo — 24/10/2026

Pit Stop V8 • single-store • Ponta Porã-MS ↔ Pedro Juan Caballero-Amambay. Complemento do [manual completo](HOMOLOGACAO-MVP-CHAMAE-2026-10-24.md), que contém pré-condições, passos, critérios e evidências por ID. **Nenhum cenário desta rodada foi executado/aprovado nesta tarefa documental.**

Rodada: __________ • Data/início/fim e offset/UTC: __________ • Operador/revisor: __________  
Ambiente/projeto: __________ • Build/hash cliente/painel/backend/Rules/bridge: __________  
Commit de referência existente + dirty: __________ • Dispositivos/modelo/SO/rede/driver: __________  
Escopo autorizado BR/PY/plataformas: __________ • Repositório de evidências restritas: __________

## Como preencher

**R** = PASSOU / FALHOU / BLOQUEADO / NÃO APLICÁVEL. **EV** = referência à ficha/evidência. Marcar o checkbox quando a execução estiver registrada, inclusive falha/bloqueio; checkbox **não significa PASSOU**. Campos inicialmente vazios aguardam execução, sem quinto status.

Por ID/subvariação registrar data/hora, responsável, ambiente, build/commit/dirty, dispositivo, ID documental/amigável do pedido quando aplicável, esperado, observado, evidência, observação e severidade. Usar a ficha do manual. N/A requer escopo/justificativa/aprovador; falta de ambiente/acesso/implementação é BLOQUEADO.

A notebook local somente; B PC Pit Stop; C Android/iPhone real; D serviço externo real (sandbox também); E Oracle/GrandChef/bridge real de ensaio; F impressora física; G pós-MVP. Classes B–F acumulam recursos; não somar colunas como se fossem cenários distintos.

**196 IDs** (192 de lançamento, 4 pós-MVP): A=87, B=63, C=39, D=51, E=32, F=19, G=4.

## Antes de começar — PC

- [ ] PC-01 Operador, aprovador, janela e contatos; horário MS documentado.
- [ ] PC-02 Versões/builds e hashes instalados de cliente/painel/backend/Rules/índices/bridge; commit existente e dirty.
- [ ] PC-03 Ambiente Firebase explícito e isolado; nenhum alias default acidental.
- [ ] PC-04 Contas autorizadas e roles; registrar referências, **nenhuma credencial**.
- [ ] PC-05 Tabela ativa/versionada, preços reais aprovados, origem Pit Stop e transporte explícito.
- [ ] PC-06 Google Routes, Geocoding de país no servidor (KB-03) e Mercado Pago **SANDBOX**/webhook autorizados; sem expor secrets.
- [ ] PC-07 Produtos/PRO_CODIGO/IDs/preços e quantidades de teste; estoque inicial físico/espelho/reservado com horário.
- [ ] PC-08 Destinos BR/PY consentidos, regras de moeda/troco/idade/horário e entregador real.
- [ ] PC-09 PC/aparelhos/rede BR/PY e impressoras 80 mm/58 mm quando suportada.
- [ ] PC-10 **Antes de Oracle:** autorização, responsável, backup/evidência recuperável, baseline e protocolo/ledger/ACK; **sem DDL**.
- [ ] PC-11 Contratos administrativos KB-04 integrados ao procedimento; refund/void PSP e RELEASE/RESTOCK físicos dependem de homologação/ACK reais, sem edição livre de saldo/status.
- [ ] PC-12 Metas de desempenho e critérios de parada aprovados; custódia de evidências.
- [ ] PC-13 Política/termos/privacidade, publicação e retenção/revogação sob revisão competente.

## Ordem e parada

LOCAL → sandbox/Routes/IdP autorizados → PC/aparelhos/papel → estoque físico controlado → E2E/conciliação → gates → eventual sessão separada de produção controlada autorizada → publicação por plataforma. A checklist não autoriza executar nenhuma dessas fases por si só.

**Parar** por dupla cobrança/baixa, saldo negativo, vazamento, valor divergente ou mistura de ambientes. Preservar IDs/logs saneados e acionar responsáveis. Nada de editar saldo/status em Firestore/Oracle para “passar” cenário, relançar venda Chamaê no GrandChef ou restaurar backup cegamente.

P0 financeiro/estoque/segurança e P1 fluxo principal **bloqueiam lançamento**. P2 precisa workaround aprovado; P3 backlog. Casos G não bloqueiam o MVP.

## Cenários — registrar cada ID

### HOM — Home e navegação (8)

- [ ] **HOM-01** · A · P1 — Carregamento e falha recuperável. R: ______ · EV: ______
- [ ] **HOM-02** · A · P1 — Categorias e busca. R: ______ · EV: ______
- [ ] **HOM-03** · A · P2 — Promoções e produtos. R: ______ · EV: ______
- [ ] **HOM-04** · A · P2 — Imagens e vídeo indisponíveis. R: ______ · EV: ______
- [ ] **HOM-05** · A · P1 — Aberta e fechada na Home. R: ______ · EV: ______
- [ ] **HOM-06** · A · P1 — Carrinho e navegação de retorno. R: ______ · EV: ______
- [ ] **HOM-07** · A · P2 — Tela pequena e texto ampliado. R: ______ · EV: ______
- [ ] **HOM-08** · C · P1 — Uso em aparelho intermediário. R: ______ · EV: ______

### PRO — Produto (5)

- [ ] **PRO-01** · A · P1 — Disponível e preço oficial. R: ______ · EV: ______
- [ ] **PRO-02** · A · P0 — Estoque zero e insuficiente. R: ______ · EV: ______
- [ ] **PRO-03** · A · P1 — Ativo/inativo e removido. R: ______ · EV: ______
- [ ] **PRO-04** · A · P1 — Quantidade máxima. R: ______ · EV: ______
- [ ] **PRO-05** · A · P1 — Adicionar/remover e identidade. R: ______ · EV: ______

### CAR — Carrinho (6)

- [ ] **CAR-01** · A · P1 — Adicionar, retirar e alterar quantidade. R: ______ · EV: ______
- [ ] **CAR-02** · A · P0 — Subtotal e taxas da prévia. R: ______ · EV: ______
- [ ] **CAR-03** · A · P0 — Atualização de estoque. R: ______ · EV: ______
- [ ] **CAR-04** · A · P1 — Produto indisponível após inclusão. R: ______ · EV: ______
- [ ] **CAR-05** · A · P1 — Recuperação de sacola/proposta. R: ______ · EV: ______
- [ ] **CAR-06** · A · P0 — Consumo idempotente da sacola. R: ______ · EV: ______

### PER — Perfil, autenticação e documentos (5)

- [ ] **PER-01** · C+D · P1 — Google e vínculo de sessão antiga. R: ______ · EV: ______
- [ ] **PER-02** · C+D · P1 — Apple e retorno da sessão. R: ______ · EV: ______
- [ ] **PER-03** · A · P1 — Perfil, termos e privacidade. R: ______ · EV: ______
- [ ] **PER-04** · A · P1 — Retry, logout e sessão expirada. R: ______ · EV: ______
- [ ] **PER-05** · A · P0 — Elegibilidade BR/PY e produto restrito. R: ______ · EV: ______

### HOR — Loja aberta/fechada — relógio operacional MS (7)

- [ ] **HOR-01** · A · P1 — 07:59 fechada. R: ______ · EV: ______
- [ ] **HOR-02** · A · P1 — 08:00 abertura. R: ______ · EV: ______
- [ ] **HOR-03** · A · P1 — Durante a operação. R: ______ · EV: ______
- [ ] **HOR-04** · A · P1 — 23:59 ainda aberta. R: ______ · EV: ______
- [ ] **HOR-05** · A · P1 — 00:00 fechada. R: ______ · EV: ______
- [ ] **HOR-06** · A · P1 — Virada com checkout aberto e fuso do aparelho. R: ______ · EV: ______
- [ ] **HOR-07** · A · P1 — Tentativa de contornar horário pela API. R: ______ · EV: ______

### END — Endereço Brasil/Paraguai (9)

- [ ] **END-01** · C+D · P1 — Brasil válido. R: ______ · EV: ______
- [ ] **END-02** · A · P1 — Incompleto ou país ausente. R: ______ · EV: ______
- [ ] **END-03** · A · P0 — Coordenadas inválidas. R: ______ · EV: ______
- [ ] **END-04** · D · P0 — Brasil fora de cobertura. R: ______ · EV: ______
- [ ] **END-05** · A · P0 — Mudança após cotação. R: ______ · EV: ______
- [ ] **END-06** · C+D · P1 — Paraguai válido. R: ______ · EV: ______
- [ ] **END-07** · B+C+D · P1 — Rota transfronteiriça real. R: ______ · EV: ______
- [ ] **END-08** · D · P0 — Paraguai fora da cobertura. R: ______ · EV: ______
- [ ] **END-09** · A · P1 — Troca de país e meios de pagamento. R: ______ · EV: ______

### FRT — Frete e Google Routes (14)

- [ ] **FRT-01** · B+D · P0 — Origem oficial e transporte. R: ______ · EV: ______
- [ ] **FRT-02** · D · P0 — Distância real e faixa publicada. R: ______ · EV: ______
- [ ] **FRT-03** · A · P0 — Primeira faixa e distância zero. R: ______ · EV: ______
- [ ] **FRT-04** · A · P0 — Início, fim e transição de faixas. R: ______ · EV: ______
- [ ] **FRT-05** · A · P0 — Granularidade e limite técnico. R: ______ · EV: ______
- [ ] **FRT-06** · A · P0 — Máximo e acima da área. R: ______ · EV: ______
- [ ] **FRT-07** · A · P0 — Tabela ausente/inativa/inválida. R: ______ · EV: ______
- [ ] **FRT-08** · A · P0 — Versão antiga/rascunho. R: ______ · EV: ______
- [ ] **FRT-09** · A · P0 — Tabela alterada entre prévia e aceite. R: ______ · EV: ______
- [ ] **FRT-10** · D · P0 — Indisponibilidade e timeout reais. R: ______ · EV: ______
- [ ] **FRT-11** · A · P0 — Sem Haversine ou tarifa fixa. R: ______ · EV: ______
- [ ] **FRT-12** · A · P0 — Adulteração e uso único de quote. R: ______ · EV: ______
- [ ] **FRT-13** · A · P0 — Snapshot congelado e preservação. R: ______ · EV: ______
- [ ] **FRT-14** · A · P0 — Publicação, permissões e histórico. R: ______ · EV: ______

### PIX — PIX Mercado Pago — sandbox (13)

- [ ] **PIX-01** · D · P0 — Criação após validações exigidas. R: ______ · EV: ______
- [ ] **PIX-02** · C+D · P1 — QR e copia e cola. R: ______ · EV: ______
- [ ] **PIX-03** · B+D+F · P0 — Ticket de PIX pendente. R: ______ · EV: ______
- [ ] **PIX-04** · D · P0 — Pagamento e webhook oficial. R: ______ · EV: ______
- [ ] **PIX-05** · A · P0 — Confirmação do cliente. R: ______ · EV: ______
- [ ] **PIX-06** · D · P0 — Retry de criação. R: ______ · EV: ______
- [ ] **PIX-07** · D · P0 — Webhook duplicado e fora de ordem. R: ______ · EV: ______
- [ ] **PIX-08** · D · P0 — Tentativa de pagamento/cobrança duplicada. R: ______ · EV: ______
- [ ] **PIX-09** · D · P0 — Expirado e cancelado. R: ______ · EV: ______
- [ ] **PIX-10** · A · P0 — Valor/identidade incorretos. R: ______ · EV: ______
- [ ] **PIX-11** · A · P0 — Assinatura e erro temporário do webhook. R: ______ · EV: ______
- [ ] **PIX-12** · B+D+E · P0 — Conferência final dos quatro eixos. R: ______ · EV: ______
- [ ] **PIX-13** · B+C+D+E+F · P0 — PIX em produção controlada — sessão separada. R: ______ · EV: ______

### DIN — Dinheiro e pagamento na entrega (10)

- [ ] **DIN-01** · A · P0 — BRL valor exato. R: ______ · EV: ______
- [ ] **DIN-02** · A · P0 — Valor insuficiente e inválido. R: ______ · EV: ______
- [ ] **DIN-03** · B+F · P0 — BRL com troco. R: ______ · EV: ______
- [ ] **DIN-04** · B+C+F · P0 — PYG e arredondamento. R: ______ · EV: ______
- [ ] **DIN-05** · B+C+F · P0 — USD e troco. R: ______ · EV: ______
- [ ] **DIN-06** · A · P0 — Split permitido. R: ______ · EV: ______
- [ ] **DIN-07** · A · P0 — Split proibido/inconsistente. R: ______ · EV: ______
- [ ] **DIN-08** · A · P1 — PY sem cartão e BR preservado. R: ______ · EV: ______
- [ ] **DIN-09** · B+E · P0 — Reserva e conclusão operacional. R: ______ · EV: ______
- [ ] **DIN-10** · A · P0 — Retomada após desconexão. R: ______ · EV: ______

### EST — Estoque físico — execução restrita (9)

- [ ] **EST-01** · B+E · P0 — Baseline e identidade canônica. R: ______ · EV: ______
- [ ] **EST-02** · B+E · P0 — RESERVE único e ACK. R: ______ · EV: ______
- [ ] **EST-03** · B+E · P0 — RESERVE repetido e ACK perdido. R: ______ · EV: ______
- [ ] **EST-04** · B+E · P0 — RELEASE antes do COMMIT. R: ______ · EV: ______
- [ ] **EST-05** · B+E · P0 — COMMIT somente lógico. R: ______ · EV: ______
- [ ] **EST-06** · B+E · P0 — RESTOCK autorizado após COMMIT. R: ______ · EV: ______
- [ ] **EST-07** · B+E · P0 — Sem dupla subtração Firebase/Oracle. R: ______ · EV: ______
- [ ] **EST-08** · B+E · P0 — Sem relançar Chamaê no GrandChef. R: ______ · EV: ______
- [ ] **EST-09** · B+E · P0 — Venda normal de balcão independente. R: ______ · EV: ______

### FAL — Falhas e concorrência de estoque (10)

- [ ] **FAL-01** · A · P0 — Zero/insuficiente antes do PIX. R: ______ · EV: ______
- [ ] **FAL-02** · A · P0 — Produto removido/inativo. R: ______ · EV: ______
- [ ] **FAL-03** · B+E · P0 — Disputa da última unidade. R: ______ · EV: ______
- [ ] **FAL-04** · B+E · P0 — Retry de operação em falha transitória. R: ______ · EV: ______
- [ ] **FAL-05** · B+E · P0 — Timeout do bridge. R: ______ · EV: ______
- [ ] **FAL-06** · B+E · P0 — ACK perdido após efeito físico. R: ______ · EV: ______
- [ ] **FAL-07** · B+E · P0 — Bridge offline. R: ______ · EV: ______
- [ ] **FAL-08** · B+E · P0 — Oracle indisponível. R: ______ · EV: ______
- [ ] **FAL-09** · B+E · P1 — GrandChef indisponível. R: ______ · EV: ______
- [ ] **FAL-10** · B+E · P0 — Reconciliação posterior e evento tardio. R: ______ · EV: ______

### KAN — Painel/Kanban e contingência (10)

- [ ] **KAN-01** · B · P1 — Chegada em tempo real e alerta. R: ______ · EV: ______
- [ ] **KAN-02** · A · P1 — Muitos cartões e scroll independente. R: ______ · EV: ______
- [ ] **KAN-03** · B · P1 — Resoluções da loja. R: ______ · EV: ______
- [ ] **KAN-04** · A · P2 — Contadores, cronômetro e detalhe. R: ______ · EV: ______
- [ ] **KAN-05** · A · P1 — Filtros e pendências anteriores. R: ______ · EV: ______
- [ ] **KAN-06** · B · P0 — Iniciar separação uma vez. R: ______ · EV: ______
- [ ] **KAN-07** · A · P0 — Bloquear PIX/estoque não prontos. R: ______ · EV: ______
- [ ] **KAN-08** · B · P1 — Atribuição/retirada sem app motoboy. R: ______ · EV: ______
- [ ] **KAN-09** · B+E · P0 — Despacho e conclusão por contingência. R: ______ · EV: ______
- [ ] **KAN-10** · A · P0 — Perfis negados e auditoria de retry. R: ______ · EV: ______

### IMP — Impressão e ticket físico (8)

- [ ] **IMP-01** · B+F · P1 — 80 mm e duas vias. R: ______ · EV: ______
- [ ] **IMP-02** · B+F · P1 — 58 mm quando adotada. R: ______ · EV: ______
- [ ] **IMP-03** · B+F · P1 — Corte e margens. R: ______ · EV: ______
- [ ] **IMP-04** · B+F · P0 — Pago — não cobrar. R: ______ · EV: ______
- [ ] **IMP-05** · B+F · P0 — A receber e hierarquia. R: ______ · EV: ______
- [ ] **IMP-06** · B+F · P0 — Split, BR e PY. R: ______ · EV: ______
- [ ] **IMP-07** · B+C+F · P0 — QR de rota e dados proibidos. R: ______ · EV: ______
- [ ] **IMP-08** · B+F · P1 — Reimpressão e falha do log. R: ______ · EV: ______

### TRA — Status e acompanhamento do cliente (6)

- [ ] **TRA-01** · B+C · P1 — Cadeia completa de estados. R: ______ · EV: ______
- [ ] **TRA-02** · A · P1 — Reabrir tracking e recuperar. R: ______ · EV: ______
- [ ] **TRA-03** · C · P1 — Perder internet e reconectar. R: ______ · EV: ______
- [ ] **TRA-04** · A · P1 — Status desconhecido. R: ______ · EV: ______
- [ ] **TRA-05** · A · P1 — Cancelado. R: ______ · EV: ______
- [ ] **TRA-06** · A · P0 — Isolamento entre contas. R: ______ · EV: ______

### CAN — Cancelamento e compensações (9)

- [ ] **CAN-01** · A · P0 — Proposta antes de existir pedido. R: ______ · EV: ______
- [ ] **CAN-02** · B+D · P0 — Antes do pagamento e antes da reserva. R: ______ · EV: ______
- [ ] **CAN-03** · B+D · P0 — PIX pendente. R: ______ · EV: ______
- [ ] **CAN-04** · B+D · P0 — PIX expirado. R: ______ · EV: ______
- [ ] **CAN-05** · B+E · P0 — Depois de RESERVE e antes de COMMIT. R: ______ · EV: ______
- [ ] **CAN-06** · B+D+E · P0 — Depois de COMMIT. R: ______ · EV: ______
- [ ] **CAN-07** · B+E · P0 — Pedido já concluído. R: ______ · EV: ______
- [ ] **CAN-08** · A · P0 — Retry e concorrência. R: ______ · EV: ______
- [ ] **CAN-09** · D+E · P0 — Pagamento confirmado após cancelamento. R: ______ · EV: ______

### FIN — Financeiro, CSV e fechamento (9)

- [ ] **FIN-01** · A · P0 — Matriz de elegibilidade. R: ______ · EV: ______
- [ ] **FIN-02** · A · P0 — Campos canônicos persistidos. R: ______ · EV: ______
- [ ] **FIN-03** · A · P0 — Legado compatível sem recalcular. R: ______ · EV: ______
- [ ] **FIN-04** · A · P0 — CSV versus indicadores. R: ______ · EV: ______
- [ ] **FIN-05** · B · P0 — Fechamento real de ensaio. R: ______ · EV: ______
- [ ] **FIN-06** · B · P0 — Comissão pendente. R: ______ · EV: ______
- [ ] **FIN-07** · A · P0 — Cancelado/revisão não contam. R: ______ · EV: ______
- [ ] **FIN-08** · A · P0 — Imutabilidade e leitura privada. R: ______ · EV: ______
- [ ] **FIN-09** · B+D+E · P0 — Conciliação PIX/dinheiro/estoque. R: ______ · EV: ______

### CAI — Caixa do motoboy no painel (6)

- [ ] **CAI-01** · B · P0 — Agrupamento por identidade real. R: ______ · EV: ______
- [ ] **CAI-02** · B · P0 — Pendentes e pagos. R: ______ · EV: ______
- [ ] **CAI-03** · B · P0 — Fechamento individual. R: ______ · EV: ______
- [ ] **CAI-04** · B · P0 — Lote e item inelegível. R: ______ · EV: ______
- [ ] **CAI-05** · B+F · P0 — Recibo e impressão. R: ______ · EV: ______
- [ ] **CAI-06** · A · P0 — Retry e concorrência de acerto. R: ______ · EV: ______

### EXC — Exclusão da conta (8)

- [ ] **EXC-01** · A · P0 — Solicitação e confirmação explícita. R: ______ · EV: ______
- [ ] **EXC-02** · A · P0 — Pedido ativo/pagamento/revisão bloqueiam. R: ______ · EV: ______
- [ ] **EXC-03** · C+D · P0 — Conta BR com pedidos fechados. R: ______ · EV: ______
- [ ] **EXC-04** · C+D · P0 — Conta PY com pedidos fechados. R: ______ · EV: ______
- [ ] **EXC-05** · A · P0 — Retry, falha parcial e app fechado. R: ______ · EV: ______
- [ ] **EXC-06** · A · P0 — Sessão expirada e conta privilegiada. R: ______ · EV: ______
- [ ] **EXC-07** · A · P0 — Dados pessoais versus preservação. R: ______ · EV: ______
- [ ] **EXC-08** · C+D · P0 — Login posterior e privacidade residual. R: ______ · EV: ______

### SEG — Segurança e permissões (10)

- [ ] **SEG-01** · A · P0 — Preços e quantidade adulterados. R: ______ · EV: ______
- [ ] **SEG-02** · A · P0 — Frete, taxa, distância e versão adulterados. R: ______ · EV: ______
- [ ] **SEG-03** · A · P0 — Estoque e status por SDK. R: ______ · EV: ______
- [ ] **SEG-04** · A · P0 — Financeiro privado. R: ______ · EV: ______
- [ ] **SEG-05** · A · P0 — Autenticação e isolamento. R: ______ · EV: ______
- [ ] **SEG-06** · A · P0 — Roles do painel. R: ______ · EV: ______
- [ ] **SEG-07** · A · P0 — Projeção do motoboy mínima. R: ______ · EV: ______
- [ ] **SEG-08** · B+F · P0 — PIN e PRO_CODIGO fora de saídas indevidas. R: ______ · EV: ______
- [ ] **SEG-09** · A · P0 — Replay e payload livre. R: ______ · EV: ______
- [ ] **SEG-10** · A · P0 — Catálogo restrito e idade. R: ______ · EV: ______

### NET — Conectividade e recuperação (7)

- [ ] **NET-01** · B+C · P1 — Wi-Fi da Pit Stop. R: ______ · EV: ______
- [ ] **NET-02** · C · P1 — Internet lenta. R: ______ · EV: ______
- [ ] **NET-03** · C · P0 — Desconexão durante checkout. R: ______ · EV: ______
- [ ] **NET-04** · C+D · P0 — Desconexão durante PIX. R: ______ · EV: ______
- [ ] **NET-05** · A · P0 — Clique duplo e timeout. R: ______ · EV: ______
- [ ] **NET-06** · C · P0 — Reconexão e sessão trocada. R: ______ · EV: ______
- [ ] **NET-07** · B+C+D · P1 — Travessia BR/PY e retorno ao app. R: ______ · EV: ______

### AND — Android real (4)

- [ ] **AND-01** · C · P1 — Instalação, versão e splash. R: ______ · EV: ______
- [ ] **AND-02** · C · P1 — Navegação e performance. R: ______ · EV: ______
- [ ] **AND-03** · C+D · P1 — Mapas e permissões. R: ______ · EV: ______
- [ ] **AND-04** · B+C+D+E · P0 — Checkout, PIX e recuperação. R: ______ · EV: ______

### IOS — iPhone real (5)

- [ ] **IOS-01** · C+D · P1 — Archive/TestFlight e identidade. R: ______ · EV: ______
- [ ] **IOS-02** · C · P1 — Splash, navegação e performance. R: ______ · EV: ______
- [ ] **IOS-03** · C+D · P1 — Mapas/permissões. R: ______ · EV: ______
- [ ] **IOS-04** · B+C+D+E · P0 — Checkout e PIX. R: ______ · EV: ______
- [ ] **IOS-05** · C+D · P0 — Apple e exclusão de conta. R: ______ · EV: ______

### GPL — Publicação Google Play — revisão documental futura (5)

- [ ] **GPL-01** · D · P1 — Registro, package e assinatura. R: ______ · EV: ______
- [ ] **GPL-02** · C+D · P1 — Build e testes exigidos. R: ______ · EV: ______
- [ ] **GPL-03** · C+D · P2 — Ficha e screenshots. R: ______ · EV: ______
- [ ] **GPL-04** · D · P0 — Privacidade, Data safety e exclusão. R: ______ · EV: ______
- [ ] **GPL-05** · D · P1 — Classificação, restritos e release. R: ______ · EV: ______

### APL — Publicação Apple — revisão documental futura (5)

- [ ] **APL-01** · D · P1 — App Store Connect e signing. R: ______ · EV: ______
- [ ] **APL-02** · C+D · P1 — TestFlight e regras de submissão. R: ______ · EV: ______
- [ ] **APL-03** · C+D · P2 — Ficha e review notes. R: ______ · EV: ______
- [ ] **APL-04** · D · P0 — App Privacy e account deletion. R: ______ · EV: ______
- [ ] **APL-05** · D · P1 — Produtos restritos, classificação e release. R: ______ · EV: ______

### POS — Pós-MVP — fora dos gates atuais (4)

- [ ] **POS-01** · G · P2 — App motoboy e aceite de ofertas. R: ______ · EV: ______
- [ ] **POS-02** · G · P2 — GPS e ETA reais. R: ______ · EV: ______
- [ ] **POS-03** · G · P2 — Border Mode completo. R: ______ · EV: ______
- [ ] **POS-04** · G · P3 — Marketplace/múltiplas lojas. R: ______ · EV: ______

### E2E — Ensaios integrados na Pit Stop V8 (4)

- [ ] **E2E-01** · B+C+D+E+F · P0 — Brasil dinheiro de ponta a ponta. R: ______ · EV: ______
- [ ] **E2E-02** · B+C+D+E+F · P0 — Brasil PIX sandbox de ponta a ponta. R: ______ · EV: ______
- [ ] **E2E-03** · B+C+D+E+F · P0 — Paraguai e fronteira. R: ______ · EV: ______
- [ ] **E2E-04** · B+C+D+E+F · P0 — Falha, cancelamento e reconciliação. R: ______ · EV: ______

## Lembretes críticos na bancada

- Horário MS: 07:59 fechado; 08:00 aberto; 23:59 aberto; 00:00 fechado. Simular fronteiras localmente; não alterar relógio de produção.
- Frete: primeira faixa inclui 0; seguintes (min,max]; máximo ativo L aceito, L+1 negado. Até 30 km e 100 m conforme tabela publicada; sem preço/rota fabricados, Haversine ou tarifa fixa de contingência.
- PIX: QR não é pagamento; esperar confirmação oficial/financeiro/estoque coerentes. PIX-01 a PIX-12 são sandbox. **PIX-13 é produção controlada futura e exige autorização específica; não executar nesta tarefa.**
- Dinheiro: BRL/PYG/USD conforme regras vigentes aprovadas; troco em BRL. Split vigente é dinheiro em 2–3 parcelas; PY sem cartão na entrega.
- Estoque: RESERVE debita físico uma vez; RELEASE devolve antes de COMMIT; COMMIT só lógico/delta físico zero; RESTOCK só após COMMIT/devolução autorizados. ACK/retry não repetem efeito.
- Chamaê não é venda normal de balcão a relançar no GrandChef. Venda normal de balcão continua independente.
- Kanban normal só inicia separação; sem app motoboy, despacho/conclusão exigem contingência superadmin autorizada/auditada e entregador real. QR de rota não muda status.
- Ticket: pagamento → valor/troco → endereço/referência → observações → itens → QR rota. PAGO — NÃO COBRAR ou A RECEBER coerentes; sem PIN/PRO_CODIGO. Medir 80/58 mm e corte/overflow no papel.
- Financeiro: Concluído + Pago + financialValidationStatus validated + valores oficiais completos. grandTotal conceitual = totalBRL; validationStatus conceitual = financialValidationStatus. Não recalcular histórico nem alargar fechamento de legado.
- Exclusão: pedido ativo/pagamento/revisão bloqueiam; Auth ao final; limpeza PII/pseudonimização preserva financeiros. Não prometer anonimização irreversível; revogação Apple e página externa Play exigem evidência.
- PIN: não em ticket/log/QR/projeção; revelação autenticada do próprio PIN é exceção funcional. PRO_CODIGO apenas painel/evidência interna.
- Publicação Android/Apple: verificar regra vigente de testes/API/SDK/Xcode/classificação/restritos, privacidade e exclusão; sem números/prazos presumidos. Signing release debug não aprova Android.

## Bloqueadores a acompanhar

| Ref. | Verificar antes de liberar | Situação / ticket / responsável |
| --- | --- | --- |
| KB-01 | Origem/tabela/travelMode/Routes reais e versões implantadas. | ______ |
| KB-02 | Bridge/ACK físico; reserva necessária antes de PIX; nenhuma dupla baixa Firebase/Oracle. | ______ |
| KB-03 | **PARCIAL**: guard/Rules implementados; 374 Functions, 343 emulador e 42 Flutter afetados aprovados; analyze sem issues. Pendem Geocoding/segredo, destinos reais BR/PY/fronteira, latência e revisão implantada. | [Evidência local](KB-03-HORARIO-PAIS-BACKEND-2026-10-24.md); responsável: ______ |
| KB-04 | **PARCIAL**: cancelamento/devolução local e proteção contra eventos tardios implementados; 388 Functions, 364 emulador e 40 Flutter afetados aprovados; analyze sem issues. Pendem PSP/refund, bridge/ACK físico, comissão externa e procedimento/painel. | [Evidência local](KB-04-CANCELAMENTO-COMPENSACOES-2026-10-24.md); responsável: ______ |
| KB-05 | **PARCIAL**: backend/painel registram tentativas e retornos; conclusão exige entrega/cobrança e revisão; RELEASE em rota/RESTOCK exigem retorno intacto. 403 Functions, 391 emulador, 40 Flutter cliente e 14 painel aprovados. Analyze cliente limpo; painel com dois infos anteriores. Pendem responsável/procedimento e ensaio físico; reentrega executável, parcial e refund/ACK externo. | [Evidência local](KB-05-CONTINGENCIA-ENTREGA-2026-10-24.md); responsável: ______ |
| KB-06 | **PARCIAL**: guard/contrato Apple, UID/link e limpeza local implementados e preservados. Retomada: 414 Functions, 20 emulador de conta/revogação e 74 Flutter afetados aprovados; analyze limpo. Emulador completo anterior: 403/403. Completo Flutter 207/209, duas fixtures pendentes. Faltam adaptador/Apple real, Google real, configuração iOS, URLs/suporte/recurso web, retenção e cache sem callback. Sem liberação de gate. | [Evidência/matriz KB-06](KB-06-PRIVACIDADE-APPLE-CONTA-2026-10-24.md); responsável: ______ |
| KB-07 | **RESOLVIDO LOCALMENTE / PENDENTE HOMOLOGAÇÃO GOOGLE PLAY**: responsável informou upload key oficial fora do repo, backup com hash idêntico, key.properties configurado/protegido e AAB release de 65.7 MB em build/app/outputs/bundle/release/app-release.aab. Certificado do AAB coincide com a upload key via keytool -printcert -jarfile; hashes registrados no relatório. Histórico local: analyze limpo e 209/209 Flutter, sem reexecução neste fechamento documental. Upload, Play App Signing e teste fechado não executados; gate Google Play/Android não liberado. | [Evidência KB-07](KB-07-ANDROID-SIGNING-BUILD-2026-10-25.md); responsável: ______ |
| KB-08 | Builds instalados, iPhone/Android, impressoras e rede de fronteira com evidência física. | ______ |

## Gates — preencher após conferir o manual

| Gate | IDs/grupos mínimos (detalhes no manual) | R / aprovador / data / evidência |
| --- | --- | --- |
| 1 — App Cliente | HOM, PRO, CAR, PER, HOR, END, TRA, NET | ______ |
| 2 — Painel | KAN, IMP | ______ |
| 3 — Frete | FRT | ______ |
| 4 — PIX | PIX | ______ |
| 5 — Estoque | EST, FAL | ______ |
| 6 — Financeiro | DIN, FIN, CAI, CAN | ______ |
| 7 — Segurança | SEG, EXC | ______ |
| 8 — Android | AND, GPL | ______ |
| 9 — iOS | IOS, APL | ______ |
| 10 — Operação real Pit Stop V8 | E2E | ______ |

Gate 3 também exige END reais; 4 exige estoque seguro e PIX-13 antes de recebimento real autorizado; 5 exige cancelamento/compensação aplicáveis; 7 inclui consentimento/privacidade das lojas. Gate 10 exige E2E, gates 1–7 e plataformas lançadas, pré-condições completas e **nenhum P0/P1 aberto**.

N/A de plataforma só com exclusão formal dessa liberação; Android não libera iOS e vice-versa. Preview/PDF, handler local e teste de widget não aprovam, respectivamente, papel físico, acionamento remoto e aparelho real.

## Encerramento

- [ ] Pedidos, PSP/eventos, quotes, ledger/ACK e saldos físico/espelho/reserva conciliados.
- [ ] Cancelamentos/estornos/devoluções resolvidos ou bloqueados com responsável; nenhuma duplicidade.
- [ ] CSV/indicadores/líquido/comissão/acertos/recibos conferidos usando snapshots, sem recalcular histórico.
- [ ] Evidências saneadas guardadas; nada de senhas/tokens/PIN em anexos comuns.
- [ ] Falhas por severidade, retestes, N/A e gates assinados por operação/financeiro/estoque/técnico.
- [ ] Decisão registrada: liberar / não liberar; plataforma(s), país(es), build(s), data/hora e responsáveis.

Decisão: __________ • Pendências: __________ • Aprovação humana: __________

**Checklist originalmente documental, atualizada pelas implementações/testes locais KB-03 e KB-04 (PARCIAIS), detalhados nos respectivos relatórios. Nenhum gate operacional liberado. Firebase produção e Oracle/GrandChef não acessados; nenhum commit, push ou deploy. Aguardar revisão humana.**

