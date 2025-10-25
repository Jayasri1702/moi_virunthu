import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class CollectionDetailsScreen extends StatefulWidget {
  const CollectionDetailsScreen({super.key});

  @override
  State<CollectionDetailsScreen> createState() => _CollectionDetailsScreenState();
}

class _CollectionDetailsScreenState extends State<CollectionDetailsScreen> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _mois = [];
  List<Map<String, dynamic>> _filteredMois = [];
  bool _isLoading = true;
  String? _eventId;
  String? _operatorId;
  double _totalAmount = 0.0;
  int _totalCount = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map<String, dynamic>) {
      _eventId = args['id'];
      _operatorId = args['operator_id'];
      _loadCollectionDetails();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCollectionDetails() async {
    if (_eventId == null || _operatorId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await _supabase
          .from('mois')
          .select('*')
          .eq('event_id', _eventId!)
          .eq('operator_id', _operatorId!)
          .eq('is_deleted', false)
          .order('serial_no', ascending: true);

      double total = 0.0;
      for (var moi in response) {
        total += (moi['amount'] as num).toDouble();
      }

      setState(() {
        _mois = List<Map<String, dynamic>>.from(response);
        _filteredMois = _mois;
        _totalAmount = total;
        _totalCount = _mois.length;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading collection details: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  void _filterMois(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredMois = _mois;
      });
      return;
    }

    setState(() {
      _filteredMois = _mois.where((moi) {
        String personsText = _getPersonsCompact(moi['persons']).toLowerCase();
        String villageName = (moi['village_name'] ?? '').toLowerCase();
        String phone = (moi['phone'] ?? '').toLowerCase();
        String searchQuery = query.toLowerCase();

        return personsText.contains(searchQuery) ||
            villageName.contains(searchQuery) ||
            phone.contains(searchQuery);
      }).toList();
    });
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd-MM-yyyy hh:mm a').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _getPersonsCompact(dynamic persons) {
    if (persons == null) return 'No name';

    try {
      List<dynamic> personsList = persons is String ? [] : (persons as List);
      if (personsList.isEmpty) return 'No name';

      List<String> names = [];
      for (var person in personsList) {
        String init = person['init'] ?? '';
        String name = person['name'] ?? '';
        if (name.isNotEmpty) {
          names.add('$init $name'.trim());
        }
      }

      return names.isEmpty ? 'No name' : names.join(', ');
    } catch (e) {
      return 'No name';
    }
  }

  void _showMoiDetails(Map<String, dynamic> moi) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: const BorderSide(color: Colors.black, width: 2),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'MOI Details - O${moi['serial_no']}',
                        style: const TextStyle(
                          fontSize: 18,
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
                Flexible(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('Serial No', 'O${moi['serial_no'] ?? 'N/A'}'),
                          _buildDetailRow('Amount', '₹${moi['amount'] ?? '0'}'),
                          _buildDetailRow('Payment Method', moi['payment_method'] ?? 'N/A'),
                          _buildDetailRow('Village Name', moi['village_name'] ?? 'N/A'),
                          _buildDetailRow('Living Place', moi['living_place'] ?? 'N/A'),
                          _buildDetailRow('Phone', moi['phone'] ?? 'N/A'),
                          _buildDetailRow('Is Uncle', moi['is_uncle'] == true ? 'Yes' : 'No'),
                          if (moi['uncle_order'] != null)
                            _buildDetailRow('Uncle Order', '${moi['uncle_order']}'),
                          if (moi['group_id'] != null)
                            _buildDetailRow('Group ID', '${moi['group_id']}'),
                          _buildDetailRow('Created At', _formatDateTime(moi['created_at'])),

                          const SizedBox(height: 16),
                          const Text(
                            'Persons:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildPersonsDetails(moi['persons']),

                          if (moi['notes'] != null && moi['notes'].toString().isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'Notes:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                border: Border.all(color: Colors.black, width: 1),
                              ),
                              child: Text(moi['notes'] ?? ''),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _editMoi(Map<String, dynamic> moi) {
    Navigator.pushNamed(
      context,
      '/operator/collect-moi',
      arguments: {
        'id': _eventId,
        'operator_id': _operatorId,
        'edit_mode': true,
        'moi_data': moi,
      },
    ).then((_) {
      _loadCollectionDetails();
    });
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonsDetails(dynamic persons) {
    if (persons == null) {
      return const Text('No person details available');
    }

    try {
      List<dynamic> personsList = persons is String ? [] : (persons as List);

      if (personsList.isEmpty) {
        return const Text('No person details available');
      }

      return Column(
        children: personsList.asMap().entries.map((entry) {
          int index = entry.key;
          var person = entry.value;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border.all(color: Colors.black, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Person ${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                _buildDetailRow('Init', person['init'] ?? 'N/A'),
                _buildDetailRow('Name', person['name'] ?? 'N/A'),
                _buildDetailRow('Qualification', person['qualification'] ?? 'N/A'),
                _buildDetailRow('Job', person['job'] ?? 'N/A'),
              ],
            ),
          );
        }).toList(),
      );
    } catch (e) {
      return const Text('Error displaying person details');
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
          'Collection Details',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _loadCollectionDetails,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Search Box
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _filterMois,
              decoration: InputDecoration(
                hintText: 'Search by name, village, or phone...',
                border: InputBorder.none,
                icon: const Icon(Icons.search, color: Colors.black),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.black),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _filteredMois = _mois;
                    });
                  },
                )
                    : null,
              ),
            ),
          ),

          // Summary Card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text(
                      'Total Entries',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_totalCount',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 2,
                  height: 60,
                  color: Colors.black,
                ),
                Column(
                  children: [
                    const Text(
                      'Total Amount',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${_totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // List of MOIs
          Expanded(
            child: _filteredMois.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _searchController.text.isEmpty
                        ? 'No collections found'
                        : 'No results found',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredMois.length,
              itemBuilder: (context, index) {
                final moi = _filteredMois[index];
                final personsDisplay = _getPersonsCompact(moi['persons']);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: InkWell(
                    onTap: () => _showMoiDetails(moi),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  personsDisplay,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                if (moi['village_name'] != null &&
                                    moi['village_name'].toString().isNotEmpty)
                                  Text(
                                    moi['village_name'],
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: moi['payment_method'] == 'CASH'
                                            ? Colors.green[50]
                                            : Colors.blue[50],
                                        border: Border.all(
                                          color: moi['payment_method'] == 'CASH'
                                              ? Colors.green
                                              : Colors.blue,
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        moi['payment_method'] ?? 'N/A',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: moi['payment_method'] == 'CASH'
                                              ? Colors.green
                                              : Colors.blue,
                                        ),
                                      ),
                                    ),
                                    if (moi['is_uncle'] == true)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange[50],
                                          border: Border.all(
                                            color: Colors.orange,
                                            width: 1,
                                          ),
                                        ),
                                        child: const Text(
                                          'UNCLE',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text(
                                '₹${moi['amount'] ?? '0'}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 34,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 2,
                                  ),
                                ),
                                child: Material(
                                  color: Colors.white,
                                  child: InkWell(
                                    onTap: () => _editMoi(moi),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 6,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.edit,
                                            size: 16,
                                            color: Colors.black,
                                          ),
                                          SizedBox(width: 5),
                                          Text(
                                            'Edit',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}