# CHAMAÊ DELIVERY — App cliente premium final

Referência: 18/10/2026, Windows, Flutter 3.47.5/Dart 3.13.4. Este relatório descreve o fluxo oficial atual e substitui a descrição anterior deste arquivo. Implementação local; nenhum deploy, commit ou push.

Auditoria anterior às alterações: [fluxo oficial](app_cliente_fluxo_oficial_auditoria_2026-10-18.md). A base de endereço, catálogo, pagamentos, carrinho, PIN e chat foi reaproveitada. Mudanças locais anteriores foram preservadas. Os detalhes técnicos/configurações estão em [autenticação e onboarding](../functions/docs/customer-auth-onboarding.md).

## FLUXO FINAL

Primeira utilização: Splash → Google/Apple → nascimento e documentos versionados → destino manual/GPS → mapa ajustável → conferência/complemento → salvar → catálogo → carrinho → checkout → pedido/chat/acompanhamento.

Retorno: Splash → sessão restaurada → consentimento corrente → último destino confirmado, ou padrão quando não há último destino → catálogo. A Home indica o endereço usado e permite alterar. Não repete mapa ou login sem necessidade. Versões já aceitas ficam reconhecidas; documento alterado exige novo aceite. Mudança de conta/logout descarta toda a pilha de telas privadas.

A possibilidade excepcional de explorar o catálogo sem destino permanece após login/onboarding; finalizar exige destino confirmado e cotação válida.

## SPLASH

Marca oficial existente, fundo carvão, assinatura Loumak discreta, fade/zoom suaves e brilho dourado discreto. Sem bandeiras, arte substituta ou atraso mínimo artificial. Respeita redução de animações. Inicializa Firebase, persistência e restauração de sessão; deixou de criar sessão anônima automaticamente. Sessão anônima antiga pode ser vinculada ao login, preservando UID.

## AUTENTICAÇÃO

Tela dedicada com Google e Apple, mensagens curtas, loading e proteção contra cliques simultâneos. Google primeiro no Android; Apple primeiro no layout iOS. Telefone aparece somente como alternativa em preparação.

Web usa popup Firebase. Google nativo usa o SDK oficial google_sign_in 7.2.0 e credencial Firebase. Apple usa o provider oficial Firebase. Identidade adicional é vinculada ao UID existente. Conflito com outro UID exige escolha explícita na entrada; não há migração silenciosa de pedidos/carrinhos. Perfil não troca de conta ao tentar vincular um provedor.

Persistência de sessão, refresh, logout e tratamento de conta revogada implementados. Erros técnicos do SDK não são apresentados ao usuário. O gate mantém rotas privadas em um Navigator próprio, descartado ao sair/trocar conta. Falha da assinatura de sessão tem retry com nova assinatura.

**Configuração externa pendente confirmada pelo usuário:** Google e Apple ainda não estão habilitados/configurados no Firebase. Não houve login real homologado. Os testes de SDK usam doubles e não comprovam Console, domínio, SHA, nonce externo, credenciais Apple ou aparelhos reais. Android tem listas OAuth vazias no google-services.json auditado; iOS precisa dos identificadores/capabilities/URL schemes oficiais. Nenhum segredo foi inventado.

## TERMOS/IDADE

Nascimento, aceite dos Termos, ciência da Privacidade e regras de álcool precedem o catálogo. Documentos abrem internamente e exibem versão e fonte. O backend registra versões, revisão, hash do conteúdo e acceptedAt/firstAcceptedAt de servidor, com auditoria transacional e idempotência. O workspace não pode conceder consentimento ou identidade.

O usuário confirmou que não existem documentos finais. Foram usados apenas marcadores DRAFT, sem texto jurídico inventado ou URL fictícia de produção: [configuração de desenvolvimento](config/customer_documents.draft.json). Versões draft-2026-10-18, published:false e draft:true. DRAFT não pode liberar onboarding/compra em produção, mesmo por chamada direta da API. Não foi publicada configuração legal.

