import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../utils/network_utils.dart';

class TodaysEventsScreen extends StatefulWidget {
  const TodaysEventsScreen({super.key});

  @override
  State<TodaysEventsScreen> createState() => _TodaysEventsScreenState();
}

class _TodaysEventsScreenState extends State<TodaysEventsScreen> {
  final _auth = AuthService();

  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _filteredEvents = [];
  List<Map<String, dynamic>> _eventTypes = [];
  bool _loading = true;

  // Filter controllers
  String? _selectedEventType;
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _loadEventTypes();
    _loadTodaysEvents();
  }

  void _editEvent(Map<String, dynamic> event) async {
    final result = await Navigator.pushNamed(
      context,
      '/admin/create-event',
      arguments: event,
    );

    if (result == true) {
      _loadTodaysEvents();
    }
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
        _loadTodaysEvents();
      }
    } catch (e) {
      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          onRetry: () => _deleteEvent(event),
          customMessage: 'Error deleting event',
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
        NetworkUtils.handleError(
          context,
          e,
          onRetry: _loadEventTypes,
          customMessage: 'Error loading event types',
        );
      }
    }
  }

  Future<void> _loadTodaysEvents() async {
    setState(() => _loading = true);

    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      var query = _auth.client
          .from('events')
          .select('''
            *,
            event_types!inner(id, name)
          ''')
          .eq('event_date', today)
          .order('event_time', ascending: true);

      final data = await query;

      setState(() {
        _events = List<Map<String, dynamic>>.from(data);
        _applyFilters();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          onRetry: _loadTodaysEvents,
          customMessage: 'Error loading events',
        );
      }
    }
  }

  void _applyFilters() {
    var filtered = _events.where((event) {
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

  void _clearFilters() {
    setState(() {
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
              // Title
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 2),
                  color: Colors.white,
                ),
                child: const Text(
                  "Today's Events",
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
                              "TODAY'S EVENTS - ${DateFormat('dd MMM yyyy').format(DateTime.now())}",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmallScreen ? 12 : 16,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
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
                            'No events scheduled for today',
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
                            'Total ${_filteredEvents.length} event(s) today',
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
                                          .then((_) => _loadTodaysEvents());
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
                                    onPressed: _loadTodaysEvents,
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