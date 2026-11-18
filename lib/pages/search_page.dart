import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:resepku/models/recipe.dart';
import 'package:resepku/services/recipe_service.dart';
import 'package:resepku/widgets/error_view.dart';
import 'package:resepku/widgets/recipe_tile.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  Future<List<Recipe>>? _results;
  String _query = '';

  void _search(String value) {
    final query = value.trim();
    setState(() {
      _query = query;
      _results = query.isEmpty
          ? null
          : context.read<RecipeService>().searchRecipes(query);
      _results?.ignore();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(hintText: 'Cari resep'),
          onSubmitted: _search,
        ),
      ),
      body: FutureBuilder<List<Recipe>>(
        future: _results,
        builder: (context, snapshot) {
          if (_results == null) {
            return const Center(child: Text('Masukkan kata kunci resep.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorView(
              error: snapshot.error!,
              onRetry: () => _search(_query),
            );
          }
          final recipes = snapshot.requireData;
          if (recipes.isEmpty) {
            return const Center(child: Text('Resep tidak ditemukan.'));
          }
          return ListView.builder(
            itemCount: recipes.length,
            itemBuilder: (context, index) => RecipeTile(recipe: recipes[index]),
          );
        },
      ),
    );
  }
}
