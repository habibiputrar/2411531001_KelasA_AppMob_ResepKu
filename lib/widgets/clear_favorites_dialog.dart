import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:resepku/providers/favorite_provider.dart';
import 'package:resepku/widgets/storage_action.dart';

Future<void> confirmClearFavorites(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Hapus semua favorit?'),
      content: const Text('Semua resep dan catatan favorit akan dihapus.'),
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
  if (!context.mounted || confirmed != true) return;
  final favorite = context.read<FavoriteProvider>();
  final success = await storageAction(context, favorite.clear);
  if (!context.mounted || !success) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Semua favorit berhasil dihapus.')),
  );
}
