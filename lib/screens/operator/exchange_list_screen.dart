import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../utils/network_utils.dart';

class ExchangeListScreen extends StatefulWidget {
  final String eventId;
  final String? operatorId;

  const ExchangeListScreen({
    super.key,
    required this.eventId,
    this.operatorId,
  });

  @override
  State<ExchangeListScreen> createState() => _ExchangeListScreenState();
}

class _ExchangeListScreenState extends State<ExchangeListScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _exchanges = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExchanges();
  }

  Future<void> _loadExchanges() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _supabase
          .from('cash_exchanges')
          .select('''
            id,
            amount,
            created_at,
            users!cash_exchanges_operator_id_fkey (
              full_name
            ),
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
          .eq('event_id', widget.eventId)
          .order('created_at', ascending: false);

      setState(() {
        _exchanges = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading exchanges: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          onRetry: _loadExchanges,
          customMessage: 'Error loading exchanges',
        );
      }
    }
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

  Map<String, Map<String, int>> _splitDenominations(
      Map<String, dynamic> netDenom) {
    Map<String, int> received = {};
    Map<String, int> returned = {};

    final denomValues = ['500', '200', '100', '50', '20', '10', '5', '1'];

    for (var denom in denomValues) {
      int netValue = netDenom['denom_$denom'] ?? 0;
      if (netValue > 0) {
        received[denom] = netValue;
        returned[denom] = 0;
      } else if (netValue < 0) {
        received[denom] = 0;
        returned[denom] = netValue.abs();
      } else {
        received[denom] = 0;
        returned[denom] = 0;
      }
    }

    return {'received': received, 'returned': returned};
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
          'Exchange List',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _loadExchanges,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _exchanges.isEmpty
          ? const Center(
        child: Text(
          'No exchanges found',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _exchanges.length,
        itemBuilder: (context, index) {
          final exchange = _exchanges[index];
          return _buildExchangeCard(exchange);
        },
      ),
    );
  }

  Widget _buildExchangeCard(Map<String, dynamic> exchange) {
    final denominations = exchange['cash_exchange_denominations'];
    final operatorName = exchange['users']?['full_name'] ?? 'Unknown';

    Map<String, Map<String, int>>? splitDenom;
    if (denominations != null) {
      splitDenom = _splitDenominations(denominations);
    }

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
              color: Colors.blue,
              border: Border(
                bottom: BorderSide(color: Colors.black, width: 2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'EXCHANGE',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '₹${(exchange['amount'] ?? 0).toStringAsFixed(0)}',
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
                _buildDetailRow('Operator', operatorName),
                const SizedBox(height: 8),
                _buildDetailRow(
                    'Date & Time', _formatDateTime(exchange['created_at'])),

                // Denominations
                if (splitDenom != null) ...[
                  const SizedBox(height: 16),
                  const Divider(color: Colors.black, thickness: 2),
                  const SizedBox(height: 12),

                  // Received Section
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        color: Colors.blue,
                        child: const Text(
                          'RECEIVED',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildDenominationGrid(splitDenom['received']!, Colors.blue),

                  const SizedBox(height: 16),

                  // Returned Section
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        color: Colors.green,
                        child: const Text(
                          'RETURNED',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildDenominationGrid(splitDenom['returned']!, Colors.green),
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

  Widget _buildDenominationGrid(Map<String, int> denom, Color color) {
    final denominations = [
      {'value': '500', 'count': denom['500'] ?? 0},
      {'value': '200', 'count': denom['200'] ?? 0},
      {'value': '100', 'count': denom['100'] ?? 0},
      {'value': '50', 'count': denom['50'] ?? 0},
      {'value': '20', 'count': denom['20'] ?? 0},
      {'value': '10', 'count': denom['10'] ?? 0},
      {'value': '5', 'count': denom['5'] ?? 0},
      {'value': '1', 'count': denom['1'] ?? 0},
    ];

    final filtered = denominations.where((d) => d['count'] as int > 0).toList();

    if (filtered.isEmpty) {
      return Text(
        'No denominations',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: filtered
          .map((d) =>
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              border: Border.all(color: color, width: 1),
            ),
            child: Text(
              '₹${d['value']} × ${d['count']} = ₹${(int.parse(
                  d['value'] as String) * (d['count'] as int))}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ))
          .toList(),
    );
  }
}