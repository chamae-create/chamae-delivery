# Auditoria anterior à implementação do fluxo definitivo

Auditoria em 18/10/2026, concluída antes das alterações desta etapa. Há alterações locais de etapas anteriores, preservadas. Nenhum AGENTS.md localizado. Sem deploy, commit ou push.

- Entrada atual: splash oficial → bootstrap Firebase com criação/restauração anônima → destino → catálogo. É necessário trocar o bootstrap e acrescentar gate de sessão/onboarding.
- Tema já contém paleta, espaçamento, raios, botões, cards e inputs; reutilizar, refinando apenas os novos componentes e estados.
- Firebase Auth instalado. Google/Apple, tela de login, logout explícito, data de nascimento e documentos versionados não existem. Não foi localizada configuração OAuth nativa completa de Google/Apple nem documentação legal oficial para publicar.
- Regras e contratos de compra/PIN exigem `customerVerified` e identidade não anônima. A nova autenticação precisa ser reconhecida a partir de dados confiáveis do token Firebase, sem aceitar booleano do cliente. Esse é o motivo das alterações pontuais necessárias nas Rules/Functions.
- Endereço manual/GPS explícito, mapa ajustável, revisão BR/PY, Casa/Trabalho/Outro e último destino já existem. Faltam exclusão, padrão, timestamps e retorno direto ao catálogo. O fluxo anterior oferece reutilização, enquanto o novo pedido autoriza reutilização automática indicada na Home.
- Workspace Firestore privado persiste carrinho, endereço e proposta. Não há DOB/aceite versionado. Novos registros de consentimento devem ficar separados, com gravação autenticada no servidor e timestamps de servidor.
- Home, catálogo, filtros, estoque disponível, horário MS, PIX, dinheiro/troco e cartão BR já implementados. Não reescrever financeiro/estoque. Cartão continua usando o contrato `Maquininha` com `cardType: null`, sem seleção débito/crédito.
- Restauração do carrinho ainda usa dados salvos sem conferir de imediato cada produto atual; a conferência autoritativa final já existe. Acrescentar reconciliação visível na restauração.
- PIN fixo, criptografia, reset protegido e contrato por pedido já existem; segredo e integração futura do entregador continuam pendentes. Não usar PIN como autenticação.
- Acompanhamento/chat existem. Há contador unread no backend; apresentar indicação no botão do chat, sem depender de push.
- Frete por faixas permanece inativo, com publicação/versionamento e `RoutingProvider` já existentes. A prioridade agora é Google Routes; preparar configuração/documentação sem escolher chave, preencher preços ou ativar cobrança.
- Ferramentas: Flutter Web e testes disponíveis. Android SDK/Java não estavam disponíveis na validação anterior; iOS requer macOS/Xcode. Reavaliar ambiente no fechamento sem declarar build nativo inexistente.

Documentos oficiais/versões e estado da configuração Firebase Google/Apple foram solicitados. O restante do trabalho pode avançar usando contratos e testes injetados, sem fingir aceite legal ou login externo aprovado.
