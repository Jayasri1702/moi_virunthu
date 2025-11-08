import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/moi_receipt_generator.dart';

class CollectMoiScreen extends StatefulWidget {
  const CollectMoiScreen({super.key});

  @override
  State<CollectMoiScreen> createState() => _CollectMoiScreenState();
}

class _CollectMoiScreenState extends State<CollectMoiScreen> {
  final _supabase = Supabase.instance.client;

  // Controllers
  final _phoneController = TextEditingController();
  final _villageController = TextEditingController();
  final _livingPlaceController = TextEditingController();
  final _notesController = TextEditingController();
  final _amountController = TextEditingController();

  // Denomination controllers
  final Map<int, TextEditingController> _denomControllers = {
    500: TextEditingController(),
    200: TextEditingController(),
    100: TextEditingController(),
    50: TextEditingController(),
    20: TextEditingController(),
    10: TextEditingController(),
    5: TextEditingController(),
    1: TextEditingController(),
  };

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
  Map<String, dynamic>? _originalData; // Store original data before editing

  // Person 1 controllers
  final _init1Controller = TextEditingController();
  final _name1Controller = TextEditingController();
  final _qualification1Controller = TextEditingController();
  final _job1Controller = TextEditingController();

  // Person 2 controllers
  final _init2Controller = TextEditingController();
  final _name2Controller = TextEditingController();
  final _qualification2Controller = TextEditingController();
  final _job2Controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _setupDenomListeners();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading) {
      _loadArguments();
    }
  }

  void _setupDenomListeners() {
    _denomControllers.forEach((denom, controller) {
      controller.addListener(() {
        if (_paymentMethod == 'CASH') {
          _calculateTotal();
        }
      });
    });
  }

  Future<void> _loadArguments() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map<String, dynamic>) {
      _eventId = args['id'];
      _operatorId = args['operator_id'];

      // Check if edit mode
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
    // Store original data for old_data field
    _originalData = Map<String, dynamic>.from(moiData);

    // Remove all listeners temporarily
    _denomControllers.forEach((_, controller) {
      controller.removeListener(_calculateTotal);
    });

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

      // Load persons
      if (moiData['persons'] != null) {
        List<dynamic> personsList = moiData['persons'] as List;
        if (personsList.isNotEmpty) {
          var person1 = personsList[0];
          _init1Controller.text = person1['init'] ?? '';
          _name1Controller.text = person1['name'] ?? '';
          _qualification1Controller.text = person1['qualification'] ?? '';
          _job1Controller.text = person1['job'] ?? '';
        }
        if (personsList.length > 1) {
          var person2 = personsList[1];
          _init2Controller.text = person2['init'] ?? '';
          _name2Controller.text = person2['name'] ?? '';
          _qualification2Controller.text = person2['qualification'] ?? '';
          _job2Controller.text = person2['job'] ?? '';
        }
      }

      _amountController.text = moiData['amount']?.toString() ?? '0';
    });

    // REQUIREMENT 1: Load all grouped entries immediately when editing
    if (_currentGroupId != null) {
      await _loadGroupedMois();
    }

    // Load denominations only if payment method is CASH
    if (_paymentMethod == 'CASH') {
      await _loadDenominations(moiData['id']);
    } else {
      _denomControllers.forEach((_, controller) {
        controller.clear();
      });
    }

    // Re-add listeners
    _setupDenomListeners();
  }

  Future<void> _loadDenominations(String moiId) async {
    try {
      final response = await _supabase
          .from('moi_denominations')
          .select('*')
          .eq('moi_id', moiId)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _denomControllers[500]!.text = response['denom_500']?.toString() ?? '';
          _denomControllers[200]!.text = response['denom_200']?.toString() ?? '';
          _denomControllers[100]!.text = response['denom_100']?.toString() ?? '';
          _denomControllers[50]!.text = response['denom_50']?.toString() ?? '';
          _denomControllers[20]!.text = response['denom_20']?.toString() ?? '';
          _denomControllers[10]!.text = response['denom_10']?.toString() ?? '';
          _denomControllers[5]!.text = response['denom_5']?.toString() ?? '';
          _denomControllers[1]!.text = response['denom_1']?.toString() ?? '';
        });
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
    print('Loading entry for edit - Payment: ${moiData['payment_method']}, Amount: ${moiData['amount']}');

    // Store original data for old_data field
    _originalData = Map<String, dynamic>.from(moiData);

    // Remove all listeners temporarily
    _denomControllers.forEach((_, controller) {
      controller.removeListener(_calculateTotal);
    });

    // Load the selected entry for editing
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

      // Load persons
      if (moiData['persons'] != null) {
        List<dynamic> personsList = moiData['persons'] as List;
        if (personsList.isNotEmpty) {
          var person1 = personsList[0];
          _init1Controller.text = person1['init'] ?? '';
          _name1Controller.text = person1['name'] ?? '';
          _qualification1Controller.text = person1['qualification'] ?? '';
          _job1Controller.text = person1['job'] ?? '';
        } else {
          _init1Controller.clear();
          _name1Controller.clear();
          _qualification1Controller.clear();
          _job1Controller.clear();
        }
        if (personsList.length > 1) {
          var person2 = personsList[1];
          _init2Controller.text = person2['init'] ?? '';
          _name2Controller.text = person2['name'] ?? '';
          _qualification2Controller.text = person2['qualification'] ?? '';
          _job2Controller.text = person2['job'] ?? '';
        } else {
          _init2Controller.clear();
          _name2Controller.clear();
          _qualification2Controller.clear();
          _job2Controller.clear();
        }
      }

      var amountValue = moiData['amount']?.toString() ?? '0';
      _amountController.text = amountValue;
      print('Amount controller set to: $amountValue');
    });

    // Load denominations only if payment method is CASH
    if (_paymentMethod == 'CASH') {
      await _loadDenominations(moiData['id']);
    } else {
      _denomControllers.forEach((_, controller) {
        controller.clear();
      });
    }

    // Re-add listeners
    _setupDenomListeners();

    print('After loading - Amount controller: ${_amountController.text}, Payment: $_paymentMethod');

    // Show a snackbar to indicate editing mode
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entry loaded for editing. Make changes and click "Save & Print"'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 3),
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

  void _calculateTotal() {
    if (_paymentMethod == 'CASH') {
      setState(() {
        int total = 0;
        _denomControllers.forEach((denom, controller) {
          int count = int.tryParse(controller.text) ?? 0;
          total += denom * count;
        });
        _amountController.text = total > 0 ? total.toString() : '';
      });
    }
  }

  int _getTotalAmount() {
    if (_paymentMethod == 'CASH') {
      int total = 0;
      _denomControllers.forEach((denom, controller) {
        int count = int.tryParse(controller.text) ?? 0;
        total += denom * count;
      });
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
    _denomControllers.forEach((_, controller) {
      count += int.tryParse(controller.text) ?? 0;
    });
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

  // Replace the _handleGroup method in your collect_moi_screen.dart with this:

  // Replace the _handleGroup method in your collect_moi_screen.dart with this:

  Future<void> _handleGroup() async {
    if (!_validateForm()) return;

    // CASE 1: Editing an existing entry that's ALREADY in a group
    if (_isEditMode && _editingMoiId != null && _currentGroupId != null) {
      // User is editing an existing grouped entry and clicked Group button
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This entry is already in a group! Use "Save & Print" to update it, or click "Add Entry" to add a new entry to the group.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return; // Don't proceed
    }

    // CASE 2: Editing an existing standalone entry (not in group) - Convert to group
    if (_isEditMode && _editingMoiId != null && _currentGroupId == null) {
      try {
        // Assign a new group ID to this existing entry
        int groupId = await _getNextGroupId();

        // Update the existing entry with group_id (no new serial number)
        final moiData = {
          'group_id': groupId,
          'updated_at': DateTime.now().toIso8601String(),
          'old_data': _originalData, // Store old data for audit
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

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Entry converted to group successfully! Add more entries to this group.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
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
      // Load next serial for NEW entries only
      await _loadNextSerialNo();

      int groupId;
      if (_currentGroupId != null) {
        // Use existing group
        groupId = _currentGroupId!;
      } else {
        // Create new group
        groupId = await _getNextGroupId();
      }

      final moiId = await _saveMoi(groupId, forceUpdate: false); // Never force update in group

      if (moiId != null) {
        setState(() {
          _currentGroupId = groupId;
        });

        await _loadGroupedMois();
        await _clearFormForNextEntry();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Entry added to group successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
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

  // Also update _saveMoi to be more explicit:
  Future<String?> _saveMoi(int? groupId, {bool forceUpdate = false}) async {
    List<Map<String, dynamic>> personsData = [];

    if (_name1Controller.text.trim().isNotEmpty) {
      personsData.add({
        'init': _init1Controller.text,
        'name': _name1Controller.text,
        'qualification': _qualification1Controller.text,
        'job': _job1Controller.text,
      });
    }

    if (_name2Controller.text.trim().isNotEmpty) {
      personsData.add({
        'init': _init2Controller.text,
        'name': _name2Controller.text,
        'qualification': _qualification2Controller.text,
        'job': _job2Controller.text,
      });
    }

    final moiData = {
      'event_id': _eventId,
      'operator_id': _operatorId,
      'serial_no': _serialNo,
      'amount': _getTotalAmount(),
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

      // Only update if explicitly in edit mode with an existing ID AND forceUpdate is true
      if (forceUpdate && _editingMoiId != null) {
        // UPDATE MODE - Store old data
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
        // INSERT NEW MOI
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

    final denomData = {
      'moi_id': moiId,
      'event_id': _eventId,
      'operator_id': _operatorId,
      'denom_500': int.tryParse(_denomControllers[500]!.text) ?? 0,
      'denom_200': int.tryParse(_denomControllers[200]!.text) ?? 0,
      'denom_100': int.tryParse(_denomControllers[100]!.text) ?? 0,
      'denom_50': int.tryParse(_denomControllers[50]!.text) ?? 0,
      'denom_20': int.tryParse(_denomControllers[20]!.text) ?? 0,
      'denom_10': int.tryParse(_denomControllers[10]!.text) ?? 0,
      'denom_5': int.tryParse(_denomControllers[5]!.text) ?? 0,
      'denom_1': int.tryParse(_denomControllers[1]!.text) ?? 0,
    };

    await _supabase
        .from('moi_denominations')
        .upsert(denomData);
  }

  Future<void> _handleSaveAndPrint() async {
    // Don't load next serial if we're editing
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
          // Pass forceUpdate=true to update the existing entry
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

      // All grouped entries saved
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All grouped entries saved successfully!'),
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
    }

    // Regular save for single entry
    if (!_validateForm()) return;

    try {
      // Pass forceUpdate based on edit mode
      await _saveMoi(_currentGroupId, forceUpdate: _isEditMode);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode ? 'MOI updated successfully!' : 'MOI saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        if (_isEditMode) {
          Navigator.pushReplacementNamed(
            context,
            '/operator/collection-details',
            arguments: {'id': _eventId, 'operator_id': _operatorId},
          );
        } else {
          await _clearFormForNextEntry();
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

// Helper method to check if form has any data
  bool _hasFormData() {
    return _name1Controller.text.trim().isNotEmpty ||
        _name2Controller.text.trim().isNotEmpty ||
        _getTotalAmount() > 0;
  }

  bool _validateForm() {
    bool hasValidPerson = _name1Controller.text.trim().isNotEmpty ||
        _name2Controller.text.trim().isNotEmpty;

    if (!hasValidPerson) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one person with a name')),
      );
      return false;
    }

    if (_paymentMethod == 'CASH') {
      if (_getTotalAmount() == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter denomination details')),
        );
        return false;
      }
    } else {
      if (_amountController.text.trim().isEmpty || _getTotalAmount() == 0) {
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

    _init1Controller.clear();
    _name1Controller.clear();
    _qualification1Controller.clear();
    _job1Controller.clear();
    _init2Controller.clear();
    _name2Controller.clear();
    _qualification2Controller.clear();
    _job2Controller.clear();

    _denomControllers.forEach((_, controller) {
      controller.clear();
    });

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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ready to add new entry to group'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _handleClear() async {
    setState(() {
      _phoneController.clear();
      _villageController.clear();
      _livingPlaceController.clear();
      _notesController.clear();
      _amountController.clear();
      _init1Controller.clear();
      _name1Controller.clear();
      _qualification1Controller.clear();
      _job1Controller.clear();
      _init2Controller.clear();
      _name2Controller.clear();
      _qualification2Controller.clear();
      _job2Controller.clear();
      _denomControllers.forEach((_, controller) => controller.clear());
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


  // Add after existing methods, before the build method

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
      // Save MOI first if not saved
      String? moiId = _editingMoiId;
      if (moiId == null) {
        moiId = await _saveMoi(_currentGroupId, forceUpdate: false);
        if (moiId == null) {
          throw Exception('Failed to save MOI');
        }
      }

      // Get operator name and event details
      final operatorName = await _getOperatorName();
      final eventDetails = await _getEventDetails();

      // Get denominations if CASH payment
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

      // Generate receipt
      final file = await MoiReceiptGenerator.generateSingleMoiReceipt(
        context: context,
        serialNo: _serialNo!,
        operatorName: operatorName,
        eventDate: eventDetails['event_date'],
        eventTime: eventDetails['event_time'],
        villageName: _villageController.text.trim(),
        livingPlace: _livingPlaceController.text.trim(),
        person1Init: _init1Controller.text.trim(),
        person1Name: _name1Controller.text.trim(),
        person2Init: _init2Controller.text.trim().isNotEmpty ? _init2Controller.text.trim() : null,
        person2Name: _name2Controller.text.trim().isNotEmpty ? _name2Controller.text.trim() : null,
        phone: _phoneController.text.trim(),
        amount: _getTotalAmount(),
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

  // In your collect_moi_screen.dart, replace the _handleGenerateGroupReceipt method:

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

    // Show dialog to choose receipt type
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
        // Generate consolidated group receipt
        double totalAmount = 0.0;  // CHANGED to double
        Map<int, int> totalDenominations = {
          500: 0, 200: 0, 100: 0, 50: 0, 20: 0, 10: 0, 5: 0, 1: 0,
        };

        // Load denominations for all entries
        for (var entry in _groupedMois) {
          // Handle amount as dynamic type and convert safely
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
          totalAmount: totalAmount,  // Now passing double
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
        // Generate individual receipts for each entry
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Generating ${_groupedMois.length} receipts...'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 3),
            ),
          );
        }

        // Load denominations for all entries first
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

    return Scaffold(
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
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSerialAndActions(),
            const SizedBox(height: 16),
            _buildTextField('Mobile Number', _phoneController),
            const SizedBox(height: 16),
            _buildVillageAndLivingPlace(),
            const SizedBox(height: 16),
            _buildPersonVertical(
              'Person 1',
              _init1Controller,
              _name1Controller,
              _qualification1Controller,
              _job1Controller,
            ),
            const SizedBox(height: 16),
            _buildPersonVertical(
              'Person 2',
              _init2Controller,
              _name2Controller,
              _qualification2Controller,
              _job2Controller,
            ),
            const SizedBox(height: 16),
            _buildTextField('Notes', _notesController, maxLines: 3),
            const SizedBox(height: 16),
            _buildPaymentMethod(),
            const SizedBox(height: 16),
            if (_paymentMethod == 'CASH')
              _buildDenominations()
            else
              _buildAmountField(),
            const SizedBox(height: 16),
            if (_groupedMois.isNotEmpty) _buildMoiDetails(),
            const SizedBox(height: 16),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildSerialAndActions() {
    return Container(
      padding: const EdgeInsets.all(16),
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: Text(
                  'O${_serialNo?.toString() ?? '0'}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          // Hide action buttons when in edit mode OR when a group is active
          if (!_isEditMode && _currentGroupId == null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildActionButton('Sample Receipt', () {})),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton('Cash Drawing', () {
                    Navigator.pushNamed(
                      context,
                      '/operator/cash_withdrawal',
                      arguments: {'id': _eventId, 'operator_id': _operatorId},
                    );
                  }),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton('Exchange\nDenomination', () {
                    Navigator.pushNamed(
                      context,
                      '/operator/exchange-denomination',
                      arguments: {'id': _eventId, 'operator_id': _operatorId},
                    );
                  }),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton('Collection Details', () {
                    Navigator.pushNamed(
                      context,
                      '/operator/collection-details',
                      arguments: {'id': _eventId, 'operator_id': _operatorId},
                    );
                  }),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback onPressed) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 2),
        color: Colors.white,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: maxLines,
            decoration: const InputDecoration(border: InputBorder.none),
          ),
        ],
      ),
    );
  }

  Widget _buildVillageAndLivingPlace() {
    return Container(
      padding: const EdgeInsets.all(16),
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
                const Text('Village Name', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _villageController,
                  decoration: const InputDecoration(border: InputBorder.none),
                ),
              ],
            ),
          ),
          Container(width: 2, height: 60, color: Colors.black, margin: const EdgeInsets.symmetric(horizontal: 16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Living Place', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _livingPlaceController,
                  decoration: const InputDecoration(border: InputBorder.none),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonVertical(
      String title,
      TextEditingController initController,
      TextEditingController nameController,
      TextEditingController qualificationController,
      TextEditingController jobController,
      ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildPersonField('Init', initController),
          const SizedBox(height: 12),
          _buildPersonField('Name', nameController),
          const SizedBox(height: 12),
          _buildPersonField('Qualification', qualificationController),
          const SizedBox(height: 12),
          _buildPersonField('Job', jobController),
        ],
      ),
    );
  }

  Widget _buildPersonField(String label, TextEditingController controller) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1)),
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethod() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Payment Method', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('Cash'),
                  value: 'CASH',
                  groupValue: _paymentMethod,
                  onChanged: (value) {
                    setState(() {
                      _paymentMethod = value!;
                      if (_amountController.text.isNotEmpty) {
                        _amountController.clear();
                      }
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('Check/\nAdvance/UPI'),
                  value: 'OTHERS',
                  groupValue: _paymentMethod,
                  onChanged: (value) {
                    setState(() {
                      _paymentMethod = value!;
                      _denomControllers.forEach((_, controller) => controller.clear());
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Amount', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            height: 50,
            decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 2)),
            child: TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            title: const Text('Uncle'),
            value: _isUncle,
            onChanged: (value) {
              setState(() {
                _isUncle = value ?? false;
              });
            },
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
    );
  }

  Widget _buildDenominations() {
    final denoms = [500, 200, 100, 50, 20, 10, 5, 1];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Denomination', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...denoms.map((denom) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildDenomRow(denom),
          )),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Count:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('${_getTotalCount()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Amount:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Flexible(
                      child: Text(
                        '₹${_getTotalAmount()}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            title: const Text('Uncle'),
            value: _isUncle,
            onChanged: (value) {
              setState(() {
                _isUncle = value ?? false;
              });
            },
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
    );
  }

  Widget _buildDenomRow(int denom) {
    final controller = _denomControllers[denom]!;
    int count = int.tryParse(controller.text) ?? 0;
    int total = denom * count;

    return Row(
      children: [
        Container(
          width: 80,
          height: 40,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 2),
            color: Colors.grey[300],
          ),
          child: Center(
            child: Text('₹ $denom', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
        const SizedBox(width: 8),
        const Text('x', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 2)),
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: '0',
                hintStyle: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Text('=', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Container(
          width: 100,
          height: 40,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 2),
            color: Colors.grey[200],
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  total.toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMoiDetails() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.black, width: 2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Moi Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (_currentGroupId != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      border: Border.all(color: Colors.blue, width: 2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Group ID - $_currentGroupId',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            child: _groupedMois.isEmpty
                ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Grouped entries will appear here...', style: TextStyle(color: Colors.grey)),
            )
                : ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.all(12),
              itemCount: _groupedMois.length,
              separatorBuilder: (context, index) => const Divider(color: Colors.black, thickness: 1, height: 16),
              itemBuilder: (context, index) {
                final moi = _groupedMois[index];
                final isCurrentlyEditing = _editingMoiId == moi['id'];

                return InkWell(
                  onTap: () => _loadGroupedEntryForEdit(moi),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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
                                  fontSize: 14,
                                  color: isCurrentlyEditing ? Colors.blue : Colors.black,
                                ),
                              ),
                              if (moi['village_name'] != null)
                                Text(
                                  moi['village_name'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isCurrentlyEditing ? Colors.blue.shade700 : Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (isCurrentlyEditing)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'EDITING',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        Text(
                          '₹${moi['amount']}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
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

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 50,
                decoration: BoxDecoration(color: Colors.green, border: Border.all(color: Colors.black, width: 2)),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _handleSaveAndPrint,
                    child: const Center(
                      child: Text(
                        'Save & Print',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 50,
                decoration: BoxDecoration(color: Colors.blue, border: Border.all(color: Colors.black, width: 2)),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _handleGroup,
                    child: const Center(
                      child: Text(
                        'Group',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
            height: 50,
            decoration: BoxDecoration(color: Colors.teal, border: Border.all(color: Colors.black, width: 2)),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _handleGenerateGroupReceipt,
                child: const Center(
                  child: Text(
                    'Generate Group Receipt',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
            height: 50,
            decoration: BoxDecoration(color: Colors.teal, border: Border.all(color: Colors.black, width: 2)),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _handleGenerateSingleReceipt,
                child: const Center(
                  child: Text(
                    'Generate Single Receipt',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
            height: 50,
            decoration: BoxDecoration(color: Colors.purple, border: Border.all(color: Colors.black, width: 2)),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _handleAddEntry,
                child: const Center(
                  child: Text(
                    'ADD ENTRY',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(color: Colors.orange, border: Border.all(color: Colors.black, width: 2)),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _handleClear,
              child: const Center(
                child: Text(
                  'Clear',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
    _villageController.dispose();
    _livingPlaceController.dispose();
    _notesController.dispose();
    _amountController.dispose();
    _init1Controller.dispose();
    _name1Controller.dispose();
    _qualification1Controller.dispose();
    _job1Controller.dispose();
    _init2Controller.dispose();
    _name2Controller.dispose();
    _qualification2Controller.dispose();
    _job2Controller.dispose();
    _denomControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }
}