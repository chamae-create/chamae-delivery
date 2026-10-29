# F01 — Exclusão de contas vinculadas à Apple

28/10/2026. Implementação local para auditoria. **Não homologado com Apple real e não liberado para produção.** Não houve stage adicional, commit, push, tag, deploy ou uso de credenciais reais. As 12 remoções staged anteriores devem permanecer intactas.

## Causa e preservação

`createCustomerAccountFunctions` chamava `processClosure` sem `services.revokeApple`. O guard convertia essa ausência em `APPLE_REVOCATION_NOT_CONFIGURED` e bloqueava antes de remover PII/Auth, inclusive para login Google com vínculo Apple. O KB-06 descreve esse comportamento histórico corretamente, mas não contempla o procedimento Apple para contas legadas sem token.

Inventário Git e SHA-256 do índice foram conferidos antes de editar. Fontes, testes, relatórios e alterações da v0.2 anteriores foram preservados fora do escopo F01. Nenhuma operação de stage é executada; a conferência final distingue as entradas do índice de seus metadados/cache. KB-07/signing e integrações financeiras/estoque não são reimplementados.

## Contrato e resultados

| Situação | Resultado de autorização Apple | Exclusão Chamaê |
|---|---|---|
| Credencial vinculada, Apple responde HTTP 200 | `revoked`, evidência `apple_http_200` (revogada ou anteriormente invalidada, segundo contrato oficial) | Prossegue após recibo durável |
| Credencial histórica inexistente | `manual_required`, `LEGACY_CREDENTIAL_MISSING`, sem confirmação de revogação | Prossegue; instrução manual apresentada ao usuário |
| Apple rejeita token com invalid_token/invalid_grant | `manual_required`, `APPLE_CREDENTIAL_UNUSABLE`, sem confirmação de revogação | Prossegue com instrução manual; erro não é prova de revogação |
| Rede, timeout, HTTP 429/5xx ou leitura indisponível do cofre | `retry_pending` | Não anuncia exclusão; evento original com retry pode retomar sem nova solicitação |
| Configuração ausente com credencial existente, cofre adulterado ou sujeito divergente | `review_required`/blocked, razão sanitizada | Exige correção/revisão e retry autorizado; não vira legado por conveniência |
| Identidade Apple ausente quando exigida e sem recibo anterior | Bloqueio seguro | Não inventa sujeito nem autorização |

`completed` descreve a exclusão Chamaê. Não afirma revogação Apple quando `appleRevocationStatus == manual_required`. O Flutter tem estados distintos para conclusão com pendência manual, falha transitória e revisão. Instruções da Conta Apple ficam disponíveis antes da confirmação; o endereço pode ser copiado. Logout/limpeza local também ocorrem na conclusão manual.

## Adaptador oficial e segurança

`functions/apple-revocation-adapter.js` implementa POST form-urlencoded para `https://appleid.apple.com/auth/revoke`, com prazo limite e sem redirects. Somente HTTP 200 confirma o resultado aceito pela Apple. Não há fake nem sucesso sintético no caminho padrão. Dublês de HTTP e respostas sintéticas existem exclusivamente nos testes.

O cofre privado `customerAppleCredentials/{uid}` guarda token cifrado com AES-256-GCM, IV aleatório e AAD ligado a UID, hash do sujeito, client ID e tipo do token. Não contém token plaintext. Leitura com UID/sujeito divergente ou autenticação criptográfica inválida falha. Gravação transacional é recusada durante exclusão solicitada/processando/concluída. Rules negam acesso SDK por padrão, inclusive para roles administrativas de cliente.

`acquireAppleCredential` é um contrato **interno do servidor**, não uma callable pública. Troca authorization code no endpoint oficial `/auth/token`, verifica a assinatura RS256 com as chaves oficiais `/auth/keys`, issuer, audience, expiração, emissão e nonce esperado, e compara o sujeito com `getAuth().getUser(uid).providerData`. Só então guarda o token cifrado. O helper de armazenamento é infraestrutura interna e não deve receber uma alegação `identityVerified` do cliente.

A ligação desse contrato ao callback OAuth autorizado ainda precisa ser implementada/homologada no ambiente real: UID/reautenticação e nonce devem pertencer ao fluxo autenticado do servidor. Não expor o helper diretamente nem aceitar UID, sujeito, nonce ou prova arbitrária como autoridade do cliente. O payload da exclusão continua recusando token, código, flag de revogação e UID estrangeiro.

## Configuração real ainda indisponível

O worker declara dois recursos Secret Manager, sem valores versionados:

- `CHAMAE_APPLE_CLIENT_SECRETS`: JSON servidor-only que associa cada App ID/Services ID autorizado ao client secret JWT legítimo daquele client. Não é um token do usuário.
- `CHAMAE_APPLE_CREDENTIAL_KEY`: chave AES de 32 bytes representada por 64 caracteres hexadecimais, sob custódia do responsável.

