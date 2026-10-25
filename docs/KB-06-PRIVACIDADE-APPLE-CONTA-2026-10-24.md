# KB-06 — Privacidade, Apple e ciclo da conta

Data-base solicitada: 24/10/2026. Auditoria e validação local: 25/10/2026.

## Inventário anterior às alterações

Inventário registrado antes das alterações funcionais. Repositório já continha
trabalho de frete, conta e KB-03/04/05, preservado. Cópias em `tool/kb06/before`;
artefatos Dart têm extensão `.dart.txt` para não participarem do analyze.

| Item | Estado anterior | Evidência / limite |
| --- | --- | --- |
| Google | IMPLEMENTADO | Web popup; Android/iOS `google_sign_in` + credencial Firebase. Configuração e login reais não verificados. |
| Apple | PARCIAL | Provider Firebase oficial, popup Web e provider nativo; capability/credenciais reais não comprovadas. |
| Nonce/state | PARCIAL | Fluxo delegado ao SDK Firebase, sem montagem manual de ID token. Não há auditoria executada do protocolo Apple real. |
| Anônimo | PARCIAL | Não há criação anônima no app atual. Sessão anônima restaurada cai no login e pode fazer link preservando UID; não é identidade verificada. |
| Link Google/Apple | IMPLEMENTADO | Identidade atual usa link, sem migração ou mesclagem. Conflito exige escolha explícita no login; perfil não troca conta. |
| Troca silenciosa | PARCIAL | Verifica UID após link, mas não encerra uma identidade inesperada e não repete todas as verificações após refresh. |
| Cancelamento/credencial inválida | PARCIAL | Erros amigáveis e conflitos tratados; cobertura Apple e confirmação de identidade incompletas. |
| Refresh / removido / desabilitado | PARCIAL | `idTokenChanges`, reload e refresh na retomada. Refresh encerra tokens inválidos; sign-in não inclui user-not-found no mesmo tratamento. |
| Logout | PARCIAL | Firebase signOut + encerramento local Google inicializado; sem desconexão/revogação do provedor. Limpeza dos campos globais de perfil é incompleta. |
| Exclusão | IMPLEMENTADO | Solicitação própria/reautenticada; worker, preflight, bloqueio de escrita, retry, pseudonimização, PII removida e Auth ao final. Não reescrever. |
| Revogação Apple | AUSENTE | Nem app nem worker revogam. Authorization code/access/refresh token não são retidos. Apagar Firebase não prova desautorização Apple. |
| Cache | PARCIAL | Firestore persistente e Auth Web LOCAL; rotas por UID descartadas, mas não há purge do cache Firestore após exclusão. |
| Logs | PARCIAL | Sem logging explícito de tokens, mas auth/bootstrap imprimem UID e caminho com UID em debug. |
| Termos/privacidade | PARCIAL | Visualização interna no onboarding/perfil. Documentos DRAFT locais e URLs nulas no exemplo; nenhum documento público oficial comprovado. |
| Suporte | AUSENTE | Mensagens citam suporte/loja, mas não foi localizado canal oficial configurado/acessível nesse fluxo. |
| DOB/restrições | IMPLEMENTADO | Calendário, futuro, política/hash/aceites, idade por país/produto e DOB não verificada. Política jurídica/classificação real pendentes; preservar. |
| Rules/Functions | IMPLEMENTADO | Exclusão é própria, veda roles/entregador/anônimo; worker autoritativo; estado bloqueia recriação de PII. |
| Publicação | PARCIAL | Não comprovados App Store Connect/TestFlight/Play, recurso web de exclusão, formulários, retenção/backups/cache ou configuração OAuth real. |

## Resultado e evidências

**KB-06: PARCIAL.** Proteções e testes locais concluídos. **Não homologado com
Apple real, Google real, App Store Connect, Play Console ou TestFlight.**
O contrato de revogação está preparado; o adaptador real e suas credenciais não
existem nesta integração. A exclusão Apple permanece bloqueada de forma segura.

## Autenticação e identidade

`FirebaseCustomerAuth` continua usando `idTokenChanges`, popup na Web,
`google_sign_in` 7.2.0 no Google nativo e provider oficial Firebase para Apple.
Login Google/Apple normal, link de anônimo e link de conta já identificada
foram exercitados com doubles do SDK. Link conserva UID; conflito não mescla
contas/pedidos/endereço. Só a escolha explícita `useExistingAccount` permite
entrar na outra conta. Pelo perfil, conflito permanece erro, sem troca automática.

