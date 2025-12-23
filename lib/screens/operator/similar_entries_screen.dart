import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../utils/network_utils.dart';

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
        NetworkUtils.handleError(
          context,
          e,
          onRetry: _loadSimilarEntries,
          customMessage: 'Error loading entries',
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Helper to extract name after dot (removes initial)
  // "P. Prashanth" → "Prashanth"
  // "Prashanth" → "Prashanth"
  String _extractNameWithoutInitial(String name) {
    if (name.isEmpty) return '';

    final trimmed = name.trim();
    final dotIndex = trimmed.indexOf('.');

    if (dotIndex > 0 && dotIndex < trimmed.length - 1) {
      // Has initial like "P. Prashanth"
      return trimmed.substring(dotIndex + 1).trim();
    }

    return trimmed;
  }

  // Helper to extract person 2 name from details (before first comma, after dot if exists)
  // "S. Jayasri, B.E, engineer" → "Jayasri" (for comparison)
  // But keeps original "S. Jayasri" for display
  String _extractPerson2NameFull(String? details) {
    if (details == null || details.isEmpty) return '';
    final firstCommaIndex = details.indexOf(',');
    return firstCommaIndex > 0
        ? details.substring(0, firstCommaIndex).trim()
        : details.trim();
  }

  String _extractPerson2NameForComparison(String? details) {
    final fullName = _extractPerson2NameFull(details);
    return _extractNameWithoutInitial(fullName);
  }

  void _filterSimilarEntries() {
    // Group entries by composite key: village_name + person1_name + person1_job + person2_name
    // All names are normalized (without initials) for comparison
    Map<String, List<Map<String, dynamic>>> groupedEntries = {};

    for (var entry in _allEntries) {
      final villageName = (entry['village_name']?.toString() ?? '').trim().toLowerCase();
      final persons = entry['persons'] as List<dynamic>?;

      if (persons == null || persons.isEmpty) continue;

      // Extract Person 1 data
      String person1NameRaw = '';
      String person1NameNormalized = '';
      String person1Job = '';

      if (persons.isNotEmpty) {
        person1NameRaw = persons[0]['name']?.toString() ?? '';
        // Remove initial for comparison
        person1NameNormalized = _extractNameWithoutInitial(person1NameRaw).trim().toLowerCase();
        person1Job = (persons[0]['job']?.toString() ?? '').trim().toLowerCase();
      }

      // Extract Person 2 name from details (before first comma, after dot)
      String person2NameRaw = '';
      String person2NameNormalized = '';

      if (persons.length > 1) {
        final person2Details = persons[1]['details']?.toString() ?? '';
        if (person2Details.isNotEmpty) {
          person2NameRaw = _extractPerson2NameFull(person2Details);
          // Remove initial for comparison
          person2NameNormalized = _extractNameWithoutInitial(person2NameRaw).trim().toLowerCase();
        }
      }

      // Create composite key with normalized names (without initials)
      final compositeKey = '$villageName|$person1NameNormalized|$person1Job';

      if (!groupedEntries.containsKey(compositeKey)) {
        groupedEntries[compositeKey] = [];
      }
      groupedEntries[compositeKey]!.add(entry);
    }

    // Filter groups with duplicates (more than 1 entry)
    Set<String> processedIds = {};
    List<Map<String, dynamic>> duplicates = [];
    Map<String, List<String>> matchGroups = {};

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
          if (!matchGroups.containsKey(entryId)) {
            matchGroups[entryId] = [];
          }

          final persons = entry['persons'] as List<dynamic>?;
          if (persons != null && persons.isNotEmpty) {
            // Mark person 1 name as matching (normalized without initial)
            final p1NameRaw = persons[0]['name']?.toString() ?? '';
            final p1NameNormalized = _extractNameWithoutInitial(p1NameRaw).trim().toLowerCase();
            if (p1NameNormalized.isNotEmpty) {
              matchGroups[entryId]!.add('p1_name:$p1NameNormalized');
            }

            // Mark person 1 job as matching
            final p1Job = persons[0]['job']?.toString().trim().toLowerCase() ?? '';
            if (p1Job.isNotEmpty) {
              matchGroups[entryId]!.add('p1_job:$p1Job');
            }
          }

          // Mark village as matching
          final village = entry['village_name']?.toString().trim().toLowerCase() ?? '';
          if (village.isNotEmpty) {
            matchGroups[entryId]!.add('village:$village');
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

  // Updated helper method to check if a field is matching
  // For names, it normalizes by removing initials before comparison
  bool _isFieldMatching(String entryId, String fieldType, String value) {
    if (!nameMatchGroups.containsKey(entryId)) return false;
    final matchingFields = nameMatchGroups[entryId]!;

    String normalizedValue;
    if (fieldType == 'p1_name' || fieldType == 'p2_name') {
      // For name fields, remove initial before comparing
      normalizedValue = _extractNameWithoutInitial(value).trim().toLowerCase();
    } else {
      normalizedValue = value.trim().toLowerCase();
    }

    final searchKey = '$fieldType:$normalizedValue';
    return matchingFields.contains(searchKey);
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
                        _buildHeaderCell('First Person', 120),
                        _buildHeaderCell('Second Person', 120),
                        _buildHeaderCell('Village Name', 130),
                        _buildHeaderCell('Living Place', 130),
                        _buildHeaderCell('Amount', 100),
                      ],
                    ),

                    // BODY
                    Expanded(
                      child: SizedBox(
                        width: 670, // total width of all columns
                        child: ListView.builder(
                          itemCount: similarEntries.length,
                          itemBuilder: (context, index) {
                            final entry = similarEntries[index];
                            final entryId = entry['id'];
                            final persons = entry['persons'] as List<dynamic>?;

                            // Display WITH initials (as stored in DB)
                            String person1NameDisplay = '';
                            String person1Job = '';
                            String person2NameDisplay = '';

                            if (persons != null && persons.isNotEmpty) {
                              // Person 1: Show full name with initial
                              person1NameDisplay = persons[0]['name']?.toString() ?? '';
                              person1Job = persons[0]['job']?.toString() ?? '';

                              if (persons.length > 1) {
                                // Person 2: Show full name with initial (before first comma)
                                final person2Details = persons[1]['details']?.toString() ?? '';
                                person2NameDisplay = _extractPerson2NameFull(person2Details);
                              }
                            }

                            // Check if fields match (comparison done without initials)
                            final isP1NameMatch = _isFieldMatching(entryId, 'p1_name', person1NameDisplay);
                            final isP2NameMatch = _isFieldMatching(entryId, 'p2_name', person2NameDisplay);
                            final isVillageMatch = _isFieldMatching(entryId, 'village', entry['village_name'] ?? '');

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
                                  _buildDataCell(person1NameDisplay, 120,
                                      isMatch: isP1NameMatch),
                                  _buildDataCell(person2NameDisplay, 120,
                                      isMatch: isP2NameMatch),
                                  _buildDataCell(
                                      entry['village_name'] ?? '',
                                      130,
                                      isMatch: isVillageMatch),
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
                      width: 670,
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