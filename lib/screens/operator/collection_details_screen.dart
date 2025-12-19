import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../utils/network_utils.dart';
import '../../services/moi_receipt_generator.dart';
import '../../services/thermal_printer_service.dart';
import 'dart:io';
import 'package:http/http.dart' as http;

class CollectionDetailsScreen extends StatefulWidget {
  const CollectionDetailsScreen({super.key});

  @override
  State<CollectionDetailsScreen> createState() => _CollectionDetailsScreenState();
}

class _CollectionDetailsScreenState extends State<CollectionDetailsScreen> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _mois = [];
  List<Map<String, dynamic>> _filteredMois = [];
  bool _isLoading = true;
  String? _eventId;
  String? _operatorId;
  double _totalAmount = 0.0;
  int _totalCount = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map<String, dynamic>) {
      _eventId = args['id'];
      _operatorId = args['operator_id'];
      _loadCollectionDetails();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCollectionDetails() async {
    if (_eventId == null || _operatorId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await _supabase
          .from('mois')
          .select('*')
          .eq('event_id', _eventId!)
          .eq('operator_id', _operatorId!)
          .eq('is_deleted', false)
          .order('created_at', ascending: false);

      double total = 0.0;
      for (var moi in response) {
        total += (moi['amount'] as num).toDouble();
      }

      setState(() {
        _mois = List<Map<String, dynamic>>.from(response);
        _filteredMois = _mois;
        _totalAmount = total;
        _totalCount = _mois.length;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading collection details: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          onRetry: _loadCollectionDetails,
          customMessage: 'Error loading collection details',
        );
      }
    }
  }

  void _filterMois(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredMois = _mois;
      });
      return;
    }

    setState(() {
      _filteredMois = _mois.where((moi) {
        String personsText = _getPersonsCompact(moi['persons']).toLowerCase();
        String villageName = (moi['village_name'] ?? '').toLowerCase();
        String phone = (moi['phone'] ?? '').toLowerCase();
        String searchQuery = query.toLowerCase();

        return personsText.contains(searchQuery) ||
            villageName.contains(searchQuery) ||
            phone.contains(searchQuery);
      }).toList();
    });
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd-MM-yyyy hh:mm a').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _getPersonsCompact(dynamic persons) {
    if (persons == null) return 'No name';

    try {
      List<dynamic> personsList = persons is String ? [] : (persons as List);
      if (personsList.isEmpty) return 'No name';

      List<String> names = [];
      for (var person in personsList) {
        String init = person['init'] ?? '';
        String name = person['name'] ?? '';
        if (name.isNotEmpty) {
          names.add('$init $name'.trim());
        }
      }

      return names.isEmpty ? 'No name' : names.join(', ');
    } catch (e) {
      return 'No name';
    }
  }

  void _showMoiDetails(Map<String, dynamic> moi) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: const BorderSide(color: Colors.black, width: 2),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'MOI Details - O${moi['serial_no']}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('Serial No', 'O${moi['serial_no'] ?? 'N/A'}'),
                          _buildDetailRow('Amount', '₹${moi['amount'] ?? '0'}'),
                          _buildDetailRow('Payment Method', moi['payment_method'] ?? 'N/A'),
                          _buildDetailRow('Village Name', moi['village_name'] ?? 'N/A'),
                          _buildDetailRow('Living Place', moi['living_place'] ?? 'N/A'),
                          _buildDetailRow('Phone', moi['phone'] ?? 'N/A'),
                          _buildDetailRow('Is Uncle', moi['is_uncle'] == true ? 'Yes' : 'No'),
                          if (moi['uncle_order'] != null)
                            _buildDetailRow('Uncle Order', '${moi['uncle_order']}'),
                          if (moi['group_id'] != null)
                            _buildDetailRow('Group ID', '${moi['group_id']}'),
                          _buildDetailRow('Created At', _formatDateTime(moi['created_at'])),

                          const SizedBox(height: 16),
                          const Text(
                            'Persons:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildPersonsDetails(moi['persons']),

                          if (moi['notes'] != null && moi['notes'].toString().isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'Notes:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                border: Border.all(color: Colors.black, width: 1),
                              ),
                              child: Text(moi['notes'] ?? ''),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _editMoi(Map<String, dynamic> moi) {
    Navigator.pushNamed(
      context,
      '/operator/collect-moi',
      arguments: {
        'id': _eventId,
        'operator_id': _operatorId,
        'edit_mode': true,
        'moi_data': moi,
      },
    ).then((_) {
      _loadCollectionDetails();
    });
  }

  // Get operator name
  Future<String> _getOperatorName() async {
    try {
      final response = await _supabase
          .from('users')
          .select('full_name')
          .eq('id', _operatorId!)
          .single();
      return response['full_name'] ?? 'Operator';
    } catch (e) {
      return 'Operator';
    }
  }

// Get event details
  Future<Map<String, dynamic>> _getEventDetails() async {
    try {
      final response = await _supabase
          .from('events')
          .select('event_date, event_time, customer_name, city, customer_phone, title, venue, event_for, skip_print, event_types(name)')
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
        'customer_name': response['customer_name'],
        'city': response['city'],
        'customer_phone': response['customer_phone'],
        'event_title': response['title'],
        'venue': response['venue'],
        'event_for': response['event_for'],
        'event_type_name': response['event_types']?['name'],
        'skip_print': response['skip_print'] ?? false,
      };
    } catch (e) {
      return {
        'event_date': DateTime.now(),
        'event_time': TimeOfDay.now(),
      };
    }
  }

