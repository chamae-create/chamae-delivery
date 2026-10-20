# Pós-login Google e Firestore — 19/10/2026

## Evidências e limites

O relato Android mostra autenticação chegando ao bootstrap e bloqueios em `customerProfiles/{customerUid}`, `customerPolicies/current` e `customerWorkspaces/{customerUid}`. Não foi disponibilizado um UID literal do incidente. O logcat retido não reproduziu os erros originais. A sessão persistida usa preferências criptografadas; não foi possível confirmar o UID real por esse meio. Nenhuma credencial foi impressa ou copiada.

As regras locais anteriores a esta correção já autorizavam a leitura do perfil próprio para conta não anônima e não motoboy; workspace próprio para conta autenticada não motoboy; e leitura pública de TODOS os documentos de customerPolicies. Logo, negar até `customerPolicies/current` não é explicado por aquelas regras locais. Divergência das regras publicadas ou outra camada de controle permanece hipótese, não causa comprovada. Não foi feita consulta autenticada às regras publicadas nem alteração em produção.

## Sequência auditada

1. `FirebaseCustomerAuth.signIn`: sessão existente usa `linkWithCredential` no Google nativo; sem sessão usa `signInWithCredential`. O caminho web usa popup. Conflito exige escolha explícita para entrar em conta existente; nenhum merge é executado. Linking valida que o UID não mudou. O método termina após reload e renovação forçada do token.
2. `CustomerSessionGate` acompanha `idTokenChanges`, ignora sessões anônimas e cria os repositórios capturando `FirebaseAuth.instance.currentUser.uid`. `_load` renova a sessão e inicia onboarding e workspace.
3. Antes desta correção, onboarding lia política e perfil em paralelo; workspace fazia GET próprio. Não havia escrita imediata. Ausência já era convertida em mapa vazio, mas qualquer exceção era exibida como conexão.
4. Agora onboarding lê `customerPolicies/current`, depois lê/cria o perfil próprio por transação. Workspace lê/cria o documento próprio por transação, em paralelo com onboarding. Perfil inicial contém somente `createdAt: serverTimestamp`; workspace inicial contém `addresses: []` e `cart: []`. Transação evita sobrescrever documentos criados concorrentemente. Sessão é conferida antes/depois e antes de programar criação. Não há fallback que transforme permission-denied em ausência.
5. Aceites continuam na callable `chamaeAceitarDocumentosCliente`, região `southamerica-east1`: backend lê política, perfil e cadastro de motoboy, valida e escreve perfil e evento de consentimento. Cliente não escreve aceites.

## Diff lógico desta intervenção

- `customerPolicies`: leitura pública ampla substituída por GET autenticado apenas do ID `current`; LIST e toda escrita negados. Permite detectar documento ausente. O app continua bloqueando aceite quando a política é ausente, draft ou indisponível. O documento current deve conter somente configuração destinada ao onboarding; outros IDs não ficam expostos.
- `customerProfiles`: GET somente do proprietário autenticado não anônimo e não motoboy; CREATE apenas `createdAt` igual ao tempo do servidor. UPDATE, DELETE e LIST negados. Não há criação de nascimento, consentimento, roles ou verificação pelo cliente.
- `customerWorkspaces`: GET próprio preservado, CREATE/UPDATE próprios e contrato de campos preservados; LIST explicitamente negado. Anônimo mantém acesso ao workspace próprio anterior ao linking; perfil continua exigindo conta não anônima.
- `orderFinancials`, segredos, auditoria de consentimento e demais coleções privadas mantêm bloqueio. Não foi criado wildcard permissivo.
- Backend de aceite aceita perfil inicial sem nascimento e gera `firstAcceptedAt` quando ausente. Após nascimento cadastrado, mudança continua negada. Essa adaptação é necessária junto da inicialização do perfil; não publicar o novo app isoladamente contra um backend antigo sem verificar compatibilidade.
- Logs debug `[customer-auth]` registram UID anterior/ativo, linking, anonimato e preservação; `[customer-bootstrap]` registra UID ativo, UID esperado, operação, path e código de falha. Não incluem tokens nem conteúdo dos documentos. A mensagem de permission-denied agora indica falha de acesso após login.