Nenhum desses recursos foi criado, lido em produção, preenchido com credencial real ou implantado nesta tarefa. Em uma implantação futura, preparar os recursos antes do deploy do worker. Não mudar a chave de cifragem de um cofre existente sem migração autorizada. App ID/Services ID, Team/Key ID, assinatura/validade do client secret, agrupamento de sujeitos Apple e nonce precisam ser comprovados no ambiente real.

Firebase não mantém automaticamente os tokens Apple históricos necessários ao nosso cofre. Não classificar uma falha de leitura/configuração como ausência de token. O contrato de aquisição não está ligado automaticamente ao `confirmIdentity` do Flutter; não houve mudança nas credenciais nem nos scopes de login existentes.

## Legado, revisão e retenção

Para legado sem token, cumprir a exclusão dos dados elegíveis e orientar o titular a remover Chamaê em Conta Apple → Início de sessão e segurança → Iniciar sessão com a Apple, em `https://account.apple.com`. Não exigir email/telefone de suporte como condição para excluir. A conta Apple externa continua existindo.

O recibo privado registra `manual_required`, motivo, hash do sujeito, fingerprint e geração da solicitação. Não existe booleano enviado pelo cliente que o converta em revogação comprovada. Confirmação manual do usuário não é prova de servidor. A revisão operacional acompanha essa fila separadamente; eventual reconciliação automática requer notificação Apple validada/integração futura. Não editar recibos para fingir revogação e não chamar essa pendência de concluída.

Após um resultado durável e a remoção dos dados locais elegíveis, o worker remove o cofre de credenciais antes de excluir Auth. Recibo/job mínimos permanecem para auditoria e retomada. Valores e referências financeiras/estoque necessárias permanecem; dados pessoais previstos são minimizados. Não se promete anonimização irreversível do hash de UID. Prazos e fundamentos de conservação, textos livres, papel, prestadores e backups continuam sob revisão competente; nenhum prazo jurídico foi inventado pela F01.

O vínculo inclui UID, sujeito e requestedAt com segundos/nanossegundos. Retry da mesma geração reutiliza o recibo; nova solicitação não reaproveita confirmação antiga. O evento possui retry. Após interrupção antes de excluir Auth, retomada pode usar o recibo mesmo que o cofre já tenha sido removido; após Auth ausente, hash do sujeito persistido permite retomar a mesma geração.

Limite preservado do KB-06: purge Flutter é acionado ao observar completed; aparelho/app encerrado sem receber esse callback ainda precisa de homologação e tratamento durável específico. Esta tarefa não afirma apagamento forense nem limpeza de outros dispositivos/backups.

## Validação local

| Verificação em 28/10/2026 | Resultado |
|---|---|
| Functions, suíte unitária completa com rede bloqueada | 519/519 aprovados |
| Firestore/Auth Emulator, projeto demo e loopback | 24/24 aprovados, incluindo interrupção/reinício em processos Node distintos |
| Flutter afetados: privacidade, autenticação e ciclo de conta | 55/55 aprovados |
| Flutter analyze | No issues found |
| Functions ESLint completo | Exit 0 |
| Flutter completo | 209 aprovados, 4 falhas preexistentes, 213 casos no total |
| Comparação anterior à F01, somente arquivos de teste afetados pelas quatro falhas | Mesmas 4 falhas; outros 8 casos desses arquivos passaram |
| Git diff --check, worktree e staged | Exit 0 |

Logs finais: `functions-final.log`, `emulator-final.log`, `flutter-affected-final.log`, `flutter-full.log`, `flutter-baseline-comparison-v2.log`, `flutter-analyze.log`, `functions-lint.log` e `diff-check.log`, em `tool/f01-2026-10-28/`.

A suíte completa não está verde. As quatro falhas são de confirmação de pedidos, nos testes `app_client_final_test.dart` (três casos) e `app_client_final_visual_test.dart` (um caso), com finder não único/Too many elements. Elas se reproduziram em cópia temporária isolada que mantém as mudanças anteriores e usa as versões anteriores à F01 dos arquivos inicialmente limpos de conta/exclusão. Nenhum arquivo do projeto original foi restaurado. Os dois testes e as implementações de confirmação/tracking ficaram intactos; não foram afrouxados nem corrigidos fora do escopo.

O teste `functions/test/f01-process-restart.emulator.spec.js` encerra um processo Node com código 42 após persistir o recibo e antes de excluir Auth, e conclui em outro processo usando o recibo, sem credencial nem nova chamada de revogação. Toda resposta Apple do ensaio é HTTP simulado: comprova a retomada e o contrato local, não revogação real.

