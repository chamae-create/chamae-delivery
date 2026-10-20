# CHAMAÊ — Frete oficial, painel e Google Routes

Data: 19/10/2026. Projeto Firebase: `chamae-delivery` (`302882774102`).

Implementação local nos projetos `chamae_delivery` e `chamae_admin`. Nenhum deploy, commit, push, alteração de API/secret/billing ou ativação em produção foi executado. A auditoria Google Cloud foi somente leitura; as escritas de teste ocorreram no emulador `demo-chamae-rules`.

## Auditoria e diff lógico

A arquitetura CHAMAE-FRETE-30KM foi reaproveitada: `delivery-pricing.js`, `delivery-service.js`, `GoogleRoutesProvider`, versões imutáveis, cotações privadas e `prepareDelivery` dentro do financeiro transacional. O painel já possuía área protegida por claims, e os pedidos já congelavam `deliverySnapshot`.

Antes, o editor começava vazio e oferecia decisão entre substituir o mínimo e aplicar piso de R$ 8. O adaptador Google existia, mas não era selecionado pela callable; ela recebia o provedor abstrato. A ausência de configuração também podia resultar em legado de R$ 10. A remuneração dos entregadores utiliza `deliveryFee` nos fluxos atuais, razão para manter a ativação bloqueada até homologação específica.

Agora:

- Modelo inicial oficial com 28 faixas, 14.500 m e preços completos em centavos. O arquivo local não é seed automático nem publicação no Firestore.
- Novas gravações são normalizadas para `schemaVersion: 2`; piso adicional é recusado. Publicação valida toda a tabela e exige coordenadas reais da loja.
- Versões persistem versão/status/autor/datas e alcance. Rascunho possui referência independente em `deliveryConfiguration/draft`; a configuração ativa não é modificada pelo salvamento/publicação.
- Callable de cotação ligada ao `GoogleRoutesProvider` server-side e ao secret dedicado. Modo de veículo deve ser escolhido explicitamente na configuração autorizada; não foi presumido um modo para cobrança.
- Configuração ausente bloqueia a cotação e o financeiro do novo fluxo. Legado explícito e pedidos históricos continuam compatíveis. Nenhuma tabela local é usada como fallback de produção.
- Campos explícitos de distância/versão/provedor/data são congelados no financeiro e no espelho do pedido, além do snapshot existente.
- Cotação visível no endereço/carrinho antes do checkout; troca de endereço elimina o resultado anterior e respostas atrasadas não substituem a cotação atual.
- Rules permitem somente leitura de configuração ao superadmin e recusam toda escrita direta de SDK, inclusive do superadmin.

## TABELA OFICIAL

Fonte local: `functions/config/delivery-pricing-initial.json`. O painel abre uma cópia editável da mesma tabela aprovada. Origem inicial permanece `null`, deliberadamente.

Primeira faixa inclui zero. Nas seguintes, o limite inferior é exclusivo e o superior é inclusivo. Limites são inteiros em metros; preços são centavos inteiros. Não há soma progressiva de faixas nem arredondamento visual antes da comparação.

| Distância em metros | Valor completo |
|---|---:|
| 0 até 1000, inclusive | R$ 6,00 |
| 1000 < distância até 1500, inclusive | R$ 7,00 |
| 1500 < distância até 2000, inclusive | R$ 8,00 |
| 2000 < distância até 2500, inclusive | R$ 9,00 |
| 2500 < distância até 3000, inclusive | R$ 10,00 |
| 3000 < distância até 3500, inclusive | R$ 11,00 |
| 3500 < distância até 4000, inclusive | R$ 12,00 |
| 4000 < distância até 4500, inclusive | R$ 13,00 |
| 4500 < distância até 5000, inclusive | R$ 14,00 |
| 5000 < distância até 5500, inclusive | R$ 15,00 |
| 5500 < distância até 6000, inclusive | R$ 16,00 |
| 6000 < distância até 6500, inclusive | R$ 17,00 |
| 6500 < distância até 7000, inclusive | R$ 18,00 |
| 7000 < distância até 7500, inclusive | R$ 19,00 |
| 7500 < distância até 8000, inclusive | R$ 20,00 |
| 8000 < distância até 8500, inclusive | R$ 21,00 |
| 8500 < distância até 9000, inclusive | R$ 22,00 |
| 9000 < distância até 9500, inclusive | R$ 23,00 |
| 9500 < distância até 10000, inclusive | R$ 24,00 |
| 10000 < distância até 10500, inclusive | R$ 25,00 |
| 10500 < distância até 11000, inclusive | R$ 27,00 |
| 11000 < distância até 11500, inclusive | R$ 29,00 |
| 11500 < distância até 12000, inclusive | R$ 31,00 |
| 12000 < distância até 12500, inclusive | R$ 33,00 |
| 12500 < distância até 13000, inclusive | R$ 35,00 |
| 13000 < distância até 13500, inclusive | R$ 37,00 |
| 13500 < distância até 14000, inclusive | R$ 39,00 |
| 14000 < distância até 14500, inclusive | R$ 40,00 |

