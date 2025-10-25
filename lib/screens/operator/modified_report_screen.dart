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
      // Fetch all mois entries that have old_data (meaning they were modified)
      final response = await _supabase
          .from('mois')
          .select('''
            id,
            serial_no,
            amount,
            village_name,
            phone,
            persons,
            old_data,
            operator_id,
            users!mois_operator_id_fkey (
              full_name
            )
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

  String _formatPersons(dynamic persons) {
    if (persons == null) return '';

    try {
      List<dynamic> personsList = persons is String ? [] : (persons as List);
      if (personsList.isEmpty) return '';

      List<String> formatted = [];
      for (var person in personsList) {
        String init = person['init'] ?? '';
        String name = person['name'] ?? '';
        String qualification = person['qualification'] ?? '';

        String personStr = '';
        if (init.isNotEmpty) personStr += '$init. ';
        if (name.isNotEmpty) personStr += name;
        if (qualification.isNotEmpty) personStr += ' ($qualification)';

        if (personStr.isNotEmpty) {
          formatted.add(personStr.trim());
        }
      }

      return formatted.join(', ');
    } catch (e) {
      return '';
    }
  }

  bool _hasChanged(dynamic oldValue, dynamic newValue) {
    if (oldValue == null && newValue == null) return false;
    if (oldValue == null || newValue == null) return true;
    return oldValue.toString() != newValue.toString();
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

          // Table
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
                final oldData = entry['old_data'] as Map<String, dynamic>?;
                final operatorName = entry['users']?['full_name'] ?? 'Unknown';

                return _buildComparisonCard(
                  entry,
                  oldData,
                  operatorName,
                );
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

  Widget _buildComparisonCard(
      Map<String, dynamic> entry,
      Map<String, dynamic>? oldData,
      String operatorName,
      ) {
    final serialNo = entry['serial_no'] ?? 'N/A';

    // Old values
    final oldVillage = oldData?['village_name'] ?? '';
    final oldPersons = _formatPersons(oldData?['persons']);
    final oldAmount = oldData?['amount']?.toString() ?? '';

    // New values
    final newVillage = entry['village_name'] ?? '';
    final newPersons = _formatPersons(entry['persons']);
    final newAmount = entry['amount']?.toString() ?? '';

    // Check what changed
    final villageChanged = _hasChanged(oldVillage, newVillage);
    final personsChanged = _hasChanged(oldPersons, newPersons);
    final amountChanged = _hasChanged(oldAmount, newAmount);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        children: [
          // Header with Sl.No
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF4CAF50),
              border: Border(
                bottom: BorderSide(color: Colors.black, width: 2),
              ),
            ),
            child: Text(
              'Sl.No: $serialNo',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),

          // Column Headers
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF4CAF50),
              border: Border(
                bottom: BorderSide(color: Colors.white, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      border: Border(
                        right: BorderSide(color: Colors.white, width: 1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Old Value',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '[UserName: $operatorName]',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Modified Value',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '[UserName: $operatorName]',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Old Value Column
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(color: Colors.grey[300]!, width: 1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (oldVillage.isNotEmpty)
                        Text(
                          oldVillage,
                          style: TextStyle(
                            fontSize: 14,
                            color: villageChanged ? Colors.red : Colors.black,
                          ),
                        ),
                      if (oldPersons.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          oldPersons,
                          style: TextStyle(
                            fontSize: 14,
                            color: personsChanged ? Colors.red : Colors.black,
                          ),
                        ),
                      ],
                      if (oldAmount.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          oldAmount,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: amountChanged ? Colors.red : Colors.black,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // New Value Column
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (newVillage.isNotEmpty)
                        Text(
                          newVillage,
                          style: TextStyle(
                            fontSize: 14,
                            color: villageChanged ? Colors.red : Colors.black,
                          ),
                        ),
                      if (newPersons.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          newPersons,
                          style: TextStyle(
                            fontSize: 14,
                            color: personsChanged ? Colors.red : Colors.black,
                          ),
                        ),
                      ],
                      if (newAmount.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          newAmount,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: amountChanged ? Colors.red : Colors.black,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}