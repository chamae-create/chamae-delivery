const {

  randomUUID,

  createHmac,

  timingSafeEqual,

} = require("node:crypto");


const {onRequest} = require("firebase-functions/v2/https");
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");

const {defineSecret} = require("firebase-functions/params");


const {

  WebhookSignatureValidator,

  InvalidWebhookSignatureError,

} = require("mercadopago");


const {

  initializeApp,

  getApps,

} = require("firebase-admin/app");


const {

  getFirestore,

  FieldValue,

} = require("firebase-admin/firestore");


if (getApps().length === 0) {
  initializeApp();
}


const db = getFirestore();

/**
 * Agrupa quantidades por produto sem permitir que itens inválidos se compensem.
 * @param {*} itemsList Itens originais do pedido.
 * @return {?Array} Itens agrupados, ou null quando algum item é inválido.
 */
function agruparItensEstoque(itemsList) {
  const itens = Array.isArray(itemsList) ? itemsList : [];
  const quantidades = new Map();

  for (const item of itens) {
    const productId = item && typeof item.id === "string" ?
      item.id.trim() : "";
    const quantity = Number(item && item.quantity);

    if (!productId || !Number.isSafeInteger(quantity) || quantity <= 0) {
      return null;
    }

    const total = (quantidades.get(productId) || 0) + quantity;
    if (!Number.isSafeInteger(total)) {
      return null;
    }
    quantidades.set(productId, total);
  }

  return Array.from(quantidades, ([id, quantity]) => ({id, quantity}));
}

const FRETE_PEDIDO_CENTAVOS = 1000;
const PYG_POR_BRL = 1500;
const BRL_POR_USD = 5;

/**
 * Identifica erros financeiros sem tratá-los como falhas de estoque.
 * @param {string} codigo Código do erro.
 * @return {Error} Erro identificado.
 */
function erroFinanceiro(codigo) {
  const error = new Error(codigo);
  error.financeiro = true;
  return error;
}

/**
 * Impede mudança dos produtos/quantidades após o financeiro ser congelado.
 * @param {Object} pedido Pedido atual.
 * @param {Object} dados Financeiro oficial.
 */
function conferirItensFinanceiros(pedido, dados) {
  const itens = agruparItensEstoque(pedido.itemsList);
  const quantidades = new Map((itens || []).map((item) =>
    [item.id, item.quantity]));
  if (
    !itens || dados.items.length !== itens.length ||
    dados.items.some((item) => quantidades.get(item.id) !== item.quantity)
  ) {
    throw erroFinanceiro("ITENS_PEDIDO_ALTERADOS");
  }
}

/**
 * Obtém preços oficiais e congela o financeiro em um documento do backend.
 * Não escreve: todas as leituras da transação devem preceder as escritas.
 * @param {Object} transaction Transação Firestore.
 * @param {Object} orderRef Referência do pedido.
 * @param {Object} pedido Pedido atual.
 * @return {Promise<Object>} Financeiro e referência para persistência.
 */
async function prepararFinanceiroPedido(transaction, orderRef, pedido) {
  const itens = agruparItensEstoque(pedido.itemsList);
  if (!itens || itens.length === 0) {
    throw erroFinanceiro(itens ? "PEDIDO_SEM_ITENS" : "ITEM_PEDIDO_INVALIDO");
  }

  // Esta coleção deve permitir escrita somente pelo backend (Admin SDK).
  const ref = db.collection("orderFinancials").doc(orderRef.id);
  const snapshot = await transaction.get(ref);
  if (snapshot.exists) {
    const dados = snapshot.data();
    conferirItensFinanceiros(pedido, dados);
    return {ref, dados, novo: false};
  }

  let subtotalCentavos = 0;
  const items = [];
  for (const item of itens) {
    const productSnapshot = await transaction.get(
        db.collection("products").doc(item.id),
    );
    if (!productSnapshot.exists) {
      throw erroFinanceiro("PRODUTO_NAO_ENCONTRADO");
    }
    const product = productSnapshot.data() || {};
    const preco = product.priceBRL == null ? product.price : product.priceBRL;
    const precoCentavos = Math.round((preco + Number.EPSILON) * 100);
    if (
      typeof preco !== "number" || !Number.isFinite(preco) || preco < 0 ||
      !Number.isSafeInteger(precoCentavos) ||
      Math.abs(preco * 100 - precoCentavos) > 0.000001
    ) {
      throw erroFinanceiro("PRECO_PRODUTO_INVALIDO");
    }
    if (product.isActive === false) {
      throw erroFinanceiro("PRODUTO_INATIVO");
    }
    subtotalCentavos += precoCentavos * item.quantity;
    if (!Number.isSafeInteger(subtotalCentavos)) {
      throw erroFinanceiro("VALOR_PEDIDO_INVALIDO");
    }
    items.push({
      id: item.id, quantity: item.quantity, price: precoCentavos / 100,
    });
  }

  if (subtotalCentavos > Math.floor((Number.MAX_SAFE_INTEGER - 50) / 3)) {
    throw erroFinanceiro("VALOR_PEDIDO_INVALIDO");
  }
  const customerFeeCentavos = Math.floor((subtotalCentavos + 50) / 100);
  const merchantFeeCentavos = Math.floor((subtotalCentavos * 3 + 50) / 100);
  const totalCentavos =
      subtotalCentavos + FRETE_PEDIDO_CENTAVOS + customerFeeCentavos;
  if (!Number.isSafeInteger(totalCentavos) || totalCentavos <= 0) {
    throw erroFinanceiro("VALOR_PEDIDO_INVALIDO");
  }

  // Uma tentativa antiga sem registro financeiro só pode reutilizar sua chave
  // se o valor previamente congelado coincide com o cálculo oficial atual.
  const chaveLegada = typeof pedido.mercadoPagoIdempotencyKey === "string" ?
    pedido.mercadoPagoIdempotencyKey : "";
  if (chaveLegada && Math.round(Number(pedido.mercadoPagoAmountBRL) * 100) !==
      totalCentavos) {
    throw erroFinanceiro("PIX_LEGADO_VALOR_DIVERGENTE");
  }

  const dados = {
    items,
    itemsTotal: subtotalCentavos / 100,
    deliveryFee: FRETE_PEDIDO_CENTAVOS / 100,
    customerFee: customerFeeCentavos / 100,
    merchantFee: merchantFeeCentavos / 100,
    merchantNet: (subtotalCentavos - merchantFeeCentavos) / 100,
    platformFee: (customerFeeCentavos + merchantFeeCentavos) / 100,
    totalBRL: totalCentavos / 100,
    totalCentavos,
    pixIdempotencyKey: chaveLegada || randomUUID(),
    version: 1,
    createdAt: FieldValue.serverTimestamp(),
  };
  return {ref, dados, novo: true};
}

/**
 * Replica os campos oficiais no pedido sem usar preços enviados pelo cliente.
 * @param {Object} pedido Pedido atual.
 * @param {Object} dados Registro financeiro do backend.
 * @return {Object} Campos financeiros oficiais para atualização.
 */
function camposFinanceirosPedido(pedido, dados) {
  const precos = new Map(dados.items.map((item) => [item.id, item.price]));
  return {
    itemsList: pedido.itemsList.map((item) => ({
      ...item,
      price: precos.get(item.id.trim()),
      ...(Object.prototype.hasOwnProperty.call(item, "unitPrice") ?
        {unitPrice: precos.get(item.id.trim())} : {}),
    })),
    itemsTotal: dados.itemsTotal,
    deliveryFee: dados.deliveryFee,
    customerFee: dados.customerFee,
    merchantFee: dados.merchantFee,
    merchantNet: dados.merchantNet,
    platformFee: dados.platformFee,
    totalBRL: dados.totalBRL,
    financialValidationStatus: "validated",
    financialValidationVersion: dados.version,
    financialValidationError: null,
  };
}

