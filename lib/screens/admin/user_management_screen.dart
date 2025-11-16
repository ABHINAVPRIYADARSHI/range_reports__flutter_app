import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../models/user_role.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  bool _isLoading = false;
  String? _error;

  // Section expand/collapse state
  final Map<String, bool> _sectionExpanded = {
    'pending': true,
    'active': true,
    'blocked': true,
  };

  @override
  void initState() {
    super.initState();
    _loadUserRoles();
  }

  Future<void> _loadUserRoles() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await context.read<AuthProvider>().fetchAllUserRoles();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load users: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Groups a flat list of UserRole rows into a map keyed by userId.
  Map<String, List<UserRole>> _groupByUser(List<UserRole> roles) {
    final Map<String, List<UserRole>> grouped = {};
    for (final role in roles) {
      grouped.putIfAbsent(role.userId, () => []).add(role);
    }
    return grouped;
  }

  Color _getStatusColor(String status, ThemeData theme) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'blocked':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return theme.textTheme.bodyMedium?.color ?? Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();

    final allRoles = authProvider.userRoles;
    final pendingRoles =
        allRoles.where((r) => r.userStatus == 'pending').toList();
    final activeRoles =
        allRoles.where((r) => r.userStatus == 'active').toList();
    final blockedRoles =
        allRoles.where((r) => r.userStatus == 'blocked').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUserRoles,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _loadUserRoles,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSection(
                          context: context,
                          statusKey: 'pending',
                          title: 'Pending Approvals',
                          flatRoles: pendingRoles,
                          theme: theme,
                        ),
                        _buildSection(
                          context: context,
                          statusKey: 'active',
                          title: 'Active Users',
                          flatRoles: activeRoles,
                          theme: theme,
                        ),
                        _buildSection(
                          context: context,
                          statusKey: 'blocked',
                          title: 'Blocked Users',
                          flatRoles: blockedRoles,
                          theme: theme,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required String statusKey, // 'pending' | 'active' | 'blocked'
    required String title,
    required List<UserRole> flatRoles,
    required ThemeData theme,
  }) {
    if (flatRoles.isEmpty) return const SizedBox.shrink();

    final grouped = _groupByUser(flatRoles); // userId -> List<UserRole>
    final isExpanded = _sectionExpanded[statusKey] ?? true;

    return Card(
      key: ValueKey('section-$statusKey'),
      margin: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _sectionExpanded[statusKey] = !isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '(${grouped.length})',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.hintColor,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            crossFadeState: isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 180),
            firstChild: Column(
              children: [
                const Divider(height: 1),
                ...grouped.entries.map((entry) {
                  final userId = entry.key;
                  final roles = entry.value;
                  if (roles.isEmpty) return const SizedBox.shrink();
                  final userStatus = roles.first.userStatus;
                  return _UserCard(
                    key: ValueKey(userId),
                    userId: userId,
                    roles: roles,
                    statusColor: _getStatusColor(userStatus, theme),
                    onDataChanged: _loadUserRoles,
                  );
                }).toList(),
              ],
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// A card representing a single user, containing all their roles with checkboxes,
/// plus user-level actions (Activate / Block / Unblock).
class _UserCard extends StatefulWidget {
  final String userId;
  final List<UserRole> roles;
  final Color statusColor;
  final Future<void> Function() onDataChanged;

  const _UserCard({
    super.key,
    required this.userId,
    required this.roles,
    required this.statusColor,
    required this.onDataChanged,
  });

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  late Map<String, bool> _roleActiveDraft; // roleId -> isActive
  bool _savingRoles = false;
  bool _changingStatus = false;

  UserRole get _primary => widget.roles.first;

  @override
  void initState() {
    super.initState();
    _initRoleDraft();
  }

  @override
  void didUpdateWidget(covariant _UserCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roles != widget.roles) {
      _initRoleDraft();
    }
  }

  void _initRoleDraft() {
    _roleActiveDraft = {
      for (final r in widget.roles) r.roleId: r.roleIsActive,
    };
  }

  Future<void> _handleUserStatusChange(String newStatus) async {
    setState(() {
      _changingStatus = true;
    });

    try {
      final auth = context.read<AuthProvider>();
      await auth.updateUserStatus(widget.userId, newStatus);

      // After status change, refresh all data.
      await widget.onDataChanged();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User status updated to $newStatus')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update user status')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _changingStatus = false;
        });
      }
    }
  }

  Future<void> _saveRoleChanges() async {
    if (_savingRoles) return;

    setState(() => _savingRoles = true);

    try {
      final auth = context.read<AuthProvider>();
      final updates = <Map<String, dynamic>>[];

      for (final entry in _roleActiveDraft.entries) {
        final roleId = entry.key;
        final isActive = entry.value;

        // Only include roles that exist in the original list
        if (widget.roles.any((r) => r.roleId == roleId)) {
          updates.add({
            'roleId': roleId,
            'isActive': isActive,
          });
        }
      }

      if (updates.isNotEmpty) {
        await auth.updateUserRoles(widget.userId, updates);
        await widget.onDataChanged();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Roles updated successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update roles')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _savingRoles = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _primary.userStatus;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: avatar + basic info + status + user-level actions
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  child: Text(
                    _primary.name.isNotEmpty
                        ? _primary.name[0].toUpperCase()
                        : '?',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _primary.name,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (_primary.email != null &&
                          _primary.email!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          _primary.email!,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: widget.statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: widget.statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildUserActions(context, status),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Roles list
            Text(
              'Roles & Jurisdictions',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),

            Column(
              children: widget.roles.map((r) {
                final isActive = _roleActiveDraft[r.roleId] ?? false;
                final canEditRoles = status == 'active' || status == 'pending';
                final subtitleParts = <String>[];

                subtitleParts.add(r.role);
                subtitleParts.add('Comm: ${r.commissionerateName}');
                if (r.divisionName != null) {
                  subtitleParts.add('Div: ${r.divisionName}');
                }
                if (r.rangeName != null) {
                  subtitleParts.add('Range: ${r.rangeName}');
                }

                return CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: isActive,
                  onChanged: (!canEditRoles || _savingRoles)
                      ? null
                      : (val) {
                          if (val == null) return;
                          setState(() {
                            _roleActiveDraft[r.roleId] = val;
                          });
                        },
                  title: Text(subtitleParts.join(' • ')),
                );
              }).toList(),
            ),

            const SizedBox(height: 8),

            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: (_savingRoles || _changingStatus)
                    ? null
                    : _saveRoleChanges,
                icon: _savingRoles
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: const Text('Save roles'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserActions(BuildContext context, String status) {
    final canTap = !_changingStatus && !_savingRoles;

    List<Widget> buttons = [];

    if (status == 'pending') {
      buttons = [
        TextButton(
          onPressed: canTap ? () => _handleUserStatusChange('active') : null,
          child: const Text(
            'Activate',
            style: TextStyle(color: Colors.green),
          ),
        ),
        TextButton(
          onPressed: canTap ? () => _handleUserStatusChange('blocked') : null,
          child: const Text(
            'Block',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ];
    } else if (status == 'active') {
      buttons = [
        TextButton(
          onPressed: canTap ? () => _handleUserStatusChange('blocked') : null,
          child: const Text(
            'Block user',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ];
    } else if (status == 'blocked') {
      buttons = [
        TextButton(
          onPressed: canTap ? () => _handleUserStatusChange('active') : null,
          child: const Text(
            'Unblock',
            style: TextStyle(color: Colors.green),
          ),
        ),
      ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: buttons,
    );
  }
}
