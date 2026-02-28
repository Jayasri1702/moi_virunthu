import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class JobManagementScreen extends StatefulWidget {
  const JobManagementScreen({super.key});

  @override
  State<JobManagementScreen> createState() => _JobManagementScreenState();
}

class _JobManagementScreenState extends State<JobManagementScreen> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  final _addJobController = TextEditingController();
  final _addJobFocusNode = FocusNode();

  List<Map<String, dynamic>> _allJobs = [];
  List<Map<String, dynamic>> _filteredJobs = [];
  bool _isLoading = true;
  bool _isAdding = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadJobs();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
        _filteredJobs = _allJobs.where((job) {
          final jobName = (job['job'] ?? '').toLowerCase();
          return jobName.contains(_searchQuery);
        }).toList();
      });
    });
  }

  Future<void> _loadJobs() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('jobs')
          .select('id, job')
          .not('job', 'is', null)
          .order('job', ascending: true);

      setState(() {
        _allJobs = List<Map<String, dynamic>>.from(response);
        _filteredJobs = _allJobs;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading jobs: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading jobs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addJob(String jobName) async {
    final trimmed = jobName.trim();
    if (trimmed.isEmpty) return;

    // Check duplicate
    final exists = _allJobs.any(
          (j) => (j['job'] ?? '').toLowerCase() == trimmed.toLowerCase(),
    );
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ This job already exists!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isAdding = true);
    try {
      final result = await _supabase
          .from('jobs')
          .insert({'job': trimmed})
          .select('id, job')
          .single();

      setState(() {
        _allJobs.add(result);
        _allJobs.sort((a, b) =>
            (a['job'] ?? '').compareTo(b['job'] ?? ''));
        _filteredJobs = _searchQuery.isEmpty
            ? List.from(_allJobs)
            : _allJobs
            .where((j) =>
            (j['job'] ?? '').toLowerCase().contains(_searchQuery))
            .toList();
        _addJobController.clear();
        _isAdding = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ "$trimmed" added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error adding job: $e');
      setState(() => _isAdding = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding job: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editJob(Map<String, dynamic> job) async {
    final controller = TextEditingController(text: job['job']);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          '✏️ Edit Job Name',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Job Name',
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (result == null || result.trim().isEmpty) return;
    if (result.trim() == job['job']) return;

    // Check duplicate
    final exists = _allJobs.any(
          (j) =>
      j['id'] != job['id'] &&
          (j['job'] ?? '').toLowerCase() == result.trim().toLowerCase(),
    );
    if (exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ A job with this name already exists!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      await _supabase
          .from('jobs')
          .update({'job': result.trim()})
          .eq('id', job['id']);

      setState(() {
        final idx = _allJobs.indexWhere((j) => j['id'] == job['id']);
        if (idx != -1) {
          _allJobs[idx] = {'id': job['id'], 'job': result.trim()};
        }
        _allJobs.sort((a, b) =>
            (a['job'] ?? '').compareTo(b['job'] ?? ''));
        _filteredJobs = _searchQuery.isEmpty
            ? List.from(_allJobs)
            : _allJobs
            .where((j) =>
            (j['job'] ?? '').toLowerCase().contains(_searchQuery))
            .toList();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Updated to "${result.trim()}"'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error editing job: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating job: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteJob(Map<String, dynamic> job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          '🗑️ Delete Job',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete "${job['job']}"?\n\nThis will remove it from the job suggestions list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _supabase.from('jobs').delete().eq('id', job['id']);

      setState(() {
        _allJobs.removeWhere((j) => j['id'] == job['id']);
        _filteredJobs = _searchQuery.isEmpty
            ? List.from(_allJobs)
            : _allJobs
            .where((j) =>
            (j['job'] ?? '').toLowerCase().contains(_searchQuery))
            .toList();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🗑️ "${job['job']}" deleted'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error deleting job: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting job: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _addJobController.dispose();
    _addJobFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Job Management',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _loadJobs,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Add New Job ──────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addJobController,
                    focusNode: _addJobFocusNode,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (v) => _addJob(v),
                    decoration: InputDecoration(
                      hintText: 'Enter new job name...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      isDense: true,
                      prefixIcon:
                      const Icon(Icons.work_outline, color: Colors.grey),
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _isAdding
                        ? null
                        : () => _addJob(_addJobController.text),
                    icon: _isAdding
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                        : const Icon(Icons.add),
                    label: const Text('Add'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Search Bar ───────────────────────────────────
          Container(
            color: Colors.white,
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search jobs...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
                    : null,
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),

          // ── Count Bar ────────────────────────────────────
          Container(
            width: double.infinity,
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: Colors.blue[50],
            child: Text(
              _searchQuery.isEmpty
                  ? 'Total: ${_allJobs.length} jobs'
                  : 'Showing ${_filteredJobs.length} of ${_allJobs.length} jobs',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.blue[800],
              ),
            ),
          ),

          // ── Job List ─────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredJobs.isEmpty
                ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.work_off,
                      size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text(
                    _searchQuery.isEmpty
                        ? 'No jobs yet.\nAdd your first job above!'
                        : 'No jobs match "$_searchQuery"',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
                : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _filteredJobs.length,
              separatorBuilder: (_, __) =>
              const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final job = _filteredJobs[index];
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border:
                    Border.all(color: Colors.grey[200]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.blue[50],
                      child: Text(
                        (job['job'] ?? '?')[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                    title: Text(
                      job['job'] ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      'ID: ${job['id']}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[400],
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Edit button
                        IconButton(
                          icon: const Icon(Icons.edit,
                              size: 20, color: Colors.blue),
                          onPressed: () => _editJob(job),
                          tooltip: 'Edit',
                          visualDensity: VisualDensity.compact,
                        ),
                        // Delete button
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 20, color: Colors.red),
                          onPressed: () => _deleteJob(job),
                          tooltip: 'Delete',
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}