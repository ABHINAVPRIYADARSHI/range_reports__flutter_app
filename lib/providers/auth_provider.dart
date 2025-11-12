import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  String? _userId;
  String? _username;
  String? _name;
  String? _status;
  List<Map<String, dynamic>> _roles = [];

  bool get isLoggedIn => _userId != null && _status == 'active';

  /// simple user getter for older UI expecting `auth.user`
  Map<String, dynamic>? get user {
    if (_userId == null) return null;
    return {
      'id': _userId,
      'username': _username,
      'name': _name,
      'status': _status,
      'roles': _roles,
    };
  }

  List<Map<String, dynamic>> get roles => _roles;
  String? get userId => _userId;
  String? get username => _username;
  String? get status => _status;

  static const _kPrefsUserKey = 'app_user_row';

  AuthProvider() {
    _tryRestoreFromPrefs();
  }

  Future<void> _tryRestoreFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefsUserKey);
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _userId = map['user_id'] as String?;
      _username = map['username'] as String?;
      _name = map['name'] as String?;
      _status = map['status'] as String?;
      final rolesList = map['roles'] as List<dynamic>? ?? [];
      _roles = rolesList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      notifyListeners();
    } catch (e) {
      // ignore corrupted prefs
    }
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final map = {
      'user_id': _userId,
      'username': _username,
      'name': _name,
      'status': _status,
      'roles': _roles,
    };
    await prefs.setString(_kPrefsUserKey, jsonEncode(map));
  }

  Future<void> _clearPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefsUserKey);
  }

  /// Register via rpc_register (creates pending user and hashes password server-side)
  /// Returns null on success, or string error message.
  Future<String?> register({
    required String username,
    required String password,
    required String name,
    String? phone,
  }) async {
    try {
      final client = Supabase.instance.client;
      final res = await client.rpc('rpc_register', params: {
        'p_username': username,
        'p_password': password,
        'p_name': name,
        'p_phone': phone ?? '',
      });

      if (res.error != null) {
        return res.error!.message;
      }
      // success: res.data will contain created user info (as list)
      return null;
    } catch (e) {
      return 'Registration failed: $e';
    }
  }

  /// Call rpc_login which verifies credentials and returns user row + roles
  /// Returns null on success; returns string error message on failure.
  Future<String?> login(String usernameInput, String password) async {
    final client = Supabase.instance.client;
    try {
      final payload = {
        'p_username': usernameInput,
        'p_password': password,
      };

      final response = await client.rpc('rpc_login', params: {
        'payload': payload,
      });

      // The response is already the data array
      final data = response as List<dynamic>;
      if (data.isEmpty) {
        return 'Invalid username or password';
      }

      final row = data[0] as Map<String, dynamic>;
      _userId = row['user_id']?.toString();
      _username = row['username'] as String?;
      _name = row['name'] as String?;
      _status = row['status'] as String?;
      final rolesRaw = row['roles'];
      if (rolesRaw is List) {
        _roles = rolesRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } else {
        _roles = [];
      }

      await _saveToPrefs();
      notifyListeners();

      return null;
    } catch (e) {
      return 'Login error: $e';
    }
  }

  Future<void> logout() async {
    _userId = null;
    _username = null;
    _name = null;
    _status = null;
    _roles = [];
    await _clearPrefs();
    // no supabase auth signOut since we're not using Supabase Auth
    notifyListeners();
  }

    /// Refresh roles from DB (safe only if _userId is not null)
  Future<void> refreshRolesFromDb() async {
    if (_userId == null) return; // guard nullable _userId

    final client = Supabase.instance.client;
    try {
      final dynamic res = await client
          .from('user_roles')
          .select('role, commissionerate_id, division_id, range_id')
          .eq('user_id', _userId!);

      // The client library version you're using returns the parsed data directly.
      // If it returned an error object it would have thrown; so handle the data case.
      if (res is List) {
        final list = res as List<dynamic>;
        _roles = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        await _saveToPrefs();
        notifyListeners();
      } else {
        // Unexpected response type — do nothing (or optionally log)
      }
    } catch (e) {
      // Query failed (network, permission, etc.) — handle/log if needed
      // print('refreshRolesFromDb error: $e');
      return;
    }
  }
}
