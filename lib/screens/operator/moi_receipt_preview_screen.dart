import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';

class MoiReceiptPreviewScreen extends StatefulWidget {
  const MoiReceiptPreviewScreen({super.key});

  @override
  State<MoiReceiptPreviewScreen> createState() => _MoiReceiptPreviewScreenState();
}

class _MoiReceiptPreviewScreenState extends State<MoiReceiptPreviewScreen> {
  File? _receiptFile;
  List<File>? _receiptFiles; // For multiple receipts
  String _receiptType = 'single'; // single, group, split
  int _currentPageIndex = 0;
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading) {
      _loadArguments();
    }
  }

  void _loadArguments() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map<String, dynamic>) {
      setState(() {
        _receiptType = args['receipt_type'] ?? 'single';

        if (_receiptType == 'split' && args['receipt_files'] != null) {
          _receiptFiles = args['receipt_files'] as List<File>;
        } else {
          _receiptFile = args['receipt_file'] as File?;
        }

        _isLoading = false;
      });
    }
  }

  Future<void> _handlePrint() async {
    try {
      if (_receiptType == 'split' && _receiptFiles != null) {
        // Print current file in view
        final currentFile = _receiptFiles![_currentPageIndex];
        final bytes = await currentFile.readAsBytes();
        await Printing.layoutPdf(onLayout: (_) => bytes);
      } else if (_receiptFile != null) {
        final bytes = await _receiptFile!.readAsBytes();
        await Printing.layoutPdf(onLayout: (_) => bytes);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt sent to printer'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handlePrintAll() async {
    if (_receiptFiles == null || _receiptFiles!.isEmpty) return;

    try {
      for (var file in _receiptFiles!) {
        final bytes = await file.readAsBytes();
        await Printing.layoutPdf(onLayout: (_) => bytes);
        // Small delay between prints
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_receiptFiles!.length} receipts sent to printer'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleShare() async {
    try {
      if (_receiptType == 'split' && _receiptFiles != null) {
        // Share all files
        await Share.shareXFiles(
          _receiptFiles!.map((f) => XFile(f.path)).toList(),
          text: 'MOI Receipts',
        );
      } else if (_receiptFile != null) {
        await Share.shareXFiles(
          [XFile(_receiptFile!.path)],
          text: 'MOI Receipt',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildReceiptViewer() {
    if (_receiptType == 'split' && _receiptFiles != null && _receiptFiles!.isNotEmpty) {
      final currentFile = _receiptFiles![_currentPageIndex];
      return Column(
        children: [
          // Page indicator
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey[200],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _currentPageIndex > 0
                      ? () {
                    setState(() {
                      _currentPageIndex--;
                    });
                  }
                      : null,
                ),
                Text(
                  'Receipt ${_currentPageIndex + 1} of ${_receiptFiles!.length}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _currentPageIndex < _receiptFiles!.length - 1
                      ? () {
                    setState(() {
                      _currentPageIndex++;
                    });
                  }
                      : null,
                ),
              ],
            ),
          ),
          Expanded(
            child: PDFView(
              filePath: currentFile.path,
              enableSwipe: false,
              swipeHorizontal: false,
              autoSpacing: false,
              pageFling: false,
            ),
          ),
        ],
      );
    } else if (_receiptFile != null) {
      return PDFView(
        filePath: _receiptFile!.path,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: true,
      );
    } else {
      return const Center(
        child: Text('No receipt to display'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _receiptType == 'split'
              ? 'MOI Receipts Preview'
              : _receiptType == 'group'
              ? 'Group MOI Receipt'
              : 'Single MOI Receipt',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey[300]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: _buildReceiptViewer(),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                if (_receiptType == 'split' && _receiptFiles != null && _receiptFiles!.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _handlePrintAll,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.print),
                        label: Text(
                          'Print All (${_receiptFiles!.length} receipts)',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _handlePrint,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.print),
                          label: Text(
                            _receiptType == 'split' ? 'Print Current' : 'Print',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _handleShare,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.share),
                          label: const Text(
                            'Share',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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
        ],
      ),
    );
  }
}