// Get denominations
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
      return null;
    }
  }

// Print handler
  Future<void> _handlePrint(Map<String, dynamic> moi) async {
    final eventDetails = await _getEventDetails();

    // Check if skip_print is enabled
    if (eventDetails['skip_print'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⏭️ Printing is disabled for this event'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // ✅ NEW: Check if it's a group MOI by counting actual group members
    if (moi['group_id'] != null) {
      // Get all MOIs in this group
      final groupMois = await _supabase
          .from('mois')
          .select('id')
          .eq('event_id', _eventId!)
          .eq('group_id', moi['group_id'])
          .eq('is_deleted', false);

      // ✅ If only ONE entry in the group, treat as single receipt
      if (groupMois.length == 1) {
        await _printSingleReceipt(moi);
        return;
      }

      // ✅ Multiple entries in group - show dialog
      final receiptType = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: const BorderSide(color: Colors.black, width: 2),
          ),
          title: const Text(
            'Generate Receipt',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Text(
            'This entry is part of a group with ${groupMois.length} entries. How would you like to generate the receipt?',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'single'),
              style: TextButton.styleFrom(
                backgroundColor: Colors.blue[50],
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text(
                'Single Receipt',
                style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'group'),
              style: TextButton.styleFrom(
                backgroundColor: Colors.green[50],
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text(
                'Group Receipt',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                backgroundColor: Colors.grey[200],
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );

      if (receiptType == null) return;

      if (receiptType == 'group') {
        await _printGroupReceipt(moi['group_id']);
      } else {
        await _printSingleReceipt(moi);
      }
    } else {
      // ✅ Single MOI (no group_id) - print directly
      await _printSingleReceipt(moi);
    }
  }

// Print single receipt
  Future<void> _printSingleReceipt(Map<String, dynamic> moi) async {
    setState(() => _isLoading = true);

    try {
      final operatorName = await _getOperatorName();
      final eventDetails = await _getEventDetails();

      // Get denominations if CASH
      Map<int, int>? denominations;
      if (moi['payment_method'] == 'CASH') {
        denominations = await _getDenominations(moi['id']);
      }

      // Parse persons data
      String? person1Name;
      String? person1Job;
      String? person2Details;
      if (moi['persons'] != null) {
        List<dynamic> personsList = moi['persons'] as List;
        if (personsList.isNotEmpty) {
          person1Name = personsList[0]['name'];
          person1Job = personsList[0]['job'];
        }
        if (personsList.length > 1) {
          person2Details = personsList[1]['details'];
        }
      }

      final result = await MoiReceiptGenerator.generateSingleMoiReceiptWithImage(
        context: context,
        serialNo: moi['serial_no'],
        operatorName: operatorName,
        eventDate: eventDetails['event_date'],
        eventTime: eventDetails['event_time'],
        villageName: moi['village_name'],
        livingPlace: moi['living_place'],
        person1Name: person1Name,
        person1Job: person1Job,
        person2Details: person2Details,
        phone: moi['phone'],
        amount: (moi['amount'] is int) ? moi['amount'] : (moi['amount'] as double).toInt(),
        paymentMethod: moi['payment_method'],
        denominations: denominations,
        customerName: eventDetails['customer_name'],
        city: eventDetails['city'],
        customerPhone: eventDetails['customer_phone'],
        isUncle: moi['is_uncle'] ?? false,
        eventTitle: eventDetails['event_title'],
        eventFor: eventDetails['event_for'],
        eventTypeName: eventDetails['event_type_name'],
        venue: eventDetails['venue'],
        notes: moi['notes'],
      );

      if (result != null && mounted) {
        final printerService = ThermalPrinterService();
        await printerService.connectAndPrintImage(context, result['imageBytes']);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Receipt printed successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error printing receipt: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

// Print group receipt
  Future<void> _printGroupReceipt(int groupId) async {
    setState(() => _isLoading = true);

    try {
      // Get all MOIs in this group
      final groupMois = await _supabase
          .from('mois')
          .select('*')
          .eq('event_id', _eventId!)
          .eq('group_id', groupId)
          .eq('is_deleted', false)
          .order('created_at', ascending: true);

      if (groupMois.isEmpty) {
        throw Exception('No entries found for this group');
      }

      final operatorName = await _getOperatorName();
      final eventDetails = await _getEventDetails();

      // Calculate totals
      double totalAmount = 0.0;
      Map<int, int> totalDenominations = {
        500: 0, 200: 0, 100: 0, 50: 0, 20: 0, 10: 0, 5: 0, 1: 0,
      };

      for (var entry in groupMois) {
        var amountValue = entry['amount'];
        if (amountValue is int) {
          totalAmount += amountValue.toDouble();
        } else if (amountValue is double) {
          totalAmount += amountValue;
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

      final result = await MoiReceiptGenerator.generateGroupMoiReceiptWithImage(
        context: context,
        groupId: groupId,
        operatorName: operatorName,
        eventDate: eventDetails['event_date'],
        eventTime: eventDetails['event_time'],
        groupEntries: List<Map<String, dynamic>>.from(groupMois),
        totalAmount: totalAmount,
        totalDenominations: totalDenominations.values.any((v) => v > 0) ? totalDenominations : null,
        customerName: eventDetails['customer_name'],
        city: eventDetails['city'],
        customerPhone: eventDetails['customer_phone'],
        eventTitle: eventDetails['event_title'],
        eventFor: eventDetails['event_for'],
        eventTypeName: eventDetails['event_type_name'],
        venue: eventDetails['venue'],
      );

      if (result != null && mounted) {
        final printerService = ThermalPrinterService();
        await printerService.connectAndPrintImage(context, result['imageBytes']);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Group receipt printed successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error printing group receipt: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonsDetails(dynamic persons) {
    if (persons == null) {
      return const Text('No person details available');
    }

    try {
      List<dynamic> personsList = persons is String ? [] : (persons as List);

      if (personsList.isEmpty) {
        return const Text('No person details available');
      }

      return Column(
        children: personsList.asMap().entries.map((entry) {
          int index = entry.key;
          var person = entry.value;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border.all(color: Colors.black, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Person ${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),

                // Person 1 has 'name' and 'job' fields
                if (index == 0) ...[
                  _buildDetailRow('Name', person['name'] ?? 'N/A'),
                  _buildDetailRow('Job', person['job'] ?? 'N/A'),
                ],

                // Person 2 has 'details' field only
                if (index == 1) ...[
                  _buildDetailRow('Details', person['details'] ?? 'N/A'),
                ],
              ],
            ),
          );
        }).toList(),
      );
    } catch (e) {
      return const Text('Error displaying person details');
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
          'Collection Details',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _loadCollectionDetails,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Search Box
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _filterMois,
              decoration: InputDecoration(
                hintText: 'Search by name, village, or phone...',
                border: InputBorder.none,
                icon: const Icon(Icons.search, color: Colors.black),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.black),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _filteredMois = _mois;
                    });
                  },
                )
                    : null,
              ),
            ),
          ),

          // Summary Card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text(
                      'Total Entries',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_totalCount',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 2,
                  height: 60,
                  color: Colors.black,
                ),
                Column(
                  children: [
                    const Text(
                      'Total Amount',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${_totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // List of MOIs
          Expanded(
            child: _filteredMois.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _searchController.text.isEmpty
                        ? 'No collections found'
                        : 'No results found',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredMois.length,
              itemBuilder: (context, index) {
                final moi = _filteredMois[index];
                final personsDisplay = _getPersonsCompact(moi['persons']);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: InkWell(
                    onTap: () => _showMoiDetails(moi),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  personsDisplay,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                if (moi['village_name'] != null &&
                                    moi['village_name'].toString().isNotEmpty)
                                  Text(
                                    moi['village_name'],
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: moi['payment_method'] == 'CASH'
                                            ? Colors.green[50]
                                            : Colors.blue[50],
                                        border: Border.all(
                                          color: moi['payment_method'] == 'CASH'
                                              ? Colors.green
                                              : Colors.blue,
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        moi['payment_method'] ?? 'N/A',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: moi['payment_method'] == 'CASH'
                                              ? Colors.green
                                              : Colors.blue,
                                        ),
                                      ),
                                    ),
                                    if (moi['is_uncle'] == true)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange[50],
                                          border: Border.all(
                                            color: Colors.orange,
                                            width: 1,
                                          ),
                                        ),
                                        child: const Text(
                                          'UNCLE',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text(
                                '₹${moi['amount'] ?? '0'}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Pencil icon button (Edit)
                                  Container(
                                    height: 34,
                                    width: 34,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.black,
                                        width: 2,
                                      ),
                                    ),
                                    child: Material(
                                      color: Colors.white,
                                      child: InkWell(
                                        onTap: () => _editMoi(moi),
                                        child: const Icon(
                                          Icons.edit,
                                          size: 18,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // Printer icon button
                                  Container(
                                    height: 34,
                                    width: 34,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.black,
                                        width: 2,
                                      ),
                                    ),
                                    child: Material(
                                      color: Colors.white,
                                      child: InkWell(
                                        onTap: () => _handlePrint(moi),
                                        child: const Icon(
                                          Icons.print,
                                          size: 18,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
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
}