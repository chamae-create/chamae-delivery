import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat, DateFormat;

import 'generated/app_localizations.dart';
import 'locale_controller.dart';
export 'generated/app_localizations.dart';

extension CustomerLocalizations on BuildContext {
  AppLocalizations get l10n =>
      AppLocalizations.of(this) ??
      lookupAppLocalizations(
        LocaleController.resolve(Localizations.maybeLocaleOf(this)),
      );
}

class LocaleScope extends InheritedNotifier<LocaleController> {
  const LocaleScope({
    super.key,
    required LocaleController controller,
    required super.child,
  }) : super(notifier: controller);
  static LocaleController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LocaleScope>()!.notifier!;
}

class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LocaleScope>();
    if (scope == null) return const SizedBox.shrink();
    final controller = scope.notifier!;
    return DropdownButton<String>(
      isDense: compact,
      selectedItemBuilder: compact
          ? (_) => const [
                Icon(Icons.language, semanticLabel: 'Português'),
                Icon(Icons.language, semanticLabel: 'Español'),
              ]
          : null,
      value: Localizations.localeOf(context).languageCode == 'es'
          ? 'es-PY'
          : 'pt-BR',
      underline: const SizedBox.shrink(),
      items: const [
        DropdownMenuItem(value: 'pt-BR', child: Text('Português')),
        DropdownMenuItem(value: 'es-PY', child: Text('Español')),
      ],
      onChanged: (value) async {
        if (value != null) {
          try {
            await controller.set(value);
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.l10n.languageSaveFailed)),
              );
            }
          }
        }
      },
    );
  }
}

