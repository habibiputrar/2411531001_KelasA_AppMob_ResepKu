import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FavoriteSort { newest, name }

class SettingsProvider extends ChangeNotifier {
  SettingsProvider({SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  static const keyGrid = 'is_grid';
  static const keyDark = 'is_dark';
  static const keyFavoriteSort = 'favorite_sort';
  final SharedPreferencesAsync _prefs;
  bool _isGrid = false;
  bool _isDark = false;
  FavoriteSort _favoriteSort = FavoriteSort.newest;
  Future<void> _pending = Future.value();

  bool get isGrid => _isGrid;
  bool get isDark => _isDark;
  FavoriteSort get favoriteSort => _favoriteSort;
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> load() => _enqueue(() async {
    final grid = await _prefs.getBool(keyGrid) ?? false;
    final dark = await _prefs.getBool(keyDark) ?? false;
    final name = await _prefs.getString(keyFavoriteSort);
    _isGrid = grid;
    _isDark = dark;
    _favoriteSort =
        FavoriteSort.values.asNameMap()[name] ?? FavoriteSort.newest;
    notifyListeners();
  });

  Future<void> setGrid(bool value) => _enqueue(() async {
    await _prefs.setBool(keyGrid, value);
    _isGrid = value;
    notifyListeners();
  });

  Future<void> setDark(bool value) => _enqueue(() async {
    await _prefs.setBool(keyDark, value);
    _isDark = value;
    notifyListeners();
  });

  Future<void> setFavoriteSort(FavoriteSort value) => _enqueue(() async {
    await _prefs.setString(keyFavoriteSort, value.name);
    _favoriteSort = value;
    notifyListeners();
  });
}
