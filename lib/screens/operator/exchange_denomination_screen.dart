import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

    try {
      final eventId = eventData?['id'];
      final operatorId = eventData?['operator_id'];

      if (eventId == null || operatorId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event or Operator ID not found')),
        );
        return;
      }

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
      // Positive values = received, Negative values = returned
      int net500 = (int.tryParse(_received500Controller.text) ?? 0) -
          (int.tryParse(_returned500Controller.text) ?? 0);
      int net200 = (int.tryParse(_received200Controller.text) ?? 0) -
          (int.tryParse(_returned200Controller.text) ?? 0);
      int net100 = (int.tryParse(_received100Controller.text) ?? 0) -
          (int.tryParse(_returned100Controller.text) ?? 0);
      int net50 = (int.tryParse(_received50Controller.text) ?? 0) -
          (int.tryParse(_returned50Controller.text) ?? 0);
      int net20 = (int.tryParse(_received20Controller.text) ?? 0) -
          (int.tryParse(_returned20Controller.text) ?? 0);
      int net10 = (int.tryParse(_received10Controller.text) ?? 0) -
          (int.tryParse(_returned10Controller.text) ?? 0);
      int net5 = (int.tryParse(_received5Controller.text) ?? 0) -
          (int.tryParse(_returned5Controller.text) ?? 0);
      int net1 = (int.tryParse(_received1Controller.text) ?? 0) -
          (int.tryParse(_returned1Controller.text) ?? 0);

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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exchange of ₹${_receivedTotalAmount.toStringAsFixed(0)} saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      _clearAllFields();
    } catch (e) {
      print('Error saving exchange: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving exchange: $e'),
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
          'Exchange Denomination',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
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
                      const SizedBox(height: 16),
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
    return Row(
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
    );
  }
}