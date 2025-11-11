import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/auth_form_field.dart';
import '../../routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final themeProv = Provider.of<ThemeProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        actions: [
          IconButton(
            tooltip: 'Toggle theme',
            icon: Icon(themeProv.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              themeProv.toggleTheme();
            },
          )
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final isLarge = constraints.maxWidth > 700;
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isLarge ? 600 : 420),
            child: Card(
              elevation: 6,
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    const Text(
                      'Welcome — please login',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    AuthFormField(label: 'Username', controller: _username),
                    const SizedBox(height: 12),
                    AuthFormField(label: 'Password', controller: _password, obscure: true),
                    const SizedBox(height: 12),
                    if (_error != null) ...[
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _loading ? null : _onLogin,
                            child: _loading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('Login'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, Routes.register);
                      },
                      child: const Text('New user? Register'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Future<void> _onLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final err = await auth.login(username: _username.text.trim(), password: _password.text.trim());
    if (err != null) {
      setState(() {
        _error = err;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = false;
    });
    if (mounted) Navigator.pushReplacementNamed(context, Routes.home);
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }
}