String localizedLabel(BuildContext context, String value) {
  if (Localizations.localeOf(context).languageCode == 'es') {
    const visualLabels = <String, String>{
      'Categorias': 'Categorías',
      'Águas': 'Aguas',
      'Remover': 'Eliminar',
      'Encontre o que precisa no nosso catálogo.':
          'Encuentra lo que necesitas en nuestro catálogo.',
      'Buscar categorias...': 'Buscar categorías...',
      'Esta conta não está autorizada a calcular a entrega. Contate o suporte.':
          'Esta cuenta no está autorizada para cotizar el envío. Contacta con soporte.',
      'Entre novamente na sua conta para calcular a entrega.':
          'Vuelve a iniciar sesión para cotizar el envío.',
      'Limite de cotações atingido. Aguarde antes de tentar novamente.':
          'Se alcanzó el límite de cotizaciones. Espera antes de volver a intentarlo.',
      'A entrega está indisponível no momento. Tente novamente ou contate o suporte.':
          'El envío no está disponible en este momento. Inténtalo de nuevo o contacta con soporte.',
      'Não foi possível calcular a entrega agora. Confira sua conexão e tente novamente.':
          'No se pudo cotizar el envío. Comprueba tu conexión e inténtalo de nuevo.',
      'Delivery todos os dias • 08h às 00h':
          'Delivery todos los días • 08h a 00h',
      'Delivery todos os dias • 08h às 00h\nLoja fechada • abre às 08:00 (MS)':
          'Delivery todos los días • 08h a 00h\nTienda cerrada • abre a las 08:00 (MS)',
      'Confira seus itens antes de finalizar.':
          'Revisa tus productos antes de finalizar.',
      'Confira seus dados e escolha a forma de pagamento.':
          'Revisa tus datos y elige la forma de pago.',
      'Confira as etapas da sua entrega.': 'Consulta las etapas de tu entrega.',
      'Dados para entrega': 'Datos para la entrega',
      'Endereço de entrega': 'Dirección de entrega',
      'Últimos pedidos': 'Últimos pedidos',
      'Histórico da sua conta': 'Historial de tu cuenta',
      'Consulte seus pedidos e acompanhe os detalhes.':
          'Consulta tus pedidos y sigue los detalles.',
      'Pagamento seguro': 'Pago seguro',
      'Seus dados protegidos': 'Tus datos protegidos',
      'Finalizar Pedido': 'Finalizar pedido',
      'Concluída': 'Completada',
      'Etapa atual': 'Etapa actual',
      'Aguardando': 'En espera',
      'Atualizar': 'Actualizar',
      'Acompanhe as etapas por aqui. A localização do entregador ao vivo ainda não está disponível.':
          'Sigue las etapas aquí. La ubicación en vivo del repartidor todavía no está disponible.',
    };
    final translated = visualLabels[value];
    if (translated != null) return translated;
  }

  final l = context.l10n;
  return switch (value) {
    'Voltar' => l.ui0,
    'Continuar' => l.ui1,
    'Registrando…' => l.ui2,
    'Sair' => l.ui3,
    'Cancelar' => l.ui4,
    'Salvar' => l.ui5,
    'Excluir' => l.ui6,
    'Editar' => l.ui7,
    'Confirmar' => l.ui8,
    'Carregando…' => l.ui9,
    'Conta já existente' => l.ui10,
    'Trocar de conta' => l.ui11,
    'Não foi possível entrar agora. Confira a conexão e tente novamente.' =>
      l.ui12,
    'Chamaê Delivery. Bebidas e conveniência.' => l.ui13,
    'Bem-vindo ao Chamaê' => l.ui14,
    'Bebidas e conveniência, do seu jeito. Entre para encontrar seus endereços e acompanhar seus pedidos.' =>
      l.ui15,
    'Continuar com Apple' => l.ui16,
    'Continuar com Google' => l.ui17,
    'Esqueceu a senha ou perdeu o acesso?' => l.ui18,
    'O acesso aguarda a configuração dos provedores neste ambiente.' => l.ui19,
    'Entrada por telefone em preparação.' => l.ui20,
    'Seus dados ficam vinculados à sua conta. Você poderá conferir os documentos e as informações de privacidade antes de continuar.' =>
      l.ui21,
    'Política de Privacidade' => l.ui22,
    'Termos de Uso' => l.ui23,
    'Informe uma data de nascimento válida e confira os três aceites.' =>
      l.ui24,
    'Não foi possível registrar o aceite. Confira a conexão e tente novamente. Se os documentos mudaram, atualize esta etapa.' =>
      l.ui25,
    'Vamos começar' => l.ui26,
    'AMBIENTE DE DESENVOLVIMENTO — documentos jurídicos ainda não são os oficiais.' =>
      l.ui27,
    'A passagem vale somente nesta sessão de homologação e não registra aceite jurídico oficial.' =>
      l.ui28,
    'Uma experiência feita para você' => l.ui29,
    'Precisamos da sua data de nascimento e da confirmação dos documentos para continuar.' =>
      l.ui30,
    'Data de nascimento' => l.ui31,
    'A data informada não comprova sua identidade. Conforme o produto e o destino, um documento poderá ser solicitado no recebimento.' =>
      l.ui32,
    'Li e aceito os Termos de Uso' => l.ui33,
    'Li e estou ciente da Política de Privacidade' => l.ui34,
    'Estou ciente das regras para bebidas alcoólicas' => l.ui35,
    'Documentos DRAFT de desenvolvimento. O primeiro acesso será liberado quando os documentos oficiais estiverem disponíveis.' =>
      l.ui36,
    'Atualizar documentos' => l.ui37,
    'Sair da conta' => l.ui38,
    'Sair da conta?' => l.ui39,
    'Seus pedidos e seu carrinho continuarão vinculados a esta conta.' =>
      l.ui40,
    'Não foi possível sair agora. Tente novamente.' => l.ui41,
    'Não foi possível vincular essa identidade. Use uma conta que ainda não esteja vinculada a outro perfil.' =>
      l.ui42,
    'Seu perfil' => l.ui43,
    'Seu perfil Chamaê' => l.ui44,
    'Minha conta' => l.ui45,
    'Buscando os dados da sua conta' => l.ui46,
    'Seu perfil já vai aparecer por aqui.' => l.ui47,
    'Método de login' => l.ui48,
    'Conta vinculada' => l.ui49,
    'Conta Chamaê' => l.ui50,
    'Não foi possível atualizar seu perfil.' => l.ui51,
    'Confira sua conexão e tente novamente. Seus dados não foram apagados.' =>
      l.ui52,
    'Conferir documentos atualizados' => l.ui53,
    'Endereço de entrega' => l.ui54,
    'Selecione o endereço na tela inicial' => l.ui55,
    'Meus pedidos' => l.ui56,
    'Vincular Google à conta' => l.ui57,
    'Vincular Apple à conta' => l.ui58,
    'Excluir minha conta' => l.ui59,
    'Conecte-se para ver seus pedidos.' => l.ui60,
    'Seus pedidos aparecerão aqui.' => l.ui61,
    'Carregar mais pedidos' => l.ui62,
    'Não foi possível carregar os pedidos.' => l.ui63,
    'Tentar novamente' => l.ui64,
    'Pedido recebido' => l.ui65,
    'Novo' => l.ui66,
    'Em Separação' => l.ui67,
    'Em separação' => l.ui68,
    'Aguardando Retirada' => l.ui69,
    'Aguardando retirada' => l.ui70,
    'Saiu para Entrega' => l.ui71,
    'Saiu para entrega' => l.ui72,
    'Concluído' => l.ui73,
    'Pedido cancelado' => l.ui74,
    'Aguardando pagamento' => l.ui75,
    'Atualizando pedido' => l.ui76,
    'Sua conta foi excluída.' => l.ui77,
    'Conta excluída' => l.ui78,
    'Você no controle da sua conta' => l.ui79,
    'Confira o que acontece antes de continuar.' => l.ui80,
    'Entendi que a exclusão é definitiva.' => l.ui81,
    'Confirmando sua identidade…' => l.ui82,
    'Confirmar identidade e excluir' => l.ui83,
    'Verificar status' => l.ui84,
    'Exclusão em andamento' => l.ui85,
    'Revogação Apple pendente' => l.ui86,
    'Resolva seu pedido antes de continuar' => l.ui87,
    'A exclusão não foi concluída. Há um pedido ou pagamento que precisa de atenção.' =>
      l.ui88,
    'A exclusão foi concluída. Sua sessão será encerrada.' => l.ui89,
    'Sua conta foi excluída. Feche e abra o aplicativo para encerrar a sessão neste aparelho.' =>
      l.ui90,
    'Recuperar acesso' => l.ui91,
    'Esqueceu a senha?' => l.ui92,
    'Conta Google' => l.ui93,
    'Conta Apple' => l.ui94,
    'Copiar endereço Google' => l.ui95,
    'Copiar endereço Apple' => l.ui96,
    'Voltar e entrar com Google' => l.ui97,
    'Voltar e entrar com Apple' => l.ui98,
    'Não salvar' => l.ui99,
    'Excluir endereço salvo?' => l.ui100,
    'Onde vamos entregar?' => l.ui101,
    'Escolha o destino. A localização do telefone pode ser diferente do local da entrega.' =>
      l.ui102,
    'Usar minha localização' => l.ui103,
    'Digitar endereço' => l.ui104,
    'Reutilizar último destino' => l.ui105,
    'Endereço' => l.ui106,
    'Opções do endereço' => l.ui107,
    'Editar endereço' => l.ui108,
    'Definir como padrão' => l.ui109,
    'Excluir endereço' => l.ui110,
    'Explorar catálogo sem endereço' => l.ui111,
    'Defina seu endereço para calcular entrega. Você pode explorar o catálogo antes disso.' =>
      l.ui112,
    'Número' => l.ui113,
    'Sem número' => l.ui114,
    'Confirmar no mapa' => l.ui115,
    'Confira o endereço' => l.ui116,
    'A entrega segue o ponto confirmado no mapa. Confira os dados para ajudar o entregador.' =>
      l.ui117,
    'Não foi possível identificar o país. Esta entrega é no Brasil ou Paraguai?' =>
      l.ui118,
    'Destino: Brasil' => l.ui119,
    'Destino: Paraguai' => l.ui120,
    'Destino fora da área atendida' => l.ui121,
    'Ponto de referência' => l.ui122,
    'Salvar endereço como' => l.ui123,
    'Confirmar destino' => l.ui124,
    'Localizando endereço...' => l.ui125,
    'Ajuste o marcador para o local exato da entrega' => l.ui126,
    'Não foi possível obter sua localização. Digite o endereço ou ajuste o ponto no mapa.' =>
      l.ui127,
    'Endereço não identificado' => l.ui128,
    'Local de entrega' => l.ui129,
    'Buscar endereço e número' => l.ui130,
    'Buscar endereço' => l.ui131,
    'Localizando você...' => l.ui132,
    'Arraste o mapa' => l.ui133,
    'Arraste o mapa até o pino ficar exatamente sobre o local da entrega.' =>
      l.ui134,
    'Complemento / referência (opcional)' => l.ui135,
    'Referência (opcional)' => l.ui136,
    'Confirmar localização' => l.ui137,
    'Seu carrinho' => l.ui138,
    'Seu carrinho está vazio.' => l.ui139,
    'Escolha suas bebidas e conveniência.' => l.ui140,
    'Confira seu pedido' => l.ui141,
    'Revise seus itens antes de continuar.' => l.ui142,
    'Resumo do pedido' => l.ui143,
    'Taxa de serviço' => l.ui144,
    'Produtos e serviço' => l.ui145,
    'A calcular após confirmar o endereço' => l.ui146,
    'Continuar para entrega' => l.ui147,
    'O total será conferido ao confirmar o pedido.' => l.ui148,
    'Diminuir quantidade' => l.ui149,
    'Aumentar quantidade' => l.ui150,
    'Cotacao expirada. Calcule a entrega novamente.' => l.ui151,
    'Cotacao expirada. O pedido nao foi enviado.' => l.ui152,
    'Não foi possível calcular a entrega agora. Tente novamente.' => l.ui153,
    'Adicionar pagamento em dinheiro' => l.ui154,
    'Pagamento dividido disponível somente em dinheiro.' => l.ui155,
    'Restará pagar' => l.ui156,
    'Pendente na entrega' => l.ui157,
    'Crédito' => l.ui158,
    'Crédito à vista' => l.ui159,
    'Débito' => l.ui160,
    'Aguardando confirmação' => l.ui161,
    'Pagamento dividido' => l.ui162,
    'Esta entrega é no Brasil ou Paraguai?' => l.ui163,
    'Confirme o destino da entrega antes de continuar.' => l.ui164,
    'Confirme o país do endereço para continuar.' => l.ui165,
    'Informe seu nome para continuar.' => l.ui166,
    'Informe um WhatsApp válido com DDD.' => l.ui167,
    'Sua sessão mudou. Reabra o checkout.' => l.ui168,
    'Sua sessão mudou.' => l.ui169,
    'Verifique sua conta para concluir a compra.' => l.ui170,
    'Confira sua elegibilidade e os documentos para continuar.' => l.ui171,
    'Um produto da sacola não está disponível para sua faixa etária neste destino.' =>
      l.ui172,
    'Seu pedido' => l.ui173,
    'Seu pedido foi iniciado. Confira a confirmação para continuar.' => l.ui174,
    'Retomar PIX' => l.ui175,
    'Verificar pedido' => l.ui176,
    'Revisar sacola antes de enviar' => l.ui177,
    'Finalizar Pedido' => l.ui178,
    'Conferindo os detalhes do seu pedido' => l.ui179,
    'Aguarde por aqui. Seu carrinho continua guardado.' => l.ui180,
    'Confira os detalhes' => l.ui181,
    'Seu endereço, seus itens e a forma de pagamento.' => l.ui182,
    'Atualizar sessão' => l.ui183,
    'Confirmar país da entrega' => l.ui184,
    'Entregar em' => l.ui185,
    'Endereço selecionado' => l.ui186,
    'Nome para a entrega' => l.ui187,
    'Editar nome' => l.ui188,
    'Seu Nome *' => l.ui189,
    'Contato para a entrega' => l.ui190,
    'Editar contato' => l.ui191,
    'Telefone / WhatsApp *' => l.ui192,
    'Valores em Real' => l.ui193,
    'Valores em Guarani' => l.ui194,
    'Valores em Dólar' => l.ui195,
    'Valor que será entregue' => l.ui196,
    'Valor insuficiente para este pedido.' => l.ui197,
    'Taxa de Entrega' => l.ui198,
    'Aguardando cotação' => l.ui199,
    'Aguardando entrega' => l.ui200,
    'Dividir pagamento' => l.ui201,
    'Somente dinheiro • até 3 partes' => l.ui202,
    'Forma de pagamento' => l.ui203,
    'Cartão na entrega' => l.ui204,
    'Dinheiro' => l.ui205,
    'Adicione pelo menos 2 partes do pagamento.' => l.ui206,
    'Ainda existe valor restante no pagamento.' => l.ui207,
    'PIX e maquininha não podem gerar troco. Ajuste os valores.' => l.ui208,
    'Informe com quanto você vai pagar.' => l.ui209,
    'O valor informado é menor que o total do pedido.' => l.ui210,
    'Pagamento dividido aceita somente dinheiro.' => l.ui211,
    'Finalizar pedido' => l.ui212,
    'Acompanhar pedido' => l.ui213,
    'Não foi possível acompanhar o pedido.' => l.ui214,
    'Buscando seu pedido' => l.ui215,
    'Só um instante para conferir as novidades.' => l.ui216,
    'Revisão financeira' => l.ui217,
    'Revisão de estoque' => l.ui218,
    'Aguardando atribuição' => l.ui219,
    'Entregador não informado' => l.ui220,
    'Endereço não informado' => l.ui221,
    'Vamos conferir seu pedido' => l.ui222,
    'Conferindo seu pedido' => l.ui223,
    'Seu pedido precisa de atenção' => l.ui224,
    'Estamos conferindo os detalhes' => l.ui225,
    'Aguarde a confirmação por aqui antes de fazer outro pedido.' => l.ui226,
    'Ver pagamento PIX' => l.ui227,
    'Total em confirmação' => l.ui228,
    'concluída' => l.ui229,
    'etapa atual' => l.ui230,
    'Acompanhe as etapas por aqui. A localização do entregador ao vivo ainda não está disponível.' =>
      l.ui231,
    'Disponível' => l.ui232,
    'Indisponível no momento' => l.ui233,
    'Ajuste a quantidade ao estoque disponível.' => l.ui234,
    'Adicionado ao carrinho.' => l.ui235,
    'Adicionar ao carrinho' => l.ui236,
    'Indisponível' => l.ui237,
    'Sua sacola está vazia.' => l.ui238,
    'Selecionar endereço de entrega' => l.ui239,
    'Escolha seu endereço' => l.ui240,
    'Buscar produtos' => l.ui241,
    'Moeda de exibição' => l.ui242,
    'Real (BRL)' => l.ui243,
    'Guarani (PYG)' => l.ui244,
    'Dólar (USD)' => l.ui245,
    'Nenhuma categoria disponível.' => l.ui246,
    'Nenhum produto encontrado.' => l.ui247,
    'Ofertas do Dia' => l.ui248,
    'Combos Festa' => l.ui249,
    'Resultados da busca' => l.ui250,
    'Ver todos' => l.ui251,
    'Promoções do dia' => l.ui252,
    'Ver todas' => l.ui253,
    'Mais pedidos' => l.ui254,
    'Compre por categoria' => l.ui255,
    'Todos os produtos' => l.ui256,
    'Buscar bebidas e conveniência' => l.ui257,
    'Início' => l.ui258,
    'Não foi possível carregar os produtos.' => l.ui259,
    'Subtotal' => l.ui260,
    'Total' => l.ui261,
    'Frete' => l.ui262,
    'Pedido' => l.ui263,
    'Pedidos' => l.ui264,
    'Suporte' => l.ui265,
    'Falar com a loja' => l.ui266,
    'Cotação expirada' => l.ui267,
    'Calcular entrega' => l.ui268,
    'Atualizar cotação' => l.ui269,
    'A entrada no Chamaê usa sua conta Google ou Apple. Recupere a senha diretamente no provedor; o Chamaê não recebe nem altera essa senha.' =>
      l.extra0,
    'Depois, volte e entre com a mesma conta usada no cadastro para recuperar seus pedidos e endereços. Criar outra conta não transfere esses dados.' =>
      l.extra1,
    'A recuperação e seus prazos dependem do provedor. Nenhuma senha foi redefinida por esta tela.' =>
      l.extra2,
    'Não foi possível carregar seus endereços. Você pode escolher outro destino.' =>
      l.extra3,
    'Não foi possível atualizar seus endereços. Tente novamente.' => l.extra4,
    'Destino confirmado neste uso. A sincronização está pendente; confira a conexão.' =>
      l.extra5,
    'Destino selecionado. A sincronização ainda está pendente.' => l.extra6,
    'Não encontramos esse endereço. Confira rua, número e cidade ou escolha o ponto no mapa.' =>
      l.extra7,
    'Não foi possível atualizar a sessão. Entre novamente pela tela inicial.' =>
      l.extra8,
    'Não conseguimos identificar o país deste endereço. Confira o ponto selecionado.' =>
      l.extra9,
    'Um produto da sacola está fora de venda. Remova-o para continuar.' =>
      l.extra10,
    'Não foi possível autenticar. Reinicie o app e tente novamente.' =>
      l.extra11,
    'Verifique sua conta antes da primeira compra. A navegação continua disponível.' =>
      l.extra12,
    'A taxa de entrega mudou. Confira o total e o pagamento antes de continuar.' =>
      l.extra13,
    'A confirmação do envio ainda está pendente. Confira a conexão e tente novamente.' =>
      l.extra14,
    'Pedido indisponível nesta sessão.' => l.extra15,
    'A entrega mudou de valor. O pedido não foi enviado. Confira a cotação antes de continuar.' =>
      l.extra16,
    'Seu pedido já foi recebido. Use Verificar pedido ou Retomar PIX para acompanhá-lo.' =>
      l.extra17,
    'Não foi possível confirmar a revisão. O carrinho foi mantido. Confira a conexão e tente novamente.' =>
      l.extra18,
    'Não foi possível confirmar sua elegibilidade para a compra. Confira seus documentos no perfil e tente novamente.' =>
      l.extra19,
    'Não foi possível iniciar o PIX. Confira sua conexão e tente novamente.' =>
      l.extra20,
    'Não foi possível enviar o pedido. Confira sua conexão e tente novamente.' =>
      l.extra21,
    'Sua sessão precisa estar atualizada para comprar.' => l.extra22,
    'Confira o endereço e tente calcular a entrega novamente.' => l.extra23,
    'Confira sua conexão e tente novamente. Essa falha não confirma o cancelamento do pedido.' =>
      l.extra24,
    'Pedido indisponível para esta sessão.' => l.extra25,
    'Confira se você entrou com a conta usada na compra.' => l.extra26,
    'A confirmação não foi concluída. Confira o pagamento e fale com a loja pelo pedido quando essa opção estiver disponível.' =>
      l.extra27,
    'Não foi possível recuperar seu carrinho. Confira a conexão e tente novamente.' =>
      l.extra28,
    'Sem confirmação de conexão. O carrinho foi mantido; tente sincronizar novamente.' =>
      l.extra29,
    'Aguarde a recuperação do carrinho ou tente novamente.' => l.extra30,
    'Você já adicionou a quantidade disponível.' => l.extra31,
    'Itens fora de venda foram removidos do carrinho.' => l.extra32,
    'Calculando entrega...' => l.extra33,
    'Entrega a calcular' => l.extra34,
    'Tentar calcular entrega novamente' => l.extra35,
    'A calcular' => l.extra36,
    'Frete cotado em BRL' => l.extra37,
    'Produtos' => l.extra38,
    'Ex.: Casa 2, ap. 51, portão vermelho...' => l.extra39,
    'Conta Chamaê excluída. A autorização Apple ainda exige remoção manual.' =>
      l.extra40,
    'Nova tentativa Apple em andamento' => l.extra41,
    'Conta Chamaê excluída; autorização Apple pendente' => l.extra42,
    'A solicitação foi recebida. O processamento continua mesmo se você fechar o app. Verifique o status por aqui.' =>
      l.extra43,
    'A solicitação está bloqueada nessa verificação. Uma nova tentativa exige confirmar sua identidade novamente.' =>
      l.extra44,
    'Endereço oficial copiado. Abra no seu navegador.' => l.extra45,
    'Não foi possível copiar. Use o endereço exibido abaixo.' => l.extra46,
    'Copiar endereço da Conta Apple' => l.extra47,
    'Rua' => l.address0,
    'Bairro' => l.address1,
    'Cidade' => l.address2,
    'Estado' => l.address3,
    'Nome' => l.address4,
    'Contato' => l.address5,
    _ => value,
  };
}

