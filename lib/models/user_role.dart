// Create a new file: lib/models/user_role.dart


class UserRole {
  final String userId;
  final String username;
  final String name;
  final String phone;
  final String? email;
  final String userStatus; // pending, active, blocked
  final DateTime userCreatedAt;
  final String roleId;
  final String role;
  final bool roleIsActive;
  final DateTime roleCreatedAt;
  final String commissionerateId;
  final String commissionerateName;
  final String? divisionId;
  final String? divisionName;
  final String? rangeId;
  final String? rangeName;

  UserRole({
    required this.userId,
    required this.username,
    required this.name,
    required this.phone,
    this.email,
    required this.userStatus,
    required this.userCreatedAt,
    required this.roleId,
    required this.role,
    required this.roleIsActive,
    required this.roleCreatedAt,
    required this.commissionerateId,
    required this.commissionerateName,
    this.divisionId,
    this.divisionName,
    this.rangeId,
    this.rangeName,
  });

  factory UserRole.fromMap(Map<String, dynamic> map) {
    return UserRole(
      userId: map['user_id']?.toString() ?? '',
      username: map['username']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Unknown',
      phone: map['phone'].toString(),
      email: map['email']?.toString(),
      userStatus: map['user_status'].toString().toLowerCase(),
      userCreatedAt: map['user_created_at'] != null
          ? DateTime.tryParse(map['user_created_at'].toString()) ??
                DateTime.now()
          : DateTime.now(),
      role: map['role']?.toString() ?? '',
      roleId: map['role_id'].toString(),
      roleIsActive:
          map['role_is_active'] == true ||
          map['role_is_active'] == 1 ||
          (map['role_is_active']?.toString().toLowerCase() == 'true'),
      roleCreatedAt: map['role_created_at'] != null
          ? DateTime.tryParse(map['role_created_at'].toString()) ??
                DateTime.now()
          : DateTime.now(),
      commissionerateId: map['commissionerate_id'].toString(),
      commissionerateName: map['commissionerate_name'].toString(),
      divisionId: map['division_id']?.toString(),
      divisionName: map['division_name']?.toString(),
      rangeId: map['range_id']?.toString(),
      rangeName: map['range_name']?.toString(),
    );
  }
}
