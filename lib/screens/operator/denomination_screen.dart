import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

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

  // Denomination values
  final List<int> denominations = [500, 200, 100, 50, 20, 10, 1];

  @override
  void initState() {
    super.initState();
    _loadDenominations();
  }

  Future<void> _loadDenominations() async {
    setState(() => _isLoading = true);

    try {
      // Fetch all moi_denominations for this event with operator info
      // Only for CASH payment method
      final data = await _auth.client
          .from('moi_denominations')
          .select('''
            moi_id,
            denom_500,
            denom_200,
            denom_100,
            denom_50,
            denom_20,
            denom_10,
            denom_1,
            operator_id,
            users!moi_denominations_operator_id_fkey (
              id,
              full_name
            ),
            mois!moi_denominations_moi_id_fkey (
              payment_method
            )
          ''')
          .eq('event_id', widget.eventId);

      // Filter only CASH payments and group by operator
      Map<String, Map<String, dynamic>> operatorDenoms = {};

      for (var entry in data) {
        final operatorId = entry['operator_id'];

        // Skip if no operator or not CASH payment
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
            'denom_1': 0,
          };
        }

        // Sum up denominations
        operatorDenoms[operatorId]!['denom_500'] =
            (operatorDenoms[operatorId]!['denom_500'] as int) + (entry['denom_500'] ?? 0);
        operatorDenoms[operatorId]!['denom_200'] =
            (operatorDenoms[operatorId]!['denom_200'] as int) + (entry['denom_200'] ?? 0);
        operatorDenoms[operatorId]!['denom_100'] =
            (operatorDenoms[operatorId]!['denom_100'] as int) + (entry['denom_100'] ?? 0);
        operatorDenoms[operatorId]!['denom_50'] =
            (operatorDenoms[operatorId]!['denom_50'] as int) + (entry['denom_50'] ?? 0);
        operatorDenoms[operatorId]!['denom_20'] =
            (operatorDenoms[operatorId]!['denom_20'] as int) + (entry['denom_20'] ?? 0);
        operatorDenoms[operatorId]!['denom_10'] =
            (operatorDenoms[operatorId]!['denom_10'] as int) + (entry['denom_10'] ?? 0);
        operatorDenoms[operatorId]!['denom_1'] =
            (operatorDenoms[operatorId]!['denom_1'] as int) + (entry['denom_1'] ?? 0);
      }

      // Convert to list and sort by name
      List<Map<String, dynamic>> denoms = operatorDenoms.values.toList();
      denoms.sort((a, b) =>
          (a['user_name'] as String).compareTo(b['user_name'] as String));

      setState(() {
        userDenominations = denoms;
      });
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

  // Calculate totals
  Map<String, dynamic> _calculateTotals() {
    Map<int, int> totalCounts = {500: 0, 200: 0, 100: 0, 50: 0, 20: 0, 10: 0, 1: 0};
    Map<int, int> totalAmounts = {500: 0, 200: 0, 100: 0, 50: 0, 20: 0, 10: 0, 1: 0};

    for (var user in userDenominations) {
      for (var denom in denominations) {
        int count = user['denom_$denom'] ?? 0;
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
    return amount.toString().replaceAllMapped(
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

          // Table
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: Column(
                children: [
                  // Table Header
                  Container(
                    color: const Color(0xFF6B4C9A),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        _buildHeaderCell('User', flex: 2),
                        _buildHeaderCell('500', flex: 1),
                        _buildHeaderCell('200', flex: 1),
                        _buildHeaderCell('100', flex: 1),
                        _buildHeaderCell('50', flex: 1),
                        _buildHeaderCell('20', flex: 1),
                        _buildHeaderCell('10', flex: 1),
                        _buildHeaderCell('1', flex: 1),
                        _buildHeaderCell('Total', flex: 2),
                      ],
                    ),
                  ),

                  // Table Body
                  Expanded(
                    child: _isLoading
                        ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF6B4C9A),
                      ),
                    )
                        : userDenominations.isEmpty
                        ? const Center(
                      child: Text(
                        'No denomination data available',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    )
                        : SingleChildScrollView(
                      child: Column(
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
                            child: Row(
                              children: [
                                _buildDataCell(
                                  user['user_name'] ?? '',
                                  flex: 2,
                                  bold: true,
                                ),
                                _buildDataCell(
                                  (user['denom_500'] ?? 0).toString(),
                                  flex: 1,
                                ),
                                _buildDataCell(
                                  (user['denom_200'] ?? 0).toString(),
                                  flex: 1,
                                ),
                                _buildDataCell(
                                  (user['denom_100'] ?? 0).toString(),
                                  flex: 1,
                                ),
                                _buildDataCell(
                                  (user['denom_50'] ?? 0).toString(),
                                  flex: 1,
                                ),
                                _buildDataCell(
                                  (user['denom_20'] ?? 0).toString(),
                                  flex: 1,
                                ),
                                _buildDataCell(
                                  (user['denom_10'] ?? 0).toString(),
                                  flex: 1,
                                ),
                                _buildDataCell(
                                  (user['denom_1'] ?? 0).toString(),
                                  flex: 1,
                                ),
                                _buildDataCell(
                                  _formatAmount(userTotal),
                                  flex: 2,
                                  bold: true,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  // Denomination Labels Row
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey[400]!, width: 2),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        _buildFooterCell('', flex: 2),
                        _buildFooterCell('500', flex: 1, color: Colors.red),
                        _buildFooterCell('200', flex: 1, color: Colors.red),
                        _buildFooterCell('100', flex: 1, color: Colors.red),
                        _buildFooterCell('50', flex: 1, color: Colors.red),
                        _buildFooterCell('20', flex: 1, color: Colors.red),
                        _buildFooterCell('10', flex: 1, color: Colors.red),
                        _buildFooterCell('1', flex: 1, color: Colors.red),
                        _buildFooterCell('', flex: 2),
                      ],
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
                    child: Row(
                      children: [
                        _buildFooterCell('Total Count', flex: 2, bold: true),
                        _buildFooterCell(
                          totals['counts'][500].toString(),
                          flex: 1,
                        ),
                        _buildFooterCell(
                          totals['counts'][200].toString(),
                          flex: 1,
                        ),
                        _buildFooterCell(
                          totals['counts'][100].toString(),
                          flex: 1,
                        ),
                        _buildFooterCell(
                          totals['counts'][50].toString(),
                          flex: 1,
                        ),
                        _buildFooterCell(
                          totals['counts'][20].toString(),
                          flex: 1,
                        ),
                        _buildFooterCell(
                          totals['counts'][10].toString(),
                          flex: 1,
                        ),
                        _buildFooterCell(
                          totals['counts'][1].toString(),
                          flex: 1,
                        ),
                        _buildFooterCell('', flex: 2),
                      ],
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
                    child: Row(
                      children: [
                        _buildFooterCell('Total Amount', flex: 2, bold: true),
                        _buildFooterCell(
                          _formatAmount(totals['amounts'][500]),
                          flex: 1,
                        ),
                        _buildFooterCell(
                          _formatAmount(totals['amounts'][200]),
                          flex: 1,
                        ),
                        _buildFooterCell(
                          _formatAmount(totals['amounts'][100]),
                          flex: 1,
                        ),
                        _buildFooterCell(
                          _formatAmount(totals['amounts'][50]),
                          flex: 1,
                        ),
                        _buildFooterCell(
                          _formatAmount(totals['amounts'][20]),
                          flex: 1,
                        ),
                        _buildFooterCell(
                          _formatAmount(totals['amounts'][10]),
                          flex: 1,
                        ),
                        _buildFooterCell(
                          _formatAmount(totals['amounts'][1]),
                          flex: 1,
                        ),
                        _buildFooterCell(
                          _formatAmount(totals['grandTotal']),
                          flex: 2,
                          bold: true,
                          color: Colors.blue,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // Print functionality
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Print functionality to be implemented'),
                        ),
                      );
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

  Widget _buildHeaderCell(String text, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
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
      ),
    );
  }

  Widget _buildDataCell(String text, {required int flex, bool bold = false}) {
    return Expanded(
      flex: flex,
      child: Container(
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
        ),
      ),
    );
  }

  Widget _buildFooterCell(
      String text, {
        required int flex,
        bool bold = false,
        Color? color,
      }) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: color ?? Colors.black,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}