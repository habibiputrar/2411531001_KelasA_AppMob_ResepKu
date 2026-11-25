import 'package:resepku/data/favorite_database.dart';
import 'package:resepku/models/favorite.dart';

class MemoryFavoriteStore implements FavoriteStore {
  MemoryFavoriteStore([List<Favorite> initial = const []])
    : _rows = [...initial];
  final List<Favorite> _rows;
  bool failWrites = false;

  void _checkWrite() {
    if (failWrites) throw StateError('Penyimpanan gagal');
  }

  @override
  Future<List<Favorite>> getAll() async =>
      [..._rows]..sort((a, b) => b.savedAt.compareTo(a.savedAt));

  @override
  Future<void> insert(Favorite favorite) async {
    _checkWrite();
    _rows.removeWhere((f) => f.recipe.id == favorite.recipe.id);
    _rows.add(favorite);
  }

  @override
  Future<void> updateNote(int id, String note) async {
    _checkWrite();
    final index = _rows.indexWhere((f) => f.recipe.id == id);
    if (index >= 0) _rows[index] = _rows[index].copyWith(note: note);
  }

  @override
  Future<void> incrementCooked(int id) async {
    _checkWrite();
    final index = _rows.indexWhere((f) => f.recipe.id == id);
    if (index >= 0) {
      _rows[index] = _rows[index].copyWith(
        cookedCount: _rows[index].cookedCount + 1,
      );
    }
  }

  @override
  Future<void> delete(int id) async {
    _checkWrite();
    _rows.removeWhere((f) => f.recipe.id == id);
  }

  @override
  Future<void> deleteAll() async {
    _checkWrite();
    _rows.clear();
  }
}
