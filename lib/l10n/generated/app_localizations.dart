import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_es.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('es'),
    Locale('es', 'PY'),
    Locale('pt'),
    Locale('pt', 'BR')
  ];

  /// No description provided for @ui0.
  ///
  /// In pt, this message translates to:
  /// **'Voltar'**
  String get ui0;

  /// No description provided for @ui1.
  ///
  /// In pt, this message translates to:
  /// **'Continuar'**
  String get ui1;

  /// No description provided for @ui2.
  ///
  /// In pt, this message translates to:
  /// **'Registrando…'**
  String get ui2;

  /// No description provided for @ui3.
  ///
  /// In pt, this message translates to:
  /// **'Sair'**
  String get ui3;

  /// No description provided for @ui4.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar'**
  String get ui4;

  /// No description provided for @ui5.
  ///
  /// In pt, this message translates to:
  /// **'Salvar'**
  String get ui5;

  /// No description provided for @ui6.
  ///
  /// In pt, this message translates to:
  /// **'Excluir'**
  String get ui6;

  /// No description provided for @ui7.
  ///
  /// In pt, this message translates to:
  /// **'Editar'**
  String get ui7;

  /// No description provided for @ui8.
  ///
  /// In pt, this message translates to:
  /// **'Confirmar'**
  String get ui8;

  /// No description provided for @ui9.
  ///
  /// In pt, this message translates to:
  /// **'Carregando…'**
  String get ui9;

  /// No description provided for @ui10.
  ///
  /// In pt, this message translates to:
  /// **'Conta já existente'**
  String get ui10;

  /// No description provided for @ui11.
  ///
  /// In pt, this message translates to:
  /// **'Trocar de conta'**
  String get ui11;

  /// No description provided for @ui12.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível entrar agora. Confira a conexão e tente novamente.'**
  String get ui12;

  /// No description provided for @ui13.
  ///
  /// In pt, this message translates to:
  /// **'Chamaê Delivery. Bebidas e conveniência.'**
  String get ui13;

  /// No description provided for @ui14.
  ///
  /// In pt, this message translates to:
  /// **'Bem-vindo ao Chamaê'**
  String get ui14;

  /// No description provided for @ui15.
  ///
  /// In pt, this message translates to:
  /// **'Bebidas e conveniência, do seu jeito. Entre para encontrar seus endereços e acompanhar seus pedidos.'**
  String get ui15;

  /// No description provided for @ui16.
  ///
  /// In pt, this message translates to:
  /// **'Continuar com Apple'**
  String get ui16;

  /// No description provided for @ui17.
  ///
  /// In pt, this message translates to:
  /// **'Continuar com Google'**
  String get ui17;

  /// No description provided for @ui18.
  ///
  /// In pt, this message translates to:
  /// **'Esqueceu a senha ou perdeu o acesso?'**
  String get ui18;

  /// No description provided for @ui19.
  ///
  /// In pt, this message translates to:
  /// **'O acesso aguarda a configuração dos provedores neste ambiente.'**
  String get ui19;

  /// No description provided for @ui20.
  ///
  /// In pt, this message translates to:
  /// **'Entrada por telefone em preparação.'**
  String get ui20;

  /// No description provided for @ui21.
  ///
  /// In pt, this message translates to:
  /// **'Seus dados ficam vinculados à sua conta. Você poderá conferir os documentos e as informações de privacidade antes de continuar.'**
  String get ui21;

  /// No description provided for @ui22.
  ///
  /// In pt, this message translates to:
  /// **'Política de Privacidade'**
  String get ui22;

  /// No description provided for @ui23.
  ///
  /// In pt, this message translates to:
  /// **'Termos de Uso'**
  String get ui23;

  /// No description provided for @ui24.
  ///
  /// In pt, this message translates to:
  /// **'Informe uma data de nascimento válida e confira os três aceites.'**
  String get ui24;

  /// No description provided for @ui25.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível registrar o aceite. Confira a conexão e tente novamente. Se os documentos mudaram, atualize esta etapa.'**
  String get ui25;

  /// No description provided for @ui26.
  ///
  /// In pt, this message translates to:
  /// **'Vamos começar'**
  String get ui26;

  /// No description provided for @ui27.
  ///
  /// In pt, this message translates to:
  /// **'AMBIENTE DE DESENVOLVIMENTO — documentos jurídicos ainda não são os oficiais.'**
  String get ui27;

  /// No description provided for @ui28.
  ///
  /// In pt, this message translates to:
  /// **'A passagem vale somente nesta sessão de homologação e não registra aceite jurídico oficial.'**
  String get ui28;

  /// No description provided for @ui29.
  ///
  /// In pt, this message translates to:
  /// **'Uma experiência feita para você'**
  String get ui29;

  /// No description provided for @ui30.
  ///
  /// In pt, this message translates to:
  /// **'Precisamos da sua data de nascimento e da confirmação dos documentos para continuar.'**
  String get ui30;

  /// No description provided for @ui31.
  ///
  /// In pt, this message translates to:
  /// **'Data de nascimento'**
  String get ui31;

  /// No description provided for @ui32.
  ///
  /// In pt, this message translates to:
  /// **'A data informada não comprova sua identidade. Conforme o produto e o destino, um documento poderá ser solicitado no recebimento.'**
  String get ui32;

  /// No description provided for @ui33.
  ///
  /// In pt, this message translates to:
  /// **'Li e aceito os Termos de Uso'**
  String get ui33;

  /// No description provided for @ui34.
  ///
  /// In pt, this message translates to:
  /// **'Li e estou ciente da Política de Privacidade'**
  String get ui34;

  /// No description provided for @ui35.
  ///
  /// In pt, this message translates to:
  /// **'Estou ciente das regras para bebidas alcoólicas'**
  String get ui35;

  /// No description provided for @ui36.
  ///
  /// In pt, this message translates to:
  /// **'Documentos DRAFT de desenvolvimento. O primeiro acesso será liberado quando os documentos oficiais estiverem disponíveis.'**
  String get ui36;

  /// No description provided for @ui37.
  ///
  /// In pt, this message translates to:
  /// **'Atualizar documentos'**
  String get ui37;

  /// No description provided for @ui38.
  ///
  /// In pt, this message translates to:
  /// **'Sair da conta'**
  String get ui38;

  /// No description provided for @ui39.
  ///
  /// In pt, this message translates to:
  /// **'Sair da conta?'**
  String get ui39;

  /// No description provided for @ui40.
  ///
  /// In pt, this message translates to:
  /// **'Seus pedidos e seu carrinho continuarão vinculados a esta conta.'**
  String get ui40;

  /// No description provided for @ui41.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível sair agora. Tente novamente.'**
  String get ui41;

  /// No description provided for @ui42.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível vincular essa identidade. Use uma conta que ainda não esteja vinculada a outro perfil.'**
  String get ui42;

  /// No description provided for @ui43.
  ///
  /// In pt, this message translates to:
  /// **'Seu perfil'**
  String get ui43;

  /// No description provided for @ui44.
  ///
  /// In pt, this message translates to:
  /// **'Seu perfil Chamaê'**
  String get ui44;

  /// No description provided for @ui45.
  ///
  /// In pt, this message translates to:
  /// **'Minha conta'**
  String get ui45;

  /// No description provided for @ui46.
  ///
  /// In pt, this message translates to:
  /// **'Buscando os dados da sua conta'**
  String get ui46;

  /// No description provided for @ui47.
  ///
  /// In pt, this message translates to:
  /// **'Seu perfil já vai aparecer por aqui.'**
  String get ui47;

  /// No description provided for @ui48.
  ///
  /// In pt, this message translates to:
  /// **'Método de login'**
  String get ui48;

  /// No description provided for @ui49.
  ///
  /// In pt, this message translates to:
  /// **'Conta vinculada'**
  String get ui49;

  /// No description provided for @ui50.
  ///
  /// In pt, this message translates to:
  /// **'Conta Chamaê'**
  String get ui50;

  /// No description provided for @ui51.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível atualizar seu perfil.'**
  String get ui51;

  /// No description provided for @ui52.
  ///
  /// In pt, this message translates to:
  /// **'Confira sua conexão e tente novamente. Seus dados não foram apagados.'**
  String get ui52;

  /// No description provided for @ui53.
  ///
  /// In pt, this message translates to:
  /// **'Conferir documentos atualizados'**
  String get ui53;

  /// No description provided for @ui54.
  ///
  /// In pt, this message translates to:
  /// **'Endereço de entrega'**
  String get ui54;

  /// No description provided for @ui55.
  ///
  /// In pt, this message translates to:
  /// **'Selecione o endereço na tela inicial'**
  String get ui55;

  /// No description provided for @ui56.
  ///
  /// In pt, this message translates to:
  /// **'Meus pedidos'**
  String get ui56;

  /// No description provided for @ui57.
  ///
  /// In pt, this message translates to:
  /// **'Vincular Google à conta'**
  String get ui57;

  /// No description provided for @ui58.
  ///
  /// In pt, this message translates to:
  /// **'Vincular Apple à conta'**
  String get ui58;

  /// No description provided for @ui59.
  ///
  /// In pt, this message translates to:
  /// **'Excluir minha conta'**
  String get ui59;

  /// No description provided for @ui60.
  ///
  /// In pt, this message translates to:
  /// **'Conecte-se para ver seus pedidos.'**
  String get ui60;

  /// No description provided for @ui61.
  ///
  /// In pt, this message translates to:
  /// **'Seus pedidos aparecerão aqui.'**
  String get ui61;

  /// No description provided for @ui62.
  ///
  /// In pt, this message translates to:
  /// **'Carregar mais pedidos'**
  String get ui62;

  /// No description provided for @ui63.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível carregar os pedidos.'**
  String get ui63;

  /// No description provided for @ui64.
  ///
  /// In pt, this message translates to:
  /// **'Tentar novamente'**
  String get ui64;

  /// No description provided for @ui65.
  ///
  /// In pt, this message translates to:
  /// **'Pedido recebido'**
  String get ui65;

  /// No description provided for @ui66.
  ///
  /// In pt, this message translates to:
  /// **'Novo'**
  String get ui66;

  /// No description provided for @ui67.
  ///
  /// In pt, this message translates to:
  /// **'Em Separação'**
  String get ui67;

  /// No description provided for @ui68.
  ///
  /// In pt, this message translates to:
  /// **'Em separação'**
  String get ui68;

  /// No description provided for @ui69.
  ///
  /// In pt, this message translates to:
  /// **'Aguardando Retirada'**
  String get ui69;

  /// No description provided for @ui70.
  ///
  /// In pt, this message translates to:
  /// **'Aguardando retirada'**
  String get ui70;

  /// No description provided for @ui71.
  ///
  /// In pt, this message translates to:
  /// **'Saiu para Entrega'**
  String get ui71;

  /// No description provided for @ui72.
  ///
  /// In pt, this message translates to:
  /// **'Saiu para entrega'**
  String get ui72;

  /// No description provided for @ui73.
  ///
  /// In pt, this message translates to:
  /// **'Concluído'**
  String get ui73;

  /// No description provided for @ui74.
  ///
  /// In pt, this message translates to:
  /// **'Pedido cancelado'**
  String get ui74;

  /// No description provided for @ui75.
  ///
  /// In pt, this message translates to:
  /// **'Aguardando pagamento'**
  String get ui75;

  /// No description provided for @ui76.
  ///
  /// In pt, this message translates to:
  /// **'Atualizando pedido'**
  String get ui76;

  /// No description provided for @ui77.
  ///
  /// In pt, this message translates to:
  /// **'Sua conta foi excluída.'**
  String get ui77;

  /// No description provided for @ui78.
  ///
  /// In pt, this message translates to:
  /// **'Conta excluída'**
  String get ui78;

  /// No description provided for @ui79.
  ///
  /// In pt, this message translates to:
  /// **'Você no controle da sua conta'**
  String get ui79;

  /// No description provided for @ui80.
  ///
  /// In pt, this message translates to:
  /// **'Confira o que acontece antes de continuar.'**
  String get ui80;

  /// No description provided for @ui81.
  ///
  /// In pt, this message translates to:
  /// **'Entendi que a exclusão é definitiva.'**
  String get ui81;

  /// No description provided for @ui82.
  ///
  /// In pt, this message translates to:
  /// **'Confirmando sua identidade…'**
  String get ui82;

  /// No description provided for @ui83.
  ///
  /// In pt, this message translates to:
  /// **'Confirmar identidade e excluir'**
  String get ui83;

  /// No description provided for @ui84.
  ///
  /// In pt, this message translates to:
  /// **'Verificar status'**
  String get ui84;

  /// No description provided for @ui85.
  ///
  /// In pt, this message translates to:
  /// **'Exclusão em andamento'**
  String get ui85;

  /// No description provided for @ui86.
  ///
  /// In pt, this message translates to:
  /// **'Revogação Apple pendente'**
  String get ui86;

  /// No description provided for @ui87.
  ///
  /// In pt, this message translates to:
  /// **'Resolva seu pedido antes de continuar'**
  String get ui87;

  /// No description provided for @ui88.
  ///
  /// In pt, this message translates to:
  /// **'A exclusão não foi concluída. Há um pedido ou pagamento que precisa de atenção.'**
  String get ui88;

  /// No description provided for @ui89.
  ///
  /// In pt, this message translates to:
  /// **'A exclusão foi concluída. Sua sessão será encerrada.'**
  String get ui89;

  /// No description provided for @ui90.
  ///
  /// In pt, this message translates to:
  /// **'Sua conta foi excluída. Feche e abra o aplicativo para encerrar a sessão neste aparelho.'**
  String get ui90;

  /// No description provided for @ui91.
  ///
  /// In pt, this message translates to:
  /// **'Recuperar acesso'**
  String get ui91;

  /// No description provided for @ui92.
  ///
  /// In pt, this message translates to:
  /// **'Esqueceu a senha?'**
  String get ui92;

  /// No description provided for @ui93.
  ///
  /// In pt, this message translates to:
  /// **'Conta Google'**
  String get ui93;

  /// No description provided for @ui94.
  ///
  /// In pt, this message translates to:
  /// **'Conta Apple'**
  String get ui94;

  /// No description provided for @ui95.
  ///
  /// In pt, this message translates to:
  /// **'Copiar endereço Google'**
  String get ui95;

  /// No description provided for @ui96.
  ///
  /// In pt, this message translates to:
  /// **'Copiar endereço Apple'**
  String get ui96;

  /// No description provided for @ui97.
  ///
  /// In pt, this message translates to:
  /// **'Voltar e entrar com Google'**
  String get ui97;

  /// No description provided for @ui98.
  ///
  /// In pt, this message translates to:
  /// **'Voltar e entrar com Apple'**
  String get ui98;

  /// No description provided for @ui99.
  ///
  /// In pt, this message translates to:
  /// **'Não salvar'**
  String get ui99;

  /// No description provided for @ui100.
  ///
  /// In pt, this message translates to:
  /// **'Excluir endereço salvo?'**
  String get ui100;

  /// No description provided for @ui101.
  ///
  /// In pt, this message translates to:
  /// **'Onde vamos entregar?'**
  String get ui101;

  /// No description provided for @ui102.
  ///
  /// In pt, this message translates to:
  /// **'Escolha o destino. A localização do telefone pode ser diferente do local da entrega.'**
  String get ui102;

  /// No description provided for @ui103.
  ///
  /// In pt, this message translates to:
  /// **'Usar minha localização'**
  String get ui103;

  /// No description provided for @ui104.
  ///
  /// In pt, this message translates to:
  /// **'Digitar endereço'**
  String get ui104;

  /// No description provided for @ui105.
  ///
  /// In pt, this message translates to:
  /// **'Reutilizar último destino'**
  String get ui105;

  /// No description provided for @ui106.
  ///
  /// In pt, this message translates to:
  /// **'Endereço'**
  String get ui106;

  /// No description provided for @ui107.
  ///
  /// In pt, this message translates to:
  /// **'Opções do endereço'**
  String get ui107;

  /// No description provided for @ui108.
  ///
  /// In pt, this message translates to:
  /// **'Editar endereço'**
  String get ui108;

  /// No description provided for @ui109.
  ///
  /// In pt, this message translates to:
  /// **'Definir como padrão'**
  String get ui109;

  /// No description provided for @ui110.
  ///
  /// In pt, this message translates to:
  /// **'Excluir endereço'**
  String get ui110;

  /// No description provided for @ui111.
  ///
  /// In pt, this message translates to:
  /// **'Explorar catálogo sem endereço'**
  String get ui111;

  /// No description provided for @ui112.
  ///
  /// In pt, this message translates to:
  /// **'Defina seu endereço para calcular entrega. Você pode explorar o catálogo antes disso.'**
  String get ui112;

  /// No description provided for @ui113.
  ///
  /// In pt, this message translates to:
  /// **'Número'**
  String get ui113;

  /// No description provided for @ui114.
  ///
  /// In pt, this message translates to:
  /// **'Sem número'**
  String get ui114;

  /// No description provided for @ui115.
  ///
  /// In pt, this message translates to:
  /// **'Confirmar no mapa'**
  String get ui115;

  /// No description provided for @ui116.
  ///
  /// In pt, this message translates to:
  /// **'Confira o endereço'**
  String get ui116;

  /// No description provided for @ui117.
  ///
  /// In pt, this message translates to:
  /// **'A entrega segue o ponto confirmado no mapa. Confira os dados para ajudar o entregador.'**
  String get ui117;

  /// No description provided for @ui118.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível identificar o país. Esta entrega é no Brasil ou Paraguai?'**
  String get ui118;

  /// No description provided for @ui119.
  ///
  /// In pt, this message translates to:
  /// **'Destino: Brasil'**
  String get ui119;

  /// No description provided for @ui120.
  ///
  /// In pt, this message translates to:
  /// **'Destino: Paraguai'**
  String get ui120;

  /// No description provided for @ui121.
  ///
  /// In pt, this message translates to:
  /// **'Destino fora da área atendida'**
  String get ui121;

  /// No description provided for @ui122.
  ///
  /// In pt, this message translates to:
  /// **'Ponto de referência'**
  String get ui122;

  /// No description provided for @ui123.
  ///
  /// In pt, this message translates to:
  /// **'Salvar endereço como'**
  String get ui123;

  /// No description provided for @ui124.
  ///
  /// In pt, this message translates to:
  /// **'Confirmar destino'**
  String get ui124;

  /// No description provided for @ui125.
  ///
  /// In pt, this message translates to:
  /// **'Localizando endereço...'**
  String get ui125;

  /// No description provided for @ui126.
  ///
  /// In pt, this message translates to:
  /// **'Ajuste o marcador para o local exato da entrega'**
  String get ui126;

  /// No description provided for @ui127.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível obter sua localização. Digite o endereço ou ajuste o ponto no mapa.'**
  String get ui127;

  /// No description provided for @ui128.
  ///
  /// In pt, this message translates to:
  /// **'Endereço não identificado'**
  String get ui128;

  /// No description provided for @ui129.
  ///
  /// In pt, this message translates to:
  /// **'Local de entrega'**
  String get ui129;

  /// No description provided for @ui130.
  ///
  /// In pt, this message translates to:
  /// **'Buscar endereço e número'**
  String get ui130;

  /// No description provided for @ui131.
  ///
  /// In pt, this message translates to:
  /// **'Buscar endereço'**
  String get ui131;

  /// No description provided for @ui132.
  ///
  /// In pt, this message translates to:
  /// **'Localizando você...'**
  String get ui132;

  /// No description provided for @ui133.
  ///
  /// In pt, this message translates to:
  /// **'Arraste o mapa'**
  String get ui133;

  /// No description provided for @ui134.
  ///
  /// In pt, this message translates to:
  /// **'Arraste o mapa até o pino ficar exatamente sobre o local da entrega.'**
  String get ui134;

  /// No description provided for @ui135.
  ///
  /// In pt, this message translates to:
  /// **'Complemento / referência (opcional)'**
  String get ui135;

  /// No description provided for @ui136.
  ///
  /// In pt, this message translates to:
  /// **'Referência (opcional)'**
  String get ui136;

  /// No description provided for @ui137.
  ///
  /// In pt, this message translates to:
  /// **'Confirmar localização'**
  String get ui137;

  /// No description provided for @ui138.
  ///
  /// In pt, this message translates to:
  /// **'Seu carrinho'**
  String get ui138;

  /// No description provided for @ui139.
  ///
  /// In pt, this message translates to:
  /// **'Seu carrinho está vazio.'**
  String get ui139;

  /// No description provided for @ui140.
  ///
  /// In pt, this message translates to:
  /// **'Escolha suas bebidas e conveniência.'**
  String get ui140;

  /// No description provided for @ui141.
  ///
  /// In pt, this message translates to:
  /// **'Confira seu pedido'**
  String get ui141;

  /// No description provided for @ui142.
  ///
  /// In pt, this message translates to:
  /// **'Revise seus itens antes de continuar.'**
  String get ui142;

  /// No description provided for @ui143.
  ///
  /// In pt, this message translates to:
  /// **'Resumo do pedido'**
  String get ui143;

  /// No description provided for @ui144.
  ///
  /// In pt, this message translates to:
  /// **'Taxa de serviço'**
  String get ui144;

  /// No description provided for @ui145.
  ///
  /// In pt, this message translates to:
  /// **'Produtos e serviço'**
  String get ui145;

  /// No description provided for @ui146.
  ///
  /// In pt, this message translates to:
  /// **'A calcular após confirmar o endereço'**
  String get ui146;

  /// No description provided for @ui147.
  ///
  /// In pt, this message translates to:
  /// **'Continuar para entrega'**
  String get ui147;

  /// No description provided for @ui148.
  ///
  /// In pt, this message translates to:
  /// **'O total será conferido ao confirmar o pedido.'**
  String get ui148;

  /// No description provided for @ui149.
  ///
  /// In pt, this message translates to:
  /// **'Diminuir quantidade'**
  String get ui149;

  /// No description provided for @ui150.
  ///
  /// In pt, this message translates to:
  /// **'Aumentar quantidade'**
  String get ui150;

  /// No description provided for @ui151.
  ///
  /// In pt, this message translates to:
  /// **'Cotacao expirada. Calcule a entrega novamente.'**
  String get ui151;

  /// No description provided for @ui152.
  ///
  /// In pt, this message translates to:
  /// **'Cotacao expirada. O pedido nao foi enviado.'**
  String get ui152;

  /// No description provided for @ui153.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível calcular a entrega agora. Tente novamente.'**
  String get ui153;

  /// No description provided for @ui154.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar pagamento em dinheiro'**
  String get ui154;

  /// No description provided for @ui155.
  ///
  /// In pt, this message translates to:
  /// **'Pagamento dividido disponível somente em dinheiro.'**
  String get ui155;

  /// No description provided for @ui156.
  ///
  /// In pt, this message translates to:
  /// **'Restará pagar'**
  String get ui156;

  /// No description provided for @ui157.
  ///
  /// In pt, this message translates to:
  /// **'Pendente na entrega'**
  String get ui157;

  /// No description provided for @ui158.
  ///
  /// In pt, this message translates to:
  /// **'Crédito'**
  String get ui158;

  /// No description provided for @ui159.
  ///
  /// In pt, this message translates to:
  /// **'Crédito à vista'**
  String get ui159;

  /// No description provided for @ui160.
  ///
  /// In pt, this message translates to:
  /// **'Débito'**
  String get ui160;

  /// No description provided for @ui161.
  ///
  /// In pt, this message translates to:
  /// **'Aguardando confirmação'**
  String get ui161;

  /// No description provided for @ui162.
  ///
  /// In pt, this message translates to:
  /// **'Pagamento dividido'**
  String get ui162;

  /// No description provided for @ui163.
  ///
  /// In pt, this message translates to:
  /// **'Esta entrega é no Brasil ou Paraguai?'**
  String get ui163;

  /// No description provided for @ui164.
  ///
  /// In pt, this message translates to:
  /// **'Confirme o destino da entrega antes de continuar.'**
  String get ui164;

  /// No description provided for @ui165.
  ///
  /// In pt, this message translates to:
  /// **'Confirme o país do endereço para continuar.'**
  String get ui165;

  /// No description provided for @ui166.
  ///
  /// In pt, this message translates to:
  /// **'Informe seu nome para continuar.'**
  String get ui166;

  /// No description provided for @ui167.
  ///
  /// In pt, this message translates to:
  /// **'Informe um WhatsApp válido com DDD.'**
  String get ui167;

  /// No description provided for @ui168.
  ///
  /// In pt, this message translates to:
  /// **'Sua sessão mudou. Reabra o checkout.'**
  String get ui168;

  /// No description provided for @ui169.
  ///
  /// In pt, this message translates to:
  /// **'Sua sessão mudou.'**
  String get ui169;

  /// No description provided for @ui170.
  ///
  /// In pt, this message translates to:
  /// **'Verifique sua conta para concluir a compra.'**
  String get ui170;

  /// No description provided for @ui171.
  ///
  /// In pt, this message translates to:
  /// **'Confira sua elegibilidade e os documentos para continuar.'**
  String get ui171;

  /// No description provided for @ui172.
  ///
  /// In pt, this message translates to:
  /// **'Um produto da sacola não está disponível para sua faixa etária neste destino.'**
  String get ui172;

  /// No description provided for @ui173.
  ///
  /// In pt, this message translates to:
  /// **'Seu pedido'**
  String get ui173;

  /// No description provided for @ui174.
  ///
  /// In pt, this message translates to:
  /// **'Seu pedido foi iniciado. Confira a confirmação para continuar.'**
  String get ui174;

  /// No description provided for @ui175.
  ///
  /// In pt, this message translates to:
  /// **'Retomar PIX'**
  String get ui175;

  /// No description provided for @ui176.
  ///
  /// In pt, this message translates to:
  /// **'Verificar pedido'**
  String get ui176;

  /// No description provided for @ui177.
  ///
  /// In pt, this message translates to:
  /// **'Revisar sacola antes de enviar'**
  String get ui177;

  /// No description provided for @ui178.
  ///
  /// In pt, this message translates to:
  /// **'Finalizar Pedido'**
  String get ui178;

  /// No description provided for @ui179.
  ///
  /// In pt, this message translates to:
  /// **'Conferindo os detalhes do seu pedido'**
  String get ui179;

  /// No description provided for @ui180.
  ///
  /// In pt, this message translates to:
  /// **'Aguarde por aqui. Seu carrinho continua guardado.'**
  String get ui180;

  /// No description provided for @ui181.
  ///
  /// In pt, this message translates to:
  /// **'Confira os detalhes'**
  String get ui181;

  /// No description provided for @ui182.
  ///
  /// In pt, this message translates to:
  /// **'Seu endereço, seus itens e a forma de pagamento.'**
  String get ui182;

  /// No description provided for @ui183.
  ///
  /// In pt, this message translates to:
  /// **'Atualizar sessão'**
  String get ui183;

  /// No description provided for @ui184.
  ///
  /// In pt, this message translates to:
  /// **'Confirmar país da entrega'**
  String get ui184;

  /// No description provided for @ui185.
  ///
  /// In pt, this message translates to:
  /// **'Entregar em'**
  String get ui185;

  /// No description provided for @ui186.
  ///
  /// In pt, this message translates to:
  /// **'Endereço selecionado'**
  String get ui186;

  /// No description provided for @ui187.
  ///
  /// In pt, this message translates to:
  /// **'Nome para a entrega'**
  String get ui187;

  /// No description provided for @ui188.
  ///
  /// In pt, this message translates to:
  /// **'Editar nome'**
  String get ui188;

  /// No description provided for @ui189.
  ///
  /// In pt, this message translates to:
  /// **'Seu Nome *'**
  String get ui189;

  /// No description provided for @ui190.
  ///
  /// In pt, this message translates to:
  /// **'Contato para a entrega'**
  String get ui190;

  /// No description provided for @ui191.
  ///
  /// In pt, this message translates to:
  /// **'Editar contato'**
  String get ui191;

  /// No description provided for @ui192.
  ///
  /// In pt, this message translates to:
  /// **'Telefone / WhatsApp *'**
  String get ui192;

  /// No description provided for @ui193.
  ///
  /// In pt, this message translates to:
  /// **'Valores em Real'**
  String get ui193;

  /// No description provided for @ui194.
  ///
  /// In pt, this message translates to:
  /// **'Valores em Guarani'**
  String get ui194;

  /// No description provided for @ui195.
  ///
  /// In pt, this message translates to:
  /// **'Valores em Dólar'**
  String get ui195;

  /// No description provided for @ui196.
  ///
  /// In pt, this message translates to:
  /// **'Valor que será entregue'**
  String get ui196;

  /// No description provided for @ui197.
  ///
  /// In pt, this message translates to:
  /// **'Valor insuficiente para este pedido.'**
  String get ui197;

  /// No description provided for @ui198.
  ///
  /// In pt, this message translates to:
  /// **'Taxa de Entrega'**
  String get ui198;

  /// No description provided for @ui199.
  ///
  /// In pt, this message translates to:
  /// **'Aguardando cotação'**
  String get ui199;

  /// No description provided for @ui200.
  ///
  /// In pt, this message translates to:
  /// **'Aguardando entrega'**
  String get ui200;

  /// No description provided for @ui201.
  ///
  /// In pt, this message translates to:
  /// **'Dividir pagamento'**
  String get ui201;

  /// No description provided for @ui202.
  ///
  /// In pt, this message translates to:
  /// **'Somente dinheiro • até 3 partes'**
  String get ui202;

  /// No description provided for @ui203.
  ///
  /// In pt, this message translates to:
  /// **'Forma de pagamento'**
  String get ui203;

  /// No description provided for @ui204.
  ///
  /// In pt, this message translates to:
  /// **'Cartão na entrega'**
  String get ui204;

  /// No description provided for @ui205.
  ///
  /// In pt, this message translates to:
  /// **'Dinheiro'**
  String get ui205;

  /// No description provided for @ui206.
  ///
  /// In pt, this message translates to:
  /// **'Adicione pelo menos 2 partes do pagamento.'**
  String get ui206;

  /// No description provided for @ui207.
  ///
  /// In pt, this message translates to:
  /// **'Ainda existe valor restante no pagamento.'**
  String get ui207;

  /// No description provided for @ui208.
  ///
  /// In pt, this message translates to:
  /// **'PIX e maquininha não podem gerar troco. Ajuste os valores.'**
  String get ui208;

  /// No description provided for @ui209.
  ///
  /// In pt, this message translates to:
  /// **'Informe com quanto você vai pagar.'**
  String get ui209;

  /// No description provided for @ui210.
  ///
  /// In pt, this message translates to:
  /// **'O valor informado é menor que o total do pedido.'**
  String get ui210;

  /// No description provided for @ui211.
  ///
  /// In pt, this message translates to:
  /// **'Pagamento dividido aceita somente dinheiro.'**
  String get ui211;

  /// No description provided for @ui212.
  ///
  /// In pt, this message translates to:
  /// **'Finalizar pedido'**
  String get ui212;

  /// No description provided for @ui213.
  ///
  /// In pt, this message translates to:
  /// **'Acompanhar pedido'**
  String get ui213;

  /// No description provided for @ui214.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível acompanhar o pedido.'**
  String get ui214;

  /// No description provided for @ui215.
  ///
  /// In pt, this message translates to:
  /// **'Buscando seu pedido'**
  String get ui215;

  /// No description provided for @ui216.
  ///
  /// In pt, this message translates to:
  /// **'Só um instante para conferir as novidades.'**
  String get ui216;

  /// No description provided for @ui217.
  ///
  /// In pt, this message translates to:
  /// **'Revisão financeira'**
  String get ui217;

  /// No description provided for @ui218.
  ///
  /// In pt, this message translates to:
  /// **'Revisão de estoque'**
  String get ui218;

  /// No description provided for @ui219.
  ///
  /// In pt, this message translates to:
  /// **'Aguardando atribuição'**
  String get ui219;

  /// No description provided for @ui220.
  ///
  /// In pt, this message translates to:
  /// **'Entregador não informado'**
  String get ui220;

  /// No description provided for @ui221.
  ///
  /// In pt, this message translates to:
  /// **'Endereço não informado'**
  String get ui221;

  /// No description provided for @ui222.
  ///
  /// In pt, this message translates to:
  /// **'Vamos conferir seu pedido'**
  String get ui222;

  /// No description provided for @ui223.
  ///
  /// In pt, this message translates to:
  /// **'Conferindo seu pedido'**
  String get ui223;

  /// No description provided for @ui224.
  ///
  /// In pt, this message translates to:
  /// **'Seu pedido precisa de atenção'**
  String get ui224;

  /// No description provided for @ui225.
  ///
  /// In pt, this message translates to:
  /// **'Estamos conferindo os detalhes'**
  String get ui225;

  /// No description provided for @ui226.
  ///
  /// In pt, this message translates to:
  /// **'Aguarde a confirmação por aqui antes de fazer outro pedido.'**
  String get ui226;

  /// No description provided for @ui227.
  ///
  /// In pt, this message translates to:
  /// **'Ver pagamento PIX'**
  String get ui227;

  /// No description provided for @ui228.
  ///
  /// In pt, this message translates to:
  /// **'Total em confirmação'**
  String get ui228;

  /// No description provided for @ui229.
  ///
  /// In pt, this message translates to:
  /// **'concluída'**
  String get ui229;

  /// No description provided for @ui230.
  ///
  /// In pt, this message translates to:
  /// **'etapa atual'**
  String get ui230;

  /// No description provided for @ui231.
  ///
  /// In pt, this message translates to:
  /// **'Acompanhe as etapas por aqui. A localização do entregador ao vivo ainda não está disponível.'**
  String get ui231;

  /// No description provided for @ui232.
  ///
  /// In pt, this message translates to:
  /// **'Disponível'**
  String get ui232;

  /// No description provided for @ui233.
  ///
  /// In pt, this message translates to:
  /// **'Indisponível no momento'**
  String get ui233;

  /// No description provided for @ui234.
  ///
  /// In pt, this message translates to:
  /// **'Ajuste a quantidade ao estoque disponível.'**
  String get ui234;

  /// No description provided for @ui235.
  ///
  /// In pt, this message translates to:
  /// **'Adicionado ao carrinho.'**
  String get ui235;

  /// No description provided for @ui236.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar ao carrinho'**
  String get ui236;

  /// No description provided for @ui237.
  ///
  /// In pt, this message translates to:
  /// **'Indisponível'**
  String get ui237;

  /// No description provided for @ui238.
  ///
  /// In pt, this message translates to:
  /// **'Sua sacola está vazia.'**
  String get ui238;

  /// No description provided for @ui239.
  ///
  /// In pt, this message translates to:
  /// **'Selecionar endereço de entrega'**
  String get ui239;

  /// No description provided for @ui240.
  ///
  /// In pt, this message translates to:
  /// **'Escolha seu endereço'**
  String get ui240;

  /// No description provided for @ui241.
  ///
  /// In pt, this message translates to:
  /// **'Buscar produtos'**
  String get ui241;

  /// No description provided for @ui242.
  ///
  /// In pt, this message translates to:
  /// **'Moeda de exibição'**
  String get ui242;

  /// No description provided for @ui243.
  ///
  /// In pt, this message translates to:
  /// **'Real (BRL)'**
  String get ui243;

  /// No description provided for @ui244.
  ///
  /// In pt, this message translates to:
  /// **'Guarani (PYG)'**
  String get ui244;

  /// No description provided for @ui245.
  ///
  /// In pt, this message translates to:
  /// **'Dólar (USD)'**
  String get ui245;

  /// No description provided for @ui246.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma categoria disponível.'**
  String get ui246;

  /// No description provided for @ui247.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum produto encontrado.'**
  String get ui247;

  /// No description provided for @ui248.
  ///
  /// In pt, this message translates to:
  /// **'Ofertas do Dia'**
  String get ui248;

  /// No description provided for @ui249.
  ///
  /// In pt, this message translates to:
  /// **'Combos Festa'**
  String get ui249;

  /// No description provided for @ui250.
  ///
  /// In pt, this message translates to:
  /// **'Resultados da busca'**
  String get ui250;

  /// No description provided for @ui251.
  ///
  /// In pt, this message translates to:
  /// **'Ver todos'**
  String get ui251;

  /// No description provided for @ui252.
  ///
  /// In pt, this message translates to:
  /// **'Promoções do dia'**
  String get ui252;

  /// No description provided for @ui253.
  ///
  /// In pt, this message translates to:
  /// **'Ver todas'**
  String get ui253;

  /// No description provided for @ui254.
  ///
  /// In pt, this message translates to:
  /// **'Mais pedidos'**
  String get ui254;

  /// No description provided for @ui255.
  ///
  /// In pt, this message translates to:
  /// **'Compre por categoria'**
  String get ui255;

  /// No description provided for @ui256.
  ///
  /// In pt, this message translates to:
  /// **'Todos os produtos'**
  String get ui256;

  /// No description provided for @ui257.
  ///
  /// In pt, this message translates to:
  /// **'Buscar bebidas e conveniência'**
  String get ui257;

  /// No description provided for @ui258.
  ///
  /// In pt, this message translates to:
  /// **'Início'**
  String get ui258;

  /// No description provided for @ui259.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível carregar os produtos.'**
  String get ui259;

  /// No description provided for @ui260.
  ///
  /// In pt, this message translates to:
  /// **'Subtotal'**
  String get ui260;

  /// No description provided for @ui261.
  ///
  /// In pt, this message translates to:
  /// **'Total'**
  String get ui261;

  /// No description provided for @ui262.
  ///
  /// In pt, this message translates to:
  /// **'Frete'**
  String get ui262;

  /// No description provided for @ui263.
  ///
  /// In pt, this message translates to:
  /// **'Pedido'**
  String get ui263;

  /// No description provided for @ui264.
  ///
  /// In pt, this message translates to:
  /// **'Pedidos'**
  String get ui264;

  /// No description provided for @ui265.
  ///
  /// In pt, this message translates to:
  /// **'Suporte'**
  String get ui265;

  /// No description provided for @ui266.
  ///
  /// In pt, this message translates to:
  /// **'Falar com a loja'**
  String get ui266;

  /// No description provided for @ui267.
  ///
  /// In pt, this message translates to:
  /// **'Cotação expirada'**
  String get ui267;

  /// No description provided for @ui268.
  ///
  /// In pt, this message translates to:
  /// **'Calcular entrega'**
  String get ui268;

  /// No description provided for @ui269.
  ///
  /// In pt, this message translates to:
  /// **'Atualizar cotação'**
  String get ui269;

  /// No description provided for @identification.
  ///
  /// In pt, this message translates to:
  /// **'Identificação'**
  String get identification;

  /// No description provided for @identityNotice.
  ///
  /// In pt, this message translates to:
  /// **'Documento, idioma e destino são independentes. O número é usado somente para conferir o formato nesta tela e não será salvo.'**
  String get identityNotice;

  /// No description provided for @brazilCpf.
  ///
  /// In pt, this message translates to:
  /// **'Brasil — CPF'**
  String get brazilCpf;

  /// No description provided for @paraguayId.
  ///
  /// In pt, this message translates to:
  /// **'Paraguay — Cédula de identidad'**
  String get paraguayId;

  /// No description provided for @otherId.
  ///
  /// In pt, this message translates to:
  /// **'Outro documento / outra jurisdição'**
  String get otherId;

  /// No description provided for @fullName.
  ///
  /// In pt, this message translates to:
  /// **'Nome completo'**
  String get fullName;

  /// No description provided for @documentTemporary.
  ///
  /// In pt, this message translates to:
  /// **'Documento — entrada temporária protegida'**
  String get documentTemporary;

  /// No description provided for @documentIssuer.
  ///
  /// In pt, this message translates to:
  /// **'País emissor (BR, PY ou outro código)'**
  String get documentIssuer;

  /// No description provided for @internationalPhone.
  ///
  /// In pt, this message translates to:
  /// **'Telefone com código internacional (+55 / +595)'**
  String get internationalPhone;

  /// No description provided for @identityInvalid.
  ///
  /// In pt, this message translates to:
  /// **'Confira nome, telefone e formato do documento. Isso não verifica identidade ou idade.'**
  String get identityInvalid;

  /// No description provided for @identitySaveFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível salvar a identificação. Seus aceites e PIN foram preservados.'**
  String get identitySaveFailed;

  /// No description provided for @noAgeProof.
  ///
  /// In pt, this message translates to:
  /// **'CPF válido no formato ou cédula digitada não comprovam idade nem titularidade.'**
  String get noAgeProof;

  /// No description provided for @saveIdentification.
  ///
  /// In pt, this message translates to:
  /// **'Salvar identificação'**
  String get saveIdentification;

  /// No description provided for @ageCheckTitle.
  ///
  /// In pt, this message translates to:
  /// **'Verificação de idade e titularidade'**
  String get ageCheckTitle;

  /// No description provided for @ageCheckUnavailable.
  ///
  /// In pt, this message translates to:
  /// **'A verificação de idade e identidade está indisponível no momento. A compra de álcool continuará bloqueada até a comprovação.'**
  String get ageCheckUnavailable;

  /// No description provided for @receiptCheck.
  ///
  /// In pt, this message translates to:
  /// **'Na entrega, identidade e idade serão conferidas antes do PIN. Para álcool: Brasil 18 anos; Paraguai 20 anos.'**
  String get receiptCheck;

  /// No description provided for @ageExpired.
  ///
  /// In pt, this message translates to:
  /// **'A verificação de idade expirou. É necessária nova verificação válida.'**
  String get ageExpired;

  /// No description provided for @ageRequired.
  ///
  /// In pt, this message translates to:
  /// **'Comprove idade e titularidade para comprar este produto. A data declarada não basta.'**
  String get ageRequired;

  /// No description provided for @language.
  ///
  /// In pt, this message translates to:
  /// **'Idioma'**
  String get language;

  /// No description provided for @freightAmount.
  ///
  /// In pt, this message translates to:
  /// **'Frete: {amount}'**
  String freightAmount(String amount);

  /// No description provided for @extra0.
  ///
  /// In pt, this message translates to:
  /// **'A entrada no Chamaê usa sua conta Google ou Apple. Recupere a senha diretamente no provedor; o Chamaê não recebe nem altera essa senha.'**
  String get extra0;

  /// No description provided for @extra1.
  ///
  /// In pt, this message translates to:
  /// **'Depois, volte e entre com a mesma conta usada no cadastro para recuperar seus pedidos e endereços. Criar outra conta não transfere esses dados.'**
  String get extra1;

  /// No description provided for @extra2.
  ///
  /// In pt, this message translates to:
  /// **'A recuperação e seus prazos dependem do provedor. Nenhuma senha foi redefinida por esta tela.'**
  String get extra2;

  /// No description provided for @extra3.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível carregar seus endereços. Você pode escolher outro destino.'**
  String get extra3;

  /// No description provided for @extra4.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível atualizar seus endereços. Tente novamente.'**
  String get extra4;

  /// No description provided for @extra5.
  ///
  /// In pt, this message translates to:
  /// **'Destino confirmado neste uso. A sincronização está pendente; confira a conexão.'**
  String get extra5;

  /// No description provided for @extra6.
  ///
  /// In pt, this message translates to:
  /// **'Destino selecionado. A sincronização ainda está pendente.'**
  String get extra6;

  /// No description provided for @extra7.
  ///
  /// In pt, this message translates to:
  /// **'Não encontramos esse endereço. Confira rua, número e cidade ou escolha o ponto no mapa.'**
  String get extra7;

  /// No description provided for @extra8.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível atualizar a sessão. Entre novamente pela tela inicial.'**
  String get extra8;

  /// No description provided for @extra9.
  ///
  /// In pt, this message translates to:
  /// **'Não conseguimos identificar o país deste endereço. Confira o ponto selecionado.'**
  String get extra9;

  /// No description provided for @extra10.
  ///
  /// In pt, this message translates to:
  /// **'Um produto da sacola está fora de venda. Remova-o para continuar.'**
  String get extra10;

  /// No description provided for @extra11.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível autenticar. Reinicie o app e tente novamente.'**
  String get extra11;

  /// No description provided for @extra12.
  ///
  /// In pt, this message translates to:
  /// **'Verifique sua conta antes da primeira compra. A navegação continua disponível.'**
  String get extra12;

  /// No description provided for @extra13.
  ///
  /// In pt, this message translates to:
  /// **'A taxa de entrega mudou. Confira o total e o pagamento antes de continuar.'**
  String get extra13;

  /// No description provided for @extra14.
  ///
  /// In pt, this message translates to:
  /// **'A confirmação do envio ainda está pendente. Confira a conexão e tente novamente.'**
  String get extra14;

  /// No description provided for @extra15.
  ///
  /// In pt, this message translates to:
  /// **'Pedido indisponível nesta sessão.'**
  String get extra15;

  /// No description provided for @extra16.
  ///
  /// In pt, this message translates to:
  /// **'A entrega mudou de valor. O pedido não foi enviado. Confira a cotação antes de continuar.'**
  String get extra16;

  /// No description provided for @extra17.
  ///
  /// In pt, this message translates to:
  /// **'Seu pedido já foi recebido. Use Verificar pedido ou Retomar PIX para acompanhá-lo.'**
  String get extra17;

  /// No description provided for @extra18.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível confirmar a revisão. O carrinho foi mantido. Confira a conexão e tente novamente.'**
  String get extra18;

  /// No description provided for @extra19.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível confirmar sua elegibilidade para a compra. Confira seus documentos no perfil e tente novamente.'**
  String get extra19;

  /// No description provided for @extra20.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível iniciar o PIX. Confira sua conexão e tente novamente.'**
  String get extra20;

  /// No description provided for @extra21.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível enviar o pedido. Confira sua conexão e tente novamente.'**
  String get extra21;

  /// No description provided for @extra22.
  ///
  /// In pt, this message translates to:
  /// **'Sua sessão precisa estar atualizada para comprar.'**
  String get extra22;

  /// No description provided for @extra23.
  ///
  /// In pt, this message translates to:
  /// **'Confira o endereço e tente calcular a entrega novamente.'**
  String get extra23;

  /// No description provided for @extra24.
  ///
  /// In pt, this message translates to:
  /// **'Confira sua conexão e tente novamente. Essa falha não confirma o cancelamento do pedido.'**
  String get extra24;

  /// No description provided for @extra25.
  ///
  /// In pt, this message translates to:
  /// **'Pedido indisponível para esta sessão.'**
  String get extra25;

  /// No description provided for @extra26.
  ///
  /// In pt, this message translates to:
  /// **'Confira se você entrou com a conta usada na compra.'**
  String get extra26;

  /// No description provided for @extra27.
  ///
  /// In pt, this message translates to:
  /// **'A confirmação não foi concluída. Confira o pagamento e fale com a loja pelo pedido quando essa opção estiver disponível.'**
  String get extra27;

  /// No description provided for @extra28.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível recuperar seu carrinho. Confira a conexão e tente novamente.'**
  String get extra28;

  /// No description provided for @extra29.
  ///
  /// In pt, this message translates to:
  /// **'Sem confirmação de conexão. O carrinho foi mantido; tente sincronizar novamente.'**
  String get extra29;

  /// No description provided for @extra30.
  ///
  /// In pt, this message translates to:
  /// **'Aguarde a recuperação do carrinho ou tente novamente.'**
  String get extra30;

  /// No description provided for @extra31.
  ///
  /// In pt, this message translates to:
  /// **'Você já adicionou a quantidade disponível.'**
  String get extra31;

  /// No description provided for @extra32.
  ///
  /// In pt, this message translates to:
  /// **'Itens fora de venda foram removidos do carrinho.'**
  String get extra32;

  /// No description provided for @extra33.
  ///
  /// In pt, this message translates to:
  /// **'Calculando entrega...'**
  String get extra33;

  /// No description provided for @extra34.
  ///
  /// In pt, this message translates to:
  /// **'Entrega a calcular'**
  String get extra34;

  /// No description provided for @extra35.
  ///
  /// In pt, this message translates to:
  /// **'Tentar calcular entrega novamente'**
  String get extra35;

  /// No description provided for @extra36.
  ///
  /// In pt, this message translates to:
  /// **'A calcular'**
  String get extra36;

  /// No description provided for @extra37.
  ///
  /// In pt, this message translates to:
  /// **'Frete cotado em BRL'**
  String get extra37;

  /// No description provided for @extra38.
  ///
  /// In pt, this message translates to:
  /// **'Produtos'**
  String get extra38;

  /// No description provided for @extra39.
  ///
  /// In pt, this message translates to:
  /// **'Ex.: Casa 2, ap. 51, portão vermelho...'**
  String get extra39;

  /// No description provided for @extra40.
  ///
  /// In pt, this message translates to:
  /// **'Conta Chamaê excluída. A autorização Apple ainda exige remoção manual.'**
  String get extra40;

  /// No description provided for @extra41.
  ///
  /// In pt, this message translates to:
  /// **'Nova tentativa Apple em andamento'**
  String get extra41;

  /// No description provided for @extra42.
  ///
  /// In pt, this message translates to:
  /// **'Conta Chamaê excluída; autorização Apple pendente'**
  String get extra42;

  /// No description provided for @extra43.
  ///
  /// In pt, this message translates to:
  /// **'A solicitação foi recebida. O processamento continua mesmo se você fechar o app. Verifique o status por aqui.'**
  String get extra43;

  /// No description provided for @extra44.
  ///
  /// In pt, this message translates to:
  /// **'A solicitação está bloqueada nessa verificação. Uma nova tentativa exige confirmar sua identidade novamente.'**
  String get extra44;

  /// No description provided for @extra45.
  ///
  /// In pt, this message translates to:
  /// **'Endereço oficial copiado. Abra no seu navegador.'**
  String get extra45;

  /// No description provided for @extra46.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível copiar. Use o endereço exibido abaixo.'**
  String get extra46;

  /// No description provided for @extra47.
  ///
  /// In pt, this message translates to:
  /// **'Copiar endereço da Conta Apple'**
  String get extra47;

  /// No description provided for @routeDistance.
  ///
  /// In pt, this message translates to:
  /// **'Distância de rota: {distance} km'**
  String routeDistance(String distance);

  /// No description provided for @destinationLabel.
  ///
  /// In pt, this message translates to:
  /// **'Destino: {country}'**
  String destinationLabel(String country);

  /// No description provided for @countryUnknown.
  ///
  /// In pt, this message translates to:
  /// **'País não confirmado'**
  String get countryUnknown;

  /// No description provided for @languageSaveFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível salvar o idioma neste aparelho.'**
  String get languageSaveFailed;

  /// No description provided for @address0.
  ///
  /// In pt, this message translates to:
  /// **'Rua'**
  String get address0;

  /// No description provided for @address1.
  ///
  /// In pt, this message translates to:
  /// **'Bairro'**
  String get address1;

  /// No description provided for @address2.
  ///
  /// In pt, this message translates to:
  /// **'Cidade'**
  String get address2;

  /// No description provided for @address3.
  ///
  /// In pt, this message translates to:
  /// **'Estado'**
  String get address3;

  /// No description provided for @address4.
  ///
  /// In pt, this message translates to:
  /// **'Nome'**
  String get address4;

  /// No description provided for @address5.
  ///
  /// In pt, this message translates to:
  /// **'Contato'**
  String get address5;

  /// No description provided for @fieldRequired.
  ///
  /// In pt, this message translates to:
  /// **'Informe {field}'**
  String fieldRequired(String field);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['es', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'es':
      {
        switch (locale.countryCode) {
          case 'PY':
            return AppLocalizationsEsPy();
        }
        break;
      }
    case 'pt':
      {
        switch (locale.countryCode) {
          case 'BR':
            return AppLocalizationsPtBr();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'es':
      return AppLocalizationsEs();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
