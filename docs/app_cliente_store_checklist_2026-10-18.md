# Chamaê Delivery — checklist externo de publicação

Data da auditoria: 18/10/2026. Este documento não representa aprovação das lojas. Nenhum envio, cadastro, deploy ou mudança de política comercial foi executado.

## Privacidade e dados

- [ ] Fornecer política de privacidade pública, acessível no aplicativo e nas fichas das lojas, com responsável e contato reais.
- [ ] Inventariar Firebase Auth anônimo, Firestore, Functions, Google Maps/geocoding e Mercado Pago: nome, WhatsApp, endereço, coordenadas, identificador de sessão e dados de pagamento efetivamente tratados.
- [ ] Confirmar finalidade, compartilhamento, retenção e procedimento de solicitação/exclusão de dados. O resumo do Perfil não substitui uma política aprovada.
- [ ] Preencher Data safety no Play Console e App Privacy no App Store Connect de acordo com o comportamento real dos SDKs.
- [ ] Avaliar a aplicabilidade das exigências de exclusão de conta à sessão anônima e ao cadastro que será efetivamente oferecido. Se aplicáveis, implementar um fluxo real e a página externa exigida pelo Google; não substituir por botão sem efeito.
- [ ] Revisar manifests de privacidade/required-reason APIs dos SDKs no archive iOS final.

Fontes: [Google — User data](https://support.google.com/googleplay/android-developer/answer/10144311?hl=en), [Google — account deletion](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en), [Apple — account deletion](https://developer.apple.com/support/offering-account-deletion-in-your-app/), [Apple — App Privacy](https://developer.apple.com/app-store/app-privacy-details/).

## Conteúdo comercial

- [ ] Confirmar o bloqueio comercial também nos dados e contratos efetivamente publicados; o cliente filtra tabacaria, cigarros, pods, vapes e demais termos da política existente.
- [ ] Revisar catálogo, imagens, vídeo Pit Stop V8, promoções e metadados para evitar conteúdo dirigido a menores ou incentivo ao consumo inadequado de álcool.
- [ ] Definir com o responsável pela operação os controles de idade/entrega necessários em cada território. Nenhuma regra legal, idade ou coleta adicional foi inventada nesta etapa.
- [ ] Preencher público-alvo e classificação indicativa reais nas duas lojas.

Fontes: [Google — Tobacco and Alcohol](https://support.google.com/googleplay/android-developer/answer/9878810?hl=en), [Apple — App Review Guidelines, 1.4.3](https://developer.apple.com/app-store/review/guidelines/).

## Android / Google Play

- [ ] Instalar/configurar Android SDK, ferramentas e JDK compatíveis. O ambiente auditado não possui Android SDK.
- [ ] ApplicationId oficial normalizado localmente: `br.com.loumak.chamae`. Registrar o novo app Firebase, substituir configurações incompatíveis e conferir restrições de chaves.
- [ ] Configurar chave Google Maps para Android via propriedade Gradle ou variável `CHAMAE_MAPS_API_KEY`, com APIs habilitadas e restrições corretas para pacote e certificados.
- [ ] Validar localização aproximada, precisa, negada e negada permanentemente em aparelho. O app pede apenas localização em primeiro plano.
- [ ] Criar assinatura de distribuição e configurar Play App Signing. O projeto ainda usa chave debug na configuração release.
- [ ] Verificar o target API exigido na data de submissão contra o SDK realmente utilizado; `targetSdk` permanece delegado ao Flutter.
- [ ] Gerar/validar AAB assinado, versionCode, ícone, screenshots, descrição, suporte, países de distribuição e declarações de conteúdo.
- [ ] Executar testes internos/fechados e cumprir os critérios aplicáveis à conta no Play Console antes de solicitar produção.

Fonte: [Google — target API](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en). Prazos e critérios devem ser reconferidos no Console na submissão; não foram presumidos.

## iOS / App Store / TestFlight

- [ ] Usar macOS e Xcode compatíveis com as exigências vigentes do App Store Connect. Nenhum build iOS foi executado no Windows.
- [ ] Bundle ID oficial normalizado localmente: `br.com.loumak.chamae`. Registrar novo app Firebase e configurar equipe/certificados/provisionamento. Deployment target 15.0 no projeto Xcode.
- [ ] Configurar `CHAMAE_MAPS_API_KEY` no build setting/xcconfig usado pelo Xcode. O Info.plist fornece `GMSApiKey` ao AppDelegate; nenhuma chave nativa foi inventada.
- [ ] Resolver as dependências nativas efetivas no Xcode e confirmar Google Maps, Firebase e o registro dos plugins.
- [ ] Validar em simulador e iPhone: permissões, mapa, teclado, notch, SafeArea, retorno do app e acessibilidade.
- [ ] Conferir usage description de localização, privacy manifests, assinaturas de SDKs e metadados do archive.
- [ ] Preparar screenshots reais, descrição, suporte, política, classificação e instruções para a revisão.
- [ ] Gerar archive assinado, validar e enviar ao TestFlight somente após autorização específica para publicação/envio.

Fonte: [Apple — App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/). A estrutura local e os testes Flutter não substituem archive, validação nativa e revisão.

## Homologação operacional

- [ ] Resolver a divergência do frete: backend atual fixa R$ 10; o pedido desta etapa descreve frete por distância.
- [ ] Confirmar a área real atendida, a cotação/rota autoritativa e o tratamento de endereço fora da operação.
- [ ] Confirmar onde serão impostas autoritativamente as regras BR/PY e de horário; o cliente já aplica essas restrições na interface.
- [ ] Validar pagamentos, confirmação PIX/webhook, reserva/liberação de estoque, concorrência e retry em ambiente controlado. Não usar pedidos reais para substituir testes.
- [ ] Homologar recuperação após encerramento completo do processo e persistência do carrinho/tentativa pendente.
- [ ] Aprovar visualmente a composição da splash com o logo existente e assinatura Loumak, além dos ícones/splash nativos das lojas.

## Publicação

- [ ] Revisar alterações locais preexistentes de Functions e Firestore em trabalho próprio; não pertencem à implementação visual desta etapa.
- [ ] Obter autorização para qualquer implantação ou submissão futura.

Não houve deploy, commit, push ou envio às lojas.