/**
 * Valida valores declarados para entrega contra o total oficial.
 * Mantém moedas e cotações; valores convertidos do cliente não são usados.
 * @param {Object} pedido Pedido atual.
 * @param {Object} dados Financeiro oficial.
 */
function validarPagamentoEntrega(pedido, dados) {
  if (pedido.splitPayment === true) {
    const partes = pedido.paymentParts;
    if (!Array.isArray(partes) || partes.length < 2 || partes.length > 3) {
      throw erroFinanceiro("SPLIT_PAYMENT_INVALIDO");
    }
    let totalBRL = 0;
    for (const parte of partes) {
      if (!parte || parte.method !== "Dinheiro") {
        throw erroFinanceiro("SPLIT_PAYMENT_INVALIDO");
      }
      const amount = parte.amountCurrency;
      if (
        typeof amount !== "number" || !Number.isFinite(amount) || amount <= 0
      ) {
        throw erroFinanceiro("VALOR_PAGAMENTO_INVALIDO");
      }
      switch (parte.currency) {
        case "BRL": totalBRL += amount; break;
        case "USD": totalBRL += amount * BRL_POR_USD; break;
        case "PYG": totalBRL += amount / PYG_POR_BRL; break;
        default: throw erroFinanceiro("MOEDA_PAGAMENTO_INVALIDA");
      }
    }
    if (!Number.isSafeInteger(Math.round(totalBRL * 100))) {
      throw erroFinanceiro("VALOR_PAGAMENTO_INVALIDO");
    }
    if (Math.round(totalBRL * 100) < dados.totalCentavos) {
      throw erroFinanceiro("PAGAMENTO_INSUFICIENTE");
    }
  } else if (pedido.paymentMethod === "Dinheiro") {
    // Pedidos antigos podem não ter declaração de cédulas para troco.
    if (pedido.cashTendered == null) return;
    const amount = pedido.cashTendered;
    if (typeof amount !== "number" || !Number.isFinite(amount) || amount <= 0) {
      throw erroFinanceiro("VALOR_PAGAMENTO_INVALIDO");
    }
    let totalMoeda;
    switch (pedido.cashCurrency || "BRL") {
      case "BRL": totalMoeda = dados.totalBRL; break;
      case "USD": totalMoeda = Math.round(dados.totalBRL / BRL_POR_USD * 100) /
          100; break;
      case "PYG": totalMoeda = Math.round(dados.totalBRL * PYG_POR_BRL); break;
      default: throw erroFinanceiro("MOEDA_PAGAMENTO_INVALIDA");
    }
    if (amount < totalMoeda) {
      throw erroFinanceiro("PAGAMENTO_INSUFICIENTE");
    }
  }
}


const mercadoPagoToken =

    defineSecret("MERCADOPAGO_ACCESS_TOKEN");


const mercadoPagoWebhookSecret =

    defineSecret("MERCADOPAGO_WEBHOOK_SECRET");


const chamaePixTestKey =

    defineSecret("CHAMAE_PIX_TEST_KEY");


// ======================================================

// FUNÇÃO 1 — STATUS DO BACKEND

// ======================================================


exports.chamaeStatus = onRequest(

    {

      region: "southamerica-east1",

      cors: false,

      invoker: "public",

    },

    (request, response) => {
      response.status(200).json({

        aplicativo: "Chamaê Delivery",

        backend: "Firebase Cloud Functions",

        status: "online",

        ambiente: "desenvolvimento",

      });
    },

);


// ======================================================

// FUNÇÃO 2 — DIAGNÓSTICO DO MERCADO PAGO

// ======================================================


exports.chamaeMercadoPagoTeste = onRequest(

    {

      region: "southamerica-east1",

      cors: false,

      invoker: "private",

      secrets: [mercadoPagoToken],

    },

    async (request, response) => {
      if (request.method !== "GET") {
        response.status(405).json({

          erro: "Método não permitido",

        });

        return;
      }


      try {
        const resultado = await fetch(

            "https://api.mercadopago.com/v1/payment_methods",

            {

              method: "GET",

              headers: {

                "Authorization":

                    `Bearer ${mercadoPagoToken.value()}`,

                "Content-Type": "application/json",

              },

              signal: AbortSignal.timeout(10000),

            },

        );


        response.status(

            resultado.ok ? 200 : 502,

        ).json({

          aplicativo: "Chamaê Delivery",

          integracao: "Mercado Pago",

          comunicacao:

              resultado.ok ? "sucesso" : "falha",

          statusHttpMercadoPago:

              resultado.status,

          ambiente: "teste",

        });
      } catch (error) {
        console.error(

            "Falha no diagnóstico do Mercado Pago:",

            error.message,

        );


        response.status(502).json({

          aplicativo: "Chamaê Delivery",

          integracao: "Mercado Pago",

          comunicacao: "falha",

        });
      }
    },

);


// ======================================================

// FUNÇÃO 3 — PIX ISOLADO DE TESTE

// ======================================================


exports.chamaePixTeste = onRequest(

    {

      region: "southamerica-east1",

      cors: false,

      invoker: "private",

      secrets: [

        mercadoPagoToken,

        chamaePixTestKey,

      ],

      maxInstances: 1,

    },

    async (request, response) => {
      if (request.method !== "POST") {
        response.status(405).json({

          erro: "Método não permitido",

        });

        return;
      }


      const chaveRecebida =

          request.get("x-chamae-test-key");


      if (

        !chaveRecebida ||

        chaveRecebida !== chamaePixTestKey.value()

      ) {
        response.status(401).json({

          erro: "Não autorizado",

        });

        return;
      }


      const identificador = randomUUID();


      const pedido = {

        type: "online",

        total_amount: "50.00",

        external_reference:

            `chamae_teste_${identificador}`,

        processing_mode: "automatic",

        transactions: {

          payments: [

            {

              amount: "50.00",

              payment_method: {

                id: "pix",

                type: "bank_transfer",

              },

            },

          ],

        },

        payer: {

          email: "test_user_br@testuser.com",

          first_name: "APRO",

        },

      };


      try {
        const resultado = await fetch(

            "https://api.mercadopago.com/v1/orders",

            {

              method: "POST",

              headers: {

                "Authorization":

                    `Bearer ${mercadoPagoToken.value()}`,

                "Content-Type": "application/json",

                "X-Idempotency-Key":

                    identificador,

              },

              body: JSON.stringify(pedido),

              signal: AbortSignal.timeout(15000),

            },

        );


        const dados = await resultado.json();


        if (!resultado.ok) {
          response.status(502).json({

            sucesso: false,

            statusHttpMercadoPago:

                resultado.status,

          });

          return;
        }


        const pagamento =

            dados.transactions &&

            dados.transactions.payments &&

            dados.transactions.payments.length > 0 ?

              dados.transactions.payments[0] :

              {};


        const metodo =

            pagamento.payment_method || {};


        response.status(200).json({

          sucesso: true,

          orderId: dados.id || null,

          paymentId: pagamento.id || null,

          qrCode: metodo.qr_code || null,

          qrCodeBase64:

              metodo.qr_code_base64 || null,

          ticketUrl:

              metodo.ticket_url || null,

        });
      } catch (error) {
        console.error(

            "Erro no PIX isolado:",

            error.message,

        );


        response.status(502).json({

          sucesso: false,

          erro: "Falha de comunicação",

        });
      }
    },

);


// ======================================================

// FUNÇÃO 4 — WEBHOOK DO MERCADO PAGO

// ======================================================