Agora o resultado `UserCredential.user.uid` é comparado com o UID esperado e
a sessão é conferida antes/depois de reload e refresh. Identidade inesperada
é encerrada; nenhum usuário novo é aceito silenciosamente. Cancelamentos
Apple/Google e credencial/nonce inválidos não exibem mensagens internas.
`user-not-found` também encerra a sessão no caminho de sign-in. Refresh já
tratava conta removida, desabilitada e tokens expirados/inválidos; seus testes
agora verificam a limpeza de todos os campos globais pessoais.

Não há geração de conta anônima no app atual. Uma sessão anônima restaurada
é encaminhada ao login e pode fazer link conservando seu UID. Não equivale a
identidade verificada; exclusão de cliente e aceite de documentos continuam
negados para anônimo, inclusive com `customerVerified` adulterado. Dados de
eventuais contas anônimas legadas exigem inventário operacional; não foi criado
um novo serviço de exclusão anônima nem concessão de privilégios.

Credencial administrativa pode autenticar no Firebase, mas não autoriza
aceite/exclusão pelo fluxo de cliente. Roles e cadastro de entregador são
validados no backend; promoção administrativa posterior à solicitação continua
bloqueando o worker. Não foi criado bypass no app.

## Apple: logout, exclusão e revogação

| Evento | Comportamento real |
| --- | --- |
| Logout | Encerra sessão Firebase/local; não exclui conta nem revoga concessão Apple. |
| Exclusão Chamaê | Solicitação autenticada + worker existente. Apaga/minimiza os dados previstos e exclui Auth ao final, condicionado à revogação quando Apple está vinculada. |
| Revogação Apple | Etapa distinta e anterior ao apagamento. Exige confirmação vinculada ao sujeito Apple; hoje o adaptador real não está configurado. |

