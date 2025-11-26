import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:supabase_flutter/supabase_flutter.dart';
import '/utils/constants.dart'; // if constants are in a separate file

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

// Syncfusion PDF library
import 'package:syncfusion_flutter_pdf/pdf.dart';

// Import pdf package for Printing.convertHtml
import 'package:pdf/pdf.dart' as pdf_pkg;


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
  String? _generatedContent; // HTML or TXT bodies or base64 PDF when return_type == pdf
  String? _selectedFormat;
  File? _generatedFile; // for xlsx or saved merged outputs

  static const _serverUrl =
      'https://agmwcgxssorjwiinpknr.supabase.co/functions/v1/report-generator';
  static const _authToken =
      'Bearer 65d9708252d6947d42e757bc7558acce87b52c2067ef5663e1dc0b29843b1e2a';

  // ********** Public actions (unchanged UI) **********

  Future<void> _generateReport(String returnType) async {
    setState(() {
      _isLoading = true;
      _selectedFormat = returnType;
      _generatedContent = null;
      _generatedFile = null;
    });

    try {
      final response = await http.post(
        Uri.parse(_serverUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': _authToken,
        },
        body: json.encode({
          'event_id': widget.eventId,
          'return_type': returnType,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to generate report: ${response.statusCode}');
      }

      // Branch by return type
      if (returnType == 'html' || returnType == 'txt') {
        // keep content
        setState(() {
          _generatedContent = response.body;
        });
      } else if (returnType == 'xlsx') {
        // bytes -> file
        final out = await getTemporaryDirectory();
        final fname = 'final_moi_report_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        final file = File('${out.path}/$fname');
        await file.writeAsBytes(response.bodyBytes);
        setState(() => _generatedFile = file);
      } else if (returnType == 'pdf') {
        // server returned PDF bytes. We'll store bytes in _generatedContent as base64 string
        final base64Pdf = base64Encode(response.bodyBytes);
        setState(() {
          _generatedContent = base64Pdf; // store pdf as base64 to indicate PDF bytes present
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ********** Print / Share logic with merging **********

  Future<void> _printReport() async {
    try {
      setState(() => _isLoading = true);

      if (_selectedFormat == 'html' && _generatedContent != null) {
        final html = _generatedContent!;
        final mergedPdfBytes = await _createMergedPdfForHtml(html);
        if (mergedPdfBytes != null) {
          await Printing.layoutPdf(onLayout: (format) => mergedPdfBytes);
        } else {
          throw Exception('Failed to create merged PDF from HTML');
        }
      } else if (_selectedFormat == 'txt' && _generatedContent != null) {
        final pdfBytes = await _convertTextToPdf(_generatedContent!);
        await Printing.layoutPdf(onLayout: (format) => pdfBytes);
      } else if (_selectedFormat == 'xlsx') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please share/open the Excel file to print from a spreadsheet app'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else if (_selectedFormat == 'pdf' && _generatedContent != null) {
        // _generatedContent is base64 PDF from server
        final serverPdfBytes = base64Decode(_generatedContent!);
        final mergedPdfBytes = await _createMergedPdfWithImageFirst(serverPdfBytes);
        if (mergedPdfBytes != null) {
          await Printing.layoutPdf(onLayout: (format) => mergedPdfBytes);
        } else {
          // fallback: print server PDF as-is
          await Printing.layoutPdf(onLayout: (format) => serverPdfBytes);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _shareReport() async {
    try {
      setState(() => _isLoading = true);

      if (_selectedFormat == 'xlsx' && _generatedFile != null) {
        await Share.shareXFiles(
          [XFile(_generatedFile!.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', name: 'final_moi_report.xlsx')],
          text: 'Final Moi Report',
        );
      } else if (_selectedFormat == 'pdf' && _generatedContent != null) {
        final serverPdfBytes = base64Decode(_generatedContent!);
        final mergedPdfBytes = await _createMergedPdfWithImageFirst(serverPdfBytes);
        final output = await getTemporaryDirectory();
        final outPath = '${output.path}/final_moi_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final outFile = File(outPath);
        if (mergedPdfBytes != null) {
          await outFile.writeAsBytes(mergedPdfBytes);
        } else {
          // fallback to original server PDF
          await outFile.writeAsBytes(serverPdfBytes);
        }
        await Share.shareXFiles([XFile(outFile.path, mimeType: 'application/pdf', name: 'final_moi_report.pdf')], text: 'Final Moi Report');
      } else if (_selectedFormat == 'html' && _generatedContent != null) {
        final html = _generatedContent!;
        final mergedHtml = await _createMergedHtmlWithImageFirst(html);
        final output = await getTemporaryDirectory();
        final outPath = '${output.path}/final_moi_report_${DateTime.now().millisecondsSinceEpoch}.html';
        final file = File(outPath);
        await file.writeAsString(mergedHtml, flush: true);
        await Share.shareXFiles([XFile(file.path, mimeType: 'text/html', name: 'final_moi_report.html')], text: 'Final Moi Report');
      } else if (_selectedFormat == 'txt' && _generatedContent != null) {
        final output = await getTemporaryDirectory();
        final outPath = '${output.path}/final_moi_report_${DateTime.now().millisecondsSinceEpoch}.txt';
        final file = File(outPath);
        await file.writeAsString(_generatedContent!);
        await Share.shareXFiles([XFile(file.path, mimeType: 'text/plain', name: 'final_moi_report.txt')], text: 'Final Moi Report');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ********** Helpers: create edited image and merging **********

  /// Draws text over the asset background image and returns PNG bytes.
  /// Uses Flutter Canvas/TextPainter to ensure consistent fonts and rendering on devices.
  /// Draws text over the asset background image and returns PNG bytes.
  /// Uses Flutter Canvas/TextPainter to ensure consistent fonts and rendering on devices.
  Future<Uint8List> _createReceiptPngBytes(Map<String, String> fields) async {
    // Load the image bytes
    final byteData = await rootBundle.load('assets/images/receipt_bg.png');
    final Uint8List imgBytes = byteData.buffer.asUint8List();

    // Decode to ui.Image
    final codec = await ui.instantiateImageCodec(imgBytes);
    final frame = await codec.getNextFrame();
    final ui.Image background = frame.image;

    final int width = background.width;
    final int height = background.height;

    // Create a picture recorder and canvas
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw the background image first
    canvas.drawImage(background, Offset.zero, Paint());

    // Helper function to draw text with proper styling
    void drawText(
        String text,
        double x,
        double y,
        double fontSize, {
          TextAlign align = TextAlign.left,
          FontWeight fontWeight = FontWeight.normal,
          Color color = Colors.black,
        }) {
      final textStyle = TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontFamily: 'NotoSerifTamil',
      );

      final textSpan = TextSpan(text: text, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textAlign: align,
        textDirection: TextDirection.ltr,
      );

      textPainter.layout(minWidth: 0, maxWidth: width.toDouble() - 40);

      double xPos = x;
      if (align == TextAlign.center) {
        xPos = (width - textPainter.width) / 2;
      } else if (align == TextAlign.right) {
        xPos = width - textPainter.width - x;
      }

      textPainter.paint(canvas, Offset(xPos, y));
    }

    // Calculate font sizes
    final titleFontSize = (width / 8).clamp(60.0, 120.0);
    final textFontSize = (width / 10).clamp(50.0, 100.0);
    final lineHeight = (height * 0.10).clamp(60.0, 120.0); // Increased spacing even more

    // Event Type Title (positioned around 38% from top, below Ganesha)
    final title = fields['Event Type'] ?? 'Final MOI Report';
    drawText(
      title,
      0,
      height * 0.38,
      titleFontSize,
      align: TextAlign.center,
      fontWeight: FontWeight.bold,
      color: const Color(0xFF8B0000), // Dark red
    );

    // Start customer details section
    double cursorY = height * 0.46;

    // Customer Name
    final customerName = fields['Customer Name'] ?? '';
    if (customerName.isNotEmpty) {
      drawText(
        customerName,
        0,
        cursorY,
        textFontSize,
        align: TextAlign.center,
        fontWeight: FontWeight.bold,
        color: const Color(0xFFFF0000), // Red
      );
      cursorY += lineHeight * 1.8; // More space after customer name
    }

    // Event For (if provided)
    final eventFor = fields['Event For'] ?? '';
    if (eventFor.isNotEmpty) {
      drawText(
        eventFor,
        0,
        cursorY,
        textFontSize,
        align: TextAlign.center,
        fontWeight: FontWeight.bold,
        color: const Color(0xFFFF0000), // Red
      );
      cursorY += lineHeight * 1.8; // More space after event for
    }

    // House Warming label (if applicable based on event type)
    if (title.toLowerCase().contains('house') || title.toLowerCase().contains('warming')) {
      drawText(
        'இல்ல காதணி விழா',
        0,
        cursorY,
        textFontSize * 0.95,
        align: TextAlign.center,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF0000FF), // Blue
      );
      cursorY += lineHeight * 1.8; // More space
    }

    // Date (நாள்:) with Tamil day
    final eventDate = fields['Event Date'] ?? '';
    final tamilDay = fields['Tamil Day'] ?? '';
    if (eventDate.isNotEmpty) {
      String dateText = 'நாள் : $eventDate';
      if (tamilDay.isNotEmpty) {
        dateText += ', $tamilDay';
      }

      drawText(
        dateText,
        0,
        cursorY,
        textFontSize * 0.95,
        align: TextAlign.center,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF008000), // Green
      );
      cursorY += lineHeight * 1.8; // More space after date
    }

    // Venue and City (இடம்:)
    final venue = fields['Venue'] ?? '';
    final city = fields['City'] ?? '';
    if (venue.isNotEmpty || city.isNotEmpty) {
      final venueText = venue.isNotEmpty && city.isNotEmpty
          ? 'இடம் : $venue, $city'
          : 'இடம் : ${venue.isNotEmpty ? venue : city}';

      drawText(
        venueText,
        0,
        cursorY,
        textFontSize * 0.9,
        align: TextAlign.center,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF0000FF), // Blue
      );
    }

    // Convert to image
    final picture = recorder.endRecording();
    final img = await picture.toImage(width, height);
    final byteData2 = await img.toByteData(format: ui.ImageByteFormat.png);

    if (byteData2 == null) {
      throw Exception('Failed to convert edited receipt to PNG bytes');
    }

    return byteData2.buffer.asUint8List();
  }

  /// Create a merged PDF where the first page is the edited image and the rest are pages from `serverPdfBytes`.
  /// Uses Syncfusion Pdf for reliable merging.
  Future<Uint8List?> _createMergedPdfWithImageFirst(Uint8List serverPdfBytes) async {
    try {
      // Fields to render on receipt
      // Fetch event details from your database first
// You'll need to add a method to fetch event data
      final eventData = await _fetchEventDetails(widget.eventId);

// Fields to render on receipt
      final fields = <String, String>{
        'Event Type': eventData['event_type'] ?? '',
        'Customer Name': eventData['customer_name'] ?? '',
        'Event For': eventData['event_for'] ?? '',
        'Event Date': eventData['event_date'] ?? '',
        'Venue': eventData['venue'] ?? '',
        'City': eventData['city'] ?? '',
      };

      // create PNG bytes of the receipt with overlay
      final pngBytes = await _createReceiptPngBytes(fields);

      // Create merged PDF with Syncfusion
      final PdfDocument mergedDocument = PdfDocument();
      // Add first page and draw the PNG (fit to page)
      final PdfPage firstPage = mergedDocument.pages.add();
      final PdfGraphics g = firstPage.graphics;

      final PdfBitmap bitmap = PdfBitmap(pngBytes);
      // Fit the image to the page while preserving aspect ratio
      final Size pageSize = firstPage.getClientSize();
      final double imgRatio = bitmap.width / bitmap.height;
      final double pageRatio = pageSize.width / pageSize.height;
      double drawWidth = pageSize.width;
      double drawHeight = pageSize.height;
      if (imgRatio > pageRatio) {
        drawWidth = pageSize.width;
        drawHeight = drawWidth / imgRatio;
      } else {
        drawHeight = pageSize.height;
        drawWidth = drawHeight * imgRatio;
      }
      final double left = (pageSize.width - drawWidth) / 2;
      final double top = (pageSize.height - drawHeight) / 2;
      g.drawImage(bitmap, Rect.fromLTWH(left, top, drawWidth, drawHeight));

      // Load server PDF
      final PdfDocument serverDoc = PdfDocument(inputBytes: serverPdfBytes);

      // Append all pages from serverDoc to mergedDocument using PdfDocumentPageCollection.addAll
      // This is the correct way to merge pages in syncfusion_flutter_pdf
      for (int i = 0; i < serverDoc.pages.count; i++) {
        final PdfPage sourcePage = serverDoc.pages[i];
        final PdfPage newPage = mergedDocument.pages.add();

        // Copy page content by drawing the template
        final template = sourcePage.createTemplate();
        newPage.graphics.drawPdfTemplate(template, Offset.zero, sourcePage.size);
      }

      // Save - note: save() returns List<int> synchronously, not Future
      final List<int> bytes = mergedDocument.saveSync();
      mergedDocument.dispose();
      serverDoc.dispose();
      return Uint8List.fromList(bytes);
    } catch (e) {
      if (kDebugMode) print('Error merging PDF: $e');
      return null;
    }
  }

  /// Create a PDF from an HTML string by first creating an image page (receipt),
  /// and then rendering the HTML to PDF and appending.
  Future<Uint8List?> _createMergedPdfForHtml(String htmlContent) async {
    try {
      // 1) Create receipt PNG (we will embed it as first page)
      // Fetch event details from your database first
// You'll need to add a method to fetch event data
      final eventData = await _fetchEventDetails(widget.eventId);

// Fields to render on receipt
      final fields = <String, String>{
        'Event Type': eventData['event_type'] ?? '',
        'Customer Name': eventData['customer_name'] ?? '',
        'Event For': eventData['event_for'] ?? '',
        'Event Date': eventData['event_date'] ?? '',
        'Venue': eventData['venue'] ?? '',
        'City': eventData['city'] ?? '',
      };
      final pngBytes = await _createReceiptPngBytes(fields);

      // 2) Convert HTML to PDF bytes using Printing.convertHtml (uses PdfPageFormat from package:pdf)
      Uint8List? htmlPdfBytes;
      try {
        htmlPdfBytes = await Printing.convertHtml(
          format: pdf_pkg.PdfPageFormat.a4,
          html: htmlContent,
        );
      } catch (e) {
        if (kDebugMode) print('Printing.convertHtml failed: $e - falling back to text PDF');
        // fallback: plain text PDF
        htmlPdfBytes = await _convertTextToPdf(htmlContent);
      }

      if (htmlPdfBytes == null) {
        throw Exception('Failed to convert HTML to PDF');
      }

      // 3) Merge: create merged doc with png first + htmlPdfBytes pages
      return await _createMergedPdfWithImageFirst(htmlPdfBytes);
    } catch (e) {
      if (kDebugMode) print('Error creating merged PDF for HTML: $e');
      return null;
    }
  }


  Future<Map<String, String>> _fetchEventDetails(String eventId) async {
    try {
      final response = await Supabase.instance.client
          .from('events')
          .select('*, event_types(name)')
          .eq('id', eventId)
          .single();

      return {
        'event_type': response['event_types']?['name'] ?? '',
        'customer_name': response['customer_name'] ?? '',
        'event_for': response['event_for'] ?? '',
        'event_date': response['event_date'] ?? '',
        'venue': response['venue'] ?? '',
        'city': response['city'] ?? '',
      };
    } catch (e) {
      if (kDebugMode) print('Error fetching event details: $e');
      return {};
    }
  }
  /// Produces merged HTML where the first element is the receipt PNG (base64).
  Future<String> _createMergedHtmlWithImageFirst(String serverHtml) async {
    // Fetch event details from your database first
// You'll need to add a method to fetch event data
    final eventData = await _fetchEventDetails(widget.eventId);

// Fields to render on receipt
    final fields = <String, String>{
      'Event Type': eventData['event_type'] ?? '',
      'Customer Name': eventData['customer_name'] ?? '',
      'Event For': eventData['event_for'] ?? '',
      'Event Date': eventData['event_date'] ?? '',
      'Venue': eventData['venue'] ?? '',
      'City': eventData['city'] ?? '',
    };
    final pngBytes = await _createReceiptPngBytes(fields);
    final base64Image = base64Encode(pngBytes);
    final imgTag =
        '<div style="text-align:center; page-break-after:always;"><img src="data:image/png;base64,$base64Image" style="max-width:100%; height:auto;" /></div>';

    // Insert the image at the top of body if possible, otherwise prepend
    if (serverHtml.contains('<body')) {
      final updated = serverHtml.replaceFirstMapped(
        RegExp(r'(<body[^>]*>)', caseSensitive: false),
            (match) => '${match.group(1)}$imgTag',
      );
      return updated;
    } else {
      return imgTag + serverHtml;
    }
  }

  /// Convert plain text to PDF bytes using Syncfusion
  Future<Uint8List> _convertTextToPdf(String textContent) async {
    final PdfDocument document = PdfDocument();
    final PdfPage page = document.pages.add();
    page.graphics.drawString(
      textContent,
      PdfStandardFont(PdfFontFamily.helvetica, 12),
      bounds: Rect.fromLTWH(0, 0, page.getClientSize().width, page.getClientSize().height),
    );
    final List<int> bytes = document.saveSync();
    document.dispose();
    return Uint8List.fromList(bytes);
  }

  // ********** UI copy from your original, unchanged UX **********

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
        initialSettings: InAppWebViewSettings(javaScriptEnabled: true),
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
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
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