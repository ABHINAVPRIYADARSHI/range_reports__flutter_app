import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/scope_dropdown.dart';
import '../widgets/scope_picker.dart';
import '../widgets/loader_overlay.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _checkedPicker = false;
  bool _isLoading = false; // <-- new

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_checkedPicker) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowScopePicker());
      _checkedPicker = true;
    }
  }

  Future<void> _maybeShowScopePicker() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final scopes = auth.scopesFromRoles;

    // if multiple scopes and no active scope, open picker
    if (scopes.length > 1 && auth.activeScope == null) {
      final result = await showDialog(
        context: context,
        barrierDismissible: false, // <-- user must choose or cancel explicitly
        builder: (_) => ScopePickerDialog(scopes: scopes),
      ) as Map<String, dynamic>?;

      if (result != null) {
        setState(() => _isLoading = true); // <-- show loader
        final ActiveScope s = result['scope'] as ActiveScope;
        final remember = result['remember'] as bool? ?? true;
        await auth.setActiveScope(s, persist: remember);
        setState(() => _isLoading = false); // <-- hide loader
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final themeProv = Provider.of<ThemeProvider>(context, listen: false);
    final username = auth.username ?? 'Officer';
    final active = auth.activeScope;

    return Scaffold(
        appBar: AppBar(
        title: const Text('Home'),
        actions: [
          // Add a flexible space to push the icons to the right
          const Spacer(),
          // Make the dropdown smaller
          const SizedBox(
            width: 150, // Fixed width for the dropdown
            child: ScopeDropdown(),
          ),
          // Add some spacing
          const SizedBox(width: 8),
          // Theme toggle button
          IconButton(
            tooltip: 'Toggle theme',
            icon: Icon(themeProv.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => themeProv.toggleTheme(),
          ),
          // Logout button
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () {
              auth.logout();
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      body: LoaderOverlay(
        isLoading: _isLoading,
        message: 'Applying selection...',
        child: LayoutBuilder(builder: (context, constraints) {
          final isLarge = constraints.maxWidth > 900;
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isLarge ? 1200 : 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Hello, $username', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    if (active != null) ...[
                      Text('Active scope: ${active.label} (${active.role.replaceAll('_', ' ')})'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Open daily form (not implemented)')),
                          );
                        },
                        child: const Text('Submit Today\'s Report'),
                      ),
                    ] else ...[
                      const Text('No active scope selected. Please choose one from the dropdown.'),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
