import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

class ReceiptGenerator {
  static Future<File?> generateReceiptPDF({
    required BuildContext context,
    required String customerName,
    required String venue,
    required String city,
    required String contactNumber,
    required String eventTypeName,
    required DateTime selectedDate,
    required TimeOfDay? selectedTime,
  }) async {
    try {
      // Create HTML content
      final htmlContent = _generateHtmlContent(
        customerName: customerName,
        venue: venue,
        city: city,
        contactNumber: contactNumber,
        eventTypeName: eventTypeName,
        selectedDate: selectedDate,
        selectedTime: selectedTime,
      );

      // Get temporary directory
      final output = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'receipt_${customerName.replaceAll(' ', '_')}_$timestamp.pdf';
      final filePath = '${output.path}/$fileName';

      File? generatedFile;
      bool pdfGenerated = false;

      // Create headless WebView to generate PDF
      HeadlessInAppWebView? headlessWebView;

      headlessWebView = HeadlessInAppWebView(
        initialData: InAppWebViewInitialData(data: htmlContent),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          useHybridComposition: true,
        ),
        onLoadStop: (controller, url) async {
          try {
            // Wait for fonts to load
            await Future.delayed(const Duration(milliseconds: 1500));

            // Take a screenshot of the rendered HTML
            final screenshot = await controller.takeScreenshot();

            if (screenshot != null) {
              // Create PDF from screenshot
              final pdf = pw.Document();

              final image = pw.MemoryImage(screenshot);

              pdf.addPage(
                pw.Page(
                  pageFormat: PdfPageFormat(
                    80 * PdfPageFormat.mm, // 80mm width
                    297 * PdfPageFormat.mm, // Auto height
                    marginAll: 0,
                  ),
                  build: (pw.Context context) {
                    return pw.Center(
                      child: pw.Image(image, fit: pw.BoxFit.contain),
                    );
                  },
                ),
              );

              // Save to file
              final file = File(filePath);
              await file.writeAsBytes(await pdf.save());
              generatedFile = file;
              pdfGenerated = true;
              print('PDF generated successfully at: $filePath');
            }
          } catch (e) {
            print('Error generating PDF: $e');
          } finally {
            // Dispose the headless WebView
            if (headlessWebView != null) {
              await headlessWebView.dispose();
            }
          }
        },
        onConsoleMessage: (controller, consoleMessage) {
          print('WebView Console: ${consoleMessage.message}');
        },
      );

      // Start the headless WebView
      await headlessWebView.run();

      // Wait for PDF generation (with timeout)
      int attempts = 0;
      while (attempts < 30 && !pdfGenerated) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (pdfGenerated) {
          final file = File(filePath);
          if (await file.exists() && await file.length() > 0) {
            generatedFile = file;
            break;
          }
        }
        attempts++;
      }

      return generatedFile;
    } catch (e) {
      print('Error in generateReceiptPDF: $e');
      return null;
    }
  }

  static String _generateHtmlContent({
    required String customerName,
    required String venue,
    required String city,
    required String contactNumber,
    required String eventTypeName,
    required DateTime selectedDate,
    required TimeOfDay? selectedTime,
  }) {
    final receiptNo = '00';
    final dateStr = DateFormat('dd-MM-yyyy').format(selectedDate);
    final timeStr = selectedTime != null
        ? '${selectedTime.hour.toString().padLeft(2, '0')}.${selectedTime.minute.toString().padLeft(2, '0')} ${selectedTime.hour < 12 ? 'am' : 'pm'}'
        : '10.30 am';

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link href="https://fonts.googleapis.com/css2?family=Noto+Sans+Tamil:wght@400;700&display=swap" rel="stylesheet">
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    
    body {
      font-family: 'Noto Sans Tamil', sans-serif;
      width: 302px;
      padding: 10px;
      text-align: center;
      background: white;
    }
    
    .header {
      font-size: 24px;
      font-weight: bold;
      margin-bottom: 10px;
      color: #000;
    }
    
    .divider {
      border-top: 2px solid black;
      margin: 10px 0;
    }
    
    .date-time-row {
      display: flex;
      justify-content: space-between;
      margin: 10px 0;
      font-size: 14px;
    }
    
    .left-section {
      text-align: left;
    }
    
    .right-section {
      text-align: right;
      font-weight: bold;
    }
    
    .receipt-no {
      font-size: 16px;
      font-weight: bold;
      margin: 8px 0;
    }
    
    .customer-name {
      font-size: 18px;
      font-weight: bold;
      margin: 8px 0;
    }
    
    .venue {
      font-size: 16px;
      margin: 6px 0;
    }
    
    .event-type {
      font-size: 20px;
      font-weight: bold;
      margin: 10px 0;
    }
    
    .footer {
      margin-top: 15px;
      font-size: 16px;
    }
    
    .thanks {
      margin: 8px 0;
    }
    
    .with-love {
      font-size: 14px;
      margin: 6px 0;
    }
    
    .phone {
      font-size: 16px;
      margin: 4px 0;
    }
  </style>
</head>
<body>
  <div class="header">ஹைடெக் மொய்</div>
  
  <div class="divider"></div>
  
  <div class="date-time-row">
    <div class="left-section">
      <div>$dateStr</div>
      <div>$timeStr</div>
    </div>
    <div class="right-section">
      <div>Admin</div>
    </div>
  </div>
  
  <div class="receipt-no">வ.எண் : $receiptNo</div>
  
  <div class="customer-name">$customerName</div>
  
  <div class="venue">${venue.isNotEmpty ? venue : 'தொழை'}</div>
  
  <div class="event-type">$eventTypeName</div>
  
  <div class="divider"></div>
  
  <div class="footer">
    <div class="thanks">தங்கள் வருகைக்கு நன்றி!</div>
    <div class="with-love">அன்புடன்</div>
    <div class="customer-name">$customerName</div>
    <div class="venue">$city</div>
    <div class="phone">$contactNumber</div>
  </div>
</body>
</html>
''';
  }
}