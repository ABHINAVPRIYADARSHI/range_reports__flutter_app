import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/auth_form_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _success;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
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
                    const Text('Create account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    AuthFormField(label: 'Username', controller: _username),
                    const SizedBox(height: 10),
                    AuthFormField(label: 'Full name', controller: _name),
                    const SizedBox(height: 10),
                    AuthFormField(label: 'Email (optional)', controller: _email, keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 10),
                    AuthFormField(label: 'Password', controller: _password, obscure: true),
                    const SizedBox(height: 12),
                    if (_error != null) ...[
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 8),
                    ],
                    if (_success != null) ...[
                      Text(_success!, style: const TextStyle(color: Colors.green)),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _loading ? null : _onRegister,
                            child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Register'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Back to login'),
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Future<void> _onRegister() async {
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final err = await auth.register(
      username: _username.text.trim(),
      password: _password.text,
      name: _name.text.trim(),
      email: _email.text.trim().isEmpty ? null : _email.text.trim(),
    );
    if (err != null) {
      setState(() {
        _error = err;
        _loading = false;
      });
      return;
    }
    setState(() {
      _success = 'Registration submitted. Admin approval required (mock).';
      _loading = false;
    });
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _name.dispose();
    _email.dispose();
    super.dispose();
  }
}
