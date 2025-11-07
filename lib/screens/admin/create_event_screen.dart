import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import '../../services/receipt_generator.dart';
import '../../services/auth_service.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  Map<String, dynamic>? _editingEvent;
  bool _isEditMode = false;
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();

  // Controllers
  final _customerName = TextEditingController();
  final _contactNumber = TextEditingController();
  final _title = TextEditingController();
  final _venue = TextEditingController();
  final _city = TextEditingController();
  final _eventFor = TextEditingController();
  final _totalComputers = TextEditingController();
  final _bookedAmount = TextEditingController();
  final _advanceAmount = TextEditingController();
  final _discountAmount = TextEditingController();
  final _referenceBy = TextEditingController();
  final _remark = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _selectedTime;
  String? _selectedEventType;
  List<String> _selectedOperators = [];
  String _selectedStatus = 'Upcoming';
  bool _skipDenomination = false;
  bool _skipPrint = false;
  bool _loading = false;

  List<Map<String, dynamic>> _eventTypes = [];
  List<Map<String, dynamic>> _operators = [];

  @override
  void initState() {
    super.initState();
    _loadEventTypes();
    _loadOperators();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is Map<String, dynamic>) {
        setState(() {
          _editingEvent = args;
          _isEditMode = true;
        });
        _populateFields();
      }
    });
  }

  Future<void> _loadEventTypes() async {
    try {
      final data = await _auth.client
          .from('event_types')
          .select()
          .order('name');

      setState(() {
        _eventTypes = List<Map<String, dynamic>>.from(data);
        if (_eventTypes.isNotEmpty) {
          _selectedEventType = _eventTypes[0]['id'];
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading event types: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadOperators() async {
    try {
      final data = await _auth.client
          .from('users')
          .select('id, full_name, phone')
          .eq('role', 'operator')
          .eq('is_active', true)
          .order('full_name');

      setState(() {
        _operators = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading operators: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _populateFields() {
    if (_editingEvent == null) return;

    _customerName.text = _editingEvent!['customer_name'] ?? '';
    _contactNumber.text = _editingEvent!['customer_phone'] ?? '';
    _title.text = _editingEvent!['title'] ?? '';
    _venue.text = _editingEvent!['venue'] ?? '';
    _city.text = _editingEvent!['city'] ?? '';
    _totalComputers.text = _editingEvent!['total_computers']?.toString() ?? '0';
    _bookedAmount.text = _editingEvent!['booked_amount']?.toString() ?? '0.00';
    _advanceAmount.text = _editingEvent!['advance_amount']?.toString() ?? '0.00';
    _discountAmount.text = _editingEvent!['discount_amount']?.toString() ?? '0.00';
    _referenceBy.text = _editingEvent!['referral_by'] ?? '';
    _remark.text = _editingEvent!['remark'] ?? '';

    if (_editingEvent!['event_date'] != null) {
      _selectedDate = DateTime.parse(_editingEvent!['event_date']);
    }

    if (_editingEvent!['event_time'] != null) {
      final timeParts = _editingEvent!['event_time'].split(':');
      _selectedTime = TimeOfDay(
        hour: int.parse(timeParts[0]),
        minute: int.parse(timeParts[1]),
      );
    }

    _selectedEventType = _editingEvent!['event_type'];

    final status = _editingEvent!['status']?.toString() ?? 'upcoming';
    _selectedStatus = status[0].toUpperCase() + status.substring(1).toLowerCase();

    _loadAssignedOperators();
  }

  Future<void> _loadAssignedOperators() async {
    if (_editingEvent == null) return;

    try {
      final assignments = await _auth.client
          .from('event_assignments')
          .select('operator_id')
          .eq('event_id', _editingEvent!['id']);

      if (assignments != null && mounted) {
        setState(() {
          _selectedOperators = assignments
              .map((a) => a['operator_id'] as String)
              .toList();
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  static const platform = MethodChannel('com.example.moi_virunthu/whatsapp');
  Future<void> _generateReceiptAndSendWhatsApp() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedEventType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an event type'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // First, save the event to database
      final currentUser = _auth.client.auth.currentUser;

      final eventData = {
        'title': _title.text.trim(),
        'customer_name': _customerName.text.trim().isEmpty ? null : _customerName.text.trim(),
        'customer_phone': _contactNumber.text.trim().isEmpty ? null : _contactNumber.text.trim(),
        'event_date': _selectedDate.toIso8601String().split('T')[0],
        'event_time': _selectedTime != null
            ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}:00'
            : null,
        'venue': _venue.text.trim().isEmpty ? null : _venue.text.trim(),
        'city': _city.text.trim().isEmpty ? null : _city.text.trim(),
        'total_computers': int.tryParse(_totalComputers.text) ?? 0,
        'booked_amount': double.tryParse(_bookedAmount.text) ?? 0,
        'advance_amount': double.tryParse(_advanceAmount.text) ?? 0,
        'discount_amount': double.tryParse(_discountAmount.text) ?? 0,
        'referral_by': _referenceBy.text.trim().isEmpty ? null : _referenceBy.text.trim(),
        'remark': _remark.text.trim().isEmpty ? null : _remark.text.trim(),
        'status': _selectedStatus.toLowerCase(),
        'event_type': _selectedEventType,
      };

      String eventId;

      if (_isEditMode && _editingEvent != null) {
        eventData['updated_at'] = DateTime.now().toIso8601String();

        await _auth.client
            .from('events')
            .update(eventData)
            .eq('id', _editingEvent!['id']);

        eventId = _editingEvent!['id'];
        await _updateOperatorAssignment(eventId);
      } else {
        eventData['created_by'] = currentUser?.id;

        final result = await _auth.client
            .from('events')
            .insert([eventData])
            .select('id')
            .single();

        eventId = result['id'];

        if (_selectedOperators.isNotEmpty) {
          final assignments = _selectedOperators.map((operatorId) => {
            'event_id': eventId,
            'operator_id': operatorId,
          }).toList();

          await _auth.client.from('event_assignments').insert(assignments);
        }

        setState(() {
          _isEditMode = true;
          _editingEvent = {'id': eventId};
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event saved successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }

      // Get event type name
      String eventTypeName = 'Event';
      if (_selectedEventType != null) {
        final eventType = _eventTypes.firstWhere(
              (type) => type['id'] == _selectedEventType,
          orElse: () => {'name': 'Event'},
        );
        eventTypeName = eventType['name'];
      }

      // Generate PDF using WebView
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Generating receipt...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      }

      final file = await ReceiptGenerator.generateReceiptPDF(
        context: context,
        customerName: _customerName.text,
        venue: _venue.text,
        city: _city.text,
        contactNumber: _contactNumber.text,
        eventTypeName: eventTypeName,
        selectedDate: _selectedDate,
        selectedTime: _selectedTime,
      );

      if (file == null) {
        throw Exception('Failed to generate PDF');
      }

      // Format phone number for WhatsApp
      String phoneNumber = _contactNumber.text.trim();
      phoneNumber = phoneNumber.replaceAll(RegExp(r'\D'), '');

      if (phoneNumber.length == 10) {
        phoneNumber = '91$phoneNumber';
      } else if (phoneNumber.startsWith('+')) {
        phoneNumber = phoneNumber.substring(1);
      }

      // Create WhatsApp message
      final whatsappMessage = 'வணக்கம் ${_customerName.text}!\n\n'
          'உங்கள் $eventTypeName பதிவு உறுதி செய்யப்பட்டது.\n\n'
          '📅 தேதி: ${DateFormat('dd-MM-yyyy').format(_selectedDate)}\n'
          '🏛️ இடம்: ${_venue.text}\n'
          '📍 நகரம்: ${_city.text}\n\n'
          'உங்கள் ரசீது இணைக்கப்பட்டுள்ளது.\n\n'
          'நன்றி!\n'
          'பேச்சி மொபைல் டெக்';

      // Send via WhatsApp
      try {
        final result = await platform.invokeMethod('sendToWhatsApp', {
          'phone': phoneNumber,
          'message': whatsappMessage,
          'filePath': file.path,
        });

        if (mounted) {
          if (result == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Opening WhatsApp for ${_customerName.text}'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('WhatsApp not installed. Please install WhatsApp.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (e) {
        print('Error invoking platform method: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error opening WhatsApp: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _showEventTypeDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    bool isCreating = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Manage Event Types'),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView( // ADD THIS
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Existing Event Types:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 150), // CHANGED from 200 to 150
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: _eventTypes.isEmpty
                          ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('No event types yet'),
                      )
                          : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _eventTypes.length,
                        separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey[300]),
                        itemBuilder: (context, index) {
                          final type = _eventTypes[index];
                          return ListTile(
                            dense: true,
                            title: Text(type['name']),
                            subtitle: type['description'] != null
                                ? Text(
                              type['description'],
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            )
                                : null,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    const Text(
                      'Create New Event Type:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Event Type Name *',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        isDense: true,
                      ),
                      maxLines: 3, // CHANGED from 2 to 3
                    ),
                  ],
                ),
              ), // CLOSE SingleChildScrollView
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: isCreating
                    ? null
                    : () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Event type name is required'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  setDialogState(() => isCreating = true);

                  try {
                    final currentUser = _auth.client.auth.currentUser;

                    final result = await _auth.client
                        .from('event_types')
                        .insert({
                      'name': name,
                      'description': descriptionController.text.trim().isEmpty
                          ? null
                          : descriptionController.text.trim(),
                      'created_by': currentUser?.id,
                    })
                        .select()
                        .single();

                    await _loadEventTypes();

                    setState(() {
                      _selectedEventType = result['id'];
                    });

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Event type created successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    setDialogState(() => isCreating = false);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error creating event type: ${e.toString()}'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB846D7),
                  foregroundColor: Colors.white,
                ),
                child: isCreating
                    ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  double get _balanceAmount {
    final booked = double.tryParse(_bookedAmount.text) ?? 0;
    final advance = double.tryParse(_advanceAmount.text) ?? 0;
    final discount = double.tryParse(_discountAmount.text) ?? 0;
    final balanceLive = _editingEvent?['balance_live_amount'] != null
        ? double.tryParse(_editingEvent!['balance_live_amount'].toString()) ?? 0
        : 0;

    return booked - advance - discount - balanceLive;
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  // Replace the _save() method with this updated version:

  Future<void> _save({bool shouldExit = false}) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedEventType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an event type'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final currentUser = _auth.client.auth.currentUser;

      final eventData = {
        'title': _title.text.trim(),
        'customer_name': _customerName.text.trim().isEmpty ? null : _customerName.text.trim(),
        'customer_phone': _contactNumber.text.trim().isEmpty ? null : _contactNumber.text.trim(),
        'event_date': _selectedDate.toIso8601String().split('T')[0],
        'event_time': _selectedTime != null
            ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}:00'
            : null,
        'venue': _venue.text.trim().isEmpty ? null : _venue.text.trim(),
        'city': _city.text.trim().isEmpty ? null : _city.text.trim(),
        'total_computers': int.tryParse(_totalComputers.text) ?? 0,
        'booked_amount': double.tryParse(_bookedAmount.text) ?? 0,
        'advance_amount': double.tryParse(_advanceAmount.text) ?? 0,
        'discount_amount': double.tryParse(_discountAmount.text) ?? 0,
        'referral_by': _referenceBy.text.trim().isEmpty ? null : _referenceBy.text.trim(),
        'remark': _remark.text.trim().isEmpty ? null : _remark.text.trim(),
        'status': _selectedStatus.toLowerCase(),
        'event_type': _selectedEventType,
      };

      String eventId;

      if (_isEditMode && _editingEvent != null) {
        eventData['updated_at'] = DateTime.now().toIso8601String();

        await _auth.client
            .from('events')
            .update(eventData)
            .eq('id', _editingEvent!['id']);

        eventId = _editingEvent!['id'];

        await _updateOperatorAssignment(eventId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Event updated successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        eventData['created_by'] = currentUser?.id;

        final result = await _auth.client
            .from('events')
            .insert([eventData])
            .select('id')
            .single();

        eventId = result['id'];

        if (_selectedOperators.isNotEmpty) {
          final assignments = _selectedOperators.map((operatorId) => {
            'event_id': eventId,
            'operator_id': operatorId,
          }).toList();

          await _auth.client.from('event_assignments').insert(assignments);
        }

        // Update state to edit mode after first save
        setState(() {
          _isEditMode = true;
          _editingEvent = {'id': eventId};
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Event created successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }

      // Only exit if shouldExit is true
      if (mounted && shouldExit) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving event: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _updateOperatorAssignment(String eventId) async {
    try {
      await _auth.client
          .from('event_assignments')
          .delete()
          .eq('event_id', eventId);

      if (_selectedOperators.isNotEmpty) {
        final assignments = _selectedOperators.map((operatorId) => {
          'event_id': eventId,
          'operator_id': operatorId,
        }).toList();

        await _auth.client.from('event_assignments').insert(assignments);
      }
    } catch (e) {
      // Handle error
    }
  }

  void _clear() {
    _customerName.clear();
    _contactNumber.clear();
    _title.clear();
    _venue.clear();
    _city.clear();
    _eventFor.clear();
    _totalComputers.clear();
    _bookedAmount.clear();
    _advanceAmount.clear();
    _discountAmount.clear();
    _referenceBy.clear();
    _remark.clear();
    setState(() {
      _selectedDate = DateTime.now();
      _selectedTime = null;
      _selectedStatus = 'Upcoming';
      _selectedOperators.clear();
      _skipDenomination = false;
      _skipPrint = false;
      if (_eventTypes.isNotEmpty) {
        _selectedEventType = _eventTypes[0]['id'];
      }
    });
  }

  @override
  void dispose() {
    _customerName.dispose();
    _contactNumber.dispose();
    _title.dispose();
    _venue.dispose();
    _city.dispose();
    _eventFor.dispose();
    _totalComputers.dispose();
    _bookedAmount.dispose();
    _advanceAmount.dispose();
    _discountAmount.dispose();
    _referenceBy.dispose();
    _remark.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 2),
                  color: Colors.white,
                ),
                child: Text(
                  _isEditMode ? 'Edit Event' : 'Create Event',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 900),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[400]!),
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF7B3A99), Color(0xFF9B4DB8)],
                        ),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            'FESTIVAL',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 20),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            _buildFormRow(
                              label: 'Customer Name',
                              required: true,
                              isSmallScreen: isSmallScreen,
                              child: TextFormField(
                                controller: _customerName,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  isDense: true,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Customer name is required';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 16),

                            _buildFormRow(
                              label: 'Contact Number',
                              required: true,
                              isSmallScreen: isSmallScreen,
                              child: TextFormField(
                                controller: _contactNumber,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  isDense: true,
                                ),
                                keyboardType: TextInputType.phone,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Contact number is required';
                                  }
                                  if (value.length != 10) {
                                    return 'Contact number must be 10 digits';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 16),

                            _buildFormRow(
                              label: 'Event',
                              required: true,
                              isSmallScreen: isSmallScreen,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: _selectedEventType,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                        isDense: true,
                                      ),
                                      items: _eventTypes.map((type) {
                                        return DropdownMenuItem<String>(
                                          value: type['id'],
                                          child: Text(
                                            type['name'],
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() => _selectedEventType = value);
                                      },
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Event type is required';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    height: 48,
                                    width: 48,
                                    child: OutlinedButton(
                                      onPressed: _showEventTypeDialog,
                                      style: OutlinedButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        side: BorderSide(color: Colors.grey[400]!),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                      child: const Icon(Icons.add, size: 20, color: Colors.black),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            _buildFormRow(
                              label: 'Title',
                              required: true,
                              isSmallScreen: isSmallScreen,
                              child: TextFormField(
                                controller: _title,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  isDense: true,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Title is required';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 16),

                            _buildFormRow(
                              label: 'Date',
                              required: true,
                              isSmallScreen: isSmallScreen,
                              child: InkWell(
                                onTap: _selectDate,
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    suffixIcon: Icon(Icons.calendar_today, size: 20),
                                    isDense: true,
                                  ),
                                  child: Text(
                                    '${_selectedDate.day.toString().padLeft(2, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.year}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            _buildFormRow(
                              label: 'Time',
                              required: false,
                              isSmallScreen: isSmallScreen,
                              child: InkWell(
                                onTap: _selectTime,
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    suffixIcon: Icon(Icons.access_time, size: 20),
                                    isDense: true,
                                  ),
                                  child: Text(
                                    _selectedTime != null
                                        ? _selectedTime!.format(context)
                                        : '',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            _buildFormRow(
                              label: 'Venue',
                              required: true,
                              isSmallScreen: isSmallScreen,
                              child: TextFormField(
                                controller: _venue,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  isDense: true,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Venue is required';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 16),

                            _buildFormRow(
                              label: 'City',
                              required: true,
                              isSmallScreen: isSmallScreen,
                              child: TextFormField(
                                controller: _city,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  isDense: true,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'City is required';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 16),

                            _buildFormRow(
                              label: 'Event For',
                              required: false,
                              isSmallScreen: isSmallScreen,
                              child: TextFormField(
                                controller: _eventFor,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            _buildFormRow(
                              label: 'Operators',
                              required: false,
                              isSmallScreen: isSmallScreen,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_selectedOperators.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey[300]!),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: _selectedOperators.map((operatorId) {
                                          final operatorIndex = _operators.indexWhere((op) => op['id'] == operatorId);
                                          if (operatorIndex == -1) return const SizedBox.shrink();

                                          final operator = _operators[operatorIndex];
                                          return Chip(
                                            label: Text(operator['full_name'], style: const TextStyle(fontSize: 13)),
                                            deleteIcon: const Icon(Icons.close, size: 16),
                                            onDeleted: () {
                                              setState(() {
                                                _selectedOperators.remove(operatorId);
                                              });
                                            },
                                            visualDensity: VisualDensity.compact,
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  if (_selectedOperators.isNotEmpty)
                                    const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    key: ValueKey('operator_${_selectedOperators.length}_${_selectedOperators.hashCode}'),
                                    value: null,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      isDense: true,
                                      hintText: 'Add Operator',
                                    ),
                                    items: _operators
                                        .where((op) => !_selectedOperators.contains(op['id']))
                                        .map((operator) {
                                      return DropdownMenuItem<String>(
                                        value: operator['id'],
                                        child: Text(
                                          '${operator['full_name']} - ${operator['phone']}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      print('DEBUG: Dropdown value selected: $value');
                                      print('DEBUG: Current _selectedOperators BEFORE: $_selectedOperators');

                                      if (value != null && !_selectedOperators.contains(value)) {
                                        setState(() {
                                          _selectedOperators.add(value);
                                          print('DEBUG: Operator added successfully');
                                          print('DEBUG: Current _selectedOperators AFTER: $_selectedOperators');
                                          print('DEBUG: Total operators now: ${_selectedOperators.length}');
                                        });
                                      } else {
                                        print('DEBUG: Operator NOT added. value=$value, already exists=${_selectedOperators.contains(value)}');
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            _buildFormRow(
                              label: 'Total Computer Booked',
                              required: true,
                              isSmallScreen: isSmallScreen,
                              child: TextFormField(
                                controller: _totalComputers,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  isDense: true,
                                  hintText: '0', // ADD THIS LINE
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Total computers is required';
                                  }
                                  return null;
                                },
                              ),
                            ),

                            const SizedBox(height: 16),


// Replace the amount field sections in your create_event_screen.dart with these:

// Around line 1240-1280, replace the Booked Amount field:
                            _buildFormRow(
                              label: 'Booked Amount',
                              required: true,
                              isSmallScreen: isSmallScreen,
                              child: TextFormField(
                                controller: _bookedAmount,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  isDense: true,
                                  hintText: '0.00',
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                                ],
                                onChanged: (value) => setState(() {}),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Booked amount is required';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Replace Advance Amount field:
                            _buildFormRow(
                              label: 'Advance Amount',
                              required: false,
                              isSmallScreen: isSmallScreen,
                              child: TextFormField(
                                controller: _advanceAmount,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  isDense: true,
                                  hintText: '0.00',
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                                ],
                                onChanged: (value) => setState(() {}),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Replace Discount Amount field:
                            _buildFormRow(
                              label: 'Discount Amount',
                              required: false,
                              isSmallScreen: isSmallScreen,
                              child: TextFormField(
                                controller: _discountAmount,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  isDense: true,
                                  hintText: '0.00',
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                                ],
                                onChanged: (value) => setState(() {}),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // The Balance Amount field remains the same (read-only calculated field)
                            _buildFormRow(
                              label: 'Balance Amount',
                              required: false,
                              isSmallScreen: isSmallScreen,
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  fillColor: Colors.grey[200],
                                  filled: true,
                                  isDense: true,
                                ),
                                child: Text(
                                  _balanceAmount.toStringAsFixed(2),
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            _buildFormRow(
                              label: 'Reference By',
                              required: false,
                              isSmallScreen: isSmallScreen,
                              child: TextFormField(
                                controller: _referenceBy,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            _buildFormRow(
                              label: 'Remark',
                              required: false,
                              isSmallScreen: isSmallScreen,
                              child: TextFormField(
                                controller: _remark,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  isDense: true,
                                ),
                                maxLines: 3,
                              ),
                            ),
                            const SizedBox(height: 16),

                            _buildFormRow(
                              label: 'Status',
                              required: false,
                              isSmallScreen: isSmallScreen,
                              child: DropdownButtonFormField<String>(
                                value: _selectedStatus,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  isDense: true,
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'Upcoming', child: Text('Upcoming')),
                                  DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                                  DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled')),
                                ],
                                onChanged: (value) {
                                  setState(() => _selectedStatus = value!);
                                },
                              ),
                            ),
                            const SizedBox(height: 16),

                            if (isSmallScreen) ...[
                              Row(
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: _skipDenomination,
                                      onChanged: (value) {
                                        setState(() => _skipDenomination = value ?? false);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Skip Denomination',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: _skipPrint,
                                      onChanged: (value) {
                                        setState(() => _skipPrint = value ?? false);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Skip Print',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              Row(
                                children: [
                                  const SizedBox(width: 170),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: Checkbox(
                                            value: _skipDenomination,
                                            onChanged: (value) {
                                              setState(() => _skipDenomination = value ?? false);
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Skip Denomination',
                                          style: TextStyle(fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const SizedBox(width: 170),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: Checkbox(
                                            value: _skipPrint,
                                            onChanged: (value) {
                                              setState(() => _skipPrint = value ?? false);
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Skip Print',
                                          style: TextStyle(fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 24),

                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                // Update the buttons section in the build method:


                                // Replace the existing buttons with these:

                                SizedBox(
                                  width: isSmallScreen ? double.infinity : 120,
                                  height: 42,
                                  child: ElevatedButton(
                                    onPressed: _loading ? null : () => _save(shouldExit: false),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFB846D7),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    child: _loading
                                        ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                        : const Text(
                                      'SAVE',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),

                                // NEW: Generate Receipt Button
                                SizedBox(
                                  width: isSmallScreen ? double.infinity : 150,
                                  height: 42,
                                  child: ElevatedButton.icon(
                                    onPressed: _loading ? null : _generateReceiptAndSendWhatsApp,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF25D366),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    icon: _loading
                                        ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                        : const Icon(Icons.receipt_long, size: 18),
                                    label: const Text(
                                      'Receipt',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),


                                SizedBox(
                                  width: isSmallScreen ? double.infinity : 120,
                                  height: 42,
                                  child: OutlinedButton(
                                    onPressed: _clear,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.black,
                                      side: BorderSide(color: Colors.grey[400]!),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    child: const Text(
                                      'Clear',
                                      style: TextStyle(fontSize: 15),
                                    ),
                                  ),
                                ),

                                SizedBox(
                                  width: isSmallScreen ? double.infinity : 120,
                                  height: 42,
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.black,
                                      side: BorderSide(color: Colors.grey[400]!),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    child: const Text(
                                      'Exit',
                                      style: TextStyle(fontSize: 15),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormRow({
    required String label,
    required bool required,
    required Widget child,
    required bool isSmallScreen,
  }) {
    if (isSmallScreen) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[800],
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (required)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text(
                    '*',
                    style: TextStyle(color: Colors.red, fontSize: 14),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 170,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                const Spacer(),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                if (required)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text(
                      '*',
                      style: TextStyle(color: Colors.red, fontSize: 14),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: child),
      ],
    );
  }
}