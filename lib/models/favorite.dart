import 'dart:convert';

import 'package:resepku/models/recipe.dart';

class Favorite {
  const Favorite({
    required this.recipe,
    required this.savedAt,
    this.note = '',
    this.cookedCount = 0,
  });
  final Recipe recipe;
  final DateTime savedAt;
  final String note;
  final int cookedCount;

  Favorite copyWith({String? note, int? cookedCount}) => Favorite(
    recipe: recipe,
    savedAt: savedAt,
    note: note ?? this.note,
    cookedCount: cookedCount ?? this.cookedCount,
  );

  Map<String, Object?> toMap() => {
    'id': recipe.id,
    'name': recipe.name,
    'data': jsonEncode(recipe.toJson()),
    'saved_at': savedAt.millisecondsSinceEpoch,
    'note': note,
    'cooked_count': cookedCount,
  };

  factory Favorite.fromMap(Map<String, Object?> map) => Favorite(
    recipe: Recipe.fromJson(
      jsonDecode(map['data'] as String) as Map<String, dynamic>,
    ),
    savedAt: DateTime.fromMillisecondsSinceEpoch(map['saved_at'] as int),
    note: map['note'] as String? ?? '',
    cookedCount: map['cooked_count'] as int? ?? 0,
  );
}
