'use strict';
const POLICY_VERSION='launch-v1.0-customer-fee-suspended';
function launchAmounts(subtotalCentavos,deliveryFeeCentavos){
 if(!Number.isSafeInteger(subtotalCentavos)||subtotalCentavos<0||!Number.isSafeInteger(deliveryFeeCentavos)||deliveryFeeCentavos<0||!Number.isSafeInteger(subtotalCentavos+deliveryFeeCentavos)||subtotalCentavos+deliveryFeeCentavos<=0)throw Error('VALOR_PEDIDO_INVALIDO');
 return {customerFeeCentavos:0,merchantFeeCentavos:0,totalCentavos:subtotalCentavos+deliveryFeeCentavos,financialPolicySnapshot:{version:POLICY_VERSION,customerFeeBps:0,appliedMerchantCommissionBps:0,futureMerchantCommissionBps:300,merchantCommissionStatus:'pending_formalization',loumakTransfersEnabled:false,sellerCnpj:'41.952.465/0001-20',paymentRecipient:'Pit Stop V8'}};
}
function assertLaunchDeclaration(pedido,amounts){
 if(!pedido||pedido.customerFee!==0||pedido.merchantFee!==0||pedido.platformFee!==0||typeof pedido.totalBRL!=='number'||!Number.isFinite(pedido.totalBRL)||Math.abs(pedido.totalBRL*100-amounts.totalCentavos)>0.000001)throw Error('FINANCIAL_POLICY_RECONFIRMATION_REQUIRED');
}
module.exports={POLICY_VERSION,launchAmounts,assertLaunchDeclaration};
