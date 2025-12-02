import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'collect_moi_screen.dart';
import 'correct_village_name.dart';
import 'uncle_reorder_screen.dart';
import 'denomination_screen.dart';
import 'user_wise_collection.dart';
import 'similar_entries_screen.dart';
import 'double_entries_screen.dart';
import 'modified_report_screen.dart';
import 'cash_managements_screen.dart';
import '../../services/receipt_generator.dart';
import 'package:printing/printing.dart';
import '../../services/final_moi_report_screen.dart';
import '../../utils/network_utils.dart';

class EventDashboardScreen extends StatefulWidget {
  const EventDashboardScreen({super.key});

  @override
  State<EventDashboardScreen> createState() => _EventDashboardScreenState();
}

// Around line 16-18, modify the state variables:
class _EventDashboardScreenState extends State<EventDashboardScreen> {
  Map<String, dynamic>? eventData;
  String operatorName = '';
  String? operatorId;

  bool _isAdminView = false; // This already exists

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute
        .of(context)
        ?.settings
        .arguments;
    if (args != null && args is Map<String, dynamic>) {
      setState(() {
        eventData = args;
        operatorName = args['_operator_name'] ?? '';
        operatorId = args['_operator_id'];
        // ✅ MODIFY THIS LINE - Check for explicit admin view flag
        _isAdminView = args['_is_admin_view'] == true;
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
              padding: const EdgeInsets.all(24),
              // Change from vertical: 16
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12), // Add this
                boxShadow: [ // Add this shadow
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              // Remove: border: Border.all(color: Colors.black, width: 2),
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
                borderRadius: BorderRadius.circular(12), // Add this
                boxShadow: [ // Add this shadow
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              // Remove: border: Border.all(color: Colors.black, width: 2),
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
            // Action Buttons - Grid Layout
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Transaction Section
                  const Text(
                    'Transaction',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildGridButton('Collect Moi', Icons.add, () {
                          final eventDataWithOperator = Map<String,
                              dynamic>.from(eventData!);
                          eventDataWithOperator['operator_id'] = operatorId;

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CollectMoiScreen(),
                              settings: RouteSettings(
                                  arguments: eventDataWithOperator),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildGridButton(
                            'Collection Details', Icons.person, () {
                          final eventDataWithOperator = Map<String,
                              dynamic>.from(eventData!);
                          eventDataWithOperator['operator_id'] = operatorId;

                          Navigator.pushNamed(
                            context,
                            '/operator/collection-details',
                            arguments: eventDataWithOperator,
                          );
                        }),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildGridButton(
                            'Cash Withdrawal', Icons.money_off, () {
                          Navigator.pushNamed(
                            context,
                            '/operator/cash_withdrawal',
                            arguments: {
                              'id': eventData!['id'],
                              'operator_id': operatorId
                            },
                          );
                        }),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildGridButton(
                            'Exchange Deno', Icons.swap_horiz, () {
                          Navigator.pushNamed(
                            context,
                            '/operator/exchange-denomination',
                            arguments: {
                              'id': eventData!['id'],
                              'operator_id': operatorId
                            },
                          );
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildGridButton(
                            'Uncle Re-order', Icons.sort_by_alpha, () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const UncleReorderScreen(),
                              settings: RouteSettings(arguments: eventData),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildGridButton(
                            'Correct Village', Icons.location_city, () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (
                                  context) =>  CorrectVillageNamesScreen(
                                  eventId: eventData!['id']
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                  if (_isAdminView) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildGridButton('Correct Person', Icons
                              .person_search, () {
                            Navigator.pushNamed(
                              context,
                              '/admin/correct-person-data',
                              arguments: {
                                'event_id': eventData!['id'],
                                'operator_id': operatorId,
                              },
                            );
                          }),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(), // Empty placeholder
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Report Section
                  const Text(
                    'Report',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildGridButton(
                            'Similar Entries', Icons.content_copy, () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  SimilarEntriesScreen(
                                    eventId: eventData!['id'],
                                  ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildGridButton(
                            'Cash Deno', Icons.currency_rupee, () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  DenominationScreen(
                                    eventId: eventData!['id'],
                                  ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildGridButton(
                            'Double Entries', Icons.filter_2, () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  DoubleEntriesScreen(
                                    eventId: eventData!['id'],
                                  ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildGridButton('User Wise', Icons.group, () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  UserWiseCollectionScreen(
                                    eventId: eventData!['id'],
                                  ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildGridButton('Cash Management',
                            Icons.account_balance_wallet, () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      CashManagementScreen(
                                        eventId: eventData!['id'],
                                        operatorId: operatorId,
                                      ),
                                ),
                              );
                            }),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildGridButton(
                            'Modified Report', Icons.edit_note, () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ModifiedReportScreen(
                                    eventId: eventData!['id'],
                                  ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildGridButton(
                            'Sample Receipt', Icons.receipt, () {
                          _showSampleReceipt();
                        }),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildGridButton(
                            'Final Moi Report', Icons.assessment, () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  FinalMoiReportScreen(
                                    eventId: eventData!['id'],
                                  ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),

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

  Widget _buildGridButton(String label, IconData icon, VoidCallback onPressed) {
    return Container(
      height: 110,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF8F8F8F),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSampleReceipt() async {
    try {
      final eventTypeName = eventData!['event_types']?['name'] ?? 'Event';
      final customerName = eventData!['customer_name'] ?? 'N/A';
      final venue = eventData!['venue'] ?? 'N/A';
      final city = eventData!['city'] ?? 'N/A';
      final contactNumber = eventData!['customer_phone'] ?? '';

      DateTime eventDate;
      try {
        eventDate = DateTime.parse(eventData!['event_date']);
      } catch (e) {
        eventDate = DateTime.now();
      }

      TimeOfDay? eventTime;
      if (eventData!['event_time'] != null) {
        final timeParts = eventData!['event_time'].split(':');
        eventTime = TimeOfDay(
          hour: int.parse(timeParts[0]),
          minute: int.parse(timeParts[1]),
        );
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
        const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final file = await ReceiptGenerator.generateReceiptPDF(
        context: context,
        customerName: customerName,
        venue: venue,
        city: city,
        contactNumber: contactNumber,
        eventTypeName: eventTypeName,
        selectedDate: eventDate,
        selectedTime: eventTime,
      );

      // Close loading indicator
      if (mounted) Navigator.pop(context);

      if (file != null && mounted) {
        // Read the PDF file
        final pdfBytes = await file.readAsBytes();

        // Show receipt in a dialog with print option
        showDialog(
          context: context,
          builder: (context) =>
              Dialog(
                child: Container(
                  width: 400,
                  constraints: const BoxConstraints(maxHeight: 700),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with close button
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            bottom: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Sample Receipt',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      // PDF Preview
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: PdfPreview(
                            build: (format) => pdfBytes,
                            allowPrinting: false,
                            allowSharing: false,
                            canChangePageFormat: false,
                            canChangeOrientation: false,
                            canDebug: false,
                            pdfFileName: 'receipt_$customerName.pdf',
                            actions: const [], // Remove default toolbar actions
                          ),
                        ),
                      ),
                      // Custom Print Button at bottom
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            top: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await Printing.layoutPdf(
                              onLayout: (format) => pdfBytes,
                            );
                          },
                          icon: const Icon(Icons.print, size: 24),
                          label: const Text(
                            'Print Receipt',
                            style: TextStyle(fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB846D7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to generate receipt'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Close loading if still showing
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          onRetry: _showSampleReceipt,
          customMessage: 'Error generating receipt',
        );
      }
    }
  }
}