O uso de `AppleAuthProvider` delega o fluxo federado ao SDK; não existe criação
manual de ID token/nonce/state neste app. Isso não é evidência de protocolo
homologado com Apple real. A alternativa manual com ID token exigiria nonce
validado, mas não foi introduzida. O caminho oficial e a configuração da
capability constam da [documentação Firebase](https://firebase.google.com/docs/auth/flutter/federated-auth#apple).

O SDK instalado `firebase_auth` 6.7.0 expõe
`revokeTokenWithAuthorizationCode` nas plataformas Apple e `revokeAccessToken`
no Android; Web não implementa essa mesma API nativa. Essas APIs foram
inspecionadas localmente, **não chamadas nesta tarefa**. O login atual não retém
authorization code/access/refresh token. Um retorno alegado pelo cliente não
foi tratado como prova financeira/administrativa de revogação.

A Apple orienta revogar os tokens de Sign in with Apple na exclusão. Não basta
apagar o usuário Firebase. Isso é um requisito de publicação a homologar,
conforme [orientação oficial Apple](https://developer.apple.com/support/offering-account-deletion-in-your-app/).

### Contrato preparado no servidor

Novo `customer-provider-revocation.js`, integrado antes da fase processing e
de qualquer redação/exclusão:

1. A solicitação registra necessidade Apple a partir do ID token verificado
   (`sign_in_provider`/`identities`), nunca do payload.
2. O worker confere `getUser().providerData` do Admin SDK. Apple vinculada
   exige revogação mesmo se o login atual foi Google.
3. `revokeApple({uid, subject, idempotencyKey})` é dependência **somente interna**.
   Não há callable que aceite um booleano, token ou recibo fornecido pelo cliente.
4. O adaptador futuro deve obter credencial autorizada ligada ao sujeito,
   executar a revogação real e ser idempotente pela chave recebida. Não há
   implementação de rede/segredo fictício nem retorno simulado no caminho padrão.
5. Só resposta de servidor `revoked === true` com sujeito correspondente gera
   `customerProviderRevocations/{uid}`. O recibo guarda hash do sujeito,
   fingerprint, requestId e timestamps; não guarda token/código/chave.
6. A chave inclui UID, sujeito e solicitação exata (`requestedAt`, segundos e
   nanossegundos). Mesmo requestId de uma nova solicitação não reaproveita
   uma revogação antiga. Escritas e avanço de fase conferem essa geração.
7. Resposta antiga não sobrescreve recibo/estado nem autoriza nova exclusão.
   Retry da mesma solicitação reutiliza a confirmação, inclusive após falha
   transitória posterior no apagamento do Auth.

Sem integração, identidade ou confirmação seguras, o job fica `blocked` com
um dos códigos `APPLE_REVOCATION_NOT_CONFIGURED`, `IDENTITY_UNVERIFIED`,
`FAILED`, `UNCONFIRMED`, `REQUEST_UNVERIFIED` ou `REQUEST_CHANGED` (todos com
prefixo `APPLE_REVOCATION_`). Falhas do provedor são sanitizadas. O app apresenta
“Revogação Apple pendente”, não “Conta excluída”; nova tentativa continua
disponível com consentimento e reautenticação explícitos.

O pipeline de preflight, redação paginada, limpeza de coleções e Auth ao final
foi preservado. O guard novo não chama provedores para Google sem Apple.
Pedidos em andamento bloqueiam antes de tentar revogar. A confirmação real
continua pendente de credenciais/configuração e de ligação segura da credencial
ao sujeito; nenhum segredo Apple foi criado, lido de produção ou armazenado no app.

## Google

Logout Firebase e signOut local do Google inicializado não são `disconnect`.
Excluir Chamaê não apaga a conta Google. Não há acesso delegado a Drive/Gmail
ou scopes adicionais de negócio neste fluxo; não foi adicionada revogação
Google automática. O SDK separa autenticação, autorização e desconexão,
conforme sua [API oficial](https://pub.dev/documentation/google_sign_in/latest/google_sign_in/GoogleSignIn-class.html).
Novos scopes exigiriam revisão própria de consentimento/revogação.

Inventário de configuração, sem expor valores: o JSON Android atual contém
quatro entradas de cliente, com 2/1/1/1 registros OAuth. Isso não prova SHA,
domínio ou login real corretos. No plist Google iOS não foram encontradas as
chaves CLIENT_ID/REVERSED_CLIENT_ID; Runner não contém URL Types nem
CODE_SIGN_ENTITLEMENTS. Dart defines para IDs públicos já são suportados, mas
seus valores no build real não foram comprovados. Nenhum arquivo de configuração
Google/Apple foi modificado.

## Exclusão e limpeza local

Solicitação permanece própria, confirmação literal, UID esperado,
reautenticação recente e sem campos extras. Anônimo, terceiro, roles e
entregador continuam negados. Worker continua autoritativo e idempotente;
conclusão não é inferida de timeout ou de um botão pressionado.

`UserSession.clearPersonalData()` limpa nome, nome social, telefone, documento
e indicador de cadastro no logout/troca de UID, além da exclusão. Preferência
de idioma permanece. Gate descarta rotas privadas e referências em memória a
perfil/workspace/endereço/consentimento ao sair/trocar identidade.

Após `completed` observado pelo cliente, `CustomerLocalPrivacy`:

- fecha a sessão Firebase e o estado local Google quando aplicável;
- executa `terminate()` e `clearPersistence()` da instância Firestore;
- impede outro login/uso de rotas privadas até reiniciar o app/recarregar a Web;
- mantém falha de limpeza visível, com retry explícito; não anuncia cache limpo
  quando o SDK falha. Reexecução depois de sucesso não limpa novamente.

O Firestore do repositório de conta é inicializado somente ao usar dados;
construir o repositório/validar UID não inicializa Firebase desnecessariamente.
Falha de UID antes da limpeza não encerra nem limpa a conta de outro usuário.

Limites: limpeza de cache foi validada com fake do SDK, não em dispositivos.
Logout comum não apaga todo o cache persistente. Se o app não observar
`completed` (por exemplo, encerrado antes da limpeza), não há marcador local
durável de purge nesta implementação; sessão removida é tratada no refresh,
mas o descarte de cache nesse caminho precisa definição/validação adicional.
Uma falha de purge seguida de encerramento do processo também requer
reconciliação. `clearPersistence` não é apagamento forense nem cobre backups,
conforme [referência Firestore](https://firebase.google.com/docs/reference/js/firestore#clearindexeddbpersistence).
Não declarar anonimização irreversível, eliminação de backups ou revogação
universal de todas as sessões/provedores por esse mecanismo.

## Matriz de dados — base para revisão de privacidade/Data Safety

Inventário de código, não respostas oficiais nem definição de base legal.
Prazo, obrigação de retenção, compartilhamento jurídico e responsáveis devem
ser aprovados por privacidade/jurídico e pelos contratos de cada prestador.

| Categoria | Finalidade / armazenamento observado | Destino na exclusão | Preservação e revisão necessária |
| --- | --- | --- | --- |
| UID, nome, e-mail, provedor | Firebase Auth; identidade em memória. Nome também no pedido; email/documentos podem existir em campos legados. | Auth excluído ao final; campos pessoais previstos removidos; cliente global limpo. | UID é substituído em pedidos por `deleted_sha256(uid)`: pseudonimização correlacionável, não anonimização definitiva. |
| Nome social, telefone, documento | UserSession/registro legado; telefone e contato de entrega em orders/workspace. | Globais e workspace apagados; campos customerPhone/customerDocument/CPF etc removidos quando presentes. | Não presume que formulário legado é coleta obrigatória do fluxo atual. Cópias externas precisam inventário. |
| DOB declarada | customerProfiles e customerConsentEvents; elegibilidade por política/país/produto. | Perfil e subcoleções de consentimento removidos. | DOB não é prova de identidade; snapshot de elegibilidade operacional não contém DOB e permanece. |
| Aceites/versionamento | Perfil/consentimento com versões, hash, revisão e timestamps. | Coleções por UID apagadas pelo worker. | Política ativa é configuração geral, não dado individual. Retenção jurídica de prova de consentimento precisa revisão; não foi inventado prazo. |
| Endereço/coordenadas | Workspace, orders, deliverySnapshot, cotações privadas, projeção do entregador; uso no mapa/geocoding/rota. | Workspace/cotações/projeção apagados; destino removido de orders/orderFinancials. | Distância/unidade/versão/faixa do frete preservadas para rastreabilidade; requisições/retencão de prestadores externos não são apagadas pelo worker. |
| PIN | Segredo cifrado por UID, verificador por pedido e audit de PIN. | customerDeliverySecrets, deliveryPinVerifiers e audit UID removidos. | Não há PIN em logs novos nem nova regra de entrega nesta tarefa. |
| Sacola e proposta pendente | customerWorkspaces; estado em memória. | Documento/filhos apagados; referências do gate descartadas. | Logout preserva dados da conta no serviço; exclusão remove. Cache tem os limites descritos acima. |
| Pedidos/financeiro/estoque | orders, orderFinancials, pagamentos/PSP IDs, snapshots e ledgers operacionais. | PII prevista minimizada; valores, itens, status, estoque e referências necessárias preservados. | Necessidade/prazo de preservação depende revisão jurídica e operacional; não recalculado nem compensado nesta tarefa. |
| Conversas e avaliações | orderChats e reviews por cliente. | Conversas encerradas apagadas recursivamente; reviews por UID removidas. | Mensagens livres podem conter PII; evitar manter cópias de suporte fora desse fluxo sem política. |
| Auditorias operacionais livres | Contingência/cancelamento/devolução e registros de operação privados. | Histórico necessário permanece; worker não varre todo texto livre nessas auditorias. | Motivos podem conter PII indevida apesar da orientação do painel. Revisar minimização/retenção e procedimento; não afirmar que todo texto arbitrário foi anonimizado. |
| Job e confirmação de revogação | customerAccountClosures e customerProviderRevocations; UID, estados, hashes, requestId/timestamps. | Evidência mínima permanece privada; cliente só lê seu status de exclusão. | Prevenir reexecução/recriação e auditar conclusão. Retenção/TTL/backups ainda sem política definitiva. Não guarda token Apple. |
| Tokens/sessão | SDKs Firebase/Google/Apple, Auth Web LOCAL; Firestore persistente no aparelho. | signOut e purge no caminho de completed observado; worker exclui Auth. | Logout, exclusão e revogação externos são distintos. Demais aparelhos, armazenamento de SDK/SO, backups e exclusão sem callback precisam ensaio real. |
| Logs/diagnóstico/dispositivo | Logs do app/Firebase e prestadores; contexto técnico de autenticação/rede pode existir nos SDKs/serviços. | Logs auth/bootstrap agora omitem UID/caminho pessoal. | Não foi auditada telemetria remota/retencão de nuvem/console; não declarar ausência de coleta de IP/dispositivo por terceiros. |
| Tickets/comprovantes/cópias de operação | Impressão para separação/entrega pode reproduzir nome, contato e destino. | Worker não recolhe papel nem apaga cópias externas. | Inventário, acesso, descarte e prazo físico precisam procedimento e revisão; não presumir que exclusão Firebase elimina essas cópias. |

Valores e referências enviados ao PSP no contrato PIX existente não foram
alterados; há payloads de teste no código legado. A matriz não homologa esses
dados para produção. Firebase/Google, mapas/geocoding/rotas, PSP e eventuais
prestadores exigem revisão de dados, termos e retenção próprios. Nenhuma
coleta/compartilhamento oficial do Play foi declarada apenas por inferência.

## DOB, documentos e suporte

Mantidos calendário estrito, rejeição de futuro, aceites explícitos,
política/hash/versões correntes e restrições por país/produto. Não foi alterada
idade mínima, lista de produtos ou política Brasil/Paraguai. O campo
`dateOfBirthVerified: false` continua explícito.

Termos e privacidade são acessíveis no onboarding/perfil, com texto e versão
no leitor interno. URL de fonte é apresentada como texto selecionável. Há
exemplo local DRAFT com URLs nulas; produção exige política publicada e válida.
Exceção de desenvolvimento DRAFT não foi ampliada. Não há URL pública definitiva,
canal de suporte configurado ou página web de exclusão comprovados. Nenhum
endereço/email/telefone foi inventado. Leitura antes do login permanece pendente.

## Checklist iOS / Apple Review

| Item | Estado / evidência |
| --- | --- |
| Login Apple no app e link com UID | VALIDADO LOCALMENTE com SDK doubles; **PENDENTE APPLE REAL**. |
| Capability, team/bundle/service IDs, segredo e domínios | EXTERNO / não comprovado; configuração nativa ausente nos pontos inventariados. |
| Nonce/state e retorno OAuth/cancelamento real | Delegados ao SDK; erros simulados cobertos. **PENDENTE APPLE REAL / TESTFLIGHT**. |
| Exclusão iniciável pelo perfil | VALIDADO LOCALMENTE, consentimento/reautenticação/status e retry. |
| Revogação Apple | Contrato e bloqueio locais; **PENDENTE ADAPTADOR/CREDENCIAL REAL**. Não anunciar completo. |
| Pós-exclusão e cache | Caminho observado testado com fake; dispositivos, app fechado, múltiplas abas e backups pendentes. |
| Privacidade/termos/suporte públicos | EXTERNO: textos/URLs aprovados e canal de suporte ainda pendentes. |
| Dados preservados/prazos | EXTERNO: revisão jurídica e de retenção; pseudonimização é descrita corretamente. |
| Declarações App Privacy / screenshots / dados do desenvolvedor | EXTERNO, não preenchidos. |
| Conta/recurso de review e instruções de uso | EXTERNO: definir sem credencial pessoal ou bypass; não foi criado login fictício de produção. |
| Build assinado, TestFlight, revisão App Store Connect | EXTERNO, não executado. |

A existência do botão de exclusão e testes simulados não fecha o review.
O processamento continua assíncrono; o texto não promete exclusão instantânea.

## Checklist Google Play / Data Safety

| Item | Estado / evidência |
| --- | --- |
| Google normal, link, conflito, cancelamento e logout | VALIDADO LOCALMENTE; **PENDENTE GOOGLE REAL** em Android/iOS/Web. |
| Exclusão interna própria e bloqueio de terceiros | VALIDADO LOCALMENTE, incluindo token antigo e retry. |
| Recurso web para solicitar exclusão sem reinstalar | EXTERNO, não localizado/publicado. |
| Política pública e dados de contato | EXTERNO, URLs oficiais e suporte pendentes. |
| Data Safety: coleta/finalidade/compartilhamento/retencão | Matriz técnica acima preparada; respostas oficiais pendentes de evidências e revisão. |
| Dados de SDKs/prestadores e medidas de segurança | Conferir contratos/configuração real, sem inferir “não coleta” de ausência de código explícito. |
| Formulários/URL no Play Console e revisão da loja | EXTERNO, não executados. |

O recurso web e as declarações de exclusão fazem parte das orientações do
[Google Play](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en).
A matriz não substitui o formulário nem comprova sua aprovação.

## Testes e preservação

Arquivos de auth/bootstrap alterados foram conferidos: logs mantêm somente
provedor/operação/coleção e código de erro. Não registram UID, caminho com UID,
senha, authorization code, access/refresh/ID token, client secret ou chave
privada. O resultado `UserCredential` e erros completos de provedores não são
impressos. Recibo Apple mantém hashes e estados; erros externos não são gravados
como texto livre. Logs operacionais de pedidos/estoque fora desse fluxo foram
preservados; SDKs nativos, consoles e retenção remota exigem auditoria própria.

| Execução final | Resultado / evidência |
| --- | --- |
| Functions completo `npm test` | **414/414 aprovados**, incluindo 3 testes originais de conta e 8 de revogação. `tool/kb06/functions-final.log`. |
| Firestore/Auth Emulator completo | **403/403 aprovados**, incluindo 8 de conta já existentes e 12 KB-06. `tool/kb06/emulator-final.log`. |
| Flutter afetados | **74/74 aprovados**, incluindo 35 novos de privacidade. `tool/kb06/flutter-affected-final.log`. |
| Flutter analyze | **No issues found**. `tool/kb06/flutter-analyze.log`. |
| Flutter completo (execução adicional) | **207/209 aprovados, 2 falhas** em fixtures de checkout fora do KB-06; não declarar suíte completa aprovada. `tool/kb06/flutter-all.log`. |
| ESLint do escopo | Aprovado. `tool/kb06/lint-scoped.log`. |
| Preservação | 19 arquivos com SHA-256 inalterado: index/Rules, PIX/checkout, frete/tabela, horário/país, estoque/compensação/contingência, onboarding, pedidos/workspace, confirmação e dependências/locks. `tool/kb06/protected-before.json` / `protected-after.json`. |
| Checklist | 196 IDs mantidos nos dois documentos; resultados de campo em branco e gates preservados. `tool/kb06/checklist-consistency.json`. |

Os dois testes adicionais que falharam:

- `checkout_delivery_contract_test.dart`: “checkout refuses an unconfirmed
  destination before any order write” tenta finalizar enquanto o botão está
  desabilitado pelo fechamento da loja; espera uma mensagem de validação que
  não é executada nesse estado.
- `client_readiness_test.dart`: “país desconhecido usa confirmação excepcional”
  toca um controle fora da área visível com o aviso de fechamento presente.

Essas fixtures usam horário corrente/layout sem preparar tais condições.
Checkout e os dois arquivos de teste não foram alterados para obter resultado
verde nesta tarefa. Corrigir preparação/relógio/visibilidade em escopo próprio;
preservar as asserções comerciais e não contornar a regra de horário.

Na regressão inicial houve também falha do construtor Firestore antecipado,
corrigida pela inicialização tardia. No emulador ampliado, o teste antigo de
`auth_time` futuro usava horário calculado antes de múltiplas chamadas e podia
atravessar sua margem de 1 segundo; foi fixado o mesmo `now` da asserção via
injeção já existente. A janela real do backend não mudou. Ajustes de formatação
no mesmo arquivo de teste eliminaram dois lints antigos, sem reescrever o worker.

Mocks de provedores e dados são explicitamente de teste. O emulador usa projeto
`demo-chamae-rules`, Firestore 127.0.0.1:8187 e Auth 127.0.0.1:9099, com guards
que impedem fallback para produção. Transações, Rules e Auth locais reais;
providerData Apple e revogação externa são simulados. Há testes para UID/link,
cancelamento, conflito, refresh, troca explícita/silenciosa, logout, exclusão
Google, Apple bloqueada/simulada, anônimo negado, admin/terceiro negados,
Auth já removido, token antigo, limpeza/erro/retry, recibo privado,
resposta atrasada e worker concorrente.

Comandos (Flutter executado pelo entrypoint local dart.exe/flutter_tools.snapshot,
com --no-version-check --suppress-analytics e --no-pub):

```text
# functions/
npm test
npm run test:privacy
firebase emulators:exec --project demo-chamae-rules --only firestore,auth --config ../firebase.account-test.json "node --test --test-concurrency=1 test/customer-privacy.emulator.spec.js test/delivery-contingency.emulator.spec.js test/order-cancellation.emulator.spec.js test/order-acceptance.emulator.spec.js test/firestore.rules.spec.js test/pilot.emulator.spec.js test/final-operations.emulator.spec.js test/delivery-radius.emulator.spec.js test/courier-assignment.emulator.spec.js test/courier-deliveries.emulator.spec.js test/order-chat.emulator.spec.js test/customer-account.emulator.spec.js"
# raiz
flutter analyze --no-pub
flutter test --no-pub test/customer_auth_test.dart test/google_login_test.dart test/customer_account_cycle_test.dart test/customer_flow_test.dart test/customer_privacy_test.dart test/order_acceptance_test.dart
flutter test --no-pub
```

## Retomada do estado salvo em 25/10/2026

Conferidos `git status`, `git diff` e o conteúdo dos arquivos existentes antes
de continuar. Nenhum arquivo de implementação foi recriado ou revertido.
Os 16 arquivos de código/configuração/testes do KB-06 foram registrados por
hash em `tool/kb06/retomada-2026-10-25/code-before.json`; os 19 arquivos protegidos
continuam iguais ao inventário anterior. Nesta retomada, as alterações se
limitam à documentação e às novas evidências de validação.

| Revalidação desta retomada | Resultado | Evidência em `tool/kb06/retomada-2026-10-25/` |
| --- | --- | --- |
| Functions completo | **414/414 aprovados** | `functions.log` |
| Emulador de conta/revogação | **20/20 aprovados**, 8 originais de conta + 12 KB-06 | `emulator.log` |
| Flutter afetados | **74/74 aprovados** | `flutter-affected.log` |
| Flutter completo | **207/209 aprovados; mesmas duas falhas de checkout já documentadas** | `flutter-all.log` |
| Flutter analyze | **No issues found** | `flutter-analyze.log` |
| ESLint dos arquivos do escopo | Aprovado | `lint.log` |

A regressão anterior completa de emulador (**403/403**) permanece registrada
separadamente; a rodada atual de 20 casos é sua parte de conta/revogação,
não uma repetição dos 403. Os logs anteriores não foram substituídos.
O Flutter completo foi reexecutado: as falhas continuam em destino não
confirmado com checkout fechado e confirmação de país fora da área visível.
Não houve alteração desses testes ou do checkout para eliminar as falhas.
Os 16 hashes da implementação coincidem antes/depois da retomada, conforme
`code-after.json`; os 196 IDs e os gates também foram reconferidos.

### Rastreabilidade da seção 15

Todos os itens abaixo correspondem a testes locais existentes, executados
novamente nesta retomada. “Validado localmente” não significa autenticação,
revogação ou homologação com provedores reais.

| Requisito | Evidência local | Limite |
| --- | --- | --- |
| anonymous → Google link | `test/customer_auth_test.dart`: mantém UID, um link e zero sign-ins novos | SDK double |
| anonymous → Apple link | Mesmo teste parametrizado para Apple | SDK double |
| Google normal | `customer_auth_test.dart`: sign-in e refresh | SDK double; Google real pendente |
| Apple normal | Mesmo teste parametrizado para Apple | SDK double; Apple real pendente |
| Cancelamento Google | `customer_auth_test.dart`: cancelamento nativo mantém UID anônimo | Exceção Google simulada |
| Cancelamento Apple | `test/customer_privacy_test.dart`: cancelamento de link/reautenticação sem troca de identidade | Exceções simuladas |
| Conflito de credencial | `customer_auth_test.dart`, `customer_privacy_test.dart` e `google_login_test.dart` | Sem mesclagem automática |
| Sessão expirada | `customer_privacy_test.dart`: tokens expirados/inválidos, usuário removido/desabilitado | FirebaseAuth fake |
| Troca explícita | `google_login_test.dart` e `customer_privacy_test.dart` | Escolha explícita antes de entrar em outro UID |
| Logout | `customer_privacy_test.dart` e `customer_flow_test.dart` | Limpa campos/rotas; não equivale a revogação |
| Exclusão Google | `functions/test/customer-privacy.emulator.spec.js` | Worker e Auth locais; preservação financeira |
| Exclusão Apple | Mesmo arquivo: bloqueio sem prova e conclusão com confirmação simulada | Adaptador Apple real ausente; caminho padrão bloqueia |
| Exclusão anônima quando aplicável | `customer_privacy_test.dart`, `customer-account.spec.js` e emulador | Recusa validada: app atual não cria contas anônimas nem oferece exclusão verificada para elas |
| Retry | Unitários/emulador de conta e revogação; `customer_privacy_test.dart` | Mesma solicitação/recibo; falha de limpeza explícita |
| Revogação Apple simulada | `customer-provider-revocation.spec.js` e `customer-privacy.emulator.spec.js` | Somente adaptador interno de teste |
| Falha de revogação | Mesmos arquivos: falha, sujeito divergente e ausência de configuração | Não apaga PII/Auth antes da confirmação |
| Limpeza local | `customer_privacy_test.dart`: logout, purge, falha/retry e reinício | Cache SDK fake; caminho sem callback permanece pendente |
| Terceiro tentando excluir | Unitário de conta e emulador de privacidade | UID alheio e recibo forjado rejeitados |
| Administrador no fluxo de cliente | `customer-privacy.emulator.spec.js`: roles negadas no aceite/exclusão | Promoção posterior também coberta pelo emulador original |
| Conta já apagada | `customer-account.emulator.spec.js` e `customer-privacy.emulator.spec.js` | Auth ausente e reexecução idempotente |
| Token antigo após exclusão | `customer-privacy.emulator.spec.js` | Contexto autenticado anterior não recria PII nem lê pedidos protegidos |

## Arquivos da implementação KB-06 preservada

- `functions/customer-account.js`: requisito Apple e proteção da geração da solicitação; etapas de limpeza existentes preservadas.
- `functions/customer-provider-revocation.js`: contrato/gate/recibo privado, sem adaptador real.
- `functions/test/customer-provider-revocation.spec.js`, `functions/test/customer-privacy.emulator.spec.js`: novos testes.
- `functions/test/customer-account.emulator.spec.js`: relógio determinístico e formatação de fixture existente.
- `functions/.eslintrc.js`, `functions/package.json`: escopo de lint e scripts/testes; nenhuma dependência atualizada.
- `lib/core/models.dart`: limpeza dos campos pessoais globais.
- `lib/data/customer_auth.dart`: vínculo/UID, refresh/logout e logs minimizados.
- `lib/data/customer_bootstrap.dart`: logs sem UID/caminho pessoal.
- `lib/data/customer_account.dart`: injeção tardia de Firestore, status Apple e purge pós-conclusão.
- `lib/data/customer_local_privacy.dart`: coordenação/retry da limpeza e reinício obrigatório.
- `lib/screens/customer_session_gate.dart`: descarte de referências pessoais e bloqueio durante/pós-purge.
- `lib/screens/customer_account_closure_screen.dart`: pendência Apple e retry explícito, sem falsa conclusão.
- `test/customer_auth_test.dart`: resultado do SDK double inclui usuário, para validar UID real do retorno.
- `test/customer_privacy_test.dart`: 35 testes novos de autenticação/privacidade/limpeza.
- Este relatório e as duas checklists oficiais de homologação. Artefatos em `tool/kb06`.

## Pendências para revisão humana

1. Implementar/configurar adaptador Apple real e obtenção segura de credencial
   autorizada ligada ao sujeito; não aceitar prova do cliente. Homologar revogação,
   falhas/retry, reautenticação, nonce/state, múltiplos provedores e UID real.
2. Configuração OAuth/capability nativa, domínios, SHA/IDs e builds reais Google/Apple.
   Confirmar login/link/logout em aparelhos e Web, App Store Connect/TestFlight/Play.
3. Publicar documentos/URLs aprovados, suporte e recurso web de exclusão. Revisar
   retenção, bases legais, prestadores, backups, logs e auditorias livres com possível PII.
4. Fechar cache no caminho sem callback de conclusão/app encerrado e validar purge
   real/falhas/múltiplas abas/outros aparelhos; não prometer apagamento forense.
5. Resolver as duas fixtures da suíte Flutter completa em seu escopo; os testes
   afetados de KB-06 e analyze estão aprovados, mas o completo permanece 207/209.
6. Preencher formulários oficiais somente após evidência e revisão. Preservar
   os 196 IDs e todos os gates sem liberação automática por testes locais.

Firebase produção, Mercado Pago produção, Oracle/GrandChef: **não acessados**.
Apple/Google reais e consoles das lojas: **não acessados**; somente documentação
pública consultada. Commit, push e deploy: **não realizados**. Parar para revisão humana.
