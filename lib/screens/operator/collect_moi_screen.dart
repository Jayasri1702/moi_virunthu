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
    // Start with only the first row (500)
    _denomRows.add({
      'denomOptions': [500, 100, 10, 1],
      'selectedDenom': 500,
      'countController': TextEditingController(),
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
    // Check each row if it has a count, then show next row
    for (int i = 0; i < _denomRows.length; i++) {
      final count = int.tryParse(_denomRows[i]['countController'].text) ?? 0;
      final selectedDenom = _denomRows[i]['selectedDenom'];

      if (count > 0 && selectedDenom < 500) {
        // Show next row if it doesn't exist
        if (i == _denomRows.length - 1) {
          _addNextDenomRow(selectedDenom);
        }
      }
    }
  }

  void _addNextDenomRow(int currentDenom) {
    List<int> nextOptions = [];
    int nextDenom = 0;

    // Define the next denomination based on current
    if (currentDenom == 500) {
      nextDenom = 200;
      nextOptions = [200, 20, 2];
    } else if (currentDenom == 200) {
      nextDenom = 100;
      nextOptions = [100, 10, 1];
    } else if (currentDenom == 100) {
      nextDenom = 50;
      nextOptions = [50, 5];
    } else if (currentDenom == 50) {
      nextDenom = 20;
      nextOptions = [20, 2];
    } else if (currentDenom == 20) {
      nextDenom = 10;
      nextOptions = [10, 1];
    } else if (currentDenom == 10) {
      nextDenom = 5;
      nextOptions = [5];
    } else if (currentDenom == 5) {
      nextDenom = 1;
      nextOptions = [1];
    }

    if (nextOptions.isNotEmpty && !_hasRowWithDenom(nextDenom)) {
      final controller = TextEditingController();
      controller.addListener(_onDenomCountChanged);

      setState(() {
        _denomRows.add({
          'denomOptions': nextOptions,
          'selectedDenom': nextDenom,
          'countController': controller,
        });
      });
    }
  }

  bool _hasRowWithDenom(int denom) {
    return _denomRows.any((row) => row['selectedDenom'] == denom);
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
          String field1 = '';
          if (person1['init'] != null && person1['init'].toString().isNotEmpty) {
            field1 += person1['init'];
          }
          if (person1['name'] != null && person1['name'].toString().isNotEmpty) {
            field1 += (field1.isEmpty ? '' : ', ') + person1['name'];
          }
          _person1Field1Controller.text = field1;

          String field2 = '';
          if (person1['qualification'] != null && person1['qualification'].toString().isNotEmpty) {
            field2 += person1['qualification'];
          }
          if (person1['job'] != null && person1['job'].toString().isNotEmpty) {
            field2 += (field2.isEmpty ? '' : ', ') + person1['job'];
          }
          _person1Field2Controller.text = field2;
        }
        if (personsList.length > 1) {
          var person2 = personsList[1];
          String person2Text = '';
          if (person2['init'] != null && person2['init'].toString().isNotEmpty) {
            person2Text += person2['init'];
          }
          if (person2['name'] != null && person2['name'].toString().isNotEmpty) {
            person2Text += (person2Text.isEmpty ? '' : ', ') + person2['name'];
          }
          if (person2['qualification'] != null && person2['qualification'].toString().isNotEmpty) {
            person2Text += (person2Text.isEmpty ? '' : ', ') + person2['qualification'];
          }
          if (person2['job'] != null && person2['job'].toString().isNotEmpty) {
            person2Text += (person2Text.isEmpty ? '' : ', ') + person2['job'];
          }
          _person2Controller.text = person2Text;
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

        // Add rows based on saved data
        savedDenoms.forEach((denom, count) {
          if (count > 0) {
            final controller = TextEditingController(text: count.toString());
            controller.addListener(_onDenomCountChanged);

            List<int> options = [];
            if (denom >= 500) options = [500, 100, 10, 1];
            else if (denom >= 100) options = [100, 50, 20, 10, 5, 1];
            else if (denom >= 50) options = [50, 20, 10, 5, 1];
            else if (denom >= 20) options = [20, 10, 5, 1];
            else if (denom >= 10) options = [10, 5, 1];
            else if (denom >= 5) options = [5, 1];
            else options = [1];

            _denomRows.add({
              'denomOptions': options,
              'selectedDenom': denom,
              'countController': controller,
            });
          }
        });

        // If no denominations saved, initialize with default
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
          String field1 = '';
          if (person1['init'] != null && person1['init'].toString().isNotEmpty) {
            field1 += person1['init'];
          }
          if (person1['name'] != null && person1['name'].toString().isNotEmpty) {
            field1 += (field1.isEmpty ? '' : ', ') + person1['name'];
          }
          _person1Field1Controller.text = field1;

          String field2 = '';
          if (person1['qualification'] != null && person1['qualification'].toString().isNotEmpty) {
            field2 += person1['qualification'];
          }
          if (person1['job'] != null && person1['job'].toString().isNotEmpty) {
            field2 += (field2.isEmpty ? '' : ', ') + person1['job'];
          }
          _person1Field2Controller.text = field2;
        } else {
          _person1Field1Controller.clear();
          _person1Field2Controller.clear();
        }
        if (personsList.length > 1) {
          var person2 = personsList[1];
          String person2Text = '';
          if (person2['init'] != null && person2['init'].toString().isNotEmpty) {
            person2Text += person2['init'];
          }
          if (person2['name'] != null && person2['name'].toString().isNotEmpty) {
            person2Text += (person2Text.isEmpty ? '' : ', ') + person2['name'];
          }
          if (person2['qualification'] != null && person2['qualification'].toString().isNotEmpty) {
            person2Text += (person2Text.isEmpty ? '' : ', ') + person2['qualification'];
          }
          if (person2['job'] != null && person2['job'].toString().isNotEmpty) {
            person2Text += (person2Text.isEmpty ? '' : ', ') + person2['job'];
          }
          _person2Controller.text = person2Text;
        } else {
          _person2Controller.clear();
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
    if (_eventId == null || _operatorId == null) return;

    try {
      final response = await _supabase
          .from('mois')
          .select('serial_no')
          .eq('event_id', _eventId!)
          .eq('operator_id', _operatorId!)
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
      String person1Name = '';
      if (_person1Field1Controller.text.trim().isNotEmpty) {
        List<String> parts = _person1Field1Controller.text.trim().split(',').map((e) => e.trim()).toList();
        person1Name = parts.length > 1 ? parts[1] : '';
      }

      // Parse Person 1 job
      String person1Job = '';
      if (_person1Field2Controller.text.trim().isNotEmpty) {
        List<String> parts = _person1Field2Controller.text.trim().split(',').map((e) => e.trim()).toList();
        person1Job = parts.length > 1 ? parts[1] : '';
      }

      // Parse Person 2 name
      String person2Name = '';
      if (_person2Controller.text.trim().isNotEmpty) {
        List<String> parts = _person2Controller.text.trim().split(',').map((e) => e.trim()).toList();
        person2Name = parts.length > 1 ? parts[1] : '';
      }

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

          // Check Person 2 name
          if (person2Name.isNotEmpty && personsList.length > 1) {
            var p2 = personsList[1];
            String entryP2Name = p2['name'] ?? '';

            if (entryP2Name.toLowerCase() != person2Name.toLowerCase()) continue;
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
          entryDetails += '  Init: ${p1['init'] ?? 'N/A'}\n';
          entryDetails += '  Name: ${p1['name'] ?? 'N/A'}\n';
          entryDetails += '  Education: ${p1['qualification'] ?? 'N/A'}\n';
          entryDetails += '  Job: ${p1['job'] ?? 'N/A'}\n';
        }
        if (personsList.length > 1) {
          var p2 = personsList[1];
          entryDetails += '\n👤 Person 2:\n';
          entryDetails += '  Init: ${p2['init'] ?? 'N/A'}\n';
          entryDetails += '  Name: ${p2['name'] ?? 'N/A'}\n';
          entryDetails += '  Education: ${p2['qualification'] ?? 'N/A'}\n';
          entryDetails += '  Job: ${p2['job'] ?? 'N/A'}\n';
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

              // Fill Person 1 Field 1 (Init, Name)
              String field1 = '';
              if (person1['init'] != null && person1['init'].toString().isNotEmpty) {
                field1 += person1['init'];
              }
              if (person1['name'] != null && person1['name'].toString().isNotEmpty) {
                field1 += (field1.isEmpty ? '' : ', ') + person1['name'];
              }
              _person1Field1Controller.text = field1;

              // Fill Person 1 Field 2 (Education, Job)
              String field2 = '';
              if (person1['qualification'] != null && person1['qualification'].toString().isNotEmpty) {
                field2 += person1['qualification'];
              }
              if (person1['job'] != null && person1['job'].toString().isNotEmpty) {
                field2 += (field2.isEmpty ? '' : ', ') + person1['job'];
              }
              _person1Field2Controller.text = field2;
            }

            // Fill Person 2 details
            if (personsList.length > 1) {
              var person2 = personsList[1];
              String person2Text = '';

              if (person2['init'] != null && person2['init'].toString().isNotEmpty) {
                person2Text += person2['init'];
              }
              if (person2['name'] != null && person2['name'].toString().isNotEmpty) {
                person2Text += (person2Text.isEmpty ? '' : ', ') + person2['name'];
              }
              if (person2['qualification'] != null && person2['qualification'].toString().isNotEmpty) {
                person2Text += (person2Text.isEmpty ? '' : ', ') + person2['qualification'];
              }
              if (person2['job'] != null && person2['job'].toString().isNotEmpty) {
                person2Text += (person2Text.isEmpty ? '' : ', ') + person2['job'];
              }

              _person2Controller.text = person2Text;
            }
          }
        });
      }
    } catch (e) {
      print('Error auto-filling from phone number: $e');
    }
  }

  int _getTotalAmount() {
    if (_paymentMethod == 'CASH') {
      int total = 0;
      for (var row in _denomRows) {
        int denom = row['selectedDenom'];
        int count = int.tryParse(row['countController'].text) ?? 0;
        total += denom * count;
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
      count += int.tryParse(row['countController'].text) ?? 0;
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
    if (!_validateForm()) return;

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
    if (_person1Field1Controller.text.trim().isNotEmpty) {
      String field1 = _person1Field1Controller.text.trim();
      List<String> parts = field1.split(',').map((e) => e.trim()).toList();

      String init = parts.length > 0 ? parts[0] : '';
      String name = parts.length > 1 ? parts[1] : '';

      String field2 = _person1Field2Controller.text.trim();
      List<String> eduJob = field2.split(',').map((e) => e.trim()).toList();

      personsData.add({
        'init': init,
        'name': name,
        'qualification': eduJob.length > 0 ? eduJob[0] : '',
        'job': eduJob.length > 1 ? eduJob[1] : '',
      });
    }

    // Parse Person 2
    if (_person2Controller.text.trim().isNotEmpty) {
      String person2Text = _person2Controller.text.trim();
      List<String> parts = person2Text.split(',').map((e) => e.trim()).toList();

      Map<String, dynamic> person2Data = {
        'init': parts.length > 0 ? parts[0] : '',
        'name': parts.length > 1 ? parts[1] : '',
        'qualification': parts.length > 2 ? parts[2] : '',
        'job': parts.length > 3 ? parts[3] : '',
      };
      personsData.add(person2Data);
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

    for (var row in _denomRows) {
      int denom = row['selectedDenom'];
      int count = int.tryParse(row['countController'].text) ?? 0;

      denomData['denom_$denom'] = count;
    }

    await _supabase
        .from('moi_denominations')
        .upsert(denomData);
  }

  Future<void> _handleSaveAndPrint() async {
    if (!_isEditMode) {
      await _loadNextSerialNo();
    }

    // Auto-add to group if user forgot to click Group button
    if (_currentGroupId != null && _hasFormData() && !_isEditMode) {
      if (!_validateForm()) return;

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
        if (!_validateForm()) return;

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
    if (!_validateForm()) return;

// CHECK FOR EXISTING ENTRY FIRST (only for new entries, not edit mode)
    if (!_isEditMode && _currentGroupId == null) {
      final existingEntries = await _checkExistingEntry();

      if (existingEntries.isNotEmpty) {
        final shouldProceed = await _showExistingEntryDialog(existingEntries);

        if (!shouldProceed) {
          // User chose DISCARD - clear the form
          _handleClear();
          return;
        }
      }
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

  bool _validateForm() {
    bool hasValidPerson = _person1Field1Controller.text.trim().isNotEmpty ||
        _person2Controller.text.trim().isNotEmpty;

    if (!hasValidPerson) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one person with a name')),
      );
      return false;
    }


    // ✅ UPDATE THIS SECTION - Phone validation for ALL cases (not just edit mode)
    String phoneNumber = _phoneController.text.trim();

    // Phone must be either empty OR exactly 10 digits
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


    // ADD THIS PHONE NUMBER VALIDATION (ONLY FOR EDIT MODE) ⬇️
    // Phone number validation ONLY for critical edits (amount, payment method, denominations)
    if (_isEditMode) {
      // Check if user is editing amount, payment method, or denominations
      bool isEditingCriticalFields = false;

      if (_originalData != null) {
        // Check if amount changed
        var originalAmount = _originalData!['amount'];
        int currentAmount = _paymentMethod == 'CASH' ? _getTotalAmount() : int.tryParse(_amountController.text) ?? 0;
        if (originalAmount != currentAmount) {
          isEditingCriticalFields = true;
        }

        // Check if payment method changed
        if (_originalData!['payment_method'] != _paymentMethod) {
          isEditingCriticalFields = true;
        }

        // Check if denominations changed (only if CASH)
        if (_paymentMethod == 'CASH' && _originalData!['payment_method'] == 'CASH') {
          int currentDenomTotal = _getTotalAmount();
          if (originalAmount != currentDenomTotal) {
            isEditingCriticalFields = true;
          }
        }
      }

      // Only validate phone if critical fields are being edited
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
    // END OF PHONE NUMBER VALIDATION ⬆️

    if (_paymentMethod == 'CASH') {
      int denomTotal = _getTotalAmount();

      if (denomTotal == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter denomination details')),
        );
        return false;
      }

      // Only validate amount match if amount is manually entered
      String enteredAmountText = _amountController.text.trim();
      if (enteredAmountText.isNotEmpty) {
        int enteredAmount = int.tryParse(enteredAmountText) ?? 0;

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
    } else {
      if (_amountController.text.trim().isEmpty || int.tryParse(_amountController.text.trim()) == null || int.tryParse(_amountController.text.trim())! == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter amount')),
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
  }

  String _getPersonsDisplay(dynamic persons) {
    if (persons == null) return 'No name';
    try {
      List<dynamic> personsList = persons as List;
      if (personsList.isEmpty) return 'No name';

      List<String> names = [];
      for (var person in personsList) {
        String name = person['name'] ?? '';
        if (name.isNotEmpty) {
          names.add(name);
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
    if (!_validateForm()) return;

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

      // Parse person 1 data
      String field1 = _person1Field1Controller.text.trim();
      List<String> parts = field1.split(',').map((e) => e.trim()).toList();
      String init1 = parts.length > 0 ? parts[0] : '';
      String name1 = parts.length > 1 ? parts[1] : '';

      final file = await MoiReceiptGenerator.generateSingleMoiReceipt(
        context: context,
        serialNo: _serialNo!,
        operatorName: operatorName,
        eventDate: eventDetails['event_date'],
        eventTime: eventDetails['event_time'],
        villageName: _villageController.text.trim(),
        livingPlace: _livingPlaceController.text.trim(),
        person1Init: init1,
        person1Name: name1,
        person2Init: '',
        person2Name: _person2Controller.text.trim().isNotEmpty ? _person2Controller.text.trim() : null,
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

  Widget _buildAmountField() {
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
            alignment: Alignment.center,  // ADD THIS
            decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 2)),
            child: TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,  // CHANGE THIS
                isDense: true,  // ADD THIS
              ),
            ),
          ),
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
    final selectedDenom = row['selectedDenom'] as int;

    // Add a controller for denomination input if not exists
    if (!row.containsKey('denomController')) {
      row['denomController'] = TextEditingController(text: selectedDenom.toString());
    }
    final denomController = row['denomController'] as TextEditingController;

    int count = int.tryParse(controller.text) ?? 0;
    int total = selectedDenom * count;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 80,
              height: 35,
              alignment: Alignment.center,  // ADD THIS
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
                  ),
                onChanged: (value) {
                  if (value.isEmpty) {
                    setState(() {
                      row['showDropdown'] = false;
                      row['denomOptions'] = [500, 100, 10, 1];
                      row['selectedDenom'] = 500;
                    });
                    return;
                  }

                  int? typedValue = int.tryParse(value);
                  if (typedValue == null) return;

                  // ✅ UPDATED VALIDATION - Check if it's a valid starting digit or complete denomination
                  List<int> validDenoms = [1, 5, 10, 20, 50, 100, 200, 500];
                  List<int> validStartDigits = [1, 2, 5]; // Valid first digits for denominations

                  // If it's a single digit, check if it's a valid starting digit
                  if (value.length == 1) {
                    if (!validStartDigits.contains(typedValue)) {
                      denomController.text = '';
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Only denominations starting with 1, 2, or 5 are allowed'),
                          backgroundColor: Colors.red,
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                  } else {
                    // For multi-digit entries, check if it's a valid denomination
                    if (!validDenoms.contains(typedValue)) {
                      denomController.text = '';
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Only ₹1, ₹5, ₹10, ₹20, ₹50, ₹100, ₹200, ₹500 allowed'),
                          backgroundColor: Colors.red,
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                  }

                  // Find the maximum denomination from all previous rows
                  int maxPrevDenom = 0;
                  for (int i = 0; i < index; i++) {
                    if (_denomRows[i]['selectedDenom'] > maxPrevDenom) {
                      maxPrevDenom = _denomRows[i]['selectedDenom'];
                    }
                  }

                  List<int> options = [];

                  if (typedValue == 1) {
                    options = [100, 10, 1];
                  } else if (typedValue == 2) {
                    options = [200, 20]; // ✅ ADD 2 here as well
                  } else if (typedValue == 5) {
                    options = [500, 50, 5];
                  } else if (typedValue == 10) {
                    options = [10];
                  } else if (typedValue == 20) {
                    options = [20]; // ✅ Should include 2 as option
                  } else if (typedValue == 50) {
                    options = [50, 5]; // ✅ Should include 5 as option
                  } else if (typedValue == 100) {
                    options = [100, 10, 1]; // ✅ Should include options
                  } else if (typedValue == 200) {
                    options = [200, 20]; // ✅ Should include options
                  } else if (typedValue == 500) {
                    options = [500, 50, 5]; // ✅ Should include options
                  }

                  // Filter out denominations >= maxPrevDenom
                  if (maxPrevDenom > 0) {
                    options = options.where((denom) => denom < maxPrevDenom).toList();
                  }

                  if (options.isNotEmpty) {
                    setState(() {
                      row['denomOptions'] = options;
                      row['showDropdown'] = options.length > 1;
                      // If only one option, auto-select it
                      if (options.length == 1) {
                        row['selectedDenom'] = options[0];
                        denomController.text = options[0].toString();
                        _updateDenominationRows();
                      }
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 6),
            const Text('×', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 35,
                alignment: Alignment.center,  // ADD THIS
                decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 2)),
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,  // KEEP THIS
                    isDense: true,  // ADD THIS
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
              alignment: Alignment.center,  // ADD THIS if text still not centered
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 2),
                color: Colors.grey[200],
              ),
              // Remove the Center widget and directly use:
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
        // Dropdown appears below
        if (row['showDropdown'] == true && row['denomOptions'] != null) ...[
          const SizedBox(height: 4),
          Container(
            width: 80,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 2),
              color: Colors.white,
            ),
            child: Column(
              children: (row['denomOptions'] as List<int>).map((denom) {
                return InkWell(
                  onTap: () {
                    setState(() {
                      row['selectedDenom'] = denom;
                      denomController.text = denom.toString();
                      row['showDropdown'] = false;
                      _updateDenominationRows();
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 1)),
                    ),
                    child: Text(
                      '₹$denom',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAmountSummary() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Container(
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
            Text('Total Amount: ₹${_getTotalAmount()}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
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