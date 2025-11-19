import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ModifiedReportScreen extends StatefulWidget {
  final String eventId;

  const ModifiedReportScreen({
    super.key,
    required this.eventId,
  });

  @override
  State<ModifiedReportScreen> createState() => _ModifiedReportScreenState();
}

class _ModifiedReportScreenState extends State<ModifiedReportScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _modifiedEntries = [];
  bool _isLoading = true;
  Map<String, bool> _expandedCards = {};

  @override
  void initState() {
    super.initState();
    _loadModifiedEntries();
  }

  Future<void> _loadModifiedEntries() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _supabase
          .from('mois')
          .select('''
            id,
            serial_no,
            amount,
            village_name,
            phone,
            persons,
            old_data
          ''')
          .eq('event_id', widget.eventId)
          .not('old_data', 'is', null)
          .order('serial_no', ascending: true);

      setState(() {
        _modifiedEntries = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading modified entries: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getPersonName(dynamic persons) {
    if (persons == null) return '';

    try {
      if (persons is! List) return '';
      List<dynamic> personsList = persons as List;
      if (personsList.isEmpty) return '';

      // Person 1: name field
      if (personsList[0] is Map) {
        var person1 = personsList[0] as Map;
        String name = person1['name']?.toString() ?? '';
        return name;
      }
    } catch (e) {
      print('Error getting person name: $e');
    }

    return '';
  }

  String _formatPersons(dynamic persons) {
    if (persons == null) return '';

    try {
      if (persons is! List) return '';
      List<dynamic> personsList = persons as List;
      if (personsList.isEmpty) return '';

      List<String> formatted = [];

      // Person 1: name and job
      if (personsList.isNotEmpty && personsList[0] is Map) {
        var person1 = personsList[0] as Map;
        String name = person1['name']?.toString() ?? '';
        String job = person1['job']?.toString() ?? '';

        if (name.isNotEmpty || job.isNotEmpty) {
          String p1Str = '';
          if (name.isNotEmpty) p1Str += name;
          if (job.isNotEmpty) p1Str += (name.isNotEmpty ? ', ' : '') + job;
          formatted.add(p1Str);
        }
      }

      // Person 2: details
      if (personsList.length > 1 && personsList[1] is Map) {
        var person2 = personsList[1] as Map;
        String details = person2['details']?.toString() ?? '';
        if (details.isNotEmpty) {
          formatted.add(details);
        }
      }

      return formatted.join(' | ');
    } catch (e) {
      print('Error formatting persons: $e');
      return '';
    }
  }

  // Flatten nested old_data structure into chronological list
  List<Map<String, dynamic>> _getChangeHistory(dynamic oldData) {
    if (oldData == null) return [];

    try {
      List<Map<String, dynamic>> flattened = [];
      dynamic current = oldData;

      // Traverse nested structure from newest to oldest
      while (current != null && current is Map) {
        Map<String, dynamic> snapshot = {
          'village_name': current['village_name'],
          'amount': current['amount'],
          'persons': current['persons'],
          'phone': current['phone'],
          'timestamp': current['updated_at'],
        };

        // Insert at beginning to maintain chronological order (oldest first)
        flattened.insert(0, snapshot);

        // Move to next nested level
        current = current['old_data'];
      }

      return flattened;
    } catch (e) {
      print('Error parsing change history: $e');
      return [];
    }
  }

  Map<String, List<String>> _getChangedFields(Map<String, dynamic> oldValue, Map<String, dynamic> newValue) {
    Map<String, List<String>> changes = {};

    // Check village_name
    final oldVillage = oldValue['village_name']?.toString() ?? '';
    final newVillage = newValue['village_name']?.toString() ?? '';
    if (oldVillage != newVillage) {
      changes['Village'] = [oldVillage, newVillage];
    }

    // Check amount
    final oldAmount = oldValue['amount']?.toString() ?? '';
    final newAmount = newValue['amount']?.toString() ?? '';
    if (oldAmount != newAmount) {
      changes['Amount'] = [oldAmount, newAmount];
    }

    // Check persons
    final oldPersons = _formatPersons(oldValue['persons']);
    final newPersons = _formatPersons(newValue['persons']);
    if (oldPersons != newPersons) {
      changes['Persons'] = [oldPersons, newPersons];
    }

    // Check phone
    final oldPhone = oldValue['phone']?.toString() ?? '';
    final newPhone = newValue['phone']?.toString() ?? '';
    if (oldPhone != newPhone) {
      changes['Phone'] = [oldPhone, newPhone];
    }

    return changes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Modified Report',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: const Text(
              'Modified Report',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 16),

          // Table Header
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50),
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: Row(
              children: [
                _buildHeaderCell('Sl.No', flex: 1),
                _buildHeaderCell('Name', flex: 2),
                _buildHeaderCell('Modified Field', flex: 2),
                _buildHeaderCell('Updated Value', flex: 2),
              ],
            ),
          ),

          // Table Body
          Expanded(
            child: _isLoading
                ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF4CAF50),
              ),
            )
                : _modifiedEntries.isEmpty
                ? const Center(
              child: Text(
                'No modified entries found',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _modifiedEntries.length,
              itemBuilder: (context, index) {
                final entry = _modifiedEntries[index];
                final entryId = entry['id'];
                final isExpanded = _expandedCards[entryId] ?? false;

                return _buildModificationRow(entry, isExpanded, entryId);
              },
            ),
          ),

          // Exit Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                    side: const BorderSide(color: Colors.black, width: 2),
                  ),
                ),
                child: const Text(
                  'Exit',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: Colors.white, width: 1),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildModificationRow(Map<String, dynamic> entry, bool isExpanded, String entryId) {
    final serialNo = entry['serial_no']?.toString() ?? 'N/A';
    final personName = _getPersonName(entry['persons']);
    final changeHistory = _getChangeHistory(entry['old_data']);

    // Get current values
    final currentValues = {
      'village_name': entry['village_name'],
      'amount': entry['amount'],
      'persons': entry['persons'],
      'phone': entry['phone'],
    };

    // Get latest old values (most recent change in history)
    Map<String, dynamic> latestOldValues = changeHistory.isNotEmpty
        ? changeHistory.last
        : {};

    // Get changed fields for summary
    final changedFields = _getChangedFields(latestOldValues, currentValues);
    final modifiedFieldsText = changedFields.keys.join(', ');
    final updatedValues = changedFields.values.map((v) => v[1]).join(', ');

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _expandedCards[entryId] = !isExpanded;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: Row(
              children: [
                _buildCell(serialNo, flex: 1),
                _buildCell(personName, flex: 2),
                _buildCell(modifiedFieldsText, flex: 2, color: Colors.orange[100]),
                _buildCell(updatedValues, flex: 2, color: Colors.green[100]),
              ],
            ),
          ),
        ),

        // Expanded history
        if (isExpanded)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[700],
                    border: const Border(
                      bottom: BorderSide(color: Colors.black, width: 1),
                    ),
                  ),
                  child: const Text(
                    'Change History',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                _buildFullHistory(changeHistory, currentValues),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCell(String text, {int flex = 1, Color? color}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          border: Border(
            right: BorderSide(color: Colors.grey[300]!, width: 1),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildFullHistory(List<Map<String, dynamic>> history, Map<String, dynamic> currentValues) {
    if (history.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No change history available',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final oldSnapshot = history[index];
        final newSnapshot = index < history.length - 1
            ? history[index + 1]
            : currentValues;

        final changes = _getChangedFields(oldSnapshot, newSnapshot);
        final changeNumber = index + 1;
        final isLatest = index == history.length - 1;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isLatest ? Colors.white : Colors.grey[100],
            border: Border(
              bottom: BorderSide(
                color: Colors.grey[300]!,
                width: 1,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isLatest ? Colors.blue[700] : Colors.grey[600],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Change $changeNumber',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...changes.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            border: Border.all(color: Colors.red[300]!),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            entry.value[0].isEmpty ? '(empty)' : entry.value[0],
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                      ),
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            border: Border.all(color: Colors.green[300]!),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            entry.value[1].isEmpty ? '(empty)' : entry.value[1],
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }
}