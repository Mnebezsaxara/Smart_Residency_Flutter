import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../services/api_client.dart';

class ChangePasswordOnFirstLoginPage extends StatefulWidget {
  final String temporaryToken;
  final String email;
  final String role;

  const ChangePasswordOnFirstLoginPage({
    super.key,
    required this.temporaryToken,
    required this.email,
    required this.role,
  });

  @override
  State<ChangePasswordOnFirstLoginPage> createState() =>
      _ChangePasswordOnFirstLoginPageState();
}

class _ChangePasswordOnFirstLoginPageState
    extends State<ChangePasswordOnFirstLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final dio = Dio(BaseOptions(
        baseUrl: ApiClient.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));

      // Добавляем временный токен в заголовок
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers['Authorization'] = 'Bearer ${widget.temporaryToken}';
          handler.next(options);
        },
      ));

      final res = await dio.post(
        '/auth/change-password-first-login',
        data: {'new_password': _passwordController.text},
      );

      if (!mounted) return;

      // Получаем новый токен из ответа и сохраняем сессию
      final newToken = res.data['token'] as String;
      await ApiClient.instance.saveSession(
        token: newToken,
        userId: res.data['user_id'] as String? ?? '',
        role: widget.role,
      );

      // Возвращаемся в главное приложение
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.response?.data?['error'] ?? 'Ошибка при смене пароля',
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
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Icon(
                Icons.lock_outline,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Смена пароля при первом входе',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Вы вошли с временным паролем. Для безопасности установите новый пароль перед тем, как продолжить.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscure1,
                      decoration: InputDecoration(
                        labelText: 'Новый пароль',
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => _obscure1 = !_obscure1),
                          icon: Icon(
                            _obscure1
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                      ),
                      validator: (value) {
                        final text = value ?? '';
                        if (text.isEmpty) return 'Введите пароль';
                        if (text.length < 6) return 'Минимум 6 символов';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: _obscure2,
                      decoration: InputDecoration(
                        labelText: 'Подтвердите пароль',
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => _obscure2 = !_obscure2),
                          icon: Icon(
                            _obscure2
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                      ),
                      validator: (value) {
                        final text = value ?? '';
                        if (text.isEmpty) return 'Подтвердите пароль';
                        if (text != _passwordController.text) {
                          return 'Пароли не совпадают';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _loading ? null : _changePassword,
                        child: Text(
                          _loading ? 'Смена пароля...' : 'Изменить пароль',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