A configuração futura customerPolicies/current contém snapshot aprovado do texto, URLs HTTPS oficiais, versões, revisão, hash e regras de elegibilidade. Publicar novo snapshot/versão não exige refazer as telas. O cliente não aceita HTML remoto mutável como prova de consentimento.

DOB é validada como data e armazenada como declarada, com dateOfBirthVerified:false. Não é prova de identidade/idade. Limiar por país depende da política aprovada; nenhum valor legal BR/PY foi presumido. Produto restrito sem regra configurada fica bloqueado. O servidor usa cadastro oficial/flags e categorias alcoólicas existentes; classificação e operação de conferência documental precisam de homologação. Correção de DOB já registrada exige atendimento, para impedir troca livre que contorne elegibilidade.

## ENDEREÇO

Localização apenas após toque explícito. O mesmo serviço usado pelo mapa foi testado para permissão autorizada, negada, bloqueada e serviço desativado. Negativa não lê posição e oferece endereço manual. O mapa não habilita localização implicitamente.

Entrada manual, pino central, geocoding estruturado, confirmação explícita, revisão de rua/número/sem número/bairro/cidade/país/complemento/referência. BR/PY são somente leitura quando identificados; fallback manual só quando o país é desconhecido. País fora de BR/PY não é aceito no fluxo normal.

Casa/Trabalho/Outro podem ser selecionados, editados, excluídos e definidos como padrão. Guarda endereço estruturado, coordenadas e timestamps; criação é preservada ao editar. Timestamps de endereço são de cliente para organização, sem autoridade financeira. Alterar endereço não elimina carrinho e invalida a cotação anterior.

GPS/geocoding reais e gesto de mapa ainda exigem aparelhos/credenciais válidos. País informado pelo app não substitui futura validação geográfica autoritativa de cobertura/país no servidor; isso deve ser homologado antes da liberação de regras comerciais dependentes do destino.

## HOME

Cabeçalho com endereço indicado, loja aberta/fechada, alterar, busca, categorias, ofertas, combos, produtos e vídeo Pit Stop V8. Nome/label do destino ficam visíveis; catálogo sem destino indica a necessidade de endereço para calcular entrega. Tema compartilhado mantém carvão, off-white, dourado, cinzas e cores de estado, radius/padding/inputs/botões consistentes.

## CATÁLOGO

Filtros e bloqueios comerciais preservados. Itens bloqueados não aparecem; sem estoque ficam indisponíveis. Imagem/placeholder, preço, quantidade e adicionar mantidos. Não expõe reserva/financeiro interno. Ordenação e funcionalidades existentes reaproveitadas, sem funcionalidades sociais/fidelidade novas.

## CARRINHO

Persistência privada por UID com cache local Firestore habilitado. Na restauração, busca dados atuais e avisa sobre mudança de preço/estoque/disponibilidade. Bloqueio comercial é conferido no cadastro oficial. Falha de conexão mantém itens e preços salvos, informa o problema e exige revalidação antes de comprar. Não apresenta dado em cache como confirmação final do servidor.

A limpeza do carrinho/proposta após confirmação ocorre atomicamente e retira apenas quantidades compradas, preservando adições posteriores. Pedido/PIX pendente mantém proposta com ID único; retry lê servidor antes de repetir escrita incerta. Uma proposta descartada pelo backend recebe marca que impede criação atrasada pelas Rules. Retomar pedido já recebido não recria proposta reconciliada.

Cache/sessão dependem do aparelho/navegador. Limpar dados do navegador remove cache/login local. Não foi criada mesclagem simultânea de carrinhos entre dispositivos.

## CHECKOUT

Organizado em entrega, resumo, pagamento e total. Dados conhecidos de nome/contato aparecem preenchidos/compactos, com edição; telefone só é pedido quando necessário para entrega. Contato é preservado no workspace. Checkout não inicia login Google/Apple: a autenticação foi antecipada para a entrada.

