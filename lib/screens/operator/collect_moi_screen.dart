import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CollectMoiScreen extends StatefulWidget {
  const CollectMoiScreen({super.key});

  @override
  State<CollectMoiScreen> createState() => _CollectMoiScreenState();
}

class _CollectMoiScreenState extends State<CollectMoiScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  // Controllers
  final _serialNoController = TextEditingController();
  final _mobileController = TextEditingController();
  final _villageController = TextEditingController();
  final _livingPlaceController = TextEditingController();
  final _init1Controller = TextEditingController();
  final _name1Controller = TextEditingController();
  final _qualification1Controller = TextEditingController();
  final _job1Controller = TextEditingController();
  final _init2Controller = TextEditingController();
  final _name2Controller = TextEditingController();
  final _qualification2Controller = TextEditingController();
  final _job2Controller = TextEditingController();
  final _notesController = TextEditingController();
  final _amountController = TextEditingController();
  final _moiDetailsController = TextEditingController();

  // Denomination controllers
  final _denom500Controller = TextEditingController();
  final _denom200Controller = TextEditingController();
  final _denom100Controller = TextEditingController();
  final _denom50Controller = TextEditingController();
  final _denom20Controller = TextEditingController();
  final _denom10Controller = TextEditingController();
  final _denom1Controller = TextEditingController();

  int _totalCount = 0;
  double _totalAmount = 0.0;

  // Payment method - CASH or OTHERS
  String _paymentMethod = 'CASH';
  bool _isUncle = false;

  // Event data
  Map<String, dynamic>? eventData;

  // Current group_id for grouped entries
  int? _currentGroupId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get event data from navigation arguments
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map<String, dynamic>) {
      setState(() {
        eventData = args;
      });
      print('Event data received: ${eventData?['id']}');
      print('Operator ID received: ${eventData?['operator_id']}');
      _loadNextSerialNumber();
    }
  }

  Future<void> _loadNextSerialNumber() async {
    if (eventData == null) return;

    try {
      final eventId = eventData!['id'];

      // Get the highest serial number for this event
      final response = await _supabase
          .from('mois')
          .select('serial_no')
          .eq('event_id', eventId)
          .order('serial_no', ascending: false)
          .limit(1);

      int nextSerial = 1;
      if (response.isNotEmpty && response[0]['serial_no'] != null) {
        nextSerial = (response[0]['serial_no'] as int) + 1;
      }

      setState(() {
        _serialNoController.text = 'O$nextSerial';
      });
    } catch (e) {
      print('Error loading serial number: $e');
      setState(() {
        _serialNoController.text = 'O1';
      });
    }
  }

  Future<int> _getNextGroupId() async {
    if (eventData == null) return 1;

    try {
      final eventId = eventData!['id'];

      // Get the highest group_id for this event
      final response = await _supabase
          .from('mois')
          .select('group_id')
          .eq('event_id', eventId)
          .not('group_id', 'is', null)
          .order('group_id', ascending: false)
          .limit(1);

      int nextGroupId = 1;
      if (response.isNotEmpty && response[0]['group_id'] != null) {
        nextGroupId = (response[0]['group_id'] as int) + 1;
      }

      return nextGroupId;
    } catch (e) {
      print('Error loading group_id: $e');
      return 1;
    }
  }

  @override
  void dispose() {
    _serialNoController.dispose();
    _mobileController.dispose();
    _villageController.dispose();
    _livingPlaceController.dispose();
    _init1Controller.dispose();
    _name1Controller.dispose();
    _qualification1Controller.dispose();
    _job1Controller.dispose();
    _init2Controller.dispose();
    _name2Controller.dispose();
    _qualification2Controller.dispose();
    _job2Controller.dispose();
    _notesController.dispose();
    _amountController.dispose();
    _moiDetailsController.dispose();
    _denom500Controller.dispose();
    _denom200Controller.dispose();
    _denom100Controller.dispose();
    _denom50Controller.dispose();
    _denom20Controller.dispose();
    _denom10Controller.dispose();
    _denom1Controller.dispose();
    super.dispose();
  }

  void _calculateDenomination() {
    int count500 = int.tryParse(_denom500Controller.text) ?? 0;
    int count200 = int.tryParse(_denom200Controller.text) ?? 0;
    int count100 = int.tryParse(_denom100Controller.text) ?? 0;
    int count50 = int.tryParse(_denom50Controller.text) ?? 0;
    int count20 = int.tryParse(_denom20Controller.text) ?? 0;
    int count10 = int.tryParse(_denom10Controller.text) ?? 0;
    int count1 = int.tryParse(_denom1Controller.text) ?? 0;

    setState(() {
      _totalCount =
          count500 + count200 + count100 + count50 + count20 + count10 + count1;
      _totalAmount = (count500 * 500) + (count200 * 200) + (count100 * 100) +
          (count50 * 50) + (count20 * 20) + (count10 * 10) + (count1 * 1);
      _amountController.text = _totalAmount.toStringAsFixed(0);
    });
  }

  void _clearAllFields() {
    setState(() {
      _mobileController.clear();
      _villageController.clear();
      _livingPlaceController.clear();
      _init1Controller.clear();
      _name1Controller.clear();
      _qualification1Controller.clear();
      _job1Controller.clear();
      _init2Controller.clear();
      _name2Controller.clear();
      _qualification2Controller.clear();
      _job2Controller.clear();
      _notesController.clear();
      _amountController.clear();
      _moiDetailsController.clear(); // Clear moi details too
      _denom500Controller.clear();
      _denom200Controller.clear();
      _denom100Controller.clear();
      _denom50Controller.clear();
      _denom20Controller.clear();
      _denom10Controller.clear();
      _denom1Controller.clear();
      _paymentMethod = 'CASH';
      _isUncle = false;
      _totalCount = 0;
      _totalAmount = 0.0;
      _currentGroupId = null; // Reset group ID
    });

    // Reload next serial number
    _loadNextSerialNumber();
  }

  void _clearFieldsExceptMoiDetails() {
    setState(() {
      _mobileController.clear();
      _villageController.clear();
      _livingPlaceController.clear();
      _init1Controller.clear();
      _name1Controller.clear();
      _qualification1Controller.clear();
      _job1Controller.clear();
      _init2Controller.clear();
      _name2Controller.clear();
      _qualification2Controller.clear();
      _job2Controller.clear();
      _notesController.clear();
      _amountController.clear();
      _denom500Controller.clear();
      _denom200Controller.clear();
      _denom100Controller.clear();
      _denom50Controller.clear();
      _denom20Controller.clear();
      _denom10Controller.clear();
      _denom1Controller.clear();
      _paymentMethod = 'CASH';
      _isUncle = false;
      _totalCount = 0;
      _totalAmount = 0.0;
      // Keep _currentGroupId as is for grouping
    });
  }

  String _generatePersonSummary() {
    List<String> summaries = [];
    double currentAmount = double.tryParse(_amountController.text) ?? 0.0;

    // Add Person 1 if has data
    if (_name1Controller.text.isNotEmpty) {
      String person1 = '${_init1Controller.text} ${_name1Controller.text}';
      summaries.add(person1);
    }

    // Add Person 2 if has data
    if (_name2Controller.text.isNotEmpty) {
      String person2 = '${_init2Controller.text} ${_name2Controller.text}';
      summaries.add(person2);
    }

    return summaries.join(', ') +
        (currentAmount > 0 ? ' - ₹${currentAmount.toStringAsFixed(0)}' : '');
  }

  Future<void> _handleGroup() async {
    // Validation
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter amount')),
      );
      return;
    }

    if (_name1Controller.text.isEmpty && _name2Controller.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least one person details')),
      );
      return;
    }

    String summary = _generatePersonSummary();

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add to Group'),
          content: Text('Save this entry to group?\n\n$summary'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Add & Save'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final eventId = eventData?['id'];
      final operatorId = eventData?['operator_id'];

      if (eventId == null || operatorId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event or Operator ID not found')),
        );
        return;
      }

      // Get or create group_id
      if (_currentGroupId == null) {
        _currentGroupId = await _getNextGroupId();
      }

      // Prepare persons data for current entry
      List<Map<String, dynamic>> personsData = [];
      if (_name1Controller.text.isNotEmpty) {
        personsData.add({
          'init': _init1Controller.text,
          'name': _name1Controller.text,
          'qualification': _qualification1Controller.text,
          'job': _job1Controller.text,
        });
      }
      if (_name2Controller.text.isNotEmpty) {
        personsData.add({
          'init': _init2Controller.text,
          'name': _name2Controller.text,
          'qualification': _qualification2Controller.text,
          'job': _job2Controller.text,
        });
      }

      // Save to database immediately
      final response = await _supabase.from('mois').insert({
        'event_id': eventId,
        'operator_id': operatorId,
        'serial_no': int.tryParse(_serialNoController.text.replaceAll('O', '')),
        'amount': double.parse(_amountController.text),
        'payment_method': _paymentMethod,
        'persons': personsData,
        'village_name': _villageController.text.trim(),
        'living_place': _livingPlaceController.text.trim(),
        'phone': _mobileController.text.trim(),
        'notes': _notesController.text.trim(),
        'is_uncle': _isUncle,
        'group_id': _currentGroupId,
      }).select();

      if (response.isNotEmpty) {
        final moiId = response[0]['id'];
        await _saveDenomination(moiId, eventId, operatorId);
        // Update Moi Details display
        setState(() {
          if (_moiDetailsController.text.isNotEmpty) {
            _moiDetailsController.text += '\n$summary';
          } else {
            _moiDetailsController.text = summary;
          }
        });

        _clearFieldsExceptMoiDetails();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entry saved to group. Add more or Save & Print for receipt.'),
            duration: Duration(seconds: 2),
          ),
        );

        // Increment serial number for next entry
        await _loadNextSerialNumber();
      }
    } catch (e) {
      print('Error saving grouped entry: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving: $e')),
      );
    }
  }

  Future<void> _showReceiptTypeDialog() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Receipt Type'),
          content: const Text('How would you like to print the receipts?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _saveAndPrint(isSingleReceipt: true);
              },
              child: const Text('Single Receipt'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _saveAndPrint(isSingleReceipt: false);
              },
              child: const Text('Group Receipt'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveAndPrint({required bool isSingleReceipt}) async {
    if (_amountController.text.isEmpty && _moiDetailsController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter amount or create group entries')),
      );
      return;
    }

    try {
      final eventId = eventData?['id'];
      final operatorId = eventData?['operator_id'];

      if (eventId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event ID not found')),
        );
        return;
      }

      if (operatorId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Operator ID not found. Please go back and try again.'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // If there's current form data, save it
      if (_amountController.text.isNotEmpty) {
        // Prepare persons data
        List<Map<String, dynamic>> personsData = [];
        if (_name1Controller.text.isNotEmpty) {
          personsData.add({
            'init': _init1Controller.text,
            'name': _name1Controller.text,
            'qualification': _qualification1Controller.text,
            'job': _job1Controller.text,
          });
        }
        if (_name2Controller.text.isNotEmpty) {
          personsData.add({
            'init': _init2Controller.text,
            'name': _name2Controller.text,
            'qualification': _qualification2Controller.text,
            'job': _job2Controller.text,
          });
        }

        // Insert into database
        final response = await _supabase.from('mois').insert({
          'event_id': eventId,
          'operator_id': operatorId,
          'serial_no': int.tryParse(_serialNoController.text.replaceAll('O', '')),
          'amount': double.parse(_amountController.text),
          'payment_method': _paymentMethod,
          'persons': personsData,
          'village_name': _villageController.text.trim(),
          'living_place': _livingPlaceController.text.trim(),
          'phone': _mobileController.text.trim(),
          'notes': _notesController.text.trim(),
          'is_uncle': _isUncle,
          'group_id': _currentGroupId,
        }).select();

        if (response.isEmpty) {
          throw Exception('Failed to save entry');
        }
        final moiId = response[0]['id'];
        await _saveDenomination(moiId, eventId, operatorId);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isSingleReceipt
              ? 'Moi saved! Printing single receipts...'
              : 'Moi saved! Printing group receipt...'),
        ),
      );

      // TODO: Implement actual printing logic here
      // You can call a print function based on isSingleReceipt flag
      // For grouped entries, query DB with group_id = _currentGroupId

      // Clear everything after successful save and print
      _clearAllFields();
    } catch (e) {
      print('Error saving moi: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving moi: $e'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
  Future<void> _handleSaveAndPrint() async {
    if (_moiDetailsController.text.isNotEmpty) {
      // Show dialog if there are grouped entries
      await _showReceiptTypeDialog();
    } else {
      // Direct save for single entry
      await _saveAndPrint(isSingleReceipt: true);
    }
  }

  Future<void> _saveDenomination(String moiId, String eventId, String operatorId) async {
    // Only save denomination if payment method is CASH
    if (_paymentMethod != 'CASH') return;

    try {
      await _supabase.from('moi_denominations').insert({
        'moi_id': moiId,
        'event_id': eventId,
        'operator_id': operatorId,
        'denom_500': int.tryParse(_denom500Controller.text) ?? 0,
        'denom_200': int.tryParse(_denom200Controller.text) ?? 0,
        'denom_100': int.tryParse(_denom100Controller.text) ?? 0,
        'denom_50': int.tryParse(_denom50Controller.text) ?? 0,
        'denom_20': int.tryParse(_denom20Controller.text) ?? 0,
        'denom_10': int.tryParse(_denom10Controller.text) ?? 0,
        'denom_1': int.tryParse(_denom1Controller.text) ?? 0,
      });
    } catch (e) {
      print('Error saving denomination: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Collect Moi',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Header with Serial No and Action Buttons
                Container(
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
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            width: 100,
                            height: 40,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black, width: 2),
                              color: Colors.grey[200],
                            ),
                            child: Center(
                              child: Text(
                                _serialNoController.text,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildTopButton('Sample Receipt'),
                          _buildTopButton('Cash Drawing'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildTopButton('Exchange Denomination'),
                          _buildTopButton('Collection Details'),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Mobile Number
                _buildInputField('Mobile Number', _mobileController,
                    keyboardType: TextInputType.phone),

                const SizedBox(height: 16),

                // Village Name and Living Place
                Container(
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
                            const Text(
                              'Village Name',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextField(
                              controller: _villageController,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 2,
                        height: 60,
                        color: Colors.black,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Living Place',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextField(
                                controller: _livingPlaceController,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Person 1 Details (Vertical Layout)
                _buildPersonVertical(
                  'Person 1',
                  _init1Controller,
                  _name1Controller,
                  _qualification1Controller,
                  _job1Controller,
                ),

                const SizedBox(height: 16),

                // Person 2 Details (Vertical Layout)
                _buildPersonVertical(
                  'Person 2',
                  _init2Controller,
                  _name2Controller,
                  _qualification2Controller,
                  _job2Controller,
                ),

                const SizedBox(height: 16),

                // Notes
                _buildNotesField(),

                const SizedBox(height: 16),

                // Payment Method Selection
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment Method',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
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
                                });
                              },
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Check/Advance/UPI'),
                              value: 'OTHERS',
                              groupValue: _paymentMethod,
                              onChanged: (value) {
                                setState(() {
                                  _paymentMethod = value!;
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
                ),

                const SizedBox(height: 16),

                // Amount Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Amount',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 50,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                        child: TextField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Checkbox(
                            value: _isUncle,
                            onChanged: (value) {
                              setState(() {
                                _isUncle = value ?? false;
                              });
                            },
                          ),
                          const Text('Uncle'),
                        ],
                      ),
                    ],
                  ),
                ),

                // Denomination Table (Only show if payment method is CASH)
                if (_paymentMethod == 'CASH') ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Denomination',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildDenomRow('500', _denom500Controller),
                        const SizedBox(height: 8),
                        _buildDenomRow('200', _denom200Controller),
                        const SizedBox(height: 8),
                        _buildDenomRow('100', _denom100Controller),
                        const SizedBox(height: 8),
                        _buildDenomRow('50', _denom50Controller),
                        const SizedBox(height: 8),
                        _buildDenomRow('20', _denom20Controller),
                        const SizedBox(height: 8),
                        _buildDenomRow('10', _denom10Controller),
                        const SizedBox(height: 8),
                        _buildDenomRow('1', _denom1Controller),
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
                                  Text(
                                    'Total Count: $_totalCount',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total Amount:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Flexible(
                                    child: Text(
                                      '₹${_totalAmount.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Moi Details - REPLACE THE ENTIRE CONTAINER WITH THIS:
                _buildMoiDetailsSection(),

                const SizedBox(height: 20),

                // Action Buttons - Updated with 3 buttons
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _handleSaveAndPrint,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.zero,
                                  side: const BorderSide(
                                      color: Colors.black, width: 2),
                                ),
                              ),
                              child: const Text(
                                'Save & Print',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _handleGroup,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.zero,
                                  side: const BorderSide(
                                      color: Colors.black, width: 2),
                                ),
                              ),
                              child: const Text(
                                'Group',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _clearAllFields,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                            side: const BorderSide(
                                color: Colors.black, width: 2),
                          ),
                        ),
                        child: const Text(
                          'Clear',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopButton(String label) {
    return Expanded(
      child: Container(
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black, width: 2),
        ),
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: () {
              if (label == 'Cash Drawing') {
                Navigator.pushNamed(
                  context,
                  '/operator/cash_withdrawal',
                  arguments: eventData,
                );
              } else if (label == 'Exchange Denomination') {
                Navigator.pushNamed(
                  context,
                  '/operator/exchange-denomination',
                  arguments: eventData,
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$label clicked')),
                );
              }
            },
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller,
      {TextInputType? keyboardType}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: const InputDecoration(
              border: InputBorder.none,
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          // Init
          Row(
            children: [
              const SizedBox(
                width: 100,
                child: Text(
                  'Init',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  child: TextField(
                    controller: initController,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Name
          Row(
            children: [
              const SizedBox(
                width: 100,
                child: Text(
                  'Name',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  child: TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Qualification
          Row(
            children: [
              const SizedBox(
                width: 100,
                child: Text(
                  'Qualification',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  child: TextField(
                    controller: qualificationController,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Job
          Row(
            children: [
              const SizedBox(
                width: 100,
                child: Text(
                  'Job',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  child: TextField(
                    controller: jobController,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotesField() {
    return Container(
      height: 100,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Notes',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _notesController,
              maxLines: null,
              decoration: const InputDecoration(
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDenomRow(String denomination, TextEditingController controller) {
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
            child: Text(
              '₹ $denomination',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'x',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: '0',
              ),
              onChanged: (value) => _calculateDenomination(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          '=',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
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
                  ((int.tryParse(controller.text) ?? 0) *
                      int.parse(denomination))
                      .toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMoiDetailsSection() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.black, width: 2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Moi Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _moiDetailsController,
                maxLines: null,
                expands: true,
                readOnly: true,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Grouped entries will appear here...',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

}