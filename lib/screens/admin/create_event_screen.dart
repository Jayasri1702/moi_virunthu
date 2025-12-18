import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/receipt_generator.dart';
import '../../services/auth_service.dart';
import '../../utils/network_utils.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  Map<String, dynamic>? _editingEvent;
  bool _isEditMode = false;
  bool _skipWhatsApp = false;
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

  // In CreateEventScreen, replace the initState and _loadEventTypes methods:

  @override
  void initState() {
    super.initState();

    // ✅ FIX: Load editing event data first, THEN load event types
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is Map<String, dynamic>) {
        setState(() {
          _editingEvent = args;
          _isEditMode = true;
        });
        // Load event types first, then populate fields
        _loadEventTypesAndPopulate();
      } else {
        // Not editing, just load event types normally
        _loadEventTypes();
      }
    });

    _loadOperators();
  }

  // ✅ NEW METHOD: Load event types and then populate fields
  Future<void> _loadEventTypesAndPopulate() async {
    try {
      final data = await _auth.client
          .from('event_types')
          .select()
          .order('name');

      setState(() {
        _eventTypes = List<Map<String, dynamic>>.from(data);

        // ✅ DON'T set a default event type here when editing
        // It will be set in _populateFields()
      });

      // Now populate the fields (including event type from saved data)
      _populateFields();
      _loadAssignedOperators();

    } catch (e) {
      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          onRetry: _loadEventTypesAndPopulate,
          customMessage: 'Error loading event types',
        );
      }
    }
  }

  // ✅ UPDATE: Modified _loadEventTypes for non-edit mode
  Future<void> _loadEventTypes() async {
    try {
      final data = await _auth.client
          .from('event_types')
          .select()
          .order('name');

      setState(() {
        _eventTypes = List<Map<String, dynamic>>.from(data);

        // Only set default when NOT editing
        if (!_isEditMode && _eventTypes.isNotEmpty && _selectedEventType == null) {
          _selectedEventType = _eventTypes[0]['id'];
        }
      });
    } catch (e) {
      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          onRetry: _loadEventTypes,
          customMessage: 'Error loading event types',
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
        NetworkUtils.handleError(
          context,
          e,
          onRetry: _loadOperators,
          customMessage: 'Error loading operators',
        );
      }
    }
  }

  // ✅ UPDATE: Modified _populateFields to properly set event type
  // ✅ UPDATED: Modified _populateFields to properly set ALL fields including skip flags
  void _populateFields() {
    if (_editingEvent == null) return;

    _skipWhatsApp = _editingEvent!['skip_whatsapp'] ?? false;
    _customerName.text = _editingEvent!['customer_name'] ?? '';
    _contactNumber.text = _editingEvent!['customer_phone'] ?? '';
    _title.text = _editingEvent!['title'] ?? '';
    _venue.text = _editingEvent!['venue'] ?? '';
    _city.text = _editingEvent!['city'] ?? '';
    _eventFor.text = _editingEvent!['event_for'] ?? '';
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

    // ✅ FIX: Set the event type from saved data
    if (_editingEvent!['event_type'] != null) {
      _selectedEventType = _editingEvent!['event_type'];
    }

    final status = _editingEvent!['status']?.toString() ?? 'upcoming';
    _selectedStatus = status[0].toUpperCase() + status.substring(1).toLowerCase();

    // ✅ NEW: Set skip_denomination and skip_print from database
    _skipDenomination = _editingEvent!['skip_denomination'] ?? false;
    _skipPrint = _editingEvent!['skip_print'] ?? false;
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
        'event_for': _eventFor.text.trim().isEmpty ? null : _eventFor.text.trim(),
        'total_computers': int.tryParse(_totalComputers.text) ?? 0,
        'booked_amount': double.tryParse(_bookedAmount.text) ?? 0,
        'advance_amount': double.tryParse(_advanceAmount.text) ?? 0,
        'discount_amount': double.tryParse(_discountAmount.text) ?? 0,
        'referral_by': _referenceBy.text.trim().isEmpty ? null : _referenceBy.text.trim(),
        'remark': _remark.text.trim().isEmpty ? null : _remark.text.trim(),
        'status': _selectedStatus.toLowerCase(),
        'event_type': _selectedEventType,
        'skip_denomination': _skipDenomination, // ✅ ADD THIS LINE
        'skip_print': _skipPrint,               // ✅ ADD THIS LINE
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
        NetworkUtils.handleError(
          context,
          e,
          onRetry: _generateReceiptAndSendWhatsApp,
          customMessage: 'Error generating receipt',
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
              child: SingleChildScrollView(
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
                      constraints: const BoxConstraints(maxHeight: 200),
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
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Edit button
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  onPressed: () => _showEditEventTypeDialog(type, setDialogState),
                                  color: Colors.blue,
                                  tooltip: 'Edit',
                                ),
                                // Delete button
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 18),
                                  onPressed: () => _deleteEventType(type['id'], setDialogState),
                                  color: Colors.red,
                                  tooltip: 'Delete',
                                ),
                              ],
                            ),
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
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
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
                      NetworkUtils.handleError(
                        context,
                        e,
                        customMessage: 'Error creating event type',
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

  Future<void> _showEditEventTypeDialog(Map<String, dynamic> eventType, StateSetter parentSetState) async {
    final nameController = TextEditingController(text: eventType['name']);
    final descriptionController = TextEditingController(text: eventType['description'] ?? '');
    bool isUpdating = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Edit Event Type'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isUpdating
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

                  setDialogState(() => isUpdating = true);

                  try {
                    await _auth.client
                        .from('event_types')
                        .update({
                      'name': name,
                      'description': descriptionController.text.trim().isEmpty
                          ? null
                          : descriptionController.text.trim(),
                    })
                        .eq('id', eventType['id']);

                    await _loadEventTypes();

                    // Update parent dialog state
                    parentSetState(() {});

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Event type updated successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    setDialogState(() => isUpdating = false);
                    if (context.mounted) {
                      NetworkUtils.handleError(
                        context,
                        e,
                        customMessage: 'Error updating event type',
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB846D7),
                  foregroundColor: Colors.white,
                ),
                child: isUpdating
                    ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Text('Update'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteEventType(String eventTypeId, StateSetter parentSetState) async {
    // Check if this event type is being used by any events
    try {
      final eventsUsingType = await _auth.client
          .from('events')
          .select('id')
          .eq('event_type', eventTypeId)
          .limit(1);

      if (eventsUsingType.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot delete: This event type is being used by existing events'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          customMessage: 'Error checking event type usage',
        );
      }
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this event type? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _auth.client
          .from('event_types')
          .delete()
          .eq('id', eventTypeId);

      await _loadEventTypes();

      // Update parent dialog state
      parentSetState(() {});

      // If the deleted type was selected, select the first available type
      if (_selectedEventType == eventTypeId) {
        setState(() {
          _selectedEventType = _eventTypes.isNotEmpty ? _eventTypes[0]['id'] : null;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event type deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          customMessage: 'Error deleting event type',
        );
      }
    }
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
        'event_for': _eventFor.text.trim().isEmpty ? null : _eventFor.text.trim(), // ✅ FIX: Remove the duplicate line above
        'total_computers': int.tryParse(_totalComputers.text) ?? 0,
        'booked_amount': double.tryParse(_bookedAmount.text) ?? 0,
        'advance_amount': double.tryParse(_advanceAmount.text) ?? 0,
        'discount_amount': double.tryParse(_discountAmount.text) ?? 0,
        'referral_by': _referenceBy.text.trim().isEmpty ? null : _referenceBy.text.trim(),
        'remark': _remark.text.trim().isEmpty ? null : _remark.text.trim(),
        'status': _selectedStatus.toLowerCase(),
        'event_type': _selectedEventType,
        'skip_denomination': _skipDenomination, // ✅ ADD THIS LINE
        'skip_print': _skipPrint,               // ✅ ADD THIS LINE
        'skip_whatsapp': _skipWhatsApp,         // ✅ ADD THIS LINE
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

      if (mounted && shouldExit) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          onRetry: () => _save(shouldExit: shouldExit),
          customMessage: 'Error saving event',
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  // Add these methods in _CreateEventScreenState class

// Method to check if operator can be removed
  Future<bool> _canRemoveOperator(String operatorId) async {
    try {
      // Check if operator has collected any MOI entries for this event
      final moiEntries = await _auth.client
          .from('mois')
          .select('id')
          .eq('event_id', _editingEvent!['id'])
          .eq('operator_id', operatorId)
          .eq('is_deleted', false)
          .limit(1);

      // If MOI entries exist, operator cannot be removed
      if (moiEntries.isNotEmpty) {
        return false;
      }

      return true;
    } catch (e) {
      print('Error checking operator MOI entries: $e');
      return false;
    }
  }

// Method to show error dialog when operator removal fails
  Future<void> _showOperatorRemovalError(String operatorName, String operatorId) async {
    // Get count of MOI entries
    int moiCount = 0;
    try {
      final moiEntries = await _auth.client
          .from('mois')
          .select('id')
          .eq('event_id', _editingEvent!['id'])
          .eq('operator_id', operatorId)
          .eq('is_deleted', false);

      moiCount = moiEntries.length;
    } catch (e) {
      print('Error counting MOI entries: $e');
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Cannot Remove Operator',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Operator: $operatorName',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                border: Border.all(color: Colors.orange, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This operator has already collected MOI entries!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total MOI Entries: $moiCount',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'To remove this operator:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                border: Border.all(color: Colors.blue, width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('1. ', style: TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text(
                          'Mark this event as "Completed"',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('2. ', style: TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text(
                          'Then you can remove the operator',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor: Colors.grey[200],
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'OK',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

// Updated _updateOperatorAssignment method with validation
  Future<void> _updateOperatorAssignment(String eventId) async {
    try {
      // Get current assignments from database
      final currentAssignments = await _auth.client
          .from('event_assignments')
          .select('operator_id')
          .eq('event_id', eventId);

      Set<String> currentOperatorIds = currentAssignments
          .map((a) => a['operator_id'] as String)
          .toSet();

      Set<String> newOperatorIds = _selectedOperators.toSet();

      // Find operators being removed
      Set<String> removedOperators = currentOperatorIds.difference(newOperatorIds);

      // Check if event is completed
      bool isEventCompleted = _selectedStatus.toLowerCase() == 'completed';

      // Validate each removed operator
      for (String operatorId in removedOperators) {
        // If event is NOT completed, check if operator has MOI entries
        if (!isEventCompleted) {
          bool canRemove = await _canRemoveOperator(operatorId);

          if (!canRemove) {
            // Get operator name
            final operator = _operators.firstWhere(
                  (op) => op['id'] == operatorId,
              orElse: () => {'full_name': 'Unknown Operator'},
            );

            // Show error dialog
            await _showOperatorRemovalError(operator['full_name'], operatorId);

            // Revert the selection (add back the removed operator)
            setState(() {
              _selectedOperators.add(operatorId);
            });

            return; // Stop the update process
          }
        }
        // If event IS completed, allow removal without checking MOI entries
      }

      // If validation passed, proceed with update
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
      print('Error updating operator assignments: $e');
      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          customMessage: 'Error updating operators',
        );
      }
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
      _skipWhatsApp = false;
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
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                ],
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
                                maxLines: 3,  // Added - allows multiple lines like Event For and Remark
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

                            // Replace the "Event For" field section in your create_event_screen.dart
// Around line 1190-1210

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
                                maxLines: 3,  // ADD THIS LINE - allows multiple lines like Remark field
                              ),
                            ),

                            const SizedBox(height: 16),

                            // UPDATED: Operators section in build method with validation on chip deletion
// Replace the operators section around line 1210-1270 with this:

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
                                            onDeleted: () async {
                                              // ✅ VALIDATION: Check if we're in edit mode and operator has MOI entries
                                              if (_isEditMode && _editingEvent != null) {
                                                bool isEventCompleted = _selectedStatus.toLowerCase() == 'completed';

                                                if (!isEventCompleted) {
                                                  bool canRemove = await _canRemoveOperator(operatorId);

                                                  if (!canRemove) {
                                                    await _showOperatorRemovalError(operator['full_name'], operatorId);
                                                    return; // Don't remove
                                                  }
                                                }
                                              }

                                              // Remove operator if validation passed
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
                                      if (value != null && !_selectedOperators.contains(value)) {
                                        setState(() {
                                          _selectedOperators.add(value);
                                        });
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
                                      value: _skipWhatsApp,
                                      onChanged: (value) {
                                        setState(() => _skipWhatsApp = value ?? false);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Skip WhatsApp',
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
                                            value: _skipWhatsApp,
                                            onChanged: (value) {
                                              setState(() => _skipWhatsApp = value ?? false);
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Skip WhatsApp',
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