exports.chamaeMercadoPagoWebhook = onRequest(

    {

      region: "southamerica-east1",

      cors: false,

      invoker: "public",

      secrets: [

        mercadoPagoToken,

        mercadoPagoWebhookSecret,

      ],

      maxInstances: 5,

    },

    async (request, response) => {
      if (request.method !== "POST") {
        response.status(405).send(

            "Método não permitido",

        );

        return;
      }


      const xSignature =

          request.get("x-signature");


      const xRequestId =

          request.get("x-request-id");


      const dataIdQuery =

          request.query["data.id"];


      const dataId =

          Array.isArray(dataIdQuery) ?

            dataIdQuery[0] :

            dataIdQuery;


      const applicationId =

          request.body &&

          request.body.application_id ?

            request.body.application_id :

            null;


      const userId =

          request.body &&

          request.body.user_id ?

            request.body.user_id :

            null;


      const liveMode =

          request.body &&

          typeof request.body.live_mode === "boolean" ?

            request.body.live_mode :

            null;


      const action =

          request.body &&

          request.body.action ?

            request.body.action :

            null;


      const tipoBody =

          request.body &&

          request.body.type ?

            request.body.type :

            null;


      const tipo =

          tipoBody || request.query.type;


      console.log(

          "Origem da notificação Mercado Pago.",

          {

            dataId: dataId || null,

            applicationId: applicationId,

            userId: userId,

            liveMode: liveMode,

            action: action,

          },

      );


      if (

        !xSignature ||

        !xRequestId ||

        !dataId

      ) {
        console.warn(

            "Webhook sem dados obrigatórios.",

        );


        response.status(401).send(

            "Assinatura inválida",

        );

        return;
      }


      // ==================================================

      // DIAGNÓSTICO HMAC

      // Temporário, somente para investigação do sandbox

      // ==================================================


      const partesAssinatura =

          xSignature.split(",");


      let timestamp = "";

      let assinaturaRecebida = "";


      for (const parte of partesAssinatura) {
        const posicaoIgual =

            parte.indexOf("=");


        if (posicaoIgual === -1) {
          continue;
        }


        const chave =

            parte

                .substring(

                    0,

                    posicaoIgual,

                )

                .trim();


        const valor =

            parte

                .substring(

                    posicaoIgual + 1,

                )

                .trim();


        if (chave === "ts") {
          timestamp = valor;
        }


        if (chave === "v1") {
          assinaturaRecebida = valor;
        }
      }


      const verificarManifest =

          (idManifest) => {
            if (

              !timestamp ||

              !assinaturaRecebida

            ) {
              return false;
            }


            const manifest =

                `id:${idManifest};` +

                `request-id:${xRequestId};` +

                `ts:${timestamp};`;


            const assinaturaCalculada =

                createHmac(

                    "sha256",

                    mercadoPagoWebhookSecret.value(),

                )

                    .update(manifest)

                    .digest("hex");


            const recebidaBuffer =

                Buffer.from(

                    assinaturaRecebida,

                    "utf8",

                );


            const calculadaBuffer =

                Buffer.from(

                    assinaturaCalculada,

                    "utf8",

                );


            if (

              recebidaBuffer.length !==

              calculadaBuffer.length

            ) {
              return false;
            }


            return timingSafeEqual(

                recebidaBuffer,

                calculadaBuffer,

            );
          };


      const matchOriginal =

          verificarManifest(

              dataId.toString(),

          );


      const matchLowercase =

          verificarManifest(

              dataId

                  .toString()

                  .toLowerCase(),

          );


      console.log(

          "Diagnóstico HMAC Mercado Pago.",

          {

            dataId: dataId,

            matchOriginal: matchOriginal,

            matchLowercase: matchLowercase,

          },

      );


      // ==================================================

      // PROCESSAMENTO SEGURO DA ORDER

      // ==================================================


      const processarOrder =

          async (origemValidacao) => {
            const orderUrl =

                "https://api.mercadopago.com/v1/orders/" +

                encodeURIComponent(

                    dataId.toString(),

                );


            let resultado;


            try {
              resultado = await fetch(

                  orderUrl,

                  {

                    method: "GET",

                    headers: {

                      "Authorization":

                          `Bearer ${mercadoPagoToken.value()}`,

                      "Content-Type":

                          "application/json",

                    },

                    signal:

                        AbortSignal.timeout(

                            15000,

                        ),

                  },

              );
            } catch (error) {
              console.error(

                  "Falha ao consultar Order.",

                  {

                    dataId: dataId,

                    erro: error.message,

                  },

              );


              response.status(500).send(

                  "Erro temporário",

              );

              return;
            }


            let order;


            try {
              order =

                  await resultado.json();
            } catch (error) {
              console.error(

                  "Resposta inválida da API de Orders.",

                  {

                    dataId: dataId,

                    statusHttp:

                        resultado.status,

                  },

              );


              response.status(500).send(

                  "Erro temporário",

              );

              return;
            }


            if (!resultado.ok) {
              console.warn(

                  "Order não consultável no Mercado Pago.",

                  {

                    dataId: dataId,

                    statusHttp:

                        resultado.status,

                  },

              );


              if (

                resultado.status >= 400 &&

                resultado.status < 500

              ) {
                response.status(200).send("OK");

                return;
              }


              response.status(500).send(

                  "Falha temporária ao consultar Order",

              );

              return;
            }


            const orderId =

                order.id ?

                  order.id.toString() :

                  "";


            const status =

                order.status || null;


            const statusDetail =

                order.status_detail || null;


            const processingMode =

                order.processing_mode || null;


            const externalReference =

                typeof order.external_reference ===

                    "string" ?

                  order.external_reference.trim() :

                  "";


            const totalAmount =

                Number(

                    order.total_amount,

                );


            const pagamento =

                order.transactions &&

                order.transactions.payments &&

                order.transactions.payments.length > 0 ?

                  order.transactions.payments[0] :

                  {};


            const paymentMethod =

                pagamento.payment_method || {};


            const paymentMethodId =

                typeof paymentMethod.id === "string" ?

                  paymentMethod.id

                      .toLowerCase() :

                  "";


            const paymentMethodType =

                typeof paymentMethod.type === "string" ?

                  paymentMethod.type

                      .toLowerCase() :

                  "";


            const paymentStatus =

                pagamento.status || null;


            const paymentStatusDetail =

                pagamento.status_detail || null;


            console.log(

                "Order consultada diretamente no Mercado Pago.",

                {

                  orderId: orderId || null,

                  status: status,

                  statusDetail: statusDetail,

                  externalReference:

                      externalReference || null,

                  origemValidacao:

                      origemValidacao,

                },

            );


            // ==============================================

            // CONFIRMAÇÃO DO ID DA ORDER

            // ==============================================


            if (

              !orderId ||

              orderId !== dataId.toString()

            ) {
              console.error(

                  "ID da Order consultada não corresponde.",

                  {

                    recebido:

                        dataId,

                    consultado:

                        orderId || null,

                  },

              );


              response.status(200).send("OK");

              return;
            }


            // ==============================================

            // EXTERNAL REFERENCE OBRIGATÓRIA

            // ==============================================


            if (!externalReference) {
              console.error(

                  "Order sem external_reference.",

                  {

                    orderId: orderId,

                  },

              );


              response.status(200).send("OK");

              return;
            }


            // ==============================================

            // PROCESSAMENTO AUTOMÁTICO

            // ==============================================


            if (

              processingMode &&

              processingMode !== "automatic"

            ) {
              console.error(

                  "Order com processing_mode inesperado.",

                  {

                    orderId: orderId,

                    processingMode:

                        processingMode,

                  },

              );


              response.status(200).send("OK");

              return;
            }


            // ==============================================

            // GARANTIR QUE O MÉTODO É PIX

            // ==============================================


            if (

              paymentMethodId !== "pix" ||

              paymentMethodType !==

                  "bank_transfer"

            ) {
              console.error(

                  "Order não corresponde a pagamento PIX.",

                  {

                    orderId: orderId,

                    paymentMethodId:

                        paymentMethodId || null,

                    paymentMethodType:

                        paymentMethodType || null,

                  },

              );


              response.status(200).send("OK");

              return;
            }


            // ==============================================

            // ORDER AINDA NÃO PAGA

            // ==============================================


            if (

              status !== "processed" ||

              statusDetail !== "accredited"

            ) {
              console.log(

                  "Order ainda não está paga.",

                  {

                    orderId: orderId,

                    status: status,

                    statusDetail:

                        statusDetail,

                    paymentStatus:

                        paymentStatus,

                    paymentStatusDetail:

                        paymentStatusDetail,

                  },

              );


              response.status(200).send("OK");

              return;
            }


            // ==============================================

            // STATUS DA TRANSAÇÃO

            // ==============================================


            if (

              paymentStatus &&

              paymentStatus !== "processed"

            ) {
              console.warn(

                  "Transação PIX ainda não processada.",

                  {

                    orderId: orderId,

                    paymentStatus:

                        paymentStatus,

                  },

              );


              response.status(200).send("OK");

              return;
            }


            const orderRef =

                db.collection("orders").doc(

                    externalReference,

                );


            try {
              await db.runTransaction(

                  async (transaction) => {
                    const snapshot =

                        await transaction.get(

                            orderRef,

                        );


                    if (!snapshot.exists) {
                      console.error(

                          "Pedido do Chamaê não encontrado.",

                          {

                            externalReference:

                                externalReference,

                            mercadoPagoOrderId:

                                orderId,

                          },

                      );

                      return;
                    }


                    const pedido =

                        snapshot.data() || {};


                    const orderIdSalvo =

                        pedido.mercadoPagoOrderId ?

                          pedido.mercadoPagoOrderId

                              .toString() :

                          "";


                    // ======================================

                    // VÍNCULO ENTRE ORDER E PEDIDO CHAMAÊ

                    // ======================================


                    if (

                      !orderIdSalvo ||

                      orderIdSalvo !== orderId

                    ) {
                      console.error(

                          "Order não corresponde ao pedido salvo.",

                          {

                            externalReference:

                                externalReference,

                            orderRecebida:

                                orderId,

                            orderSalva:

                                orderIdSalvo || null,

                          },

                      );

                      return;
                    }


                    // ======================================

                    // PAGAMENTO MISTO

                    //

                    // Por enquanto não marca o pedido inteiro

                    // como pago. Será tratado depois.

                    // ======================================


                    if (

                      pedido.splitPayment === true

                    ) {
                      console.warn(

                          "Pagamento misto não será confirmado " +

                          "como pagamento integral.",

                          {

                            externalReference:

                                externalReference,

                            mercadoPagoOrderId:

                                orderId,

                          },

                      );

                      return;
                    }


                    // ======================================

                    // VALOR ESPERADO

                    // ======================================


                    const financeiroSnapshot = await transaction.get(
                        db.collection("orderFinancials").doc(externalReference),
                    );
                    const financeiroSalvo = financeiroSnapshot.exists ?
                      financeiroSnapshot.data() : null;
                    if (financeiroSalvo) {
                      conferirItensFinanceiros(pedido, financeiroSalvo);
                    }

                    const valorCongelado =

                        Number(

                            pedido

                                .mercadoPagoAmountBRL,

                        );


                    // Cobranças antigas sem registro oficial mantêm o valor
                    // congelado para não reprecificar PIX já emitidos.
                    const valorEsperado = financeiroSalvo ?
                      financeiroSalvo.totalBRL : valorCongelado;


                    if (

                      !Number.isFinite(

                          valorEsperado,

                      ) ||

                      valorEsperado <= 0

                    ) {
                      console.error(

                          "Pedido possui valor inválido.",

                          {

                            externalReference:

                                externalReference,

                          },

                      );

                      return;
                    }


                    if (

                      !Number.isFinite(

                          totalAmount,

                      )

                    ) {
                      console.error(

                          "Order possui valor inválido.",

                          {

                            orderId: orderId,

                          },

                      );

                      return;
                    }


                    const centavosEsperados =

                        Math.round(

                            valorEsperado * 100,

                        );


                    const centavosRecebidos =

                        Math.round(

                            totalAmount * 100,

                        );


                    if (

                      centavosEsperados !==

                      centavosRecebidos

                    ) {
                      console.error(

                          "Valor da Order não corresponde " +

                          "ao pedido.",

                          {

                            externalReference:

                                externalReference,

                            esperado:

                                valorEsperado,

                            recebido:

                                totalAmount,

                          },

                      );

                      return;
                    }


                    // ======================================

                    // IDEMPOTÊNCIA

                    // ======================================

                    if (pedido.paymentStatus === "Pago") {
                      console.log(
                          "Pedido já estava pago. " +
                          "Webhook duplicado ignorado.",
                          {
                            externalReference: externalReference,
                            mercadoPagoOrderId: orderId,
                            stockProcessed:
                                pedido.stockProcessed === true,
                          },
                      );

                      return;
                    }

                    // ======================================

                    // ESTOQUE DO PIX INTEGRAL

                    // A confirmação do pagamento e a baixa de
                    // estoque acontecem na MESMA transação.
                    // Assim, um webhook repetido não baixa duas vezes.

                    // ======================================

                    const itens =
                        agruparItensEstoque(pedido.itemsList);

                    const itensValidados = [];
                    let estoquePodeSerProcessado = true;
                    let motivoRevisaoEstoque = null;

                    if (!itens || itens.length === 0) {
                      estoquePodeSerProcessado = false;
                      motivoRevisaoEstoque = itens ?
                        "PEDIDO_SEM_ITENS" : "ITEM_PEDIDO_INVALIDO";
                    }

                    for (const item of itens || []) {
                      const productId = item.id;
                      const quantity = item.quantity;

                      const productRef =
                          db.collection("products").doc(productId);

                      const productSnapshot =
                          await transaction.get(productRef);

                      if (!productSnapshot.exists) {
                        estoquePodeSerProcessado = false;
                        motivoRevisaoEstoque =
                            "PRODUTO_NAO_ENCONTRADO";
                        break;
                      }

                      const product =
                          productSnapshot.data() || {};

                      const stockAtual = Number(product.stock);
                      const reservadoAtual = Number(
                          product.reservedStock || 0,
                      );
                      const disponivelAtual =
                          stockAtual - reservadoAtual;

                      if (
                        !Number.isFinite(stockAtual) ||
                        !Number.isFinite(reservadoAtual) ||
                        reservadoAtual < 0 ||
                        disponivelAtual < quantity
                      ) {
                        estoquePodeSerProcessado = false;
                        motivoRevisaoEstoque =
                            "ESTOQUE_INSUFICIENTE";
                        break;
                      }

                      itensValidados.push({
                        ref: productRef,
                        quantity: quantity,
                      });
                    }

                    // ======================================

                    // CONFIRMAÇÃO DO PAGAMENTO

                    // ======================================

                    const atualizacao = {
                      ...(financeiroSalvo ?
                        camposFinanceirosPedido(pedido, financeiroSalvo) : {}),
                      paymentStatus: "Pago",

                      mercadoPagoOrderId: orderId,

                      mercadoPagoPaymentId:
                          pagamento.id || null,

                      mercadoPagoStatus: status,

                      mercadoPagoStatusDetail:
                          statusDetail,

                      mercadoPagoPaymentStatus:
                          paymentStatus,

                      mercadoPagoPaymentStatusDetail:
                          paymentStatusDetail,

                      mercadoPagoConfirmedAt:
                          FieldValue.serverTimestamp(),

                      paidAt:
                          FieldValue.serverTimestamp(),

                      paymentConfirmedBy:
                          origemValidacao,

                      updatedAt:
                          FieldValue.serverTimestamp(),

                      stockProcessed:
                          estoquePodeSerProcessado,

                      stockProcessingStatus:
                          estoquePodeSerProcessado ?
                            "processed" :
                            "requires_review",

                      stockProcessingError:
                          estoquePodeSerProcessado ?
                            null :
                            motivoRevisaoEstoque,
                    };

                    if (estoquePodeSerProcessado) {
                      atualizacao.stockProcessedAt =
                          FieldValue.serverTimestamp();

                      atualizacao.stockProcessedBy =
                          "mercado_pago_webhook";

                      for (const item of itensValidados) {
                        transaction.update(
                            item.ref,
                            {
                              stock: FieldValue.increment(
                                  -item.quantity,
                              ),
                              salesCount: FieldValue.increment(
                                  item.quantity,
                              ),
                            },
                        );
                      }

                      if (
                        pedido.status ===
                        "Aguardando pagamento"
                      ) {
                        atualizacao.status = "Novo";
                      }
                    } else {
                      console.error(
                          "PIX pago, mas estoque exige revisão.",
                          {
                            externalReference:
                                externalReference,
                            mercadoPagoOrderId:
                                orderId,
                            motivo:
                                motivoRevisaoEstoque,
                          },
                      );

                      if (
                        pedido.status ===
                        "Aguardando pagamento"
                      ) {
                        atualizacao.status =
                            "Revisão de estoque";
                      }
                    }

                    transaction.update(
                        orderRef,
                        atualizacao,
                    );

                    console.log(
                        "Pagamento PIX confirmado no Firestore.",
                        {
                          externalReference:
                              externalReference,
                          mercadoPagoOrderId:
                              orderId,
                          valorBRL:
                              valorEsperado,
                          origemValidacao:
                              origemValidacao,
                          stockProcessed:
                              estoquePodeSerProcessado,
                        },
                    );
                  },

              );
            } catch (error) {
              console.error(

                  "Erro na transação do Firestore.",

                  {

                    dataId: dataId,

                    erro: error.message,

                  },

              );


              response.status(500).send(

                  "Erro temporário",

              );

              return;
            }


            response.status(200).send("OK");
          };


      // ==================================================

      // VALIDAÇÃO OFICIAL DO WEBHOOK

      // ==================================================


      let assinaturaOficialValida = false;


      try {
        WebhookSignatureValidator.validate({

          xSignature: xSignature,

          xRequestId: xRequestId,

          dataId: dataId.toString(),

          secret:

              mercadoPagoWebhookSecret.value(),

        });


        assinaturaOficialValida = true;
      } catch (error) {
        if (

          error instanceof

              InvalidWebhookSignatureError

        ) {
          console.warn(

              "Webhook rejeitado pelo validador oficial.",

              {

                dataId: dataId,

                motivo:

                    error.reason ||

                    "SignatureMismatch",

              },

          );
        } else if (

          error instanceof RangeError &&

          error.code ===

              "ERR_CRYPTO_TIMING_SAFE_EQUAL_LENGTH"

        ) {
          console.warn(

              "Webhook com assinatura malformada.",

              {

                dataId: dataId,

              },

          );
        } else {
          console.error(

              "Erro inesperado ao validar webhook.",

              {

                dataId: dataId,

                erro: error.message,

              },

          );


          response.status(500).send(

              "Erro temporário",

          );

          return;
        }
      }


      // ==================================================

      // CAMINHO NORMAL

      // ASSINATURA OFICIAL VÁLIDA

      // ==================================================


      if (assinaturaOficialValida) {
        console.log(

            "Webhook Mercado Pago validado pelo SDK oficial.",

            {

              dataId: dataId,

              action: action,

              liveMode: liveMode,

            },

        );


        if (tipo !== "order") {
          response.status(200).send("OK");

          return;
        }


        await processarOrder(

            "mercado_pago_webhook",

        );

        return;
      }


      // ==================================================

      // FALLBACK CONTROLADO EXCLUSIVO DO SANDBOX

      //

      // IMPORTANTE:

      // O webhook NÃO confirma pagamento diretamente.

      //

      // Ele apenas permite a consulta autenticada da Order

      // na API oficial do Mercado Pago.

      //

      // Em produção real este fallback NÃO é aceito.

      // ==================================================


      const sandboxConhecido =

          liveMode === false &&

          tipo === "order" &&

          applicationId !== null &&

          String(applicationId) ===

              "1991368945375836" &&

          userId !== null &&

          String(userId) ===

              "3754565992" &&

          dataId

              .toString()

              .startsWith("ORDTST");


      if (!sandboxConhecido) {
        console.warn(

            "Webhook recusado. Fallback sandbox não aplicável.",

            {

              dataId: dataId,

              liveMode: liveMode,

              applicationId:

                  applicationId,

              userId: userId,

              tipo: tipo,

            },

        );


        response.status(401).send(

            "Assinatura inválida",

        );

        return;
      }


      console.warn(

          "Fallback seguro de sandbox ativado.",

          {

            dataId: dataId,

            applicationId:

                applicationId,

            userId: userId,

            action: action,

          },

      );


      await processarOrder(

          "mercado_pago_sandbox_verified_api",

      );
    },

);


