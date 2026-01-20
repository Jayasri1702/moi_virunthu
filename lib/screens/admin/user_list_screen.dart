import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import './create_operator_screen.dart';
import '../../utils/network_utils.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final _auth = AuthService();
  List<UserModel> _users = [];
  bool _loading = true;
  bool _showInactiveOnly = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      // Fetch all users with pagination
      List<dynamic> data = [];
      int pageSize = 1000;
      int currentPage = 0;
      bool hasMore = true;

      while (hasMore) {
        final pageResponse = await _auth.client
            .from('users')
            .select()
            .order('full_name')
            .range(currentPage * pageSize, (currentPage + 1) * pageSize - 1);

        data.addAll(pageResponse);

        if (pageResponse.length < pageSize) {
          hasMore = false;
        } else {
          currentPage++;
        }
      }

      setState(() {
        _users = (data as List).map((user) => UserModel.fromMap(user)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          onRetry: _loadUsers,
          customMessage: 'Error loading users',
        );
      }
    }
  }

  Future<void> _deleteUser(UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete user "${user.fullName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _auth.client.from('users').delete().eq('id', user.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadUsers();
        }
      } catch (e) {
        if (mounted) {
          NetworkUtils.handleError(
            context,
            e,
            onRetry: () => _deleteUser(user),
            customMessage: 'Error deleting user',
          );
        }
      }
    }
  }

  Future<bool> _hasActiveEvents(String userId) async {
    try {
      // Check for active events with pagination
      List<dynamic> activeEvents = [];
      int pageSize = 1000;
      int currentPage = 0;
      bool hasMore = true;

      while (hasMore) {
        final pageResponse = await _auth.client
            .from('event_assignments')
            .select('event_id, events!inner(status)')
            .eq('operator_id', userId)
            .or('status.eq.upcoming,status.eq.live', referencedTable: 'events')
            .range(currentPage * pageSize, (currentPage + 1) * pageSize - 1);

        activeEvents.addAll(pageResponse);

        if (pageResponse.length < pageSize) {
          hasMore = false;
        } else {
          currentPage++;
        }
      }

      return activeEvents.isNotEmpty;
    } catch (e) {
      print('Error checking active events: $e');
      return false;
    }
  }

  Future<void> _showCannotDeactivateDialog(UserModel user, List<Map<String, dynamic>> activeEvents) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Cannot Deactivate User',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Operator: ${user.fullName}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  border: Border.all(color: Colors.orange, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'This operator is currently assigned to the following events:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                ),
              ),
              const SizedBox(height: 12),
              ...activeEvents.map((event) {
                final eventData = event['events'];
                final status = eventData['status'].toString().toUpperCase();
                final title = eventData['title'] ?? 'Untitled Event';
                final date = eventData['event_date'] ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: status == 'UPCOMING' ? Colors.blue : Colors.green,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              status,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      if (date.isNotEmpty)
                        Text(
                          'Date: $date',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
              const SizedBox(height: 12),
              const Text(
                'To deactivate this operator:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              const Text('• Complete or cancel all assigned events, OR', style: TextStyle(fontSize: 12)),
              const Text('• Remove this operator from those events', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor: Colors.grey[200],
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('OK', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleActiveStatus(UserModel user) async {
    final newStatus = !user.isActive;

    // ✅ CHECK: If trying to deactivate, check for active events
    if (newStatus == false && user.role == 'operator') {
      final hasActive = await _hasActiveEvents(user.id);

      if (hasActive) {
        // Fetch event details for display
        List<Map<String, dynamic>> activeEventsList = [];
        try {
          // Fetch event details with pagination
          List<dynamic> events = [];
          int pageSize = 1000;
          int currentPage = 0;
          bool hasMore = true;

          while (hasMore) {
            final pageResponse = await _auth.client
                .from('event_assignments')
                .select('event_id, events!inner(id, title, event_date, status)')
                .eq('operator_id', user.id)
                .or('status.eq.upcoming,status.eq.live', referencedTable: 'events')
                .range(currentPage * pageSize, (currentPage + 1) * pageSize - 1);

            events.addAll(pageResponse);

            if (pageResponse.length < pageSize) {
              hasMore = false;
            } else {
              currentPage++;
            }
          }
          activeEventsList = List<Map<String, dynamic>>.from(events);
        } catch (e) {
          print('Error fetching event details: $e');
        }

        await _showCannotDeactivateDialog(user, activeEventsList);
        return; // Don't proceed with deactivation
      }
    }

    // Optimistically update UI immediately
    setState(() {
      final index = _users.indexWhere((u) => u.id == user.id);
      if (index != -1) {
        _users[index] = UserModel(
          id: user.id,
          fullName: user.fullName,
          role: user.role,
          isActive: newStatus,
          email: user.email,
          phone: user.phone,
        );
      }
    });

    try {
      await _auth.client
          .from('users')
          .update({'is_active': newStatus})
          .eq('id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User ${newStatus ? "activated" : "deactivated"} successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Revert on error
      setState(() {
        final index = _users.indexWhere((u) => u.id == user.id);
        if (index != -1) {
          _users[index] = user; // Revert to original
        }
      });

      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          onRetry: () => _toggleActiveStatus(user),
          customMessage: 'Error updating user status',
        );
      }
    }
  }

  Future<void> _navigateToCreate() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateOperatorScreen()),
    );

    if (result == true) {
      _loadUsers();
    }
  }

  Future<void> _navigateToEdit(UserModel user) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateOperatorScreen(userToEdit: user),
      ),
    );

    if (result == true) {
      _loadUsers();
    }
  }

  List<UserModel> get _filteredUsers {
    if (_showInactiveOnly) {
      return _users.where((user) => !user.isActive).toList();
    }
    return _users;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            // Header
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
                    'App User List',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
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

            // Filter checkbox
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Checkbox(
                    value: _showInactiveOnly,
                    onChanged: (value) {
                      setState(() => _showInactiveOnly = value ?? false);
                    },
                  ),
                  const Text('Show inactive user only'),
                ],
              ),
            ),

            // Table
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    // Table Header
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        border: Border(
                          bottom: BorderSide(color: Colors.grey[400]!),
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildHeaderCell('Name', flex: 3),
                          _buildHeaderCell('Contact Number', flex: 3),
                          _buildHeaderCell('User Type', flex: 2),
                          _buildHeaderCell('Actions', flex: 3),
                        ],
                      ),
                    ),

                    // Table Body
                    Expanded(
                      child: _filteredUsers.isEmpty
                          ? const Center(
                        child: Text('No users found'),
                      )
                          : ListView.builder(
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          return Container(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                _buildDataCell(
                                  user.fullName,
                                  flex: 3,
                                ),
                                _buildDataCell(
                                  user.phone ?? '',
                                  flex: 3,
                                ),
                                _buildDataCell(
                                  user.role == 'admin'
                                      ? 'Administrator'
                                      : 'Operator',
                                  flex: 2,
                                ),
                                _buildActionCell(user),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'No. of Users  ${_filteredUsers.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 45,
                          child: ElevatedButton(
                            onPressed: _navigateToCreate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFB846D7),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: const Text(
                              'NEW USER',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 45,
                          child: OutlinedButton(
                            onPressed: _loadUsers,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black,
                              side: BorderSide(color: Colors.grey[400]!),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: const Text(
                              'Show',
                              style: TextStyle(fontSize: 15),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 45,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
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
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildDataCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Text(
          text,
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildActionCell(UserModel user) {
    return Expanded(
      flex: 2,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Active/Inactive Toggle
            Expanded(
              child: IconButton(
                icon: Icon(
                  user.isActive ? Icons.check_circle : Icons.cancel,
                  size: 20,
                ),
                onPressed: () => _toggleActiveStatus(user),
                color: user.isActive ? Colors.green : Colors.grey,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
            const SizedBox(width: 4),
            // Edit Button
            Expanded(
              child: IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () => _navigateToEdit(user),
                color: Colors.blue,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
            const SizedBox(width: 4),
            // Delete Button
            Expanded(
              child: IconButton(
                icon: const Icon(Icons.delete, size: 20),
                onPressed: () => _deleteUser(user),
                color: Colors.red,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}