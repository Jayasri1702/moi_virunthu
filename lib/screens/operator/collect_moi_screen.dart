import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/moi_receipt_generator.dart';
import 'package:flutter/services.dart';

class CollectMoiScreen extends StatefulWidget {
  const CollectMoiScreen({super.key});

  @override
  State<CollectMoiScreen> createState() => _CollectMoiScreenState();
}

class _CollectMoiScreenState extends State<CollectMoiScreen> {
  final _supabase = Supabase.instance.client;

  // Controllers
  final _phoneController = TextEditingController();
  final _phoneFocusNode = FocusNode(); // ✅ ADD THIS
  final _villageController = TextEditingController();
  final _livingPlaceController = TextEditingController();
  final _notesController = TextEditingController();
  final _amountController = TextEditingController();

  // Person 1 controllers (2 fields now)
  final _person1Field1Controller = TextEditingController(); // Init + Name
  final _person1Field2Controller = TextEditingController(); // Education + Job

  // Person 2 controller (combined)
  final _person2Controller = TextEditingController();

  // Denomination controllers with dropdown support
  final List<Map<String, dynamic>> _denomRows = [];

  // State variables
  String? _eventId;
  String? _operatorId;
  int? _serialNo;
  String _paymentMethod = 'CASH';
  bool _isUncle = false;
  bool _isLoading = true;

  // Edit mode variables
  bool _isEditMode = false;
  String? _editingMoiId;
  int? _currentGroupId;
  List<Map<String, dynamic>> _groupedMois = [];
  Map<String, dynamic>? _originalData;
  // Store the original auto-filled data to track changes
  Map<String, dynamic>? _autoFilledData;

