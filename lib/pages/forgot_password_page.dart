import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../services/api_client.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  String? _emailForReset;
  bool _loading = false;
  bool _step1 = true;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    FocusScope.of(context).unfocus();
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите email')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await ApiClient.instance.post(
        '/auth/forgot-password',
        data: {'email': _emailController.text.trim()},
      );

      if (!mounted) return;
      setState(() {
        _step1 = false;
        _emailForReset = _emailController.text.trim();
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Код отправлен на вашу почту')),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.response?.data?['error'] ?? 'Ошибка при отправке кода',
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

  void _goBack() {
    setState(() => _step1 = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Восстановление пароля'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _step1
              ? _buildStep1()
              : _buildStep2(),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Icon(
          Icons.email_outlined,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          'Забыли пароль?',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Введите адрес электронной почты, связанный с вашей учетной записью. Код восстановления придет на эту почту.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined),
            hintText: 'example@gmail.com',
          ),
          enabled: !_loading,
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _loading ? null : _sendCode,
            child: Text(_loading ? 'Отправка...' : 'Отправить код'),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return _ResetPasswordForm(
      email: _emailForReset ?? '',
      onSuccess: () {
        Navigator.of(context).pop();
      },
      onBack: _goBack,
    );
  }
}

class _ResetPasswordForm extends StatefulWidget {
  final String email;
  final VoidCallback onSuccess;
  final VoidCallback onBack;

  const _ResetPasswordForm({
    required this.email,
    required this.onSuccess,
    required this.onBack,
  });

  @override
  State<_ResetPasswordForm> createState() => _ResetPasswordFormState();
}

class _ResetPasswordFormState extends State<_ResetPasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      await ApiClient.instance.post(
        '/auth/reset-password',
        data: {
          'email': widget.email,
          'code': _codeController.text.trim(),
          'new_password': _passwordController.text,
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пароль успешно изменён')),
      );
      widget.onSuccess();
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.response?.statusCode == 400
                ? 'Неверный или истекший код'
                : e.response?.data?['error'] ?? 'Ошибка сброса пароля',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Icon(
          Icons.verified_outlined,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          'Введите код',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Мы отправили 6-значный код на вашу почту. Проверьте входящие письма (и спам).',
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
                controller: _codeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Код (6 цифр)',
                  prefixIcon: Icon(Icons.security_outlined),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Введите код';
                  if (text.length != 6) return 'Код должен содержать 6 цифр';
                  return null;
                },
              ),
              const SizedBox(height: 16),
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
                  onPressed: _loading ? null : _resetPassword,
                  child: Text(_loading ? 'Сброс...' : 'Сбросить пароль'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _loading ? null : widget.onBack,
                  child: const Text('Назад'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
