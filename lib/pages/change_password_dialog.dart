import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../services/api_client.dart';

class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _obscure3 = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      await ApiClient.instance.post(
        '/auth/change-password',
        data: {
          'current_password': _currentPasswordController.text,
          'new_password': _newPasswordController.text,
        },
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пароль успешно изменён')),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.response?.statusCode == 401
                ? 'Текущий пароль неправильный'
                : e.response?.data?['error'] ?? 'Ошибка смены пароля',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Смена пароля'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _currentPasswordController,
                obscureText: _obscure1,
                decoration: InputDecoration(
                  labelText: 'Текущий пароль',
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure1 = !_obscure1),
                    icon: Icon(
                      _obscure1 ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
                validator: (value) {
                  if ((value ?? '').isEmpty) return 'Введите текущий пароль';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPasswordController,
                obscureText: _obscure2,
                decoration: InputDecoration(
                  labelText: 'Новый пароль',
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure2 = !_obscure2),
                    icon: Icon(
                      _obscure2 ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
                validator: (value) {
                  final text = value ?? '';
                  if (text.isEmpty) return 'Введите новый пароль';
                  if (text.length < 6) return 'Минимум 6 символов';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscure3,
                decoration: InputDecoration(
                  labelText: 'Подтвердите пароль',
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure3 = !_obscure3),
                    icon: Icon(
                      _obscure3 ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
                validator: (value) {
                  final text = value ?? '';
                  if (text.isEmpty) return 'Подтвердите пароль';
                  if (text != _newPasswordController.text) {
                    return 'Пароли не совпадают';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _loading ? null : _changePassword,
          child: Text(_loading ? 'Смена...' : 'Изменить'),
        ),
      ],
    );
  }
}
