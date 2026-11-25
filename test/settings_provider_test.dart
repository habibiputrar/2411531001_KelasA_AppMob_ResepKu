import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resepku/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  test('Default list, light theme and newest sort', () async {
    final settings = SettingsProvider(prefs: SharedPreferencesAsync());
    await settings.load();
    expect(settings.isGrid, false);
    expect(settings.isDark, false);
    expect(settings.themeMode, ThemeMode.light);
    expect(settings.favoriteSort, FavoriteSort.newest);
  });

  test('New instance reads grid, dark mode and sort', () async {
    final settings = SettingsProvider();
    await settings.setGrid(true);
    await settings.setDark(true);
    await settings.setFavoriteSort(FavoriteSort.name);
    final reopened = SettingsProvider();
    await reopened.load();
    expect(reopened.isGrid, true);
    expect(reopened.themeMode, ThemeMode.dark);
    expect(reopened.favoriteSort, FavoriteSort.name);
  });

  test('Unknown saved sort falls back to newest', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
          SettingsProvider.keyFavoriteSort: 'invalid',
        });
    final settings = SettingsProvider();
    await settings.load();
    expect(settings.favoriteSort, FavoriteSort.newest);
  });

  test('Each loaded or saved setting notifies listeners', () async {
    final settings = SettingsProvider();
    var notifications = 0;
    settings.addListener(() => notifications++);
    await settings.load();
    await settings.setDark(true);
    await settings.setGrid(true);
    await settings.setFavoriteSort(FavoriteSort.name);
    expect(notifications, 4);
  });

  test('Concurrent settings writes retain call order', () async {
    final settings = SettingsProvider();
    await Future.wait([settings.setDark(true), settings.setDark(false)]);
    final reopened = SettingsProvider();
    await reopened.load();
    expect(settings.isDark, false);
    expect(reopened.isDark, false);
  });
  test(
    'Failed setting write does not change state or notify success',
    () async {
      final settings = SettingsProvider(prefs: RejectingPreferences());
      var notified = 0;
      settings.addListener(() => notified++);
      await expectLater(settings.setGrid(true), throwsStateError);
      expect(settings.isGrid, false);
      expect(notified, 0);
    },
  );
}

class RejectingPreferences extends SharedPreferencesAsync {
  @override
  Future<void> setBool(String key, bool value) async {
    throw StateError('Disk write failed');
  }
}
