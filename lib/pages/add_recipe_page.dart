import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:resepku/services/recipe_service.dart';

class AddRecipePage extends StatefulWidget {
  const AddRecipePage({super.key});

  @override
  State<AddRecipePage> createState() => _AddRecipePageState();
}

class _AddRecipePageState extends State<AddRecipePage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _cuisine = TextEditingController();
  final _minutes = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _cuisine.dispose();
    _minutes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final created = await context.read<RecipeService>().addRecipe(
        name: _name.text.trim(),
        cuisine: _cuisine.text.trim(),
        cookTimeMinutes: int.parse(_minutes.text.trim()),
      );
      if (!mounted) return;
      Navigator.pop(context, created);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mengirim resep. $error')));
    }
  }

  String? _required(String? value) =>
      (value ?? '').trim().isEmpty ? 'Wajib diisi' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Resep')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              enabled: !_saving,
              decoration: const InputDecoration(labelText: 'Nama resep'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cuisine,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'Cuisine, misalnya Indonesian',
              ),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _minutes,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'Waktu memasak (menit)',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                final minutes = int.tryParse((value ?? '').trim());
                return minutes == null || minutes <= 0
                    ? 'Isi dengan angka lebih dari 0'
                    : null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}
