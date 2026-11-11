import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:resepku/data/dummy_recipes.dart';
import 'package:resepku/main.dart';
import 'package:resepku/pages/detail_page.dart';
import 'package:resepku/providers/favorite_provider.dart';
import 'package:resepku/providers/theme_provider.dart';
import 'package:resepku/widgets/identity_footer.dart';
import 'package:resepku/widgets/recipe_grid_card.dart';
import 'package:resepku/widgets/recipe_image.dart';
import 'package:resepku/widgets/recipe_tile.dart';

// Widget tests use Flutter's HTTP 400 stub, never the real recipe CDN.
// Successful image downloads and airplane mode still require a device test.
Future<FavoriteProvider> pumpResepKu(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final favorites = FavoriteProvider();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: favorites),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const ResepKuApp(),
    ),
  );
  await tester.pumpAndSettle();
  return favorites;
}

void main() {
  testWidgets('Home registers Poppins, logo, thumbnails and identity footer', (
    tester,
  ) async {
    await pumpResepKu(tester);
    expect(tester.widget<ListView>(find.byType(ListView).last).semanticChildCount, dummyRecipes.length);
    expect(find.byType(RecipeImage).evaluate().length, greaterThan(0));
    expect(find.text('$kNim • $kNama'), findsOneWidget);
    final context = tester.element(find.byType(RecipeTile).first);
    expect(Theme.of(context).textTheme.bodyMedium!.fontFamily, 'Poppins');
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == 'assets/images/logo.png',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Grid favorite survives switching back to list', (tester) async {
    final favorites = await pumpResepKu(tester);
    await tester.tap(find.byTooltip('Tampilan grid'));
    await tester.pumpAndSettle();
    final grid = tester.widget<GridView>(find.byType(GridView));
    expect(
      (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      2,
    );
    expect(find.byTooltip('Tampilan list'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(RecipeGridCard).first,
        matching: find.byType(IconButton),
      ),
    );
    await tester.pumpAndSettle();
    expect(favorites.isFavorite(dummyRecipes.first), isTrue);
    expect(tester.widget<Badge>(find.byType(Badge)).label, isA<Text>());
    expect((tester.widget<Badge>(find.byType(Badge)).label! as Text).data, '1');
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: find.byType(RecipeGridCard).first,
              matching: find.byIcon(Icons.favorite),
            ),
          )
          .color,
      Colors.red,
    );
    await tester.tap(find.byTooltip('Tampilan list'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: find.byType(RecipeTile).first,
              matching: find.byIcon(Icons.favorite),
            ),
          )
          .color,
      Colors.red,
    );
    expect(favorites.count, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Cuisine filters both modes; Alfredo opens detail with large photo',
    (tester) async {
      await pumpResepKu(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Italian'));
      await tester.pumpAndSettle();
      expect(find.byType(RecipeTile), findsNWidgets(2));
      expect(find.text('Vegetarian Stir-Fry'), findsNothing);
      await tester.tap(find.byTooltip('Tampilan grid'));
      await tester.pumpAndSettle();
      expect(find.byType(RecipeGridCard), findsNWidgets(2));
      await tester.tap(find.text('Chicken Alfredo Pasta'));
      await tester.pumpAndSettle();
      expect(find.byType(DetailPage), findsOneWidget);
      final image = tester.widget<RecipeImage>(find.byType(RecipeImage).last);
      expect(image.url, dummyRecipes[3].image);
      expect(image.cacheWidth, isNull);
      expect(
        find.ancestor(
          of: find.byType(RecipeImage).last,
          matching: find.byType(AspectRatio),
        ),
        findsOneWidget,
      );
      expect(find.text('$kNim • $kNama'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Semua'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<GridView>(find.byType(GridView)).semanticChildCount,
        dummyRecipes.length,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Favorites have separators and stable swipe removal with SnackBar',
    (tester) async {
      final favorites = await pumpResepKu(tester);
      favorites.toggle(dummyRecipes[0]);
      favorites.toggle(dummyRecipes[1]);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Favorit saya'));
      await tester.pumpAndSettle();
      expect(find.byType(Divider), findsOneWidget);
      expect(find.byType(RecipeImage), findsNWidgets(2));
      expect(find.byKey(ValueKey(dummyRecipes[0].id)), findsOneWidget);
      await tester.drag(
        find.byKey(ValueKey(dummyRecipes[0].id)),
        const Offset(-400, 0),
      );
      await tester.pumpAndSettle();
      expect(favorites.count, 1);
      expect(
        find.text('${dummyRecipes[0].name} dihapus dari favorit.'),
        findsOneWidget,
      );
      expect(find.byKey(ValueKey(dummyRecipes[1].id)), findsOneWidget);
      await tester.tap(find.text('Hapus semua'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(favorites.count, 1);
      await tester.tap(find.text('Hapus semua'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();
      expect(favorites.count, 0);
      expect(find.textContaining('Belum ada resep favorit.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Settings keeps dark mode and Poppins across navigation', (
    tester,
  ) async {
    await pumpResepKu(tester);
    await tester.tap(find.byTooltip('Pengaturan'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(SwitchListTile))).brightness,
      Brightness.dark,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    final theme = Theme.of(tester.element(find.byType(RecipeTile).first));
    expect(theme.brightness, Brightness.dark);
    expect(theme.textTheme.bodyMedium!.fontFamily, 'Poppins');
    expect(find.text('$kNim • $kNama'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Failed network image renders bundled placeholder without exception',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 56,
            height: 56,
            child: RecipeImage(url: 'https://example.invalid/missing.webp'),
          ),
        ),
      );
      // Let the stubbed network request finish and decode the real asset.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/images/placeholder.png',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
