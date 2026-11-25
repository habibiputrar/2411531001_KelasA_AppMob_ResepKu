import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:resepku/data/favorite_database.dart';
import 'package:resepku/models/favorite.dart';
import 'package:resepku/models/recipe.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const recipe = Recipe(
  id: 1,
  name: 'Rendang',
  cuisine: 'Indonesian',
  difficulty: 'Hard',
  prepTimeMinutes: 30,
  cookTimeMinutes: 180,
  servings: 6,
  caloriesPerServing: 450,
  rating: 4.9,
  image: '',
  ingredients: ['Daging', 'Santan'],
  instructions: ['Tumis bumbu', 'Masak hingga kering'],
);
final first = Favorite(recipe: recipe, savedAt: DateTime(2026, 10, 1));
final second = Favorite(
  recipe: Recipe.fromJson({...recipe.toJson(), 'id': 2, 'name': 'Soto'}),
  savedAt: DateTime(2026, 10, 2),
);

void main() {
  sqfliteFfiInit();
  late FavoriteDatabase db;
  setUp(
    () => db = FavoriteDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    ),
  );
  tearDown(() => db.close());

  test(
    'Recipe and Favorite round trip preserves complete recipe and timestamp',
    () async {
      await db.insert(first);
      final saved = (await db.getAll()).single;
      expect(saved.recipe.toJson(), recipe.toJson());
      expect(saved.savedAt, first.savedAt);
      expect(saved.note, '');
      expect(saved.copyWith(note: 'Pedas').savedAt, first.savedAt);
      expect(saved.copyWith(note: 'Pedas').recipe, same(saved.recipe));
    },
  );

  test(
    'Newest first, replace same id, update note and parameterized delete',
    () async {
      await db.insert(first);
      await db.insert(second);
      expect((await db.getAll()).map((f) => f.recipe.id), [2, 1]);
      await db.insert(first.copyWith(note: "Chef's favorite"));
      expect(await db.getAll(), hasLength(2));
      await db.updateNote(1, "Kurangi garam ' 1=1");
      expect((await db.getAll()).last.note, "Kurangi garam ' 1=1");
      await db.delete(1);
      expect((await db.getAll()).single.recipe.id, 2);
      await db.deleteAll();
      expect(await db.getAll(), isEmpty);
    },
  );

  test('Concurrent initial reads share a single open', () async {
    await Future.wait([db.getAll(), db.getAll()]);
    await db.insert(first);
    expect(await db.getAll(), hasLength(1));
  });

  test('Migration v1 directly to v3 keeps both complete recipes and allows notes', () async {
    final dir = await Directory.systemTemp.createTemp('resepku_migration_');
    final path = p.join(dir.path, 'resepku.db');
    final old = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => db.execute(
          'CREATE TABLE favorites (id INTEGER PRIMARY KEY, '
          'name TEXT NOT NULL, data TEXT NOT NULL, saved_at INTEGER NOT NULL)',
        ),
      ),
    );
    for (final favorite in [first, second]) {
      await old.insert('favorites', {
        'id': favorite.recipe.id,
        'name': favorite.recipe.name,
        'data': jsonEncode(favorite.recipe.toJson()),
        'saved_at': favorite.savedAt.millisecondsSinceEpoch,
      });
    }
    await old.close();
    final upgraded = FavoriteDatabase(factory: databaseFactoryFfi, path: path);
    try {
      final all = await upgraded.getAll();
      expect(all.map((f) => f.recipe.id), [2, 1]);
      expect(all.last.recipe.toJson(), recipe.toJson());
      expect(all.last.savedAt, first.savedAt);
      expect(all.every((f) => f.note.isEmpty), true);
      expect(all.every((f) => f.cookedCount == 0), true);
      await upgraded.updateNote(1, 'Pedas');
      await upgraded.close();
      expect((await upgraded.getAll()).last.note, 'Pedas');
    } finally {
      await upgraded.close();
      await dir.delete(recursive: true);
    }
  });
  test('Increment is atomic and preserves note and saved time', () async {
    await db.insert(first.copyWith(note: 'Tetap ada'));
    await Future.wait(List.generate(8, (_) => db.incrementCooked(1)));
    final saved = (await db.getAll()).single;
    expect(saved.cookedCount, 8);
    expect(saved.note, 'Tetap ada');
    expect(saved.savedAt, first.savedAt);
    expect(saved.copyWith(note: 'Baru').cookedCount, 8);
    expect(saved.copyWith(cookedCount: 9).note, 'Tetap ada');
  });

  test('Migration v2 to v3 retains notes, dates and recipe data', () async {
    final dir = await Directory.systemTemp.createTemp('resepku_v2_');
    final path = p.join(dir.path, 'resepku.db');
    final old = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, _) => db.execute(
          "CREATE TABLE favorites (id INTEGER PRIMARY KEY, name TEXT NOT NULL, "
          "data TEXT NOT NULL, saved_at INTEGER NOT NULL, note TEXT NOT NULL DEFAULT '')",
        ),
      ),
    );
    await old.insert('favorites', {
      'id': 1,
      'name': recipe.name,
      'data': jsonEncode(recipe.toJson()),
      'saved_at': first.savedAt.millisecondsSinceEpoch,
      'note': 'Catatan versi dua',
    });
    await old.close();
    final upgraded = FavoriteDatabase(factory: databaseFactoryFfi, path: path);
    try {
      final saved = (await upgraded.getAll()).single;
      expect(saved.recipe.toJson(), recipe.toJson());
      expect(saved.note, 'Catatan versi dua');
      expect(saved.savedAt, first.savedAt);
      expect(saved.cookedCount, 0);
      await upgraded.incrementCooked(1);
      await upgraded.close();
      expect((await upgraded.getAll()).single.cookedCount, 1);
    } finally {
      await upgraded.close();
      await dir.delete(recursive: true);
    }
  });
}
