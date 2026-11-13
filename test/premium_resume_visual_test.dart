import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/core/models.dart';
import 'package:chamae_delivery/core/theme.dart';
import 'package:chamae_delivery/data/binational_identity.dart';
import 'package:chamae_delivery/l10n/customer_localizations.dart';
import 'package:chamae_delivery/l10n/locale_controller.dart';
import 'package:chamae_delivery/screens/home_screen.dart';
import 'package:chamae_delivery/screens/customer_profile_screen.dart';
import 'package:chamae_delivery/screens/customer_identification_screen.dart';
import 'package:chamae_delivery/screens/cart_screen.dart';
import 'support/customer_flow_fakes.dart';
import 'package:chamae_delivery/widgets/commerce_components.dart';

class _Identity implements IdentificationRepository {
  @override
  Future<void> save(BinationalIdentity value) async {}
}

void main() {
  setUpAll(() async {
    const dir = 'C:/flutter/bin/cache/artifacts/material_fonts';
    for (final font in [
      ('Roboto', 'roboto-regular.ttf'),
      ('Ahem', 'roboto-regular.ttf'),
      ('MaterialIcons', 'materialicons-regular.otf')
    ]) {
      await (FontLoader(font.$1)
            ..addFont(File('$dir/${font.$2}')
                .readAsBytes()
                .then(ByteData.sublistView)))
          .load();
    }
  });
  for (final width in [320.0, 390.0, 430.0]) {
    for (final language in ['pt', 'es']) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('premium rendered $width/$language/$scale', (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final locale = LocaleController(
              stored: language == 'es' ? 'es-PY' : 'pt-BR',
              persist: (_) async {});
          addTearDown(locale.dispose);
          final key = GlobalKey();
          Future<void> show(Widget page) async {
            await tester.pumpWidget(LocaleScope(
                controller: locale,
                child: MaterialApp(
                    theme: AppTheme.lightTheme,
                    locale: Locale(language),
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    builder: (context, child) => MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                            textScaler: TextScaler.linear(scale),
                            padding: const EdgeInsets.only(top: 47, bottom: 34),
                            viewPadding:
                                const EdgeInsets.only(top: 47, bottom: 34)),
                        child: RepaintBoundary(key: key, child: child!)),
                    home: page)));
            await tester.pumpAndSettle();
          }

          Future<void> capture(String page) async {
            final dest = Platform.environment['CHAMAE_RESUME_CAPTURE_DIR'];
            if (dest == null) return;
            await tester.runAsync(() async {
              final boundary = key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 2),
                  bytes =
                      await image.toByteData(format: ui.ImageByteFormat.png);
              Directory(dest).createSync(recursive: true);
              File('$dest/$page-${width.toInt()}-$language-s${scale.toInt()}.png')
                  .writeAsBytesSync(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }

          final product = Product(
              id: 'synthetic',
              name: 'Água teste HML — não comercializar',
              category: 'Águas',
              price: 20,
              stock: 15,
              isActive: true,
              imageUrl: '',
              description: 'Produto sintético sem imagem cadastrada.',
              isOffer: false,
              isCombo: false,
              salesCount: 0);
          await show(DeliveryHomeScreen(products: Stream.value([product])));
          expect(find.textContaining('Delivery todos os dias'), findsNothing);
          expect(find.textContaining('Delivery todos los'), findsNothing);
          await capture('home');
          expect(tester.takeException(), isNull);
          await tester.tap(
              find.text(language == 'es' ? 'Categorías' : 'Categorias').last);
          await tester.pumpAndSettle();
          await capture('categories');
          expect(tester.takeException(), isNull);
          await show(CustomerProfileScreen(
              onboarding: FlowOnboarding(accepted: true),
              selectAddress: () async {}));
          await capture('profile');
          expect(tester.takeException(), isNull);
          await show(CustomerIdentificationScreen(
              profile: const {}, repository: _Identity(), onComplete: () {}));
          await capture('identification');
          await tester.scrollUntilVisible(find.byType(FilledButton), 180,
              scrollable: find.byType(Scrollable).first);
          await tester.pumpAndSettle();
          await capture('identification-footer');
          expect(tester.takeException(), isNull);
          await show(CartScreen(
              items: () => [
                    CartItem(
                        id: 'synthetic',
                        name: product.name,
                        price: 20,
                        imageUrl: '',
                        quantity: 10)
                  ],
              change: (_, __) {},
              checkout: () {}));
          await capture('cart');
          await tester.scrollUntilVisible(find.byType(GoldPrimaryButton), 180,
              scrollable: find.byType(Scrollable).first);
          await tester.pumpAndSettle();
          await capture('cart-summary');
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
}
