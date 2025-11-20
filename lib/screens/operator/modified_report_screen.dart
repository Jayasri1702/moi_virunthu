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
            phone,
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
      'amount': entry['amount'],
      'persons': entry['persons'],
      'phone': entry['phone'],
    };

    Map<String, dynamic> latestOldValues = changeHistory.isNotEmpty
        ? changeHistory.last
        : {};

    final changedFields = _getChangedFields(latestOldValues, currentValues);

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
            itemCount: history.length,
            itemBuilder: (context, index) {
              final oldSnapshot = history[index];
              final newSnapshot = index < history.length - 1
                  ? history[index + 1]
                  : currentValues;

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