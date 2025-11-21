import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';

class EventExpensesScreen extends StatefulWidget {
  const EventExpensesScreen({super.key});

  @override
  State<EventExpensesScreen> createState() => _EventExpensesScreenState();
}

class _EventExpensesScreenState extends State<EventExpensesScreen> {
  Map<String, String> _unsavedSalaries = {};
  final _auth = AuthService();
  final _formKey = GlobalKey<FormState>();

  Map<String, dynamic>? _event;
  List<Map<String, dynamic>> _operators = [];
  bool _loading = true;
  bool _saving = false;

  // Controller for balance live amount (only editable field)
  final _balanceLiveController = TextEditingController();

  // Controllers for event-level costs
  final _travelCostController = TextEditingController();
  final _teaCostController = TextEditingController();
  final _paperRollCostController = TextEditingController();
  final _miscCostController = TextEditingController();
  final _note1Controller = TextEditingController();
  final _note2Controller = TextEditingController();

  // Map to store operator-specific salary only
  Map<String, TextEditingController> _operatorSalaryControllers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        setState(() {
          _event = args;
        });
        _loadEventData();
      }
    });
  }

// ✅ ALSO UPDATE the dispose method to handle the controllers properly:

  @override
  void dispose() {
    _balanceLiveController.dispose();
    _travelCostController.dispose();
    _teaCostController.dispose();
    _paperRollCostController.dispose();
    _miscCostController.dispose();
    _note1Controller.dispose();
    _note2Controller.dispose();

    // Dispose operator salary controllers
    for (var controller in _operatorSalaryControllers.values) {
      controller.dispose();
    }
    _operatorSalaryControllers.clear();

    super.dispose();
  }

  // ✅ STEP 2: Replace the _loadEventData method with this:
  Future<void> _loadEventData() async {
    if (_event == null) return;

    setState(() => _loading = true);

    try {
      // Load event details with all costs
      final eventData = await _auth.client
          .from('events')
          .select()
          .eq('id', _event!['id'])
          .single();

      // Load assigned operators with their salaries
      final assignments = await _auth.client
          .from('event_assignments')
          .select('''
          *,
          users!inner(id, full_name, phone)
        ''')
          .eq('event_id', _event!['id']);

      setState(() {
        _event = eventData;
        _operators = List<Map<String, dynamic>>.from(assignments);

        // Initialize balance live controller only
        _balanceLiveController.text = _event!['balance_live_amount']?.toString() ?? '';

        // Initialize cost controllers
        _travelCostController.text = _event!['travel_cost']?.toString() ?? '';
        _teaCostController.text = _event!['tea_cost']?.toString() ?? '';
        _paperRollCostController.text = _event!['paper_roll_cost']?.toString() ?? '';
        _miscCostController.text = _event!['misc_cost']?.toString() ?? '';
        _note1Controller.text = _event!['note1_cost']?.toString() ?? '';
        _note2Controller.text = _event!['note2_cost']?.toString() ?? '';

        // ✅ Preserve current unsaved salary values before clearing controllers
        for (var entry in _operatorSalaryControllers.entries) {
          if (entry.value.text.isNotEmpty) {
            _unsavedSalaries[entry.key] = entry.value.text;
          }
        }

        // Dispose old controllers
        for (var controller in _operatorSalaryControllers.values) {
          controller.dispose();
        }
        _operatorSalaryControllers.clear();

        // Initialize operator salary controllers
        for (var operator in _operators) {
          final opId = operator['operator_id'];

          // Priority: 1. Unsaved value 2. Database value 3. Empty
          String salaryValue = '';
          if (_unsavedSalaries.containsKey(opId) && _unsavedSalaries[opId]!.isNotEmpty) {
            // Use unsaved value if exists
            salaryValue = _unsavedSalaries[opId]!;
          } else if (operator['salary'] != null) {
            // Use database value if exists
            salaryValue = operator['salary'].toString();
          }

          _operatorSalaryControllers[opId] = TextEditingController(text: salaryValue);
        }

        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ✅ STEP 3: Update _saveExpenses to clear unsaved data after successful save:
  Future<void> _saveExpenses() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      // Update each operator's salary
      for (var operator in _operators) {
        final opId = operator['operator_id'];
        final salaryController = _operatorSalaryControllers[opId]!;
        final salary = int.tryParse(salaryController.text) ?? 0;

        await _auth.client
            .from('event_assignments')
            .update({
          'salary': salary,
        })
            .eq('event_id', _event!['id'])
            .eq('operator_id', opId);
      }

      // Update event with balance_live_amount and costs
      await _auth.client
          .from('events')
          .update({
        'balance_live_amount': double.tryParse(_balanceLiveController.text) ?? 0,
        'travel_cost': int.tryParse(_travelCostController.text) ?? 0,
        'tea_cost': int.tryParse(_teaCostController.text) ?? 0,
        'paper_roll_cost': int.tryParse(_paperRollCostController.text) ?? 0,
        'misc_cost': int.tryParse(_miscCostController.text) ?? 0,
        'note1_cost': int.tryParse(_note1Controller.text) ?? 0,
        'note2_cost': int.tryParse(_note2Controller.text) ?? 0,
        'updated_at': DateTime.now().toIso8601String(),
        'net_profit': _calculateNetProfit().toInt(),
      })
          .eq('id', _event!['id']);

      // ✅ Clear unsaved salaries after successful save
      _unsavedSalaries.clear();

      setState(() => _saving = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expenses saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving expenses: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  double get _bookedAmount => _event?['booked_amount']?.toDouble() ?? 0;
  double get _advanceAmount => _event?['advance_amount']?.toDouble() ?? 0;
  double get _discountAmount => _event?['discount_amount']?.toDouble() ?? 0;
  double get _balanceLiveAmount => double.tryParse(_balanceLiveController.text) ?? 0;

  double get _balanceAmount {
    return _bookedAmount - _advanceAmount - _discountAmount - _balanceLiveAmount;
  }

  double _calculateNetProfit() {
    double totalTravel = double.tryParse(_travelCostController.text) ?? 0;
    double totalTea = double.tryParse(_teaCostController.text) ?? 0;
    double totalPaper = double.tryParse(_paperRollCostController.text) ?? 0;
    double miscCost = double.tryParse(_miscCostController.text) ?? 0;
    double note1 = double.tryParse(_note1Controller.text) ?? 0;
    double note2 = double.tryParse(_note2Controller.text) ?? 0;

    // Calculate total salary from all operators
    double totalSalary = 0;
    for (var controller in _operatorSalaryControllers.values) {
      totalSalary += double.tryParse(controller.text) ?? 0;
    }

    return _bookedAmount - (totalTravel + totalTea + totalPaper + totalSalary + miscCost + note1 + note2);
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 900;

    if (_event == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Title
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 2),
                    color: Colors.white,
                  ),
                  child: Text(
                    'Expense Management - ${_event!['customer_name']}',
                    style: const TextStyle(
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
                            const Icon(Icons.currency_rupee, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'EVENT EXPENSES & PROFIT',
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

                      // Content
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Amount Section
                            Text(
                              'Booking Details',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Booked Amount (Read-only)
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey[400]!),
                                      borderRadius: BorderRadius.circular(4),
                                      color: Colors.grey[100],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Booked Amount',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _bookedAmount.toStringAsFixed(2),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Advance Amount (Read-only)
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey[400]!),
                                      borderRadius: BorderRadius.circular(4),
                                      color: Colors.grey[100],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Advance Amount',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _advanceAmount.toStringAsFixed(2),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Discount Amount (Read-only)
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey[400]!),
                                      borderRadius: BorderRadius.circular(4),
                                      color: Colors.grey[100],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Discount Amount',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _discountAmount.toStringAsFixed(2),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Balance Live Amount (Editable - Prominent)
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: const Color(0xFFB846D7), width: 2),
                                      borderRadius: BorderRadius.circular(4),
                                      color: Colors.white,
                                    ),
                                    child: TextFormField(
                                      controller: _balanceLiveController,
                                      decoration: const InputDecoration(
                                        labelText: 'Balance Live Amount',
                                        labelStyle: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFB846D7),
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                                        hintText: '0.00',
                                        hintStyle: TextStyle(color: Colors.grey),
                                      ),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                                      ],
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Balance Amount (Read-only calculated field)
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey[400]!),
                                      borderRadius: BorderRadius.circular(4),
                                      color: Colors.grey[100],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Balance Amount',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _balanceAmount.toStringAsFixed(2),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 32),

                            // Event-level Costs
                            Text(
                              'Event Costs',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _travelCostController,
                                    decoration: const InputDecoration(
                                      labelText: 'Travel Cost',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      hintText: '0',
                                    ),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _teaCostController,
                                    decoration: const InputDecoration(
                                      labelText: 'Tea Cost',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      hintText: '0',
                                    ),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _paperRollCostController,
                                    decoration: const InputDecoration(
                                      labelText: 'Paper Roll Cost',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      hintText: '0',
                                    ),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _miscCostController,
                                    decoration: const InputDecoration(
                                      labelText: 'Miscellaneous Cost',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      hintText: '0',
                                    ),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _note1Controller,
                                    decoration: const InputDecoration(
                                      labelText: 'Notes 1',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      hintText: '0',
                                    ),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _note2Controller,
                                    decoration: const InputDecoration(
                                      labelText: 'Notes 2',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      hintText: '0',
                                    ),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 32),

                            // Operators Salary Table
                            Text(
                              'Operator Salaries',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 12),

                            _operators.isEmpty
                                ? Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange[300]!),
                              ),
                              child: const Center(
                                child: Text(
                                  'No operators assigned to this event',
                                  style: TextStyle(fontSize: 16, color: Colors.orange),
                                ),
                              ),
                            )
                                : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: MaterialStateProperty.all(Colors.purple[50]),
                                border: TableBorder.all(color: Colors.grey[300]!),
                                columnSpacing: 16,
                                columns: const [
                                  DataColumn(
                                    label: Text(
                                      'Operator Name',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Phone',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Salary',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                                rows: _operators.map((operator) {
                                  final opId = operator['operator_id'];
                                  final salaryController = _operatorSalaryControllers[opId]!;

                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        SizedBox(
                                          width: 150,
                                          child: Text(
                                            operator['users']['full_name'] ?? '',
                                            style: const TextStyle(fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        SizedBox(
                                          width: 120,
                                          child: Text(
                                            operator['users']['phone'] ?? '',
                                            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        SizedBox(
                                          width: 120,
                                          child: TextFormField(
                                            controller: salaryController,
                                            decoration: const InputDecoration(
                                              border: OutlineInputBorder(),
                                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                              isDense: true,
                                              hintText: '0',
                                            ),
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                            onChanged: (_) => setState(() {}),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),

                            const SizedBox(height: 32),

                            // Net Profit Display
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    _calculateNetProfit() >= 0 ? Colors.green[400]! : Colors.red[400]!,
                                    _calculateNetProfit() >= 0 ? Colors.green[600]! : Colors.red[600]!,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_calculateNetProfit() >= 0 ? Colors.green : Colors.red).withOpacity(0.3),
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
                                        _calculateNetProfit() >= 0 ? Icons.trending_up : Icons.trending_down,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'NET PROFIT',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    '₹ ${_calculateNetProfit().toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black26,
                                          offset: Offset(2, 2),
                                          blurRadius: 4,
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

                      // Footer with buttons
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
                                child: const Text('Cancel', style: TextStyle(fontSize: 16)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 120,
                              height: 45,
                              child: ElevatedButton(
                                onPressed: _saving ? null : _saveExpenses,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFB846D7),
                                  foregroundColor: Colors.white,
                                ),
                                child: _saving
                                    ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                    : const Text('Save', style: TextStyle(fontSize: 16)),
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
      ),
    );
  }
}