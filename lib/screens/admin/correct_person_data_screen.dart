import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../utils/network_utils.dart';

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

  // Controllers for editing - Map<moiId, Map<fieldName, controller>>
  Map<String, Map<String, TextEditingController>> _controllers = {};

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map<String, dynamic>) {
      _eventId = args['event_id'];
      if (_eventId != null) {
        _loadMois();
      }
    }
  }

  @override
  void dispose() {
    // Dispose all controllers
    _controllers.forEach((key, controllers) {
      controllers.forEach((field, controller) {
        controller.dispose();
      });
    });
    super.dispose();
  }

  Future<void> _loadMois() async {
    if (_eventId == null) return;

    setState(() => _loading = true);

    try {
      // Fetch all mois with pagination
      List<dynamic> data = [];
      int pageSize = 1000;
      int currentPage = 0;
      bool hasMore = true;

      while (hasMore) {
        final pageResponse = await _auth.client
            .from('mois')
            .select('*')
            .eq('event_id', _eventId!)
            .eq('is_deleted', false)
            .order('serial_no', ascending: true)
            .range(currentPage * pageSize, (currentPage + 1) * pageSize - 1);

        data.addAll(pageResponse);

        if (pageResponse.length < pageSize) {
          hasMore = false;
        } else {
          currentPage++;
        }
      }

      setState(() {
        _mois = List<Map<String, dynamic>>.from(data);
        _initializeControllers();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          onRetry: _loadMois,
          customMessage: 'Error loading data',
        );
      }
    }
  }

  void _initializeControllers() {
    final newControllers = <String, Map<String, TextEditingController>>{};

    for (var moi in _mois) {
      final moiId = moi['id'];

      if (_controllers.containsKey(moiId)) {
        _controllers[moiId]!['village_name']!.text = moi['village_name'] ?? '';
        _controllers[moiId]!['living_place']!.text = moi['living_place'] ?? '';

        final persons = moi['persons'] as List<dynamic>?;
        if (persons != null && persons.isNotEmpty) {
          // Person 1
          final person1 = persons[0] as Map<String, dynamic>;
          _controllers[moiId]!['person_0_name']!.text = person1['name'] ?? '';
          _controllers[moiId]!['person_0_job']!.text = person1['job'] ?? '';

          // Person 2
          if (persons.length > 1) {
            final person2 = persons[1] as Map<String, dynamic>;
            _controllers[moiId]!['person_1_details']!.text = person2['details'] ?? '';
          }
        }

        newControllers[moiId] = _controllers[moiId]!;
      } else {
        newControllers[moiId] = {
          'village_name': TextEditingController(text: moi['village_name'] ?? ''),
          'living_place': TextEditingController(text: moi['living_place'] ?? ''),
        };

        final persons = moi['persons'] as List<dynamic>?;
        if (persons != null && persons.isNotEmpty) {
          // Person 1
          final person1 = persons[0] as Map<String, dynamic>;
          newControllers[moiId]!['person_0_name'] =
              TextEditingController(text: person1['name'] ?? '');
          newControllers[moiId]!['person_0_job'] =
              TextEditingController(text: person1['job'] ?? '');

          // Person 2
          if (persons.length > 1) {
            final person2 = persons[1] as Map<String, dynamic>;
            newControllers[moiId]!['person_1_details'] =
                TextEditingController(text: person2['details'] ?? '');
          } else {
            newControllers[moiId]!['person_1_details'] = TextEditingController();
          }
        }
      }
    }

    _controllers = newControllers;
  }

  Future<void> _saveAllChanges() async {
    setState(() => _saving = true);

    int successCount = 0;
    int errorCount = 0;

    for (var moi in _mois) {
      try {
        await _saveSingleMoi(moi);
        successCount++;
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
        await _loadMois();
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

  Widget _buildEditableCell(TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: const InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        isDense: true,
      ),
      style: const TextStyle(fontSize: 13),
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

                        // Table
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: MaterialStateProperty.all(Colors.grey[200]),
                            border: TableBorder.all(color: Colors.grey[300]!),
                            columnSpacing: 8,
                            dataRowMinHeight: 48,
                            dataRowMaxHeight: 80,
                            columns: const [
                              DataColumn(
                                label: Text(
                                  'S.No',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Person 1 Name',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Person 1 Job',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Person 2 Details',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Village Name',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Living City',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ],
                            rows: _mois.map((moi) {
                              final moiId = moi['id'];
                              final persons = moi['persons'] as List<dynamic>?;

                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      'O${moi['serial_no']?.toString() ?? ''}',
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  // Person 1 Name
                                  DataCell(
                                    SizedBox(
                                      width: 150,
                                      child: _buildEditableCell(
                                        _controllers[moiId]!['person_0_name']!,
                                      ),
                                    ),
                                  ),
                                  // Person 1 Job
                                  DataCell(
                                    SizedBox(
                                      width: 150,
                                      child: _buildEditableCell(
                                        _controllers[moiId]!['person_0_job']!,
                                      ),
                                    ),
                                  ),
                                  // Person 2 Details
                                  DataCell(
                                    SizedBox(
                                      width: 200,
                                      child: persons != null && persons.length > 1
                                          ? _buildEditableCell(
                                        _controllers[moiId]!['person_1_details']!,
                                      )
                                          : const SizedBox(),
                                    ),
                                  ),
                                  // Village Name
                                  DataCell(
                                    SizedBox(
                                      width: 120,
                                      child: _buildEditableCell(
                                        _controllers[moiId]!['village_name']!,
                                      ),
                                    ),
                                  ),
                                  // Living City
                                  DataCell(
                                    SizedBox(
                                      width: 120,
                                      child: _buildEditableCell(
                                        _controllers[moiId]!['living_place']!,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ],
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