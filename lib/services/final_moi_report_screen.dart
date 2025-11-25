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
        } else if (returnType == 'pdf') {
          // Save PDF bytes temporarily - we'll convert from HTML instead
          setState(() {
            _generatedContent = response.body; // Store as content for now
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
      } else if (_selectedFormat == 'pdf' && _generatedContent != null) {
        // For PDF format, we need to fetch as HTML first and then convert
        // Let's get HTML version instead
        final response = await http.post(
          Uri.parse('https://agmwcgxssorjwiinpknr.supabase.co/functions/v1/report-generator'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer 65d9708252d6947d42e757bc7558acce87b52c2067ef5663e1dc0b29843b1e2a',
          },
          body: json.encode({
            'event_id': widget.eventId,
            'return_type': 'html',
          }),
        );

        if (response.statusCode == 200) {
          final pdfBytes = await _convertHtmlToPdf(response.body);
          if (pdfBytes != null) {
            await Printing.layoutPdf(onLayout: (format) => pdfBytes);
          } else {
            throw Exception('Failed to convert HTML to PDF');
          }
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

      if (_selectedFormat == 'pdf') {
        // Generate PDF from HTML for sharing
        final response = await http.post(
          Uri.parse('https://agmwcgxssorjwiinpknr.supabase.co/functions/v1/report-generator'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer 65d9708252d6947d42e757bc7558acce87b52c2067ef5663e1dc0b29843b1e2a',
          },
          body: json.encode({
            'event_id': widget.eventId,
            'return_type': 'html',
          }),
        );

        if (response.statusCode == 200) {
          final pdfBytes = await _convertHtmlToPdf(response.body);
          if (pdfBytes != null) {
            final output = await getTemporaryDirectory();
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final filePath = '${output.path}/final_moi_report_$timestamp.pdf';
            final file = File(filePath);
            await file.writeAsBytes(pdfBytes);

            await Share.shareXFiles(
              [XFile(file.path)],
              text: 'Final Moi Report',
            );
          }
        }
      } else if (_generatedContent != null) {
        // Save content to temporary file
        final output = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final extension = _selectedFormat == 'html' ? 'html' : 'txt';
        final filePath = '${output.path}/final_moi_report_$timestamp.$extension';
        final file = File(filePath);
        await file.writeAsString(_generatedContent!);

        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Final Moi Report',
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

      // Wrap content with proper A4 styling
      final styledHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    
    body {
      width: 210mm;
      padding: 10mm;
      font-family: Arial, sans-serif;
      background: white;
    }
    
    table {
      width: 100%;
      border-collapse: collapse;
      margin: 10px 0;
      font-size: 11px;
    }
    
    th, td {
      border: 1px solid #000;
      padding: 6px 4px;
      text-align: center;
    }
    
    th {
      background-color: #6B4C9A;
      color: white;
      font-weight: bold;
    }
    
    h1, h2, h3 {
      margin: 10px 0;
      color: #333;
    }
    
    .summary {
      margin: 15px 0;
      padding: 10px;
      background: #f5f5f5;
      border: 2px solid #000;
    }
    
    .summary-row {
      display: flex;
      justify-content: space-between;
      padding: 5px 0;
      font-size: 12px;
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
        ),
        initialSize: const Size(794, 1123), // A4 size in pixels at 96 DPI
        onLoadStop: (controller, url) async {
          try {
            // Wait for content to render
            await Future.delayed(const Duration(milliseconds: 2000));

            // Get the actual content height
            final contentHeight = await controller.evaluateJavascript(
                source: "Math.max(document.body.scrollHeight, document.documentElement.scrollHeight)"
            );

            int height = 1123;
            if (contentHeight != null) {
              height = int.tryParse(contentHeight.toString()) ?? 1123;
              // Ensure minimum height and add padding
              height = height < 1123 ? 1123 : (height + 50);
            }

            print('Content height: $height pixels');

            // Resize to actual content
            await headlessWebView?.setSize(Size(794, height.toDouble()));
            await Future.delayed(const Duration(milliseconds: 800));

            // Take screenshot
            final screenshot = await controller.takeScreenshot();

            if (screenshot != null) {
              print('Screenshot captured: ${screenshot.length} bytes');

              final pdf = pw.Document();
              final image = pw.MemoryImage(screenshot);

              // Calculate number of pages needed
              final pagesNeeded = (height / 1123).ceil();
              print('Pages needed: $pagesNeeded');

              if (pagesNeeded == 1) {
                // Single page
                pdf.addPage(
                  pw.Page(
                    pageFormat: PdfPageFormat.a4,
                    margin: const pw.EdgeInsets.all(0),
                    build: (pw.Context context) {
                      return pw.Image(image, fit: pw.BoxFit.fill);
                    },
                  ),
                );
              } else {
                // Multiple pages - split the image
                pdf.addPage(
                  pw.Page(
                    pageFormat: PdfPageFormat.a4,
                    margin: const pw.EdgeInsets.all(0),
                    build: (pw.Context context) {
                      return pw.Image(image, fit: pw.BoxFit.fill);
                    },
                  ),
                );
              }

              final file = File(filePath);
              final pdfBytes = await pdf.save();
              await file.writeAsBytes(pdfBytes);
              generatedFile = file;
              pdfGenerated = true;
              print('PDF generated successfully: ${pdfBytes.length} bytes');
            }
          } catch (e) {
            print('Error generating PDF: $e');
          } finally {
            if (headlessWebView != null) {
              await headlessWebView.dispose();
            }
          }
        },
        onConsoleMessage: (controller, consoleMessage) {
          print('WebView Console: ${consoleMessage.message}');
        },
      );

      await headlessWebView.run();

      // Wait for PDF generation
      int attempts = 0;
      while (attempts < 40 && !pdfGenerated) {
        await Future.delayed(const Duration(milliseconds: 500));
        attempts++;
      }

      if (pdfGenerated && generatedFile != null) {
        final bytes = await generatedFile!.readAsBytes();
        print('Reading PDF file: ${bytes.length} bytes');
        return bytes;
      }

      print('PDF generation timed out or failed');
      return null;
    } catch (e) {
      print('Error converting HTML to PDF: $e');
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
          // Format Selection
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
                      _buildFormatButton('HTML', 'html', Icons.code),
                      const SizedBox(height: 16),
                      _buildFormatButton('PDF', 'pdf', Icons.picture_as_pdf),
                      const SizedBox(height: 16),
                      _buildFormatButton('Text', 'txt', Icons.text_fields),
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
            // Report Content
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

            // Action Buttons
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
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _shareReport,
                      icon: const Icon(Icons.share, size: 24),
                      label: const Text(
                        'Share',
                        style: TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8F8F8F),
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

  Widget _buildFormatButton(String label, String format, IconData icon) {
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
          backgroundColor: const Color(0xFFB846D7),
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