Exemplos verificados: 1.500 m → R$ 7,00; 1.501 m → R$ 8,00; 8.243 m → R$ 21,00; 14.500 m → R$ 40,00; 14.501 m → fora da área. A distância fracionária também é comparada antes de arredondar.

Mensagem de fora da área: `Este endereço está fora da área de entrega disponível no momento.`

## PISO R$ 8

Não aplicado ao cálculo oficial. Zero a 1.000 m custa R$ 6,00. O editor não oferece mais o piso, e o endpoint recusa novas versões com `minimumPolicy: floor800`. A leitura do formato antigo permanece apenas para compatibilidade com versões históricas; não migra nem recalcula financeiro antigo.

## PAINEL ADMIN

Seção `Frete por distância`, na área protegida de configurações. Colunas De/Até/Valor/Status/Ações, distâncias em km com vírgula e valores em reais.

Permite editar limites e preço, adicionar, excluir e duplicar faixas, subdividir, habilitar faixas do rascunho, salvar rascunho, descartar alterações locais, carregar o modelo inicial, editar cópia de versão salva, consultar versão ativa e confirmar explicitamente uma publicação. Duplicar não corrige limites silenciosamente: sobreposições precisam ser resolvidas antes de publicar.

Somente `superadmin` possui a permissão existente. `finance`, `operations_admin` e `catalog_admin` não foram ampliados. Backend repete a autorização e exclui contas de entregadores.

Publicação gera versão imutável e inativa para revisão. Não escreve `activeVersion`. A callable de ativação continua recusando a operação enquanto os bloqueadores operacionais não forem resolvidos.

## SUBDIVISÃO 100M

Opera exclusivamente na cópia em edição. Divide a faixa em passos de 100 m, preservando o preço completo original. As novas linhas ficam pendentes de habilitação/revisão no rascunho; o painel oferece habilitação das faixas. Não publica automaticamente e não altera a versão ativa.

Exemplo: 5.000–5.500 m gera 5.000–5.100, 5.100–5.200, 5.200–5.300, 5.300–5.400 e 5.400–5.500 m. A expansão não exige subdivisão de todas as faixas.

## LIMITE ATUAL / LIMITE TÉCNICO

- Inicial aprovado: **14,5 km**, inclusive.
- Técnico: **30 km**, inclusive, e até 300 faixas.
- Não há tarifa presumida acima de 14,5 km. Uma extensão exige edição, validação e publicação futura explícita.

Publicação recusa lacunas, sobreposições, inversões, duplicidade, ordem quebrada, preço negativo/fracionário em centavos, linha desabilitada, limite maior que 30.000 m ou `maxDistanceMeters` divergente da última faixa. A cobertura publicada deve ser contínua desde zero.

## CONFIGURAÇÃO VERSIONADA

`deliveryPricingVersions/{version}` mantém `version`, `status` (`draft`/`published`), `createdAt`, `updatedAt`, `createdBy`, `publishedAt`, `publishedBy`, `maxDistanceMeters`, fingerprint e `table`.

`table` contém `schemaVersion`, `minimumPolicy: replace`, `origin`, `maxDistanceMeters` e `bands`. Cada faixa usa `minExclusiveMeters`, `maxInclusiveMeters`, `priceCents`, `enabled` e `order`. O editor consegue ler cópias do esquema antigo, mas novos salvamentos são canônicos.

