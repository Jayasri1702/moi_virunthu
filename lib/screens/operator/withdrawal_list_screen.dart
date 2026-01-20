import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../utils/network_utils.dart';

class WithdrawalListScreen extends StatefulWidget {
  final String eventId;
  final String? operatorId;

  const WithdrawalListScreen({
    super.key,
    required this.eventId,
    this.operatorId,
  });

  @override
  State<WithdrawalListScreen> createState() => _WithdrawalListScreenState();
}

class _WithdrawalListScreenState extends State<WithdrawalListScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _withdrawals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWithdrawals();
  }

  Future<void> _loadWithdrawals() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch all withdrawals with pagination
      List<dynamic> response = [];
      int pageSize = 1000;
      int currentPage = 0;
      bool hasMore = true;

      while (hasMore) {
        final pageResponse = await _supabase
            .from('cash_withdrawals')
            .select('''
        id,
        requested_by,
        requester_phone_number,
        amount,
        reason,
        created_at,
        users!cash_withdrawals_operator_id_fkey (
          full_name
        ),
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
            .eq('event_id', widget.eventId)
            .order('created_at', ascending: false)
            .range(currentPage * pageSize, (currentPage + 1) * pageSize - 1);

        response.addAll(pageResponse);

        if (pageResponse.length < pageSize) {
          hasMore = false;
        } else {
          currentPage++;
        }
      }

      setState(() {
        _withdrawals = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading withdrawals: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          onRetry: _loadWithdrawals,
          customMessage: 'Error loading withdrawals',
        );
      }
    }
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final utcDate = DateTime.parse(dateStr).toUtc();
      final localDate = utcDate.toLocal(); // 🔥 Convert to local timezone
      return DateFormat('dd-MM-yyyy hh:mm a').format(localDate);
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Withdrawal List',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _loadWithdrawals,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _withdrawals.isEmpty
          ? const Center(
        child: Text(
          'No withdrawals found',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _withdrawals.length,
        itemBuilder: (context, index) {
          final withdrawal = _withdrawals[index];
          return _buildWithdrawalCard(withdrawal);
        },
      ),
    );
  }

  Widget _buildWithdrawalCard(Map<String, dynamic> withdrawal) {
    final denominations = withdrawal['cash_withdrawal_denominations'];
    final operatorName = withdrawal['users']?['full_name'] ?? 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.red,
              border: Border(
                bottom: BorderSide(color: Colors.black, width: 2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'WITHDRAWAL',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '₹${(withdrawal['amount'] ?? 0).toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Requested By', withdrawal['requested_by'] ?? 'N/A'),
                const SizedBox(height: 8),
                _buildDetailRow('Phone', withdrawal['requester_phone_number'] ?? 'N/A'),
                const SizedBox(height: 8),
                _buildDetailRow('Operator', operatorName),
                const SizedBox(height: 8),
                _buildDetailRow('Date & Time', _formatDateTime(withdrawal['created_at'])),
                if (withdrawal['reason'] != null && withdrawal['reason'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildDetailRow('Reason', withdrawal['reason']),
                ],

                // Denominations
                if (denominations != null) ...[
                  const SizedBox(height: 16),
                  const Divider(color: Colors.black, thickness: 2),
                  const SizedBox(height: 12),
                  const Text(
                    'Denomination Breakdown',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDenominationGrid(denominations),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildDenominationGrid(Map<String, dynamic> denom) {
    final denominations = [
      {'value': '500', 'count': denom['denom_500'] ?? 0},
      {'value': '200', 'count': denom['denom_200'] ?? 0},
      {'value': '100', 'count': denom['denom_100'] ?? 0},
      {'value': '50', 'count': denom['denom_50'] ?? 0},
      {'value': '20', 'count': denom['denom_20'] ?? 0},
      {'value': '10', 'count': denom['denom_10'] ?? 0},
      {'value': '5', 'count': denom['denom_5'] ?? 0},
      {'value': '1', 'count': denom['denom_1'] ?? 0},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: denominations
          .where((d) => d['count'] as int > 0)
          .map((d) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          border: Border.all(color: Colors.black, width: 1),
        ),
        child: Text(
          '₹${d['value']} × ${d['count']} = ₹${(int.parse(d['value'] as String) * (d['count'] as int))}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ))
          .toList(),
    );
  }
}