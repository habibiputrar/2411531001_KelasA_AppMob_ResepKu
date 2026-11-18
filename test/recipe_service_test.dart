import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:resepku/models/recipe.dart';
import 'package:resepku/services/recipe_service.dart';

void main() {
  test('fromJson converts integer rating and defaults optional fields', () {
    final recipe = Recipe.fromJson({'id': 1, 'name': 'Pasta', 'rating': 5});

    expect(recipe.rating, 5.0);
    expect(recipe.rating, isA<double>());
    expect(recipe.cuisine, '-');
    expect(recipe.servings, 1);
    expect(recipe.totalTimeMinutes, 0);
    expect(recipe.image, isEmpty);
    expect(recipe.ingredients, isEmpty);
    expect(recipe.instructions, isEmpty);
  });

  test('fetchRecipes decodes the recipes array', () async {
    final service = RecipeService(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/recipes');
        expect(request.url.queryParameters['limit'], '50');
        return http.Response('{"recipes":[{"id":1,"name":"Pasta"}]}', 200);
      }),
    );
    addTearDown(service.close);

    final recipes = await service.fetchRecipes();
    expect(recipes.single.name, 'Pasta');
  });

  test('fetchRecipes throws on HTTP 404', () async {
    final service = RecipeService(
      client: MockClient((_) async => http.Response('{}', 404)),
    );
    addTearDown(service.close);

    await expectLater(
      service.fetchRecipes(),
      throwsA(isA<RecipeServiceException>()),
    );
  });
}
