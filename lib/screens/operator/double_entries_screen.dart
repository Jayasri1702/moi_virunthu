import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class DoubleEntriesScreen extends StatefulWidget {
  final String eventId;

  const DoubleEntriesScreen({
    super.key,
    required this.eventId,
  });

  @override
  State<DoubleEntriesScreen> createState() => _DoubleEntriesScreenState();
}

class _DoubleEntriesScreenState extends State<DoubleEntriesScreen> {
  final _auth = AuthService();
  List<Map<String, dynamic>> _allEntries = [];
  List<Map<String, dynamic>> doubleEntries = [];
  Map<String, List<String>> matchGroups = {};
  bool _isLoading = true;
  final ScrollController _horizontalController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadDoubleEntries();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  Future<void> _loadDoubleEntries() async {
    setState(() => _isLoading = true);

    try {
      final data = await _auth.client
          .from('mois')
          .select('id, serial_no, persons, village_name, living_place, amount')
          .eq('event_id', widget.eventId)
          .eq('is_deleted', false)
          .order('serial_no');

      setState(() {
        _allEntries = List<Map<String, dynamic>>.from(data);
        _filterDoubleEntries();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading entries: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteEntry(String entryId) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to permanently delete this entry from the database?'),
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
        );
      },
    );

    if (confirmed != true) return;

    try {
      // Permanently delete the entry from database
      await _auth.client
          .from('mois')
          .delete()
          .eq('id', entryId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entry deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reload the data
      await _loadDoubleEntries();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting entry: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper to extract initial from name
  // "P. Prashanth" → "P"
  // "Prashanth" → ""
  String _extractInitial(String name) {
    if (name.isEmpty) return '';

    final trimmed = name.trim();
    final dotIndex = trimmed.indexOf('.');

    if (dotIndex > 0) {
      return trimmed.substring(0, dotIndex).trim().toUpperCase();
    }

    return '';
  }

  // Helper to extract name without initial
  // "P. Prashanth" → "Prashanth"
  // "Prashanth" → "Prashanth"
  String _extractNameWithoutInitial(String name) {
    if (name.isEmpty) return '';

    final trimmed = name.trim();
    final dotIndex = trimmed.indexOf('.');

    if (dotIndex > 0 && dotIndex < trimmed.length - 1) {
      return trimmed.substring(dotIndex + 1).trim();
    }

    return trimmed;
  }

  void _filterDoubleEntries() {
    // Group entries by composite key: village_name + initial + name + job + amount
    Map<String, List<Map<String, dynamic>>> groupedEntries = {};

    for (var entry in _allEntries) {
      final villageName = (entry['village_name']?.toString() ?? '').trim().toLowerCase();
      final amount = entry['amount']?.toString() ?? '0';
      final persons = entry['persons'] as List<dynamic>?;

      if (persons == null || persons.isEmpty) continue;

      // Extract Person 1 data
      String person1NameRaw = '';
      String person1Initial = '';
      String person1NameNormalized = '';
      String person1Job = '';

      if (persons.isNotEmpty) {
        person1NameRaw = persons[0]['name']?.toString() ?? '';
        person1Initial = _extractInitial(person1NameRaw).toLowerCase();
        person1NameNormalized = _extractNameWithoutInitial(person1NameRaw).trim().toLowerCase();
        person1Job = (persons[0]['job']?.toString() ?? '').trim().toLowerCase();
      }

      // Create composite key: village + initial + name + job + amount
      final compositeKey = '$villageName|$person1Initial|$person1NameNormalized|$person1Job|$amount';

      if (!groupedEntries.containsKey(compositeKey)) {
        groupedEntries[compositeKey] = [];
      }
      groupedEntries[compositeKey]!.add(entry);
    }

    // Filter groups with duplicates (more than 1 entry)
    Set<String> processedIds = {};
    List<Map<String, dynamic>> duplicates = [];
    Map<String, List<String>> groups = {};

    groupedEntries.forEach((key, entries) {
      if (entries.length > 1) {
        // This group has duplicates
        for (var entry in entries) {
          final entryId = entry['id'];
          if (!processedIds.contains(entryId)) {
            duplicates.add(entry);
            processedIds.add(entryId);
          }

          // Store which fields matched for highlighting
          if (!groups.containsKey(entryId)) {
            groups[entryId] = [];
          }

          final persons = entry['persons'] as List<dynamic>?;
          if (persons != null && persons.isNotEmpty) {
            // Mark person 1 name as matching
            final p1NameRaw = persons[0]['name']?.toString() ?? '';
            final p1Initial = _extractInitial(p1NameRaw).toLowerCase();
            final p1NameNormalized = _extractNameWithoutInitial(p1NameRaw).trim().toLowerCase();
            final p1Job = persons[0]['job']?.toString().trim().toLowerCase() ?? '';

            if (p1NameNormalized.isNotEmpty) {
              groups[entryId]!.add('p1_name:$p1Initial|$p1NameNormalized');
            }

            if (p1Job.isNotEmpty) {
              groups[entryId]!.add('p1_job:$p1Job');
            }
          }

          // Mark village as matching
          final village = entry['village_name']?.toString().trim().toLowerCase() ?? '';
          if (village.isNotEmpty) {
            groups[entryId]!.add('village:$village');
          }

          // Mark amount as matching
          final amt = entry['amount']?.toString() ?? '';
          if (amt.isNotEmpty) {
            groups[entryId]!.add('amount:$amt');
          }
        }
      }
    });

    // Sort by serial number
    duplicates.sort((a, b) {
      final aSerial = a['serial_no'] ?? 0;
      final bSerial = b['serial_no'] ?? 0;
      return aSerial.compareTo(bSerial);
    });

    setState(() {
      doubleEntries = duplicates;
      matchGroups = groups;
    });
  }

  String _formatAmount(double amount) {
    String formatted = amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2);
    return formatted.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
    );
  }

  // Check if a field is matching
  bool _isFieldMatching(String entryId, String fieldType, String value) {
    if (!matchGroups.containsKey(entryId)) return false;
    final matchingFields = matchGroups[entryId]!;

    if (fieldType == 'p1_name') {
      // For name fields, check with initial
      final initial = _extractInitial(value).toLowerCase();
      final nameNormalized = _extractNameWithoutInitial(value).trim().toLowerCase();
      final searchKey = '$fieldType:$initial|$nameNormalized';
      return matchingFields.contains(searchKey);
    } else if (fieldType == 'amount') {
      final searchKey = '$fieldType:$value';
      return matchingFields.contains(searchKey);
    } else {
      final normalizedValue = value.trim().toLowerCase();
      final searchKey = '$fieldType:$normalizedValue';
      return matchingFields.contains(searchKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF6B4C9A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Double Entries',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: const Text(
              'Double Entries',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: _isLoading
                  ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF6B4C9A)),
              )
                  : doubleEntries.isEmpty
                  ? const Center(
                child: Text(
                  'No double entries found',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
                  : SingleChildScrollView(
                controller: _horizontalController,
                scrollDirection: Axis.horizontal,
                child: Column(
                  children: [
                    // HEADER
                    Row(
                      children: [
                        _buildHeaderCell('Serial.No', 70),
                        _buildHeaderCell('Init.', 50),
                        _buildHeaderCell('Name', 120),
                        _buildHeaderCell('Job', 100),
                        _buildHeaderCell('Village Name', 130),
                        _buildHeaderCell('Living Place', 130),
                        _buildHeaderCell('Amount', 100),
                        _buildHeaderCell('Action', 80),
                      ],
                    ),

                    // BODY
                    Expanded(
                      child: SizedBox(
                        width: 780, // total width of all columns
                        child: ListView.builder(
                          itemCount: doubleEntries.length,
                          itemBuilder: (context, index) {
                            final entry = doubleEntries[index];
                            final entryId = entry['id'];
                            final persons = entry['persons'] as List<dynamic>?;

                            String person1NameFull = '';
                            String person1Initial = '';
                            String person1Name = '';
                            String person1Job = '';

                            if (persons != null && persons.isNotEmpty) {
                              person1NameFull = persons[0]['name']?.toString() ?? '';
                              person1Initial = _extractInitial(person1NameFull);
                              person1Name = _extractNameWithoutInitial(person1NameFull);
                              person1Job = persons[0]['job']?.toString() ?? '';
                            }

                            final amountValue = double.tryParse(entry['amount']?.toString() ?? '0') ?? 0.0;
                            final amountStr = entry['amount']?.toString() ?? '0';

                            // Check if fields match
                            final isNameMatch = _isFieldMatching(entryId, 'p1_name', person1NameFull);
                            final isJobMatch = _isFieldMatching(entryId, 'p1_job', person1Job);
                            final isVillageMatch = _isFieldMatching(entryId, 'village', entry['village_name'] ?? '');
                            final isAmountMatch = _isFieldMatching(entryId, 'amount', amountStr);

                            return Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey[300]!,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  _buildDataCell(
                                      entry['serial_no']?.toString() ?? '',
                                      70,
                                      align: TextAlign.center),
                                  _buildDataCell(person1Initial, 50,
                                      align: TextAlign.center,
                                      isMatch: isNameMatch),
                                  _buildDataCell(person1Name, 120,
                                      isMatch: isNameMatch),
                                  _buildDataCell(person1Job, 100,
                                      isMatch: isJobMatch),
                                  _buildDataCell(
                                      entry['village_name'] ?? '',
                                      130,
                                      isMatch: isVillageMatch),
                                  _buildDataCell(
                                      entry['living_place'] ?? '', 130),
                                  _buildDataCell(
                                    _formatAmount(amountValue),
                                    100,
                                    align: TextAlign.right,
                                    isMatch: isAmountMatch,
                                  ),
                                  // Delete button cell
                                  Container(
                                    width: 80,
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        right: BorderSide(color: Colors.grey[300]!, width: 1),
                                      ),
                                    ),
                                    child: Center(
                                      child: IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _deleteEntry(entryId),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // FOOTER
                    Container(
                      width: 780,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                              color: Colors.grey[300]!, width: 1),
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Total   ${doubleEntries.length}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // EXIT BUTTON
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 150,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.black, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
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
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF6B4C9A),
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.5), width: 1),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildDataCell(
      String text,
      double width, {
        TextAlign align = TextAlign.left,
        bool isMatch = false,
      }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: isMatch ? Colors.red : Colors.black,
          fontWeight: isMatch ? FontWeight.bold : FontWeight.normal,
        ),
        textAlign: align,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}