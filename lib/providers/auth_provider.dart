import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Simple ActiveScope model used by the UI
class ActiveScope {
  final String role; // 'range_officer', 'nodal_officer', 'admin'
  final String commissionerateId;
  final String? commissionerateName;
  final String? divisionId;
  final String? divisionName;
  final String? rangeId;
  final String? rangeName;
  final String label;

  ActiveScope({
    required this.role,
    required this.commissionerateId,
    this.commissionerateName,
    this.divisionId,
    this.divisionName,
    this.rangeId,
    this.rangeName,
    required this.label,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ActiveScope &&
        other.role == role &&
        other.commissionerateId == commissionerateId &&
        other.divisionId == divisionId &&
        other.rangeId == rangeId;
  }

  @override
  int get hashCode => Object.hash(role, commissionerateId, divisionId, rangeId);

  Map<String, dynamic> toJson() => {
        'role': role,
        'commissionerateId': commissionerateId,
        'commissionerateName': commissionerateName,
        'divisionId': divisionId,
        'divisionName': divisionName,
        'rangeId': rangeId,
        'rangeName': rangeName,
        'label': label,
      };

  static ActiveScope? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return ActiveScope(
      role: json['role'] as String,
      commissionerateId: json['commissionerateId'] as String,
      commissionerateName: json['commissionerateName'] as String?,
      divisionId: json['divisionId'] as String?,
      divisionName: json['divisionName'] as String?,
      rangeId: json['rangeId'] as String?,
      rangeName: json['rangeName'] as String?,
      label: json['label'] as String,
    );
  }
}

class AuthProvider extends ChangeNotifier {
  String? _userId;
  String? _username;
  String? _name;
  String? _status;
  List<Map<String, dynamic>> _roles = [];

  ActiveScope? _activeScope;

  // prefs keys
  static const _kPrefsUserKey = 'app_user_row';
  static const _kPrefsActiveScope = 'app_active_scope';

  // getters
  bool get isLoggedIn => _userId != null && _status == 'active';
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

  String? get userId => _userId;
  String? get username => _username;
  String? get status => _status;
  List<Map<String, dynamic>> get roles => List.unmodifiable(_roles);
  ActiveScope? get activeScope => _activeScope;

  AuthProvider() {
    _tryRestoreFromPrefs();
  }

