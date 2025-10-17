import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../models/user.dart';

class OperatorHomeScreen extends StatefulWidget {
  const OperatorHomeScreen({super.key});

  @override
  State<OperatorHomeScreen> createState() => _OperatorHomeScreenState();
}

class _OperatorHomeScreenState extends State<OperatorHomeScreen> {
  final _auth = AuthService();
  List<Map<String, dynamic>> _upcomingEvents = [];
  bool _loading = true;
  String _operatorName = '';
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    // Get user data passed from login screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is UserModel) {
        setState(() {
          _currentUserId = args.id;
          _operatorName = args.fullName;
        });
        _loadUpcomingEvents();
      } else {
        // No user data passed, redirect to login
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    });
  }

  Future<void> _loadUpcomingEvents() async {
    if (_currentUserId == null) {
      print('No user ID available');
      return;
    }

    setState(() => _loading = true);

    try {
      print('Loading events for operator: $_currentUserId');

      // Get today's date at midnight for accurate comparison
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final todayStr = DateFormat('yyyy-MM-dd').format(today);
      print('Today date: $todayStr');

      // Get assigned event IDs for this operator
      final assignments = await _auth.client
          .from('event_assignments')
          .select('event_id')
          .eq('operator_id', _currentUserId!);

      print('Assignments found: ${assignments.length}');

      if (assignments.isEmpty) {
        print('No event assignments found for this operator');
        if (mounted) {
          setState(() {
            _upcomingEvents = [];
            _loading = false;
          });
        }
        return;
      }

      // Extract event IDs
      final eventIds = assignments.map((a) => a['event_id'] as String).toList();
      print('Event IDs assigned to operator: $eventIds');

      // Get events that are assigned to this operator AND have today or future dates
      final events = await _auth.client
          .from('events')
          .select('''
            *,
            event_types!inner(id, name)
          ''')
          .inFilter('id', eventIds)
          .gte('event_date', todayStr)
          .order('event_date', ascending: true)
          .order('event_time', ascending: true);

      print('Filtered events count: ${events.length}');

      if (mounted) {
        setState(() {
          _upcomingEvents = List<Map<String, dynamic>>.from(events);
          _loading = false;
        });
      }
    } catch (e, stackTrace) {
      print('Error loading upcoming events: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading events: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
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
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await _auth.logout();
      print('Logout completed successfully');

      navigator.pushNamedAndRemoveUntil('/', (route) => false);
    } catch (e, stackTrace) {
      print('Logout error: $e');
      print('Stack trace: $stackTrace');
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error logging out: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToEventDashboard(Map<String, dynamic> event) {
    Navigator.pushNamed(
      context,
      '/operator/event-dashboard',
      arguments: event,
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd-MM-yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        automaticallyImplyLeading: false,
        title: const Text(
          'Hi Tech Moi',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _loadUpcomingEvents,
            tooltip: 'Refresh',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout, color: Colors.red, size: 24),
                tooltip: 'Logout',
                padding: const EdgeInsets.all(8),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadUpcomingEvents,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Profile Section
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 3),
                        color: Colors.white,
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 60,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Welcome $_operatorName',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Upcoming Functions Section
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.black, width: 2),
                        ),
                      ),
                      child: const Text(
                        'Upcoming functions',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    // Table Header
                    Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.black, width: 2),
                        ),
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: const BoxDecoration(
                                  border: Border(
                                    right: BorderSide(
                                      color: Colors.black,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: const Text(
                                  'Date',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: const BoxDecoration(
                                  border: Border(
                                    right: BorderSide(
                                      color: Colors.black,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: const Text(
                                  'Title',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                child: const Text(
                                  'Event',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Table Body
                    if (_upcomingEvents.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.event_busy,
                              size: 60,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No upcoming events assigned',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...List.generate(_upcomingEvents.length, (index) {
                        final event = _upcomingEvents[index];
                        final eventTypeName =
                            event['event_types']?['name'] ?? 'N/A';
                        final isLastItem =
                            index == _upcomingEvents.length - 1;

                        return InkWell(
                          onTap: () => _navigateToEventDashboard(event),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                bottom: isLastItem
                                    ? BorderSide.none
                                    : const BorderSide(
                                  color: Colors.black,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          right: BorderSide(
                                            color: Colors.black,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        _formatDate(event['event_date']),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.blue,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 4,
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          right: BorderSide(
                                            color: Colors.black,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        event['title'] ?? 'N/A',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.blue,
                                          decoration:
                                          TextDecoration.underline,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      child: Text(
                                        eventTypeName,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.blue,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
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