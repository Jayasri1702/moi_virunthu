import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/network_utils.dart';

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
  List<Map<String, dynamic>> _filteredEntries = [];
  bool _isLoading = true;
  Map<String, bool> _expandedCards = {};

  // Search controller
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadModifiedEntries();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterEntries();
    });
  }

  void _filterEntries() {
    if (_searchQuery.isEmpty) {
      _filteredEntries = List.from(_modifiedEntries);
    } else {
      _filteredEntries = _modifiedEntries.where((entry) {
        final personName = _getPersonName(entry['persons']).toLowerCase();
        final serialNo = entry['serial_no']?.toString().toLowerCase() ?? '';
        final village = entry['village_name']?.toString().toLowerCase() ?? '';

        return personName.contains(_searchQuery) ||
            serialNo.contains(_searchQuery) ||
            village.contains(_searchQuery);
      }).toList();
    }
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
          living_place,
          phone,
          notes,
          payment_method,
          is_uncle,
          persons,
          old_data
        ''')
          .eq('event_id', widget.eventId)
          .not('old_data', 'is', null)
          .order('serial_no', ascending: true);

      setState(() {
        _modifiedEntries = List<Map<String, dynamic>>.from(response);
        _filteredEntries = List.from(_modifiedEntries);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading modified entries: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          onRetry: _loadModifiedEntries,
          customMessage: 'Error loading data',
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

      while (current != null && current is Map) {
        Map<String, dynamic> snapshot = {
          'village_name': current['village_name'],
          'living_place': current['living_place'],
          'amount': current['amount'],
          'persons': current['persons'],
          'phone': current['phone'],
          'notes': current['notes'],
          'payment_method': current['payment_method'],
          'is_uncle': current['is_uncle'],
          'timestamp': current['updated_at'],
        };

        flattened.insert(0, snapshot);
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

    // Helper function to format amount without .0
    String formatAmount(dynamic amount) {
      if (amount == null) return '';
      if (amount is num) {
        // Check if it's a whole number
        if (amount == amount.toInt()) {
          return amount.toInt().toString();
        }
        return amount.toString();
      }
      return amount.toString();
    }

    // Helper function to compare numeric values properly
    bool areNumbersDifferent(dynamic old, dynamic new_) {
      if (old == null && new_ == null) return false;
      if (old == null || new_ == null) return true;

      // Try to parse as numbers
      num? oldNum;
      num? newNum;

      if (old is num) {
        oldNum = old;
      } else {
        oldNum = num.tryParse(old.toString());
      }

      if (new_ is num) {
        newNum = new_;
      } else {
        newNum = num.tryParse(new_.toString());
      }

      // If both are valid numbers, compare numerically
      if (oldNum != null && newNum != null) {
        return oldNum != newNum;
      }

      // Otherwise compare as strings
      return old.toString() != new_.toString();
    }

    // Check village_name
    final oldVillage = oldValue['village_name']?.toString().trim() ?? '';
    final newVillage = newValue['village_name']?.toString().trim() ?? '';
    if (oldVillage != newVillage && (oldVillage.isNotEmpty || newVillage.isNotEmpty)) {
      changes['Village'] = [
        oldVillage.isEmpty ? '(empty)' : oldVillage,
        newVillage.isEmpty ? '(empty)' : newVillage
      ];
    }

    // Check living_place
    final oldLivingPlace = oldValue['living_place']?.toString().trim() ?? '';
    final newLivingPlace = newValue['living_place']?.toString().trim() ?? '';
    if (oldLivingPlace != newLivingPlace && (oldLivingPlace.isNotEmpty || newLivingPlace.isNotEmpty)) {
      changes['Living City'] = [
        oldLivingPlace.isEmpty ? '(empty)' : oldLivingPlace,
        newLivingPlace.isEmpty ? '(empty)' : newLivingPlace
      ];
    }

    // Check amount - WITH PROPER NUMERIC COMPARISON
    if (areNumbersDifferent(oldValue['amount'], newValue['amount'])) {
      final oldAmountFormatted = formatAmount(oldValue['amount']);
      final newAmountFormatted = formatAmount(newValue['amount']);
      if (oldAmountFormatted.isNotEmpty || newAmountFormatted.isNotEmpty) {
        changes['Amount'] = [
          oldAmountFormatted.isEmpty ? '₹0' : '₹$oldAmountFormatted',
          newAmountFormatted.isEmpty ? '₹0' : '₹$newAmountFormatted'
        ];
      }
    }

    // Check phone
    final oldPhone = oldValue['phone']?.toString().trim() ?? '';
    final newPhone = newValue['phone']?.toString().trim() ?? '';
    if (oldPhone != newPhone && (oldPhone.isNotEmpty || newPhone.isNotEmpty)) {
      changes['Phone'] = [
        oldPhone.isEmpty ? '(empty)' : oldPhone,
        newPhone.isEmpty ? '(empty)' : newPhone
      ];
    }

    // Check notes
    final oldNotes = oldValue['notes']?.toString().trim() ?? '';
    final newNotes = newValue['notes']?.toString().trim() ?? '';
    if (oldNotes != newNotes && (oldNotes.isNotEmpty || newNotes.isNotEmpty)) {
      changes['Notes'] = [
        oldNotes.isEmpty ? '(empty)' : oldNotes,
        newNotes.isEmpty ? '(empty)' : newNotes
      ];
    }

    // Check payment_method
    final oldPaymentMethod = oldValue['payment_method']?.toString().trim() ?? '';
    final newPaymentMethod = newValue['payment_method']?.toString().trim() ?? '';
    if (oldPaymentMethod != newPaymentMethod && (oldPaymentMethod.isNotEmpty || newPaymentMethod.isNotEmpty)) {
      changes['Payment Method'] = [
        oldPaymentMethod.isEmpty ? '(empty)' : oldPaymentMethod,
        newPaymentMethod.isEmpty ? '(empty)' : newPaymentMethod
      ];
    }

    // Check is_uncle
    final oldIsUncle = oldValue['is_uncle']?.toString() ?? 'false';
    final newIsUncle = newValue['is_uncle']?.toString() ?? 'false';
    if (oldIsUncle != newIsUncle) {
      changes['Uncle'] = [
        oldIsUncle == 'true' ? 'Yes' : 'No',
        newIsUncle == 'true' ? 'Yes' : 'No'
      ];
    }

    // Check Person 1 - Name
    String oldP1Name = '';
    String newP1Name = '';

    if (oldValue['persons'] != null && oldValue['persons'] is List && (oldValue['persons'] as List).isNotEmpty) {
      oldP1Name = oldValue['persons'][0]['name']?.toString().trim() ?? '';
    }
    if (newValue['persons'] != null && newValue['persons'] is List && (newValue['persons'] as List).isNotEmpty) {
      newP1Name = newValue['persons'][0]['name']?.toString().trim() ?? '';
    }

    if (oldP1Name != newP1Name && (oldP1Name.isNotEmpty || newP1Name.isNotEmpty)) {
      changes['Person 1 - Name'] = [
        oldP1Name.isEmpty ? '(empty)' : oldP1Name,
        newP1Name.isEmpty ? '(empty)' : newP1Name
      ];
    }

    // Check Person 1 - Job
    String oldP1Job = '';
    String newP1Job = '';

    if (oldValue['persons'] != null && oldValue['persons'] is List && (oldValue['persons'] as List).isNotEmpty) {
      oldP1Job = oldValue['persons'][0]['job']?.toString().trim() ?? '';
    }
    if (newValue['persons'] != null && newValue['persons'] is List && (newValue['persons'] as List).isNotEmpty) {
      newP1Job = newValue['persons'][0]['job']?.toString().trim() ?? '';
    }

    if (oldP1Job != newP1Job && (oldP1Job.isNotEmpty || newP1Job.isNotEmpty)) {
      changes['Person 1 - Job'] = [
        oldP1Job.isEmpty ? '(empty)' : oldP1Job,
        newP1Job.isEmpty ? '(empty)' : newP1Job
      ];
    }

    // Check Person 2 - Details
    String oldP2Details = '';
    String newP2Details = '';

    if (oldValue['persons'] != null && oldValue['persons'] is List && (oldValue['persons'] as List).length > 1) {
      oldP2Details = oldValue['persons'][1]['details']?.toString().trim() ?? '';
    }
    if (newValue['persons'] != null && newValue['persons'] is List && (newValue['persons'] as List).length > 1) {
      newP2Details = newValue['persons'][1]['details']?.toString().trim() ?? '';
    }

    if (oldP2Details != newP2Details && (oldP2Details.isNotEmpty || newP2Details.isNotEmpty)) {
      changes['Person 2 - Details'] = [
        oldP2Details.isEmpty ? '(empty)' : oldP2Details,
        newP2Details.isEmpty ? '(empty)' : newP2Details
      ];
    }

    return changes;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Modified Report',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.grey[300],
            height: 1,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF4CAF50),
        ),
      )
          : _modifiedEntries.isEmpty
          ? _buildEmptyState()
          : Column(
        children: [
          // Search Box and Summary in scrollable area
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Summary Card
                _buildSummaryCard(),
                const SizedBox(height: 16),

                // Search Box
                _buildSearchBox(),
                const SizedBox(height: 16),

                // Modified Entries List
                ..._filteredEntries.map((entry) {
                  final entryId = entry['id'];
                  final isExpanded = _expandedCards[entryId] ?? false;
                  return _buildModernCard(entry, isExpanded, entryId);
                }).toList(),

                // Show "No results" message if filtered list is empty
                if (_filteredEntries.isEmpty && _searchQuery.isNotEmpty)
                  _buildNoResultsWidget(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by name, serial no, or village...',
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear, color: Colors.grey[600]),
            onPressed: () {
              _searchController.clear();
            },
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildNoResultsWidget() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try searching with different keywords',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Modified Entries',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All entries are in their original state',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.edit_note,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total Modified Entries',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_modifiedEntries.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_searchQuery.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Showing ${_filteredEntries.length} results',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
  Widget _buildModernCard(Map<String, dynamic> entry, bool isExpanded, String entryId) {
    final serialNo = entry['serial_no']?.toString() ?? 'N/A';
    final personName = _getPersonName(entry['persons']);
    final changeHistory = _getChangeHistory(entry['old_data']);

    final currentValues = {
      'village_name': entry['village_name'],
      'living_place': entry['living_place'],
      'amount': entry['amount'],
      'persons': entry['persons'],
      'phone': entry['phone'],
      'notes': entry['notes'],
      'payment_method': entry['payment_method'],
      'is_uncle': entry['is_uncle'],
    };

    // FIX: Get the FIRST (oldest) snapshot to compare with current
    Map<String, dynamic> oldestValues = changeHistory.isNotEmpty
        ? changeHistory.first  // Changed from .last to .first
        : {};

    // This now shows ALL changed fields from original to current
    final changedFields = _getChangedFields(oldestValues, currentValues);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _expandedCards[entryId] = !isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'O$serialNo',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4CAF50),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          personName.isEmpty ? 'No Name' : personName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.edit, size: 16, color: Colors.orange[700]),
                            const SizedBox(width: 6),
                            Text(
                              'Modified Fields',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: changedFields.keys.map((field) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.orange[300]!),
                              ),
                              child: Text(
                                field,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange[800],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) _buildExpandedHistory(changeHistory, currentValues),
        ],
      ),
    );
  }

  Widget _buildExpandedHistory(List<Map<String, dynamic>> history, Map<String, dynamic> currentValues) {
    if (history.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
        ),
        child: const Center(
          child: Text(
            'No change history available',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[700],
            ),
            child: Row(
              children: const [
                Icon(Icons.history, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  'Change History',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),

            // ✅ EXCLUDE LAST CHANGE
            itemCount: history.length > 1 ? history.length - 1 : 0,

            itemBuilder: (context, index) {
              final oldSnapshot = history[index];
              final newSnapshot = history[index + 1];

              final changes = _getChangedFields(oldSnapshot, newSnapshot);
              final changeNumber = index + 1;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[700],
                        borderRadius: BorderRadius.circular(12),
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
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.key,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.red[50],
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.red[200]!),
                                    ),
                                    child: Text(
                                      entry.value[0].isEmpty ? '(empty)' : entry.value[0],
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Icon(
                                    Icons.arrow_forward,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.green[200]!),
                                    ),
                                    child: Text(
                                      entry.value[1].isEmpty ? '(empty)' : entry.value[1],
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.green,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}