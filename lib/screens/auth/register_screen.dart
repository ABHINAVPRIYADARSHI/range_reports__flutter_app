import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/auth_form_field.dart';
import 'package:flutter/services.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;
  String? _success;

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    final phoneRegex = RegExp(r'^\d{10}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'Enter a valid 10-digit phone number';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: LayoutBuilder(builder: (context, constraints) {
        final isLarge = constraints.maxWidth > 700;
        return Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isLarge ? 600 : 420,
                minHeight: constraints.maxHeight,
              ),
              child: IntrinsicHeight(
                child: Card(
                  elevation: 6,
                  margin: const EdgeInsets.all(24),
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Form(
                      key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Create account',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),
                      
                      // Username Field
                      TextFormField(
                        controller: _username,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        validator: (value) => value?.isEmpty ?? true ? 'Username is required' : null,
                      ),
                      const SizedBox(height: 16),
                      
                      // Full Name Field
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        validator: (value) => value?.isEmpty ?? true ? 'Full name is required' : null,
                      ),
                      const SizedBox(height: 16),
                      
                      // Phone Number Field
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          hintText: 'Enter 10-digit number',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixText: '+91 ',
                        ),
                        validator: _validatePhone,
                      ),
                      const SizedBox(height: 16),
                      
                      // Email Field (Optional)
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email (optional)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Password Field
                      TextFormField(
                        controller: _password,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password is required';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Error/Success Messages
                      if (_error != null) ...[
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                      ],
                      
                      if (_success != null) ...[
                        Text(
                          _success!,
                          style: const TextStyle(color: Colors.green),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                      ],
                      
                      // Register Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _onRegister,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                            elevation: 2,
                          ),
                          child: _loading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Register',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Back to Login
                      TextButton(
                        onPressed: _loading ? null : () => Navigator.pop(context),
                        child: const Text('Already have an account? Sign in'),
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
      }),
    );
  }

  Future<void> _onRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final phoneNumber = _phone.text.trim();
      
      // Final phone validation
      final phoneError = _validatePhone(phoneNumber);
      if (phoneError != null) {
        setState(() => _error = phoneError);
        return;
      }

      final err = await auth.register(
        username: _username.text.trim(),
        password: _password.text,
        name: _name.text.trim(),
        phone: phoneNumber,
        email: _email.text.trim().isNotEmpty ? _email.text.trim() : null,
      );

      if (mounted) {
        setState(() {
          if (err != null) {
            _error = err;
          } else {
            _success = 'Registration submitted. Admin approval required.';
            // Clear form on success
            if (_success != null) {
              _username.clear();
              _name.clear();
              _phone.clear();
              _email.clear();
              _password.clear();
            }
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'An error occurred. Please try again.';
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }
}
