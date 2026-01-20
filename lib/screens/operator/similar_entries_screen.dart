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
      // Fetch all entries with pagination
      List<dynamic> data = [];
      int pageSize = 1000;
      int currentPage = 0;
      bool hasMore = true;

      while (hasMore) {
        final pageResponse = await _auth.client
            .from('mois')
            .select('id, serial_no, persons, village_name, living_place, amount')
            .eq('event_id', widget.eventId)
            .eq('is_deleted', false)
            .order('serial_no')
            .range(currentPage * pageSize, (currentPage + 1) * pageSize - 1);

        data.addAll(pageResponse);

        if (pageResponse.length < pageSize) {
          hasMore = false;
        } else {
          currentPage++;
        }
      }

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

  String _extractNameWithoutInitial(String name) {
    if (name.isEmpty) return '';

    final trimmed = name.trim();
    final dotIndex = trimmed.indexOf('.');

    if (dotIndex > 0 && dotIndex < trimmed.length - 1) {
      return trimmed.substring(dotIndex + 1).trim();
    }

    return trimmed;
  }

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

  bool _isTamil(String text) {
    final tamilRegex = RegExp(r'[\u0B80-\u0BFF]');
    return tamilRegex.hasMatch(text);
  }

  String _extractTamilPart(String text) {
    final tamilRegex = RegExp(r'[\u0B80-\u0BFF]+');
    final matches = tamilRegex.allMatches(text);
    if (matches.isNotEmpty) {
      return matches.first.group(0) ?? '';
    }
    return '';
  }

  int _compareTamilStrings(String a, String b) {
    final tamilOrder = {
      'அ': 1, 'ஆ': 2, 'இ': 3, 'ஈ': 4, 'உ': 5, 'ஊ': 6, 'எ': 7, 'ஏ': 8,
      'ஐ': 9, 'ஒ': 10, 'ஓ': 11, 'ஔ': 12,
      'க': 13, 'ங': 14, 'ச': 15, 'ஞ': 16, 'ட': 17, 'ண': 18, 'த': 19, 'ந': 20,
      'ப': 21, 'ம': 22, 'ய': 23, 'ர': 24, 'ல': 25, 'வ': 26, 'ழ': 27, 'ள': 28,
      'ற': 29, 'ன': 30,
    };

    final aFirstChar = a.isNotEmpty ? a[0] : '';
    final bFirstChar = b.isNotEmpty ? b[0] : '';

    final aOrder = tamilOrder[aFirstChar] ?? aFirstChar.codeUnitAt(0);
    final bOrder = tamilOrder[bFirstChar] ?? bFirstChar.codeUnitAt(0);

    if (aOrder != bOrder) {
      return aOrder.compareTo(bOrder);
    }

    return a.compareTo(b);
  }

  void _filterSimilarEntries() {
    Map<String, List<Map<String, dynamic>>> groupedEntries = {};

    for (var entry in _allEntries) {
      final villageName = (entry['village_name']?.toString() ?? '').trim().toLowerCase();
      final persons = entry['persons'] as List<dynamic>?;

      if (persons == null || persons.isEmpty) continue;

      String person1NameRaw = '';
      String person1NameNormalized = '';
      String person1Job = '';

      if (persons.isNotEmpty) {
        person1NameRaw = persons[0]['name']?.toString() ?? '';
        person1NameNormalized = _extractNameWithoutInitial(person1NameRaw).trim().toLowerCase();
        person1Job = (persons[0]['job']?.toString() ?? '').trim().toLowerCase();
      }

      String person2NameRaw = '';
      String person2NameNormalized = '';

      if (persons.length > 1) {
        final person2Details = persons[1]['details']?.toString() ?? '';
        if (person2Details.isNotEmpty) {
          person2NameRaw = _extractPerson2NameFull(person2Details);
          person2NameNormalized = _extractNameWithoutInitial(person2NameRaw).trim().toLowerCase();
        }
      }

      final compositeKey = '$villageName|$person1NameNormalized|$person1Job';

      if (!groupedEntries.containsKey(compositeKey)) {
        groupedEntries[compositeKey] = [];
      }
      groupedEntries[compositeKey]!.add(entry);
    }

    Set<String> processedIds = {};
    List<Map<String, dynamic>> duplicates = [];
    Map<String, List<String>> matchGroups = {};

    groupedEntries.forEach((key, entries) {
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

          final persons = entry['persons'] as List<dynamic>?;
          if (persons != null && persons.isNotEmpty) {
            final p1NameRaw = persons[0]['name']?.toString() ?? '';
            final p1NameNormalized = _extractNameWithoutInitial(p1NameRaw).trim().toLowerCase();
            if (p1NameNormalized.isNotEmpty) {
              matchGroups[entryId]!.add('p1_name:$p1NameNormalized');
            }

            final p1Job = persons[0]['job']?.toString().trim().toLowerCase() ?? '';
            if (p1Job.isNotEmpty) {
              matchGroups[entryId]!.add('p1_job:$p1Job');
            }
          }

          final village = entry['village_name']?.toString().trim().toLowerCase() ?? '';
          if (village.isNotEmpty) {
            matchGroups[entryId]!.add('village:$village');
          }
        }
      }
    });

    // ✅ SORT ALPHABETICALLY BY PERSON 1 NAME (Tamil first, then English)
    duplicates.sort((a, b) {
      final personsA = a['persons'] as List<dynamic>?;
      final personsB = b['persons'] as List<dynamic>?;

      if (personsA == null || personsA.isEmpty) return 1;
      if (personsB == null || personsB.isEmpty) return -1;

      final nameA = personsA[0]['name']?.toString() ?? '';
      final nameB = personsB[0]['name']?.toString() ?? '';

      // Extract name without initial for comparison
      final normalizedA = _extractNameWithoutInitial(nameA);
      final normalizedB = _extractNameWithoutInitial(nameB);

      // Check if Tamil or English
      final isTamilA = _isTamil(normalizedA);
      final isTamilB = _isTamil(normalizedB);

      // Tamil names come first
      if (isTamilA && !isTamilB) return -1;
      if (!isTamilA && isTamilB) return 1;

      // Both Tamil - use Tamil sorting
      if (isTamilA && isTamilB) {
        final tamilPartA = _extractTamilPart(normalizedA);
        final tamilPartB = _extractTamilPart(normalizedB);
        return _compareTamilStrings(tamilPartA, tamilPartB);
      }

      // Both English - case insensitive sort
      return normalizedA.toLowerCase().compareTo(normalizedB.toLowerCase());
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

  bool _isFieldMatching(String entryId, String fieldType, String value) {
    if (!nameMatchGroups.containsKey(entryId)) return false;
    final matchingFields = nameMatchGroups[entryId]!;

    String normalizedValue;
    if (fieldType == 'p1_name' || fieldType == 'p2_name') {
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
                        width: 670,
                        child: ListView.builder(
                          itemCount: similarEntries.length,
                          itemBuilder: (context, index) {
                            final entry = similarEntries[index];
                            final entryId = entry['id'];
                            final persons = entry['persons'] as List<dynamic>?;

                            String person1NameDisplay = '';
                            String person1Job = '';
                            String person2NameDisplay = '';

                            if (persons != null && persons.isNotEmpty) {
                              person1NameDisplay = persons[0]['name']?.toString() ?? '';
                              person1Job = persons[0]['job']?.toString() ?? '';

                              if (persons.length > 1) {
                                final person2Details = persons[1]['details']?.toString() ?? '';
                                person2NameDisplay = _extractPerson2NameFull(person2Details);
                              }
                            }

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