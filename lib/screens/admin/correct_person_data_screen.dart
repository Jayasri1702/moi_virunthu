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
          // Don't dispose controllers here, just reinitialize them
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
    // Create a new map instead of clearing to avoid disposing active controllers
    final newControllers = <String, Map<String, TextEditingController>>{};

    for (var moi in _mois) {
      final moiId = moi['id'];

      // Reuse existing controllers if they exist, otherwise create new ones
      if (_controllers.containsKey(moiId)) {
        // Update existing controllers with new values
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
        // Create new controllers for this moi
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

  String _getPersonNames(Map<String, dynamic> moi) {
    final persons = moi['persons'] as List<dynamic>?;
    if (persons == null || persons.isEmpty) return '';

    return persons.map((person) {
      final p = person as Map<String, dynamic>;
      final init = p['init'] ?? '';
      final name = p['name'] ?? '';
      if (init.isNotEmpty && name.isNotEmpty) {
        return '$init.$name';
      } else if (name.isNotEmpty) {
        return name;
      }
      return '';
    }).where((n) => n.isNotEmpty).join(', ');
  }

  String _getEducations(Map<String, dynamic> moi) {
    final persons = moi['persons'] as List<dynamic>?;
    if (persons == null || persons.isEmpty) return '';

    return persons.map((person) {
      final p = person as Map<String, dynamic>;
      return p['qualification'] ?? '';
    }).where((e) => e.isNotEmpty).join(', ');
  }

  String _getJobs(Map<String, dynamic> moi) {
    final persons = moi['persons'] as List<dynamic>?;
    if (persons == null || persons.isEmpty) return '';

    return persons.map((person) {
      final p = person as Map<String, dynamic>;
      return p['job'] ?? '';
    }).where((j) => j.isNotEmpty).join(', ');
  }

  Future<void> _saveChanges(Map<String, dynamic> moi) async {
    final moiId = moi['id'];

    try {
      // Reconstruct persons array from controllers
      final persons = moi['persons'] as List<dynamic>?;
      final updatedPersons = <Map<String, dynamic>>[];

      if (persons != null) {
        for (int i = 0; i < persons.length; i++) {
          final init = _controllers[moiId]!['person_${i}_init']!.text.trim();
          final name = _controllers[moiId]!['person_${i}_name']!.text.trim();
          final qualification = _controllers[moiId]!['person_${i}_qualification']!.text.trim();
          final job = _controllers[moiId]!['person_${i}_job']!.text.trim();

          // Match collect_moi structure - include all fields
          updatedPersons.add({
            'init': init,
            'name': name,
            'qualification': qualification,
            'job': job,
          });
        }
      }

      print('🔄 Updating moi $moiId');
      print('📝 Updated persons: $updatedPersons');

// Update in database (NO old_data tracking for correct person data)
      final response = await _auth.client
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
          .eq('id', moiId)
          .select()
          .single();

      print('✅ Update successful: $response');

      if (mounted) {
        // Reload data FIRST to ensure we have fresh data
        await _loadMois();

        // Then show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Changes saved for Serial No: O${moi['serial_no']}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error saving changes: $e');
      print('📍 Error type: ${e.runtimeType}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _showEditDialog(Map<String, dynamic> moi) {
    final moiId = moi['id'];
    final persons = moi['persons'] as List<dynamic>?;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Person Data - O${moi['serial_no']}'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Person fields
                if (persons != null)
                  ...List.generate(persons.length, (i) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Person ${i + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _controllers[moiId]!['person_${i}_init'],
                          decoration: const InputDecoration(
                            labelText: 'Init',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _controllers[moiId]!['person_${i}_name'],
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _controllers[moiId]!['person_${i}_qualification'],
                          decoration: const InputDecoration(
                            labelText: 'Education',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _controllers[moiId]!['person_${i}_job'],
                          decoration: const InputDecoration(
                            labelText: 'Job',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        if (i < persons.length - 1)
                          const Divider(height: 24, thickness: 2),
                        if (i < persons.length - 1)
                          const SizedBox(height: 8),
                      ],
                    );
                  }),

                const SizedBox(height: 16),
                const Divider(thickness: 2),
                const SizedBox(height: 16),

                // Village and Living Place
                const Text(
                  'Location Details',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _controllers[moiId]!['village_name'],
                  decoration: const InputDecoration(
                    labelText: 'Village Name',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _controllers[moiId]!['living_place'],
                  decoration: const InputDecoration(
                    labelText: 'Living City',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _saveChanges(moi);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB846D7),
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
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
          : SingleChildScrollView(
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
                      'PERSON DATA - Click on any row to edit',
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
                      columnSpacing: 16,
                      dataRowMinHeight: 48,
                      dataRowMaxHeight: 80,
                      columns: const [
                        DataColumn(
                          label: Text(
                            'S.No',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Names',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Education',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Job',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Village Name',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Living City',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                      rows: _mois.map((moi) {
                        return DataRow(
                          onSelectChanged: (_) => _showEditDialog(moi),
                          cells: [
                            DataCell(Text('O${moi['serial_no']?.toString() ?? ''}')),
                            DataCell(
                              SizedBox(
                                width: 150,
                                child: Text(
                                  _getPersonNames(moi),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 150,
                                child: Text(
                                  _getEducations(moi),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 150,
                                child: Text(
                                  _getJobs(moi),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 150,
                                child: Text(
                                  moi['village_name'] ?? '',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 150,
                                child: Text(
                                  moi['living_place'] ?? '',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
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
    );
  }
}