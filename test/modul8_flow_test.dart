import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:resepku/main.dart';
import 'package:resepku/providers/favorite_provider.dart';
import 'package:resepku/providers/settings_provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'fakes.dart';

import 'package:resepku/services/recipe_service.dart';

const _recipe = {
  'id': 1,
  'name': 'Pasta Uji',
  'ingredients': ['Pasta'],
  'instructions': ['Rebus pasta.'],
};

http.Response _json(Object value) => http.Response(jsonEncode(value), 200);

Future<FavoriteProvider> _launch(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) handler,
) async {
  final favorites = FavoriteProvider(MemoryFavoriteStore());
  final service = RecipeService(client: MockClient(handler));
  addTearDown(service.close);
  addTearDown(favorites.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<RecipeService>.value(value: service),
        ChangeNotifierProvider.value(value: favorites),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: const ResepKuApp(),
    ),
  );
  return favorites;
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  testWidgets(
    'Loading, offline retry, refresh and grid preserve two favorites',
    (tester) async {
      final initial = Completer<http.Response>();
      final refreshing = Completer<http.Response>();
      const second = {'id': 2, 'name': 'Pizza Uji'};
      final data = _json({
        'recipes': [_recipe, second],
      });
      var gets = 0;

      final favorites = await _launch(tester, (_) async {
        gets++;
        if (gets == 1) return initial.future;
        if (gets == 3) return refreshing.future;
        return data;
      });

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      initial.completeError(http.ClientException('Simulated offline'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Tambah ke favorit').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Tambah ke favorit').first);
      await tester.pumpAndSettle();
      expect(favorites.count, 2);

      await tester.drag(find.byType(ListView).last, const Offset(0, 350));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(gets, 3);
      expect(find.text('Pasta Uji'), findsOneWidget);
      expect(find.byType(RefreshProgressIndicator), findsOneWidget);
      refreshing.complete(data);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Hapus dari favorit'), findsNWidgets(2));

      await tester.tap(find.byTooltip('Tampilan grid'));
      await tester.pumpAndSettle();
      expect(find.byType(GridView), findsOneWidget);
      await tester.tap(find.byTooltip('Tampilan list'));
      await tester.pumpAndSettle();
      expect(gets, 3);
    },
  );

  testWidgets('Search encodes input and handles results, empty and error', (
    tester,
  ) async {
    await _launch(tester, (request) async {
      if (request.url.path == '/recipes') {
        return _json({
          'recipes': [_recipe],
        });
      }
      expect(request.url.path, '/recipes/search');
      return switch (request.url.queryParameters['q']) {
        'pasta & keju' => _json({
          'recipes': [_recipe],
        }),
        'kosong' => _json({'recipes': []}),
        'offline' => throw http.ClientException('Simulated offline'),
        _ => throw StateError('Unexpected search'),
      };
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cari resep'));
    await tester.pumpAndSettle();

    Future<void> submit(String query) async {
      await tester.enterText(find.byType(TextField), query);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
    }

    await submit('pasta & keju');
    expect(find.text('Pasta Uji'), findsOneWidget);
    await submit('kosong');
    expect(find.text('Resep tidak ditemukan.'), findsOneWidget);
    await submit('offline');
    expect(find.text('Coba lagi'), findsOneWidget);
  });

  testWidgets('POST validates input and displays the returned simulated ID', (
    tester,
  ) async {
    var posts = 0;
    await _launch(tester, (request) async {
      if (request.method == 'GET') {
        return _json({
          'recipes': [_recipe],
        });
      }
      posts++;
      expect(request.method, 'POST');
      expect(request.url.path, '/recipes/add');
      expect(jsonDecode(request.body), {
        'name': 'Rendang',
        'cuisine': 'Indonesian',
        'cookTimeMinutes': 180,
      });
      return http.Response('{"id":51,"name":"Rendang"}', 201);
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tambah resep'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Wajib diisi'), findsNWidgets(2));
    expect(posts, 0);

    for (final (index, value) in ['Rendang', 'Indonesian', '180'].indexed) {
      await tester.enterText(find.byType(TextFormField).at(index), value);
    }
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(posts, 1);
    expect(find.textContaining('ID 51'), findsOneWidget);
  });

  testWidgets('Sliver detail shows instructions and confirms PUT and DELETE', (
    tester,
  ) async {
    final mutations = <String>[];
    await _launch(tester, (request) async {
      if (request.method == 'GET') {
        return _json({
          'recipes': [_recipe],
        });
      }
      expect(request.url.path, '/recipes/1');
      mutations.add(request.method);
      if (request.method == 'PUT') {
        expect(jsonDecode(request.body), {'name': 'Pasta Baru'});
        return _json({..._recipe, 'name': 'Pasta Baru'});
      }
      return _json({'isDeleted': true});
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pasta Uji'));
    await tester.pumpAndSettle();
    expect(find.byType(SliverAppBar), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('Rebus pasta.'), findsOneWidget);

    Future<void> menu(String action) async {
      await tester.tap(find.byTooltip('Aksi resep'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(action));
      await tester.pumpAndSettle();
    }

    await menu('Ubah nama');
    await tester.enterText(find.byType(TextFormField), 'Pasta Baru');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Nama dari server: "Pasta Baru"'),
      findsOneWidget,
    );

    await menu('Hapus');
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(mutations, ['PUT']);

    await menu('Hapus');
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(mutations, ['PUT', 'DELETE']);
    expect(find.byType(SliverAppBar), findsNothing);
    expect(find.textContaining('dihapus dalam simulasi'), findsOneWidget);
  });
}