Trocar destino mantém itens e recalcula cotação. Preço/estoque/frete/consentimento/elegibilidade são revalidados. Erros mostram retry amigável. Novos pedidos identificam customerFlowVersion:2; Rules e backend exigem consentimento atual. Pedidos antigos e financeiro já congelado continuam no contrato anterior.

## PAGAMENTOS

Brasil: PIX, dinheiro e Cartão na entrega, sem escolher débito/crédito. Paraguai: PIX e dinheiro. Mantidos contrato Maquininha/cardType:null para cartão novo, BRL contábil, BRL/PYG/USD, troco BRL e divisão existente.

PIX mantém criação, QR/copia e cola, feedback ao copiar, aguardando/pago/erro/expirado e reabertura pelo acompanhamento. Retry não gera nova cobrança. Não houve cobrança real, webhook real ou teste de pagamento de produção. Estoque, reservas, finalização e taxas oficiais não foram reescritos.

Horário preservado: diariamente 08:00–00:00 MS. Catálogo navegável fora do horário; checkout bloqueado. A apresentação usa relógio do aparelho, não é prova de imposição do horário pelo servidor.

Frete CHAMAE-FRETE-30KM permanece inativo. Google Routes agora tem adaptador de servidor preparado e testado com respostas fake; não está instalado na callable ativa. Nenhuma chave secreta no app. Ativação ainda depende de origem, veículo/cobertura, chave, preços, decisão do piso e separação da remuneração do entregador. Legado R$ 10 preservado.

## PIN

Seu PIN de entrega: máscara ••••, revelar/ocultar e orientação para informar somente ao receber. Retira valor da tela ao trocar sessão/ir para segundo plano. Reset solicita confirmação de identidade com Google/Apple e exige conta recente e ausência de pedido ativo no servidor.

Preservados PIN aleatório fixo, criptografia, segredo de servidor e contrato por pedido. PIN nunca é login/OTP/senha. Não é enviado em texto ao entregador. Segredo de PIN e homologação real de reset ainda são necessários; conferência por pedido/tentativas/reconciliação no app do entregador continuam dependências futuras. Não se declara validação offline segura implementada.

## CHAT

Chat por pedido preservado, com entrada pelo acompanhamento e indicação de mensagens não lidas usando metadados existentes. Atualiza sem push, mantém isolamento por UID e cancelamento de listeners. Não há chat geral novo. Timeline continua Pedido recebido, Em separação, Aguardando retirada, Saiu para entrega e Entregue.

Notificações continuam contextuais no pedido, sem permissão na abertura. Contrato existente informa indisponibilidade enquanto não houver adaptador push real; acompanhamento e chat seguem dentro do app.

## SEGURANÇA

Identidade é reconhecida a partir do token validado pelo Firebase; gravação de booleano no cliente não autentica. Consentimento, auditoria e DOB só são escritos pelo backend. Rules exigem identidade, versão de fluxo, destino e consentimento atual. Financeiro repete a elegibilidade antes de cobrar, com produtos oficiais e snapshot da política. Documento exigível no recebimento é registrado sem declarar DOB verificada.

Alterações de backend foram limitadas ao necessário para o novo login/consentimento/eligibilidade e preparação Routes. PIX/estoque/financeiro congelado, segurança de UID, chat e remuneração existente preservados. Nenhum papel administrativo ampliado. Conteúdo jurídico e preços reais não foram inventados.

## PERFORMANCE

Bootstrap restaura sessão, perfil/documentos e workspace com leituras essenciais em paralelo. Catálogo usa stream estável; listas/imagens/placeholder e listeners existentes reaproveitados. Rotas privadas são descartadas ao mudar identidade. Busca manual não dispara GPS. Não foram medidas memória/FPS/performance em hardware; não se afirma benchmark nativo aprovado.

## TESTES

