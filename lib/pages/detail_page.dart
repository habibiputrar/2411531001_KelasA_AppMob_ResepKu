import 'package:resepku/widgets/storage_action.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:resepku/models/recipe.dart';
import 'package:resepku/providers/favorite_provider.dart';
import 'package:resepku/services/recipe_service.dart';
import 'package:resepku/widgets/recipe_name_dialog.dart';

enum _RecipeAction { rename, delete }

class DetailPage extends StatefulWidget {
  const DetailPage({super.key, required this.recipe});

  final Recipe recipe;

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  bool _mutating = false;
  late int _servings; // state lokal: hanya halaman ini yang butuh

  @override
  void initState() {
    super.initState();
    _servings = widget.recipe.servings; // nilai awal dari data resep
  }

  void _addServing() {
    setState(() => _servings++);
  }

  void _removeServing() {
    if (_servings > 1) {
      setState(() => _servings--);
    }
  }

  Future<void> _rename() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => RecipeNameDialog(name: widget.recipe.name),
    );
    if (!mounted || name == null) return;

    setState(() => _mutating = true);
    try {
      final updated = await context.read<RecipeService>().updateRecipe(
        widget.recipe.id,
        name,
      );
      if (!mounted) return;
      _showMessage(
        'Nama dari server: "${updated.name}". Perubahan disimulasikan.',
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage('Gagal mengubah nama. $error');
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus resep?'),
        content: Text(
          'Hapus "${widget.recipe.name}" melalui simulasi DummyJSON?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    setState(() => _mutating = true);
    try {
      final deleted = await context.read<RecipeService>().deleteRecipe(
        widget.recipe.id,
      );
      if (!mounted) return;
      if (!deleted) {
        _showMessage('Server tidak mengonfirmasi penghapusan resep.');
        return;
      }
      _showMessage('"${widget.recipe.name}" dihapus dalam simulasi DummyJSON.');
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      _showMessage('Gagal menghapus resep. $error');
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final totalCalories = recipe.caloriesPerServing * _servings;
    final isFavorite = context.watch<FavoriteProvider>().isFavorite(recipe);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 260,
            backgroundColor: Colors.deepOrange.shade800,
            foregroundColor: Colors.white,
            leading: BackButton(
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.surface,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            actions: [
              IconButton.filledTonal(
                tooltip: isFavorite
                    ? 'Hapus dari favorit'
                    : 'Tambah ke favorit',
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : null,
                ),
                onPressed: () => storageAction(
                  context,
                  () => context.read<FavoriteProvider>().toggle(recipe),
                ),
              ),
              PopupMenuButton<_RecipeAction>(
                tooltip: 'Aksi resep',
                enabled: !_mutating,
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                ),
                onSelected: (action) => switch (action) {
                  _RecipeAction.rename => _rename(),
                  _RecipeAction.delete => _delete(),
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: _RecipeAction.rename,
                    child: Text('Ubah nama'),
                  ),
                  PopupMenuItem(
                    value: _RecipeAction.delete,
                    child: Text('Hapus'),
                  ),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(
                start: 56,
                end: 104,
                bottom: 16,
              ),
              title: Text(
                recipe.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: recipe.image,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => ColoredBox(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: const Center(child: Icon(Icons.restaurant_menu)),
                    ),
                    errorWidget: (context, url, error) => Image.asset(
                      'assets/images/placeholder.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black87],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${recipe.cuisine} • ${recipe.difficulty} • ${recipe.totalTimeMinutes} menit',
                    style: textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Text('Porsi', style: textTheme.titleMedium),
                          const Spacer(),
                          IconButton.filledTonal(
                            onPressed: _servings > 1 ? _removeServing : null,
                            icon: const Icon(Icons.remove),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              '$_servings',
                              style: textTheme.titleLarge,
                            ),
                          ),
                          IconButton.filledTonal(
                            onPressed: _addServing,
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total kalori: $totalCalories kkal',
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: 24),
                  Text('Bahan', style: textTheme.titleLarge),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverList.builder(
              itemCount: recipe.ingredients.length,
              itemBuilder: (context, index) => ListTile(
                dense: true,
                leading: const Icon(Icons.check_circle_outline),
                title: Text(recipe.ingredients[index]),
              ),
            ),
          ),
          if (recipe.instructions.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: Text('Langkah', style: textTheme.titleLarge),
              ),
            ),
          SliverList.builder(
            itemCount: recipe.instructions.length,
            itemBuilder: (context, index) => ListTile(
              dense: true,
              leading: CircleAvatar(radius: 12, child: Text('${index + 1}')),
              title: Text(recipe.instructions[index]),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          SliverLayoutBuilder(
            builder: (context, constraints) {
              // Resep pendek juga harus bisa menggulir header hingga mengecil.
              final remaining =
                  constraints.viewportMainAxisExtent +
                  (260 - kToolbarHeight) -
                  constraints.precedingScrollExtent;
              return SliverToBoxAdapter(
                child: SizedBox(height: remaining > 0 ? remaining : 0),
              );
            },
          ),
        ],
      ),
    );
  }
}
