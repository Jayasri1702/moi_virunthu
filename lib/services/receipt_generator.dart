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
        initialSize: Size(302, 800), // Set initial size to match your content width
        onLoadStop: (controller, url) async {
          try {
            await Future.delayed(const Duration(milliseconds: 1500));

            // Get the actual content height
            final contentHeight = await controller.evaluateJavascript(
                source: "document.body.scrollHeight"
            );

            int height = 800; // default
            if (contentHeight != null) {
              height = int.tryParse(contentHeight.toString()) ?? 800;
            }

            // Resize to actual content
            await headlessWebView?.setSize(Size(302, height.toDouble()));
            await Future.delayed(const Duration(milliseconds: 500));

            final screenshot = await controller.takeScreenshot();

            if (screenshot != null) {
              final pdf = pw.Document();
              final image = pw.MemoryImage(screenshot);

              // Calculate PDF height based on content
              final pdfWidth = 80 * PdfPageFormat.mm;
              final pdfHeight = (height / 302) * pdfWidth; // Maintain aspect ratio

              pdf.addPage(
                pw.Page(
                  pageFormat: PdfPageFormat(pdfWidth, pdfHeight, marginAll: 0),
                  build: (pw.Context context) {
                    return pw.Image(image, fit: pw.BoxFit.fill);
                  },
                ),
              );

              final file = File(filePath);
              await file.writeAsBytes(await pdf.save());
              generatedFile = file;
              pdfGenerated = true;
              print('PDF generated successfully at: $filePath');
            }
          } catch (e) {
            print('Error generating PDF: $e');
          } finally {
            if (headlessWebView != null) {
              await headlessWebView.dispose();
            }
          }
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
    padding: 6px;
    background: white;
  }
  
  .outer-box {
    border: 3px solid black;
    padding: 0;
  }
  
  
  .company-name {
    font-size: 20px;
    font-weight: bold;
    color: #000;
    text-align: center;
  }
  
  .phone-numbers {
    font-size: 14px;
    margin-top: 2px;
  }
  
  .date-time-section {
    display: flex;
    border-bottom: 2px solid black;
  }
  
  .date-time-left {
    flex: 1;
    padding: 8px;
    text-align: center;
    border-right: 2px solid black;
    font-size: 16px;
    font-weight: bold;
  }
  
  .date-time-right {
    flex: 1;
    padding: 8px;
    text-align: center;
    font-size: 14px;
  }
  
  .typer-label {
    font-size: 12px;
    margin-bottom: 2px;
  }
  
  .typer-name {
    font-size: 16px;
    font-weight: bold;
  }
  
  .content-section {
    padding: 12px;
    text-align: center;
    border-bottom: 2px solid black;
  }
  
  .receipt-no {
    font-size: 16px;
    font-weight: bold;
    margin-bottom: 8px;
  }
  
  .customer-name {
    font-size: 18px;
    font-weight: bold;
    margin-bottom: 6px;
  }
  
  .venue {
    font-size: 16px;
    margin-bottom: 6px;
  }
  
  .event-type {
    font-size: 20px;
    font-weight: bold;
    margin-bottom: 4px;
  }
  
  .category {
    font-size: 18px;
    font-weight: bold;
  }
  
  .footer-section {
    padding: 12px;
    text-align: center;
  }
  
  .header {
      background-color: #1976D2;
      color: white;
      font-size: 18px;
      font-weight: bold;
      padding: 10px;
      margin-bottom: 10px;
      text-align: center;
    }
    
  .thanks {
    font-size: 16px;
    margin-bottom: 4px;
  }
  
  .with-love {
    font-size: 14px;
    margin-bottom: 8px;
  }
  
  .footer-name {
    font-size: 18px;
    font-weight: bold;
    margin-bottom: 4px;
  }
  
  .footer-city {
    font-size: 16px;
    margin-bottom: 4px;
  }
  
  .footer-phone {
    font-size: 16px;
  }
</style>
</head>
<body>
<div class="header">Sample Event Receipt</div>

  <div class="outer-box">
    
      <div class="company-name">Hi Tech Moi</div>
    </div>
    
    <div class="date-time-section">
      <div class="date-time-left">
        <div>$dateStr</div>
        <div>$timeStr</div>
      </div>
      <div class="date-time-right">
        <div class="typer-label">Typer</div>
        <div class="typer-name">Admin</div>
      </div>
    </div>
    
    <div class="content-section">
      <div class="receipt-no">வ.எண் : $receiptNo</div>
      <div class="customer-name">$customerName</div>
      <div class="venue">${venue.isNotEmpty ? venue : 'தொழை'}</div>
      <div class="event-type">$eventTypeName</div>
      <div class="category">ரூ.1</div>
    </div>
    
    <div class="footer-section">
      <div class="thanks">தங்கள் வருகைக்கு நன்றி!</div>
      <div class="with-love">அன்புடன்...</div>
      <div class="footer-name">$customerName</div>
      <div class="footer-city">$city</div>
      <div class="footer-phone">$contactNumber</div>
    </div>
  </div>
</body>
</html>
''';
  }
}