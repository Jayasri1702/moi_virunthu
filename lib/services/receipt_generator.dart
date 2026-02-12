import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

class ReceiptGenerator {
  // Cache for base64 logo
  static String? _cachedLogoBase64;

  // Cache for base64 font
  static String? _cachedFontBase64;

  // Load and cache logo as base64
  static Future<String> _getLogoBase64() async {
    if (_cachedLogoBase64 != null) {
      return _cachedLogoBase64!;
    }

    try {
      final ByteData data = await rootBundle.load('assets/images/money_transfer.png');
      final List<int> bytes = data.buffer.asUint8List();
      _cachedLogoBase64 = base64Encode(bytes);
      return _cachedLogoBase64!;
    } catch (e) {
      print('Error loading logo: $e');
      return '';
    }
  }

  // Load and cache font as base64
  static Future<String> _getFontBase64() async {
    if (_cachedFontBase64 != null) {
      return _cachedFontBase64!;
    }

    try {
      final ByteData data = await rootBundle.load('assets/fonts/ALTRONED_Trial.ttf');
      final List<int> bytes = data.buffer.asUint8List();
      _cachedFontBase64 = base64Encode(bytes);
      return _cachedFontBase64!;
    } catch (e) {
      print('Error loading font: $e');
      return '';
    }
  }

  // Add this method after generateReceiptPDFWithImage (around line 150)