String localizedBrl(BuildContext context, num value) => NumberFormat.currency(
      locale: LocaleController.resolve(Localizations.localeOf(context))
          .toLanguageTag()
          .replaceAll('-', '_'),
      name: 'BRL',
      symbol: 'R\$',
    ).format(value).replaceAll('\u00a0', ' ');
String localizedDate(BuildContext context, DateTime value) => DateFormat.yMd(
      LocaleController.resolve(Localizations.localeOf(context))
          .toLanguageTag()
          .replaceAll('-', '_'),
    ).format(value);

/// Presentation-only migration bridge: backend status codes/product data remain
/// unchanged. Dynamic messages without an explicit catalog entry are retained.
class LocalizedText extends StatelessWidget {
  const LocalizedText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.semanticsLabel,
    this.textDirection,
    this.locale,
    this.strutStyle,
    this.textScaler,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final String? semanticsLabel;
  final TextDirection? textDirection;
  final Locale? locale;
  final StrutStyle? strutStyle;
  final TextScaler? textScaler;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;
  @override
  Widget build(BuildContext context) => Text(
        localizedLabel(context, data),
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        softWrap: softWrap,
        semanticsLabel: semanticsLabel == null
            ? null
            : localizedLabel(context, semanticsLabel!),
        textDirection: textDirection,
        locale: locale,
        strutStyle: strutStyle,
        textScaler: textScaler,
        textWidthBasis: textWidthBasis ?? TextWidthBasis.parent,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
}

InputDecoration localizedDecoration(
  BuildContext context,
  InputDecoration value,
) =>
    value.copyWith(
      labelText: value.labelText == null
          ? null
          : localizedLabel(context, value.labelText!),
      hintText: value.hintText == null
          ? null
          : localizedLabel(context, value.hintText!),
      helperText: value.helperText == null
          ? null
          : localizedLabel(context, value.helperText!),
      errorText: value.errorText == null
          ? null
          : localizedLabel(context, value.errorText!),
    );