O primeiro ensaio do emulador também revelou campo opcional nulo adicionado indevidamente à resposta de retry Google. A implementação foi corrigida para manter o contrato anterior; as asserções originais BR/PY passaram sem alteração. Ambiente do runner final foi limitado a variáveis operacionais necessárias e sem herança de credenciais. Linhas de ambiente herdado dos logs iniciais desta tarefa foram omitidas da evidência.

A primeira rodada de Flutter detectou Scrollable adicional introduzido por SelectableText na instrução Apple. A interface foi corrigida para texto com botão de cópia; testes antigos não foram afrouxados. A primeira inicialização dos testes de emulador falhou no bloqueador de rede local ao receber um objeto URL; o guard foi corrigido preservando a restrição a loopback. Logs iniciais permanecem disponíveis.

Casos cobertos: credencial válida e vínculo, HTTP 200/invalidado anteriormente, token expirado/inutilizável, legado, falha temporária, retry, Google vinculado à Apple, UID estrangeiro, preservação financeira, credenciais sem vazamento, recibo durável/retomada, vault privado, assinatura/nonce/audience inválidos e proibição de recriar credencial durante exclusão.

## Homologação Apple exigida antes de produção

1. Configurar aquisição oficial, nonce/reautenticação, client IDs e Secret Manager em ambiente autorizado; não usar produção para substituir laboratório.
2. Comprovar login Apple e Google vinculado à Apple em dispositivo/build adequados; confrontar UID e sujeito de servidor sem expor tokens.
3. Executar revogação oficial com credencial válida, previamente revogada e inválida; registrar somente status/evidência saneados.
4. Comprovar exclusão Chamaê no legado sem token e instrução de revogação manual, sem bloqueio permanente nem falsa confirmação Apple.
5. Ensaiar falha de rede, interrupção/retomada, exclusão Auth, purge local, dispositivos adicionais e retenções aprovadas.
6. Auditoria humana e demais bloqueadores Gate 3 continuam necessários. Não prosseguir para F02 sem autorização.

## Fontes oficiais consultadas

- Apple Token revocation: https://developer.apple.com/documentation/signinwithapplerestapi/revoke-tokens
- Apple Token validation: https://developer.apple.com/documentation/signinwithapplerestapi/generate-and-validate-tokens
- Apple account deletion: https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion/
- Orientação Apple DTS para ausência de token histórico: https://developer.apple.com/forums/thread/708415
- Firebase/Apple: https://firebase.google.com/docs/auth/ios/apple e https://firebase.google.com/docs/auth/web/apple

## Arquivos F01 e impacto

- Backend: `functions/apple-revocation-adapter.js` (novo), `customer-provider-revocation.js`, `customer-account.js`.
- Flutter: `lib/data/customer_account.dart`, `lib/screens/customer_account_closure_screen.dart`.
- Testes: `functions/test/customer-provider-revocation.spec.js`, `functions/test/customer-privacy.emulator.spec.js`, `functions/test/f01-process-restart.emulator.spec.js` (novo), `test/customer_privacy_test.dart`.
- Integração de lint: `functions/.eslintrc.js`.
- Documentação: este relatório e nota histórica no KB-06. Evidências e runners exclusivamente locais em `tool/f01-2026-10-28/`.

`lib/data/customer_auth.dart`, funções financeiras, rotas, pagamentos, estoque, painel e app Motoboy não foram alterados pela F01. O contrato de reautenticação/UID existente foi reutilizado. Não foram adicionadas dependências nem modificados pubspec/package.json. Não houve assinatura/build de aplicativo novo. F01: **implementado e validado localmente; integração/homologação real pendentes**. Aguardar auditoria, sem iniciar F02.

## Conferência final de preservação

As entradas staged continuam sendo exatamente as 12 remoções anteriores. Conferência por modo/objeto/caminho: 392 entradas em HEAD, 380 no índice, diferença exclusiva dos 12 caminhos autorizados, sem objetos divergentes nem adições. O SHA-256 binário do arquivo interno `.git/index` mudou durante as ferramentas; isso não foi tratado como mudança de stage nem restaurado. A evidência distingue esse hash das entradas efetivamente staged.

Os 12 arquivos gerados continuam no disco com os mesmos hashes. Foram comparados 284 arquivos do inventário anterior fora do escopo F01: nenhum drift. `functions/package.json` e `lib/data/customer_auth.dart` também conservaram os hashes anteriores. Os status completos de Admin/Motoboy coincidem com o snapshot anterior. Não restaram listeners dos emuladores nas portas 8187/9099. Evidências em `preservation.json`, `initial-state.json`, `final-state.json` e `git-status-final.txt` na pasta de validação.
