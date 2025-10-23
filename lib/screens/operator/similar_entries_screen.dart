import 'package:flutter/material.dart';

class SimilarEntriesScreen extends StatefulWidget {
  const SimilarEntriesScreen({super.key});

  @override
  State<SimilarEntriesScreen> createState() => _SimilarEntriesScreenState();
}

class _SimilarEntriesScreenState extends State<SimilarEntriesScreen> {
  // Empty list for now - will be populated from database later
  List<Map<String, dynamic>> similarEntries = [];

  String _formatAmount(double amount) {
    return amount.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
    );
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
          'Similar Entries',
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
              'Similar Entries',
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
                        _buildHeaderCell('Serial.No', flex: 1),
                        _buildHeaderCell('Name', flex: 2),
                        _buildHeaderCell('Second Person', flex: 2),
                        _buildHeaderCell('City', flex: 2),
                        _buildHeaderCell('Living City', flex: 2),
                        _buildHeaderCell('Amount', flex: 2),
                      ],
                    ),
                  ),

                  // Table Body
                  Expanded(
                    child: similarEntries.isEmpty
                        ? const Center(
                      child: Text(
                        'No similar entries found',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    )
                        : ListView.builder(
                      itemCount: similarEntries.length,
                      itemBuilder: (context, index) {
                        final entry = similarEntries[index];
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
                                entry['serial_no']?.toString() ?? '',
                                flex: 1,
                              ),
                              _buildDataCell(
                                entry['name'] ?? '',
                                flex: 2,
                              ),
                              _buildDataCell(
                                entry['second_person'] ?? '',
                                flex: 2,
                              ),
                              _buildDataCell(
                                entry['city'] ?? '',
                                flex: 2,
                              ),
                              _buildDataCell(
                                entry['living_city'] ?? '',
                                flex: 2,
                              ),
                              _buildDataCell(
                                _formatAmount(entry['amount'] ?? 0.0),
                                flex: 2,
                                align: TextAlign.right,
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
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Total   ${similarEntries.length}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Exit Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 150,
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
        padding: const EdgeInsets.symmetric(horizontal: 8),
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
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildDataCell(
      String text, {
        required int flex,
        TextAlign align = TextAlign.left,
      }) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: Colors.grey[300]!, width: 1),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 12),
          textAlign: align,
        ),
      ),
    );
  }
}