// ======================================================

// FUNÇÃO 5 — CRIAR PIX VINCULADO AO FIRESTORE

// ======================================================


exports.chamaeCriarPix = onRequest(

    {

      region: "southamerica-east1",

      cors: false,


      // TEMPORARIAMENTE PUBLIC PARA TESTE CONTROLADO

      invoker: "public",


      secrets: [

        mercadoPagoToken,

        chamaePixTestKey,

      ],


      maxInstances: 5,

    },

    async (request, response) => {
      if (request.method !== "POST") {
        response.status(405).json({

          erro: "Método não permitido",

        });

        return;
      }


      const chaveRecebida =

          request.get("x-chamae-test-key");


      if (

        !chaveRecebida ||

        chaveRecebida !==

            chamaePixTestKey.value()

      ) {
        response.status(401).json({

          erro: "Não autorizado",

        });

        return;
      }


      const body =

          request.body || {};


      const orderDocumentId =

          typeof body.orderDocumentId === "string" ?

            body.orderDocumentId.trim() :

            "";


      if (!orderDocumentId) {
        response.status(400).json({

          erro:

              "orderDocumentId obrigatório",

        });

        return;
      }


      const orderRef =

          db.collection("orders").doc(

              orderDocumentId,

          );


      let valorBRL = 0;

      let idempotencyKey = "";


      try {
        await db.runTransaction(

            async (transaction) => {
              const snapshot =

                  await transaction.get(

                      orderRef,

                  );


              if (!snapshot.exists) {
                throw new Error(

                    "PEDIDO_NAO_ENCONTRADO",

                );
              }


              const pedido =

                  snapshot.data() || {};


              if (

                pedido.mercadoPagoOrderId

              ) {
                throw new Error(

                    "PIX_JA_CRIADO",

                );
              }


              const financeiro = await prepararFinanceiroPedido(
                  transaction, orderRef, pedido,
              );
              idempotencyKey = financeiro.dados.pixIdempotencyKey;
              valorBRL = financeiro.dados.totalBRL;

              if (financeiro.novo) {
                transaction.set(financeiro.ref, financeiro.dados);
              }

              transaction.update(orderRef, {
                ...camposFinanceirosPedido(pedido, financeiro.dados),
                mercadoPagoIdempotencyKey: idempotencyKey,
                mercadoPagoAmountBRL: valorBRL,
                mercadoPagoCreateStatus: "creating",
                mercadoPagoCreateStartedAt: FieldValue.serverTimestamp(),
              });
            },

        );
      } catch (error) {
        if (error.financeiro) {
          response.status(400).json({erro: error.message});
          return;
        }
        if (

          error.message ===

          "PEDIDO_NAO_ENCONTRADO"

        ) {
          response.status(404).json({

            erro:

                "Pedido não encontrado",

          });

          return;
        }


        if (

          error.message ===

          "PIX_JA_CRIADO"

        ) {
          response.status(409).json({

            erro:

                "Este pedido já possui PIX criado",

          });

          return;
        }


        if (

          error.message ===

          "VALOR_PEDIDO_INVALIDO"

        ) {
          response.status(400).json({

            erro:

                "Valor do pedido inválido",

          });

          return;
        }


        console.error(

            "Erro ao preparar criação do PIX:",

            error.message,

        );


        response.status(500).json({

          erro:

              "Falha ao preparar pagamento",

        });

        return;
      }


      const valorMercadoPago =

          valorBRL.toFixed(2);


      const externalReference =

          orderDocumentId;


      const pedidoMercadoPago = {

        type: "online",


        total_amount:

            valorMercadoPago,


        external_reference:

            externalReference,


        processing_mode:

            "automatic",


        transactions: {

          payments: [

            {

              amount:

                  valorMercadoPago,


              payment_method: {

                id: "pix",

                type:

                    "bank_transfer",

              },

            },

          ],

        },


        payer: {

          email:

              "test_user_br@testuser.com",


          first_name:

              "APRO",

        },

      };


      try {
        const resultado =

            await fetch(

                "https://api.mercadopago.com/v1/orders",

                {

                  method: "POST",


                  headers: {

                    "Authorization":

                        `Bearer ${mercadoPagoToken.value()}`,


                    "Content-Type":

                        "application/json",


                    "X-Idempotency-Key":

                        idempotencyKey,

                  },


                  body:

                      JSON.stringify(

                          pedidoMercadoPago,

                      ),


                  signal:

                      AbortSignal.timeout(

                          15000,

                      ),

                },

            );


        const dados =

            await resultado.json();


        if (!resultado.ok) {
          console.error(

              "Mercado Pago recusou criação do PIX:",

              resultado.status,

          );


          await orderRef.update({

            mercadoPagoCreateStatus:

                "error",


            mercadoPagoLastErrorHttp:

                resultado.status,


            mercadoPagoLastErrorAt:

                FieldValue.serverTimestamp(),

          });


          response.status(502).json({

            sucesso: false,


            erro:

                "Mercado Pago recusou " +

                "a criação do PIX",


            statusHttpMercadoPago:

                resultado.status,

          });

          return;
        }


        const pagamento =

            dados.transactions &&

            dados.transactions.payments &&

            dados.transactions.payments.length > 0 ?

              dados.transactions.payments[0] :

              {};


        const metodo =

            pagamento.payment_method ||

            {};


        await orderRef.update({

          externalReference:

              externalReference,


          mercadoPagoOrderId:

              dados.id || null,


          mercadoPagoPaymentId:

              pagamento.id || null,


          mercadoPagoStatus:

              dados.status || null,


          mercadoPagoStatusDetail:

              dados.status_detail || null,


          mercadoPagoPaymentStatus:

              pagamento.status || null,


          mercadoPagoAmountBRL:

              valorBRL,


          mercadoPagoCreateStatus:

              "created",


          mercadoPagoCreatedAt:

              FieldValue.serverTimestamp(),


          paymentStatus:

              "Aguardando confirmação",

        });


        response.status(200).json({

          sucesso: true,


          orderDocumentId:

              orderDocumentId,


          mercadoPagoOrderId:

              dados.id || null,


          orderStatus:

              dados.status || null,


          paymentId:

              pagamento.id || null,


          paymentStatus:

              pagamento.status || null,


          qrCode:

              metodo.qr_code || null,


          qrCodeBase64:

              metodo.qr_code_base64 ||

              null,


          ticketUrl:

              metodo.ticket_url || null,

        });
      } catch (error) {
        console.error(

            "Erro ao criar PIX vinculado ao pedido:",

            error.message,

        );


        response.status(502).json({

          sucesso: false,


          erro:

              "Falha de comunicação " +

              "com Mercado Pago",

        });
      }
    },

);

