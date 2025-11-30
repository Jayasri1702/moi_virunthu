import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/network_utils.dart';

class UncleReorderScreen extends StatefulWidget {
  const UncleReorderScreen({super.key});

  @override
  State<UncleReorderScreen> createState() => _UncleReorderScreenState();
}

class _UncleReorderScreenState extends State<UncleReorderScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> uncles = [];
  final Map<int, TextEditingController> _controllers = {};
  bool _isLoading = true;
  Map<String, dynamic>? eventData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get event data from navigation arguments
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map<String, dynamic>) {
      setState(() {
        eventData = args;
      });
      _loadUncles();
    }
  }

  Future<void> _loadUncles() async {
    if (eventData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event data not found')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      final eventId = eventData!['id'];

      // Fetch all mois where is_uncle = true for this event
      final response = await _supabase
          .from('mois')
          .select('id, persons, uncle_order')
          .eq('event_id', eventId)
          .eq('is_uncle', true)
          .order('uncle_order', ascending: true);

      List<Map<String, dynamic>> loadedUncles = [];

      // Process each moi record to extract only first person's name (without init)
      for (var moi in response) {
        final persons = moi['persons'] as List<dynamic>?;
        if (persons != null && persons.isNotEmpty) {
          // Get only the first person
          final firstPerson = persons[0];
          if (firstPerson is Map<String, dynamic>) {
            // Only get the name, not the init
            final name = firstPerson['name']?.toString() ?? '';

            if (name.trim().isNotEmpty) {
              loadedUncles.add({
                'id': moi['id'],
                'uncle_name': name.trim(),
                'serial_no': moi['uncle_order'] ?? 0,
              });
            }
          }
        }
      }

      setState(() {
        uncles = loadedUncles;
        _isLoading = false;
      });

      // Initialize controllers
      _controllers.clear();
      for (int i = 0; i < uncles.length; i++) {
        final serialNo = uncles[i]['serial_no'];
        _controllers[i] = TextEditingController(
          text: (serialNo != null && serialNo > 0) ? serialNo.toString() : '',
        );
      }
    } catch (e) {
      print('Error loading uncles: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          onRetry: _loadUncles,
          customMessage: 'Error loading uncles',
        );
      }
    }
  }

  @override
  void dispose() {
    // Dispose all controllers
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _updateSerialNumbers() async {
    try {
      // Collect all serial numbers and validate
      Map<int, int> serialNumberMap = {};
      Set<int> usedSerialNumbers = {};

      for (int i = 0; i < uncles.length; i++) {
        final text = _controllers[i]?.text.trim() ?? '';

        if (text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please enter a serial number for ${uncles[i]['uncle_name']}'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final serialNo = int.tryParse(text);
        if (serialNo == null || serialNo <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please enter a valid serial number for ${uncles[i]['uncle_name']}'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // Check for duplicates
        if (usedSerialNumbers.contains(serialNo)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Serial number $serialNo is used multiple times. Please use unique numbers.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        usedSerialNumbers.add(serialNo);
        serialNumberMap[i] = serialNo;
      }

      // Update each uncle's serial number in database
      for (int i = 0; i < uncles.length; i++) {
        final uncleId = uncles[i]['id'];
        final serialNo = serialNumberMap[i]!;

        await _supabase
            .from('mois')
            .update({'uncle_order': serialNo})
            .eq('id', uncleId);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Serial numbers updated successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Reload the list to show updated order
      await _loadUncles();
    } catch (e) {
      print('Error updating serial numbers: $e');
      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          onRetry: _updateSerialNumbers,
          customMessage: 'Error updating serial numbers',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Uncle Re-order',
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
              'Uncle Re-order',
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
                        Expanded(
                          flex: 7,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: const BoxDecoration(
                              border: Border(
                                right: BorderSide(color: Colors.white, width: 1),
                              ),
                            ),
                            child: const Text(
                              'Uncle Name',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: const Text(
                              'Serial_No',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
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
                        : uncles.isEmpty
                        ? const Center(
                      child: Text(
                        'No uncles to display',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    )
                        : ListView.builder(
                      itemCount: uncles.length,
                      itemBuilder: (context, index) {
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
                              Expanded(
                                flex: 7,
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      right: BorderSide(
                                        color: Colors.grey[300]!,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    uncles[index]['uncle_name'] ?? '',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  child: TextField(
                                    controller: _controllers[index],
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    textAlign: TextAlign.center,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                        horizontal: 8,
                                      ),
                                      hintText: '0',
                                      hintStyle: TextStyle(
                                        color: Colors.grey[400],
                                      ),
                                      border: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.grey[400]!,
                                        ),
                                      ),
                                      focusedBorder: const OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Color(0xFF6B4C9A),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Footer with total count
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey[300]!, width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Total : ${uncles.length}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
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
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _updateSerialNumbers,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE91E63),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Text(
                      'UPDATE',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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
}