import 'package:flutter_test/flutter_test.dart';
import 'package:resepku/models/favorite.dart';
import 'package:resepku/providers/favorite_provider.dart';

import 'fakes.dart';
import 'recipe_fixtures.dart';

void main() {
  test('Load retains recipe, savedAt, note and immutable items', () async {
    final saved = Favorite(
      recipe: dummyRecipes.first,
      savedAt: DateTime(2026, 11, 1),
      note: 'Pedas',
    );
    final provider = FavoriteProvider(MemoryFavoriteStore([saved]));
    await provider.load();
    expect(provider.count, 1);
    expect(provider.items.single.note, 'Pedas');
    expect(() => provider.items.clear(), throwsUnsupportedError);
    expect(provider.isFavorite(dummyRecipes.first), true);
  });

  test('Writes persist across provider instances and trim note', () async {
    final store = MemoryFavoriteStore();
    final provider = FavoriteProvider(store);
    var notifications = 0;
    provider.addListener(() => notifications++);
    await provider.toggle(dummyRecipes.first);
    final time = provider.items.single.savedAt;
    await provider.updateNote(dummyRecipes.first.id, '  Tambah keju  ');
    final reopened = FavoriteProvider(store);
    await reopened.load();
    expect(reopened.items.single.note, 'Tambah keju');
    expect(reopened.items.single.savedAt, time);
    expect(notifications, 2);
    await reopened.toggle(dummyRecipes.first);
    expect(await store.getAll(), isEmpty);
    await reopened.toggle(dummyRecipes[1]);
    await reopened.clear();
    expect(reopened.count, 0);
    expect(await store.getAll(), isEmpty);
  });

  test('Failed writes leave memory unchanged and allow retry', () async {
    final store = MemoryFavoriteStore();
    final provider = FavoriteProvider(store);
    store.failWrites = true;
    await expectLater(provider.toggle(dummyRecipes.first), throwsStateError);
    expect(provider.count, 0);
    store.failWrites = false;
    await provider.toggle(dummyRecipes.first);
    final original = provider.items.single;
    store.failWrites = true;
    await expectLater(
      provider.updateNote(original.recipe.id, 'new'),
      throwsStateError,
    );
    await expectLater(provider.toggle(original.recipe), throwsStateError);
    await expectLater(provider.clear(), throwsStateError);
    expect(provider.items.single, same(original));
    store.failWrites = false;
    await provider.clear();
    expect(provider.count, 0);
  });

  test('Queued toggle and clear agree with storage', () async {
    final store = MemoryFavoriteStore();
    final provider = FavoriteProvider(store);
    await Future.wait([
      provider.toggle(dummyRecipes.first),
      provider.toggle(dummyRecipes.first),
      provider.toggle(dummyRecipes[1]),
      provider.clear(),
    ]);
    expect(provider.count, 0);
    expect(await store.getAll(), isEmpty);
  });
}
