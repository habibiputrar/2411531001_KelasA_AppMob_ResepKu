import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:resepku/main.dart';
import 'package:resepku/models/favorite.dart';
import 'package:resepku/models/recipe.dart';
import 'package:resepku/providers/favorite_provider.dart';
import 'package:resepku/providers/settings_provider.dart';
import 'package:resepku/services/recipe_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'fakes.dart';
import 'recipe_fixtures.dart';

Future<FavoriteProvider> launch(
  WidgetTester tester,
  MemoryFavoriteStore store,
) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final settings = SettingsProvider();
  final favorites = FavoriteProvider(store);
  await settings.load();
  await favorites.load();
  final service = RecipeService(
    client: MockClient(
      (_) async => http.Response(
        jsonEncode({'recipes': dummyRecipes.map((r) => r.toJson()).toList()}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    ),
  );
  addTearDown(service.close);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: favorites),
        Provider<RecipeService>.value(value: service),
      ],
      child: const ResepKuApp(),
    ),
  );
  await tester.pumpAndSettle();
  return favorites;
}

Favorite saved(int index, {String note = ''}) => Favorite(
  recipe: Recipe.fromJson({
    ...dummyRecipes[index].toJson(),
    'instructions': ['Langkah lokal lengkap'],
  }),
  savedAt: DateTime(2026, 11, index + 1),
  note: note,
);

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  testWidgets('Persisted grid and dark theme appear at startup on 360dp', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
          SettingsProvider.keyGrid: true,
          SettingsProvider.keyDark: true,
        });
    await launch(tester, MemoryFavoriteStore());
    expect(
      find.byType(GridView),
      findsOneWidget,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .toString(),
    );
    expect(
      Theme.of(tester.element(find.byType(GridView))).brightness,
      Brightness.dark,
    );
    expect(find.byTooltip('Cari resep'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Saved note, local detail, and removal from detail update badge',
    (tester) async {
      final favorites = await launch(
        tester,
        MemoryFavoriteStore([saved(0, note: 'Tambah keju')]),
      );
      await tester.tap(find.byTooltip('Favorit saya'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Tambah keju'), findsOneWidget);
      await tester.tap(find.text(dummyRecipes.first.name));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.text('Langkah lokal lengkap'), findsOneWidget);
      await tester.tap(find.byTooltip('Hapus dari favorit'));
      await tester.pumpAndSettle();
      expect(favorites.count, 0);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.textContaining('Belum ada resep favorit.'), findsOneWidget);
    },
  );

  testWidgets('Note dialog cancellation and trimmed save persist', (
    tester,
  ) async {
    final store = MemoryFavoriteStore([saved(0)]);
    await launch(tester, store);
    await tester.tap(find.byTooltip('Favorit saya'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Catatan'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'discard');
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect((await store.getAll()).single.note, '');
    await tester.tap(find.byTooltip('Catatan'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Kurangi garam  ');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect((await store.getAll()).single.note, 'Kurangi garam');
    expect(find.textContaining('Kurangi garam'), findsOneWidget);
  });

  testWidgets(
    'Settings clear confirmation cancels or deletes persistent favorites',
    (tester) async {
      final store = MemoryFavoriteStore([saved(0), saved(1)]);
      final favorites = await launch(tester, store);
      await tester.tap(find.byTooltip('Pengaturan'));
      await tester.pumpAndSettle();
      expect(find.text('2 resep tersimpan'), findsOneWidget);
      await tester.tap(find.text('Hapus semua favorit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(favorites.count, 2);
      await tester.tap(find.text('Hapus semua favorit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();
      expect(favorites.count, 0);
      expect(await store.getAll(), isEmpty);
      expect(find.text('Semua favorit berhasil dihapus.'), findsOneWidget);
    },
  );

  testWidgets(
    'Sort applies to a copy and is saved for a new settings instance',
    (tester) async {
      final favorites = await launch(
        tester,
        MemoryFavoriteStore([saved(0), saved(1)]),
      );
      final original = favorites.items.map((f) => f.recipe.id).toList();
      await tester.tap(find.byTooltip('Favorit saya'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Urutan favorit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nama A–Z').last);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text(dummyRecipes[0].name)).dy,
        lessThan(tester.getTopLeft(find.text(dummyRecipes[1].name)).dy),
      );
      expect(favorites.items.map((f) => f.recipe.id), original);
      final reopened = SettingsProvider();
      await reopened.load();
      expect(reopened.favoriteSort, FavoriteSort.name);
    },
  );

  testWidgets('Failed swipe retains favorite and shows an error', (
    tester,
  ) async {
    final store = MemoryFavoriteStore([saved(0)]);
    final favorites = await launch(tester, store);
    await tester.tap(find.byTooltip('Favorit saya'));
    await tester.pumpAndSettle();
    store.failWrites = true;
    await tester.drag(
      find.byKey(ValueKey(dummyRecipes.first.id)),
      const Offset(-450, 0),
    );
    await tester.pumpAndSettle();
    expect(favorites.count, 1);
    expect(find.textContaining('Gagal menyimpan perubahan'), findsOneWidget);
    expect(find.textContaining('dihapus dari favorit.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Cooked count is saved and note is preserved', (tester) async {
    final store = MemoryFavoriteStore([saved(0, note: 'Catatan tetap')]);
    final provider = await launch(tester, store);
    await tester.tap(find.byTooltip('Favorit saya'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sudah dimasak'));
    await tester.pumpAndSettle();
    expect(find.text('Dimasak 1 kali'), findsOneWidget);
    expect(provider.items.single.note, 'Catatan tetap');
    expect((await store.getAll()).single.cookedCount, 1);
    await provider.updateNote(dummyRecipes.first.id, 'Catatan baru');
    await tester.pumpAndSettle();
    expect(provider.items.single.cookedCount, 1);
  });
}
