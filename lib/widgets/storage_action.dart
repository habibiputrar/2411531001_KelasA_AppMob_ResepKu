import 'package:flutter/material.dart';

Future<bool> storageAction(
  BuildContext context,
  Future<void> Function() operation,
) async {
  try {
    await operation();
    return true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menyimpan perubahan. Silakan coba lagi.'),
        ),
      );
    }
    return false;
  }
}