// ======================================================
// FUNÇÃO 6 — CRIAR PIX AUTOMATICAMENTE AO CRIAR PEDIDO
// ======================================================

exports.chamaeCriarPixAutomatico = onDocumentCreated(
    {
      document: "orders/{orderId}",
      region: "southamerica-east1",
      secrets: [mercadoPagoToken],
      maxInstances: 5,
    },
    async (event) => {
      const snapshot = event.data;

      if (!snapshot || !snapshot.exists) {
        console.warn(
            "Trigger PIX automático sem documento válido.",
        );
        return;
      }

      const orderRef = snapshot.ref;
      const orderDocumentId = event.params.orderId;
      const pedidoInicial = snapshot.data() || {};
      const paymentMethod =
          typeof pedidoInicial.paymentMethod === "string" ?
            pedidoInicial.paymentMethod.trim() :
            "";

      if (
        pedidoInicial.pixRequested !== true ||
        pedidoInicial.splitPayment === true ||
        paymentMethod !== "PIX"
      ) {
        console.log(
            "Pedido não exige geração automática de PIX.",
            {
              orderDocumentId: orderDocumentId,
              pixRequested: pedidoInicial.pixRequested === true,
              splitPayment: pedidoInicial.splitPayment === true,
              paymentMethod: paymentMethod || null,
            },
        );
        return;
      }

      let valorBRL = 0;
      let idempotencyKey = "";
      let deveCriarPix = true;

      try {
        await db.runTransaction(
            async (transaction) => {
              const atual = await transaction.get(orderRef);

              if (!atual.exists) {
                deveCriarPix = false;
                return;
              }

              const pedido = atual.data() || {};
              const metodoAtual =
                  typeof pedido.paymentMethod === "string" ?
                    pedido.paymentMethod.trim() :
                    "";

              if (
                pedido.pixRequested !== true ||
                pedido.splitPayment === true ||
                metodoAtual !== "PIX" ||
                pedido.paymentStatus === "Pago"
              ) {
                deveCriarPix = false;
                return;
              }

              if (pedido.mercadoPagoOrderId) {
                deveCriarPix = false;
                return;
              }

              const financeiro = await prepararFinanceiroPedido(
                  transaction, orderRef, pedido,
              );
              idempotencyKey = financeiro.dados.pixIdempotencyKey;
              valorBRL = financeiro.dados.totalBRL;

              if (financeiro.novo) {
                transaction.set(financeiro.ref, financeiro.dados);
              }

              transaction.update(
                  orderRef,
                  {
                    ...camposFinanceirosPedido(pedido, financeiro.dados),
                    mercadoPagoIdempotencyKey:
                        idempotencyKey,
                    mercadoPagoAmountBRL:
                        valorBRL,
                    mercadoPagoCreateStatus:
                        "creating",
                    mercadoPagoCreateStartedAt:
                        FieldValue.serverTimestamp(),
                    mercadoPagoCreateSource:
                        "firestore_order_trigger",
                  },
              );
            },
        );
      } catch (error) {
        console.error(
            "Erro ao preparar PIX automático.",
            {
              orderDocumentId: orderDocumentId,
              erro: error.message,
            },
        );

        try {
          await orderRef.update({
            mercadoPagoCreateStatus: "error",
            mercadoPagoLastErrorCode:
                error.financeiro ? error.message : "PREPARATION_ERROR",
            ...(error.financeiro ? {
              financialValidationStatus: "rejected",
              financialValidationError: error.message,
            } : {}),
            mercadoPagoLastErrorAt:
                FieldValue.serverTimestamp(),
          });
        } catch (updateError) {
          console.error(
              "Falha ao registrar erro do PIX automático.",
              {
                orderDocumentId: orderDocumentId,
                erro: updateError.message,
              },
          );
        }

        return;
      }

      if (!deveCriarPix) {
        console.log(
            "Criação automática de PIX ignorada por idempotência.",
            {
              orderDocumentId: orderDocumentId,
            },
        );
        return;
      }

      const valorMercadoPago =
          valorBRL.toFixed(2);

      const pedidoMercadoPago = {
        type: "online",
        total_amount: valorMercadoPago,
        external_reference: orderDocumentId,
        processing_mode: "automatic",
        transactions: {
          payments: [
            {
              amount: valorMercadoPago,
              payment_method: {
                id: "pix",
                type: "bank_transfer",
              },
            },
          ],
        },
        payer: {
          email: "test_user_br@testuser.com",
          first_name: "APRO",
        },
      };

      try {
        const resultado = await fetch(
            "https://api.mercadopago.com/v1/orders",
            {
              method: "POST",
              headers: {
                "Authorization":
                    `Bearer ${mercadoPagoToken.value()}`,
                "Content-Type": "application/json",
                "X-Idempotency-Key": idempotencyKey,
              },
              body: JSON.stringify(pedidoMercadoPago),
              signal: AbortSignal.timeout(15000),
            },
        );

        let dados;

        try {
          dados = await resultado.json();
        } catch (error) {
          console.error(
              "Resposta inválida ao criar PIX automático.",
              {
                orderDocumentId: orderDocumentId,
                statusHttp: resultado.status,
              },
          );

          await orderRef.update({
            mercadoPagoCreateStatus: "error",
            mercadoPagoLastErrorCode:
                "INVALID_API_RESPONSE",
            mercadoPagoLastErrorHttp:
                resultado.status,
            mercadoPagoLastErrorAt:
                FieldValue.serverTimestamp(),
          });
          return;
        }

        if (!resultado.ok) {
          console.error(
              "Mercado Pago recusou o PIX automático.",
              {
                orderDocumentId: orderDocumentId,
                statusHttp: resultado.status,
              },
          );

          await orderRef.update({
            mercadoPagoCreateStatus: "error",
            mercadoPagoLastErrorCode:
                "MERCADO_PAGO_REJECTED",
            mercadoPagoLastErrorHttp:
                resultado.status,
            mercadoPagoLastErrorAt:
                FieldValue.serverTimestamp(),
          });
          return;
        }

        const pagamento =
            dados.transactions &&
            dados.transactions.payments &&
            dados.transactions.payments.length > 0 ?
              dados.transactions.payments[0] :
              {};

        const metodo =
            pagamento.payment_method || {};

        const mercadoPagoOrderId =
            dados.id ? dados.id.toString() : "";

        const qrCode =
            typeof metodo.qr_code === "string" ?
              metodo.qr_code :
              "";

        const qrCodeBase64 =
            typeof metodo.qr_code_base64 === "string" ?
              metodo.qr_code_base64 :
              "";

        if (!mercadoPagoOrderId || !qrCode) {
          console.error(
              "PIX automático criado sem dados essenciais.",
              {
                orderDocumentId: orderDocumentId,
                possuiOrderId:
                    mercadoPagoOrderId.length > 0,
                possuiQrCode:
                    qrCode.length > 0,
              },
          );

          await orderRef.update({
            mercadoPagoCreateStatus: "error",
            mercadoPagoLastErrorCode:
                "MISSING_PIX_DATA",
            mercadoPagoLastErrorAt:
                FieldValue.serverTimestamp(),
          });
          return;
        }

        await orderRef.update({
          externalReference: orderDocumentId,
          mercadoPagoOrderId:
              mercadoPagoOrderId,
          mercadoPagoPaymentId:
              pagamento.id || null,
          mercadoPagoStatus:
              dados.status || null,
          mercadoPagoStatusDetail:
              dados.status_detail || null,
          mercadoPagoPaymentStatus:
              pagamento.status || null,
          mercadoPagoAmountBRL:
              valorBRL,
          mercadoPagoQrCode:
              qrCode,
          mercadoPagoQrCodeBase64:
              qrCodeBase64 || null,
          mercadoPagoTicketUrl:
              metodo.ticket_url || null,
          mercadoPagoCreateStatus:
              "created",
          mercadoPagoCreatedAt:
              FieldValue.serverTimestamp(),
          paymentStatus:
              "Aguardando confirmação",
          status:
              "Aguardando pagamento",
        });

        console.log(
            "PIX automático criado e salvo no Firestore.",
            {
              orderDocumentId: orderDocumentId,
              mercadoPagoOrderId:
                  mercadoPagoOrderId,
              valorBRL: valorBRL,
            },
        );
      } catch (error) {
        console.error(
            "Erro ao criar PIX automático.",
            {
              orderDocumentId: orderDocumentId,
              erro: error.message,
            },
        );

        try {
          await orderRef.update({
            mercadoPagoCreateStatus: "error",
            mercadoPagoLastErrorCode:
                "COMMUNICATION_ERROR",
            mercadoPagoLastErrorAt:
                FieldValue.serverTimestamp(),
          });
        } catch (updateError) {
          console.error(
              "Falha ao registrar erro de comunicação do PIX.",
              {
                orderDocumentId: orderDocumentId,
                erro: updateError.message,
              },
          );
        }
      }
    },
);


