import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../utils/network_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CorrectPersonDataScreen extends StatefulWidget {
  const CorrectPersonDataScreen({super.key});

  @override
  State<CorrectPersonDataScreen> createState() => _CorrectPersonDataScreenState();
}

class _CorrectPersonDataScreenState extends State<CorrectPersonDataScreen> {
  final _auth = AuthService();

  List<Map<String, dynamic>> _mois = [];
  bool _loading = true;
  bool _saving = false;
  String? _eventId;

  // Pagination
  static const int _pageSize = 100; // Load 100 records at a time
  int _currentPage = 0;
  bool _hasMore = true;
  int _totalCount = 0;
  bool _loadingMore = false;

// Track modified records
  Set<String> _modifiedIds = {};

  final ScrollController _scrollController = ScrollController();

  // Controllers for editing - Map<moiId, Map<fieldName, controller>>
  Map<String, Map<String, TextEditingController>> _controllers = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map<String, dynamic>) {
      _eventId = args['event_id'];
      if (_eventId != null) {
        _loadInitialData();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // Dispose all controllers
    _controllers.forEach((key, controllers) {
      controllers.forEach((field, controller) {
        controller.dispose();
      });
    });
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_loadingMore && _hasMore) {
        _loadMoreData();
      }
    }
  }

  Future<void> _loadInitialData() async {
    if (_eventId == null) return;

    setState(() {
      _loading = true;
      _currentPage = 0;
      _mois.clear();
      _hasMore = true;
    });

    try {
      // Get total count first
      final countResponse = await _auth.client
          .from('mois')
          .select('*')
          .eq('event_id', _eventId!)
          .eq('is_deleted', false)
          .count(CountOption.exact);

      _totalCount = countResponse.count;

      // Load first page
      await _loadPage(0);

      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          onRetry: _loadInitialData,
          customMessage: 'Error loading data',
        );
      }
    }
  }

  Future<void> _loadPage(int page) async {
    if (_eventId == null) return;

    final pageResponse = await _auth.client
        .from('mois')
        .select('*')
        .eq('event_id', _eventId!)
        .eq('is_deleted', false)
        .order('serial_no', ascending: true)
        .range(page * _pageSize, (page + 1) * _pageSize - 1);

    final newMois = List<Map<String, dynamic>>.from(pageResponse);

    setState(() {
      _mois.addAll(newMois);
      _hasMore = newMois.length == _pageSize;
      _currentPage = page;
    });

    _initializeControllersForPage(newMois);
  }

  void _initializeControllersForPage(List<Map<String, dynamic>> newMois) {
    for (var moi in newMois) {
      final moiId = moi['id'];

      // Skip if already initialized
      if (_controllers.containsKey(moiId)) continue;

      _controllers[moiId] = {
        'village_name': TextEditingController(text: moi['village_name'] ?? ''),
        'living_place': TextEditingController(text: moi['living_place'] ?? ''),
      };

      final persons = moi['persons'] as List<dynamic>?;
      if (persons != null && persons.isNotEmpty) {
        // Person 1
        final person1 = persons[0] as Map<String, dynamic>;
        _controllers[moiId]!['person_0_name'] =
            TextEditingController(text: person1['name'] ?? '');
        _controllers[moiId]!['person_0_job'] =
            TextEditingController(text: person1['job'] ?? '');

        // Person 2
        if (persons.length > 1) {
          final person2 = persons[1] as Map<String, dynamic>;
          _controllers[moiId]!['person_1_details'] =
              TextEditingController(text: person2['details'] ?? '');
        } else {
          _controllers[moiId]!['person_1_details'] = TextEditingController();
        }
      }
    }
  }

  Future<void> _loadMoreData() async {
    if (_loadingMore || !_hasMore) return;

    setState(() => _loadingMore = true);

    try {
      await _loadPage(_currentPage + 1);
    } catch (e) {
      print('Error loading more data: $e');
    } finally {
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _saveAllChanges() async {
    setState(() => _saving = true);

    int successCount = 0;
    int errorCount = 0;

    // Only save modified records
    final modifiedMois = _mois.where((moi) => _modifiedIds.contains(moi['id'])).toList();

    if (modifiedMois.isEmpty) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No changes to save'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    for (var moi in modifiedMois) {
      try {
        await _saveSingleMoi(moi);
        successCount++;
        _modifiedIds.remove(moi['id']); // Remove from modified set after saving
      } catch (e) {
        errorCount++;
        print(' Error saving moi ${moi['serial_no']}: $e');

        // If it's a network error, show dialog and stop processing
        if (NetworkUtils.isNetworkError(e)) {
          setState(() => _saving = false);
          if (mounted) {
            NetworkUtils.handleError(
              context,
              e,
              onRetry: _saveAllChanges,
              customMessage: 'Connection lost while saving',
            );
          }
          return; // Stop processing remaining records
        }
      }
    }

    setState(() => _saving = false);

    if (mounted) {
      if (errorCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ All changes saved successfully! ($successCount records)'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        await _loadInitialData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Saved $successCount records, $errorCount failed'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _saveSingleMoi(Map<String, dynamic> moi) async {
    final moiId = moi['id'];
    final persons = moi['persons'] as List<dynamic>?;
    final updatedPersons = <Map<String, dynamic>>[];

    if (persons != null && persons.isNotEmpty) {
      // Person 1
      final name = _controllers[moiId]!['person_0_name']!.text.trim();
      final job = _controllers[moiId]!['person_0_job']!.text.trim();

      updatedPersons.add({
        'name': name,
        'job': job,
      });

      // Person 2 (if exists)
      if (persons.length > 1) {
        final details = _controllers[moiId]!['person_1_details']!.text.trim();

        updatedPersons.add({
          'details': details,
        });
      }
    }

    await _auth.client
        .from('mois')
        .update({
      'persons': updatedPersons,
      'village_name': _controllers[moiId]!['village_name']!.text.trim().isEmpty
          ? null
          : _controllers[moiId]!['village_name']!.text.trim(),
      'living_place': _controllers[moiId]!['living_place']!.text.trim().isEmpty
          ? null
          : _controllers[moiId]!['living_place']!.text.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    })
        .eq('id', moiId);
  }

  Widget _buildEditableCell(TextEditingController controller, String moiId) {
    return TextField(
      controller: controller,
      onChanged: (value) {
        _modifiedIds.add(moiId);
      },
      decoration: const InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        isDense: true,
      ),
      style: const TextStyle(fontSize: 13),
    );
  }

  Widget _buildFieldRow(String label, TextEditingController controller, String moiId) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(4),
            ),
            child: TextField(
              controller: controller,
              onChanged: (value) {
                _modifiedIds.add(moiId);
              },
              autofocus: false,
              enableInteractiveSelection: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ),
      ],
    );
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
          'Correct Person Data',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _mois.isEmpty
          ? const Center(
        child: Text(
          'No moi records found',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      )
          : Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: Column(
                      children: [
                        // Header
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF7B3A99), Color(0xFF9B4DB8)],
                            ),
                          ),
                          child: const Text(
                            'PERSON DATA - Edit fields directly in the table',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                        ListView.builder(
                          shrinkWrap: true,
                          physics: const ClampingScrollPhysics(),
                          itemCount: _mois.length,
                          itemBuilder: (context, index) {
                            final moi = _mois[index];
                            final moiId = moi['id'];
                            final persons = moi['persons'] as List<dynamic>?;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 1),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: index % 2 == 0 ? Colors.white : Colors.grey[50],
                                border: Border(
                                  bottom: BorderSide(color: Colors.grey[300]!),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Serial Number Header
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF7B3A99),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'O${moi['serial_no']?.toString() ?? ''}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Person 1 Name
                                  _buildFieldRow(
                                    'Person 1 Name',
                                    _controllers[moiId]!['person_0_name']!,
                                    moiId,
                                  ),
                                  const SizedBox(height: 8),

                                  // Person 1 Job
                                  _buildFieldRow(
                                    'Person 1 Job',
                                    _controllers[moiId]!['person_0_job']!,
                                    moiId,
                                  ),
                                  const SizedBox(height: 8),

                                  // Person 2 Details (if exists)
                                  if (persons != null && persons.length > 1)
                                    _buildFieldRow(
                                      'Person 2 Details',
                                      _controllers[moiId]!['person_1_details']!,
                                      moiId,
                                    ),
                                  if (persons != null && persons.length > 1)
                                    const SizedBox(height: 8),

                                  // Village Name
                                  _buildFieldRow(
                                    'Village Name',
                                    _controllers[moiId]!['village_name']!,
                                    moiId,
                                  ),
                                  const SizedBox(height: 8),

                                  // Living City
                                  _buildFieldRow(
                                    'Living City',
                                    _controllers[moiId]!['living_place']!,
                                    moiId,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  // Loading indicator for pagination
                  if (_loadingMore)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  if (!_hasMore && _mois.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Center(
                        child: Text(
                          'All ${_mois.length} of $_totalCount records loaded',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Bottom Save Button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _saving ? null : _saveAllChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB846D7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
              child: _saving
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Text(
                'SAVE ALL CHANGES',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}