import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleController extends ChangeNotifier {
  LocaleController({String? stored, required this.persist})
      : _locale = parse(stored);
  final Future<void> Function(String) persist;
  Locale? _locale;
  Locale? get locale => _locale;
  static Locale? parse(String? value) => switch (value) {
        'pt-BR' => const Locale('pt', 'BR'),
        'es-PY' => const Locale('es', 'PY'),
        _ => null,
      };
  static Locale resolve(Locale? device) => device?.languageCode == 'es'
      ? const Locale('es', 'PY')
      : const Locale('pt', 'BR');
  Future<void> set(String tag) async {
    final next = parse(tag);
    if (next == null) throw ArgumentError('LOCALE_UNSUPPORTED');
    await persist(tag);
    _locale = next;
    notifyListeners();
  }

  static Future<LocaleController> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return LocaleController(
          stored: prefs.getString('chamae_language'),
          persist: (value) async {
            await prefs.setString('chamae_language', value);
          });
    } catch (_) {
      return LocaleController(persist: (_) async {
        throw StateError('LANGUAGE_STORAGE_UNAVAILABLE');
      });
    }
  }
}
