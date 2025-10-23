import 'package:flutter/material.dart';

class UserWiseCollectionScreen extends StatefulWidget {
  const UserWiseCollectionScreen({super.key});

  @override
  State<UserWiseCollectionScreen> createState() => _UserWiseCollectionScreenState();
}

class _UserWiseCollectionScreenState extends State<UserWiseCollectionScreen> {
  // Empty list for now - will be populated from database later
  List<Map<String, dynamic>> userCollections = [];

  // Calculate totals
  Map<String, dynamic> _calculateTotals() {
    int totalCount = 0;
    int totalAmount = 0;

    for (var user in userCollections) {
      totalCount += (user['count'] ?? 0) as int;
      totalAmount += (user['amount'] ?? 0) as int;
    }

    return {
      'totalCount': totalCount,
      'totalAmount': totalAmount,
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
          'User wise collection',
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
              'User wise collection',
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
                          flex: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: const BoxDecoration(
                              border: Border(
                                right: BorderSide(color: Colors.white, width: 1),
                              ),
                            ),
                            child: const Text(
                              'Name',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: const BoxDecoration(
                              border: Border(
                                right: BorderSide(color: Colors.white, width: 1),
                              ),
                            ),
                            child: const Text(
                              'Count',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: const Text(
                              'Amount',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Table Body
                  Expanded(
                    child: userCollections.isEmpty
                        ? const Center(
                      child: Text(
                        'No collection data available',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    )
                        : ListView.builder(
                      itemCount: userCollections.length,
                      itemBuilder: (context, index) {
                        final user = userCollections[index];
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
                                flex: 4,
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
                                    user['name'] ?? '',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
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
                                    (user['count'] ?? 0).toString(),
                                    style: const TextStyle(fontSize: 14),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    _formatAmount(user['amount'] ?? 0),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Footer with totals
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey[400]!, width: 2),
                      ),
                      color: Colors.grey[50],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Total Count ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        Text(
                          '${totals['totalCount']}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(width: 30),
                        Text(
                          'Total Amount ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        Text(
                          _formatAmount(totals['totalAmount']),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
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
}