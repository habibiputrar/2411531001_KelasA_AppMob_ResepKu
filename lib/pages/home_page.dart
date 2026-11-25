import 'package:resepku/providers/settings_provider.dart';
import 'package:resepku/widgets/storage_action.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:resepku/pages/add_recipe_page.dart';
import 'package:resepku/pages/search_page.dart';
import 'package:resepku/services/recipe_service.dart';
import 'package:resepku/widgets/error_view.dart';
import 'package:resepku/models/recipe.dart';
import 'package:resepku/pages/settings_page.dart';
import 'package:resepku/widgets/favorite_badge_button.dart';
import 'package:resepku/widgets/recipe_tile.dart';
import 'package:resepku/widgets/recipe_grid_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _cuisine;

  late Future<List<Recipe>> _recipesFuture;

  @override
  void initState() {
    super.initState();
    _recipesFuture = _fetchRecipes();
  }

  Future<List<Recipe>> _fetchRecipes() {
    final future = context.read<RecipeService>().fetchRecipes();
    future.ignore();
    return future;
  }

  void _reload() {
    setState(() {
      _recipesFuture = _fetchRecipes();
    });
  }

  Future<void> _refresh() async {
    _reload();
    try {
      await _recipesFuture;
    } catch (_) {}
  }

  Future<void> _openAddPage() async {
    final created = await Navigator.push<Recipe>(
      context,
      MaterialPageRoute(builder: (_) => const AddRecipePage()),
    );
    if (!mounted || created == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '"${created.name}" diterima server dengan ID ${created.id}. '
          'DummyJSON hanya menyimulasikan penyimpanan.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isGrid = settings.isGrid;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', height: 32),
            const SizedBox(width: 8),
            const Flexible(
              child: Text('ResepKu', overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Cari resep',
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchPage()),
            ),
          ),
          IconButton(
            tooltip: isGrid ? 'Tampilan list' : 'Tampilan grid',
            icon: Icon(isGrid ? Icons.view_list : Icons.grid_view),
            onPressed: () =>
                storageAction(context, () => settings.setGrid(!isGrid)),
          ),
          const FavoriteBadgeButton(),
          IconButton(
            tooltip: 'Pengaturan',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsPage()),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<Recipe>>(
        future: _recipesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorView(error: snapshot.error!, onRetry: _reload);
          }
          return _buildRecipes(snapshot.requireData);
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Tambah resep',
        onPressed: _openAddPage,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildRecipes(List<Recipe> recipes) {
    final cuisines = recipes.map((recipe) => recipe.cuisine).toSet();
    final filtered = recipes
        .where((recipe) => _cuisine == null || recipe.cuisine == _cuisine)
        .toList();
    return Column(
      children: [
        SizedBox(
          height: 56,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            scrollDirection: Axis.horizontal,
            children: [
              _buildCuisineChip('Semua', null),
              for (final cuisine in cuisines)
                _buildCuisineChip(cuisine, cuisine),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: filtered.isEmpty
                ? const CustomScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: Text('Tidak ada resep.')),
                      ),
                    ],
                  )
                : context.watch<SettingsProvider>().isGrid
                ? _buildGrid(filtered)
                : _buildList(filtered),
          ),
        ),
      ],
    );
  }

  Widget _buildCuisineChip(String label, String? cuisine) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: _cuisine == cuisine,
        onSelected: (_) => setState(() => _cuisine = cuisine),
      ),
    );
  }

  Widget _buildList(List<Recipe> recipes) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: recipes.length,
      itemBuilder: (context, index) => RecipeTile(recipe: recipes[index]),
    );
  }

  Widget _buildGrid(List<Recipe> recipes) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 3 / 4,
      ),
      itemCount: recipes.length,
      itemBuilder: (context, index) => RecipeGridCard(recipe: recipes[index]),
    );
  }
}
