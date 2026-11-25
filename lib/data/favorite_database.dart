import 'package:path/path.dart' as p;
import 'package:resepku/models/favorite.dart';
import 'package:sqflite/sqflite.dart';

abstract interface class FavoriteStore {
  Future<List<Favorite>> getAll();
  Future<void> insert(Favorite favorite);
  Future<void> updateNote(int id, String note);
  Future<void> incrementCooked(int id);
  Future<void> delete(int id);
  Future<void> deleteAll();
}

class FavoriteDatabase implements FavoriteStore {
  FavoriteDatabase({DatabaseFactory? factory, this.path})
    : _factory = factory ?? databaseFactorySqflitePlugin;
  final DatabaseFactory _factory;
  final String? path;
  static const _version = 3;
  Future<Database>? _opening;

  Future<Database> get _database => _opening ??= _open();

  Future<Database> _open() async {
    try {
      final dbPath =
          path ?? p.join(await _factory.getDatabasesPath(), 'resepku.db');
      return await _factory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: _version,
          onCreate: (db, version) => db.execute(
            'CREATE TABLE favorites (id INTEGER PRIMARY KEY, name TEXT NOT NULL, '
            "data TEXT NOT NULL, saved_at INTEGER NOT NULL, note TEXT NOT NULL DEFAULT '', "
            'cooked_count INTEGER NOT NULL DEFAULT 0)',
          ),
          onUpgrade: (db, oldVersion, newVersion) async {
            if (oldVersion < 2) {
              await db.execute(
                "ALTER TABLE favorites ADD COLUMN note TEXT NOT NULL DEFAULT ''",
              );
            }
            if (oldVersion < 3) {
              await db.execute(
                'ALTER TABLE favorites ADD COLUMN cooked_count INTEGER NOT NULL DEFAULT 0',
              );
            }
          },
        ),
      );
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  @override
  Future<List<Favorite>> getAll() async {
    final db = await _database;
    return (await db.query(
      'favorites',
      orderBy: 'saved_at DESC',
    )).map(Favorite.fromMap).toList();
  }

  @override
  Future<void> insert(Favorite favorite) async {
    final db = await _database;
    await db.insert(
      'favorites',
      favorite.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateNote(int id, String note) async {
    final db = await _database;
    await db.update(
      'favorites',
      {'note': note},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> incrementCooked(int id) async {
    final db = await _database;
    await db.rawUpdate(
      'UPDATE favorites SET cooked_count = cooked_count + 1 WHERE id = ?',
      [id],
    );
  }

  @override
  Future<void> delete(int id) async {
    final db = await _database;
    await db.delete('favorites', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> deleteAll() async {
    final db = await _database;
    await db.delete('favorites');
  }

  Future<void> close() async {
    final opening = _opening;
    if (opening == null) return;
    final db = await opening;
    await db.close();
    _opening = null;
  }
}
