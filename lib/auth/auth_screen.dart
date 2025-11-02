import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stuttgart_network/services/auth_service.dart'; // Наш сервис

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  bool _isLogin = true; // Переключатель Вход/Регистрация
  bool _isLoading = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// Главная функция для входа или регистрации
  Future<void> _submit() async {
    // 1. Проверяем валидность формы
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        // --- 2. Логика ВХОДА ---
        await _authService.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        // AuthGate в main.dart автоматически переключит экран
      } else {
        // --- 3. Логика РЕГИСТРАЦИИ ---
        await _authService.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          fullName: _fullNameController.text.trim(),
          phone: _phoneController.text.trim(),
        );
        // Показываем сообщение о подтверждении email
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Регистрация успешна! Проверьте email для подтверждения.'),
              backgroundColor: Colors.green,
            ),
          );
          // Возвращаем на экран входа
          setState(() => _isLogin = true);
        }
      }
    } on AuthException catch (e) {
      // 4. Показываем ошибку
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      // 5. Показываем любую другую ошибку
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Произошла непредвиденная ошибка: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      // 6. Выключаем загрузку
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- UI Helpers ---

  /// Создает стилизованное поле ввода
  InputDecoration _styledInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.black.withOpacity(0.1),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide.none,
      ),
    );
  }

  /// Виджет с полями только для регистрации
  Widget _buildRegisterFields() {
    return Column(
      children: [
        TextFormField(
          controller: _fullNameController,
          decoration: _styledInputDecoration('Полное имя'),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Введите ваше имя';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _phoneController,
          decoration: _styledInputDecoration('Телефон (необязательно)'),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // Убираем AppBar, т.к. заголовок будет на карточке
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            // 1. Оборачиваем в Card
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 2. Добавляем иконку и заголовок
                      Icon(Icons.hub_outlined,
                          size: 48, color: theme.colorScheme.primary),
                      const SizedBox(height: 16),
                      Text(
                        _isLogin ? 'С возвращением!' : 'Создать аккаунт',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isLogin
                            ? 'Войдите в свой аккаунт'
                            : 'Заполните поля для регистрации',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),

                      // 3. Используем AnimatedSwitcher для полей регистрации
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) {
                          // Плавное появление/исчезание
                          return FadeTransition(
                            opacity: animation,
                            child: SizeTransition(
                              sizeFactor: animation,
                              axis: Axis.vertical,
                              child: child,
                            ),
                          );
                        },
                        child: _isLogin
                            ? const SizedBox.shrink() // Пусто, если логин
                            : _buildRegisterFields(), // Поля, если регистрация
                      ),

                      // --- Общие поля ---
                      // 4. Стилизуем поля
                      TextFormField(
                        controller: _emailController,
                        decoration: _styledInputDecoration('Email'),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || !value.contains('@')) {
                            return 'Введите корректный email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: _styledInputDecoration('Пароль'),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.length < 6) {
                            return 'Пароль должен быть мин. 6 символов';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // --- Кнопка ---
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                              onPressed: _submit,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 48),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text(
                                  _isLogin ? 'Войти' : 'Зарегистрироваться',
                                  style: const TextStyle(fontSize: 16)),
                            ),
                      const SizedBox(height: 16),

                      // --- Переключатель ---
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                setState(() => _isLogin = !_isLogin);
                              },
                        child: Text(
                          _isLogin
                              ? 'Нет аккаунта? Зарегистрироваться'
                              : 'Уже есть аккаунт? Войти',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
