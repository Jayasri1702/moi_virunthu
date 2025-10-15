import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';

class AllEventsScreen extends StatefulWidget {
  const AllEventsScreen({super.key});

  @override
  State<AllEventsScreen> createState() => _AllEventsScreenState();
}

class _AllEventsScreenState extends State<AllEventsScreen> {
  final _auth = AuthService();

  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _filteredEvents = [];
  List<Map<String, dynamic>> _eventTypes = [];
  bool _loading = true;

  // Filter controllers
  String _dateRange = 'This Month';
  DateTime? _fromDate;
  DateTime? _toDate;
  String? _selectedEventType;
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _initializeFilters();
    _loadEventTypes();
    _loadEvents();
  }

  void _initializeFilters() {
    final now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, 1);
    _toDate = DateTime(now.year, now.month + 1, 0);
  }
  void _editEvent(Map<String, dynamic> event) async {
    final result = await Navigator.pushNamed(
      context,
      '/admin/create-event',
      arguments: event, // Pass the event data
    );

    // Reload events if changes were saved
    if (result == true) {
      _loadEvents();
    }
  }

  Future<void> _deleteEvent(Map<String, dynamic> event) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('Delete Event'),
            content: Text(
              'Are you sure you want to delete the event for "${event['customer_name']}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      // Delete event assignments first (foreign key constraint)
      await _auth.client
          .from('event_assignments')
          .delete()
          .eq('event_id', event['id']);

      // Delete the event
      await _auth.client
          .from('events')
          .delete()
          .eq('id', event['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadEvents(); // Reload the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting event: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }}

  Future<void> _loadEventTypes() async {
    try {
      final data = await _auth.client
          .from('event_types')
          .select()
          .order('name');

      setState(() {
        _eventTypes = List<Map<String, dynamic>>.from(data);
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

  Future<void> _loadEvents() async {
    setState(() => _loading = true);

    try {
      var query = _auth.client
          .from('events')
          .select('''
            *,
            event_types!inner(id, name)
          ''')
          .order('event_date', ascending: false);

      final data = await query;

      setState(() {
        _events = List<Map<String, dynamic>>.from(data);
        _applyFilters();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading events: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applyFilters() {
    var filtered = _events.where((event) {
      // Date filter
      if (_fromDate != null && _toDate != null && event['event_date'] != null) {
        final eventDate = DateTime.parse(event['event_date']);
        if (eventDate.isBefore(_fromDate!) || eventDate.isAfter(_toDate!)) {
          return false;
        }
      }

      // Event type filter
      if (_selectedEventType != null && _selectedEventType!.isNotEmpty) {
        if (event['event_types']['id'] != _selectedEventType) {
          return false;
        }
      }

      // Status filter
      if (_selectedStatus != null && _selectedStatus!.isNotEmpty) {
        if (event['status']?.toString().toLowerCase() != _selectedStatus!.toLowerCase()) {
          return false;
        }
      }

      return true;
    }).toList();

    setState(() {
      _filteredEvents = filtered;
    });
  }

  void _onDateRangeChanged(String? value) {
    if (value == null) return;

    setState(() {
      _dateRange = value;
      final now = DateTime.now();

      switch (value) {
        case 'This Month':
          _fromDate = DateTime(now.year, now.month, 1);
          _toDate = DateTime(now.year, now.month + 1, 0);
          break;
        case 'Last Month':
          _fromDate = DateTime(now.year, now.month - 1, 1);
          _toDate = DateTime(now.year, now.month, 0);
          break;
        case 'This Year':
          _fromDate = DateTime(now.year, 1, 1);
          _toDate = DateTime(now.year, 12, 31);
          break;
        case 'All':
          _fromDate = null;
          _toDate = null;
          break;
      }
      _applyFilters();
    });
  }

  Future<void> _selectFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked;
        _dateRange = 'Custom';
        _applyFilters();
      });
    }
  }

  Future<void> _selectToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _toDate = picked;
        _dateRange = 'Custom';
        _applyFilters();
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _dateRange = 'This Month';
      _initializeFilters();
      _selectedEventType = null;
      _selectedStatus = null;
      _applyFilters();
    });
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd-MM-yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'upcoming':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
          child: Column(
            children: [
              // Title
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 2),
                  color: Colors.white,
                ),
                child: const Text(
                  'View Events',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Main Card
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 1200),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[400]!),
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF7B3A99), Color(0xFF9B4DB8)],
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'FESTIVAL LIST',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmallScreen ? 14 : 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 18),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          ),
                        ],
                      ),
                    ),

                    // Filters Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        border: Border(
                          bottom: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: Column(
                        children: [
                          // First Row - Date Range
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            alignment: WrapAlignment.start,
                            children: [
                              // Date Range Label
                              const SizedBox(
                                width: 100,
                                child: Padding(
                                  padding: EdgeInsets.only(top: 12),
                                  child: Text(
                                    'Date Range',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ),

                              // Date Range Dropdown
                              SizedBox(
                                width: isSmallScreen ? double.infinity : 150,
                                child: DropdownButtonFormField<String>(
                                  value: _dateRange,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    isDense: true,
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'This Month', child: Text('This Month')),
                                    DropdownMenuItem(value: 'Last Month', child: Text('Last Month')),
                                    DropdownMenuItem(value: 'This Year', child: Text('This Year')),
                                    DropdownMenuItem(value: 'All', child: Text('All')),
                                    DropdownMenuItem(value: 'Custom', child: Text('Custom')),
                                  ],
                                  onChanged: _onDateRangeChanged,
                                ),
                              ),

                              // From Date
                              const SizedBox(
                                width: 50,
                                child: Padding(
                                  padding: EdgeInsets.only(top: 12),
                                  child: Text(
                                    'From',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: isSmallScreen ? double.infinity : 150,
                                child: InkWell(
                                  onTap: _selectFromDate,
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      suffixIcon: Icon(Icons.calendar_today, size: 16),
                                      isDense: true,
                                    ),
                                    child: Text(
                                      _fromDate != null ? DateFormat('dd-MM-yyyy').format(_fromDate!) : '',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ),
                              ),

                              // To Date
                              const SizedBox(
                                width: 30,
                                child: Padding(
                                  padding: EdgeInsets.only(top: 12),
                                  child: Text(
                                    'To',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: isSmallScreen ? double.infinity : 150,
                                child: InkWell(
                                  onTap: _selectToDate,
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      suffixIcon: Icon(Icons.calendar_today, size: 16),
                                      isDense: true,
                                    ),
                                    child: Text(
                                      _toDate != null ? DateFormat('dd-MM-yyyy').format(_toDate!) : '',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Second Row - Event Type and Status
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            alignment: WrapAlignment.start,
                            children: [
                              // Event Label
                              const SizedBox(
                                width: 100,
                                child: Padding(
                                  padding: EdgeInsets.only(top: 12),
                                  child: Text(
                                    'Event',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ),

                              // Event Type Dropdown
                              SizedBox(
                                width: isSmallScreen ? double.infinity : 250,
                                child: DropdownButtonFormField<String>(
                                  value: _selectedEventType,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    isDense: true,
                                    hintText: 'All Events',
                                  ),
                                  items: [
                                    const DropdownMenuItem(value: null, child: Text('All Events')),
                                    ..._eventTypes.map((type) {
                                      return DropdownMenuItem<String>(
                                        value: type['id'],
                                        child: Text(type['name']),
                                      );
                                    }).toList(),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedEventType = value;
                                      _applyFilters();
                                    });
                                  },
                                ),
                              ),

                              const SizedBox(width: 20),

                              // Status Label
                              const SizedBox(
                                width: 50,
                                child: Padding(
                                  padding: EdgeInsets.only(top: 12),
                                  child: Text(
                                    'Status',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ),

                              // Status Dropdown
                              SizedBox(
                                width: isSmallScreen ? double.infinity : 150,
                                child: DropdownButtonFormField<String>(
                                  value: _selectedStatus,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    isDense: true,
                                    hintText: 'All Status',
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: null, child: Text('All Status')),
                                    DropdownMenuItem(value: 'upcoming', child: Text('Upcoming')),
                                    DropdownMenuItem(value: 'completed', child: Text('Completed')),
                                    DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedStatus = value;
                                      _applyFilters();
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Table Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: _loading
                          ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                          : _filteredEvents.isEmpty
                          ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text(
                            'No events found',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ),
                      )
                          : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: MaterialStateProperty.all(Colors.grey[200]),
                          border: TableBorder.all(color: Colors.grey[300]!),
                          columnSpacing: 16,
                          columns: const [
                            DataColumn(
                              label: Text(
                                'Date',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Customer Name',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Event',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'City',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Status',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: _filteredEvents.map((event) {
                            return DataRow(
                              cells: [
                                DataCell(Text(_formatDate(event['event_date']))),
                                DataCell(
                                  SizedBox(
                                    width: 150,
                                    child: Text(
                                      event['customer_name'] ?? '',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(event['event_types']?['name'] ?? ''),
                                ),
                                DataCell(Text(event['city'] ?? '')),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(event['status']).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: _getStatusColor(event['status']),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      event['status']?.toString().toUpperCase() ?? '',
                                      style: TextStyle(
                                        color: _getStatusColor(event['status']),
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                                        onPressed: () => _editEvent(event),
                                        tooltip: 'Edit',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                        onPressed: () => _deleteEvent(event),
                                        tooltip: 'Delete',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                    // Footer (Fixed for mobile)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        border: Border(
                          top: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total ${_filteredEvents.length}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                SizedBox(
                                  width: isSmallScreen ? 80 : 100,
                                  height: 40,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.pushNamed(context, '/admin/create-event')
                                          .then((_) => _loadEvents());
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFB846D7),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                    ),
                                    child: const Text('NEW', style: TextStyle(fontSize: 13)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: isSmallScreen ? 80 : 100,
                                  height: 40,
                                  child: OutlinedButton(
                                    onPressed: _loadEvents,
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                    ),
                                    child: const Text('Show', style: TextStyle(fontSize: 13)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: isSmallScreen ? 80 : 100,
                                  height: 40,
                                  child: OutlinedButton(
                                    onPressed: _clearFilters,
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                    ),
                                    child: const Text('Clear', style: TextStyle(fontSize: 13)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: isSmallScreen ? 80 : 100,
                                  height: 40,
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                    ),
                                    child: const Text('Exit', style: TextStyle(fontSize: 13)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
}