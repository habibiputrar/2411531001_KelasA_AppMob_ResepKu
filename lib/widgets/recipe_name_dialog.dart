import 'package:flutter/material.dart';

class RecipeNameDialog extends StatefulWidget {
  const RecipeNameDialog({super.key, required this.name});

  final String name;

  @override
  State<RecipeNameDialog> createState() => _RecipeNameDialogState();
}

class _RecipeNameDialogState extends State<RecipeNameDialog> {
  late final _controller = TextEditingController(text: widget.name);
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, _controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ubah nama resep'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          autofocus: true,
          controller: _controller,
          decoration: const InputDecoration(labelText: 'Nama resep'),
          validator: (value) =>
              (value ?? '').trim().isEmpty ? 'Wajib diisi' : null,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Simpan')),
      ],
    );
  }
}
