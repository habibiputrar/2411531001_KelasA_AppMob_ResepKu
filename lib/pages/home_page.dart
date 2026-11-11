import 'package:flutter/material.dart';
import 'package:resepku/data/dummy_recipes.dart';
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
  bool _isGrid = false;
  String? _cuisine;

  @override
  Widget build(BuildContext context) {
    final cuisines = dummyRecipes.map((recipe) => recipe.cuisine).toSet();
    final recipes = dummyRecipes
        .where((recipe) => _cuisine == null || recipe.cuisine == _cuisine)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', height: 32),
            const SizedBox(width: 8),
            const Flexible(child: Text('ResepKu')),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _isGrid ? 'Tampilan list' : 'Tampilan grid',
            icon: Icon(_isGrid ? Icons.view_list : Icons.grid_view),
            onPressed: () => setState(() => _isGrid = !_isGrid),
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
      body: Column(
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
          Expanded(child: _isGrid ? _buildGrid(recipes) : _buildList(recipes)),
        ],
      ),
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
      itemCount: recipes.length,
      itemBuilder: (context, index) => RecipeTile(recipe: recipes[index]),
    );
  }

  Widget _buildGrid(List<Recipe> recipes) {
    return GridView.builder(
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
