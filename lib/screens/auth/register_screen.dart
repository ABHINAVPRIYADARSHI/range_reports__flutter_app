import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  String? _error;
  String? _success;

  // Role & jurisdiction state
  String? _selectedRole; // 'ADMIN' | 'NODAL_OFFICER' | 'RANGE_OFFICER'
  String? _selectedCommissionerate;
  String? _selectedDivisionForRange;
  final Set<String> _selectedDivisions = <String>{}; // for NODAL_OFFICER
  final Set<String> _selectedRanges = <String>{}; // for RANGE_OFFICER

  // Hierarchy data from view_active_comm_div_range_hierarchy
  List<Map<String, dynamic>> _hierarchy = [];
  bool _hierarchyLoading = false;
  String? _hierarchyError;

  // NEW: Scroll controllers for inner lists
  final ScrollController _nodalDivisionsScrollController = ScrollController();
  final ScrollController _rangesScrollController = ScrollController();

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
  void initState() {
    super.initState();
    _loadHierarchy();
  }

  Future<void> _loadHierarchy() async {
    setState(() {
      _hierarchyLoading = true;
      _hierarchyError = null;
    });

    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('view_active_comm_div_range_hierarchy')
          .select();

      if (response is List) {
        setState(() {
          _hierarchy = List<Map<String, dynamic>>.from(
            response.map((e) => Map<String, dynamic>.from(e as Map)),
          );
        });
      } else {
        setState(() {
          _hierarchyError =
              'Unexpected response while loading jurisdiction data.';
        });
      }
    } catch (e) {
      setState(() {
        _hierarchyError = 'Failed to load jurisdiction data.';
      });
    } finally {
      setState(() {
        _hierarchyLoading = false;
      });
    }
  }

  List<Map<String, String>> get _commissionerateOptions {
    final seen = <String>{};
    final result = <Map<String, String>>[];

    for (final row in _hierarchy) {
      final id = row['commissionerate_id']?.toString();
      if (id == null || id.isEmpty || seen.contains(id)) continue;
      seen.add(id);
      result.add({
        'id': id,
        'name': row['commissionerate_name']?.toString() ?? id,
      });
    }

    result.sort(
      (a, b) => a['name']!.compareTo(b['name']!),
    );
    return result;
  }

  List<Map<String, String>> get _divisionOptions {
    if (_selectedCommissionerate == null) return [];
    final seen = <String>{};
    final result = <Map<String, String>>[];

    for (final row in _hierarchy) {
      if (row['commissionerate_id']?.toString() != _selectedCommissionerate) {
        continue;
      }
      final id = row['division_id']?.toString();
      if (id == null || id.isEmpty || seen.contains(id)) continue;
      seen.add(id);
      result.add({
        'id': id,
        'name': row['division_name']?.toString() ?? id,
      });
    }

    result.sort(
      (a, b) => a['name']!.compareTo(b['name']!),
    );
    return result;
  }

  List<Map<String, String>> get _rangeOptions {
    if (_selectedCommissionerate == null ||
        _selectedDivisionForRange == null) {
      return [];
    }

    final seen = <String>{};
    final result = <Map<String, String>>[];

    for (final row in _hierarchy) {
      if (row['commissionerate_id']?.toString() != _selectedCommissionerate) {
        continue;
      }
      if (row['division_id']?.toString() != _selectedDivisionForRange) {
        continue;
      }
      final id = row['range_id']?.toString();
      if (id == null || id.isEmpty || seen.contains(id)) continue;
      seen.add(id);
      result.add({
        'id': id,
        'name': row['range_name']?.toString() ?? id,
      });
    }

    result.sort(
      (a, b) => a['name']!.compareTo(b['name']!),
    );
    return result;
  }

  Widget _buildRoleAndJurisdictionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Role & Jurisdiction',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Role dropdown
        DropdownButtonFormField<String>(
          value: _selectedRole,
          decoration: const InputDecoration(
            labelText: 'Select Role',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: const [
            DropdownMenuItem(
              value: 'admin',
              child: Text('Admin'),
            ),
            DropdownMenuItem(
              value: 'nodal_officer',
              child: Text('Nodal Officer'),
            ),
            DropdownMenuItem(
              value: 'range_officer',
              child: Text('Range Officer'),
            ),
          ],
          onChanged: _loading
              ? null
              : (value) {
                  setState(() {
                    _selectedRole = value;
                    // Reset jurisdiction selection when role changes
                    _selectedCommissionerate = null;
                    _selectedDivisionForRange = null;
                    _selectedDivisions.clear();
                    _selectedRanges.clear();
                  });
                },
        ),
        const SizedBox(height: 16),

        if (_hierarchyLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),

        if (_hierarchyError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              _hierarchyError!,
              style: const TextStyle(color: Colors.red),
            ),
          ),

        // Only show jurisdiction controls if we have some hierarchy data
        if (_hierarchy.isNotEmpty && _selectedRole != null) ...[
          const SizedBox(height: 8),
          _buildCommissionerateDropdown(),
          const SizedBox(height: 12),
          if (_selectedRole == 'nodal_officer') _buildNodalDivisionSelector(),
          if (_selectedRole == 'range_officer') _buildRangeSelectors(),
        ],
      ],
    );
  }

  Widget _buildCommissionerateDropdown() {
    final options = _commissionerateOptions;
    return DropdownButtonFormField<String>(
      value: _selectedCommissionerate,
      decoration: const InputDecoration(
        labelText: 'Commissionerate',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: options
          .map(
            (opt) => DropdownMenuItem<String>(
              value: opt['id'],
              child: Text('${opt['id']} - ${opt['name']}'),
            ),
          )
          .toList(),
      onChanged: _loading
          ? null
          : (value) {
              setState(() {
                _selectedCommissionerate = value;
                // Reset lower levels
                _selectedDivisions.clear();
                _selectedDivisionForRange = null;
                _selectedRanges.clear();
              });
            },
    );
  }

  Widget _buildNodalDivisionSelector() {
    final divisions = _divisionOptions;

    if (_selectedCommissionerate == null) {
      return const Text(
        'Select a commissionerate to choose divisions.',
        style: TextStyle(fontSize: 13),
      );
    }

    if (divisions.isEmpty) {
      return const Text(
        'No active divisions found for the selected commissionerate.',
        style: TextStyle(fontSize: 13),
      );
    }

        return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Divisions (one or more)',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 150,
          child: Scrollbar(
            thumbVisibility: true,
            controller: _nodalDivisionsScrollController,
            child: ListView.builder(
              controller: _nodalDivisionsScrollController,
              itemCount: divisions.length,
              itemBuilder: (context, index) {
                final div = divisions[index];
                final id = div['id']!;
                final name = div['name']!;
                final selected = _selectedDivisions.contains(id);

                return CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: selected,
                  title: Text('$id - $name'),
                  onChanged: _loading
                      ? null
                      : (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedDivisions.add(id);
                            } else {
                              _selectedDivisions.remove(id);
                            }
                          });
                        },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRangeSelectors() {
    final divisions = _divisionOptions;
    final ranges = _rangeOptions;

    if (_selectedCommissionerate == null) {
      return const Text(
        'Select a commissionerate to choose division and ranges.',
        style: TextStyle(fontSize: 13),
      );
    }

    if (divisions.isEmpty) {
      return const Text(
        'No active divisions found for the selected commissionerate.',
        style: TextStyle(fontSize: 13),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Division dropdown
        DropdownButtonFormField<String>(
          value: _selectedDivisionForRange,
          decoration: const InputDecoration(
            labelText: 'Division',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: divisions
              .map(
                (div) => DropdownMenuItem<String>(
                  value: div['id'],
                  child: Text('${div['id']} - ${div['name']}'),
                ),
              )
              .toList(),
              onChanged: _loading
              ? null
              : (value) {
                  setState(() {
                    _selectedDivisionForRange = value;
                    _selectedRanges.clear();
                  });
                },
        ),
        const SizedBox(height: 12),

        if (_selectedDivisionForRange == null)
          const Text(
            'Select a division to choose ranges.',
            style: TextStyle(fontSize: 13),
          )
        else if (ranges.isEmpty)
          const Text(
            'No active ranges found for the selected division.',
            style: TextStyle(fontSize: 13),
          )
        else ...[
          const Text(
            'Select Ranges (one or more)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 150,
            child: Scrollbar(
              thumbVisibility: true,
              controller: _rangesScrollController,
              child: ListView.builder(
                controller: _rangesScrollController,
                itemCount: ranges.length,
                itemBuilder: (context, index) {
                  final r = ranges[index];
                  final id = r['id']!;
                  final name = r['name']!;
                  final selected = _selectedRanges.contains(id);

                  return CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: selected,
                    title: Text('$id - $name'),
                    onChanged: _loading
                        ? null
                        : (bool? value) {
                            setState(() {
                              if (value == true) {
                                _selectedRanges.add(id);
                              } else {
                                _selectedRanges.remove(id);
                              }
                            });
                          },
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
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
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600),
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
                            validator: (value) =>
                                value?.isEmpty ?? true ? 'Username is required' : null,
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
                            validator: (value) =>
                                value?.isEmpty ?? true ? 'Full name is required' : null,
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

                          // Role & Jurisdiction
                          _buildRoleAndJurisdictionSection(),

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
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 24),
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
                            onPressed:
                                _loading ? null : () => Navigator.pop(context),
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
      final phoneNumber = _phone.text.trim();

      // Final phone validation
      final phoneError = _validatePhone(phoneNumber);
      if (phoneError != null) {
        setState(() {
          _error = phoneError;
          _loading = false;
        });
        return;
      }

      // Validate role & jurisdiction before calling backend
      final roles = _buildRolesPayload();
      if (roles == null) {
        // _buildRolesPayload will set _error itself
        setState(() {
          _loading = false;
        });
        return;
      }
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final err = await auth.registerWithRoles(
        username: _username.text.trim(),
        password: _password.text,
        name: _name.text.trim(),
        phone: phoneNumber,
        email: _email.text.trim().isNotEmpty ? _email.text.trim() : null,
        roles: roles,
      );

      if (mounted) {
        setState(() {
          if (err != null) {
            _error = err;
          } else {
            _success = 'Registration submitted. Admin approval required.';
            // Clear form on success
            _username.clear();
            _name.clear();
            _phone.clear();
            _email.clear();
            _password.clear();
            _selectedRole = null;
            _selectedCommissionerate = null;
            _selectedDivisionForRange = null;
            _selectedDivisions.clear();
            _selectedRanges.clear();
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

  /// Builds the roles list based on current selections.
  /// Returns `null` if validation fails and sets `_error`.
  List<Map<String, String?>>? _buildRolesPayload() {
    if (_selectedRole == null) {
      _error = 'Please select a role.';
      return null;
    }

    if (_hierarchy.isEmpty) {
      _error = 'Jurisdiction data is not available. Please try again later.';
      return null;
    }

    final role = _selectedRole;

    if (role == 'admin') {
      if (_selectedCommissionerate == null ||
          _selectedCommissionerate!.isEmpty) {
        _error = 'Please select a commissionerate for Admin.';
        return null;
      }
      // Only one commissionerate allowed
      return [
        {
          'role': role, // 'admin'
          'commissionerate_id': _selectedCommissionerate,
          'division_id': null,
          'range_id': null,
        },
      ];
    }

    if (role == 'nodal_officer') {
      if (_selectedCommissionerate == null) {
        _error = 'Please select a commissionerate.';
        return null;
      }
      if (_selectedDivisions.isEmpty) {
        _error = 'Please select at least one division for Nodal Officer.';
        return null;
      }

      return _selectedDivisions
          .map<Map<String, String?>>(
            (divId) => {
              'role': role, // 'nodal_officer'
              'commissionerate_id': _selectedCommissionerate,
              'division_id': divId,
              'range_id': null,
            },
          )
          .toList();
    }

    if (role == 'range_officer') {
      if (_selectedCommissionerate == null) {
        _error = 'Please select a commissionerate.';
        return null;
      }
      if (_selectedDivisionForRange == null) {
        _error = 'Please select a division for Range Officer.';
        return null;
      }
      if (_selectedRanges.isEmpty) {
        _error = 'Please select at least one range for Range Officer.';
        return null;
      }

      return _selectedRanges
          .map<Map<String, String?>>(
            (rangeId) => {
              'role': role, // 'range_officer'
              'commissionerate_id': _selectedCommissionerate,
              'division_id': _selectedDivisionForRange,
              'range_id': rangeId,
            },
          )
          .toList();
    }

    _error = 'Invalid role selection.';
    return null;
  }


  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _nodalDivisionsScrollController.dispose();
    _rangesScrollController.dispose();
    super.dispose();
  }

}
