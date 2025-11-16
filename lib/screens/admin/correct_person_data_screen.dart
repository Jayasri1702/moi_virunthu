import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

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
      final data = await _auth.client
          .from('mois')
          .select('*')
          .eq('event_id', _eventId!)
          .eq('is_deleted', false)
          .order('serial_no', ascending: true);

      setState(() {
        _mois = List<Map<String, dynamic>>.from(data);
        _initializeControllers();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
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
        if (persons != null) {
          for (int i = 0; i < persons.length; i++) {
            final person = persons[i] as Map<String, dynamic>;
            _controllers[moiId]!['person_${i}_init']!.text = person['init'] ?? '';
            _controllers[moiId]!['person_${i}_name']!.text = person['name'] ?? '';
            _controllers[moiId]!['person_${i}_qualification']!.text = person['qualification'] ?? '';
            _controllers[moiId]!['person_${i}_job']!.text = person['job'] ?? '';
          }
        }

        newControllers[moiId] = _controllers[moiId]!;
      } else {
        newControllers[moiId] = {
          'village_name': TextEditingController(text: moi['village_name'] ?? ''),
          'living_place': TextEditingController(text: moi['living_place'] ?? ''),
        };

        final persons = moi['persons'] as List<dynamic>?;
        if (persons != null) {
          for (int i = 0; i < persons.length; i++) {
            final person = persons[i] as Map<String, dynamic>;
            newControllers[moiId]!['person_${i}_init'] =
                TextEditingController(text: person['init'] ?? '');
            newControllers[moiId]!['person_${i}_name'] =
                TextEditingController(text: person['name'] ?? '');
            newControllers[moiId]!['person_${i}_qualification'] =
                TextEditingController(text: person['qualification'] ?? '');
            newControllers[moiId]!['person_${i}_job'] =
                TextEditingController(text: person['job'] ?? '');
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
        print('❌ Error saving moi ${moi['serial_no']}: $e');
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

    // Reconstruct persons array from controllers
    final persons = moi['persons'] as List<dynamic>?;
    final updatedPersons = <Map<String, dynamic>>[];

    if (persons != null) {
      for (int i = 0; i < persons.length; i++) {
        final init = _controllers[moiId]!['person_${i}_init']!.text.trim();
        final name = _controllers[moiId]!['person_${i}_name']!.text.trim();
        final qualification = _controllers[moiId]!['person_${i}_qualification']!.text.trim();
        final job = _controllers[moiId]!['person_${i}_job']!.text.trim();

        updatedPersons.add({
          'init': init,
          'name': name,
          'qualification': qualification,
          'job': job,
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
                                  'Init 1',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Name 1',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Education 1',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Job 1',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Init 2',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Name 2',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Education 2',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Job 2',
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
                                  // Person 1 fields
                                  DataCell(
                                    SizedBox(
                                      width: 60,
                                      child: _buildEditableCell(
                                        _controllers[moiId]!['person_0_init']!,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 120,
                                      child: _buildEditableCell(
                                        _controllers[moiId]!['person_0_name']!,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 120,
                                      child: _buildEditableCell(
                                        _controllers[moiId]!['person_0_qualification']!,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 120,
                                      child: _buildEditableCell(
                                        _controllers[moiId]!['person_0_job']!,
                                      ),
                                    ),
                                  ),
                                  // Person 2 fields (if exists)
                                  DataCell(
                                    SizedBox(
                                      width: 60,
                                      child: persons != null && persons.length > 1
                                          ? _buildEditableCell(
                                        _controllers[moiId]!['person_1_init']!,
                                      )
                                          : const SizedBox(),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 120,
                                      child: persons != null && persons.length > 1
                                          ? _buildEditableCell(
                                        _controllers[moiId]!['person_1_name']!,
                                      )
                                          : const SizedBox(),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 120,
                                      child: persons != null && persons.length > 1
                                          ? _buildEditableCell(
                                        _controllers[moiId]!['person_1_qualification']!,
                                      )
                                          : const SizedBox(),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 120,
                                      child: persons != null && persons.length > 1
                                          ? _buildEditableCell(
                                        _controllers[moiId]!['person_1_job']!,
                                      )
                                          : const SizedBox(),
                                    ),
                                  ),
                                  // Village and Living Place
                                  DataCell(
                                    SizedBox(
                                      width: 120,
                                      child: _buildEditableCell(
                                        _controllers[moiId]!['village_name']!,
                                      ),
                                    ),
                                  ),
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