  // restore user + scope on startup
  Future<void> _tryRestoreFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefsUserKey);
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _userId = map['user_id'] as String?;
        _username = map['username'] as String?;
        _name = map['name'] as String?;
        _status = map['status'] as String?;
        final rolesList = map['roles'] as List<dynamic>? ?? [];
        _roles = rolesList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }

    final rawScope = prefs.getString(_kPrefsActiveScope);
    if (rawScope != null) {
      try {
        final sMap = jsonDecode(rawScope) as Map<String, dynamic>;
        _activeScope = ActiveScope.fromJson(sMap);
      } catch (_) {}
    }

    notifyListeners();
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

  Future<void> _saveActiveScopeToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (_activeScope == null) {
      await prefs.remove(_kPrefsActiveScope);
      return;
    }
    await prefs.setString(_kPrefsActiveScope, jsonEncode(_activeScope!.toJson()));
  }

  Future<void> _clearPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefsUserKey);
    await prefs.remove(_kPrefsActiveScope);
  }

  /// Register (RPC wrapper) - returns null on success, or string message on error
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
      return null;
    } catch (e) {
      return 'Registration failed: $e';
    }
  }

  /// Login using rpc_login (server-side verifies password)
  Future<String?> login(String usernameInput, String password) async {
    final client = Supabase.instance.client;
    try {
      final dynamic rawResponse = await client.rpc('rpc_login', params: {
        'payload': {'p_username': usernameInput, 'p_password': password}
      });

      // rawResponse may be:
      //  - a List<dynamic> (parsed data) -> use it directly
      //  - or a PostgrestResponse-like object with .error and .data
      List<dynamic>? dataList;
      String? rpcError;

      if (rawResponse is List) {
        dataList = rawResponse;
      } else {
        // try to handle PostgrestResponse-like object
        try {
          // some versions allow .error and .data
          final dynamic maybeError = rawResponse.error;
          final dynamic maybeData = rawResponse.data;
          if (maybeError != null) {
            rpcError = (maybeError is String) ? maybeError : maybeError.toString();
          } else if (maybeData is List) {
            dataList = maybeData;
          } else if (maybeData != null) {
            // sometimes data is a single object
            dataList = [maybeData];
          }
        } catch (_) {
          // fallback: try to treat rawResponse as map-like
          try {
            final asMap = Map<String, dynamic>.from(rawResponse as Map);
            if (asMap.containsKey('error')) {
              rpcError = asMap['error']?.toString();
            }
            if (asMap.containsKey('data')) {
              final d = asMap['data'];
              if (d is List) dataList = d;
              else if (d != null) dataList = [d];
            }
          } catch (__) {
            // couldn't interpret response shape
          }
        }
      }

      if (rpcError != null) {
        return 'Login failed: $rpcError';
      }

      if (dataList == null || dataList.isEmpty) {
        // no rows returned -> invalid credentials
        return 'Invalid username or password';
      }

      final row = Map<String, dynamic>.from(dataList[0] as Map);
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

      // If user has exactly one scope, set it automatically
      if (_roles.length == 1) {
        _activeScope = _scopeFromRoleMap(_roles.first);
        await _saveActiveScopeToPrefs();
      } else {
        // validate persisted scope still present in roles
        if (_activeScope != null) {
          final stillPresent = _roles.any((r) =>
              (r['role'] == _activeScope!.role) &&
              ((r['range_id']?.toString() ?? '') == (_activeScope!.rangeId ?? '')) &&
              ((r['division_id']?.toString() ?? '') == (_activeScope!.divisionId ?? '')) &&
              ((r['commissionerate_id']?.toString() ?? '') == _activeScope!.commissionerateId));
          if (!stillPresent) {
            _activeScope = null;
            await _saveActiveScopeToPrefs();
          }
        }
      }

      await _saveToPrefs();
      notifyListeners();
      return null;
    } catch (e, st) {
      // helpful debug info while developing
      debugPrint('login exception: $e\n$st');
      return 'Login error: $e';
    }
  }


  /// Logout
  Future<void> logout() async {
    _userId = null;
    _username = null;
    _name = null;
    _status = null;
    _roles = [];
    _activeScope = null;
    await _clearPrefs();
    notifyListeners();
  }

  /// Set active scope (persist if requested)
  Future<void> setActiveScope(ActiveScope scope, {bool persist = true}) async {
    _activeScope = scope;
    if (persist) await _saveActiveScopeToPrefs();
    notifyListeners();
  }

  Future<void> clearActiveScope() async {
    _activeScope = null;
    await _saveActiveScopeToPrefs();
    notifyListeners();
  }

  /// Utility to construct ActiveScope from a role row (user_roles JSON)
  ActiveScope _scopeFromRoleMap(Map<String, dynamic> role) {
  final String roleType = role['role'] ?? '';
  final String comId = role['commissionerate_id'] ?? '';
  final String divId = role['division_id'];
  final String rngId = role['range_id'];

  final String? comName = role['commissionerate_name'];
  final String? divName = role['division_name'];
  final String? rngName = role['range_name'];

  // Build a friendly label for the UI
  String label;
  if (roleType == 'admin') {
    label = '${comName ?? comId} (Admin)';
  } else if (roleType == 'nodal_officer') {
    label = '${divName ?? divId} — ${comName ?? comId}';
  } else if (roleType == 'range_officer') {
    label = '${rngName ?? rngId} — ${divName ?? divId}';
  } else {
    label = roleType;
  }

  return ActiveScope(
    role: roleType,
    commissionerateId: comId,
    commissionerateName: comName,
    divisionId: divId,
    divisionName: divName,
    rangeId: rngId,
    rangeName: rngName,
    label: label,
  );
}


  /// Convenience: list of ActiveScope objects built from _roles
  List<ActiveScope> get scopesFromRoles {
    return _roles.map((r) => _scopeFromRoleMap(r)).toList();
  }
}
