import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class SimilarEntriesScreen extends StatefulWidget {
  final String eventId;
  final String? searchName;

  const SimilarEntriesScreen({
    super.key,
    required this.eventId,
    this.searchName,
  });

  @override
  State<SimilarEntriesScreen> createState() => _SimilarEntriesScreenState();
}

class _SimilarEntriesScreenState extends State<SimilarEntriesScreen> {
  final _auth = AuthService();
  List<Map<String, dynamic>> _allEntries = [];
  List<Map<String, dynamic>> similarEntries = [];
  Map<String, List<String>> nameMatchGroups = {};
  bool _isLoading = true;
  final ScrollController _horizontalController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadSimilarEntries();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  Future<void> _loadSimilarEntries() async {
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
        _filterSimilarEntries();
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

  void _filterSimilarEntries() {
    Map<String, List<Map<String, dynamic>>> allNameGroups = {};

    for (var entry in _allEntries) {
      final persons = entry['persons'] as List<dynamic>?;
      if (persons == null || persons.isEmpty) continue;

      for (var person in persons) {
        final name = person['name']?.toString().trim().toLowerCase() ?? '';
        if (name.isNotEmpty) {
          if (!allNameGroups.containsKey(name)) {
            allNameGroups[name] = [];
          }
          allNameGroups[name]!.add(entry);
        }
      }
    }

    Map<String, List<String>> matchGroups = {};
    Set<String> processedIds = {};
    List<Map<String, dynamic>> duplicates = [];

    allNameGroups.forEach((name, entries) {
      if (entries.length > 1) {
        for (var entry in entries) {
          final entryId = entry['id'];
          if (!processedIds.contains(entryId)) {
            duplicates.add(entry);
            processedIds.add(entryId);
          }

          if (!matchGroups.containsKey(entryId)) {
            matchGroups[entryId] = [];
          }
          matchGroups[entryId]!.add(name);
        }
      }
    });

    duplicates.sort((a, b) {
      final aSerial = a['serial_no'] ?? 0;
      final bSerial = b['serial_no'] ?? 0;
      return aSerial.compareTo(bSerial);
    });

    setState(() {
      similarEntries = duplicates;
      nameMatchGroups = matchGroups;
    });
  }

  String _formatAmount(double amount) {
    String formatted = amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2);
    return formatted.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
    );
  }

  bool _isNameMatching(String entryId, String name) {
    if (!nameMatchGroups.containsKey(entryId)) return false;
    final matchingNames = nameMatchGroups[entryId]!;
    final normalizedName = name.trim().toLowerCase();
    return matchingNames.contains(normalizedName);
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
          'Similar Entries',
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
              'Similar Entries',
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
                  : similarEntries.isEmpty
                  ? const Center(
                child: Text(
                  'No similar entries found',
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
                        _buildHeaderCell('Name', 100),
                        _buildHeaderCell('Second Person', 120),
                        _buildHeaderCell('Village Name', 130),
                        _buildHeaderCell('Living Place', 130),
                        _buildHeaderCell('Amount', 100),
                      ],
                    ),

                    // BODY
                    Expanded(
                      child: SizedBox(
                        width: 650, // total width of all columns
                        child: ListView.builder(
                          itemCount: similarEntries.length,
                          itemBuilder: (context, index) {
                            final entry = similarEntries[index];
                            final entryId = entry['id'];
                            final persons =
                            entry['persons'] as List<dynamic>?;

                            String firstName = '';
                            String secondPerson = '';

                            if (persons != null && persons.isNotEmpty) {
                              firstName =
                                  persons[0]['name']?.toString() ?? '';
                              if (persons.length > 1) {
                                secondPerson =
                                    persons[1]['name']?.toString() ??
                                        '';
                              }
                            }

                            final isFirstMatch =
                            _isNameMatching(entryId, firstName);
                            final isSecondMatch =
                            _isNameMatching(entryId, secondPerson);

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
                                      entry['serial_no']?.toString() ??
                                          '',
                                      70,
                                      align: TextAlign.center),
                                  _buildDataCell(firstName, 100,
                                      isMatch: isFirstMatch),
                                  _buildDataCell(secondPerson, 120,
                                      isMatch: isSecondMatch),
                                  _buildDataCell(
                                      entry['village_name'] ?? '',
                                      130),
                                  _buildDataCell(
                                      entry['living_place'] ?? '', 130),
                                  _buildDataCell(
                                    _formatAmount(
                                      double.tryParse(entry['amount']
                                          ?.toString() ??
                                          '0') ??
                                          0.0,
                                    ),
                                    100,
                                    align: TextAlign.right,
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
                      width: 650,
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
                          'Total   ${similarEntries.length}',
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