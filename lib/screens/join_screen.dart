import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../custom_widgets/custom_textfield.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import 'rooms_screen.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _auth = AuthService();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _busy = false;
  String _status = 'Войдите или зарегистрируйтесь, чтобы попробовать';

  Uri get _baseUri => Uri.parse(AppConfig.serverUrl);

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_validateFields()) {
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Создаём аккаунт...';
    });

    try {
      await _auth.register(
        baseUri: _baseUri,
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      setState(() {
        _status = 'Аккаунт создан. Теперь войдите в echo.';
      });
    } catch (error) {
      setState(() {
        _status = 'Ошибка регистрации: $error';
      });
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _login() async {
    if (!_validateFields()) {
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Входим в echo...';
    });

    try {
      final token = await _auth.login(
        baseUri: _baseUri,
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      final profile = await _auth.me(baseUri: _baseUri, token: token);
      if (!mounted) {
        return;
      }
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => RoomsScreen(
                baseUri: _baseUri,
                token: token,
                profile: profile,
              ),
        ),
      );
    } catch (error) {
      setState(() {
        _status = 'Ошибка входа: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  bool _validateFields() {
    if (_usernameCtrl.text.trim().isEmpty || _passwordCtrl.text.isEmpty) {
      setState(() {
        _status = 'Введите имя пользователя и пароль.';
      });
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFFFF), Color(0xFFF4FBFF), Color(0xFFEAF7FF)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 820;
                  return Flex(
                    direction: compact ? Axis.vertical : Axis.horizontal,
                    children: [
                      Expanded(
                        flex: compact ? 0 : 10,
                        child: _AuthHero(status: _status),
                      ),
                      SizedBox(
                        width: compact ? 0 : 24,
                        height: compact ? 24 : 0,
                      ),
                      Expanded(
                        flex: 9,
                        child: SingleChildScrollView(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Вход в echo',
                                    style: theme.textTheme.headlineMedium,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Регистрация без номера и почты. Всё просто.',
                                    style: theme.textTheme.bodyLarge,
                                  ),
                                  const SizedBox(height: 28),
                                  CustomTextfield(
                                    hint: 'Имя пользователя',
                                    controller: _usernameCtrl,
                                    prefixIcon: Icons.person_outline,
                                  ),
                                  const SizedBox(height: 16),
                                  CustomTextfield(
                                    hint: 'Пароль',
                                    controller: _passwordCtrl,
                                    prefixIcon: Icons.lock_outline,
                                    obscureText: true,
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) => _login(),
                                  ),
                                  const SizedBox(height: 24),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: _busy ? null : _login,
                                          child: const Text('Войти'),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: _busy ? null : _register,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFFBEEBFF,
                                            ),
                                            foregroundColor: const Color(
                                              0xFF17608E,
                                            ),
                                          ),
                                          child: const Text('Регистрация'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF7FCFF),
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(
                                        color: const Color(0xFFDCEFFC),
                                      ),
                                    ),
                                    child: Text(
                                      'Присоединяйтесь!',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthHero extends StatelessWidget {
  const _AuthHero({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00AFF0), Color(0xFF3FC7FF), Color(0xFF8FDEFF)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Text(
              'echo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Ваши комнаты всегда под рукой.',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Присоединяйся к голосовому общению!',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
          const SizedBox(height: 18),
          // const Spacer(),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Text(
              status,
              style: const TextStyle(color: Colors.white, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
