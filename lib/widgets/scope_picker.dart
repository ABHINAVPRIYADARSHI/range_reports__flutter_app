import 'package:flutter/material.dart';
import '../providers/auth_provider.dart';

/// Returns a Map with keys:
///  - 'scope': ActiveScope
///  - 'remember': bool
class ScopePickerDialog extends StatefulWidget {
  final List<ActiveScope> scopes;
  final ActiveScope? initial;

  const ScopePickerDialog({super.key, required this.scopes, this.initial});

  @override
  State<ScopePickerDialog> createState() => _ScopePickerDialogState();
}

class _ScopePickerDialogState extends State<ScopePickerDialog> {
  ActiveScope? _selected;
  bool _remember = true;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial ?? (widget.scopes.isNotEmpty ? widget.scopes.first : null);
  }

  String _titleForScope(ActiveScope s) {
    if (s.role == 'admin') {
      return s.commissionerateName ?? s.commissionerateId;
    }
    if (s.role == 'nodal_officer') {
      final d = s.divisionName ?? s.divisionId ?? '';
      final c = s.commissionerateName ?? s.commissionerateId;
      return d.isNotEmpty ? '$d — $c' : c;
    }
    // range_officer
    final r = s.rangeName ?? s.rangeId ?? '';
    final d = s.divisionName ?? s.divisionId ?? '';
    return r.isNotEmpty ? '$r — $d' : (d.isNotEmpty ? d : s.commissionerateName ?? s.commissionerateId);
  }

  String _subtitleForScope(ActiveScope s) {
    return s.role.replaceAll('_', ' ');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select active scope'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.scopes.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, idx) {
                  final s = widget.scopes[idx];
                  return RadioListTile<ActiveScope>(
                    value: s,
                    groupValue: _selected,
                    title: Text(_titleForScope(s)),
                    subtitle: Text(_subtitleForScope(s)),
                    onChanged: (v) => setState(() => _selected = v),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(value: _remember, onChanged: (v) => setState(() => _remember = v ?? true)),
                const SizedBox(width: 6),
                const Expanded(child: Text('Remember this selection across sessions')),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _selected == null ? null : () => Navigator.pop(context, {'scope': _selected!, 'remember': _remember}),
          child: const Text('Use selected scope'),
        ),
      ],
    );
  }
}
