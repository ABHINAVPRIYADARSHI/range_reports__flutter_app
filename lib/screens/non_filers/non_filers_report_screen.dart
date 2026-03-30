import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border, TextSpan;
import 'package:url_launcher/url_launcher_string.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';

class NonFilersReportScreen extends StatefulWidget {
  final String? divisionId;
  final String? rangeId;
  
  const NonFilersReportScreen({
    super.key,
    this.divisionId,
    this.rangeId,
  });

  @override
  State<NonFilersReportScreen> createState() => _NonFilersReportScreenState();
}

class _NonFilersReportScreenState extends State<NonFilersReportScreen> {
  List<Map<String, dynamic>> _reports = [];
  Map<String, List<Map<String, dynamic>>> _groupedReports = {};
  bool _isLoading = true;
  bool _isUploading = false;
  String? _error;
  Set<String> _selectedIds = {};
  bool _isSelectAll = false;

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      final supabase = Supabase.instance.client;
      final activeScope = auth.activeScope;
      
      if (activeScope == null) {
        throw Exception('No active scope selected');
      }

      String userRole = activeScope.role ?? '';
      String? userRangeId = activeScope.rangeId;
      String? userDivisionId = activeScope.divisionId;

      // Use routing parameters if provided, otherwise fall back to activeScope data
      String? effectiveRangeId = widget.rangeId ?? userRangeId;
      String? effectiveDivisionId = widget.divisionId ?? userDivisionId;
      debugPrint('Fetching reports for role: $userRole, Division: $effectiveDivisionId, Range: $effectiveRangeId');
      var query = supabase.from('call_reports').select('*');

      // Apply role-based filtering
      if (userRole == 'range_officer' && effectiveRangeId != null && effectiveDivisionId != null) {
        query = query.eq('range_id', effectiveRangeId).eq('division_id', effectiveDivisionId);
      } else if (userRole == 'nodal_officer' && effectiveDivisionId != null) {
        query = query.eq('division_id', effectiveDivisionId);
      }
      // Admin sees all records (no additional filter)

      final response = await query.order('gstin', ascending: false);
      
