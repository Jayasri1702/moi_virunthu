import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CashWithdrawalScreen extends StatefulWidget {
  const CashWithdrawalScreen({super.key});

  @override
  State<CashWithdrawalScreen> createState() => _CashWithdrawalScreenState();
}

class _CashWithdrawalScreenState extends State<CashWithdrawalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  // Controllers
  final _requestedByController = TextEditingController();
  final _phoneController = TextEditingController();
  final _reasonController = TextEditingController();

  // Denomination controllers
  final _denom500Controller = TextEditingController();
  final _denom200Controller = TextEditingController();
  final _denom100Controller = TextEditingController();
  final _denom50Controller = TextEditingController();
  final _denom20Controller = TextEditingController();
  final _denom10Controller = TextEditingController();
  final _denom5Controller = TextEditingController();
  final _denom1Controller = TextEditingController();

  int _totalCount = 0;
  double _totalAmount = 0.0;

  // Event data
  Map<String, dynamic>? eventData;

  // Available balances
  Map<String, int> _availableBalance = {};
  bool _isLoadingBalance = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map<String, dynamic>) {
      setState(() {
        eventData = args;
      });
      print('Event data received: ${eventData?['id']}');
      print('Operator ID received: ${eventData?['operator_id']}');
      _loadAvailableBalance();
    }
  }

  Future<void> _loadAvailableBalance() async {
    if (eventData?['id'] == null) return;

    setState(() {
      _isLoadingBalance = true;
    });

    try {
      final eventId = eventData!['id'];

      // Get total collected denominations
      final collectedResponse = await _supabase
          .from('moi_denominations')
          .select('denom_500, denom_200, denom_100, denom_50, denom_20, denom_10, denom_5, denom_1')
          .eq('event_id', eventId);

      // Get total withdrawn denominations
      final withdrawnResponse = await _supabase
          .from('cash_withdrawal_denominations')
          .select('denom_500, denom_200, denom_100, denom_50, denom_20, denom_10, denom_5, denom_1, withdrawal:cash_withdrawals!inner(event_id)')
          .eq('withdrawal.event_id', eventId);

      // Calculate totals
      Map<String, int> collected = {
        '500': 0,
        '200': 0,
        '100': 0,
        '50': 0,
        '20': 0,
        '10': 0,
        '5': 0,
        '1': 0,
      };

      Map<String, int> withdrawn = {
        '500': 0,
        '200': 0,
        '100': 0,
        '50': 0,
        '20': 0,
        '10': 0,
        '5': 0,
        '1': 0,
      };

      // Sum up collected
      for (var record in collectedResponse) {
        collected['500'] = (collected['500'] ?? 0) + ((record['denom_500'] ?? 0) as int);
        collected['200'] = (collected['200'] ?? 0) + ((record['denom_200'] ?? 0) as int);
        collected['100'] = (collected['100'] ?? 0) + ((record['denom_100'] ?? 0) as int);
        collected['50'] = (collected['50'] ?? 0) + ((record['denom_50'] ?? 0) as int);
        collected['20'] = (collected['20'] ?? 0) + ((record['denom_20'] ?? 0) as int);
        collected['10'] = (collected['10'] ?? 0) + ((record['denom_10'] ?? 0) as int);
        collected['5'] = (collected['5'] ?? 0) + ((record['denom_5'] ?? 0) as int);
        collected['1'] = (collected['1'] ?? 0) + ((record['denom_1'] ?? 0) as int);
      }

      // Sum up withdrawn
      for (var record in withdrawnResponse) {
        withdrawn['500'] = (withdrawn['500'] ?? 0) + ((record['denom_500'] ?? 0) as int);
        withdrawn['200'] = (withdrawn['200'] ?? 0) + ((record['denom_200'] ?? 0) as int);
        withdrawn['100'] = (withdrawn['100'] ?? 0) + ((record['denom_100'] ?? 0) as int);
        withdrawn['50'] = (withdrawn['50'] ?? 0) + ((record['denom_50'] ?? 0) as int);
        withdrawn['20'] = (withdrawn['20'] ?? 0) + ((record['denom_20'] ?? 0) as int);
        withdrawn['10'] = (withdrawn['10'] ?? 0) + ((record['denom_10'] ?? 0) as int);
        withdrawn['5'] = (withdrawn['5'] ?? 0) + ((record['denom_5'] ?? 0) as int);
        withdrawn['1'] = (withdrawn['1'] ?? 0) + ((record['denom_1'] ?? 0) as int);
      }

      // Calculate available = collected - withdrawn
      setState(() {
        _availableBalance = {
          '500': (collected['500'] ?? 0) - (withdrawn['500'] ?? 0),
          '200': (collected['200'] ?? 0) - (withdrawn['200'] ?? 0),
          '100': (collected['100'] ?? 0) - (withdrawn['100'] ?? 0),
          '50': (collected['50'] ?? 0) - (withdrawn['50'] ?? 0),
          '20': (collected['20'] ?? 0) - (withdrawn['20'] ?? 0),
          '10': (collected['10'] ?? 0) - (withdrawn['10'] ?? 0),
          '5': (collected['5'] ?? 0) - (withdrawn['5'] ?? 0),
          '1': (collected['1'] ?? 0) - (withdrawn['1'] ?? 0),
        };
        _isLoadingBalance = false;
      });
    } catch (e) {
      print('Error loading balance: $e');
      setState(() {
        _isLoadingBalance = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading denomination balance: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _requestedByController.dispose();
    _phoneController.dispose();
    _reasonController.dispose();
    _denom500Controller.dispose();
    _denom200Controller.dispose();
    _denom100Controller.dispose();
    _denom50Controller.dispose();
    _denom20Controller.dispose();
    _denom10Controller.dispose();
    _denom5Controller.dispose();
    _denom1Controller.dispose();
    super.dispose();
  }

  void _calculateDenomination() {
    int count500 = int.tryParse(_denom500Controller.text) ?? 0;
    int count200 = int.tryParse(_denom200Controller.text) ?? 0;
    int count100 = int.tryParse(_denom100Controller.text) ?? 0;
    int count50 = int.tryParse(_denom50Controller.text) ?? 0;
    int count20 = int.tryParse(_denom20Controller.text) ?? 0;
    int count10 = int.tryParse(_denom10Controller.text) ?? 0;
    int count5 = int.tryParse(_denom5Controller.text) ?? 0;
    int count1 = int.tryParse(_denom1Controller.text) ?? 0;

    setState(() {
      _totalCount = count500 + count200 + count100 + count50 + count20 + count10 + count5 + count1;
      _totalAmount = (count500 * 500) +
          (count200 * 200) +
          (count100 * 100) +
          (count50 * 50) +
          (count20 * 20) +
          (count10 * 10) +
          (count5 * 5) +
          (count1 * 1);
    });
  }

  void _clearAllFields() {
    setState(() {
      _requestedByController.clear();
      _phoneController.clear();
      _reasonController.clear();
      _denom500Controller.clear();
      _denom200Controller.clear();
      _denom100Controller.clear();
      _denom50Controller.clear();
      _denom20Controller.clear();
      _denom10Controller.clear();
      _denom5Controller.clear();
      _denom1Controller.clear();
      _totalCount = 0;
      _totalAmount = 0.0;
    });
  }

  bool _validateDenominations() {
    List<String> errors = [];

    Map<String, int> requested = {
      '500': int.tryParse(_denom500Controller.text) ?? 0,
      '200': int.tryParse(_denom200Controller.text) ?? 0,
      '100': int.tryParse(_denom100Controller.text) ?? 0,
      '50': int.tryParse(_denom50Controller.text) ?? 0,
      '20': int.tryParse(_denom20Controller.text) ?? 0,
      '10': int.tryParse(_denom10Controller.text) ?? 0,
      '5': int.tryParse(_denom5Controller.text) ?? 0,
      '1': int.tryParse(_denom1Controller.text) ?? 0,
    };

    requested.forEach((denom, requestedCount) {
      if (requestedCount > 0) {
        int available = _availableBalance[denom] ?? 0;
        if (requestedCount > available) {
          errors.add('₹$denom: Requested $requestedCount but only $available available');
        }
      }
    });

    if (errors.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            'Insufficient Denomination',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The following denominations are not available:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...errors.map((error) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return false;
    }

    return true;
  }

  Future<void> _saveWithdrawal() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    if (_totalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter denomination details. Amount cannot be zero.')),
      );
      return;
    }

    if (_requestedByController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter who requested the withdrawal')),
      );
      return;
    }

    // Validate denominations
    if (!_validateDenominations()) {
      return;
    }

    try {
      final eventId = eventData?['id'];
      final operatorId = eventData?['operator_id'];

      if (eventId == null || operatorId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event or Operator ID not found')),
        );
        return;
      }

      // Insert withdrawal record with calculated amount
      final response = await _supabase.from('cash_withdrawals').insert({
        'event_id': eventId,
        'operator_id': operatorId,
        'requested_by': _requestedByController.text.trim(),
        'requester_phone_number': _phoneController.text.trim(),
        'amount': _totalAmount,
        'reason': _reasonController.text.trim(),
      }).select();

      if (response.isEmpty) {
        throw Exception('Failed to save withdrawal');
      }

      final withdrawalId = response[0]['id'];

      // Save denomination breakdown
      await _supabase.from('cash_withdrawal_denominations').insert({
        'withdrawal_id': withdrawalId,
        'denom_500': int.tryParse(_denom500Controller.text) ?? 0,
        'denom_200': int.tryParse(_denom200Controller.text) ?? 0,
        'denom_100': int.tryParse(_denom100Controller.text) ?? 0,
        'denom_50': int.tryParse(_denom50Controller.text) ?? 0,
        'denom_20': int.tryParse(_denom20Controller.text) ?? 0,
        'denom_10': int.tryParse(_denom10Controller.text) ?? 0,
        'denom_5': int.tryParse(_denom5Controller.text) ?? 0,
        'denom_1': int.tryParse(_denom1Controller.text) ?? 0,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Withdrawal of ₹${_totalAmount.toStringAsFixed(0)} saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      _clearAllFields();
      // Reload balance after successful withdrawal
      await _loadAvailableBalance();
    } catch (e) {
      print('Error saving withdrawal: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving withdrawal: $e'),
          duration: const Duration(seconds: 4),
        ),
      );
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
          'Cash Withdrawal',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_isLoadingBalance)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: const Center(
                    child: Text(
                      'CASH WITHDRAWAL FORM',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Requested By
                _buildInputField('Requested By', _requestedByController, required: true),

                const SizedBox(height: 16),

                // Phone Number
                _buildInputField('Phone Number', _phoneController, keyboardType: TextInputType.phone),

                const SizedBox(height: 16),

                // Denomination Table
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Withdrawal Amount (Enter Denomination)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDenomRow('500', _denom500Controller),
                      const SizedBox(height: 8),
                      _buildDenomRow('200', _denom200Controller),
                      const SizedBox(height: 8),
                      _buildDenomRow('100', _denom100Controller),
                      const SizedBox(height: 8),
                      _buildDenomRow('50', _denom50Controller),
                      const SizedBox(height: 8),
                      _buildDenomRow('20', _denom20Controller),
                      const SizedBox(height: 8),
                      _buildDenomRow('10', _denom10Controller),
                      const SizedBox(height: 8),
                      _buildDenomRow('5', _denom5Controller),
                      const SizedBox(height: 8),
                      _buildDenomRow('1', _denom1Controller),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Count: $_totalCount',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Total Withdrawal Amount: ₹${_totalAmount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Reason
                Container(
                  height: 120,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reason for Withdrawal',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _reasonController,
                          maxLines: null,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Enter reason...',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _saveWithdrawal,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                              side: const BorderSide(color: Colors.black, width: 2),
                            ),
                          ),
                          child: const Text(
                            'Save Withdrawal',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _clearAllFields,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                              side: const BorderSide(color: Colors.black, width: 2),
                            ),
                          ),
                          child: const Text(
                            'Clear',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller,
      {TextInputType? keyboardType, bool required = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (required)
                const Text(
                  ' *',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: const InputDecoration(
              border: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDenomRow(String denomination, TextEditingController controller) {
    int available = _availableBalance[denomination] ?? 0;

    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 80,
              height: 40,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 2),
                color: Colors.grey[300],
              ),
              child: Center(
                child: Text(
                  '₹ $denomination',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'x',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: '0',
                  ),
                  onChanged: (value) => _calculateDenomination(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '=',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 2),
                  color: Colors.grey[200],
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        ((int.tryParse(controller.text) ?? 0) * int.parse(denomination))
                            .toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        // Available balance indicator
        Padding(
          padding: const EdgeInsets.only(top: 2, left: 90),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Available: $available',
              style: TextStyle(
                fontSize: 11,
                color: available > 0 ? Colors.green[700] : Colors.red[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}