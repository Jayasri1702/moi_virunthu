import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../utils/network_utils.dart';

class ProfitDashboardScreen extends StatefulWidget {
  const ProfitDashboardScreen({super.key});

  @override
  State<ProfitDashboardScreen> createState() => _ProfitDashboardScreenState();
}

class _ProfitDashboardScreenState extends State<ProfitDashboardScreen> {
  final _auth = AuthService();

  bool _loading = false;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  // Analytics data
  int _totalEvents = 0;
  double _totalBookedAmount = 0;
  double _totalAdvanceAmount = 0;
  double _totalDiscountAmount = 0;
  double _totalBalanceLiveAmount = 0;
  double _totalNetProfit = 0;
  double _totalOperatorSalaries = 0;
  double _totalTravelCost = 0;
  double _totalTeaCost = 0;
  double _totalPaperRollCost = 0;
  double _totalMiscCost = 0;
  double _totalNote1Cost = 0;
  double _totalNote2Cost = 0;

  List<Map<String, dynamic>> _eventsList = [];
  Map<String, double> _operatorWiseSalaries = {};

  @override
  void initState() {
    super.initState();
    _loadProfitData();
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: _endDate,
    );

    if (picked != null && picked != _startDate) {
      setState(() => _startDate = picked);
      _loadProfitData();
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null && picked != _endDate) {
      setState(() => _endDate = picked);
      _loadProfitData();
    }
  }

  Future<void> _loadProfitData() async {
    setState(() => _loading = true);

    try {
      final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate);

      // Fetch events within date range with pagination
      List<dynamic> events = [];
      int pageSize = 1000;
      int currentPage = 0;
      bool hasMore = true;

      while (hasMore) {
        final pageResponse = await _auth.client
            .from('events')
            .select('''
              *,
              event_types!inner(id, name)
            ''')
            .gte('event_date', startDateStr)
            .lte('event_date', endDateStr)
            .order('event_date', ascending: false)
            .range(currentPage * pageSize, (currentPage + 1) * pageSize - 1);

        events.addAll(pageResponse);

        if (pageResponse.length < pageSize) {
          hasMore = false;
        } else {
          currentPage++;
        }
      }

      // Fetch operator assignments and salaries for all events
      final eventIds = events.map((e) => e['id']).toList();

      Map<String, double> operatorSalaries = {};

      if (eventIds.isNotEmpty) {
        // Fetch assignments with pagination
        List<dynamic> assignments = [];
        currentPage = 0;
        hasMore = true;

        while (hasMore) {
          final pageResponse = await _auth.client
              .from('event_assignments')
              .select('''
                event_id,
                operator_id,
                salary,
                users!inner(id, full_name)
              ''')
              .inFilter('event_id', eventIds)
              .range(currentPage * pageSize, (currentPage + 1) * pageSize - 1);

          assignments.addAll(pageResponse);

          if (pageResponse.length < pageSize) {
            hasMore = false;
          } else {
            currentPage++;
          }
        }

        for (var assignment in assignments) {
          final operatorName = assignment['users']['full_name'];
          final salary = (assignment['salary'] ?? 0).toDouble();

          operatorSalaries[operatorName] = (operatorSalaries[operatorName] ?? 0) + salary;
        }
      }

      // Calculate totals
      double totalBooked = 0;
      double totalAdvance = 0;
      double totalDiscount = 0;
      double totalBalanceLive = 0;
      double totalOperatorSalaries = 0;
      double totalTravel = 0;
      double totalTea = 0;
      double totalPaper = 0;
      double totalMisc = 0;
      double totalNote1 = 0;
      double totalNote2 = 0;

      for (var event in events) {
        totalBooked += (event['booked_amount'] ?? 0).toDouble();
        totalAdvance += (event['advance_amount'] ?? 0).toDouble();
        totalDiscount += (event['discount_amount'] ?? 0).toDouble();
        totalBalanceLive += (event['balance_live_amount'] ?? 0).toDouble();

        totalTravel += (event['travel_cost'] ?? 0).toDouble();
        totalTea += (event['tea_cost'] ?? 0).toDouble();
        totalPaper += (event['paper_roll_cost'] ?? 0).toDouble();
        totalMisc += (event['misc_cost'] ?? 0).toDouble();
        totalNote1 += (event['note1_cost'] ?? 0).toDouble();
        totalNote2 += (event['note2_cost'] ?? 0).toDouble();
      }

      totalOperatorSalaries = operatorSalaries.values.fold(0, (sum, val) => sum + val);

      // ✅ FIXED: Net Profit = Booked Amount - All Expenses (Travel + Tea + Paper + Operator Salaries + Misc + Note1 + Note2)
      // DO NOT subtract Advance, Discount, or Balance Live Amount
      double totalNetProfit = totalBooked - (totalTravel + totalTea + totalPaper + totalMisc + totalNote1 + totalNote2 + totalOperatorSalaries);

      setState(() {
        _totalEvents = events.length;
        _totalBookedAmount = totalBooked;
        _totalAdvanceAmount = totalAdvance;
        _totalDiscountAmount = totalDiscount;
        _totalBalanceLiveAmount = totalBalanceLive;
        _totalNetProfit = totalNetProfit;
        _totalOperatorSalaries = totalOperatorSalaries;
        _totalTravelCost = totalTravel;
        _totalTeaCost = totalTea;
        _totalPaperRollCost = totalPaper;
        _totalMiscCost = totalMisc;
        _totalNote1Cost = totalNote1;
        _totalNote2Cost = totalNote2;

        _eventsList = List<Map<String, dynamic>>.from(events);
        _operatorWiseSalaries = operatorSalaries;

        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          onRetry: _loadProfitData,
          customMessage: 'Error loading profit data',
        );
      }
    }
  }

  // ✅ FIXED: Show total events details dialog
  void _showEventsListDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 700,
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event, color: Colors.white),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Events List',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: _eventsList.isEmpty
                    ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No events found'),
                  ),
                )
                    : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _eventsList.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey[300]),
                  itemBuilder: (context, index) {
                    final event = _eventsList[index];
                    final eventDate = event['event_date'] != null
                        ? DateFormat('dd-MM-yyyy').format(DateTime.parse(event['event_date']))
                        : 'N/A';
                    final customerName = event['customer_name'] ?? 'N/A';
                    final eventType = event['event_types']?['name'] ?? 'N/A';
                    final venue = event['venue'] ?? 'N/A';

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.withOpacity(0.1),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        customerName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            'Event: $eventType',
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          Text(
                            'Date: $eventDate',
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          Text(
                            'Venue: $venue',
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ],
                      ),
                      isThreeLine: true,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ FIXED: Show total booked amount details dialog with proper overflow handling
  void _showBookedAmountDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 700,
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.currency_rupee, color: Colors.white),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Event-wise Booked Amount',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: _eventsList.isEmpty
                    ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No events found'),
                  ),
                )
                    : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _eventsList.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey[300]),
                  itemBuilder: (context, index) {
                    final event = _eventsList[index];
                    final eventDate = event['event_date'] != null
                        ? DateFormat('dd-MM-yyyy').format(DateTime.parse(event['event_date']))
                        : 'N/A';
                    final customerName = event['customer_name'] ?? 'N/A';
                    final eventType = event['event_types']?['name'] ?? 'N/A';
                    final bookedAmount = (event['booked_amount'] ?? 0).toDouble();

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          // Leading avatar
                          CircleAvatar(
                            backgroundColor: Colors.green.withOpacity(0.1),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Event details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  customerName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Event: $eventType',
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                Text(
                                  'Date: $eventDate',
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Amount
                          Container(
                            constraints: const BoxConstraints(minWidth: 100, maxWidth: 140),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green, width: 1),
                            ),
                            child: Text(
                              '₹${bookedAmount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // Footer with total
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border(
                    top: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Booked Amount',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        '₹ ${_totalBookedAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
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

  // ✅ FIXED: Show operator salaries breakdown dialog with proper overflow handling
  void _showOperatorSalariesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.people, color: Color(0xFFB846D7)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Operator-wise Salaries',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: _operatorWiseSalaries.isEmpty
              ? const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No operator salaries found'),
          )
              : ListView.separated(
            shrinkWrap: true,
            itemCount: _operatorWiseSalaries.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey[300]),
            itemBuilder: (context, index) {
              final entry = _operatorWiseSalaries.entries.elementAt(index);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFFB846D7),
                      radius: 18,
                      child: Text(
                        entry.key.isNotEmpty ? entry.key[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      constraints: const BoxConstraints(minWidth: 80, maxWidth: 120),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB846D7).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '₹${entry.value.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFB846D7),
                        ),
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
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
  }

  // ✅ FIXED: Show expenses breakdown dialog with proper overflow handling
  void _showExpensesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.receipt_long, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Expenses Breakdown',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Travel Cost', _totalTravelCost),
                _buildDetailRow('Tea Cost', _totalTeaCost),
                _buildDetailRow('Paper Roll Cost', _totalPaperRollCost),
                _buildDetailRow('Miscellaneous Cost', _totalMiscCost),
                _buildDetailRow('Notes 1', _totalNote1Cost),
                _buildDetailRow('Notes 2', _totalNote2Cost),
                const Divider(thickness: 2),
                _buildDetailRow(
                  'Total Expenses',
                  _totalTravelCost + _totalTeaCost + _totalPaperRollCost +
                      _totalMiscCost + _totalNote1Cost + _totalNote2Cost,
                  isBold: true,
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
        ],
      ),
    );
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
                  'Profit Dashboard',
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
                          const Icon(Icons.analytics, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'PROFIT ANALYSIS',
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

                    // Date Range Selector
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        border: Border(
                          bottom: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Select Date Range',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              // Start Date
                              InkWell(
                                onTap: _selectStartDate,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey[400]!),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.calendar_today, size: 18),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'From',
                                            style: TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                          Text(
                                            DateFormat('dd-MM-yyyy').format(_startDate),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // End Date
                              InkWell(
                                onTap: _selectEndDate,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey[400]!),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.calendar_today, size: 18),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'To',
                                            style: TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                          Text(
                                            DateFormat('dd-MM-yyyy').format(_endDate),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Refresh Button
                              ElevatedButton.icon(
                                onPressed: _loading ? null : _loadProfitData,
                                icon: _loading
                                    ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                    : const Icon(Icons.refresh, size: 18),
                                label: const Text('Refresh'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFB846D7),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Content
                    _loading
                        ? const Padding(
                      padding: EdgeInsets.all(48.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                        : Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Summary Cards - Now Interactive
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              _buildSummaryCard(
                                'Total Events',
                                _totalEvents.toString(),
                                Icons.event,
                                Colors.blue,
                                onTap: _showEventsListDialog,
                              ),
                              _buildSummaryCard(
                                'Total Booked',
                                '₹ ${_totalBookedAmount.toStringAsFixed(0)}',
                                Icons.currency_rupee,
                                Colors.green,
                                onTap: _showBookedAmountDialog,
                              ),
                              _buildSummaryCard(
                                'Total Expenses',
                                '₹ ${(_totalTravelCost + _totalTeaCost + _totalPaperRollCost + _totalMiscCost + _totalNote1Cost + _totalNote2Cost).toStringAsFixed(0)}',
                                Icons.receipt_long,
                                Colors.orange,
                                onTap: _showExpensesDialog,
                              ),
                              _buildSummaryCard(
                                'Operator Salaries',
                                '₹ ${_totalOperatorSalaries.toStringAsFixed(0)}',
                                Icons.people,
                                const Color(0xFFB846D7),
                                onTap: _showOperatorSalariesDialog,
                              ),
                            ],
                          ),

                          const SizedBox(height: 32),

                          // ✅ FIXED: Net Profit Display with proper overflow handling
                          Center(
                            child: Container(
                              width: double.infinity,
                              constraints: const BoxConstraints(maxWidth: 600),
                              padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    _totalNetProfit >= 0 ? Colors.green[400]! : Colors.red[400]!,
                                    _totalNetProfit >= 0 ? Colors.green[600]! : Colors.red[600]!,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_totalNetProfit >= 0 ? Colors.green : Colors.red).withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _totalNetProfit >= 0 ? Icons.trending_up : Icons.trending_down,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          'TOTAL NET PROFIT',
                                          style: TextStyle(
                                            fontSize: isSmallScreen ? 16 : 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            letterSpacing: 1.2,
                                          ),
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '₹ ${_totalNetProfit.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 32 : 42,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        shadows: const [
                                          Shadow(
                                            color: Colors.black26,
                                            offset: Offset(2, 2),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'from $_totalEvents event${_totalEvents != 1 ? 's' : ''}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Footer
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        border: Border(
                          top: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            width: 120,
                            height: 45,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close', style: TextStyle(fontSize: 16)),
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

  Widget _buildSummaryCard(
      String title,
      String value,
      IconData icon,
      Color color, {
        VoidCallback? onTap,
      }) {
    final card = Container(
      width: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              if (onTap != null)
                Icon(Icons.touch_app, color: color.withOpacity(0.5), size: 20),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          // ✅ FIXED: Better overflow handling for card values
          SizedBox(
            width: 210,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: card,
      );
    }

    return card;
  }

  Widget _buildDetailRow(String label, double amount, {bool isNegative = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: TextStyle(
                fontSize: isBold ? 16 : 15,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: Colors.grey[800],
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              '${isNegative ? '- ' : ''}₹ ${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: isBold ? 16 : 15,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: isNegative ? Colors.red : (isBold ? Colors.black : Colors.grey[800]),
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}