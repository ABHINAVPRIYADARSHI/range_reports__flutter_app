import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:html' as html; // web-only APIs (guarded by kIsWeb)
import 'dart:js_util' as js_util;
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
    final themeProv = Provider.of<ThemeProvider>(context, listen: true);
    final gradientColors = themeProv.gradientColors;
    final theme = Theme.of(context);
    final isDark = themeProv.isDarkMode;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.black,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.white,
            ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(
            color: isDark ? Colors.white : Colors.black87,
          ),
          actions: [
            IconButton(
              icon: Icon(
                isDark ? Icons.light_mode : Icons.dark_mode,
                color: isDark ? Colors.white : Colors.black87,
              ),
              onPressed: themeProv.toggleTheme,
              tooltip: 'Toggle theme',
            ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isLarge = constraints.maxWidth > 700;
                  return Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isLarge ? 500 : double.infinity,
                      ),
                      child: Card(
                        elevation: 12,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 10),
                              // App Logo
                              Image.network(
                                'icons/Icon-192x192.png',
                                height: 80,
                                width: 80,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.account_circle,
                                    size: 80,
                                    color: Colors.grey,
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Welcome Back!',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Please sign in to continue',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.7),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 32),
                              AuthFormField(
                                label: 'Username',
                                controller: _username,
                              ),
                              const SizedBox(height: 20),
                              AuthFormField(
                                label: 'Password',
                                controller: _password,
                                obscure: true,
                              ),
                              const SizedBox(height: 24),
                              if (_error != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.errorContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        color:
                                            theme.colorScheme.onErrorContainer,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: TextStyle(
                                            color: theme
                                                .colorScheme
                                                .onErrorContainer,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Login Button
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _onLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor:
                                        theme.colorScheme.onPrimary,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          'Sign In',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),

                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Don\'t have an account?',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.7),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushNamed(
                                        context,
                                        Routes.register,
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      'Sign up',
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _hasExistingPushSubscription() async {
    if (!kIsWeb || !html.Notification.supported) return false;

    try {
      final swContainer = html.window.navigator.serviceWorker;
      if (swContainer == null) return false;

      final registration = await swContainer.ready;
      final pushManager = js_util.getProperty(registration, 'pushManager');
      if (pushManager == null) return false;

      final existingSubJs = await js_util.promiseToFuture(
        js_util.callMethod(pushManager, 'getSubscription', []),
      );

      return existingSubJs != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> _requestNotificationPermissionAndSubscribe() async {
    if (!kIsWeb) {
      debugPrint('Not on web platform, returning');
      return; // only web
    }

    // Check Notification API support
    if (!html.Notification.supported) {
      debugPrint('Notification API not supported, returning');
      return;
    }

    try {
      final permission = await html.Notification.requestPermission();
      if (permission != 'granted') {
        debugPrint('Permission not granted: $permission, returning');
        return;
      }

      final swContainer = html.window.navigator.serviceWorker;
      if (swContainer == null) {
        debugPrint('Service worker container is null, returning');
        return;
      }

      try {
        final registration = await swContainer.ready.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            throw TimeoutException(
              'Service worker registration timed out - no service worker found',
              const Duration(seconds: 5),
            );
          },
        );
        // --- Check PushManager support ---
        if (!js_util.hasProperty(registration, 'pushManager')) {
          debugPrint('PushManager not supported on this browser / registration',
          );
          return;
        }

        final pushManager = js_util.getProperty(registration, 'pushManager');
        if (pushManager == null) {
          debugPrint('pushManager is null, returning');
          return;
        }

        if (!js_util.hasProperty(pushManager, 'subscribe')) {
          debugPrint('pushManager.subscribe is not available');
          return;
        }

        // VAPID Public Key
        final String vapidPublicKey =
            'BMtsYPzIYCkjIv4YwlZaCq4Vwve8QfpeH1LrKtyRSAuQsK7JVR1FnBVxxT1rsfL8zpwg1qFb5by4WdyT6C9RvYo';
        final Uint8List applicationServerKey = _urlBase64ToUint8List(
          vapidPublicKey,
        );

        // Prepare options object
        final options = js_util.jsify({
          'userVisibleOnly': true,
          'applicationServerKey': applicationServerKey,
        });

        // Call subscribe and make sure we actually got a Promise
        final jsResult = js_util.callMethod(pushManager, 'subscribe', [
          options,]);
        if (jsResult == null) {
          debugPrint('pushManager.subscribe returned null (Push API likely unsupported)',
          );
          return;
        }

        final subscription = await js_util.promiseToFuture(jsResult);

        // Extract subscription data
        final subJsonJs = js_util.callMethod(subscription, 'toJSON', []);

        // Now safely read from that JSON object
        final endpoint = js_util.getProperty(subJsonJs, 'endpoint') as String?;
        final keysObj = js_util.getProperty(subJsonJs, 'keys');

        String? p256dh;
        String? auth;
        if (keysObj != null) {
          p256dh = js_util.getProperty(keysObj, 'p256dh') as String?;
          auth = js_util.getProperty(keysObj, 'auth') as String?;
        }
        // Create a clean Dart Map for storage
        final subscriptionJson = <String, dynamic>{
          'endpoint': endpoint,
          'p256dh': p256dh, 
          'auth': auth,
        };
        // debugPrint('Subscription JSON: $subscriptionJson');
        // final Map<String, dynamic> subJson = {
        //   'subscription': subscriptionJson,
        //   'endpoint': endpoint,
        //   'keys': <String, dynamic>{'p256dh': p256dh, 'auth': auth},
        // };

        // Save push subscription to database
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.savePushSubscription(subscriptionJson);
      } catch (e, st) {
        debugPrint('Error during push subscription: $e\n$st');
        return;
      }
    } catch (e, st) {
      debugPrint('subscribe wrapper error: $e\n$st');
    }
  }

  // Helper to fetch vapid key — customize this to read from env/secure endpoint or SupabaseService
  // Future<String> _fetchVapidPublicKey() async {
  //   // TODO: return your VAPID public key. Example:
  //   // return const String.fromEnvironment('VAPID_PUBLIC_KEY');
  //   // Or call _supabaseService.getVapidPublicKey() if you store it in Supabase config.
  //   try {
  //     return await _supabaseService.getVapidPublicKey(); // implement this method
  //   } catch (_) {
  //     return '';
  //   }
  // }

  Uint8List _urlBase64ToUint8List(String base64String) {
    final padding = '=' * ((4 - base64String.length % 4) % 4);
    final base64 = (base64String + padding)
        .replaceAll('-', '+')
        .replaceAll('_', '/');
    return base64Decode(base64);
  }

  Future<void> _onLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final username = _username.text.trim();
    final password = _password.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'Please enter username and password';
        _loading = false;
      });
      return;
    }

    final err = await auth.login(username, password);
    if (err != null) {
      // auth.login returns an error message string on failure
      setState(() {
        _error = err;
        _loading = false;
      });
      return;
    }

    // login succeeded; check status
    if (auth.status != 'active') {
      setState(() {
        _error = 'Account is ${auth.status}. Please wait for admin approval.';
        _loading = false;
      });
      return;
    }

    // successful and active — navigate to home
    setState(() {
      _loading = false;
      _error = null;
    });

    if (mounted) {
      final alreadySubscribed = await _hasExistingPushSubscription();
      // final wantReminders = await showDialog<bool>(
      //   context: context,
      //   builder: (_) => AlertDialog(
      //     title: const Text('Daily reminders?'),
      //     content: const Text(
      //       'Do you want daily reminders to file your report?',
      //     ),
      //     actions: [
      //       TextButton(
      //         onPressed: () => Navigator.pop(context, false),
      //         child: const Text('Skip'),
      //       ),
      //       TextButton(
      //         onPressed: () => Navigator.pop(context, true),
      //         child: const Text('Enable'),
      //       ),
      //     ],
      //   ),
      // );

      // if (wantReminders == true) {
      if (!alreadySubscribed == true) {
        await _requestNotificationPermissionAndSubscribe();
      }

      // navigate to home (existing navigation call)
      Navigator.pushReplacementNamed(context, Routes.home);
    }
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }
}
