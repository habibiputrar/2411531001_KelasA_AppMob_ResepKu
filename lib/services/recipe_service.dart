import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:resepku/models/recipe.dart';

class RecipeService {
  RecipeService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _baseUrl = 'https://dummyjson.com';
  static const _timeout = Duration(seconds: 10);
  static const _jsonHeaders = {'Content-Type': 'application/json'};

  Future<List<Recipe>> fetchRecipes({int limit = 50}) =>
      _getRecipes(Uri.parse('$_baseUrl/recipes?limit=$limit'));

  Future<List<Recipe>> searchRecipes(String query) => _getRecipes(
    Uri.parse('$_baseUrl/recipes/search')
        .replace(queryParameters: {'q': query}),
  );

  Future<List<Recipe>> _getRecipes(Uri uri) async {
    final body = await _decode(_client.get(uri));
    return (body['recipes'] as List<dynamic>)
        .map((item) => Recipe.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Recipe> addRecipe({
    required String name,
    required String cuisine,
    required int cookTimeMinutes,
  }) async {
    final body = await _decode(
      _client.post(
        Uri.parse('$_baseUrl/recipes/add'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'name': name,
          'cuisine': cuisine,
          'cookTimeMinutes': cookTimeMinutes,
        }),
      ),
    );
    return Recipe.fromJson(body);
  }

  Future<Recipe> updateRecipe(int id, String name) async {
    final body = await _decode(
      _client.put(
        Uri.parse('$_baseUrl/recipes/$id'),
        headers: _jsonHeaders,
        body: jsonEncode({'name': name}),
      ),
    );
    return Recipe.fromJson(body);
  }

  Future<bool> deleteRecipe(int id) async {
    final body = await _decode(
      _client.delete(Uri.parse('$_baseUrl/recipes/$id')),
    );
    return body['isDeleted'] == true;
  }

  Future<Map<String, dynamic>> _decode(Future<http.Response> request) async {
    final response = await request.timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RecipeServiceException(
        'Server menjawab dengan status ${response.statusCode}',
      );
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  void close() => _client.close();
}

class RecipeServiceException implements Exception {
  const RecipeServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