  static Future<Map<String, dynamic>?> generateReceiptPDFWithImage({
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
      final logoBase64 = await _getLogoBase64();
      final fontBase64 = await _getFontBase64();

      final htmlContent = _generateHtmlContent(
        customerName: customerName,
        venue: venue,
        city: city,
        contactNumber: contactNumber,
        eventTypeName: eventTypeName,
        selectedDate: selectedDate,
        selectedTime: selectedTime,
        logoBase64: logoBase64,
        fontBase64: fontBase64,
      );

      final output = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'event_receipt.pdf';
      final filePath = '${output.path}/$fileName';

      File? generatedFile;
      Uint8List? screenshotBytes;
      bool pdfGenerated = false;

      HeadlessInAppWebView? headlessWebView;

      headlessWebView = HeadlessInAppWebView(
        initialData: InAppWebViewInitialData(data: htmlContent),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          useHybridComposition: true,
        ),
        initialSize: Size(302, 800),
        onLoadStop: (controller, url) async {
          try {
            await Future.delayed(const Duration(milliseconds: 1500));

            final contentHeight = await controller.evaluateJavascript(
                source: "document.body.scrollHeight"
            );

            int height = 800;
            if (contentHeight != null) {
              height = int.tryParse(contentHeight.toString()) ?? 800;
            }

            await headlessWebView?.setSize(Size(302, height.toDouble()));
            await Future.delayed(const Duration(milliseconds: 500));

            final screenshot = await controller.takeScreenshot();

            if (screenshot != null) {
              // ✅ Save screenshot bytes for thermal printer
              screenshotBytes = screenshot;

              final pdf = pw.Document();
              final image = pw.MemoryImage(screenshot);

              final pdfWidth = 80 * PdfPageFormat.mm;
              final pdfHeight = (height / 302) * pdfWidth;

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
              print('Event receipt generated: PDF + Image');
            }
          } catch (e) {
            print('Error generating event receipt: $e');
          } finally {
            if (headlessWebView != null) {
              await headlessWebView.dispose();
            }
          }
        },
      );

      await headlessWebView.run();

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

      // ✅ Return both PDF file and screenshot bytes
      if (generatedFile != null && screenshotBytes != null) {
        return {
          'pdf': generatedFile,
          'imageBytes': screenshotBytes,
        };
      }

      return null;
    } catch (e) {
      print('Error in generateReceiptPDFWithImage: $e');
      return null;
    }
  }

  // ✅ Keep the old method for backward compatibility
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
      final logoBase64 = await _getLogoBase64();
      final fontBase64 = await _getFontBase64();

      final htmlContent = _generateHtmlContent(
        customerName: customerName,
        venue: venue,
        city: city,
        contactNumber: contactNumber,
        eventTypeName: eventTypeName,
        selectedDate: selectedDate,
        selectedTime: selectedTime,
        logoBase64: logoBase64,
        fontBase64: fontBase64,
      );

      final output = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'event_receipt.pdf';
      final filePath = '${output.path}/$fileName';

      File? generatedFile;
      bool pdfGenerated = false;

      HeadlessInAppWebView? headlessWebView;

      headlessWebView = HeadlessInAppWebView(
        initialData: InAppWebViewInitialData(data: htmlContent),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          useHybridComposition: true,
        ),
        initialSize: Size(302, 800),
        onLoadStop: (controller, url) async {
          try {
            await Future.delayed(const Duration(milliseconds: 1500));

            final contentHeight = await controller.evaluateJavascript(
                source: "document.body.scrollHeight"
            );

            int height = 800;
            if (contentHeight != null) {
              height = int.tryParse(contentHeight.toString()) ?? 800;
            }

            await headlessWebView?.setSize(Size(302, height.toDouble()));
            await Future.delayed(const Duration(milliseconds: 500));

            final screenshot = await controller.takeScreenshot();

            if (screenshot != null) {
              final pdf = pw.Document();
              final image = pw.MemoryImage(screenshot);

              final pdfWidth = 80 * PdfPageFormat.mm;
              final pdfHeight = (height / 302) * pdfWidth;

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

      await headlessWebView.run();

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

  // ✅ UPDATED: HTML template matching MOI style
  static String _generateHtmlContent({
    required String customerName,
    required String venue,
    required String city,
    required String contactNumber,
    required String eventTypeName,
    required DateTime selectedDate,
    required TimeOfDay? selectedTime,
    required String logoBase64,
    required String fontBase64,
  }) {
    final receiptNo = '00';

    // ✅ Use current date/time
    final now = DateTime.now();
    final dateStr = DateFormat('dd-MM-yyyy').format(now);
    final timeStr = DateFormat('hh.mm a').format(now);

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link href="https://fonts.googleapis.com/css2?family=Noto+Sans+Tamil:wght@400;700&display=swap" rel="stylesheet">
  <style>
  @font-face {
    font-family: 'Altroned';
    src: url(data:font/truetype;charset=utf-8;base64,$fontBase64) format('truetype');
  }

  * {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
  }
  
  body {
    font-family: 'Noto Sans Tamil', sans-serif;
    width: 302px;
    padding: 0;
    text-align: center;
    background: white;
    font-weight: 700;
    overflow: hidden;
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
    text-rendering: optimizeLegibility;
  }
  
  .outer-box {
    border: 3px solid black;
    padding: 0;
    margin: 0;
    box-sizing: border-box;
    background: white;
    position: relative;
  }
  
  .logo-header {
    display: flex;
    align-items: center;
    padding: 8px;
    gap: 10px;
  }

  .logo {
    width: 85px;
    height: 85px;
    object-fit: contain;
  }

  .company-info {
    width: 100%;
    text-align: center;
  }

  .company-name {
    font-family: 'Altroned', sans-serif;
    font-size: 22px;
    font-weight: 700;
    color: #000;
    margin-bottom: 3px;
  }

  .tamil-heading {
    font-size: 17px;
    font-weight: 700;
    color: #000;
    margin-bottom: 4px;
  }

  .company-phone {
    font-size: 16px;
    font-weight: 700;
    color: #000;
  }
  
  .divider {
    border-top: 2px solid black;
    margin: 0;
    padding: 0;
    box-sizing: border-box;
    height: 0;
    width: 100%;
    overflow: hidden;
  }
  
  .date-time-row {
    display: flex;
    justify-content: space-between;
    font-size: 14px;
    font-weight: 700;
    border-bottom: 2px solid black;
    box-sizing: border-box;
  }

  .left-section {
    text-align: left;
    padding: 8px;
    flex: 1;
    border-right: 2px solid black;
    box-sizing: border-box;
    font-weight: 700;
  }

  .right-section {
    text-align: right;
    padding: 8px;
    flex: 1;
    font-weight: 700;
  }
  
  .content-section {
    padding: 12px;
    text-align: center;
  }
  
  .receipt-no {
    font-size: 16px;
    font-weight: 700;
    margin: 8px 0;
  }
  
  .customer-name {
    font-size: 18px;
    font-weight: 700;
    margin: 6px 0;
  }
  
  .venue {
    font-size: 16px;
    font-weight: 700;
    margin: 6px 0;
  }
  
  .event-type {
    font-size: 20px;
    font-weight: 700;
    margin: 6px 0;
  }
  
  .category {
    font-size: 18px;
    font-weight: 700;
    margin: 6px 0;
  }
  
  .footer {
    margin-top: 0;
    padding-top: 8px;
    font-size: 14px;
    font-weight: 700;
  }
  
  .thanks {
    margin: 6px 0;
    font-weight: 700;
  }
  
  .with-love {
    font-size: 12px;
    font-weight: 700;
    margin: 4px 0;
  }
  
  .footer-name {
    font-size: 15px;
    font-weight: 700;
    margin: 6px 0;
    word-wrap: break-word;
    line-height: 1.3;
  }
  
  .footer-city {
    font-size: 14px;
    font-weight: 700;
    margin: 4px 0;
    word-wrap: break-word;
    line-height: 1.3;
  }
  
  .footer-phone {
    font-size: 14px;
    font-weight: 700;
    margin: 6px 0;
  }
  
  .village-info {
  font-size: 14px;
  font-weight: 700;
  margin: 4px 0;
  word-wrap: break-word;
  line-height: 1.3;
}

.footer-name {
  font-size: 15px;
  font-weight: 700;
  margin: 6px 0;
  word-wrap: break-word;
  line-height: 1.3;
}

.phone {
  font-size: 14px;
  font-weight: 700;
  margin: 6px 0;
}
  </style>
</head>
<body>
  <div class="outer-box">
    <div class="logo-header">
      <img src="data:image/png;base64,$logoBase64" alt="Logo" class="logo">
      <div class="company-info">
        <div class="company-name">Hi Tech Moi</div>
        <div class="tamil-heading">ஹை-டெக் மொய்</div>
        <div class="company-phone">9043606296,9047556443</div>
      </div>
    </div>
    
    <div class="divider"></div>
    
    <div class="date-time-row">
      <div class="left-section">
        <div>$dateStr</div>
        <div>$timeStr</div>
      </div>
      <div class="right-section">
        <div>Typer</div>
        <div>Admin</div>
      </div>
    </div>
    
    <div class="content-section">
      <div class="receipt-no">வ.எண் : $receiptNo</div>
      <div class="customer-name">$customerName</div>
      ${venue.isNotEmpty ? '<div class="venue">$venue</div>' : ''}
      <div class="event-type">$eventTypeName</div>
      <div class="category">ரூ.1</div>
    </div>
    
    <div class="divider"></div>
    
    <div class="footer">
  <div class="thanks">தங்கள் வருகைக்கு நன்றி!</div>
  <div class="with-love">அன்புடன்</div>
  ${customerName.isNotEmpty ? '<div class="footer-name">$customerName</div>' : ''}
  ${eventTypeName.isNotEmpty ? '<div class="footer-name">$eventTypeName</div>' : ''}
  ${venue.isNotEmpty ? '<div class="village-info">$venue</div>' : ''}
  ${city.isNotEmpty ? '<div class="village-info">$city</div>' : ''}
  ${contactNumber.isNotEmpty ? '<div class="phone">$contactNumber</div>' : ''}
</div>
  </div>
</body>
</html>
''';
  }
}