`deliveryConfiguration/draft.draftVersion` é independente de `deliveryConfiguration/current.activeVersion`. Uma futura configuração ativa de homologação deve selecionar explicitamente `mode: routeBands`, uma versão publicada, `travelMode: DRIVE` ou `TWO_WHEELER` e o marco de ativação previsto no contrato legado. Esse documento não foi criado/alterado nesta tarefa.

## GOOGLE ROUTES

Abstração `RoutingProvider` preservada. `GoogleRoutesProvider` faz POST para `https://routes.googleapis.com/directions/v2:computeRoutes` somente no backend. Usa origem da tabela publicada, destino confirmado, máscara de campos com distância/duração e timeout de 10 s. O nome do provedor congelado é `google-routes`.

Falha HTTP, timeout, rota ausente, resposta inválida ou fallback informado pelo Google bloqueiam a cotação. Não há Haversine, frete zero por falha, troca silenciosa de provedor ou preço inventado. Mensagem temporária: `Não foi possível calcular a entrega agora. Tente novamente.`

Auditoria remota em 19/10/2026:

- Routes API (`routes.googleapis.com`): **não habilitada**.
- Billing do projeto: **habilitado** (`billingEnabled: true`). A consulta não verifica débitos ou meios de pagamento da conta.
- Secret `CHAMAE_ROUTES_API_KEY`: **não encontrado**.
- `deliveryConfiguration/current`: **não encontrado**.
- Nenhuma dessas condições foi modificada automaticamente.

A execução permanece em `southamerica-east1`; a API de rotas é global. O código não considera cruzar a fronteira como fora da área: aceita destinos BR/PY e aplica a mesma regra de rota e distância. A documentação Google inclui Brasil e Paraguai na cobertura, inclusive de duas rodas. Isso não comprova uma rota específica em fronteira: a homologação deverá testar os trajetos reais a partir da origem aprovada e confirmar o modo de veículo.

## SECRET / CONFIGURAÇÃO FUTURA

O secret está declarado por `defineSecret("CHAMAE_ROUTES_API_KEY")` e vinculado em `secrets` apenas à callable de cotação. O valor é lido durante a execução. Nenhuma chave Routes foi criada, impressa, hardcoded ou reutilizada das chaves Web/Android Maps/Firebase.

Após autorização externa, o responsável poderá habilitar a API e provisionar a credencial dedicada:

```powershell
# Documentação para etapa futura; comandos NÃO executados nesta tarefa.
gcloud services enable routes.googleapis.com --project=chamae-delivery
firebase functions:secrets:set CHAMAE_ROUTES_API_KEY --project chamae-delivery
```

Inserir o valor pelo prompt seguro, sem passá-lo na linha de comando ou adicioná-lo ao Git. Restringir a API a Routes API. Para restrição por IP, configurar e confirmar saída pública estática do backend (VPC/NAT ou arquitetura aprovada); não usar restrições de referer Web nem package/SHA Android para essa chave. Conceder acesso ao secret somente à identidade de execução necessária. Modo de veículo, quotas e monitoramento também precisam de revisão antes da ativação.

## ORIGEM PIT STOP V8

Não foi localizada origem comercial aprovada no código/configurações de frete auditados. Os documentos remotos `deliveryConfiguration/current`, `stores/pit-stop-v8` e `settings/store` consultados retornaram 404. Não se presume que esses nomes esgotem todos os cadastros remotos; se existir outro cadastro oficial, ele deve ser identificado e validado.

O fallback visual do mapa não foi convertido em origem da loja. O modelo permanece com origem vazia, e a publicação exige coordenadas preenchidas. **Origem oficial é bloqueador objetivo para rota real.** Coordenadas em testes são sintéticas e identificadas como fixtures.

## BACKEND AUTORITATIVO / FREEZE POR PEDIDO

Cliente solicita uma cotação, mas não escolhe origem, distância, faixa, preço ou versão. A origem e versão vêm da configuração no servidor, a distância vem do provedor e o preço vem da tabela publicada. Campos forjados no request são ignorados.