  @override
  void initState() {
    super.initState();
    _initializeDenominations();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading) {
      _loadArguments();
    }
  }

  void _initializeDenominations() {
    _denomRows.add({
      'selectedDenom': null, // Empty by default
      'countController': TextEditingController(),
      'denomController': TextEditingController(), // For user input
    });

    _denomRows[0]['countController'].addListener(_onDenomCountChanged);
  }

  void _onDenomCountChanged() {
    if (_paymentMethod == 'CASH') {
      setState(() {
        _updateDenominationRows();
      });
    }
  }

  void _updateDenominationRows() {
    if (_denomRows.isEmpty) return;

    final lastRow = _denomRows[_denomRows.length - 1];
    final count = int.tryParse(lastRow['countController'].text) ?? 0;
    final selectedDenom = lastRow['selectedDenom'];

    // If last row has denomination and count entered, add new empty row
    if (count != 0 && selectedDenom != null) {
      final controller = TextEditingController();
      controller.addListener(_onDenomCountChanged);

      setState(() {
        _denomRows.add({
          'selectedDenom': null,
          'countController': controller,
          'denomController': TextEditingController(),
        });
      });
    }
  }

  Future<void> _loadArguments() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map<String, dynamic>) {
      _eventId = args['id'];
      _operatorId = args['operator_id'];

      if (args['edit_mode'] == true && args['moi_data'] != null) {
        _isEditMode = true;
        final moiData = args['moi_data'] as Map<String, dynamic>;
        await _loadEditData(moiData);
      } else {
        await _loadNextSerialNo();
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadEditData(Map<String, dynamic> moiData) async {
    _originalData = Map<String, dynamic>.from(moiData);

    setState(() {
      _editingMoiId = moiData['id'];
      _serialNo = moiData['serial_no'];
      _phoneController.text = moiData['phone'] ?? '';
      _villageController.text = moiData['village_name'] ?? '';
      _livingPlaceController.text = moiData['living_place'] ?? '';
      _notesController.text = moiData['notes'] ?? '';
      _paymentMethod = moiData['payment_method'] ?? 'CASH';
      _isUncle = moiData['is_uncle'] ?? false;
      _currentGroupId = moiData['group_id'];

      if (moiData['persons'] != null) {
        List<dynamic> personsList = moiData['persons'] as List;
        if (personsList.isNotEmpty) {
          var person1 = personsList[0];
          _person1Field1Controller.text = person1['name'] ?? '';
          _person1Field2Controller.text = person1['job'] ?? '';
        }
        if (personsList.length > 1) {
          var person2 = personsList[1];
          _person2Controller.text = person2['details'] ?? '';
        }
      }

      var amountValue = moiData['amount'];
      if (amountValue != null) {
        if (amountValue is double) {
          _amountController.text = amountValue.toInt().toString();
        } else {
          _amountController.text = amountValue.toString();
        }
      } else {
        _amountController.text = '0';
      }

    });

    if (_currentGroupId != null) {
      await _loadGroupedMois();
    }

    if (_paymentMethod == 'CASH') {
      await _loadDenominations(moiData['id']);
    }
  }

  Future<void> _loadDenominations(String moiId) async {
    try {
      final response = await _supabase
          .from('moi_denominations')
          .select('*')
          .eq('moi_id', moiId)
          .maybeSingle();

      if (response != null) {
        // Clear existing rows
        for (var row in _denomRows) {
          row['countController'].dispose();
          if (row.containsKey('denomController')) {
            row['denomController'].dispose();
          }
        }
        _denomRows.clear();

        // Reconstruct denomination rows from saved data
        Map<int, int> savedDenoms = {
          500: response['denom_500'] ?? 0,
          200: response['denom_200'] ?? 0,
          100: response['denom_100'] ?? 0,
          50: response['denom_50'] ?? 0,
          20: response['denom_20'] ?? 0,
          10: response['denom_10'] ?? 0,
          5: response['denom_5'] ?? 0,
          1: response['denom_1'] ?? 0,
        };

        // ✅ Add rows for ALL denominations (positive AND negative)
        savedDenoms.forEach((denom, count) {
          if (count != 0) { // ✅ Changed from count > 0 to count != 0
            final countController = TextEditingController(text: count.toString());
            countController.addListener(_onDenomCountChanged);

            final denomController = TextEditingController(text: denom.toString());

            _denomRows.add({
              'selectedDenom': denom,
              'countController': countController,
              'denomController': denomController,
            });
          }
        });

        // If no denominations saved, initialize with default empty row
        if (_denomRows.isEmpty) {
          _initializeDenominations();
        }

        setState(() {});
      }
    } catch (e) {
      print('Error loading denominations: $e');
    }
  }

  Future<void> _loadGroupedMois() async {
    if (_currentGroupId == null) return;

    try {
      final response = await _supabase
          .from('mois')
          .select('*')
          .eq('event_id', _eventId!)
          .eq('group_id', _currentGroupId!)
          .eq('is_deleted', false)
          .order('created_at', ascending: true);

      setState(() {
        _groupedMois = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error loading grouped MOIs: $e');
    }
  }

  Future<void> _loadGroupedEntryForEdit(Map<String, dynamic> moiData) async {
    _originalData = Map<String, dynamic>.from(moiData);

    setState(() {
      _editingMoiId = moiData['id'];
      _serialNo = moiData['serial_no'];
      _phoneController.text = moiData['phone'] ?? '';
      _villageController.text = moiData['village_name'] ?? '';
      _livingPlaceController.text = moiData['living_place'] ?? '';
      _notesController.text = moiData['notes'] ?? '';
      _paymentMethod = moiData['payment_method'] ?? 'CASH';
      _isUncle = moiData['is_uncle'] ?? false;
      _isEditMode = true;

      if (moiData['persons'] != null) {
        List<dynamic> personsList = moiData['persons'] as List;
        if (personsList.isNotEmpty) {
          var person1 = personsList[0];
          _person1Field1Controller.text = person1['name'] ?? '';
          _person1Field2Controller.text = person1['job'] ?? '';
        }
        if (personsList.length > 1) {
          var person2 = personsList[1];
          _person2Controller.text = person2['details'] ?? '';
        }
      }
      var amountValue = moiData['amount'];
      if (amountValue != null) {
        if (amountValue is double) {
          _amountController.text = amountValue.toInt().toString();
        } else {
          _amountController.text = amountValue.toString();
        }
      } else {
        _amountController.text = '0';
      }
    });

    if (_paymentMethod == 'CASH') {
      await _loadDenominations(moiData['id']);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entry loaded for editing. Make changes and click "Save & Print"'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _loadNextSerialNo() async {
    if (_eventId == null) return;

    try {
      // ✅ FIXED: Get highest serial number for the EVENT (not operator-specific)
      final response = await _supabase
          .from('mois')
          .select('serial_no')
          .eq('event_id', _eventId!)
          .eq('is_deleted', false)
          .order('serial_no', ascending: false)
          .limit(1)
          .maybeSingle();

      setState(() {
        _serialNo = (response != null && response['serial_no'] != null)
            ? (response['serial_no'] as int) + 1
            : 1;
      });
    } catch (e) {
      print('Error loading serial number: $e');
      setState(() {
        _serialNo = 1;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _checkExistingEntry() async {
    try {
      // Get the values to check
      String villageName = _villageController.text.trim();
      int amount = _paymentMethod == 'CASH' ? _getTotalAmount() : int.tryParse(_amountController.text) ?? 0;

      // Parse Person 1 name
      String person1Name = _person1Field1Controller.text.trim();

// Parse Person 1 job
      String person1Job = _person1Field2Controller.text.trim();

// Parse Person 2 details
      String person2Details = _person2Controller.text.trim();

      // Query all entries for this event (not deleted)
      final response = await _supabase
          .from('mois')
          .select('*')
          .eq('event_id', _eventId!)
          .eq('is_deleted', false);

      List<Map<String, dynamic>> matchingEntries = [];

      // Check each entry for matches
      for (var entry in response) {
        // Check village name
        String entryVillage = entry['village_name'] ?? '';
        if (entryVillage.toLowerCase() != villageName.toLowerCase()) continue;

        // Check amount
        var entryAmount = entry['amount'];
        int entryAmountInt = 0;
        if (entryAmount is int) {
          entryAmountInt = entryAmount;
        } else if (entryAmount is double) {
          entryAmountInt = entryAmount.toInt();
        }
        if (entryAmountInt != amount) continue;

        // Check persons
        // Check persons
        if (entry['persons'] != null) {
          List<dynamic> personsList = entry['persons'] as List;

          // Check Person 1 name and job
          if (personsList.isNotEmpty) {
            var p1 = personsList[0];
            String entryP1Name = p1['name'] ?? '';
            String entryP1Job = p1['job'] ?? '';

            if (entryP1Name.toLowerCase() != person1Name.toLowerCase()) continue;
            if (person1Job.isNotEmpty && entryP1Job.toLowerCase() != person1Job.toLowerCase()) continue;
          }

          // Check Person 2 details
          if (person2Details.isNotEmpty && personsList.length > 1) {
            var p2 = personsList[1];
            String entryP2Details = p2['details'] ?? '';

            if (entryP2Details.toLowerCase() != person2Details.toLowerCase()) continue;
          }
        }

        // If we reach here, all fields match
        matchingEntries.add(entry);
      }

      return matchingEntries;
    } catch (e) {
      print('Error checking existing entry: $e');
      return [];
    }
  }

  Future<bool> _showExistingEntryDialog(List<Map<String, dynamic>> existingEntries) async {
    String serialNumbers = existingEntries.map((e) => 'O${e['serial_no']}').join(', ');

    // Build the complete data display
    String entryDetails = '';
    if (existingEntries.isNotEmpty) {
      var entry = existingEntries[0];

      // Show ALL fields
      entryDetails += '📍 Village: ${entry['village_name'] ?? 'N/A'}\n';
      entryDetails += '🏙️ Living Place: ${entry['living_place'] ?? 'N/A'}\n';
      entryDetails += '📞 Phone: ${entry['phone'] ?? 'N/A'}\n';
      entryDetails += '💰 Amount: ₹${entry['amount']}\n';
      entryDetails += '💳 Payment: ${entry['payment_method'] ?? 'N/A'}\n';
      entryDetails += '👤 Uncle: ${(entry['is_uncle'] ?? false) ? 'Yes' : 'No'}\n';

      if (entry['persons'] != null) {
        List<dynamic> personsList = entry['persons'] as List;
        if (personsList.isNotEmpty) {
          var p1 = personsList[0];
          entryDetails += '\n👤 Person 1:\n';
          entryDetails += '  Name: ${p1['name'] ?? 'N/A'}\n';
          entryDetails += '  Job: ${p1['job'] ?? 'N/A'}\n';
        }
        if (personsList.length > 1) {
          var p2 = personsList[1];
          entryDetails += '\n👤 Person 2:\n';
          entryDetails += '  Details: ${p2['details'] ?? 'N/A'}\n';
        }
      }

      if (entry['notes'] != null && entry['notes'].toString().isNotEmpty) {
        entryDetails += '\n📝 Notes: ${entry['notes']}\n';
      }
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          '⚠️ Entry Already Exists!',
          style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(  // Added ScrollView for long content
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This entry already exists in Serial No: $serialNumbers',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Existing Entry Details:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, decoration: TextDecoration.underline),
              ),
              const SizedBox(height: 8),
              Text(
                entryDetails,
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 12),
              const Text(
                'Do you want to proceed anyway?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              backgroundColor: Colors.red[100],
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              'DISCARD',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              backgroundColor: Colors.green[100],
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              'PROCEED',
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _autoFillFromPhoneNumber(String phoneNumber) async {
    if (phoneNumber.trim().isEmpty || phoneNumber.length != 10) return;

    try {
      // Search for the most recent entry with this phone number from ANY event
      final response = await _supabase
          .from('mois')
          .select('*')
          .eq('phone', phoneNumber.trim())
          .eq('is_deleted', false)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        // Store the auto-filled data for comparison later
        _autoFilledData = {
          'living_place': response['living_place'],
          'village_name': response['village_name'],
          'persons': response['persons'],
        };

        setState(() {
          // Fill living place and village
          if (response['living_place'] != null) {
            _livingPlaceController.text = response['living_place'];
          }
          if (response['village_name'] != null) {
            _villageController.text = response['village_name'];
          }

          // Fill person 1 details
          if (response['persons'] != null) {
            List<dynamic> personsList = response['persons'] as List;

            if (personsList.isNotEmpty) {
              var person1 = personsList[0];
              _person1Field1Controller.text = person1['name'] ?? '';
              _person1Field2Controller.text = person1['job'] ?? '';
            }

            if (personsList.length > 1) {
              var person2 = personsList[1];
              _person2Controller.text = person2['details'] ?? '';
            }
          }
        });
      }
    } catch (e) {
      print('Error auto-filling from phone number: $e');
    }
  }

  // Check if auto-filled data was modified
  bool _hasAutoFilledDataChanged() {
    if (_autoFilledData == null) return false;

    // Check if living place changed
    String currentLivingPlace = _livingPlaceController.text.trim();
    String originalLivingPlace = _autoFilledData!['living_place'] ?? '';
    if (currentLivingPlace != originalLivingPlace) return true;

    // Check if village name changed
    String currentVillage = _villageController.text.trim();
    String originalVillage = _autoFilledData!['village_name'] ?? '';
    if (currentVillage != originalVillage) return true;

    // Check if person data changed
    if (_autoFilledData!['persons'] != null) {
      List<dynamic> originalPersons = _autoFilledData!['persons'] as List;

      if (originalPersons.isNotEmpty) {
        var origP1 = originalPersons[0];
        String origP1Name = origP1['name'] ?? '';
        String origP1Job = origP1['job'] ?? '';

        if (_person1Field1Controller.text.trim() != origP1Name) return true;
        if (_person1Field2Controller.text.trim() != origP1Job) return true;
      }

      if (originalPersons.length > 1) {
        var origP2 = originalPersons[1];
        String origP2Details = origP2['details'] ?? '';

        if (_person2Controller.text.trim() != origP2Details) return true;
      }
    }

    return false;
  }

  Future<void> _updateAllEntriesWithPhoneNumber(String phoneNumber) async {
    try {
      // Build persons data
      List<Map<String, dynamic>> personsData = [];
      if (_person1Field1Controller.text.trim().isNotEmpty || _person1Field2Controller.text.trim().isNotEmpty) {
        personsData.add({
          'name': _person1Field1Controller.text.trim(),
          'job': _person1Field2Controller.text.trim(),
        });
      }
      if (_person2Controller.text.trim().isNotEmpty) {
        personsData.add({
          'details': _person2Controller.text.trim(),
        });
      }

      // Update all entries with this phone number
      final updateData = {
        'living_place': _livingPlaceController.text.trim().isEmpty ? null : _livingPlaceController.text.trim(),
        'village_name': _villageController.text.trim().isEmpty ? null : _villageController.text.trim(),
        'persons': personsData,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase
          .from('mois')
          .update(updateData)
          .eq('phone', phoneNumber)
          .eq('is_deleted', false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ All entries with this phone number have been updated!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Error updating entries: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating entries: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  Future<bool> _showGlobalUpdateConfirmation(String phoneNumber) async {
    // Count how many entries will be affected
    int affectedCount = 0;
    try {
      final response = await _supabase
          .from('mois')
          .select('id')
          .eq('phone', phoneNumber)
          .eq('is_deleted', false);

      affectedCount = response.length;
    } catch (e) {
      print('Error counting entries: $e');
    }

    if (affectedCount <= 1) {
      // Only current entry, no need to update globally
      return false;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          '📝 Update All Entries?',
          style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have modified the auto-filled details for phone number: $phoneNumber',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                border: Border.all(color: Colors.orange, width: 2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ This will affect $affectedCount existing entries with this phone number!',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Fields that will be updated:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text('• Village Name', style: TextStyle(fontSize: 11)),
                  const Text('• Living Place', style: TextStyle(fontSize: 11)),
                  const Text('• Person Details', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Do you want to update all existing entries with this phone number?',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              backgroundColor: Colors.grey[200],
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              'NO, ONLY THIS ENTRY',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              backgroundColor: Colors.blue[100],
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              'YES, UPDATE ALL',
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  int _getTotalAmount() {
    if (_paymentMethod == 'CASH') {
      int total = 0;
      for (var row in _denomRows) {
        int? denom = row['selectedDenom']; // ✅ Can be null now
        int count = int.tryParse(row['countController'].text) ?? 0;

        // ✅ Only calculate if denomination is selected
        if (denom != null && count != 0) {
          total += denom * count;
        }
      }
      return total;
    } else {
      String amountText = _amountController.text.trim();
      if (amountText.isEmpty) return 0;
      double? doubleValue = double.tryParse(amountText);
      if (doubleValue != null) {
        return doubleValue.round();
      }
      return 0;
    }
  }

  int _getTotalCount() {
    int count = 0;
    for (var row in _denomRows) {
      int rowCount = int.tryParse(row['countController'].text) ?? 0;
      int? denom = row['selectedDenom']; // ✅ Check denomination exists

      // ✅ Only count if denomination is selected and count is positive
      if (denom != null && rowCount > 0) {
        count += rowCount;
      }
    }
    return count;
  }

  Future<int> _getNextGroupId() async {
    try {
      final maxGroupResponse = await _supabase
          .from('mois')
          .select('group_id')
          .eq('event_id', _eventId!)
          .eq('is_deleted', false)
          .not('group_id', 'is', null)
          .order('group_id', ascending: false)
          .limit(1)
          .maybeSingle();

      return (maxGroupResponse != null && maxGroupResponse['group_id'] != null)
          ? (maxGroupResponse['group_id'] as int) + 1
          : 1;
    } catch (e) {
      print('Error getting next group ID: $e');
      return 1;
    }
  }

  Future<void> _handleGroup() async {
    if (!await _validateForm()) return; // ✅ Add await

    // CASE 1: Editing an existing entry that's ALREADY in a group
    if (_isEditMode && _editingMoiId != null && _currentGroupId != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This entry is already in a group! Use "Save & Print" to update it, or click "Add Entry" to add a new entry to the group.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // CASE 2: Editing an existing standalone entry (not in group) - Convert to group
    if (_isEditMode && _editingMoiId != null && _currentGroupId == null) {
      try {
        int groupId = await _getNextGroupId();

        final moiData = {
          'group_id': groupId,
          'updated_at': DateTime.now().toIso8601String(),
          'old_data': _originalData,
        };

        await _supabase
            .from('mois')
            .update(moiData)
            .eq('id', _editingMoiId!);

        setState(() {
          _currentGroupId = groupId;
        });

        await _loadGroupedMois();
        await _clearFormForNextEntry();
        _phoneFocusNode.requestFocus(); // ✅ ADD THIS

        return;
      } catch (e) {
        print('Error converting to group: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
        return;
      }
    }

    // CASE 3: Adding a NEW entry to an existing or new group
    try {
      // CHECK FOR EXISTING ENTRY FIRST
      final existingEntries = await _checkExistingEntry();

      if (existingEntries.isNotEmpty) {
        final shouldProceed = await _showExistingEntryDialog(existingEntries);

        if (!shouldProceed) {
          // User chose DISCARD - clear the form
          _handleClear();
          return;
        }
      }

      await _loadNextSerialNo();

      int groupId;
      if (_currentGroupId != null) {
        groupId = _currentGroupId!;
      } else {
        groupId = await _getNextGroupId();
      }

      final moiId = await _saveMoi(groupId, forceUpdate: false);

      if (moiId != null) {
        setState(() {
          _currentGroupId = groupId;
        });

        await _loadGroupedMois();
        await _clearFormForNextEntry();
        _phoneFocusNode.requestFocus(); // ✅ ADD THIS

      }
    } catch (e) {
      print('Error in group operation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<String?> _saveMoi(int? groupId, {bool forceUpdate = false}) async {
    List<Map<String, dynamic>> personsData = [];

// Parse Person 1
    if (_person1Field1Controller.text.trim().isNotEmpty || _person1Field2Controller.text.trim().isNotEmpty) {
      personsData.add({
        'name': _person1Field1Controller.text.trim(),
        'job': _person1Field2Controller.text.trim(),
      });
    }

// Parse Person 2
    if (_person2Controller.text.trim().isNotEmpty) {
      personsData.add({
        'details': _person2Controller.text.trim(),
      });
    }

    final moiData = {
      'event_id': _eventId,
      'operator_id': _operatorId,
      'serial_no': _serialNo,
      'amount': _paymentMethod == 'CASH' ? _getTotalAmount() : int.tryParse(_amountController.text) ?? 0,
      'payment_method': _paymentMethod,
      'persons': personsData,
      'village_name': _villageController.text.trim().isEmpty ? null : _villageController.text.trim(),
      'living_place': _livingPlaceController.text.trim().isEmpty ? null : _livingPlaceController.text.trim(),
      'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      'is_uncle': _isUncle,
      'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      'group_id': groupId,
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      dynamic response;
      String moiId;

      if (forceUpdate && _editingMoiId != null) {
        moiData['old_data'] = _originalData;

        response = await _supabase
            .from('mois')
            .update(moiData)
            .eq('id', _editingMoiId!)
            .select()
            .single();
        moiId = _editingMoiId!;

        print('Updated existing MOI: $moiId with serial_no: $_serialNo');
      } else {
        moiData['created_at'] = DateTime.now().toIso8601String();
        response = await _supabase
            .from('mois')
            .insert(moiData)
            .select()
            .single();
        moiId = response['id'];

        print('Inserted new MOI: $moiId with serial_no: $_serialNo');
      }

      await _saveDenominations(moiId);

      return moiId;
    } catch (e) {
      print('Error saving MOI: $e');
      rethrow;
    }
  }

  Future<void> _saveDenominations(String moiId) async {
    if (_paymentMethod != 'CASH') return;

    // Build denomination data from rows
    Map<String, dynamic> denomData = {
      'moi_id': moiId,
      'event_id': _eventId!,
      'operator_id': _operatorId!,
      'denom_500': 0,
      'denom_200': 0,
      'denom_100': 0,
      'denom_50': 0,
      'denom_20': 0,
      'denom_10': 0,
      'denom_5': 0,
      'denom_1': 0,
    };

    // ✅ ACCUMULATE counts for same denomination
    for (var row in _denomRows) {
      int? denom = row['selectedDenom'];
      int count = int.tryParse(row['countController'].text) ?? 0;

      if (denom != null && count != 0) {
        // ✅ Add to existing value instead of replacing
        denomData['denom_$denom'] = (denomData['denom_$denom'] as int) + count;
      }
    }

    await _supabase
        .from('moi_denominations')
        .upsert(denomData);
  }

  Future<void> _handleSaveAndPrint() async {
    if (!_isEditMode) {
      await _loadNextSerialNo();
    }

    // ✅ ADD THIS SECTION HERE - CHECK FOR GLOBAL UPDATE
    String phoneNumber = _phoneController.text.trim();
    if (phoneNumber.isNotEmpty && phoneNumber.length == 10 && _hasAutoFilledDataChanged()) {
      final shouldUpdateAll = await _showGlobalUpdateConfirmation(phoneNumber);

      if (shouldUpdateAll) {
        await _updateAllEntriesWithPhoneNumber(phoneNumber);
      }
    }
    // ✅ END OF NEW CODE

    // Auto-add to group if user forgot to click Group button
    if (_currentGroupId != null && _hasFormData() && !_isEditMode) {
      if (!await _validateForm()) return; // ✅ Add await

      try {
        await _saveMoi(_currentGroupId);
        await _loadGroupedMois();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Entry automatically added to group and saved!'),
              backgroundColor: Colors.green,
            ),
          );

          Navigator.pushReplacementNamed(
            context,
            '/operator/collection-details',
            arguments: {'id': _eventId, 'operator_id': _operatorId},
          );
        }
        return;
      } catch (e) {
        print('Error auto-saving to group: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
        return;
      }
    }

    // Handle grouped entries - UPDATE MODE
    if (_groupedMois.isNotEmpty) {
      if (_isEditMode && _editingMoiId != null) {
        if (!await _validateForm()) return; // ✅ Add await

        // ✅ ADD THIS CHECK HERE - Compare current data with original
        if (_hasNoChanges()) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No changes detected. Nothing to update.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }

        try {
          await _saveMoi(_currentGroupId, forceUpdate: true);
          await _loadGroupedMois();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Entry updated successfully!'),
                backgroundColor: Colors.green,
              ),
            );

            Navigator.pushReplacementNamed(
              context,
              '/operator/collection-details',
              arguments: {'id': _eventId, 'operator_id': _operatorId},
            );
          }
          return;
        } catch (e) {
          print('Error updating: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
            );
          }
          return;
        }
      }

      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/operator/collection-details',
          arguments: {'id': _eventId, 'operator_id': _operatorId},
        );
      }
      return;
    }

    // Regular save for single entry
    if (!await _validateForm()) return; // ✅ Add await

// CHECK FOR EXISTING ENTRY FIRST (only for new entries, not edit mode)
    if (!_isEditMode && _currentGroupId == null) {
      final existingEntries = await _checkExistingEntry();
      // ... existing code
    }

// ✅ ADD THIS CHECK HERE - For single MOI edit mode
    if (_isEditMode && _hasNoChanges()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No changes detected. Nothing to update.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      await _saveMoi(_currentGroupId, forceUpdate: _isEditMode);
      if (mounted) {

        if (_isEditMode) {
          Navigator.pushReplacementNamed(
            context,
            '/operator/collection-details',
            arguments: {'id': _eventId, 'operator_id': _operatorId},
          );
        } else {
          await _clearFormForNextEntry();
          _phoneFocusNode.requestFocus(); // ✅ ADD THIS
        }
      }
    } catch (e) {
      print('Error saving: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  bool _hasFormData() {
    return _person1Field1Controller.text.trim().isNotEmpty ||
        _person2Controller.text.trim().isNotEmpty ||
        _getTotalAmount() > 0;
  }

  bool _hasNoChanges() {
    if (_originalData == null || !_isEditMode) return false;

    // Compare all fields
    bool phoneChanged = (_originalData!['phone'] ?? '') != _phoneController.text.trim();
    bool villageChanged = (_originalData!['village_name'] ?? '') != _villageController.text.trim();
    bool livingPlaceChanged = (_originalData!['living_place'] ?? '') != _livingPlaceController.text.trim();
    bool notesChanged = (_originalData!['notes'] ?? '') != _notesController.text.trim();
    bool paymentMethodChanged = _originalData!['payment_method'] != _paymentMethod;
    bool isUncleChanged = (_originalData!['is_uncle'] ?? false) != _isUncle;

    // Compare amount
    var originalAmount = _originalData!['amount'];
    int currentAmount = _paymentMethod == 'CASH' ? _getTotalAmount() : int.tryParse(_amountController.text) ?? 0;
    bool amountChanged = originalAmount != currentAmount;

    // Compare persons
    bool personsChanged = false;
    if (_originalData!['persons'] != null) {
      List<dynamic> originalPersons = _originalData!['persons'] as List;

      String currentP1Name = _person1Field1Controller.text.trim();
      String currentP1Job = _person1Field2Controller.text.trim();
      String currentP2Details = _person2Controller.text.trim();

      String origP1Name = '';
      String origP1Job = '';
      String origP2Details = '';

      if (originalPersons.isNotEmpty) {
        origP1Name = originalPersons[0]['name'] ?? '';
        origP1Job = originalPersons[0]['job'] ?? '';
      }

      if (originalPersons.length > 1) {
        origP2Details = originalPersons[1]['details'] ?? '';
      }

      personsChanged = currentP1Name != origP1Name ||
          currentP1Job != origP1Job ||
          currentP2Details != origP2Details;
    } else {
      // If original had no persons but current has
      personsChanged = _person1Field1Controller.text.trim().isNotEmpty ||
          _person1Field2Controller.text.trim().isNotEmpty ||
          _person2Controller.text.trim().isNotEmpty;
    }

    // Return true if NO changes detected
    return !phoneChanged && !villageChanged && !livingPlaceChanged &&
        !notesChanged && !paymentMethodChanged && !isUncleChanged &&
        !amountChanged && !personsChanged;
  }

  // Update the _validateForm() method
  Future<bool> _validateForm() async {
    bool hasValidPerson = _person1Field1Controller.text.trim().isNotEmpty ||
        _person2Controller.text.trim().isNotEmpty;

    if (!hasValidPerson) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one person with a name')),
      );
      return false;
    }

    // Phone validation
    String phoneNumber = _phoneController.text.trim();
    if (phoneNumber.isNotEmpty) {
      if (phoneNumber.length != 10 || !RegExp(r'^\d{10}$').hasMatch(phoneNumber)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone number must be exactly 10 digits or leave it empty!'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        return false;
      }
    }

    // Validate negative denominations
    if (_paymentMethod == 'CASH') {
      for (var row in _denomRows) {
        int count = int.tryParse(row['countController'].text) ?? 0;
        int? denom = row['selectedDenom'];

        if (count < 0 && denom != null) {
          int available = await _getAvailableBalance(denom);

          if (count.abs() > available) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('₹$denom: Insufficient balance. Available: $available, Requested: ${count.abs()}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
            return false;
          }
        }
      }
    }

    // Phone number validation for edit mode (critical fields)
    if (_isEditMode) {
      bool isEditingCriticalFields = false;

      if (_originalData != null) {
        var originalAmount = _originalData!['amount'];
        int currentAmount = _paymentMethod == 'CASH' ? _getTotalAmount() : int.tryParse(_amountController.text) ?? 0;
        if (originalAmount != currentAmount) {
          isEditingCriticalFields = true;
        }

        if (_originalData!['payment_method'] != _paymentMethod) {
          isEditingCriticalFields = true;
        }

        if (_paymentMethod == 'CASH' && _originalData!['payment_method'] == 'CASH') {
          int currentDenomTotal = _getTotalAmount();
          if (originalAmount != currentDenomTotal) {
            isEditingCriticalFields = true;
          }
        }
      }

      if (isEditingCriticalFields) {
        String phoneNumber = _phoneController.text.trim();

        if (phoneNumber.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Phone number is mandatory when editing amount, payment method, or denominations!'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
          _phoneFocusNode.requestFocus();
          return false;
        }

        if (phoneNumber.length != 10 || !RegExp(r'^\d{10}$').hasMatch(phoneNumber)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Phone number must be exactly 10 digits!'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
          return false;
        }
      }
    }

    // Amount validation - ALWAYS mandatory regardless of CASH or OTHERS
    String enteredAmountText = _amountController.text.trim();
    if (enteredAmountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Amount is mandatory! Please enter the amount.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    }

    int enteredAmount = int.tryParse(enteredAmountText) ?? 0;
    if (enteredAmount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Amount cannot be zero!'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    }

    // CASH payment validation
    if (_paymentMethod == 'CASH') {
      int denomTotal = _getTotalAmount();

      if (denomTotal == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter denomination details')),
        );
        return false;
      }

      // Validate amount matches denomination
      if (denomTotal != enteredAmount) {
        int difference = enteredAmount - denomTotal;
        String message = difference > 0
            ? 'Amount is ₹$enteredAmount but denomination is ₹$denomTotal. ₹${difference.abs()} is missing!'
            : 'Amount is ₹$enteredAmount but denomination is ₹$denomTotal. ₹${difference.abs()} is extra!';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
        return false;
      }
    }

    return true;
  }

  Future<void> _clearFormForNextEntry() async {
    await _loadNextSerialNo();

    _phoneController.clear();
    _villageController.clear();
    _livingPlaceController.clear();
    _notesController.clear();
    _amountController.clear();

    _person1Field1Controller.clear();
    _person1Field2Controller.clear();
    _person2Controller.clear();

    // Clear denomination rows
    for (var row in _denomRows) {
      row['countController'].dispose();
    }
    _denomRows.clear();
    _initializeDenominations();

    setState(() {
      _paymentMethod = 'CASH';
      _isUncle = false;
      _isEditMode = false;
      _editingMoiId = null;
      _originalData = null;
    });
  }

  void _handleAddEntry() {
    _clearFormForNextEntry();
    _phoneFocusNode.requestFocus(); // ✅ ADD THIS

  }

  void _handleClear() async {
    setState(() {
      _phoneController.clear();
      _villageController.clear();
      _livingPlaceController.clear();
      _notesController.clear();
      _amountController.clear();
      _person1Field1Controller.clear();
      _person1Field2Controller.clear();
      _person2Controller.clear();

      for (var row in _denomRows) {
        row['countController'].dispose();
      }
      _denomRows.clear();
      _initializeDenominations();

      _paymentMethod = 'CASH';
      _isUncle = false;
      _currentGroupId = null;
      _groupedMois.clear();
      _isEditMode = false;
      _editingMoiId = null;
      _originalData = null;
    });
    await _loadNextSerialNo();
    _phoneFocusNode.requestFocus(); // ✅ ADD THIS LINE
  }

  // First, add this helper function to convert numbers to words at the top of your class (after the state variables)

  String _numberToWords(int number) {
    if (number == 0) return 'Zero';

    final ones = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine'];
    final teens = ['Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
    final tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

    String convertHundreds(int n) {
      if (n == 0) return '';
      if (n < 10) return ones[n];
      if (n < 20) return teens[n - 10];
      if (n < 100) {
        int tensDigit = n ~/ 10;
        int onesDigit = n % 10;
        return '${tens[tensDigit]} ${ones[onesDigit]}'.trim();
      }
      int hundreds = n ~/ 100;
      int remainder = n % 100;
      return '${ones[hundreds]} Hundred ${convertHundreds(remainder)}'.trim();
    }

    if (number < 0) return 'Minus ${_numberToWords(-number)}';
    if (number < 1000) return convertHundreds(number);

    // Handle thousands
    if (number < 100000) {
      int thousands = number ~/ 1000;
      int remainder = number % 1000;
      String result = '${convertHundreds(thousands)} Thousand';
      if (remainder > 0) result += ' ${convertHundreds(remainder)}';
      return result.trim();
    }

    // Handle lakhs
    if (number < 10000000) {
      int lakhs = number ~/ 100000;
      int remainder = number % 100000;
      String result = '${convertHundreds(lakhs)} Lakh';
      if (remainder >= 1000) {
        int thousands = remainder ~/ 1000;
        int finalRemainder = remainder % 1000;
        result += ' ${convertHundreds(thousands)} Thousand';
        if (finalRemainder > 0) result += ' ${convertHundreds(finalRemainder)}';
      } else if (remainder > 0) {
        result += ' ${convertHundreds(remainder)}';
      }
      return result.trim();
    }

    // Handle crores
    int crores = number ~/ 10000000;
    int remainder = number % 10000000;
    String result = '${convertHundreds(crores)} Crore';

    if (remainder >= 100000) {
      int lakhs = remainder ~/ 100000;
      int finalRemainder = remainder % 100000;
      result += ' ${convertHundreds(lakhs)} Lakh';
      if (finalRemainder >= 1000) {
        int thousands = finalRemainder ~/ 1000;
        int lastRemainder = finalRemainder % 1000;
        result += ' ${convertHundreds(thousands)} Thousand';
        if (lastRemainder > 0) result += ' ${convertHundreds(lastRemainder)}';
      } else if (finalRemainder > 0) {
        result += ' ${convertHundreds(finalRemainder)}';
      }
    } else if (remainder > 0) {
      if (remainder >= 1000) {
        int thousands = remainder ~/ 1000;
        int lastRemainder = remainder % 1000;
        result += ' ${convertHundreds(thousands)} Thousand';
        if (lastRemainder > 0) result += ' ${convertHundreds(lastRemainder)}';
      } else {
        result += ' ${convertHundreds(remainder)}';
      }
    }

    return result.trim();
  }


  String _getPersonsDisplay(dynamic persons) {
    if (persons == null) return 'No name';
    try {
      List<dynamic> personsList = persons as List;
      if (personsList.isEmpty) return 'No name';

      List<String> names = [];
      for (var person in personsList) {
        if (person['name'] != null && person['name'].toString().isNotEmpty) {
          names.add(person['name']);
        } else if (person['details'] != null && person['details'].toString().isNotEmpty) {
          // For person 2, extract first part before comma
          String details = person['details'];
          String firstName = details.split(',')[0].trim();
          names.add(firstName);
        }
      }
      return names.isEmpty ? 'No name' : names.join(', ');
    } catch (e) {
      return 'No name';
    }
  }

  Future<String> _getOperatorName() async {
    try {
      final response = await _supabase
          .from('users')
          .select('full_name')
          .eq('id', _operatorId!)
          .single();

      return response['full_name'] ?? 'Operator';
    } catch (e) {
      print('Error fetching operator name: $e');
      return 'Operator';
    }
  }

  Future<Map<String, dynamic>> _getEventDetails() async {
    try {
      final response = await _supabase
          .from('events')
          .select('event_date, event_time')
          .eq('id', _eventId!)
          .single();

      DateTime eventDate = DateTime.parse(response['event_date']);

      TimeOfDay eventTime = TimeOfDay.now();
      if (response['event_time'] != null) {
        final timeParts = response['event_time'].split(':');
        eventTime = TimeOfDay(
          hour: int.parse(timeParts[0]),
          minute: int.parse(timeParts[1]),
        );
      }

      return {
        'event_date': eventDate,
        'event_time': eventTime,
      };
    } catch (e) {
      print('Error fetching event details: $e');
      return {
        'event_date': DateTime.now(),
        'event_time': TimeOfDay.now(),
      };
    }
  }

  Future<Map<int, int>?> _getDenominations(String moiId) async {
    try {
      final response = await _supabase
          .from('moi_denominations')
          .select('*')
          .eq('moi_id', moiId)
          .maybeSingle();

      if (response != null) {
        return {
          500: response['denom_500'] ?? 0,
          200: response['denom_200'] ?? 0,
          100: response['denom_100'] ?? 0,
          50: response['denom_50'] ?? 0,
          20: response['denom_20'] ?? 0,
          10: response['denom_10'] ?? 0,
          5: response['denom_5'] ?? 0,
          1: response['denom_1'] ?? 0,
        };
      }
      return null;
    } catch (e) {
      print('Error loading denominations: $e');
      return null;
    }
  }

  Future<void> _handleGenerateSingleReceipt() async {
    if (!await _validateForm()) return; // ✅ Add await

    setState(() => _isLoading = true);

    try {
      String? moiId = _editingMoiId;
      if (moiId == null) {
        moiId = await _saveMoi(_currentGroupId, forceUpdate: false);
        if (moiId == null) {
          throw Exception('Failed to save MOI');
        }
      }

      final operatorName = await _getOperatorName();
      final eventDetails = await _getEventDetails();

      Map<int, int>? denominations;
      if (_paymentMethod == 'CASH') {
        denominations = await _getDenominations(moiId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Generating receipt...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Parse person1Name (split by dot)
      String person1Name = _person1Field1Controller.text.trim();
      String person1Init = '';
      String person1NameOnly = person1Name;
      if (person1Name.contains('.')) {
        List<String> parts = person1Name.split('.');
        person1Init = parts[0].trim();
        person1NameOnly = parts.length > 1 ? parts.sublist(1).join('.').trim() : person1Name;
      }

// Parse person1Job (no splitting needed, pass as-is or split if needed)
      String person1Job = _person1Field2Controller.text.trim();

// Parse person2Details
      String person2Details = _person2Controller.text.trim();
      String person2Init = '';
      String person2NameOnly = '';
      if (person2Details.isNotEmpty && person2Details.contains(',')) {
        List<String> parts = person2Details.split(',');
        String namePart = parts[0].trim();
        if (namePart.contains('.')) {
          List<String> nameParts = namePart.split('.');
          person2Init = nameParts[0].trim();
          person2NameOnly = nameParts.length > 1 ? nameParts.sublist(1).join('.').trim() : namePart;
        } else {
          person2NameOnly = namePart;
        }
      }

      final file = await MoiReceiptGenerator.generateSingleMoiReceipt(
        context: context,
        serialNo: _serialNo!,
        operatorName: operatorName,
        eventDate: eventDetails['event_date'],
        eventTime: eventDetails['event_time'],
        villageName: _villageController.text.trim(),
        livingPlace: _livingPlaceController.text.trim(),
        person1Init: person1Init,
        person1Name: person1NameOnly,
        person2Init: person2Init,
        person2Name: person2NameOnly.isNotEmpty ? person2NameOnly : null,
        phone: _phoneController.text.trim(),
        amount: _paymentMethod == 'CASH' ? _getTotalAmount() : int.tryParse(_amountController.text) ?? 0,
        paymentMethod: _paymentMethod,
        denominations: denominations,
      );

      if (file != null && mounted) {
        Navigator.pushNamed(
          context,
          '/operator/moi-receipt-preview',
          arguments: {
            'receipt_type': 'single',
            'receipt_file': file,
          },
        );
      } else {
        throw Exception('Failed to generate receipt');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<int> _getAvailableBalance(int denomination) async {
    try {
      if (_eventId == null) return 0;

      // Step 1: Get collected from MOI (CASH only)
      final moiData = await _supabase
          .from('moi_denominations')
          .select('''
          denom_$denomination,
          mois!moi_denominations_moi_id_fkey (
            payment_method,
            is_deleted
          )
        ''')
          .eq('event_id', _eventId!);

      int collected = 0;
      for (var entry in moiData) {
        final moi = entry['mois'];
        if (moi != null &&
            moi['payment_method'] == 'CASH' &&
            moi['is_deleted'] == false) {
          collected += (entry['denom_$denomination'] ?? 0) as int;
        }
      }

      // Step 2: Get withdrawn
      final withdrawalData = await _supabase
          .from('cash_withdrawals')
          .select('''
          cash_withdrawal_denominations (
            denom_$denomination
          )
        ''')
          .eq('event_id', _eventId!);

      int withdrawn = 0;
      for (var withdrawal in withdrawalData) {
        final denomData = withdrawal['cash_withdrawal_denominations'];
        if (denomData != null) {
          withdrawn += (denomData['denom_$denomination'] ?? 0) as int;
        }
      }

      // Step 3: Get exchanged (net)
      final exchangeData = await _supabase
          .from('cash_exchanges')
          .select('''
          cash_exchange_denominations (
            denom_$denomination
          )
        ''')
          .eq('event_id', _eventId!);

      int exchanged = 0;
      for (var exchange in exchangeData) {
        final denomData = exchange['cash_exchange_denominations'];
        if (denomData != null) {
          exchanged += (denomData['denom_$denomination'] ?? 0) as int;
        }
      }

      // Available = Collected - Withdrawn + Exchanged
      return collected - withdrawn + exchanged;
    } catch (e) {
      print('Error getting available balance: $e');
      return 0;
    }
  }

  Future<void> _handleGenerateGroupReceipt() async {
    if (_groupedMois.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No grouped entries to generate receipt'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final receiptType = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate Group Receipt'),
        content: const Text('How would you like to generate the receipts?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'consolidated'),
            child: const Text('One Group Receipt'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'split'),
            child: const Text('Individual Receipts'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (receiptType == null) return;

    setState(() => _isLoading = true);

    try {
      final operatorName = await _getOperatorName();
      final eventDetails = await _getEventDetails();

      if (receiptType == 'consolidated') {
        double totalAmount = 0.0;
        Map<int, int> totalDenominations = {
          500: 0, 200: 0, 100: 0, 50: 0, 20: 0, 10: 0, 5: 0, 1: 0,
        };

        for (var entry in _groupedMois) {
          var amountValue = entry['amount'];
          if (amountValue is int) {
            totalAmount += amountValue.toDouble();
          } else if (amountValue is double) {
            totalAmount += amountValue;
          } else if (amountValue is num) {
            totalAmount += amountValue.toDouble();
          }

          if (entry['payment_method'] == 'CASH') {
            final denoms = await _getDenominations(entry['id']);
            if (denoms != null) {
              denoms.forEach((denom, count) {
                totalDenominations[denom] = (totalDenominations[denom] ?? 0) + count;
              });
            }
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Generating group receipt...'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
        }

        final file = await MoiReceiptGenerator.generateGroupMoiReceipt(
          context: context,
          groupId: _currentGroupId!,
          operatorName: operatorName,
          eventDate: eventDetails['event_date'],
          eventTime: eventDetails['event_time'],
          groupEntries: _groupedMois,
          totalAmount: totalAmount,
          totalDenominations: totalDenominations.values.any((v) => v > 0) ? totalDenominations : null,
        );

        if (file != null && mounted) {
          Navigator.pushNamed(
            context,
            '/operator/moi-receipt-preview',
            arguments: {
              'receipt_type': 'group',
              'receipt_file': file,
            },
          );
        } else {
          throw Exception('Failed to generate group receipt');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Generating ${_groupedMois.length} receipts...'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        List<Map<String, dynamic>> entriesWithDenoms = [];
        for (var entry in _groupedMois) {
          Map<String, dynamic> entryData = Map.from(entry);
          if (entry['payment_method'] == 'CASH') {
            entryData['denominations'] = await _getDenominations(entry['id']);
          }
          entriesWithDenoms.add(entryData);
        }

        final files = await MoiReceiptGenerator.generateSplitGroupReceipts(
          context: context,
          operatorName: operatorName,
          eventDate: eventDetails['event_date'],
          eventTime: eventDetails['event_time'],
          groupEntries: entriesWithDenoms,
        );

        if (files.isNotEmpty && mounted) {
          Navigator.pushNamed(
            context,
            '/operator/moi-receipt-preview',
            arguments: {
              'receipt_type': 'split',
              'receipt_files': files,
            },
          );
        } else {
          throw Exception('Failed to generate receipts');
        }
      }
    } catch (e) {
      print('Error in _handleGenerateGroupReceipt: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            // Check for Ctrl+S
            if (event.logicalKey == LogicalKeyboardKey.keyS &&
                (event.logicalKey.keyLabel == 's' || event.logicalKey.keyLabel == 'S') &&
                HardwareKeyboard.instance.isControlPressed) {
              _handleSaveAndPrint();
              return KeyEventResult.handled;
            }
            // Check for Ctrl+G
            if (event.logicalKey == LogicalKeyboardKey.keyG &&
                (event.logicalKey.keyLabel == 'g' || event.logicalKey.keyLabel == 'G') &&
                HardwareKeyboard.instance.isControlPressed) {
              _handleGroup();
              return KeyEventResult.handled;
            }
            // Check for Ctrl+Delete
            if (event.logicalKey == LogicalKeyboardKey.delete &&
                HardwareKeyboard.instance.isControlPressed) {
              _handleClear();
              return KeyEventResult.handled;
            }
            // Check for Ctrl+A (Add Entry - only when in group mode)
            if (event.logicalKey == LogicalKeyboardKey.keyA &&
                (event.logicalKey.keyLabel == 'a' || event.logicalKey.keyLabel == 'A') &&
                HardwareKeyboard.instance.isControlPressed) {
              if (_currentGroupId != null) {
                _handleAddEntry();
                return KeyEventResult.handled;
              }
            }
// Check for Ctrl+P (Generate receipt)
            if (event.logicalKey == LogicalKeyboardKey.keyP &&
                (event.logicalKey.keyLabel == 'p' || event.logicalKey.keyLabel == 'P') &&
                HardwareKeyboard.instance.isControlPressed) {
              if (_currentGroupId != null && _groupedMois.isNotEmpty) {
                _handleGenerateGroupReceipt();
              } else if (_currentGroupId == null && (_isEditMode || _hasFormData())) {
                _handleGenerateSingleReceipt();
              }
              return KeyEventResult.handled;
            }

          }
          return KeyEventResult.ignored;
        },
        child: Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditMode ? 'Edit MOI' : 'Collect Moi',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _buildSerialAndPaymentHeader(),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Search Mobile Number',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _phoneController,
                    focusNode: _phoneFocusNode,
                    keyboardType: TextInputType.number, // ✅ CHANGE from phone to number
                    maxLength: 10,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly, // ✅ ADD THIS - Only digits allowed
                    ],
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Search Mobile Number',
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      isDense: true,
                      counterText: '',  // Hide character counter
                    ),
                    onChanged: (value) {
                      // Auto-fill when 10 digits are entered
                      if (value.length == 10 && !_isEditMode) {
                        _autoFillFromPhoneNumber(value);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildVillageAndLivingPlace(),
            const SizedBox(height: 12),
            _buildPerson1Fields(),
            const SizedBox(height: 12),
            _buildPerson2Field(),
            const SizedBox(height: 12),
            _buildTextField('Notes', _notesController, maxLines: 2),
            const SizedBox(height: 12),
            _buildAmountField(),
            const SizedBox(height: 12),
            if (_paymentMethod == 'CASH') _buildDenominations(),
            const SizedBox(height: 12),
            if (_paymentMethod == 'CASH') _buildAmountSummary(),
            const SizedBox(height: 12),
            if (_groupedMois.isNotEmpty) _buildMoiDetails(),
            const SizedBox(height: 12),
            _buildActionButtons(),
          ],
        ),
      ),
        ),
    );
  }

  Widget _buildSerialAndPaymentHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'Serial No.',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: Text(
                  'O${_serialNo?.toString() ?? '0'}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Uncle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              Checkbox(
                value: _isUncle,
                onChanged: (value) {
                  setState(() {
                    _isUncle = value ?? false;
                  });
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 20),
              const Text('Cheque / Advance / UPI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              Checkbox(
                value: _paymentMethod == 'OTHERS',
                onChanged: (value) {
                  setState(() {
                    _paymentMethod = value == true ? 'OTHERS' : 'CASH';
                    if (_paymentMethod == 'OTHERS') {
                      for (var row in _denomRows) {
                        row['countController'].clear();
                      }
                    }
                  });
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: label,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVillageAndLivingPlace() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Village Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: _villageController,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Living City', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: _livingPlaceController,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerson1Fields() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Init, Name 1', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          TextField(
            controller: _person1Field1Controller,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'e.g., init, name',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _person1Field2Controller,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'e.g., education, job',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerson2Field() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Init, Name 2, Education, Job',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          TextField(
            controller: _person2Controller,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'e.g., init, name, education, job',
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              isDense: true,
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  // Update the _buildAmountField() widget
  Widget _buildAmountField() {
    int amount = int.tryParse(_amountController.text) ?? 0;
    String amountInWords = amount > 0 ? _numberToWords(amount) : '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Amount', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 2)),
            child: TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              onChanged: (value) {
                setState(() {}); // Rebuild to update amount in words
              },
            ),
          ),
          if (amountInWords.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                border: Border.all(color: Colors.blue, width: 1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$amountInWords Rupees Only',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[900],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDenominations() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Denomination', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ..._denomRows.asMap().entries.map((entry) {
            int index = entry.key;
            var row = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildDenomRow(row, index),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildDenomRow(Map<String, dynamic> row, int index) {
    final controller = row['countController'] as TextEditingController;
    final selectedDenom = row['selectedDenom'];

    if (!row.containsKey('denomController')) {
      row['denomController'] = TextEditingController(
          text: selectedDenom != null ? selectedDenom.toString() : ''
      );
    }
    final denomController = row['denomController'] as TextEditingController;

    int count = int.tryParse(controller.text) ?? 0;
    int total = (selectedDenom ?? 0) * count;

    // Check if we need to show availability
    bool showAvailability = count < 0 && selectedDenom != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 80,
              height: 35,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 2),
                color: Colors.white,
              ),
              child: TextField(
                controller: denomController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                  prefixText: '₹',
                  prefixStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  hintText: '0',
                ),
                onChanged: (value) {
                  if (value.isEmpty) {
                    setState(() {
                      row['selectedDenom'] = null;
                    });
                    return;
                  }

                  int? typedValue = int.tryParse(value);
                  if (typedValue == null) return;

                  List<int> validDenoms = [1, 5, 10, 20, 50, 100, 200, 500];

                  if (!validDenoms.contains(typedValue)) {
                    denomController.clear();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Only ₹1, ₹5, ₹10, ₹20, ₹50, ₹100, ₹200, ₹500 allowed'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }

                  setState(() {
                    row['selectedDenom'] = typedValue;
                  });
                },
              ),
            ),
            const SizedBox(width: 6),
            const Text('×', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 35,
                alignment: Alignment.center,
                decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 2)),
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'-?\d*')),
                  ],
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    hintText: '0',
                    hintStyle: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Text('=', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(width: 6),
            Container(
              width: 90,
              height: 35,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 2),
                color: Colors.grey[200],
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    total.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ),
          ],
        ),

        // Availability indicator (only for negative counts)
        if (showAvailability)
          FutureBuilder<int>(
            future: _getAvailableBalance(selectedDenom!),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.only(top: 2, left: 90),
                  child: SizedBox(
                    height: 12,
                    width: 12,
                    child: CircularProgressIndicator(strokeWidth: 1),
                  ),
                );
              }

              int available = snapshot.data ?? 0;
              bool isSufficient = available.abs() >= count.abs();

              return Padding(
                padding: const EdgeInsets.only(top: 2, left: 90),
                child: Text(
                  'Available: $available',
                  style: TextStyle(
                    fontSize: 11,
                    color: isSufficient ? Colors.green[700] : Colors.red[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  // Update the _buildAmountSummary() widget
  Widget _buildAmountSummary() {
    int totalAmount = _getTotalAmount(); // Now safe with null check
    String amountInWords = totalAmount > 0 ? _numberToWords(totalAmount) : '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Count: ${_getTotalCount()}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                Text('Total Amount: ₹$totalAmount',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (amountInWords.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[50],
                border: Border.all(color: Colors.green, width: 1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$amountInWords Rupees Only',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[900],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMoiDetails() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.black, width: 2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Moi Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                if (_currentGroupId != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      border: Border.all(color: Colors.blue, width: 2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Group ID - $_currentGroupId',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            child: _groupedMois.isEmpty
                ? const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Grouped entries will appear here...', style: TextStyle(color: Colors.grey, fontSize: 12)),
            )
                : ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.all(10),
              itemCount: _groupedMois.length,
              separatorBuilder: (context, index) => const Divider(color: Colors.black, thickness: 1, height: 12),
              itemBuilder: (context, index) {
                final moi = _groupedMois[index];
                final isCurrentlyEditing = _editingMoiId == moi['id'];

                return InkWell(
                  // ✅ ADD DOUBLE-CLICK TO DELETE
                  onDoubleTap: () => _handleDeleteFromGroup(moi),
                  onTap: () => _loadGroupedEntryForEdit(moi),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isCurrentlyEditing ? Colors.blue.shade50 : Colors.transparent,
                      border: isCurrentlyEditing ? Border.all(color: Colors.blue, width: 2) : null,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getPersonsDisplay(moi['persons']),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: isCurrentlyEditing ? Colors.blue : Colors.black,
                                ),
                              ),
                              if (moi['village_name'] != null)
                                Text(
                                  moi['village_name'],
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isCurrentlyEditing ? Colors.blue.shade700 : Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (isCurrentlyEditing)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'EDITING',
                              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        Text(
                          '₹${moi['amount']}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isCurrentlyEditing ? Colors.blue : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteFromGroup(Map<String, dynamic> moi) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          '🗑️ Delete Entry',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Do you want to delete this entry from the group?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text('Serial No: O${moi['serial_no']}'),
            Text('Name: ${_getPersonsDisplay(moi['persons'])}'),
            Text('Amount: ₹${moi['amount']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              backgroundColor: Colors.grey[200],
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              backgroundColor: Colors.red[100],
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              'DELETE',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        // Mark as deleted
        await _supabase
            .from('mois')
            .update({'is_deleted': true, 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', moi['id']);

        // If this was the entry being edited, clear edit mode
        if (_editingMoiId == moi['id']) {
          setState(() {
            _isEditMode = false;
            _editingMoiId = null;
            _originalData = null;
          });
          await _clearFormForNextEntry();
        }

        // Reload the group
        await _loadGroupedMois();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Entry deleted from group'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        print('Error deleting entry: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting entry: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 42,
                decoration: BoxDecoration(color: Colors.green, border: Border.all(color: Colors.black, width: 2)),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _handleSaveAndPrint,
                    child: const Center(
                      child: Text(
                        'Save & Print',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 42,
                decoration: BoxDecoration(color: Colors.blue, border: Border.all(color: Colors.black, width: 2)),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _handleGroup,
                    child: const Center(
                      child: Text(
                        'Group',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Receipt generation buttons
        if (_currentGroupId != null && _groupedMois.isNotEmpty) ...[
          Container(
            width: double.infinity,
            height: 42,
            decoration: BoxDecoration(color: Colors.teal, border: Border.all(color: Colors.black, width: 2)),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _handleGenerateGroupReceipt,
                child: const Center(
                  child: Text(
                    'Generate Group Receipt',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        if (_currentGroupId == null && (_isEditMode || _hasFormData())) ...[
          Container(
            width: double.infinity,
            height: 42,
            decoration: BoxDecoration(color: Colors.teal, border: Border.all(color: Colors.black, width: 2)),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _handleGenerateSingleReceipt,
                child: const Center(
                  child: Text(
                    'Generate Single Receipt',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        if (_currentGroupId != null) ...[
          Container(
            width: double.infinity,
            height: 42,
            decoration: BoxDecoration(color: Colors.purple, border: Border.all(color: Colors.black, width: 2)),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _handleAddEntry,
                child: const Center(
                  child: Text(
                    'ADD ENTRY',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        Container(
          width: double.infinity,
          height: 42,
          decoration: BoxDecoration(color: Colors.orange, border: Border.all(color: Colors.black, width: 2)),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _handleClear,
              child: const Center(
                child: Text(
                  'Clear',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose(); // ✅ ADD THIS
    _villageController.dispose();
    _livingPlaceController.dispose();
    _notesController.dispose();
    _amountController.dispose();
    _person1Field1Controller.dispose();
    _person1Field2Controller.dispose();
    _person2Controller.dispose();

    for (var row in _denomRows) {
      row['countController'].dispose();
      if (row.containsKey('denomController')) {
        row['denomController'].dispose();
      }
    }
    super.dispose();
  }
}