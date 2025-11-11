import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  AppUser? _user;
  bool get isLoggedIn => _user != null;
  AppUser? get user => _user;

  // Mock user store (in-memory)
  final Map<String, String> _users = {}; // username -> password
  final Uuid _uuid = const Uuid();

  AuthProvider() {
    // seed a demo user (for quick testing)
    _users['ro_demo'] = 'password123';
  }

  Future<String?> register({
    required String username,
    required String password,
    required String name,
    String? email,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400)); // simulate work
    if (_users.containsKey(username)) {
      return 'Username already exists';
    }
    _users[username] = password;
    // create user but don't auto-login
    // In real world: create record in DB and set status pending/active
    return null;
  }

  Future<String?> login({
    required String username,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400)); // simulate network
    final existing = _users[username];
    if (existing == null) return 'User not found';
    if (existing != password) return 'Invalid credentials';
    _user = AppUser(
      id: _uuid.v4(),
      username: username,
      name: username, // placeholder
    );
    notifyListeners();
    return null;
  }

  void logout() {
    _user = null;
    notifyListeners();
  }
}
