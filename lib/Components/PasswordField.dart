import 'package:flutter/material.dart';

class PasswordField extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hintText;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final bool allowEmpty; // keep behaviour: empty means remove
  final bool initiallyObscured;

  const PasswordField({
    super.key,
    this.controller,
    this.label,
    this.hintText,
    this.validator,
    this.onChanged,
    this.allowEmpty = true,
    this.initiallyObscured = true,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _obscure = widget.initiallyObscured;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      onChanged: widget.onChanged,
      validator: widget.validator ??
          (value) {
            if (!widget.allowEmpty && (value == null || value.isEmpty)) {
              return 'Password required';
            }
            return null;
          },
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hintText,
        border: const OutlineInputBorder(),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blue, width: 2),
        ),
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _obscure = !_obscure),
          splashRadius: 18,
          tooltip: _obscure ? 'Show password' : 'Hide password',
        ),
      ),
    );
  }
}