## UID e retomada da homologação

Preservação é verificada pelo código e pelos testes de linking, mas o resultado do incidente Android é **não confirmado**. Não confundir fixtures dos testes com o UID real. Em próxima execução debug, comparar `previousUid`, `activeUid`, `authUid` e os sufixos dos paths nos novos logs. A chegada ao gate comprova uma sessão não anônima; o evento `complete` confirma também o término do refresh do adapter. Mudança explícita de conta mantém dados no UID anterior; nenhum registro é copiado, apagado ou reatribuído.

Se a produção continuar negando GET de current, comparar manualmente o ruleset publicado com `firestore.rules`, incluindo o banco alvo. Perfil e workspace também podem ser negados por UID diferente, token ainda anônimo (perfil), ou cadastro de motoboy. Não é possível atribuir um desses motivos ao incidente sem o contexto real da requisição.

## Operação e referências

Resultados concluídos:

- Firestore Emulator: **222/222 testes aprovados**, zero falhas, processo terminou com código 0. Log: `tool/post_login_rules_retry.log`.
- Flutter: **28/28 testes aprovados** (auth/linking/conflito/troca explícita, Google login, fluxo/onboarding, erro de permissão e carrinho). Log: `tool/post_login_flutter_retry.log`.
- Backend onboarding: **9/9 testes aprovados**, incluindo primeiro aceite sobre perfil mínimo e bloqueio posterior de alteração do nascimento. Log: `tool/post_login_backend.log`.
- Análise estática Flutter: **6 arquivos, nenhum problema**, código 0. Log: `tool/post_login_analyze_final.log`. `git diff --check` dos arquivos rastreados de Rules/testes passou.
- As Rules cobrem GET próprio, negação de perfil/workspace alheio, CREATE mínimo, campos de consentimento/roles não forjáveis, política current somente leitura, negação de LIST, anônimo antes do linking/Google com mesmo UID e bloqueio financeiro/segredos/motoboy.
- Tentativas anteriores falharam por porta ocupada, configuração isolada fora da raiz, erro de escrita do processo de teste e falta de memória/threads do host. A repetição das Rules usou portas isoladas e heap limitado; Flutter passou com concorrência 1 após encerramento de um daemon Gradle comprovadamente ocioso. Não foram encerrados app nem emulador Android. Não confundir os logs iniciais com o resultado final aprovado.

Nenhum deploy, commit ou push. OAuth e identificadores Firebase não foram alterados nesta intervenção. O workspace já tinha alterações extensas anteriores; o diff total contra Git inclui trabalho preexistente.

`firebase.post_login.json` é configuração isolada de teste, sem identificadores de produção alterados. Com Java disponível, executar:

```powershell
$env:JAVA_HOME='C:/Program Files/Android/Android Studio/jbr'
$env:PATH="$env:JAVA_HOME/bin;$env:PATH"
$env:JAVA_TOOL_OPTIONS='-Xmx384m -XX:ActiveProcessorCount=2'
firebase.cmd emulators:exec --config firebase.post_login.json --only firestore --project demo-chamae-rules "npm --prefix functions run test:rules"
flutter.bat test --concurrency=1 test/customer_auth_test.dart test/google_login_test.dart test/customer_flow_test.dart test/workspace_cart_test.dart
node --test functions/test/customer-onboarding.spec.js
```

O linking preserva acesso aos mesmos dados conforme a [documentação Firebase de account linking](https://firebase.google.com/docs/auth/flutter/account-linking). Autorização usa o UID do token conforme as [condições de Security Rules](https://firebase.google.com/docs/firestore/security/rules-conditions).

Para aplicar em produção será necessária aprovação manual para Rules e para a adaptação da callable de aceite, além de distribuir o app atualizado. Esta auditoria não autoriza nem executa publicação.