- Suíte VM final completa: 81 testes aprovados, incluindo retry da assinatura de sessão, primeira visita, retorno, Google/Apple, DOB/versões legais, endereços, carrinho, pagamentos, horário, chat e PIN.
- Backend: 246 testes aprovados, incluindo identidade Google/Apple, vínculo/consentimento, DRAFT recusado, DOB, idade por destino, legado, financeiro oficial, Google Routes fake, PIN e idempotência.
- Rules/fluxo integrado: 259 testes aprovados em emulador Firestore local com projeto demo-chamae-rules. Java portátil oficial, checksum SHA-256 conferido, dentro de .dart_tool ignorado pelo Git. O bloqueio anterior de ausência de Java foi resolvido para esses testes.
- Análise estática do cliente: última execução concluída sem ocorrências. Lint Functions aprovado.
- Chrome/Web: suíte completa com 81 testes aprovados, incluindo o smoke Web, mais 11 testes de jornada aprovados na verificação final após o ajuste de retry de sessão. Usa o contorno local tool/chrome_test_assets.mjs para CanvasKit no runner Windows/Flutter 3.47; não altera SDK/aplicação nem usa serviço externo de assets. O auxiliar passou a permitir 30 minutos e encerra junto ao navegador, pois a compilação concorrente excedeu o limite anterior de dez minutos nesta máquina.
- Testes de layout incluem 320/390/430, texto ampliado, SafeArea e teclado nos fluxos existentes; iOS simulado valida prioridade Apple. Não equivale a homologação Android/iPhone real.

## BUILD

Build Web release aprovado: execução completa com diagnóstico Wasm aprovado (744,5 s) e artefato atualizado após o último ajuste de sessão com flutter build web --release --no-wasm-dry-run (53,5 s). Saída em build/web. O parâmetro da última execução desabilita somente o diagnóstico Wasm adicional; o artefato continua sendo JavaScript/CanvasKit, não uma homologação de app Wasm.

Build Android tentado: falhou com No Android SDK found. Java portátil de teste não fornece SDK Android, ferramentas de assinatura ou JDK completo de build. Não foi produzido APK/AAB novo. iOS não foi compilado no Windows; requer macOS/Xcode e configuração Apple.

## BLOQUEADORES

1. Substituir Termos e Política DRAFT pelos documentos oficiais e URLs públicas.
2. Habilitar/configurar Google e Apple no Firebase e plataformas, homologar login real, vínculo/conflito, restauração, revogação e reautenticação para PIN.
3. Aprovar política de elegibilidade BR/PY, classificação dos produtos e conferência documental operacional. DOB declarada não é comprovação; cobertura/país precisam de validação confiável no servidor.
4. Para novo frete: preços, piso, origem, credencial Google Routes, modalidade/cobertura real e remuneração separada. Não ativado.
5. SDK Android/assinatura e ambiente macOS/iOS; homologação real de mapas/GPS, pagamentos, PIN e vídeo. Push real e integração futura do entregador permanecem pendentes.

## DEPLOY NECESSÁRIO

Nenhum deploy, commit ou push. A implementação é revisável localmente, com configurações externas explicitamente pendentes.

Após resolver os itens de publicação, coordenar Functions, Rules, índices, políticas oficiais e cliente compatível em homologação. Não publicar Rules isoladas esperando o fluxo anônimo antigo continuar criando compras. Não ativar faixas de frete por publicar uma tabela. Provisionar segredo do PIN e credenciais Routes exclusivamente no ambiente seguro do servidor. Validar ponta a ponta antes de publicar nas lojas.

Principais arquivos novos: customer_auth/customer_onboarding/customer_location/restore_customer_cart, telas login/session_gate/onboarding/legal_document, CustomerChatEntry, módulos backend customer-identity/customer-onboarding/google-routes-provider e testes correspondentes. Integrações em main/splash/endereço/Home/carrinho/checkout/perfil/PIN/tracking/Rules/financeiro. Dependência Google Sign-In e registradores gerados atualizados. Não houve implementação de histórias, rede social, fidelidade ou motoboy offline.

**APP CLIENTE AINDA POSSUI BLOQUEADORES**
