import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'scope_picker.dart';

class ScopeDropdown extends StatelessWidget {
  const ScopeDropdown({super.key});

  String _displayLabel(ActiveScope scope) {
    // prefer human-readable names, fall back to ids
    if (scope.role == 'admin') {
      return scope.commissionerateName?.isNotEmpty == true
          ? '${scope.commissionerateName} (Admin)'
          : '${scope.commissionerateId} (Admin)';
    }
    if (scope.role == 'nodal_officer') {
      final div = scope.divisionName ?? scope.divisionId ?? '';
      final comm = scope.commissionerateName ?? scope.commissionerateId;
      return div.isNotEmpty ? '$div — $comm' : comm;
    }
    // range_officer
    final rng = scope.rangeName ?? scope.rangeId ?? '';
    final div = scope.divisionName ?? scope.divisionId ?? '';
    return rng.isNotEmpty ? '$rng — $div' : (div.isNotEmpty ? div : scope.commissionerateName ?? scope.commissionerateId);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final scopes = auth.scopesFromRoles;
    final active = auth.activeScope;

    if (scopes.isEmpty) return const SizedBox.shrink();

    final label = active != null ? _displayLabel(active) : _displayLabel(scopes.first);

    return InkWell(
      onTap: () async {
        final result = await showDialog(
          context: context,
          builder: (_) => ScopePickerDialog(scopes: scopes, initial: active),
        ) as Map<String, dynamic>?;
        if (result != null) {
          final ActiveScope s = result['scope'] as ActiveScope;
          final remember = result['remember'] as bool? ?? true;
          await auth.setActiveScope(s, persist: remember);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}