Cotação privada vincula UID, origem, destino, país, versão, distância, preço, provedor e validade de cinco minutos. `requestId` fornece idempotência; falha não persiste um preço substituto. Reuso por outro UID/destino/pedido e expiração são recusados.

Na confirmação financeira, o backend valida a cotação privada. O consumo da cotação é atômico com a criação do financeiro; não se exige uma segunda chamada paga ao Google enquanto a cotação válida está vinculada ao pedido. O pedido/financeiro congelam:

- `deliveryFee`;
- `deliveryDistanceMeters`;
- `deliveryPricingVersion`;
- `routingProvider`;
- `deliveryQuotedAtMs`;
- `deliverySnapshot` com os demais vínculos.

Financeiro já existente é reutilizado sem recalcular. Mudança posterior de tabela não altera pedidos congelados, e distância percorrida depois pelo entregador não participa da cobrança.

Comissões atuais de produtos (1% cliente e 3% lojista), frete separado e regras de pagamento BR/PY foram preservados. Não foi definida uma nova remuneração do motoboy.

## CUSTOMER APP

Após destino confirmado, a Home mostra cotação. Carrinho e checkout mostram cálculo em andamento, preço, fora da área, erro e retry. Carrinho com endereço e cotação indisponível não avança para entrega. Sem endereço, mostra os valores de produtos/serviço e informa que a entrega depende da confirmação do destino.

Mudança de endereço invalida a cotação e respostas anteriores são descartadas. Checkout também protege contra corrida entre respostas e revalida antes de enviar. Falha não exibe zero como entrega definitiva; itens do carrinho são mantidos. O caminho explícito de modo legado permanece compatível; não é fallback para falha do Google.

## RULES

`deliveryPricingVersions` e `deliveryConfiguration`: leitura somente por superadmin sem vínculo de entregador; escrita direta de cliente/admin pelo SDK recusada. `deliveryQuotes` continua privada, sem acesso direto pelo app. Publicação passa pela callable autorizada. Testes de Rules executados no Firestore Emulator local, projeto demo, não no Firebase de produção.

## TESTES

| Verificação | Resultado |
|---|---|
| Backend direcionado: faixas/rota/financeiro | 102 aprovados |
| Backend: suíte `npm test` | 269 aprovados |
| Backend: lint completo | Aprovado |
| Rules + operações no emulador local | 226 aprovados |
| Cliente: testes direcionados | 22 aprovados |
| Cliente: suíte Flutter VM completa | 101 aprovados |
| Cliente: `flutter analyze` final | Sem ocorrências |
| Painel: frete + autenticação + responsividade | 54 aprovados |
| Painel: editor após ajuste final | 6 aprovados |
| Painel: análise dos arquivos de frete/testes | Sem ocorrências |
| Painel: `flutter analyze` completo | 22 diagnósticos preexistentes: 2 warnings e 20 infos, fora dos arquivos alterados |

Casos de faixas solicitados cobertos: 0/1000/1001/1500/1501/8000/8001/10500/10501/14000/14001/14500/14501 m, além de 8.243 m e limites fracionários. Cobertos preço, adição/remoção, subdivisão, gap/overlap, sequência/duplicidade, 30 km, draft independente, publicação explícita e roles sem permissão. Backend testa campos forjados, falha/ausência de configuração/origem, freeze, histórico, idempotência e BR/PY. Cliente testa carregamento, erro/retry, total separado e respostas atrasadas.

A suíte inicial completa do cliente identificou a retirada do subtotal conhecido do carrinho sem endereço. O subtotal foi preservado e a suíte final passou. Ajustes de lint introduzidos nesta etapa foram corrigidos. Os diagnósticos restantes do painel estão em `main.dart`, `new_order_attention.dart` e `order_chat.dart`; não foram alterados para resolver avisos fora do escopo.

Testes com providers fake/fixtures e emulador não equivalem a uma chamada Google Routes real nem à homologação em aparelho. A suíte Flutter VM não executa o teste marcado exclusivamente para browser; os builds Web foram executados separadamente.

## BUILDS

