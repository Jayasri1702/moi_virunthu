import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'collect_moi_screen.dart';
import 'correct_village_name.dart'; // Add this import

class EventDashboardScreen extends StatefulWidget {
  const EventDashboardScreen({super.key});

  @override
  State<EventDashboardScreen> createState() => _EventDashboardScreenState();
}

class _EventDashboardScreenState extends State<EventDashboardScreen> {
  Map<String, dynamic>? eventData;
  String operatorName = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get event data from navigation arguments
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map<String, dynamic>) {
      setState(() {
        eventData = args;
        // Get operator name from the event data if it was passed
        operatorName = args['_operator_name'] ?? '';
      });
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd-MM-yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (eventData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Event Dashboard'),
        ),
        body: const Center(
          child: Text('No event data available'),
        ),
      );
    }

    final eventTypeName = eventData!['event_types']?['name'] ?? 'N/A';
    final title = eventData!['title'] ?? 'N/A';
    final venue = eventData!['venue'] ?? 'N/A';
    final city = eventData!['city'] ?? 'N/A';
    final eventDate = _formatDate(eventData!['event_date']);

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
          'Hi Tech Moi',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Dashboard Header
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: const Text(
                'Dashboard',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Event Details
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: Column(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    eventTypeName,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    venue,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    city,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Operator : $operatorName',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildActionButton('Collect Moi', () {
                    // Navigate to Collect Moi screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CollectMoiScreen(),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  _buildActionButton('Correct Village Names', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CorrectVillageNamesScreen(),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  _buildActionButton('Uncle Re-order', () {
                    // Navigate to Uncle Re-order screen
                  }),
                  const SizedBox(height: 12),
                  _buildActionButton('Denomination', () {
                    // Navigate to Denomination screen
                  }),
                  const SizedBox(height: 12),
                  _buildActionButton('User wise collection', () {
                    // Navigate to User wise collection screen
                  }),
                  const SizedBox(height: 12),
                  _buildActionButton('Similar Entries', () {
                    // Navigate to Similar Entries screen
                  }),
                  const SizedBox(height: 12),
                  _buildActionButton('Modified Report', () {
                    // Navigate to Modified Report screen
                  }),
                  const SizedBox(height: 12),
                  _buildActionButton('Export Receipts', () {
                    // Navigate to Export Receipts screen
                  }),
                  const SizedBox(height: 12),
                  _buildActionButton('Final Moi Report', () {
                    // Navigate to Final Moi Report screen
                  }),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback onPressed) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}