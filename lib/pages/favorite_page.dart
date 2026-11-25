import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:resepku/models/favorite.dart';
import 'package:resepku/pages/detail_page.dart';
import 'package:resepku/providers/favorite_provider.dart';
import 'package:resepku/providers/settings_provider.dart';
import 'package:resepku/widgets/clear_favorites_dialog.dart';
import 'package:resepku/widgets/recipe_image.dart';
import 'package:resepku/widgets/storage_action.dart';

class FavoritePage extends StatelessWidget {
  const FavoritePage({super.key});

  Future<void> _editNote(BuildContext context, Favorite item) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _NoteDialog(initial: item.note),
    );
    if (!context.mounted || note == null) return;
    final provider = context.read<FavoriteProvider>();
    await storageAction(
      context,
      () => provider.updateNote(item.recipe.id, note.trim()),
    );
  }

  Future<void> _remove(BuildContext context, Favorite item) async {
    final provider = context.read<FavoriteProvider>();
    final success = await storageAction(
      context,
      () => provider.toggle(item.recipe),
    );
    if (!context.mounted || !success) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${item.recipe.name} dihapus dari favorit.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final favorite = context.watch<FavoriteProvider>();
    final settings = context.watch<SettingsProvider>();
    final items = [...favorite.items];
    if (settings.favoriteSort == FavoriteSort.name) {
      items.sort(
        (a, b) =>
            a.recipe.name.toLowerCase().compareTo(b.recipe.name.toLowerCase()),
      );
    } else {
      items.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorit Saya', overflow: TextOverflow.ellipsis),
        actions: [
          PopupMenuButton<FavoriteSort>(
            tooltip: 'Urutan favorit',
            initialValue: settings.favoriteSort,
            onSelected: (value) =>
                storageAction(context, () => settings.setFavoriteSort(value)),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: FavoriteSort.newest,
                child: Text('Terbaru disimpan'),
              ),
              PopupMenuItem(value: FavoriteSort.name, child: Text('Nama A–Z')),
            ],
          ),
          TextButton(
            onPressed: favorite.count == 0
                ? null
                : () => confirmClearFavorites(context),
            child: const Text('Hapus semua'),
          ),
        ],
      ),
      body: items.isEmpty
          ? const Center(
              child: Text(
                'Belum ada resep favorit.\nTekan ikon hati di daftar resep.',
                textAlign: TextAlign.center,
              ),
            )
          : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, index) {
                final item = items[index];
                final recipe = item.recipe;
                return Dismissible(
                  key: ValueKey(recipe.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Theme.of(context).colorScheme.errorContainer,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    child: const Icon(Icons.delete_outline),
                  ),
                  // Daftar diperbarui provider sesudah penulisan berhasil.
                  confirmDismiss: (_) async {
                    await _remove(context, item);
                    return false;
                  },
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: RecipeImage(url: recipe.image, cacheWidth: 168),
                      ),
                    ),
                    title: Text(recipe.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${recipe.cuisine}\n${item.note.isEmpty ? 'Belum ada catatan' : item.note}',
                        ),
                        Text('Dimasak ${item.cookedCount} kali'),
                        TextButton(
                          onPressed: () => storageAction(
                            context,
                            () => favorite.incrementCooked(recipe.id),
                          ),
                          child: const Text('Sudah dimasak'),
                        ),
                      ],
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetailPage(recipe: recipe),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Catatan',
                          icon: const Icon(Icons.edit_note),
                          onPressed: () => _editNote(context, item),
                        ),
                        IconButton(
                          tooltip: 'Hapus dari favorit',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _remove(context, item),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.initial});
  final String initial;
  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final TextEditingController _controller;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Catatan pribadi'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLines: 4,
      decoration: const InputDecoration(hintText: 'Tulis catatan resep'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        child: const Text('Simpan'),
      ),
    ],
  );
}
