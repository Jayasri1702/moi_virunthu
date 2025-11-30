import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/network_utils.dart';

class CorrectVillageNamesScreen extends StatefulWidget {
  const CorrectVillageNamesScreen({super.key});

  @override
  State<CorrectVillageNamesScreen> createState() => _CorrectVillageNamesScreenState();
}

class _CorrectVillageNamesScreenState extends State<CorrectVillageNamesScreen> {
  final _searchController = TextEditingController();
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _villages = [];
  List<Map<String, dynamic>> _filteredVillages = [];
  int _totalCities = 0;
  int _totalPersons = 0;
  bool _isLoading = false;

  // Map to track renamed values: original_name -> new_name
  final Map<String, TextEditingController> _renameControllers = {};

  // Store last saved state to compare for changes
  final Map<String, String> _lastSavedState = {};

  @override
  void initState() {
    super.initState();
    _loadVillageData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    // Dispose all rename controllers
    for (var controller in _renameControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadVillageData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch all non-deleted mois records with village names
      final response = await _supabase
          .from('mois')
          .select('village_name')
          .eq('is_deleted', false)
          .not('village_name', 'is', null);

      if (response == null || response.isEmpty) {
        setState(() {
          _villages = [];
          _filteredVillages = [];
          _totalCities = 0;
          _totalPersons = 0;
          _isLoading = false;
        });
        return;
      }

      // Group by village_name and count occurrences
      final Map<String, int> villageCounts = {};
      int totalPersons = 0;

      for (var record in response) {
        final villageName = record['village_name'] as String?;
        if (villageName != null && villageName.isNotEmpty) {
          villageCounts[villageName] = (villageCounts[villageName] ?? 0) + 1;
          totalPersons++;
        }
      }

      // Convert to list format
      final villageList = villageCounts.entries.map((entry) {
        // Create a text controller for each village
        final controller = TextEditingController(text: entry.key);
        _renameControllers[entry.key] = controller;

        // Store the last saved state (initially same as current)
        _lastSavedState[entry.key] = entry.key;

        return {
          'city': entry.key,
          'relations': entry.value,
          'original_name': entry.key,
        };
      }).toList();

      // Sort by village name
      villageList.sort((a, b) =>
          (a['city'] as String).compareTo(b['city'] as String));

      setState(() {
        _villages = villageList;
        _filteredVillages = List.from(villageList);
        _totalCities = villageList.length;
        _totalPersons = totalPersons;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          onRetry: _loadVillageData,
          customMessage: 'Error loading village data',
        );
      }
    }
  }

  void _filterVillages(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredVillages = List.from(_villages);
      } else {
        _filteredVillages = _villages.where((village) {
          final city = village['city'].toString().toLowerCase();
          final searchLower = query.toLowerCase();
          return city.contains(searchLower);
        }).toList();
      }
    });
  }

  Future<void> _updateVillageNames() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Collect all the changes
      final List<Map<String, String>> changes = [];

      for (var village in _villages) {
        final originalName = village['original_name'] as String;
        final controller = _renameControllers[originalName];
        final newName = controller?.text.trim() ?? '';

        if (newName.isNotEmpty && newName != originalName) {
          changes.add({
            'old': originalName,
            'new': newName,
          });
        }
      }

      if (changes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No changes to update'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Update each village name in the database
      for (var change in changes) {
        final oldName = change['old']!;
        final newName = change['new']!;

        await _supabase
            .from('mois')
            .update({'village_name': newName})
            .eq('village_name', oldName)
            .eq('is_deleted', false);

        // Update the last saved state
        _lastSavedState[oldName] = newName;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully updated ${changes.length} village name(s)!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reload the data
      await _loadVillageData();
    } catch (e) {
      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          onRetry: _updateVillageNames,
          customMessage: 'Error updating village names',
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _filteredVillages = List.from(_villages);
    });
  }

  void _resetToOriginalNames() {
    // Check if there are any unsaved changes
    bool hasChanges = false;

    for (var village in _villages) {
      final originalName = village['original_name'] as String;
      final controller = _renameControllers[originalName];
      final lastSaved = _lastSavedState[originalName] ?? originalName;

      if (controller != null && controller.text.trim() != lastSaved) {
        hasChanges = true;
        break;
      }
    }

    if (!hasChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No changes to reset'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Reset all text controllers to last saved state (not original)
    for (var village in _villages) {
      final originalName = village['original_name'] as String;
      final controller = _renameControllers[originalName];
      final lastSaved = _lastSavedState[originalName] ?? originalName;

      if (controller != null) {
        controller.text = lastSaved;
      }
    }

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Changes have been reset'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: const Color(0xFF7B3F8F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'CITY RENAME',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Header Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: const Text(
                  'Correct Village Names',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // Search Bar
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.white,
                child: TextField(
                  controller: _searchController,
                  onChanged: _filterVillages,
                  decoration: InputDecoration(
                    hintText: 'Type To Search City',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: _clearSearch,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: Color(0xFF7B3F8F), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),

              // Table Header
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    _buildTableHeader('City', flex: 3),
                    _buildTableHeader('Rel', flex: 2),
                    _buildTableHeader('Rename', flex: 4),
                  ],
                ),
              ),

              // Table Body
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: _filteredVillages.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_city, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          _isLoading ? 'Loading village data...' : 'No village data available',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (!_isLoading) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Data will be loaded from database',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                      : ListView.builder(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: _filteredVillages.length,
                    itemBuilder: (context, index) {
                      final village = _filteredVillages[index];
                      final originalName = village['original_name'] as String;
                      final controller = _renameControllers[originalName];

                      return _buildTableRow(
                        village['city'] ?? '',
                        village['relations']?.toString() ?? '0',
                        controller,
                        index,
                      );
                    },
                  ),
                ),
              ),

              // Footer with totals
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Colors.grey[300]!, width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Total City ',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$_totalCities',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Text(
                      'Total Persons ',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$_totalPersons',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Action Buttons
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _updateVillageNames,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD946A6),
                            foregroundColor: Colors.white,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                            elevation: 0,
                            disabledBackgroundColor: Colors.grey[300],
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: const Text(
                              'UPDATE',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : _resetToOriginalNames,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            side: BorderSide(color: Colors.grey[400]!, width: 1),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                          child: const Text(
                            'Clear',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            side: BorderSide(color: Colors.grey[400]!, width: 1),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                          child: const Text(
                            'Exit',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF7B3F8F),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String title, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: Colors.grey[300]!, width: 1),
          ),
        ),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          textAlign: title == 'Rel' ? TextAlign.center : TextAlign.left,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildTableRow(
      String city,
      String relations,
      TextEditingController? controller,
      int index,
      ) {
    final isEven = index % 2 == 0;
    return Container(
      decoration: BoxDecoration(
        color: isEven ? Colors.grey[50] : Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // City
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Colors.grey[300]!, width: 1),
                  ),
                ),
                child: Text(
                  city,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            // Relations
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Colors.grey[300]!, width: 1),
                  ),
                ),
                child: Text(
                  relations,
                  style: const TextStyle(fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            // Rename
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'Enter new name',
                    hintStyle: TextStyle(fontSize: 11, color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: Color(0xFF7B3F8F), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}