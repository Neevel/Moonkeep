import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'moonkeep_theme.dart';

abstract interface class MoonkeepThemeStore {
  Future<String?> read();
  Future<void> write(String value);
}

class SharedPreferencesMoonkeepThemeStore implements MoonkeepThemeStore {
  SharedPreferencesMoonkeepThemeStore([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const key = 'moonkeep.theme.v1';
  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read() => _preferences.getString(key);

  @override
  Future<void> write(String value) => _preferences.setString(key, value);
}

class MoonkeepThemeController extends ChangeNotifier {
  MoonkeepThemeController({
    MoonkeepThemeId initialTheme = MoonkeepThemeId.moonkeep,
    MoonkeepThemeStore? store,
  }) : this._(initialTheme, store);

  MoonkeepThemeController._(this._themeId, this._store);

  final MoonkeepThemeStore? _store;
  MoonkeepThemeId _themeId;

  MoonkeepThemeId get themeId => _themeId;

  static Future<MoonkeepThemeController> load({
    MoonkeepThemeStore? store,
  }) async {
    final preferences = store ?? SharedPreferencesMoonkeepThemeStore();
    MoonkeepThemeId themeId = MoonkeepThemeId.moonkeep;
    try {
      final stored = await preferences.read();
      themeId = MoonkeepThemeId.values.firstWhere(
        (value) => value.name == stored,
        orElse: () => MoonkeepThemeId.moonkeep,
      );
    } catch (_) {
      // A local preference failure must never prevent Moonkeep from starting.
    }
    return MoonkeepThemeController(initialTheme: themeId, store: preferences);
  }

  Future<void> select(MoonkeepThemeId themeId) async {
    if (themeId == _themeId) return;
    final previous = _themeId;
    _themeId = themeId;
    notifyListeners();
    try {
      await _store?.write(themeId.name);
    } catch (_) {
      _themeId = previous;
      notifyListeners();
      rethrow;
    }
  }
}

class MoonkeepThemeScope extends InheritedNotifier<MoonkeepThemeController> {
  const MoonkeepThemeScope({
    super.key,
    required MoonkeepThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static MoonkeepThemeController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<MoonkeepThemeScope>();
    assert(scope != null, 'MoonkeepThemeScope is missing.');
    return scope!.notifier!;
  }
}
