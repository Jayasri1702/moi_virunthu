import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/denomination_receipt_generator.dart';

class DenominationScreen extends StatefulWidget {
  final String eventId;

  const DenominationScreen({
    super.key,
    required this.eventId,
  });

  @override
  State<DenominationScreen> createState() => _DenominationScreenState();
}

class _DenominationScreenState extends State<DenominationScreen> {
  final _auth = AuthService();
  List<Map<String, dynamic>> userDenominations = [];
  bool _isLoading = true;

  // Summary data
  Map<String, dynamic> _summaryData = {};
  bool _isLoadingSummary = false;

  final List<int> denominations = [500, 200, 100, 50, 20, 10, 5, 1];

  @override
  void initState() {
    super.initState();
    _loadDenominations();
  }

  Future<void> _loadDenominations() async {
    setState(() => _isLoading = true);

    try {
      // Fetch MOI denominations for CASH payments
      final moiData = await _auth.client
          .from('moi_denominations')
          .select('''
            operator_id,
            denom_500,
            denom_200,
            denom_100,
            denom_50,
            denom_20,
            denom_10,
            denom_5,
            denom_1,
            users!moi_denominations_operator_id_fkey (
              id,
              full_name
            ),
            mois!moi_denominations_moi_id_fkey (
              payment_method
            )
          ''')
          .eq('event_id', widget.eventId);

      // Fetch cash withdrawals with denominations
      final withdrawalData = await _auth.client
          .from('cash_withdrawals')
          .select('''
            operator_id,
            cash_withdrawal_denominations (
              denom_500,
              denom_200,
              denom_100,
              denom_50,
              denom_20,
              denom_10,
              denom_5,
              denom_1
            )
          ''')
          .eq('event_id', widget.eventId);

      // Fetch cash exchanges with denominations
      final exchangeData = await _auth.client
          .from('cash_exchanges')
          .select('''
            operator_id,
            cash_exchange_denominations (
              denom_500,
              denom_200,
              denom_100,
              denom_50,
              denom_20,
              denom_10,
              denom_5,
              denom_1
            )
          ''')
          .eq('event_id', widget.eventId);

      // Calculate current denominations
      Map<String, Map<String, dynamic>> operatorDenoms = {};

      // Step 1: ADD MOI denominations (cash collected by operator)
      for (var entry in moiData) {
        final operatorId = entry['operator_id'];
        if (operatorId == null) continue;

        final paymentMethod = entry['mois']?['payment_method'];
        if (paymentMethod != 'CASH') continue;

        final operatorName = entry['users']?['full_name'] ?? 'Unknown';

        if (!operatorDenoms.containsKey(operatorId)) {
          operatorDenoms[operatorId] = {
            'user_name': operatorName,
            'denom_500': 0,
            'denom_200': 0,
            'denom_100': 0,
            'denom_50': 0,
            'denom_20': 0,
            'denom_10': 0,
            'denom_5': 0,
            'denom_1': 0,
          };
        }

        // ADD collected denominations from MOI
        for (var denom in denominations) {
          int currentValue = operatorDenoms[operatorId]!['denom_$denom'] as int;
          int addValue = entry['denom_$denom'] ?? 0;
          operatorDenoms[operatorId]!['denom_$denom'] = currentValue + addValue;
        }
      }

      // Step 2: SUBTRACT withdrawal denominations
      for (var withdrawal in withdrawalData) {
        final operatorId = withdrawal['operator_id'];
        if (operatorId == null) continue;

        final denomData = withdrawal['cash_withdrawal_denominations'];
        if (denomData == null) continue;

        if (!operatorDenoms.containsKey(operatorId)) {
          continue;
        }

        for (var denom in denominations) {
          int currentValue = operatorDenoms[operatorId]!['denom_$denom'] as int;
          int subtractValue = denomData['denom_$denom'] ?? 0;
          operatorDenoms[operatorId]!['denom_$denom'] = currentValue - subtractValue;
        }
      }

      // Step 3: ADD/SUBTRACT exchange denominations
      for (var exchange in exchangeData) {
        final operatorId = exchange['operator_id'];
        if (operatorId == null) continue;

        final denomData = exchange['cash_exchange_denominations'];
        if (denomData == null) continue;

        if (!operatorDenoms.containsKey(operatorId)) {
          continue;
        }

        for (var denom in denominations) {
          int currentValue = operatorDenoms[operatorId]!['denom_$denom'] as int;
          int exchangeValue = denomData['denom_$denom'] ?? 0;
          operatorDenoms[operatorId]!['denom_$denom'] = currentValue + exchangeValue;
        }
      }

      // Convert to list and sort by name
      List<Map<String, dynamic>> denoms = operatorDenoms.values.toList();
      denoms.sort((a, b) =>
          (a['user_name'] as String).compareTo(b['user_name'] as String));

      setState(() {
        userDenominations = denoms;
      });

      // Calculate summary data
      await _calculateSummary();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading denomination data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Calculate summary method with corrected formulas
  Future<void> _calculateSummary() async {
    setState(() => _isLoadingSummary = true);

    try {
      // Get total denomination amounts (CASH only)
      final moiTotal = await _auth.client
          .from('moi_denominations')
          .select('''
            total_amount,
            mois!moi_denominations_moi_id_fkey (
              payment_method,
              is_deleted,
              amount
            )
          ''')
          .eq('event_id', widget.eventId);

      double totalCashCollected = 0;
      for (var entry in moiTotal) {
        final moi = entry['mois'];
        if (moi != null &&
            moi['payment_method'] == 'CASH' &&
            moi['is_deleted'] == false) {
          totalCashCollected += ((entry['total_amount'] ?? 0) as num).toDouble();
        }
      }

      // Get total withdrawals
      final withdrawalData = await _auth.client
          .from('cash_withdrawals')
          .select('amount')
          .eq('event_id', widget.eventId);

      double totalWithdrawals = 0;
      for (var item in withdrawalData) {
        totalWithdrawals += ((item['amount'] ?? 0) as num).toDouble();
      }

      // Get OTHERS payment total (Check/Advance/UPI)
      final othersData = await _auth.client
          .from('mois')
          .select('amount')
          .eq('event_id', widget.eventId)
          .neq('payment_method', 'CASH')
          .eq('is_deleted', false);

      double totalOthers = 0;
      for (var item in othersData) {
        totalOthers += ((item['amount'] ?? 0) as num).toDouble();
      }

      // Get total people count
      final peopleCount = await _auth.client
          .from('mois')
          .select('id')
          .eq('event_id', widget.eventId)
          .eq('is_deleted', false);

      // Calculate totals as per requirements:
      // Total Event Amount = Total Cash Collected + Check/Advance/UPI (without withdrawals)
      double totalEventAmount = totalCashCollected + totalOthers;

      // Hand Cash = Total Event Amount - Total Withdrawals
      double handCash = totalEventAmount - totalWithdrawals;

      setState(() {
        _summaryData = {
          'totalCashCollected': totalCashCollected,
          'totalWithdrawals': totalWithdrawals,
          'totalOthers': totalOthers,
          'peopleCount': peopleCount.length,
          'totalEventAmount': totalEventAmount,
          'handCash': handCash,
        };
      });
    } catch (e) {
      print('Error calculating summary: $e');
    } finally {
      setState(() => _isLoadingSummary = false);
    }
  }

  // Calculate totals - sum absolute values
  Map<String, dynamic> _calculateTotals() {
    Map<int, int> totalCounts = {500: 0, 200: 0, 100: 0, 50: 0, 20: 0, 10: 0, 5: 0, 1: 0};
    Map<int, int> totalAmounts = {500: 0, 200: 0, 100: 0, 50: 0, 20: 0, 10: 0, 5: 0, 1: 0};

    for (var user in userDenominations) {
      for (var denom in denominations) {
        int count = (user['denom_$denom'] ?? 0).abs();
        totalCounts[denom] = (totalCounts[denom] ?? 0) + count;
        totalAmounts[denom] = (totalAmounts[denom] ?? 0) + (count * denom);
      }
    }

    int grandTotal = totalAmounts.values.fold(0, (sum, amount) => sum + amount);

    return {
      'counts': totalCounts,
      'amounts': totalAmounts,
      'grandTotal': grandTotal,
    };
  }

  String _formatAmount(int amount) {
    final absAmount = amount.abs();
    return absAmount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    final totals = _calculateTotals();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF6B4C9A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Denomination',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: const Text(
              'Cash Denomination List',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 16),

          // Table with proper scrolling
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  // Table
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Table Header
                          Container(
                            color: const Color(0xFF6B4C9A),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: IntrinsicHeight(
                              child: Row(
                                children: [
                                  _buildHeaderCell('User', width: 120),
                                  _buildHeaderCell('500', width: 60),
                                  _buildHeaderCell('200', width: 60),
                                  _buildHeaderCell('100', width: 60),
                                  _buildHeaderCell('50', width: 60),
                                  _buildHeaderCell('20', width: 60),
                                  _buildHeaderCell('10', width: 60),
                                  _buildHeaderCell('5', width: 60),
                                  _buildHeaderCell('1', width: 60),
                                  _buildHeaderCell('Total', width: 100),
                                ],
                              ),
                            ),
                          ),

                          // Table Body
                          _isLoading
                              ? Container(
                            padding: const EdgeInsets.all(40),
                            child: const CircularProgressIndicator(
                              color: Color(0xFF6B4C9A),
                            ),
                          )
                              : userDenominations.isEmpty
                              ? Container(
                            padding: const EdgeInsets.all(40),
                            child: const Text(
                              'No denomination data available',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          )
                              : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: userDenominations.map((user) {
                              int userTotal = 0;
                              for (var denom in denominations) {
                                int count = user['denom_$denom'] ?? 0;
                                userTotal += count * denom;
                              }

                              return Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.grey[300]!,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: IntrinsicHeight(
                                  child: Row(
                                    children: [
                                      _buildDataCell(
                                        user['user_name'] ?? '',
                                        width: 120,
                                        bold: true,
                                      ),
                                      _buildDataCell(
                                        ((user['denom_500'] ?? 0) as int).abs().toString(),
                                        width: 60,
                                      ),
                                      _buildDataCell(
                                        ((user['denom_200'] ?? 0) as int).abs().toString(),
                                        width: 60,
                                      ),
                                      _buildDataCell(
                                        ((user['denom_100'] ?? 0) as int).abs().toString(),
                                        width: 60,
                                      ),
                                      _buildDataCell(
                                        ((user['denom_50'] ?? 0) as int).abs().toString(),
                                        width: 60,
                                      ),
                                      _buildDataCell(
                                        ((user['denom_20'] ?? 0) as int).abs().toString(),
                                        width: 60,
                                      ),
                                      _buildDataCell(
                                        ((user['denom_10'] ?? 0) as int).abs().toString(),
                                        width: 60,
                                      ),
                                      _buildDataCell(
                                        ((user['denom_5'] ?? 0) as int).abs().toString(),
                                        width: 60,
                                      ),
                                      _buildDataCell(
                                        ((user['denom_1'] ?? 0) as int).abs().toString(),
                                        width: 60,
                                      ),
                                      _buildDataCell(
                                        _formatAmount(userTotal),
                                        width: 100,
                                        bold: true,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                          // Denomination Labels Row
                          Container(
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Colors.grey[400]!, width: 2),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: IntrinsicHeight(
                              child: Row(
                                children: [
                                  _buildFooterCell('', width: 120),
                                  _buildFooterCell('500', width: 60, color: Colors.red),
                                  _buildFooterCell('200', width: 60, color: Colors.red),
                                  _buildFooterCell('100', width: 60, color: Colors.red),
                                  _buildFooterCell('50', width: 60, color: Colors.red),
                                  _buildFooterCell('20', width: 60, color: Colors.red),
                                  _buildFooterCell('10', width: 60, color: Colors.red),
                                  _buildFooterCell('5', width: 60, color: Colors.red),
                                  _buildFooterCell('1', width: 60, color: Colors.red),
                                  _buildFooterCell('', width: 100),
                                ],
                              ),
                            ),
                          ),

                          // Total Count Row
                          Container(
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Colors.grey[300]!, width: 1),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: IntrinsicHeight(
                              child: Row(
                                children: [
                                  _buildFooterCell('Total Count', width: 120, bold: true),
                                  _buildFooterCell(
                                    (totals['counts'][500] as int).abs().toString(),
                                    width: 60,
                                  ),
                                  _buildFooterCell(
                                    (totals['counts'][200] as int).abs().toString(),
                                    width: 60,
                                  ),
                                  _buildFooterCell(
                                    (totals['counts'][100] as int).abs().toString(),
                                    width: 60,
                                  ),
                                  _buildFooterCell(
                                    (totals['counts'][50] as int).abs().toString(),
                                    width: 60,
                                  ),
                                  _buildFooterCell(
                                    (totals['counts'][20] as int).abs().toString(),
                                    width: 60,
                                  ),
                                  _buildFooterCell(
                                    (totals['counts'][10] as int).abs().toString(),
                                    width: 60,
                                  ),
                                  _buildFooterCell(
                                    (totals['counts'][5] as int).abs().toString(),
                                    width: 60,
                                  ),
                                  _buildFooterCell(
                                    (totals['counts'][1] as int).abs().toString(),
                                    width: 60,
                                  ),
                                  _buildFooterCell('', width: 100),
                                ],
                              ),
                            ),
                          ),

                          // Total Amount Row
                          Container(
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Colors.grey[300]!, width: 1),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: IntrinsicHeight(
                              child: Row(
                                children: [
                                  _buildFooterCell('Total Amount', width: 120, bold: true),
                                  _buildFooterCell(
                                    _formatAmount(totals['amounts'][500] as int),
                                    width: 60,
                                  ),
                                  _buildFooterCell(
                                    _formatAmount(totals['amounts'][200] as int),
                                    width: 60,
                                  ),
                                  _buildFooterCell(
                                    _formatAmount(totals['amounts'][100] as int),
                                    width: 60,
                                  ),
                                  _buildFooterCell(
                                    _formatAmount(totals['amounts'][50] as int),
                                    width: 60,
                                  ),
                                  _buildFooterCell(
                                    _formatAmount(totals['amounts'][20] as int),
                                    width: 60,
                                  ),
                                  _buildFooterCell(
                                    _formatAmount(totals['amounts'][10] as int),
                                    width: 60,
                                  ),
                                  _buildFooterCell(
                                    _formatAmount(totals['amounts'][5] as int),
                                    width: 60,
                                  ),
                                  _buildFooterCell(
                                    _formatAmount(totals['amounts'][1] as int),
                                    width: 60,
                                  ),
                                  _buildFooterCell(
                                    _formatAmount(totals['grandTotal'] as int),
                                    width: 100,
                                    bold: true,
                                    color: Colors.blue,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Summary Section with corrected calculations
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Summary',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(thickness: 2, color: Colors.black),
                        const SizedBox(height: 8),
                        _buildSummaryRow(
                          'Total Cash Collected',
                          '₹${_formatAmount((_summaryData['totalCashCollected'] ?? 0).round())}',
                          Colors.green,
                        ),
                        const SizedBox(height: 8),
                        _buildSummaryRow(
                          'Total Withdrawals',
                          '₹${_formatAmount((_summaryData['totalWithdrawals'] ?? 0).round())}',
                          Colors.red,
                        ),
                        const SizedBox(height: 8),
                        _buildSummaryRow(
                          'Check/Advance/UPI',
                          '₹${_formatAmount((_summaryData['totalOthers'] ?? 0).round())}',
                          Colors.orange,
                        ),
                        const SizedBox(height: 8),
                        _buildSummaryRow(
                          'Total People',
                          '${_summaryData['peopleCount'] ?? 0}',
                          Colors.purple,
                        ),
                        const SizedBox(height: 8),
                        _buildSummaryRow(
                          'Total Event Amount',
                          '₹${_formatAmount((_summaryData['totalEventAmount'] ?? 0).round())}',
                          Colors.blue,
                        ),
                        const SizedBox(height: 8),
                        _buildSummaryRow(
                          'Hand Cash',
                          '₹${_formatAmount((_summaryData['handCash'] ?? 0).round())}',
                          Colors.teal,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () async {
                      try {
                        // Get event details
                        final eventData = await _auth.client
                            .from('events')
                            .select('''
                    customer_name,
                    customer_phone,
                    venue,
                    city,
                    event_date,
                    event_types!events_event_type_fkey (
                      name
                    )
                  ''')
                            .eq('id', widget.eventId)
                            .single();

                        if (eventData == null) {
                          throw Exception('Event not found');
                        }

                        final customerName = eventData['customer_name'] ?? 'N/A';
                        final eventTypeName = eventData['event_types']?['name'] ?? 'Event';
                        final venue = eventData['venue'] ?? 'N/A';
                        final city = eventData['city'] ?? 'N/A';
                        final contactNumber = eventData['customer_phone'] ?? 'N/A';
                        final eventDate = DateTime.parse(eventData['event_date']);

                        // Calculate totals
                        final totals = _calculateTotals();

                        // Calculate verupaadu (difference between hand cash and grand total)
                        final verupaadu = (_summaryData['handCash'] ?? 0) - (totals['grandTotal'] as int);

                        // Show loading
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Generating receipt...'),
                              backgroundColor: Colors.blue,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }

                        // Generate receipt
                        final file = await DenominationReceiptGenerator.generateDenominationReceipt(
                          context: context,
                          customerName: customerName,
                          eventTypeName: eventTypeName,
                          venue: venue,
                          city: city,
                          contactNumber: contactNumber,
                          eventDate: eventDate,
                          denominationCounts: totals['counts'] as Map<int, int>,
                          denominationAmounts: totals['amounts'] as Map<int, int>,
                          grandTotal: totals['grandTotal'] as int,
                          totalCashCollected: ((_summaryData['totalCashCollected'] ?? 0) as num).toDouble(),
                          computedTotal: ((_summaryData['totalEventAmount'] ?? 0) as num).toDouble(),
                          totalWithdrawals: ((_summaryData['totalWithdrawals'] ?? 0) as num).toDouble(),
                          verupaadu: (verupaadu as num).toDouble(),
                          peopleCount: _summaryData['peopleCount'] ?? 0,
                          totalOthersAmount: ((_summaryData['totalOthers'] ?? 0) as num).toDouble(),
                        );

                        if (file == null) {
                          throw Exception('Failed to generate receipt');
                        }

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Receipt generated successfully!'),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      } catch (e) {
                        print('Error generating receipt: $e');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error generating receipt: ${e.toString()}'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.black, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Text(
                      'Print',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.black, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Text(
                      'Exit',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, {required double width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.5), width: 1),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildDataCell(String text, {required double width, bool bold = false}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildFooterCell(
      String text, {
        required double width,
        bool bold = false,
        Color? color,
      }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: color ?? Colors.black,
        ),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // Summary row builder
  Widget _buildSummaryRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}