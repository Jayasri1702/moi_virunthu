import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/exchange_receipt_generator.dart'; // Add this import

class ExchangeDenominationScreen extends StatefulWidget {
  const ExchangeDenominationScreen({super.key});

  @override
  State<ExchangeDenominationScreen> createState() => _ExchangeDenominationScreenState();
}

class _ExchangeDenominationScreenState extends State<ExchangeDenominationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  // Received denomination controllers
  final _received500Controller = TextEditingController();
  final _received200Controller = TextEditingController();
  final _received100Controller = TextEditingController();
  final _received50Controller = TextEditingController();
  final _received20Controller = TextEditingController();
  final _received10Controller = TextEditingController();
  final _received5Controller = TextEditingController();
  final _received1Controller = TextEditingController();

  // Returned denomination controllers
  final _returned500Controller = TextEditingController();
  final _returned200Controller = TextEditingController();
  final _returned100Controller = TextEditingController();
  final _returned50Controller = TextEditingController();
  final _returned20Controller = TextEditingController();
  final _returned10Controller = TextEditingController();
  final _returned5Controller = TextEditingController();
  final _returned1Controller = TextEditingController();

  int _receivedTotalCount = 0;
  double _receivedTotalAmount = 0.0;
  int _returnedTotalCount = 0;
  double _returnedTotalAmount = 0.0;

  // Event data
  Map<String, dynamic>? eventData;

  // Available balances (TOTAL across all operators)
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
      final List<int> denominations = [500, 200, 100, 50, 20, 10, 5, 1];

      // Step 1: Get total collected denominations from MOI (CASH only)
      final moiData = await _supabase
          .from('moi_denominations')
          .select('''
            denom_500,
            denom_200,
            denom_100,
            denom_50,
            denom_20,
            denom_10,
            denom_5,
            denom_1,
            mois!moi_denominations_moi_id_fkey (
              payment_method
            )
          ''')
          .eq('event_id', eventId);

      // Step 2: Get total withdrawn denominations
      final withdrawalData = await _supabase
          .from('cash_withdrawals')
          .select('''
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
          .eq('event_id', eventId);

      // Step 3: Get exchange denominations (net values)
      final exchangeData = await _supabase
          .from('cash_exchanges')
          .select('''
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
          .eq('event_id', eventId);

      // Initialize totals
      Map<String, int> collected = {
        '500': 0, '200': 0, '100': 0, '50': 0,
        '20': 0, '10': 0, '5': 0, '1': 0,
      };

      Map<String, int> withdrawn = {
        '500': 0, '200': 0, '100': 0, '50': 0,
        '20': 0, '10': 0, '5': 0, '1': 0,
      };

      Map<String, int> exchanged = {
        '500': 0, '200': 0, '100': 0, '50': 0,
        '20': 0, '10': 0, '5': 0, '1': 0,
      };

      // Calculate collected (CASH only, from ALL operators)
      print('=== MOI Data Count: ${moiData.length} ===');
      for (var entry in moiData) {
        final paymentMethod = entry['mois']?['payment_method'];
        if (paymentMethod != 'CASH') continue; // Only count CASH payments

        for (var denom in denominations) {
          collected['$denom'] = (collected['$denom'] ?? 0) + ((entry['denom_$denom'] ?? 0) as int);
        }
      }
      print('Total Collected: $collected');

      // Calculate withdrawn (from ALL operators)
      print('=== Withdrawal Data Count: ${withdrawalData.length} ===');
      for (var withdrawal in withdrawalData) {
        final denomData = withdrawal['cash_withdrawal_denominations'];
        if (denomData == null) continue;

        for (var denom in denominations) {
          withdrawn['$denom'] = (withdrawn['$denom'] ?? 0) + ((denomData['denom_$denom'] ?? 0) as int);
        }
      }
      print('Total Withdrawn: $withdrawn');

      // Calculate exchanged (net from ALL operators)
      print('=== Exchange Data Count: ${exchangeData.length} ===');
      for (var exchange in exchangeData) {
        final denomData = exchange['cash_exchange_denominations'];
        if (denomData == null) continue;

        for (var denom in denominations) {
          exchanged['$denom'] = (exchanged['$denom'] ?? 0) + ((denomData['denom_$denom'] ?? 0) as int);
        }
      }
      print('Total Exchanged (Net): $exchanged');

      // Calculate available = collected - withdrawn + exchanged
      setState(() {
        _availableBalance = {
          '500': (collected['500'] ?? 0) - (withdrawn['500'] ?? 0) + (exchanged['500'] ?? 0),
          '200': (collected['200'] ?? 0) - (withdrawn['200'] ?? 0) + (exchanged['200'] ?? 0),
          '100': (collected['100'] ?? 0) - (withdrawn['100'] ?? 0) + (exchanged['100'] ?? 0),
          '50': (collected['50'] ?? 0) - (withdrawn['50'] ?? 0) + (exchanged['50'] ?? 0),
          '20': (collected['20'] ?? 0) - (withdrawn['20'] ?? 0) + (exchanged['20'] ?? 0),
          '10': (collected['10'] ?? 0) - (withdrawn['10'] ?? 0) + (exchanged['10'] ?? 0),
          '5': (collected['5'] ?? 0) - (withdrawn['5'] ?? 0) + (exchanged['5'] ?? 0),
          '1': (collected['1'] ?? 0) - (withdrawn['1'] ?? 0) + (exchanged['1'] ?? 0),
        };
        _isLoadingBalance = false;
      });

      print('=== FINAL AVAILABLE BALANCE (TOTAL) ===');
      print(_availableBalance);
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
    _received500Controller.dispose();
    _received200Controller.dispose();
    _received100Controller.dispose();
    _received50Controller.dispose();
    _received20Controller.dispose();
    _received10Controller.dispose();
    _received5Controller.dispose();
    _received1Controller.dispose();
    _returned500Controller.dispose();
    _returned200Controller.dispose();
    _returned100Controller.dispose();
    _returned50Controller.dispose();
    _returned20Controller.dispose();
    _returned10Controller.dispose();
    _returned5Controller.dispose();
    _returned1Controller.dispose();
    super.dispose();
  }

  void _calculateReceivedDenomination() {
    int count500 = int.tryParse(_received500Controller.text) ?? 0;
    int count200 = int.tryParse(_received200Controller.text) ?? 0;
    int count100 = int.tryParse(_received100Controller.text) ?? 0;
    int count50 = int.tryParse(_received50Controller.text) ?? 0;
    int count20 = int.tryParse(_received20Controller.text) ?? 0;
    int count10 = int.tryParse(_received10Controller.text) ?? 0;
    int count5 = int.tryParse(_received5Controller.text) ?? 0;
    int count1 = int.tryParse(_received1Controller.text) ?? 0;

    setState(() {
      _receivedTotalCount = count500 + count200 + count100 + count50 + count20 + count10 + count5 + count1;
      _receivedTotalAmount = (count500 * 500) +
          (count200 * 200) +
          (count100 * 100) +
          (count50 * 50) +
          (count20 * 20) +
          (count10 * 10) +
          (count5 * 5) +
          (count1 * 1);
    });
  }

  void _calculateReturnedDenomination() {
    int count500 = int.tryParse(_returned500Controller.text) ?? 0;
    int count200 = int.tryParse(_returned200Controller.text) ?? 0;
    int count100 = int.tryParse(_returned100Controller.text) ?? 0;
    int count50 = int.tryParse(_returned50Controller.text) ?? 0;
    int count20 = int.tryParse(_returned20Controller.text) ?? 0;
    int count10 = int.tryParse(_returned10Controller.text) ?? 0;
    int count5 = int.tryParse(_returned5Controller.text) ?? 0;
    int count1 = int.tryParse(_returned1Controller.text) ?? 0;

    setState(() {
      _returnedTotalCount = count500 + count200 + count100 + count50 + count20 + count10 + count5 + count1;
      _returnedTotalAmount = (count500 * 500) +
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
      _received500Controller.clear();
      _received200Controller.clear();
      _received100Controller.clear();
      _received50Controller.clear();
      _received20Controller.clear();
      _received10Controller.clear();
      _received5Controller.clear();
      _received1Controller.clear();
      _returned500Controller.clear();
      _returned200Controller.clear();
      _returned100Controller.clear();
      _returned50Controller.clear();
      _returned20Controller.clear();
      _returned10Controller.clear();
      _returned5Controller.clear();
      _returned1Controller.clear();
      _receivedTotalCount = 0;
      _receivedTotalAmount = 0.0;
      _returnedTotalCount = 0;
      _returnedTotalAmount = 0.0;
    });
  }

  bool _validateReturnedDenominations() {
    List<String> errors = [];

    Map<String, int> returned = {
      '500': int.tryParse(_returned500Controller.text) ?? 0,
      '200': int.tryParse(_returned200Controller.text) ?? 0,
      '100': int.tryParse(_returned100Controller.text) ?? 0,
      '50': int.tryParse(_returned50Controller.text) ?? 0,
      '20': int.tryParse(_returned20Controller.text) ?? 0,
      '10': int.tryParse(_returned10Controller.text) ?? 0,
      '5': int.tryParse(_returned5Controller.text) ?? 0,
      '1': int.tryParse(_returned1Controller.text) ?? 0,
    };

    returned.forEach((denom, returnedCount) {
      if (returnedCount > 0) {
        int available = _availableBalance[denom] ?? 0;
        if (returnedCount > available) {
          errors.add('₹$denom: Trying to return $returnedCount but only $available available (total for event)');
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
                'The following denominations cannot be returned (insufficient balance):',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '(Based on total collected by all operators)',
                style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
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

  Future<void> _saveExchange() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    if (_receivedTotalAmount <= 0 || _returnedTotalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both received and returned denomination details')),
      );
      return;
    }

    if (_receivedTotalAmount != _returnedTotalAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Received and Returned amounts must be equal!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate returned denominations against available balance
    if (!_validateReturnedDenominations()) {
      return;
    }

    try {
      final eventId = eventData?['id'];
      final operatorId = eventData?['operator_id'];

      // Fetch operator name from users table
      String operatorName = 'Operator';
      try {
        final userResponse = await _supabase
            .from('users')
            .select('full_name')
            .eq('id', operatorId)
            .single();

        if (userResponse != null && userResponse['full_name'] != null) {
          operatorName = userResponse['full_name'];
        }
      } catch (e) {
        print('Error fetching operator name: $e');
      }

      if (eventId == null || operatorId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event or Operator ID not found')),
        );
        return;
      }

      // Prepare denomination maps
      Map<int, int> receivedDenominations = {
        500: int.tryParse(_received500Controller.text) ?? 0,
        200: int.tryParse(_received200Controller.text) ?? 0,
        100: int.tryParse(_received100Controller.text) ?? 0,
        50: int.tryParse(_received50Controller.text) ?? 0,
        20: int.tryParse(_received20Controller.text) ?? 0,
        10: int.tryParse(_received10Controller.text) ?? 0,
        5: int.tryParse(_received5Controller.text) ?? 0,
        1: int.tryParse(_received1Controller.text) ?? 0,
      };

      Map<int, int> returnedDenominations = {
        500: int.tryParse(_returned500Controller.text) ?? 0,
        200: int.tryParse(_returned200Controller.text) ?? 0,
        100: int.tryParse(_returned100Controller.text) ?? 0,
        50: int.tryParse(_returned50Controller.text) ?? 0,
        20: int.tryParse(_returned20Controller.text) ?? 0,
        10: int.tryParse(_returned10Controller.text) ?? 0,
        5: int.tryParse(_returned5Controller.text) ?? 0,
        1: int.tryParse(_returned1Controller.text) ?? 0,
      };

      // Insert exchange record
      final response = await _supabase.from('cash_exchanges').insert({
        'event_id': eventId,
        'operator_id': operatorId,
        'amount': _receivedTotalAmount,
      }).select();

      if (response.isEmpty) {
        throw Exception('Failed to save exchange');
      }

      final exchangeId = response[0]['id'];

      // Calculate net denominations (received - returned)
      int net500 = receivedDenominations[500]! - returnedDenominations[500]!;
      int net200 = receivedDenominations[200]! - returnedDenominations[200]!;
      int net100 = receivedDenominations[100]! - returnedDenominations[100]!;
      int net50 = receivedDenominations[50]! - returnedDenominations[50]!;
      int net20 = receivedDenominations[20]! - returnedDenominations[20]!;
      int net10 = receivedDenominations[10]! - returnedDenominations[10]!;
      int net5 = receivedDenominations[5]! - returnedDenominations[5]!;
      int net1 = receivedDenominations[1]! - returnedDenominations[1]!;

      // Save net denomination breakdown in single table
      await _supabase.from('cash_exchange_denominations').insert({
        'exchange_id': exchangeId,
        'denom_500': net500,
        'denom_200': net200,
        'denom_100': net100,
        'denom_50': net50,
        'denom_20': net20,
        'denom_10': net10,
        'denom_5': net5,
        'denom_1': net1,
      });

      // Generate exchange receipt with proper operator name
      final receiptFile = await ExchangeReceiptGenerator.generateExchangeReceipt(
        context: context,
        operatorName: operatorName,
        exchangeDate: DateTime.now(),
        exchangeTime: TimeOfDay.now(),
        receivedDenominations: receivedDenominations,
        returnedDenominations: returnedDenominations,
      );

      if (receiptFile != null) {
        print('Exchange receipt generated: ${receiptFile.path}');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exchange of ₹${_receivedTotalAmount.toStringAsFixed(0)} saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _clearAllFields();
      // Reload balance after successful exchange
      await _loadAvailableBalance();
    } catch (e) {
      print('Error saving exchange: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving exchange: $e'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
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
          'Exchange Denomination',
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
                    color: Colors.blue,
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: const Center(
                    child: Text(
                      'Exchange Denomination Receipt',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Received Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.blue, width: 3),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        color: Colors.blue,
                        child: const Center(
                          child: Text(
                            'Received',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDenomRow('500', _received500Controller, isReceived: true),
                      const SizedBox(height: 8),
                      _buildDenomRow('200', _received200Controller, isReceived: true),
                      const SizedBox(height: 8),
                      _buildDenomRow('100', _received100Controller, isReceived: true),
                      const SizedBox(height: 8),
                      _buildDenomRow('50', _received50Controller, isReceived: true),
                      const SizedBox(height: 8),
                      _buildDenomRow('20', _received20Controller, isReceived: true),
                      const SizedBox(height: 8),
                      _buildDenomRow('10', _received10Controller, isReceived: true),
                      const SizedBox(height: 8),
                      _buildDenomRow('5', _received5Controller, isReceived: true),
                      const SizedBox(height: 8),
                      _buildDenomRow('1', _received1Controller, isReceived: true),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          border: Border.all(color: Colors.blue, width: 2),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total Count: $_receivedTotalCount',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Received:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.blue,
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    '₹${_receivedTotalAmount.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Colors.blue,
                                    ),
                                    overflow: TextOverflow.ellipsis,
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

                const SizedBox(height: 24),

                // Returned Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.green, width: 3),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        color: Colors.green,
                        child: const Center(
                          child: Text(
                            'Returned',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          'Total available across all operators for this event',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildDenomRow('500', _returned500Controller, isReceived: false),
                      const SizedBox(height: 8),
                      _buildDenomRow('200', _returned200Controller, isReceived: false),
                      const SizedBox(height: 8),
                      _buildDenomRow('100', _returned100Controller, isReceived: false),
                      const SizedBox(height: 8),
                      _buildDenomRow('50', _returned50Controller, isReceived: false),
                      const SizedBox(height: 8),
                      _buildDenomRow('20', _returned20Controller, isReceived: false),
                      const SizedBox(height: 8),
                      _buildDenomRow('10', _returned10Controller, isReceived: false),
                      const SizedBox(height: 8),
                      _buildDenomRow('5', _returned5Controller, isReceived: false),
                      const SizedBox(height: 8),
                      _buildDenomRow('1', _returned1Controller, isReceived: false),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          border: Border.all(color: Colors.green, width: 2),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total Count: $_returnedTotalCount',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Returned:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.green,
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    '₹${_returnedTotalAmount.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Colors.green,
                                    ),
                                    overflow: TextOverflow.ellipsis,
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

                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _saveExchange,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                              side: const BorderSide(color: Colors.black, width: 2),
                            ),
                          ),
                          child: const Text(
                            'Save Exchange',
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

  Widget _buildDenomRow(String denomination, TextEditingController controller, {required bool isReceived}) {
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
                  onChanged: (value) {
                    if (isReceived) {
                      _calculateReceivedDenomination();
                    } else {
                      _calculateReturnedDenomination();
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '=',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              width: 100,
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
          ],
        ),
        // Available balance indicator (only for returned section)
        if (!isReceived)
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 90),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Available (Total): $available',
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