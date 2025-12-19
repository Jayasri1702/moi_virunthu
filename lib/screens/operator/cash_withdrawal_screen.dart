import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/withdrawal_receipt_generator.dart';
import '../../utils/network_utils.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../services/thermal_printer_service.dart';

class CashWithdrawalScreen extends StatefulWidget {
  const CashWithdrawalScreen({super.key});

  @override
  State<CashWithdrawalScreen> createState() => _CashWithdrawalScreenState();
}

class _CashWithdrawalScreenState extends State<CashWithdrawalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  // Event details for receipt footer
  String? _customerName;
  String? _city;
  String? _customerPhone;
  String? _eventTitle;
  String? _eventFor;
  String? _eventTypeName;
  String? _venue;

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

  // Available balances (TOTAL across all operators)
  Map<String, int> _availableBalance = {};
  bool _isLoadingBalance = false;
  bool _isSaving = false;

  // Track if withdrawal was just saved
  bool _withdrawalSaved = false;
  Map<int, int>? _lastSavedDenominations;

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
      _loadEventDetails();  // ✅ ADD THIS LINE
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

      // Step 3: Get exchange denominations
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
      for (var entry in moiData) {
        final paymentMethod = entry['mois']?['payment_method'];
        if (paymentMethod != 'CASH') continue;

        for (var denom in denominations) {
          collected['$denom'] = (collected['$denom'] ?? 0) +
              ((entry['denom_$denom'] ?? 0) as int);
        }
      }

      // Calculate withdrawn (from ALL operators)
      for (var withdrawal in withdrawalData) {
        final denomData = withdrawal['cash_withdrawal_denominations'];
        if (denomData == null) continue;

        for (var denom in denominations) {
          withdrawn['$denom'] = (withdrawn['$denom'] ?? 0) +
              ((denomData['denom_$denom'] ?? 0) as int);
        }
      }

      // Calculate exchanged (from ALL operators)
      for (var exchange in exchangeData) {
        final denomData = exchange['cash_exchange_denominations'];
        if (denomData == null) continue;

        for (var denom in denominations) {
          exchanged['$denom'] = (exchanged['$denom'] ?? 0) +
              ((denomData['denom_$denom'] ?? 0) as int);
        }
      }

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
    } catch (e) {
      print('Error loading balance: $e');
      setState(() {
        _isLoadingBalance = false;
      });
      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          onRetry: _loadAvailableBalance,
          customMessage: 'Error loading denomination balance',
        );
      }
    }
  }

  Future<void> _loadEventDetails() async {
    if (eventData?['id'] == null) return;

    try {
      final eventId = eventData!['id'];

      final response = await _supabase
          .from('events')
          .select('customer_name, city, customer_phone, title, venue, event_for, event_types(name)')
          .eq('id', eventId)
          .single();

      setState(() {
        _customerName = response['customer_name'];
        _city = response['city'];
        _customerPhone = response['customer_phone'];
        _eventTitle = response['title'];
        _venue = response['venue'];
        _eventFor = response['event_for'];
        _eventTypeName = response['event_types']?['name'];
      });

      print('✅ Event details loaded for withdrawal receipt');
    } catch (e) {
      print('Error loading event details: $e');
      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          onRetry: _loadEventDetails,
          customMessage: 'Error loading event details',
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

      // Reset withdrawal saved state when amounts change
      _withdrawalSaved = false;
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
      _withdrawalSaved = false;
      _lastSavedDenominations = null;
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
          errors.add(
              '₹$denom: Requested $requestedCount but only $available available (total for event)');
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

  // Check for duplicate withdrawal
  Future<bool> _checkDuplicateWithdrawal() async {
    try {
      final eventId = eventData?['id'];
      final requestedBy = _requestedByController.text.trim();
      final phone = _phoneController.text.trim();
      final amount = _totalAmount;

      // Check if a withdrawal with same requested_by, phone, and amount exists
      final existing = await _supabase
          .from('cash_withdrawals')
          .select('id')
          .eq('event_id', eventId)
          .eq('requested_by', requestedBy)
          .eq('requester_phone_number', phone)
          .eq('amount', amount);

      if (existing.isNotEmpty) {
        // Show dialog with PROCEED and DISCARD options
        final shouldProceed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text(
              'Duplicate Withdrawal Detected',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'A withdrawal with the same details already exists:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text('• Requested By: $requestedBy'),
                Text('• Phone: $phone'),
                Text('• Amount: ₹${amount.toStringAsFixed(0)}'),
                const SizedBox(height: 12),
                const Text(
                  'Do you want to proceed anyway?',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.red[100],
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: const Text(
                  'DISCARD',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.green[100],
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: const Text(
                  'PROCEED',
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );

        // If user chose DISCARD or closed dialog
        if (shouldProceed != true) {
          return true; // Return true to indicate duplicate (stops save)
        }

        // User chose PROCEED - allow save
        return false;
      }

      return false; // No duplicate
    } catch (e) {
      print('Error checking duplicate: $e');
      return false;
    }
  }

  Future<void> _saveWithdrawal() async {
    // Prevent multiple clicks
    if (_isSaving) return;

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

    // Set loading state
    setState(() {
      _isSaving = true;
    });

    try {
      // Check for duplicate withdrawal
      bool isDuplicate = await _checkDuplicateWithdrawal();
      if (isDuplicate) {
        return; // Stop if duplicate found
      }

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

      // Prepare denominations map
      Map<int, int> denominations = {
        500: int.tryParse(_denom500Controller.text) ?? 0,
        200: int.tryParse(_denom200Controller.text) ?? 0,
        100: int.tryParse(_denom100Controller.text) ?? 0,
        50: int.tryParse(_denom50Controller.text) ?? 0,
        20: int.tryParse(_denom20Controller.text) ?? 0,
        10: int.tryParse(_denom10Controller.text) ?? 0,
        5: int.tryParse(_denom5Controller.text) ?? 0,
        1: int.tryParse(_denom1Controller.text) ?? 0,
      };

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
        'denom_500': denominations[500],
        'denom_200': denominations[200],
        'denom_100': denominations[100],
        'denom_50': denominations[50],
        'denom_20': denominations[20],
        'denom_10': denominations[10],
        'denom_5': denominations[5],
        'denom_1': denominations[1],
      });

      // ✅ Generate withdrawal receipt WITH IMAGE (for thermal printer)
      final result = await WithdrawalReceiptGenerator.generateWithdrawalReceiptWithImage(
        context: context,
        operatorName: operatorName,
        withdrawalDate: DateTime.now(),
        withdrawalTime: TimeOfDay.now(),
        requestedBy: _requestedByController.text.trim(),
        amount: _totalAmount,
        denominations: denominations,
        reason: _reasonController.text.trim().isNotEmpty ? _reasonController.text.trim() : null,
        eventTitle: _eventTitle,
        eventFor: _eventFor,
        eventTypeName: _eventTypeName,
        venue: _venue,
        customerName: _customerName,
        city: _city,
        customerPhone: _customerPhone,
      );

      if (result != null) {
        print('Withdrawal receipt generated: ${result['pdf'].path}');

        // ✅ Print using thermal printer
        final printerService = ThermalPrinterService();
        await printerService.connectAndPrintImage(context, result['imageBytes']);

        // ✅ Check skip_whatsapp setting and submit to backend
        try {
          final eventData = await _supabase
              .from('events')
              .select('skip_whatsapp')
              .eq('id', eventId)
              .single();

          final skipWhatsapp = eventData['skip_whatsapp'] ?? false;
          final toWhatsapp = !skipWhatsapp;

          print('📱 skip_whatsapp from DB: $skipWhatsapp');
          print('📱 to_whatsapp being sent: $toWhatsapp');

          // Submit receipt to backend
          await _submitReceiptToBackend(
            pdfFile: result['pdf'],
            eventId: eventId.toString(),
            phoneNumber: _phoneController.text.trim(),
            toWhatsapp: toWhatsapp,
            receiptNo: withdrawalId,
          );

          print('✅ Receipt submitted to backend successfully');
        } catch (e) {
          print('❌ Error checking WhatsApp setting or submitting receipt: $e');
        }
      }

      // Mark withdrawal as saved and store denominations
      setState(() {
        _withdrawalSaved = true;
        _lastSavedDenominations = Map<int, int>.from(denominations);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Withdrawal of ₹${_totalAmount.toStringAsFixed(0)} saved successfully! Receipt printed.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Reload balance after successful withdrawal
      await _loadAvailableBalance();
    } catch (e) {
      print('Error saving withdrawal: $e');
      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          onRetry: _saveWithdrawal,
          customMessage: 'Error saving withdrawal',
        );
      }
    } finally {
      // Always remove loading state
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _sendReceiptToWhatsApp() async {
    if (!_withdrawalSaved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please save the withdrawal first before sending receipt'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter phone number to send receipt')),
      );
      return;
    }

    try {
      final operatorName = eventData?['operator_name'] ?? 'Unknown';

      // Use the saved denominations
      if (_lastSavedDenominations == null) {
        throw Exception('No saved withdrawal data found');
      }

      // Send receipt to WhatsApp
      await WithdrawalReceiptGenerator.sendToWhatsApp(
        context: context,
        phoneNumber: _phoneController.text.trim(),
        operatorName: operatorName,
        withdrawalDate: DateTime.now(),
        withdrawalTime: TimeOfDay.now(),
        requestedBy: _requestedByController.text.trim(),
        amount: _totalAmount,
        denominations: _lastSavedDenominations!,
        reason: _reasonController.text.trim().isNotEmpty ? _reasonController.text.trim() : null,
      );
    } catch (e) {
      print('Error sending receipt to WhatsApp: $e');
      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          onRetry: _sendReceiptToWhatsApp,
          customMessage: 'Error sending receipt to WhatsApp',
        );
      }
    }
  }

  Future<void> _submitReceiptToBackend({
    required File pdfFile,
    required String eventId,
    required String phoneNumber,
    required bool toWhatsapp,
    required dynamic receiptNo, // Changed from 'int' to 'dynamic' to accept both uuid and int
  }) async {
    try {
      print('📱 ========== BACKEND SUBMISSION STARTED ==========');
      print('📱 Event ID: $eventId');
      print('📱 Phone Number: $phoneNumber'); // Will be empty string
      print('📱 PDF Path: ${pdfFile.path}');
      print('📱 to_whatsapp: $toWhatsapp'); // Will be false

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://agmwcgxssorjwiinpknr.supabase.co/functions/v1/receipts_handler'),
      );

      // Add authorization header
      final session = _supabase.auth.currentSession;
      if (session != null) {
        request.headers['Authorization'] = 'Bearer ${session.accessToken}';
      }

      // Add form fields
      request.fields['event_id'] = eventId;
      request.fields['phone_number'] = phoneNumber; // Empty string
      request.fields['to_whatsapp'] = toWhatsapp.toString(); // 'false'
      request.fields['receipt_type'] = 'withdrawal';
      request.fields['receipt_no'] = receiptNo.toString(); // Convert to string

      // Add PDF file
      var pdfMultipart = await http.MultipartFile.fromPath(
        'pdf',
        pdfFile.path,
        filename: 'withdrawal_receipt_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      request.files.add(pdfMultipart);

      // Send request
      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        print('✅ SUCCESS: Receipt submitted to backend');
      } else {
        print('❌ FAILED: Receipt submission failed (${streamedResponse.statusCode})');
        print('Response: $responseBody');
      }
    } catch (e, stackTrace) {
      print('❌ Error submitting receipt to backend: $e');
      print('Stack trace: $stackTrace');
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AbsorbPointer(
          absorbing: _isSaving,
          child: Scaffold(
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

                      // Phone Number with validation
                      _buildPhoneInputField(),

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
                            const SizedBox(height: 4),
                            const Text(
                              'Total available across all operators for this event',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
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
                      Column(
                        children: [
                          // Save and Clear buttons
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

                          const SizedBox(height: 12),

                          // WhatsApp button - disabled until withdrawal is saved
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: _withdrawalSaved ? _sendReceiptToWhatsApp : null,
                              icon: Icon(
                                Icons.send,
                                color: _withdrawalSaved ? Colors.white : Colors.grey[400],
                              ),
                              label: Text(
                                _withdrawalSaved ? 'Send Receipt to WhatsApp' : 'Save Withdrawal First',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _withdrawalSaved ? Colors.white : Colors.grey[400],
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _withdrawalSaved ? const Color(0xFF25D366) : Colors.grey[300],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.zero,
                                  side: const BorderSide(color: Colors.black, width: 2),
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
          ),
        ),
        // Loading overlay - this will be on top and block everything
        if (_isSaving)
          Container(
            color: Colors.black.withOpacity(0.7),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 4,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Saving withdrawal...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
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


  // Add this method after _buildInputField method:

  Widget _buildPhoneInputField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text(
                'Phone Number',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                ' *',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.number,
            maxLength: 10,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: const InputDecoration(
              border: InputBorder.none,
              counterText: '',
              hintText: 'Enter 10-digit phone number',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Phone number is required';
              }
              if (value.length != 10) {
                return 'Phone number must be exactly 10 digits';
              }
              return null;
            },
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
                        ((int.tryParse(controller.text) ?? 0) *
                            int.parse(denomination))
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
        // Available balance indicator (TOTAL for event)
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