      if (mounted) {
        setState(() {
          _reports = List<Map<String, dynamic>>.from(response);
          _groupReports();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load reports: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _groupReports() {
    if (_reports == null || _reports.isEmpty) {
      _groupedReports = {};
      return;
    }
    
    _groupedReports.clear();
    
    for (var report in _reports) {
      if (report == null) continue;
      
      final divisionId = report['division_id']?.toString() ?? 'Unknown Division';
      final rangeId = report['range_id']?.toString() ?? 'Unknown Range';
      final groupKey = '$divisionId-$rangeId';
      
      if (!_groupedReports.containsKey(groupKey)) {
        _groupedReports[groupKey] = [];
      }
      _groupedReports[groupKey]!.add(report);
    }
  }

  Future<void> makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrlString(phoneUri.toString())) {
      await launchUrlString(phoneUri.toString());
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch phone call to $phoneNumber'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _isAdmin() {
    final auth = context.read<AuthProvider>();
    final active = auth.activeScope;
    // debugPrint('Active scope role: ${active?.role}');
    return active?.role == 'admin';
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      _updateSelectAllState();
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_isSelectAll) {
        _selectedIds.clear();
        _isSelectAll = false;
      } else {
        _selectedIds = _reports.map((report) => report['id'].toString()).toSet();
        _isSelectAll = true;
      }
    });
  }

  void _updateSelectAllState() {
    _isSelectAll = _selectedIds.length == _reports.length && _reports.isNotEmpty;
  }

  Future<void> _deleteSelectedRecords() async {
    if (_selectedIds.isEmpty) return;

    final confirmed = await _showDeleteConfirmation();
    if (!confirmed) return;

    try {
      final supabase = Supabase.instance.client;
      
      for (String id in _selectedIds) {
        await supabase.from('call_reports').delete().eq('id', id);
      }

      // Clear selections and reset state
      setState(() {
        _selectedIds.clear();
        _isSelectAll = false;
      });

      await _fetchReports();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_selectedIds.length} records deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete records: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadExcelFile() async {
    debugPrint('=== Excel Upload Started ===');
    
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        debugPrint('Step 1: No file selected');
        return;
      }

      debugPrint('Step 2: File selected - ${result.files.first.name}');
      final file = result.files.first;
      if (file.bytes == null) {
        debugPrint('Step 2: Unable to read file bytes');
        throw Exception('Unable to read file bytes');
      }

      // Set uploading state
      setState(() => _isUploading = true);

      try {
        // debugPrint('Step 4: Starting Excel parsing...');
        final excel = Excel.decodeBytes(file.bytes!);
        // debugPrint('Step 4: Excel decoded, sheets: ${excel.tables.keys.toList()}');
        
        final sheet = excel.tables[excel.tables.keys.first];
        
        if (sheet == null) {
          debugPrint('Step 4: No worksheet found in Excel file');
          throw Exception('No worksheet found in Excel file');
        }

        // debugPrint('Step 5: Processing ${sheet.rows.length} rows from sheet');
        final List<Map<String, dynamic>> records = [];
        
        // Skip header row (assuming first row is header)
        for (int i = 1; i < sheet.rows.length; i++) {
          final row = sheet.rows[i];
          
          // Extract data from columns (assuming fixed order)
          final gstin = _getCellValue(row[0]);
          final tradeName = _getCellValue(row[1]);
          final division = _getCellValue(row[2]);
          final range = _getCellValue(row[3]);
          final lastFiledMonth = _getCellValue(row[4]);
          final lastFiledDate = _formatDate(_getCellValue(row[5]));
          final mobileNo = _getCellValue(row[6]);

          // debugPrint('Step 5: Row $i - GSTIN: $gstin, Trade: $tradeName');

          // Skip empty rows
          if (gstin.isEmpty) continue;

          records.add({
            'gstin': gstin,
            'trade_name': tradeName,
            'division_id': division,
            'range_id': range,
            'last_filed_month': lastFiledMonth,
            'last_filed_date': lastFiledDate,
            'mobile_no': mobileNo,
            'status': 'pending',
            'comment_1': null,
            'comment_2': null,
            'comment_3': null,
          });
        }

        debugPrint('Step 6: Parsed ${records.length} records');
        
        if (records.isEmpty) {
          debugPrint('Step 6: No data found in Excel file');
          throw Exception('No data found in Excel file');
        }

        debugPrint('Step 7: Starting database insert...');
        // Insert records into database
        final supabase = Supabase.instance.client;
        await supabase.from('call_reports').insert(records);

        debugPrint('Step 8: Database insert completed successfully');

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${records.length} records uploaded successfully'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Refresh data
          await _fetchReports();
        }
      } catch (e) {
        debugPrint('Step 4-8 Error: $e');
        rethrow;
      } finally {
        // Reset uploading state
        if (mounted) {
          setState(() => _isUploading = false);
        }
      }
    } catch (e) {
      debugPrint('Excel Upload Error: $e');
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload Excel file: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getCellValue(dynamic cell) {
    if (cell == null) return '';
    if (cell.value == null) return '';
    return cell.value.toString().trim();
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null || dateValue.toString().trim().isEmpty) {
      return '';
    }
    
    final String dateStr = dateValue.toString().trim();
    
    // Remove timestamp part using regex (T00:00:00.000Z pattern)
    return dateStr.replaceAll(RegExp(r'T\d{2}:\d{2}:\d{2}\.\d{3}Z'), '');
  }


  Future<bool> _showDeleteConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete ${_selectedIds.length} record(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProv = Provider.of<ThemeProvider>(context, listen: true);
    final gradientColors = themeProv.gradientColors;
    final isAdmin = _isAdmin();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Non-filers Report'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildTopSummary() {
    final theme = Theme.of(context);
    final contactedCount = _reports.where((report) {
      final status = report['status']?.toString().toLowerCase() ?? '';
      return status == 'contacted';
    }).length;
    final pendingCount = _reports.where((report) {
      final status = report['status']?.toString().toLowerCase() ?? '';
      return status == 'pending';
    }).length;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withOpacity(0.96),
            theme.colorScheme.primaryContainer.withOpacity(0.92),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Overview',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_reports.length} records',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimary.withOpacity(0.86),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildOverviewMetric(
                label: 'Total',
                value: _reports.length.toString(),
                icon: Icons.receipt_long_rounded,
              ),
              _buildOverviewMetric(
                label: 'Contacted',
                value: contactedCount.toString(),
                icon: Icons.call_outlined,
              ),
              _buildOverviewMetric(
                label: 'Pending',
                value: pendingCount.toString(),
                icon: Icons.pending_actions_rounded,
              ),
              _buildOverviewMetric(
                label: 'Groups',
                value: _groupedReports.length.toString(),
                icon: Icons.account_tree_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewMetric({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.14),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: theme.colorScheme.onPrimary, size: 14),
          const SizedBox(width: 6),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onPrimary.withOpacity(0.88),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminActions() {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 520;

          final uploadButton = InkWell(
            onTap: _isUploading ? null : _uploadExcelFile,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _isUploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.add_rounded,
                          color: theme.colorScheme.primary,
                          size: 18,
                        ),
                  const SizedBox(width: 8),
                  Text(
                    _isUploading ? 'Uploading...' : 'Upload excel',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );

          final deleteButton = _selectedIds.isNotEmpty
              ? ElevatedButton.icon(
                  onPressed: _deleteSelectedRecords,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text('Delete (${_selectedIds.length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                )
              : null;

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                uploadButton,
                if (deleteButton != null) ...[
                  const SizedBox(height: 10),
                  deleteButton,
                ],
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: uploadButton),
              if (deleteButton != null) ...[
                const SizedBox(width: 12),
                deleteButton,
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _error!,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final isAdmin = _isAdmin();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        children: [
          _buildTopSummary(),
          if (isAdmin) _buildAdminActions(),
          if (_reports.isEmpty)
            _buildEmptyState()
          else
            _buildDataTable(),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
    final theme = Theme.of(context);
    final isAdmin = _isAdmin();

    return Card(
      margin: const EdgeInsets.all(16.0),
      elevation: 0,
      color: theme.colorScheme.surface.withOpacity(0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withOpacity(0.12),
                  theme.colorScheme.primaryContainer.withOpacity(0.18),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28.0),
                topRight: Radius.circular(28.0),
              ),
            ),
            child: Row(
              children: [
                if (isAdmin)
                  Checkbox(
                    value: _isSelectAll,
                    onChanged: (value) => _toggleSelectAll(),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_reports.length} records',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      if (_groupedReports.isNotEmpty)
                        Text(
                          '${_groupedReports.length} groups',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: _fetchReports,
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Refresh',
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          if (_groupedReports == null || _groupedReports.isEmpty || _groupedReports.length == 0)
            _buildEmptyState()
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
              child: Column(
                children: _groupedReports.keys.map((groupKey) {
                  final reports = _groupedReports[groupKey] ?? [];
                  final parts = groupKey.split('-');
                  final divisionId = parts.isNotEmpty ? parts[0] : 'Unknown';
                  final rangeId = parts.length > 1 ? parts[1] : 'Unknown';

                  return _buildGroupedCard(divisionId, rangeId, reports, isAdmin);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.14),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);

    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.12),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.file_present_outlined,
                size: 38,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No non-filers data found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try refreshing to check for newly uploaded or updated records.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: _fetchReports,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedCard(String divisionId, String rangeId, List<Map<String, dynamic>> reports, bool isAdmin) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      elevation: 0,
      color: theme.colorScheme.surface.withOpacity(0.96),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withOpacity(0.14),
                  theme.colorScheme.secondary.withOpacity(0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24.0),
                topRight: Radius.circular(24.0),
              ),
            ),
            child: Wrap(
              runSpacing: 12,
              spacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.account_balance_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Text(
                  'Division $divisionId',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                _buildInfoPill(
                  icon: Icons.location_on_outlined,
                  label: 'Range $rangeId',
                  color: theme.colorScheme.primary,
                ),
                _buildInfoPill(
                  icon: Icons.layers_outlined,
                  label: '${reports.length} records',
                  color: theme.colorScheme.secondary,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: Column(
              children: reports.map((report) => _buildReportCard(report, isAdmin)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report, bool isAdmin) {
    final theme = Theme.of(context);
    final id = report['id'].toString();
    final isSelected = _selectedIds.contains(id);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primary.withOpacity(0.06)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary.withOpacity(0.45)
              : theme.colorScheme.outline.withOpacity(0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        leading: isAdmin 
            ? Checkbox(
                value: isSelected,
                onChanged: (value) => _toggleSelection(id),
              )
            : null,
        title: Text(
          '${report['gstin'] ?? 'N/A'}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                report['trade_name'] ?? 'N/A',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildInfoPill(
                    icon: Icons.location_on_outlined,
                    label: 'Range ${report['range_id'] ?? 'N/A'}',
                    color: theme.colorScheme.primary,
                  ),
                  _buildInfoPill(
                    icon: Icons.business_outlined,
                    label: 'Division ${report['division_id'] ?? 'N/A'}',
                    color: theme.colorScheme.secondary,
                  ),
                  _buildInfoPill(
                    icon: Icons.calendar_month_outlined,
                    label: 'Last filed month: ${report['last_filed_month'] ?? 'N/A'}',
                    color: Colors.teal,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                icon: Icons.event_outlined,
                label: 'Filed Date',
                value: report['last_filed_date'] ?? 'N/A',
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(report['status'] ?? 'N/A'),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Status: ${report['status'] ?? 'N/A'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      final mobileNo = report['mobile_no']?.toString();
                      if (mobileNo != null && mobileNo.isNotEmpty && mobileNo != 'N/A') {
                        makePhoneCall(mobileNo);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.18),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.phone_in_talk,
                            size: 18,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            report['mobile_no'] ?? 'N/A',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: _buildCommentsSection(report),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'contacted':
        return Colors.green;
      case 'in progress':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Widget _buildCommentsSection(Map<String, dynamic> report) {
    final theme = Theme.of(context);
    final comments = _getCommentEntries(report);
    final visibleComments = comments.where((entry) => entry.comment.trim().isNotEmpty).toList();
    final nextComment = comments.cast<_CommentEntry?>().firstWhere(
      (entry) => entry != null && entry.comment.trim().isEmpty,
      orElse: () => null,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Comments',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const Spacer(),
            if (visibleComments.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${visibleComments.length}/3 saved',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (visibleComments.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: Text(
              'No comments added yet. Add the first comment below.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ...visibleComments.asMap().entries.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildSavedCommentTimelineItem(
                entry: item.value,
                report: report,
                isFirst: item.key == 0,
                isLast: item.key == visibleComments.length - 1,
              ),
            ),
          ),
        if (nextComment != null) ...[
          const SizedBox(height: 8),
          _buildCommentField(
            '',
            nextComment.comment,
            report,
            nextComment.number,
          ),
        ] else ...[
          const SizedBox(height: 8),
          Text(
            'All 3 comment slots are used. You can still edit an existing comment using its edit button.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  List<_CommentEntry> _getCommentEntries(Map<String, dynamic> report) {
    return [
      _CommentEntry(number: 1, comment: report['comment_1']?.toString() ?? ''),
      _CommentEntry(number: 2, comment: report['comment_2']?.toString() ?? ''),
      _CommentEntry(number: 3, comment: report['comment_3']?.toString() ?? ''),
    ];
  }

  Widget _buildSavedCommentTimelineItem({
    required _CommentEntry entry,
    required Map<String, dynamic> report,
    required bool isFirst,
    required bool isLast,
  }) {
    final theme = Theme.of(context);
    final parsedComment = _parseComment(entry.comment);
    final lineColor = theme.colorScheme.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 44,
          child: Column(
            children: [
              Container(
                width: 4,
                height: 18,
                color: isFirst ? Colors.transparent : lineColor,
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.onPrimary.withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${entry.number}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Container(
                width: 4,
                height: 72,
                color: isLast ? Colors.transparent : lineColor,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.15),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (parsedComment.timestamp != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: theme.colorScheme.primary.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            parsedComment.timestamp!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Text(
                        parsedComment.body.isEmpty ? entry.comment : parsedComment.body,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _showEditCommentDialog(report, entry),
                  icon: Icon(
                    Icons.edit_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  tooltip: 'Edit comment ${entry.number}',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentField(String label, String? comment, Map<String, dynamic> report, int commentNumber) {
    final theme = Theme.of(context);
    final controller = TextEditingController(text: comment ?? '');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.trim().isNotEmpty) ...[
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: controller,
          enabled: true, // Allow all users to edit comments
          minLines: 2,
          maxLines: 3,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.4),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 1.5,
              ),
            ),
            hintText: 'Add a comment...',
            filled: true,
            fillColor: theme.colorScheme.surface,
            suffixIcon: IconButton(
              icon: Icon(
                Icons.save,
                color: theme.colorScheme.primary,
              ),
              onPressed: () {
                _updateComment(report['id'], commentNumber, controller.text.trim());
              },
              tooltip: 'Save Comment',
            ),
          ),
          onSubmitted: (value) {
            _updateComment(report['id'], commentNumber, value.trim());
          },
        ),
      ],
    );
  }

  _ParsedComment _parseComment(String rawComment) {
    final trimmed = rawComment.trim();
    final match = RegExp(r'^\[([^\]]+)\]\s*(.*)$', dotAll: true).firstMatch(trimmed);

    if (match == null) {
      return _ParsedComment(timestamp: null, body: trimmed);
    }

    return _ParsedComment(
      timestamp: match.group(1)?.trim(),
      body: _stripLeadingTimestamps(match.group(2) ?? ''),
    );
  }

  String _stripLeadingTimestamps(String value) {
    var result = value.trim();
    final timestampPrefix = RegExp(r'^\[[^\]]+\]\s*', dotAll: true);

    while (timestampPrefix.hasMatch(result)) {
      result = result.replaceFirst(timestampPrefix, '').trimLeft();
    }

    return result.trim();
  }

  Future<void> _showEditCommentDialog(Map<String, dynamic> report, _CommentEntry entry) async {
    final parsedComment = _parseComment(entry.comment);
    final controller = TextEditingController(text: parsedComment.body);
    final theme = Theme.of(context);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Edit Comment ${entry.number}'),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Update comment...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              await _updateComment(
                report['id'].toString(),
                entry.number,
                controller.text.trim(),
              );
              if (mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            icon: Icon(Icons.save, color: theme.colorScheme.onPrimary),
            label: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateComment(String reportId, int commentNumber, String comment) async {
    final sanitizedComment = _stripLeadingTimestamps(comment);

    if (sanitizedComment.trim().isEmpty) {
      debugPrint('Comment is empty, skipping update');
      return;
    }

    // Prepend current date and time to the comment
    final now = DateTime.now();
    final formattedDate = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final formattedTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final commentWithTimestamp = '[$formattedDate $formattedTime] $sanitizedComment';
    
    debugPrint('Updating comment for report ID: $reportId, comment number: $commentNumber, value: "$commentWithTimestamp"');
    
    try {
      final supabase = Supabase.instance.client;
      final commentField = 'comment_$commentNumber';
      
      await supabase.from('call_reports').update({
        commentField: commentWithTimestamp,
        'status': 'contacted', // Update status when comment is added
      }).eq('id', reportId);

      debugPrint('Comment update successful for report ID: $reportId');
      
      await _fetchReports();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Comment $commentNumber updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to update comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update comment: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCommentsDialog(Map<String, dynamic> report) {
    showDialog(
      context: context,
      builder: (context) => _CommentsDialog(
        report: report,
        isAdmin: _isAdmin(),
        onSave: () => _fetchReports(),
      ),
    );
  }
}

class _CommentsDialog extends StatefulWidget {
  final Map<String, dynamic> report;
  final bool isAdmin;
  final VoidCallback onSave;

  const _CommentsDialog({
    required this.report,
    required this.isAdmin,
    required this.onSave,
  });

  @override
  State<_CommentsDialog> createState() => _CommentsDialogState();
}

class _CommentsDialogState extends State<_CommentsDialog> {
  late TextEditingController _comment1Controller;
  late TextEditingController _comment2Controller;
  late TextEditingController _comment3Controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _comment1Controller = TextEditingController(
      text: _extractCommentBody(widget.report['comment_1']),
    );
    _comment2Controller = TextEditingController(
      text: _extractCommentBody(widget.report['comment_2']),
    );
    _comment3Controller = TextEditingController(
      text: _extractCommentBody(widget.report['comment_3']),
    );
  }

  @override
  void dispose() {
    _comment1Controller.dispose();
    _comment2Controller.dispose();
    _comment3Controller.dispose();
    super.dispose();
  }

  Future<void> _saveComments() async {
    setState(() => _isSaving = true);

    try {
      final supabase = Supabase.instance.client;
      
      // Helper function to prepend timestamp to comment
      String prependTimestamp(String comment) {
        if (comment.trim().isEmpty) return comment;
        
        final now = DateTime.now();
        final formattedDate = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
        final formattedTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
        return '[$formattedDate $formattedTime] $comment';
      }
      
      await supabase.from('call_reports').update({
        'comment_1': prependTimestamp(_comment1Controller.text.trim()),
        'comment_2': prependTimestamp(_comment2Controller.text.trim()),
        'comment_3': prependTimestamp(_comment3Controller.text.trim()),
        'status': 'contacted', // Update status when comments are saved
      }).eq('id', widget.report['id']);

      widget.onSave();
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comments saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save comments: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Comments - ${widget.report['trade_name'] ?? 'N/A'}',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'GSTIN: ${widget.report['gstin'] ?? 'N/A'}',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 20),
              
              Expanded(
                child: Column(
                  children: [
                    _buildCommentField('Comment 1:', _comment1Controller),
                    const SizedBox(height: 16),
                    _buildCommentField('Comment 2:', _comment2Controller),
                    const SizedBox(height: 16),
                    _buildCommentField('Comment 3:', _comment3Controller),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                  if (widget.isAdmin) ...[
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveComments,
                      child: _isSaving 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentField(String label, TextEditingController controller) {
    final theme = Theme.of(context);
    final isAdmin = widget.isAdmin;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: true, // Allow all users to edit comments
          maxLines: 3,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: 'Enter comment...',
            filled: false,
            suffixIcon: Icon(
              Icons.edit,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  String _extractCommentBody(dynamic value) {
    final rawComment = value?.toString() ?? '';
    return _stripLeadingTimestamps(rawComment);
  }

  String _stripLeadingTimestamps(String value) {
    var result = value.trim();
    final timestampPrefix = RegExp(r'^\[[^\]]+\]\s*', dotAll: true);

    while (timestampPrefix.hasMatch(result)) {
      result = result.replaceFirst(timestampPrefix, '').trimLeft();
    }

    return result.trim();
  }
}

class _CommentEntry {
  final int number;
  final String comment;

  const _CommentEntry({
    required this.number,
    required this.comment,
  });
}

class _ParsedComment {
  final String? timestamp;
  final String body;

  const _ParsedComment({
    required this.timestamp,
    required this.body,
  });
}
