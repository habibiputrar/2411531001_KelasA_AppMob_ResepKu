import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:resepku/providers/settings_provider.dart';
import 'package:resepku/providers/favorite_provider.dart';
import 'package:resepku/widgets/storage_action.dart';
import 'package:resepku/widgets/clear_favorites_dialog.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final favorites = context.watch<FavoriteProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('Mode gelap'),
            value: settings.isDark,
            onChanged: (value) =>
                storageAction(context, () => settings.setDark(value)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.grid_view),
            title: const Text('Tampilan grid'),
            subtitle: const Text('Daftar resep ditampilkan dalam dua kolom'),
            value: settings.isGrid,
            onChanged: (value) =>
                storageAction(context, () => settings.setGrid(value)),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Hapus semua favorit'),
            subtitle: Text('${favorites.count} resep tersimpan'),
            enabled: favorites.count > 0,
            onTap: () => confirmClearFavorites(context),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Pengaturan tersimpan di HP'),
            subtitle: Text('Pilihan tetap ada walaupun aplikasi ditutup.'),
          ),
        ],
      ),
    );
  }
}
