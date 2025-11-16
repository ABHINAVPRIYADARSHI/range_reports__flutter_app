import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/UserRole.dart';
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

// In lib/screens/admin/user_management_screen.dart
class _UserManagementScreenState extends State<UserManagementScreen> {
  bool _isLoading = false;
  String? _error;

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

  List<UserRole> _getUsersByStatus(String status) {
    return context
        .read<AuthProvider>()
        .userRoles
        .where((user) => user.userStatus == status)
        .toList();
  }

  Future<void> _updateUserStatus(String userId, String status) async {
    try {
      await context.read<AuthProvider>().updateUserStatus(userId, status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User status updated to $status')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update user status')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();
    final pendingUsers = _getUsersByStatus('pending');
    final activeUsers = _getUsersByStatus('active');
    final blockedUsers = _getUsersByStatus('blocked');

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
                        _buildSection('Pending Approvals', pendingUsers, theme),
                        _buildSection('Active Users', activeUsers, theme),
                        _buildSection('Blocked Users', blockedUsers, theme),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildSection(String title, List<UserRole> users, ThemeData theme) {
    if (users.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            '$title (${users.length})',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...users.map((user) => _buildUserCard(user, theme)).toList(),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildUserCard(UserRole user, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?'),
        ),
        title: Text(user.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email ?? ''),
            if (user.role.isNotEmpty) Text('Role: ${user.role}'),
            if (user.commissionerateName != null)
              Text('Commissionerate: ${user.commissionerateName}'),
            if (user.divisionName != null) Text('Division: ${user.divisionName}'),
            if (user.rangeName != null) Text('Range: ${user.rangeName}'),
            Text(
              'Status: ${user.userStatus}',
              style: TextStyle(
                color: _getStatusColor(user.userStatus, theme),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        onTap: () => _showUserActions(context, user),
      ),
    );
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

  void _showUserActions(BuildContext context, UserRole user) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Manage User: ${user.name}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (user.userStatus == 'pending') ...[
                _buildActionButton(
                  context,
                  'Approve User',
                  Icons.check_circle,
                  Colors.green,
                  () => _updateUserStatus(user.userId, 'active'),
                ),
                _buildActionButton(
                  context,
                  'Reject User',
                  Icons.cancel,
                  Colors.red,
                  () => _updateUserStatus(user.userId, 'blocked'),
                ),
              ],
              if (user.userStatus == 'active') ...[
                _buildActionButton(
                  context,
                  'Block User',
                  Icons.block,
                  Colors.red,
                  () => _updateUserStatus(user.userId, 'blocked'),
                ),
              ],
              if (user.userStatus == 'blocked') ...[
                _buildActionButton(
                  context,
                  'Unblock User',
                  Icons.check_circle,
                  Colors.green,
                  () => _updateUserStatus(user.userId, 'active'),
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: () {
        Navigator.pop(context); // Close the bottom sheet
        onPressed();
      },
    );
  }
}