// ======================================================
// FUNÇÃO 7 — RESERVAR ESTOQUE PARA PAGAMENTO NA ENTREGA
// ======================================================

exports.chamaeReservarEstoquePagamentoEntrega = onDocumentCreated(
    {
      document: "orders/{orderId}",
      region: "southamerica-east1",
      maxInstances: 10,
    },
    async (event) => {
      const snapshot = event.data;

      if (!snapshot || !snapshot.exists) {
        return;
      }

      const orderRef = snapshot.ref;
      const orderId = event.params.orderId;
      const pedidoInicial = snapshot.data() || {};
      const metodo =
          typeof pedidoInicial.paymentMethod === "string" ?
            pedidoInicial.paymentMethod.trim() :
            "";

      const metodosComReserva = new Set([
        "Dinheiro",
        "Maquininha",
        "Maquininha - Débito à vista",
        "Maquininha - Crédito à vista",
        "Pagamento dividido",
      ]);

      if (
        pedidoInicial.pixRequested === true ||
        !metodosComReserva.has(metodo)
      ) {
        return;
      }

      // Pagamento dividido do lançamento: somente dinheiro.
      if (pedidoInicial.splitPayment === true) {
        const partes =
            Array.isArray(pedidoInicial.paymentParts) ?
              pedidoInicial.paymentParts :
              [];

        if (
          partes.length === 0 ||
          partes.some((parte) => parte.method !== "Dinheiro")
        ) {
          await orderRef.update({
            stockReservationStatus: "requires_review",
            stockReservationError: "SPLIT_PAYMENT_INVALIDO",
            status: "Revisão de estoque",
            updatedAt: FieldValue.serverTimestamp(),
          });
          return;
        }
      }

      try {
        await db.runTransaction(
            async (transaction) => {
              const atual = await transaction.get(orderRef);

              if (!atual.exists) {
                return;
              }

              const pedido = atual.data() || {};

              if (
                pedido.stockReservationStatus === "reserved" ||
                pedido.stockReservationStatus === "finalized" ||
                pedido.stockReservationStatus === "released"
              ) {
                return;
              }

              const itens =
                  agruparItensEstoque(pedido.itemsList);

              if (!itens || itens.length === 0) {
                transaction.update(orderRef, {
                  stockReservationStatus: "requires_review",
                  stockReservationError: itens ?
                    "PEDIDO_SEM_ITENS" : "ITEM_PEDIDO_INVALIDO",
                  status: "Revisão de estoque",
                  updatedAt: FieldValue.serverTimestamp(),
                });
                return;
              }

              const financeiro = await prepararFinanceiroPedido(
                  transaction, orderRef, pedido,
              );
              validarPagamentoEntrega(pedido, financeiro.dados);

              const itensValidados = [];
              let erro = null;

              for (const item of itens) {
                const productId = item.id;
                const quantity = item.quantity;

                const productRef =
                    db.collection("products").doc(productId);
                const productSnapshot =
                    await transaction.get(productRef);

                if (!productSnapshot.exists) {
                  erro = "PRODUTO_NAO_ENCONTRADO";
                  break;
                }

                const product = productSnapshot.data() || {};
                const stockAtual = Number(product.stock);
                const reservadoAtual = Number(
                    product.reservedStock || 0,
                );
                const disponivelAtual =
                    stockAtual - reservadoAtual;

                if (
                  !Number.isFinite(stockAtual) ||
                  !Number.isFinite(reservadoAtual) ||
                  reservadoAtual < 0 ||
                  disponivelAtual < quantity
                ) {
                  erro = "ESTOQUE_INSUFICIENTE";
                  break;
                }

                itensValidados.push({
                  ref: productRef,
                  quantity: quantity,
                });
              }

              if (erro) {
                transaction.update(orderRef, {
                  stockReservationStatus: "requires_review",
                  stockReservationError: erro,
                  status: "Revisão de estoque",
                  updatedAt: FieldValue.serverTimestamp(),
                });
                return;
              }

              if (financeiro.novo) {
                transaction.set(financeiro.ref, financeiro.dados);
              }

              for (const item of itensValidados) {
                transaction.update(
                    item.ref,
                    {
                      reservedStock: FieldValue.increment(
                          item.quantity,
                      ),
                    },
                );
              }

              transaction.update(orderRef, {
                ...camposFinanceirosPedido(pedido, financeiro.dados),
                stockReservationRequired: true,
                stockReservationStatus: "reserved",
                stockReservationError: null,
                stockReservedAt: FieldValue.serverTimestamp(),
                stockReservedBy: "firestore_order_trigger",
                updatedAt: FieldValue.serverTimestamp(),
              });

              console.log(
                  "Estoque reservado para pagamento na entrega.",
                  {
                    orderId: orderId,
                    paymentMethod: metodo,
                  },
              );
            },
        );
      } catch (error) {
        console.error(
            "Erro ao reservar estoque.",
            {
              orderId: orderId,
              erro: error.message,
            },
        );

        try {
          await orderRef.update({
            ...(error.financeiro ? {
              financialValidationStatus: "rejected",
              financialValidationError: error.message,
              status: "Revisão financeira",
            } : {
              stockReservationStatus: "error",
              stockReservationError: "RESERVATION_TRANSACTION_ERROR",
            }),
            stockReservationLastErrorAt:
                FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          });
        } catch (updateError) {
          console.error(
              "Falha ao registrar erro da reserva de estoque.",
              {
                orderId: orderId,
                erro: updateError.message,
              },
          );
        }
      }
    },
);


