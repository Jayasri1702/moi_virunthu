import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:share_plus/share_plus.dart';

class FinalMoiReportScreen extends StatefulWidget {
  final String eventId;

  const FinalMoiReportScreen({
    super.key,
    required this.eventId,
  });

  @override
  State<FinalMoiReportScreen> createState() => _FinalMoiReportScreenState();
}

class _FinalMoiReportScreenState extends State<FinalMoiReportScreen> {
  bool _isLoading = false;
  String? _generatedContent;
  String? _selectedFormat;
  File? _generatedFile;

  Future<void> _generateReport(String returnType) async {
    setState(() {
      _isLoading = true;
      _selectedFormat = returnType;
      _generatedContent = null;
      _generatedFile = null;
    });

    try {
      final response = await http.post(
        Uri.parse('https://agmwcgxssorjwiinpknr.supabase.co/functions/v1/report-generator'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer 65d9708252d6947d42e757bc7558acce87b52c2067ef5663e1dc0b29843b1e2a',
        },
        body: json.encode({
          'event_id': widget.eventId,
          'return_type': returnType,
        }),
      );

      if (response.statusCode == 200) {
        if (returnType == 'html' || returnType == 'txt') {
          setState(() {
            _generatedContent = response.body;
          });
        } else if (returnType == 'xlsx') {
          // Save Excel file
          final output = await getTemporaryDirectory();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final filePath = '${output.path}/final_moi_report_$timestamp.xlsx';
          final file = File(filePath);

          await file.writeAsBytes(response.bodyBytes);

          if (await file.exists()) {
            final fileSize = await file.length();
            if (kDebugMode) print('Excel file created: ${file.path}, size: $fileSize bytes');

            setState(() {
              _generatedFile = file;
            });
          } else {
            throw Exception('Failed to create Excel file');
          }
        } else if (returnType == 'pdf') {
          setState(() {
            _generatedContent = response.body;
          });
        }
      } else {
        throw Exception('Failed to generate report: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _printReport() async {
    try {
      setState(() => _isLoading = true);

      if (_selectedFormat == 'html' && _generatedContent != null) {
        // Convert HTML to PDF and print
        final pdfBytes = await _convertHtmlToPdf(_generatedContent!);
        if (pdfBytes != null) {
          await Printing.layoutPdf(onLayout: (format) => pdfBytes);
        } else {
          throw Exception('Failed to convert HTML to PDF');
        }
      } else if (_selectedFormat == 'txt' && _generatedContent != null) {
        // Convert text to PDF and print
        final pdfBytes = await _convertTextToPdf(_generatedContent!);
        await Printing.layoutPdf(onLayout: (format) => pdfBytes);
      } else if (_selectedFormat == 'xlsx') {
        // For Excel, suggest opening in spreadsheet app
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please share the Excel file and print from your spreadsheet app'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else if (_selectedFormat == 'pdf' && _generatedContent != null) {
        // Convert HTML to PDF for printing
        final pdfBytes = await _convertHtmlToPdf(_generatedContent!);
        if (pdfBytes != null) {
          await Printing.layoutPdf(onLayout: (format) => pdfBytes);
        } else {
          throw Exception('Failed to convert HTML to PDF');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _shareReport() async {
    try {
      setState(() => _isLoading = true);

      if (_selectedFormat == 'xlsx' && _generatedFile != null) {
        // Share Excel file with proper MIME type
        await Share.shareXFiles(
          [XFile(
            _generatedFile!.path,
            mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            name: 'final_moi_report.xlsx',
          )],
          text: 'Final Moi Report',
          subject: 'Final Moi Report',
        );
      } else if (_selectedFormat == 'pdf' && _generatedContent != null) {
        // Generate PDF from HTML for sharing
        final pdfBytes = await _convertHtmlToPdf(_generatedContent!);
        if (pdfBytes != null) {
          final output = await getTemporaryDirectory();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final filePath = '${output.path}/final_moi_report_$timestamp.pdf';
          final file = File(filePath);
          await file.writeAsBytes(pdfBytes);

          await Share.shareXFiles(
            [XFile(
              file.path,
              mimeType: 'application/pdf',
              name: 'final_moi_report.pdf',
            )],
            text: 'Final Moi Report',
            subject: 'Final Moi Report',
          );
        }
      } else if (_generatedContent != null) {
        // Save content to temporary file (HTML or TXT)
        final output = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final extension = _selectedFormat == 'html' ? 'html' : 'txt';
        final mimeType = _selectedFormat == 'html' ? 'text/html' : 'text/plain';
        final filePath = '${output.path}/final_moi_report_$timestamp.$extension';
        final file = File(filePath);
        await file.writeAsString(_generatedContent!);

        await Share.shareXFiles(
          [XFile(
            file.path,
            mimeType: mimeType,
            name: 'final_moi_report.$extension',
          )],
          text: 'Final Moi Report',
          subject: 'Final Moi Report',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Share error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<Uint8List?> _convertHtmlToPdf(String htmlContent) async {
    try {
      File? generatedFile;
      bool pdfGenerated = false;

      final output = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${output.path}/report_$timestamp.pdf';

      HeadlessInAppWebView? headlessWebView;

      final styledHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    @page {
      size: A4;
      margin: 10mm;
    }
    
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    
    body {
      width: 794px;
      font-family: Arial, sans-serif;
      background: white;
      font-size: 10px;
      line-height: 1.3;
      padding: 20px;
    }
    
    table {
      width: 100%;
      border-collapse: collapse;
      margin: 8px 0;
      font-size: 9px;
      page-break-inside: auto;
    }
    
    tr {
      page-break-inside: avoid;
      page-break-after: auto;
    }
    
    th, td {
      border: 1px solid #000;
      padding: 4px 3px;
      text-align: center;
      word-wrap: break-word;
    }
    
    th {
      background-color: #6B4C9A;
      color: white;
      font-weight: bold;
      font-size: 10px;
    }
    
    h1 {
      font-size: 18px;
      margin: 8px 0;
      color: #333;
      text-align: center;
    }
    
    h2 {
      font-size: 14px;
      margin: 6px 0;
      color: #333;
    }
    
    h3 {
      font-size: 12px;
      margin: 5px 0;
      color: #333;
    }
    
    .summary {
      margin: 10px 0;
      padding: 8px;
      background: #f5f5f5;
      border: 2px solid #000;
      page-break-inside: avoid;
    }
    
    .summary-row {
      display: flex;
      justify-content: space-between;
      padding: 3px 0;
      font-size: 10px;
    }
    
    .page-break {
      page-break-after: always;
    }
    
    img {
      max-width: 100%;
      height: auto;
    }
  </style>
</head>
<body>
$htmlContent
</body>
</html>
''';

      headlessWebView = HeadlessInAppWebView(
        initialData: InAppWebViewInitialData(data: styledHtml),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          useHybridComposition: true,
          useShouldOverrideUrlLoading: false,
        ),
        initialSize: const Size(794, 1123),
        onLoadStop: (controller, url) async {
          try {
            await Future.delayed(const Duration(milliseconds: 2500));

            final contentHeight = await controller.evaluateJavascript(
                source: "Math.max(document.body.scrollHeight, document.documentElement.scrollHeight, document.body.offsetHeight)"
            );

            int totalHeight = 1123;
            if (contentHeight != null) {
              totalHeight = int.tryParse(contentHeight.toString()) ?? 1123;
              if (kDebugMode) print('Content height: $totalHeight pixels');
            }

            final pageHeight = 1123;
            final pagesNeeded = (totalHeight / pageHeight).ceil();
            if (kDebugMode) print('Pages needed: $pagesNeeded');

            final pdf = pw.Document();

            for (int pageIndex = 0; pageIndex < pagesNeeded; pageIndex++) {
              final scrollY = pageIndex * pageHeight;
              await controller.evaluateJavascript(
                  source: "window.scrollTo(0, $scrollY);"
              );
              await Future.delayed(const Duration(milliseconds: 300));

              await headlessWebView?.setSize(Size(794, pageHeight.toDouble()));
              await Future.delayed(const Duration(milliseconds: 300));

              final screenshot = await controller.takeScreenshot();

              if (screenshot != null) {
                final image = pw.MemoryImage(screenshot);

                pdf.addPage(
                  pw.Page(
                    pageFormat: PdfPageFormat.a4,
                    margin: const pw.EdgeInsets.all(0),
                    build: (pw.Context context) {
                      return pw.Image(image, fit: pw.BoxFit.fill);
                    },
                  ),
                );
                if (kDebugMode) print('Added page ${pageIndex + 1} of $pagesNeeded');
              }
            }

            final file = File(filePath);
            final pdfBytes = await pdf.save();
            await file.writeAsBytes(pdfBytes);
            generatedFile = file;
            pdfGenerated = true;
            if (kDebugMode) print('PDF generated successfully: ${pdfBytes.length} bytes with $pagesNeeded pages');
          } catch (e) {
            if (kDebugMode) print('Error generating PDF: $e');
          } finally {
            if (headlessWebView != null) {
              await headlessWebView.dispose();
            }
          }
        },
        onConsoleMessage: (controller, consoleMessage) {
          if (kDebugMode) print('WebView Console: ${consoleMessage.message}');
        },
      );

      await headlessWebView.run();

      int attempts = 0;
      while (attempts < 60 && !pdfGenerated) {
        await Future.delayed(const Duration(milliseconds: 500));
        attempts++;
      }

      if (pdfGenerated && generatedFile != null) {
        final bytes = await generatedFile!.readAsBytes();
        if (kDebugMode) print('Reading PDF file: ${bytes.length} bytes');
        return bytes;
      }

      if (kDebugMode) print('PDF generation timed out or failed');
      return null;
    } catch (e) {
      if (kDebugMode) print('Error converting HTML to PDF: $e');
      return null;
    }
  }

  Future<Uint8List> _convertTextToPdf(String textContent) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Text(
              textContent,
              style: const pw.TextStyle(fontSize: 12),
            ),
          ];
        },
      ),
    );

    return pdf.save();
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
          'Final Moi Report',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          if (_generatedContent == null && _generatedFile == null) ...[
            Expanded(
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(24),
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Select Report Format',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildFormatButton('HTML', 'html', Icons.code, const Color(0xFFB846D7)),
                      const SizedBox(height: 16),
                      _buildFormatButton('Excel', 'xlsx', Icons.table_chart, const Color(0xFF217346)),
                      const SizedBox(height: 16),
                      _buildFormatButton('PDF', 'pdf', Icons.picture_as_pdf, const Color(0xFFB846D7)),
                      const SizedBox(height: 16),
                      _buildFormatButton('Text', 'txt', Icons.text_fields, const Color(0xFFB846D7)),
                    ],
                  ),
                ),
              ),
            ),
          ] else if (_isLoading) ...[
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Processing report...',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
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
                child: _buildReportPreview(),
              ),
            ),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (_selectedFormat != 'xlsx') ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _printReport,
                        icon: const Icon(Icons.print, size: 24),
                        label: const Text(
                          'Print',
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
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _shareReport,
                      icon: const Icon(Icons.share, size: 24),
                      label: Text(
                        _selectedFormat == 'xlsx' ? 'Open/Share' : 'Share',
                        style: const TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedFormat == 'xlsx'
                            ? const Color(0xFF217346)
                            : const Color(0xFF8F8F8F),
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
          ],
        ],
      ),
    );
  }

  Widget _buildFormatButton(String label, String format, IconData icon, Color color) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : () => _generateReport(format),
        icon: Icon(icon, size: 28),
        label: Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildReportPreview() {
    if (_selectedFormat == 'html' && _generatedContent != null) {
      return InAppWebView(
        initialData: InAppWebViewInitialData(data: _generatedContent!),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
        ),
      );
    } else if (_selectedFormat == 'xlsx' && _generatedFile != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.table_chart, size: 64, color: Color(0xFF217346)),
            const SizedBox(height: 16),
            const Text(
              'Excel Report Generated',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'File: ${_generatedFile!.path.split('/').last}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            const Text(
              'Use the Share button to open in Excel',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else if (_selectedFormat == 'txt' && _generatedContent != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(
          _generatedContent!,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
          ),
        ),
      );
    } else if (_selectedFormat == 'pdf') {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.picture_as_pdf, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'PDF Preview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Use Print or Share to view the PDF',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return const Center(child: Text('No content available'));
  }
}