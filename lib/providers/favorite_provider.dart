import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:resepku/data/favorite_database.dart';
import 'package:resepku/models/favorite.dart';
import 'package:resepku/models/recipe.dart';

class FavoriteProvider extends ChangeNotifier {
  FavoriteProvider(this._store);
  final FavoriteStore _store;
  List<Favorite> _items = [];
  Future<void> _pending = Future.value();

  UnmodifiableListView<Favorite> get items => UnmodifiableListView(_items);
  int get count => _items.length;
  bool isFavorite(Recipe recipe) => _items.any((f) => f.recipe.id == recipe.id);

  // Serialisasi menjaga urutan toggle, catatan, dan hapus semua saat dipanggil cepat.
  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> load() => _enqueue(() async {
    _items = await _store.getAll();
    notifyListeners();
  });

  Future<void> toggle(Recipe recipe) => _enqueue(() async {
    if (isFavorite(recipe)) {
      await _store.delete(recipe.id);
      _items.removeWhere((f) => f.recipe.id == recipe.id);
    } else {
      final item = Favorite(recipe: recipe, savedAt: DateTime.now());
      await _store.insert(item);
      _items = [item, ..._items];
    }
    notifyListeners();
  });

  Future<void> updateNote(int id, String note) => _enqueue(() async {
    final index = _items.indexWhere((f) => f.recipe.id == id);
    if (index < 0) return;
    final trimmed = note.trim();
    await _store.updateNote(id, trimmed);
    _items[index] = _items[index].copyWith(note: trimmed);
    notifyListeners();
  });

  Future<void> incrementCooked(int id) => _enqueue(() async {
    final index = _items.indexWhere((f) => f.recipe.id == id);
    if (index < 0) return;
    await _store.incrementCooked(id);
    _items[index] = _items[index].copyWith(
      cookedCount: _items[index].cookedCount + 1,
    );
    notifyListeners();
  });

  Future<void> clear() => _enqueue(() async {
    await _store.deleteAll();
    _items = [];
    notifyListeners();
  });
}
