# Autenticação e primeiro acesso do cliente

Esta etapa muda o fluxo para Google/Apple antes do catálogo. Nenhum provedor foi habilitado e nenhum documento foi publicado por esta implementação.

## Identidade e UID

Web usa Firebase Auth popup. Google nativo usa `google_sign_in` 7 e credencial Firebase; Apple usa o provider oficial do Firebase. Identidade já presente na sessão é vinculada por link, preservando UID. Uma credencial pertencente a outro UID exige escolha explícita no login; não há migração silenciosa de pedidos ou mesclagem entre contas. Vinculação pelo perfil não troca de conta.

As Rules/Functions reconhecem `firebase.sign_in_provider` Google/Apple no ID token validado pelo Firebase. A compatibilidade com a claim confiável `customerVerified` não anônima permanece. Dados gravados no workspace não concedem autenticação ou idade verificada. Google/Apple não comprovam a data de nascimento digitada.

Configuração pendente: habilitar Google e Apple no Firebase Authentication; conferir domínios autorizados Web; Android SHA-1/SHA-256 e novo google-services.json com OAuth; iOS cliente Google/reversed URL scheme e Sign in with Apple capability, bundle/team/service IDs e configuração Apple no Firebase. As chaves privadas Apple ficam no ambiente Firebase/servidor. IDs OAuth públicos podem ser fornecidos por `GOOGLE_IOS_CLIENT_ID` e `GOOGLE_SERVER_CLIENT_ID` via dart-define. Não há chave secreta no app. O google-services.json auditado tinha listas OAuth vazias.

## Documentos oficiais

Configuração futura: `customerPolicies/current`, somente escrita administrativa via ambiente controlado. O cliente lê um snapshot de texto e abre a visualização interna; URLs oficiais ficam como fonte. Isso evita aceitar conteúdo de uma URL que muda silenciosamente sem mudar a versão. Ao publicar novos documentos, carregar o snapshot aprovado das URLs oficiais e atualizar versões/revisão/hash. Não é necessário refazer a UX.

Campos: published, draft, revision, termsVersion, privacyVersion, alcoholVersion, termsText, privacyText, alcoholNotice, termsUrl, privacyUrl, minimumAgeByCountry, contentHash. Textos não vazios e URLs HTTPS oficiais são obrigatórios. Hash SHA-256 calculado por `policyFingerprint(policy)` do módulo customer-onboarding.js; a validação do servidor confere o conteúdo do snapshot.

O exemplo de desenvolvimento está em `docs/config/customer_documents.draft.json`. Não contém URL inventada, texto jurídico ou idade mínima presumida. `published:false`, `draft:true` e versões DRAFT não liberam onboarding nem compra em produção. Não publicar o arquivo de exemplo como política ativa.

O aceite chama `chamaeAceitarDocumentosCliente` com DOB ISO YYYY-MM-DD, versões/revisão/hash e três flags explícitas: acceptTerms, acknowledgePrivacy e acknowledgeAlcohol. O servidor confere a versão atual, impede mudança comum de DOB já registrada, grava perfil e evento de auditoria atomicamente. DOB permanece `dateOfBirthVerified:false`. Repetição do mesmo aceite é idempotente; versão nova exige aceite novo. Correção de DOB requer processo operacional de atendimento a ser definido, não troca livre para contornar restrições.

`customerProfiles/{uid}` é privado e somente o backend escreve. `customerConsentEvents/{uid}/events/{hash}` mantém versões, DOB declarada e acceptedAt de servidor, sem exposição direta aos clientes/motoboys. Perfis antigos e histórico não são migrados automaticamente.

## Elegibilidade e pagamentos

Pedidos novos usam `customerFlowVersion:2`. As Rules exigem identidade válida, destino confirmado e consentimento corrente. O backend repete as verificações antes de criar o financeiro: versão vigente, DOB válida e elegibilidade de produtos conforme destino. Produtos marcados requiresAgeCheck/isAlcoholic e categorias alcoólicas existentes entram na política. Os limiares BR/PY devem ser aprovados e configurados; ausência de política impede compra de produto restrito. Nenhuma idade legal foi presumida nesta etapa. Classificação oficial de produtos e conferência operacional no recebimento devem ser homologadas.

`ageEligibilitySnapshot` congela revisão, país, DOB não verificada e necessidade de documento no recebimento. Não contém DOB nem comprovação de documento. Fluxo de verificação de documento do entregador continua pendente; não confundir com PIN ou login.

Pedidos legados sem customerFlowVersion:2 continuam no contrato financeiro original. Financeiro já congelado não é recalculado, inclusive se a política mudar. PIX, estoque, pagamentos e remuneração não foram reescritos.

## Google Routes

`GoogleRoutesProvider` prepara computeRoutes no servidor, com máscara de distância/duração e rejeição de fallback. Chave e travelMode são parâmetros privados de servidor. Nenhuma chave real, modalidade de veículo, origem ou faixa foi escolhida. O adapter ainda não foi instalado na callable ativa. Liberar somente após configuração e homologação BR/PY, preços/piso aprovados e separação da remuneração do entregador. Modo por faixas continua inativo.

## Referências técnicas usadas

- [Firebase: autenticação federada Flutter](https://firebase.google.com/docs/auth/flutter/federated-auth)
- [Firebase: vinculação de provedores mantendo UID](https://firebase.google.com/docs/auth/flutter/account-linking)
- [Flutter: Google Sign-In](https://pub.dev/packages/google_sign_in)
- [Google Routes: computeRoutes](https://developers.google.com/maps/documentation/routes/reference/rest/v2/TopLevel/computeRoutes)

## Publicação

Substituir Termos e Política DRAFT pelos documentos oficiais e URLs públicas. Configurar provedores, testar login real/link/revogação, publicar políticas aprovadas e homologar aceite/compra. Coordenar cliente, Rules e Functions compatíveis; não publicar Rules isoladas esperando compra pelo fluxo anônimo anterior. PIN requer segredo já previsto e conta recente para reset. Sem deploy nesta tarefa.
