import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

class BookingReceiptGenerator {
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

  static Future<File?> generateBookingReceipt({
    required BuildContext context,
    required String customerName,
    required String contactNumber,
    required String eventTypeName,
    required DateTime selectedDate,
    TimeOfDay? selectedTime,
    String? venue,
    required double bookedAmount,
    required double advanceAmount,
    required int totalComputers,  // ADD THIS PARAMETER
  }) async {
    try {
      final logoBase64 = await _getLogoBase64();
      final fontBase64 = await _getFontBase64();

      final balanceAmount = bookedAmount - advanceAmount;
      final htmlContent = _generateHtmlContent(
        customerName: customerName,
        contactNumber: contactNumber,
        eventTypeName: eventTypeName,
        selectedDate: selectedDate,
        selectedTime: selectedTime,
        venue: venue ?? '',
        bookedAmount: bookedAmount.toStringAsFixed(2),
        advanceAmount: advanceAmount.toStringAsFixed(2),
        balanceAmount: balanceAmount.toStringAsFixed(2),
        logoBase64: logoBase64,
        fontBase64: fontBase64,
        totalComputers: totalComputers.toString(),  // ADD THIS
      );

      final output = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'booking_receipt_${customerName.replaceAll(' ', '_')}_$timestamp.pdf';
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
        initialSize: Size(794, 1123), // A4 size in pixels at 96 DPI
        onLoadStop: (controller, url) async {
          try {
            await Future.delayed(const Duration(milliseconds: 1500));

            final contentHeight = await controller.evaluateJavascript(
                source: "document.body.scrollHeight"
            );

            int height = 1123;
            if (contentHeight != null) {
              height = int.tryParse(contentHeight.toString()) ?? 1123;
            }

            await headlessWebView?.setSize(Size(794, height.toDouble()));
            await Future.delayed(const Duration(milliseconds: 500));

            final screenshot = await controller.takeScreenshot();

            if (screenshot != null) {
              final pdf = pw.Document();
              final image = pw.MemoryImage(screenshot);

              pdf.addPage(
                pw.Page(
                  pageFormat: PdfPageFormat.a4,
                  margin: pw.EdgeInsets.zero,
                  build: (pw.Context context) {
                    return pw.Image(image, fit: pw.BoxFit.fill);
                  },
                ),
              );

              final file = File(filePath);
              await file.writeAsBytes(await pdf.save());
              generatedFile = file;
              pdfGenerated = true;
              print('Booking receipt generated successfully');
            }
          } catch (e) {
            print('Error generating booking receipt: $e');
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
      print('Error in generateBookingReceipt: $e');
      return null;
    }
  }

  static String _generateHtmlContent({
    required String customerName,
    required String contactNumber,
    required String eventTypeName,
    required DateTime selectedDate,
    TimeOfDay? selectedTime,
    required String venue,
    required String bookedAmount,
    required String advanceAmount,
    required String balanceAmount,
    required String logoBase64,
    required String fontBase64,
    required String totalComputers,  // ADD THIS
  }) {
    final dateStr = DateFormat('dd-MM-yyyy').format(selectedDate);
    final currentDate = DateFormat('dd-MM-yyyy').format(DateTime.now());

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
      font-family: 'Noto Sans Tamil', Arial, sans-serif;
      width: 794px;
      background: white;
      -webkit-font-smoothing: antialiased;
      -moz-osx-font-smoothing: grayscale;
    }
    
    .header {
      background: #0B6623;
      padding: 15px 20px;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 15px;
    }
    
    .logo {
      width: 90px;
      height: 90px;
      background: white;
      border-radius: 8px;
      display: flex;
      align-items: center;
      justify-content: center;
      overflow: hidden;
      flex-shrink: 0;
      padding: 8px;
    }
    
    .logo img {
      width: 100%;
      height: 100%;
      object-fit: contain;
    }
    
    .company-info {
      color: white;
      text-align: left;
    }
    
    .company-name {
      font-family: 'Altroned', sans-serif;
      font-size: 52px;
      font-weight: 700;
      margin-bottom: 6px;
      letter-spacing: 1.5px;
      line-height: 1;
    }
    
  .company-address {
      font-size: 18px;
      margin-bottom: 2px;
      font-weight: 700;
      line-height: 1.3;
    }
    
    .customer-section {
      padding: 12px 20px;
      background: white;
    }
    
    .customer-row {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  margin-bottom: 14px;
  font-size: 24px;  /* ✅ CHANGE from 22px to 24px */
  font-weight: bold;
}
    
    .customer-field {
      display: flex;
      align-items: baseline;
      gap: 10px;
    }
    
    .field-value {
      border-bottom: 2px solid black;
      min-width: 280px;
      display: inline-block;
      padding-bottom: 2px;
    }
    
   .booking-header {
      background: #0B6623;
      color: white;
      text-align: center;
      padding: 16px;
      font-size: 38px;
      font-weight: bold;
      letter-spacing: 1px;
    }
    
    .details-table {
      width: 100%;
      border-collapse: collapse;
    }
    
   .details-table td {
  border: 2px solid black;
  padding: 18px 20px;
  font-size: 20px;
  font-weight: normal;  
}

.details-table td:first-child {
  width: 280px;
  background: #f5f5f5;
}
    
    .footer-section {
      padding: 22px 25px;
      background: white;
    }
    
    .footer-title {
      font-size: 17px;
      font-weight: bold;
      margin-bottom: 12px;
    }
    
    .footer-list {
      margin-left: 0;
      padding-left: 20px;
      list-style-position: outside;
    }
    
    .footer-list li {
      font-size: 14px;
      line-height: 1.7;
      margin-bottom: 8px;
      padding-left: 5px;
    }
    
   .thank-you {
      text-align: center;
      font-size: 26px;
      font-weight: bold;
      margin-top: 22px;
      padding: 12px;
      letter-spacing: 0.5px;
    }

  </style>
</head>
<body>
  <div class="header">
    <div class="logo">
      <img src="data:image/png;base64,$logoBase64" alt="Logo">
    </div>
    <div class="company-info">
      <div class="company-name">Hi Tech Moi</div>
      <div class="company-address">Checkanurani, Madurai - 625 514.</div>
      <div class="company-address">Mobile: 9043606296, 9047556443</div>
    </div>
  </div>
  
  <div class="customer-section">
    <div class="customer-row">
      <div class="customer-field">
        <span>Customer Name :</span>
        <span class="field-value">$customerName</span>
      </div>
      <div>Date : $currentDate</div>
    </div>
    <div class="customer-row">
      <div class="customer-field">
        <span>Contact Number :</span>
        <span class="field-value">$contactNumber</span>
      </div>
      <div></div>
    </div>
  </div>
  
  <div class="booking-header">Booking Details</div>
  
  <table class="details-table">
  <tr>
    <td>தேதி</td>
    <td>$dateStr</td>
  </tr>
  <tr>
    <td>மண்டபம்</td>
    <td>$venue</td>
  </tr>
  <tr>
    <td>கம்ப்யூட்டர் எண்ணிக்கை</td>
    <td>$totalComputers</td>
  </tr>
  <tr>
    <td>புக்கிங் தொகை</td>
    <td>$bookedAmount</td>
  </tr>
  <tr>
    <td>அட்வான்ஸ்</td>
    <td>$advanceAmount</td>
  </tr>
  <tr>
    <td>மீதம்</td>
    <td>$balanceAmount</td>
  </tr>
</table>
  
  <div class="footer-section">
    <div class="footer-title">அன்பார்ந்த வாடிக்கையாளரே,</div>
    <ol class="footer-list">
      <li>பின்வரும் பொருட்களை விழா நாளன்று ஏற்பாடு செய்து வைக்கவும். (டேபிள், சேர், சிறிய நோட்டு, பேனா மற்றும் ரப்பர் பேண்ட்).</li>
      <li>எங்களது வேலை நேரம் காலை 9 மணி முதல் மாலை 3 மணி வரை.</li>
      <li>விழா முடிந்தவுடன் மண்டபத்தில் கணக்கீடு முடித்தவுடன் உடனுக்குடன் மொய் நோட்டு வழங்கப்படும். பின்பு 10 நாட்கள் கழித்து வீட்டிற்கு வந்த மொய் விவரங்களை நீங்கள் விரும்பும் பட்சத்தில் அவற்றையும் ஏற்றி 2வது நோட்டு வழங்கப்படும். அதற்கு தனிக்கட்டணம்.</li>
      <li>எக்காரணத்தைக் கொண்டும் முன்பணம் திருப்பித்தரப்பட மாட்டாது.</li>
    </ol>
    
    <div class="thank-you">Thank you for booking us!</div>
  </div>
</body>
</html>
''';
  }
}