| Build | Resultado |
|---|---|
| Cliente Web release (final) | Aprovado |
| Cliente Android debug | Aprovado |
| Painel Web release (final) | Aprovado |

Artefatos esperados: cliente `build/web`, cliente `build/app/outputs/flutter-apk/app-debug.apk`, painel `build/web`. Nenhum artefato foi publicado ou instalado no aparelho nesta etapa.

Build Web gera JavaScript/CanvasKit. O painel avisa sobre `dart:html` preexistente no diagnóstico opcional de Wasm; isso não é falha do build JavaScript nem aprovação de build Wasm. Android emite aviso de migração futura de KGP dos plugins Firebase; o APK debug foi gerado.

## ARQUIVOS DE IMPLEMENTAÇÃO ALTERADOS NESTA ETAPA

Cliente (`C:/Users/DELL/chamae_delivery`):

- `functions/config/delivery-pricing-initial.json` (novo);
- `functions/delivery-pricing.js`, `functions/delivery-service.js`, `functions/google-routes-provider.js`, `functions/index.js`;
- `functions/.eslintrc.js`, `functions/package.json`;
- `functions/test/delivery-official.spec.js` (novo), `functions/test/financial.spec.js`, `functions/test/firestore.rules.spec.js`;
- `firestore.rules`;
- `lib/data/delivery_quote.dart`;
- `lib/widgets/delivery_quote_summary.dart` (novo);
- `lib/screens/cart_screen.dart`, `lib/screens/home_screen.dart`, `lib/screens/checkout_screen.dart`;
- `test/delivery_quote_state_test.dart` (novo);
- `docs/frete_google_routes_final_readiness_2026-10-19.md` (este relatório).

Painel (`C:/Users/DELL/chamae_admin`):

- `lib/delivery_settings.dart`;
- `test/delivery_settings_test.dart`.

Logs locais desta tarefa usam prefixo `frete_` em `chamae_delivery/tool/` e `chamae_admin/tools/`. São evidências de execução, não configuração de produção. Há modificações anteriores nos dois workspaces; esta lista não atribui essas mudanças à etapa atual.

## BLOQUEADORES

1. Habilitar Routes API e provisionar o secret dedicado, após autorização.
2. Confirmar a origem oficial da Pit Stop V8 e escolher/homologar o modo de veículo.
3. Homologar rotas reais BR→BR e BR→PY, fronteira e distâncias próximas de 14.500 m.
4. Revisar a remuneração dos entregadores: o código existente utiliza `deliveryFee` nos repasses. Não se pode ativar novos preços sem a decisão/integração operacional necessária.
5. Implantar o conjunto revisado de Functions, Rules e apps em homologação autorizada, publicar a versão aprovada e realizar ativação separada. A callable de ativação permanece bloqueada nesta entrega.
6. Para homologação Android completa, resolver a configuração Maps SDK/chave Android apontada na auditoria anterior. As validações jurídicas do backend também continuam exigindo documentos oficiais no checkout; a passagem debug pelo onboarding não cria aceite jurídico.

## DEPLOY NECESSÁRIO

Não realizado. Após as decisões acima, revisar as Functions afetadas de cotação/publicação e financeiro, provisionar a credencial dedicada, validar permissões de execução e publicar Rules junto com clientes compatíveis em ambiente de homologação. Revalidar PIX, dinheiro, cartão BR, restrição de cartão PY, pedido histórico, reenvio idempotente e falha de rede. Só depois autorizar ativação da versão publicada; manter rollback deliberado para modo legado sem reprecificar pedidos congelados.

## REFERÊNCIAS OFICIAIS

- [Google Routes Compute Routes](https://developers.google.com/maps/documentation/routes/compute_route_directions).
- [Cobertura Routes API](https://developers.google.com/maps/documentation/routes/coverage).
- [Cobertura de duas rodas, incluindo BR/PY](https://developers.google.com/maps/documentation/routes/coverage-two-wheeled).
- [Segurança e restrições de credenciais](https://developers.google.com/maps/api-security-best-practices).
- [Firebase Functions e Secret Manager](https://firebase.google.com/docs/functions/config-env).

**FRETE AINDA POSSUI BLOQUEADORES**