// ======================================================
// FUNÇÃO 8 — FINALIZAR OU LIBERAR RESERVA DE ESTOQUE
// ======================================================

exports.chamaeResolverReservaEstoque = onDocumentUpdated(
    {
      document: "orders/{orderId}",
      region: "southamerica-east1",
      maxInstances: 10,
    },
    async (event) => {
      const afterSnapshot = event.data && event.data.after;

      if (
        !afterSnapshot ||
        !afterSnapshot.exists
      ) {
        return;
      }

      const depois = afterSnapshot.data() || {};

      if (depois.stockReservationStatus !== "reserved") {
        return;
      }

      const orderRef = afterSnapshot.ref;
      const orderId = event.params.orderId;

      try {
        await db.runTransaction(
            async (transaction) => {
              const atual = await transaction.get(orderRef);

              if (!atual.exists) {
                return;
              }

              const pedido = atual.data() || {};

              if (pedido.stockReservationStatus !== "reserved") {
                return;
              }

              // Decide pelo estado atual, inclusive em retries da transação.
              const status =
                  typeof pedido.status === "string" ?
                    pedido.status.trim() :
                    "";
              const deveLiberar =
                  status.toLowerCase().includes("cancel");

              // "Concluído" continua significando entrega e pagamento recebido.
              const deveFinalizar = !deveLiberar && (
                status === "Concluído" || pedido.paymentStatus === "Pago"
              );

              if (!deveLiberar && !deveFinalizar) {
                return;
              }

              const financeiroSnapshot = await transaction.get(
                  db.collection("orderFinancials").doc(orderId),
              );
              const financeiroSalvo = financeiroSnapshot.exists ?
                financeiroSnapshot.data() : null;
              if (financeiroSalvo && deveFinalizar) {
                conferirItensFinanceiros(pedido, financeiroSalvo);
              }

              const itens =
                  agruparItensEstoque(pedido.itemsList);

              if (!itens || itens.length === 0) {
                transaction.update(orderRef, {
                  stockReservationStatus: "requires_review",
                  stockReservationError: itens ?
                    "PEDIDO_SEM_ITENS" : "ITEM_PEDIDO_INVALIDO",
                  updatedAt: FieldValue.serverTimestamp(),
                });
                return;
              }

              const itensValidados = [];
              let erro = null;

              for (const item of itens) {
                const productId = item.id;
                const quantity = item.quantity;

                const productRef =
                    db.collection("products").doc(productId);
                const productSnapshot =
                    await transaction.get(productRef);

                if (!productSnapshot.exists) {
                  erro = "PRODUTO_NAO_ENCONTRADO";
                  break;
                }

                const product = productSnapshot.data() || {};
                const stockAtual = Number(product.stock);
                const reservadoAtual = Number(
                    product.reservedStock || 0,
                );

                if (
                  !Number.isFinite(stockAtual) ||
                  !Number.isFinite(reservadoAtual) ||
                  reservadoAtual < quantity
                ) {
                  erro = "RESERVA_INCONSISTENTE";
                  break;
                }

                if (
                  deveFinalizar &&
                  stockAtual < quantity
                ) {
                  erro = "ESTOQUE_INSUFICIENTE_NA_FINALIZACAO";
                  break;
                }

                itensValidados.push({
                  ref: productRef,
                  quantity: quantity,
                  stockAtual: stockAtual,
                  reservadoAtual: reservadoAtual,
                });
              }

              if (erro) {
                transaction.update(orderRef, {
                  stockReservationStatus: "requires_review",
                  stockReservationError: erro,
                  status: "Revisão de estoque",
                  updatedAt: FieldValue.serverTimestamp(),
                });
                return;
              }

              for (const item of itensValidados) {
                if (deveLiberar) {
                  transaction.update(
                      item.ref,
                      {
                        reservedStock:
                            item.reservadoAtual -
                            item.quantity,
                      },
                  );
                } else {
                  transaction.update(
                      item.ref,
                      {
                        stock:
                            item.stockAtual -
                            item.quantity,
                        reservedStock:
                            item.reservadoAtual -
                            item.quantity,
                        salesCount:
                            FieldValue.increment(
                                item.quantity,
                            ),
                      },
                  );
                }
              }

              if (deveLiberar) {
                transaction.update(orderRef, {
                  stockReservationStatus: "released",
                  stockReservationError: null,
                  stockReleasedAt:
                      FieldValue.serverTimestamp(),
                  stockReleasedBy:
                      "order_status_cancelled",
                  updatedAt:
                      FieldValue.serverTimestamp(),
                });

                console.log(
                    "Reserva de estoque liberada.",
                    {
                      orderId: orderId,
                    },
                );
                return;
              }

              const atualizacao = {
                ...(financeiroSalvo ?
                  camposFinanceirosPedido(pedido, financeiroSalvo) : {}),
                stockReservationStatus: "finalized",
                stockReservationError: null,
                stockFinalized: true,
                stockFinalizedAt:
                    FieldValue.serverTimestamp(),
                stockFinalizedBy:
                    "order_delivery_completed",
                stockProcessed: true,
                stockProcessedAt:
                    FieldValue.serverTimestamp(),
                stockProcessedBy:
                    "stock_reservation_finalizer",
                updatedAt:
                    FieldValue.serverTimestamp(),
              };

              if (pedido.paymentStatus !== "Pago") {
                atualizacao.paymentStatus = "Pago";
                atualizacao.paidAt =
                    FieldValue.serverTimestamp();
                atualizacao.paymentConfirmedBy =
                    "delivery_completion";
              }

              transaction.update(
                  orderRef,
                  atualizacao,
              );

              console.log(
                  "Reserva de estoque finalizada.",
                  {
                    orderId: orderId,
                  },
              );
            },
        );
      } catch (error) {
        console.error(
            "Erro ao resolver reserva de estoque.",
            {
              orderId: orderId,
              erro: error.message,
            },
        );
      }
    },
);
