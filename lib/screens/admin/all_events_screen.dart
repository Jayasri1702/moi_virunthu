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
  String _dateFilter = 'All';
  String? _selectedEventType;
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _loadEventTypes();
    _loadEvents();
  }

  void _editEvent(Map<String, dynamic> event) async {
    final result = await Navigator.pushNamed(
      context,
      '/admin/create-event',
      arguments: event,
    );

    if (result == true) {
      _loadEvents();
    }
  }

  void _manageExpenses(Map<String, dynamic> event) async {
    await Navigator.pushNamed(
      context,
      '/admin/event-expenses',
      arguments: event,
    );
    _loadEvents();
  }

  // NEW: Show operators dialog and navigate to operator dashboard
  Future<void> _showOperatorsDialog(Map<String, dynamic> event) async {
    try {
      // Fetch assigned operators for this event
      final assignments = await _auth.client
          .from('event_assignments')
          .select('''
            operator_id,
            users!inner(id, full_name, phone)
          ''')
          .eq('event_id', event['id']);

      if (!mounted) return;

      if (assignments == null || assignments.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No operators assigned to this event'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Show dialog with operator list
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Assigned Operators'),
          content: SizedBox(
            width: 300,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: assignments.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final operator = assignments[index]['users'];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFB846D7),
                    child: Text(
                      operator['full_name'][0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(operator['full_name']),
                  subtitle: Text(operator['phone'] ?? ''),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.pop(context); // Close dialog
                    _navigateToOperatorDashboard(event, operator);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
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

  // NEW: Navigate to operator dashboard as admin
  // Around line 91-100, modify the _navigateToOperatorDashboard method:
  void _navigateToOperatorDashboard(
      Map<String, dynamic> event,
      Map<String, dynamic> operator,
      ) {
    // Prepare event data with operator info
    final eventDataWithOperator = Map<String, dynamic>.from(event);
    eventDataWithOperator['_operator_name'] = operator['full_name'];
    eventDataWithOperator['_operator_id'] = operator['id'];
    eventDataWithOperator['_is_admin_view'] = true; // ✅ ADD THIS LINE

    // Navigate to operator dashboard
    Navigator.pushNamed(
      context,
      '/operator/event-dashboard',
      arguments: eventDataWithOperator,
    );
  }

  Future<void> _deleteEvent(Map<String, dynamic> event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
      await _auth.client
          .from('event_assignments')
          .delete()
          .eq('event_id', event['id']);

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
        _loadEvents();
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
    }
  }

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
          .order('event_date', ascending: false)
          .order('event_time', ascending: true);

      final data = await query;

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final todayDate = DateTime.parse(today);

      for (var event in data) {
        if (event['event_date'] != null) {
          final eventDate = DateTime.parse(event['event_date']);

          if (eventDate.isBefore(todayDate) &&
              event['status']?.toString().toLowerCase() == 'upcoming') {
            try {
              await _auth.client
                  .from('events')
                  .update({'status': 'completed'})
                  .eq('id', event['id']);
              event['status'] = 'completed';
            } catch (e) {
              print('Error updating event status: $e');
            }
          }
        }
      }

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
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todayDate = DateTime.parse(today);

    var filtered = _events.where((event) {
      if (_dateFilter != 'All' && event['event_date'] != null) {
        final eventDate = DateTime.parse(event['event_date']);

        switch (_dateFilter) {
          case 'Today':
            if (eventDate.year != todayDate.year ||
                eventDate.month != todayDate.month ||
                eventDate.day != todayDate.day) {
              return false;
            }
            break;
          case 'Upcoming':
            if (!eventDate.isAfter(todayDate)) {
              return false;
            }
            break;
          case 'Past':
            if (!eventDate.isBefore(todayDate)) {
              return false;
            }
            break;
        }
      }

      if (_selectedEventType != null && _selectedEventType!.isNotEmpty) {
        if (event['event_types']['id'] != _selectedEventType) {
          return false;
        }
      }

      if (_selectedStatus != null && _selectedStatus!.isNotEmpty) {
        if (event['status']?.toString().toLowerCase() !=
            _selectedStatus!.toLowerCase()) {
          return false;
        }
      }

      return true;
    }).toList();

    setState(() {
      _filteredEvents = filtered;
    });
  }

  void _clearFilters() {
    setState(() {
      _dateFilter = 'All';
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

  String _formatTime(String? timeStr) {
    if (timeStr == null) return '';
    try {
      final time = TimeOfDay(
        hour: int.parse(timeStr.split(':')[0]),
        minute: int.parse(timeStr.split(':')[1]),
      );
      return time.format(context);
    } catch (e) {
      return timeStr;
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 2),
                  color: Colors.white,
                ),
                child: const Text(
                  'All Events',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 1200),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[400]!),
                ),
                child: Column(
                  children: [
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
                              'ALL EVENTS',
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
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.start,
                        children: [
                          const SizedBox(
                            width: 100,
                            child: Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Text(
                                'Show',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: isSmallScreen ? double.infinity : 150,
                            child: DropdownButtonFormField<String>(
                              value: _dateFilter,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                isDense: true,
                              ),
                              items: const [
                                DropdownMenuItem(value: 'All', child: Text('All Events')),
                                DropdownMenuItem(value: 'Today', child: Text('Today')),
                                DropdownMenuItem(value: 'Upcoming', child: Text('Upcoming')),
                                DropdownMenuItem(value: 'Past', child: Text('Past')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _dateFilter = value!;
                                  _applyFilters();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 20),
                          const SizedBox(
                            width: 100,
                            child: Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Text(
                                'Event Type',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
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
                                'Time',
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
                                'Venue',
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
                                'Computers',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Status',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Actions',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                          rows: _filteredEvents.map((event) {
                            return DataRow(
                              cells: [
                                DataCell(Text(_formatDate(event['event_date']))),
                                DataCell(Text(_formatTime(event['event_time']))),
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
                                DataCell(
                                  SizedBox(
                                    width: 150,
                                    child: Text(
                                      event['venue'] ?? '',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(Text(event['city'] ?? '')),
                                DataCell(
                                  Text(event['total_computers']?.toString() ?? '0'),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(event['status'])
                                          .withOpacity(0.1),
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
                                        icon: const Icon(Icons.edit,
                                            size: 18, color: Colors.blue),
                                        onPressed: () => _editEvent(event),
                                        tooltip: 'Edit',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            size: 18, color: Colors.red),
                                        onPressed: () => _deleteEvent(event),
                                        tooltip: 'Delete',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.currency_rupee,
                                            size: 18, color: Colors.green),
                                        onPressed: () => _manageExpenses(event),
                                        tooltip: 'Manage Expenses',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      const SizedBox(width: 8),
                                      // NEW: Operator icon
                                      IconButton(
                                        icon: const Icon(Icons.people,
                                            size: 18, color: Color(0xFFB846D7)),
                                        onPressed: () => _showOperatorsDialog(event),
                                        tooltip: 'View Operators',
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

                    // Footer
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
                            'Showing ${_filteredEvents.length} event(s)',
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
                                    child: const Text('Refresh', style: TextStyle(fontSize: 13)),
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