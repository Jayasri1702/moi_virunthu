import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CollectMoiScreen extends StatefulWidget {
  const CollectMoiScreen({super.key});

  @override
  State<CollectMoiScreen> createState() => _CollectMoiScreenState();
}

class _CollectMoiScreenState extends State<CollectMoiScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _serialNoController = TextEditingController(text: 'O1');
  final _mobileController = TextEditingController();
  final _villageController = TextEditingController();
  final _livingPlaceController = TextEditingController();
  final _init1Controller = TextEditingController();
  final _name1Controller = TextEditingController();
  final _qualification1Controller = TextEditingController();
  final _job1Controller = TextEditingController();
  final _init2Controller = TextEditingController();
  final _name2Controller = TextEditingController();
  final _qualification2Controller = TextEditingController();
  final _job2Controller = TextEditingController();
  final _notesController = TextEditingController();
  final _amountController = TextEditingController();

  // Checkboxes
  bool _isCheckAdvanceUPI = false;
  bool _isUncle = false;

  // Denomination controllers
  final _denom500Controller = TextEditingController();
  final _denom200Controller = TextEditingController();
  final _denom100Controller = TextEditingController();
  final _denom50Controller = TextEditingController();
  final _denom20Controller = TextEditingController();
  final _denom10Controller = TextEditingController();
  final _denom1Controller = TextEditingController();

  int _totalCount = 0;
  double _totalAmount = 0.0;

  @override
  void dispose() {
    _serialNoController.dispose();
    _mobileController.dispose();
    _villageController.dispose();
    _livingPlaceController.dispose();
    _init1Controller.dispose();
    _name1Controller.dispose();
    _qualification1Controller.dispose();
    _job1Controller.dispose();
    _init2Controller.dispose();
    _name2Controller.dispose();
    _qualification2Controller.dispose();
    _job2Controller.dispose();
    _notesController.dispose();
    _amountController.dispose();
    _denom500Controller.dispose();
    _denom200Controller.dispose();
    _denom100Controller.dispose();
    _denom50Controller.dispose();
    _denom20Controller.dispose();
    _denom10Controller.dispose();
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
    int count1 = int.tryParse(_denom1Controller.text) ?? 0;

    setState(() {
      _totalCount = count500 + count200 + count100 + count50 + count20 + count10 + count1;
      _totalAmount = (count500 * 500) + (count200 * 200) + (count100 * 100) +
          (count50 * 50) + (count20 * 20) + (count10 * 10) + (count1 * 1);
      _amountController.text = _totalAmount.toStringAsFixed(0);
    });
  }

  String _numberToWords(double number) {
    // Basic implementation - you can enhance this
    if (number == 0) return 'Zero';
    return 'Rs. ${number.toStringAsFixed(0)} Only';
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
          'Collect Moi',
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
                // Header with Serial No and Action Buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Serial No.',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            width: 100,
                            height: 40,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                            child: Center(
                              child: TextField(
                                controller: _serialNoController,
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildTopButton('Sample Receipt'),
                          _buildTopButton('Cash Drawing'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildTopButton('Exchange Denomination'),
                          _buildTopButton('Collection Details'),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Mobile Number
                _buildInputField('Mobile Number', _mobileController,
                    keyboardType: TextInputType.phone),

                const SizedBox(height: 16),

                // Village Name and Living Place
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Village Name',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextField(
                              controller: _villageController,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 2,
                        height: 60,
                        color: Colors.black,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Living Place',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextField(
                                controller: _livingPlaceController,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Person 1 Details
                _buildPersonRow(
                  _init1Controller,
                  _name1Controller,
                  _qualification1Controller,
                  _job1Controller,
                ),

                const SizedBox(height: 16),

                // Person 2 Details
                _buildPersonRow(
                  _init2Controller,
                  _name2Controller,
                  _qualification2Controller,
                  _job2Controller,
                ),

                const SizedBox(height: 16),

                // Notes
                _buildNotesField(),

                const SizedBox(height: 16),

                // Amount and Checkboxes Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Amount Section
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Amount',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  height: 50,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.black, width: 2),
                                  ),
                                  child: TextField(
                                    controller: _amountController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Amount in words',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Checkboxes and Denomination
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Check/Advance/UPI row
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 35,
                                    child: Checkbox(
                                      value: _isCheckAdvanceUPI,
                                      onChanged: (value) {
                                        setState(() {
                                          _isCheckAdvanceUPI = value ?? false;
                                        });
                                      },
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const SizedBox(
                                    width: 100,
                                    child: Text(
                                      'Check / Advance / UPI',
                                      style: TextStyle(fontSize: 11),
                                      maxLines: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildDenomCell('500', _denom500Controller),
                                ],
                              ),
                              // Uncle row
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 35,
                                    child: Checkbox(
                                      value: _isUncle,
                                      onChanged: (value) {
                                        setState(() {
                                          _isUncle = value ?? false;
                                        });
                                      },
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const SizedBox(
                                    width: 100,
                                    child: Text(
                                      'Uncle',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildDenomCell('200', _denom200Controller),
                                ],
                              ),
                              // Rest of denominations
                              _buildDenomCell('100', _denom100Controller),
                              _buildDenomCell('50', _denom50Controller),
                              _buildDenomCell('20', _denom20Controller),
                              _buildDenomCell('10', _denom10Controller),
                              _buildDenomCell('1', _denom1Controller),
                              // Total row
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 60,
                                    height: 35,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.black, width: 2),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'Total',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 70,
                                    height: 35,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.black, width: 2),
                                    ),
                                    child: Center(
                                      child: Text(
                                        _totalAmount.toStringAsFixed(0),
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Count : $_totalCount'),
                          Text('Amount : ${_totalAmount.toStringAsFixed(0)}'),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Moi Details
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.black, width: 2),
                          ),
                        ),
                        child: const Text(
                          'Moi Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: TextField(
                            maxLines: null,
                            expands: true,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Enter moi details here...',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        // Handle form submission
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Moi collected successfully!')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                        side: const BorderSide(color: Colors.black, width: 2),
                      ),
                    ),
                    child: const Text(
                      'Submit',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopButton(String label) {
    return Expanded(
      child: Container(
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black, width: 2),
        ),
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: () {
              // Handle button tap
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label clicked')),
              );
            },
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller,
      {TextInputType? keyboardType}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
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

  Widget _buildPersonRow(
      TextEditingController initController,
      TextEditingController nameController,
      TextEditingController qualificationController,
      TextEditingController jobController,
      ) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Row(
        children: [
          _buildPersonCell('Init', initController, flex: 1),
          _buildPersonCell('Name', nameController, flex: 3),
          _buildPersonCell('Qualification', qualificationController, flex: 2),
          _buildPersonCell('Job', jobController, flex: 2),
        ],
      ),
    );
  }

  Widget _buildPersonCell(String label, TextEditingController controller,
      {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            right: BorderSide(color: Colors.black, width: 2),
          ),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesField() {
    return Container(
      height: 100,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Notes',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _notesController,
              maxLines: null,
              decoration: const InputDecoration(
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDenomCell(String label, TextEditingController controller) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 35,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ),
        Container(
          width: 70,
          height: 35,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (value) => _calculateDenomination(),
          ),
        ),
      ],
    );
  }
}