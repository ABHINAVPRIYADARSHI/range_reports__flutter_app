import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';

class NonFilersReportScreen extends StatefulWidget {
  const NonFilersReportScreen({super.key});

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
      final user = auth.user;
      
      if (user == null) {
        throw Exception('User not authenticated');
      }

      String userRole = user['role'] ?? '';
      String? userRangeId = user['range_id'];
      String? userDivisionId = user['division_id'];

      var query = supabase.from('call_reports').select('*');

      // Apply role-based filtering
      if (userRole == 'range_officer' && userRangeId != null) {
        query = query.eq('range_id', userRangeId);
      } else if (userRole == 'nodal_officer' && userDivisionId != null) {
        query = query.eq('division_id', userDivisionId);
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
          final lastFiledDate = _getCellValue(row[5]);
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
          child: Column(
            children: [
              if (isAdmin) _buildAdminActions(),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminActions() {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              // Upload Excel Button
              Expanded(
                child: _isUploading
                    ? ElevatedButton.icon(
                        onPressed: null,
                        icon: const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        label: const Text('Uploading...'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: _uploadExcelFile,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Upload Excel'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              // Delete Button (visible only when records are selected)
              if (_selectedIds.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: _deleteSelectedRecords,
                  icon: const Icon(Icons.delete),
                  label: Text('Delete (${_selectedIds.length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
            ],
          ),
        ],
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

    if (_reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.file_present_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No non-filers data found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _fetchReports,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return _buildDataTable();
  }

  Widget _buildDataTable() {
    final theme = Theme.of(context);
    final isAdmin = _isAdmin();

    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12.0),
                topRight: Radius.circular(12.0),
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
                  child: Text(
                    'Total Records: ${_reports.length}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _fetchReports,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),
          // Table Content with grouped card-based display
          Expanded(
            child: (_groupedReports == null || _groupedReports.isEmpty || _groupedReports.length == 0)
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: _groupedReports.keys.length,
                    itemBuilder: (context, index) {
                      final groupKey = _groupedReports.keys.elementAt(index);
                      final reports = _groupedReports[groupKey] ?? [];
                      final parts = groupKey.split('-');
                      final divisionId = parts.isNotEmpty ? parts[0] : 'Unknown';
                      final rangeId = parts.length > 1 ? parts[1] : 'Unknown';
                      
                      return _buildGroupedCard(divisionId, rangeId, reports, isAdmin);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.file_present_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No non-filers data found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _fetchReports,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedCard(String divisionId, String rangeId, List<Map<String, dynamic>> reports, bool isAdmin) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      child: Column(
        children: [
          // Group Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12.0),
                topRight: Radius.circular(12.0),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.business, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Division: $divisionId',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                Icon(Icons.location_on, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Range: $rangeId',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${reports.length} records',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Individual Report Cards
          ...reports.map((report) => _buildReportCard(report, isAdmin)).toList(),
        ],
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report, bool isAdmin) {
    final theme = Theme.of(context);
    final id = report['id'].toString();
    final isSelected = _selectedIds.contains(id);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: ExpansionTile(
        leading: isAdmin 
            ? Checkbox(
                value: isSelected,
                onChanged: (value) => _toggleSelection(id),
              )
            : null,
        title: Text(
          '${report['gstin'] ?? 'N/A'} - ${report['trade_name'] ?? 'N/A'}',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  'Range: ${report['range_id'] ?? 'N/A'}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(width: 16),
                Icon(Icons.business, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  'Division: ${report['division_id'] ?? 'N/A'}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  'Month: ${report['last_filed_month'] ?? 'N/A'}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(width: 16),
                Icon(Icons.event, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  'Date: ${report['last_filed_date'] ?? 'N/A'}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.phone_in_talk, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  'Mobile: ${report['mobile_no'] ?? 'N/A'}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getStatusColor(report['status'] ?? 'N/A'),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Status: ${report['status'] ?? 'N/A'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Comments',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildCommentField('Comment 1:', report['comment_1'], isAdmin, report, 1),
                const SizedBox(height: 12),
                _buildCommentField('Comment 2:', report['comment_2'], isAdmin, report, 2),
                const SizedBox(height: 12),
                _buildCommentField('Comment 3:', report['comment_3'], isAdmin, report, 3),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'in progress':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Widget _buildCommentField(String label, String? comment, bool isAdmin, Map<String, dynamic> report, int commentNumber) {
    final theme = Theme.of(context);
    final controller = TextEditingController(text: comment ?? '');
    
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
          enabled: isAdmin,
          maxLines: 2,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: isAdmin ? 'Enter comment...' : 'No comment added',
            filled: !isAdmin,
            fillColor: isAdmin ? null : theme.colorScheme.surface.withOpacity(0.5),
          ),
          onSubmitted: (value) {
            if (isAdmin) {
              _updateComment(report['id'], commentNumber, value.trim());
            }
          },
        ),
      ],
    );
  }

  Future<void> _updateComment(String reportId, int commentNumber, String comment) async {
    try {
      final supabase = Supabase.instance.client;
      final commentField = 'comment_$commentNumber';
      
      await supabase.from('call_reports').update({
        commentField: comment.isEmpty ? null : comment,
      }).eq('id', reportId);

      await _fetchReports();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
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
    _comment1Controller = TextEditingController(text: widget.report['comment_1'] ?? '');
    _comment2Controller = TextEditingController(text: widget.report['comment_2'] ?? '');
    _comment3Controller = TextEditingController(text: widget.report['comment_3'] ?? '');
  }

  @override
  void dispose() {
    _comment1Controller.dispose();
    _comment2Controller.dispose();
    _comment3Controller.dispose();
    super.dispose();
  }

  Future<void> _saveComments() async {
    if (!widget.isAdmin) return;

    setState(() => _isSaving = true);

    try {
      final supabase = Supabase.instance.client;
      
      await supabase.from('call_reports').update({
        'comment_1': _comment1Controller.text.trim(),
        'comment_2': _comment2Controller.text.trim(),
        'comment_3': _comment3Controller.text.trim(),
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
          enabled: isAdmin,
          maxLines: 3,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: isAdmin ? 'Enter comment...' : 'No comment added',
            filled: !isAdmin,
            fillColor: isAdmin ? null : theme.colorScheme.surface.withOpacity(0.5),
          ),
        ),
      ],
    );
  }
}
