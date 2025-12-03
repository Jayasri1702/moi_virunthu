import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

class MoiReceiptGenerator {

  // Format number with commas (Indian numbering system)
  static String _formatAmount(num amount) {
    final roundedAmount = amount.round();
    final str = roundedAmount.toString();

    if (str.length <= 3) return str;

    // Indian numbering: last 3 digits, then groups of 2
    final lastThree = str.substring(str.length - 3);
    final remaining = str.substring(0, str.length - 3);

    String result = '';
    int count = 0;
    for (int i = remaining.length - 1; i >= 0; i--) {
      if (count == 2) {
        result = ',$result';
        count = 0;
      }
      result = remaining[i] + result;
      count++;
    }

    return '$result,$lastThree';
  }

  // Cache for base64 logo
  static String? _cachedLogoBase64;

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
      return ''; // Return empty string if logo fails to load
    }
  }
  // Generate single MOI receipt
  static Future<File?> generateSingleMoiReceipt({
    required BuildContext context,
    required int serialNo,
    required String operatorName,
    required DateTime eventDate,
    required TimeOfDay eventTime,
    String? villageName,
    String? livingPlace,
    String? person1Name,
    String? person1Job,
    String? person2Details,
    String? phone,
    required num amount,
    required String paymentMethod,
    Map<int, int>? denominations,
    // ✅ NEW: Event details for footer
    String? customerName,
    String? city,
    String? customerPhone,
    bool isUncle = false,  // ✅ ADD THIS LINE
  }) async {
    try {
      final logoBase64 = await _getLogoBase64();
      // Use different template based on payment method
      final htmlContent = paymentMethod == 'CASH'
          ? _generateSingleMoiHtml(
        serialNo: serialNo,
        operatorName: operatorName,
        eventDate: eventDate,
        eventTime: eventTime,
        villageName: villageName,
        livingPlace: livingPlace,
        person1Name: person1Name,
        person1Job: person1Job,
        person2Details: person2Details,
        phone: phone,
        amount: amount,
        paymentMethod: paymentMethod,
        denominations: denominations,
        customerName: customerName,
        city: city,
        customerPhone: customerPhone,
        logoBase64: logoBase64,  // ADD THIS
        isUncle: isUncle,
      )
          : _generateSingleMoiHtmlOthers(
        serialNo: serialNo,
        operatorName: operatorName,
        eventDate: eventDate,
        eventTime: eventTime,
        villageName: villageName,
        livingPlace: livingPlace,
        person1Name: person1Name,
        person1Job: person1Job,
        person2Details: person2Details,
        phone: phone,
        amount: amount,
        paymentMethod: paymentMethod,
        customerName: customerName,
        city: city,
        customerPhone: customerPhone,
        logoBase64: logoBase64,  // ADD THIS
        isUncle: isUncle,
      );

      final output = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'moi_single_${serialNo}_$timestamp.pdf';
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
              print('Single receipt PDF generated: $filePath');
            }
          } catch (e) {
            print('Error generating single receipt PDF: $e');
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
      print('Error in generateSingleMoiReceipt: $e');
      return null;
    }
  }

  // HTML template for single MOI receipt (CASH)
  static String _generateSingleMoiHtml({
    required int serialNo,
    required String operatorName,
    required DateTime eventDate,
    required TimeOfDay eventTime,
    String? villageName,
    String? livingPlace,
    String? person1Name,
    String? person1Job,
    String? person2Details,
    String? phone,
    required num amount,
    required String paymentMethod,
    Map<int, int>? denominations,
    String? customerName,
    String? city,
    String? customerPhone,
    required String logoBase64,
    bool isUncle = false,
  }) {
    // ✅ FIXED: Use current date/time for receipt generation
    final now = DateTime.now();
    final dateStr = DateFormat('dd-MM-yyyy').format(now);
    final timeStr = DateFormat('hh.mm a').format(now);

    // Build person display
    String personDisplay = '';
    if (person1Name != null && person1Name.isNotEmpty) {
      personDisplay += '$person1Name\n';
      if (person1Job != null && person1Job.isNotEmpty) {
        personDisplay += '$person1Job\n';
      }
    }
    if (person2Details != null && person2Details.isNotEmpty) {
      personDisplay += person2Details;
    }

    // ✅ FIXED: Build denomination table with received/return logic
    String denomTable = '';
    num receivedAmount = 0;
    num returnAmount = 0;

    if (paymentMethod == 'CASH' && denominations != null) {
      List<int> denomKeys = [500, 200, 100, 50, 20, 10, 5, 1];

      // Separate positive (received) and negative (return) denominations
      Map<int, int> receivedDenoms = {};
      Map<int, int> returnDenoms = {};

      for (int denom in denomKeys) {
        int count = denominations[denom] ?? 0;
        if (count > 0) {
          receivedDenoms[denom] = count;
          receivedAmount += denom * count;
        } else if (count < 0) {
          returnDenoms[denom] = count.abs();
          returnAmount += denom * count.abs();
        }
      }

      // ✅ Build received table
      if (receivedDenoms.isNotEmpty) {
        for (int denom in denomKeys) {
          if (receivedDenoms.containsKey(denom)) {
            int count = receivedDenoms[denom]!;
            num total = denom * count;
            denomTable += '''
              <tr>
                <td style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold;">$denom</td>
                <td style="border: 2px solid black; padding: 4px; text-align: center;">x</td>
                <td style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold;">$count</td>
                <td style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold;">$total</td>
              </tr>
            ''';
          }
        }

        denomTable += '''
          <tr>
            <td colspan="3" style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold; background-color: #e8f5e9;">Received</td>
            <td style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold; background-color: #e8f5e9;">$receivedAmount</td>
          </tr>
        ''';
      }

      // ✅ Build return table
      if (returnDenoms.isNotEmpty) {
        denomTable += '''
          <tr>
            <td colspan="3" style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold; background-color: #fff3e0;">Return</td>
            <td style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold; background-color: #fff3e0;">$returnAmount</td>
          </tr>
        ''';

        for (int denom in denomKeys) {
          if (returnDenoms.containsKey(denom)) {
            int count = returnDenoms[denom]!;
            num total = denom * count;
            denomTable += '''
              <tr>
                <td style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold;">$denom</td>
                <td style="border: 2px solid black; padding: 4px; text-align: center;">x</td>
                <td style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold;">$count</td>
                <td style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold;">$total</td>
              </tr>
            ''';
          }
        }
      }
    }

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
      background-color: #1976D2;
      color: white;
      font-size: 20px;
      font-weight: bold;
      padding: 8px;
      margin-bottom: 10px;
    }
    .outer-box {
  border: 3px solid black;
  padding: 0;
}

.uncle-indicator {
  font-size: 14px;
  font-weight: bold;
  margin: 6px 0 4px 0;
  text-align: center;
  color: #000;
}
    
.logo-header {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 8px;
  gap: 6px;
  text-align: center;
}

.logo {
  width: 50px;
  height: 50px;
  object-fit: contain;
}

.company-info {
  width: 100%;
  text-align: center;
}

.company-name {
  font-size: 18px;
  font-weight: bold;
  color: #000;
  margin-bottom: 2px;
}

.tamil-heading {
  font-size: 14px;
  color: #000;
  margin-bottom: 3px;
}

.company-phone {
  font-size: 11px;
  color: #000;
}
    
    .divider {
  border-top: 2px solid black;
  margin: 0;  // Changed from margin: 10px 0;
}
    
    .date-time-row {
  display: flex;
  justify-content: space-between;
  font-size: 14px;
  border-bottom: 2px solid black;
}

.left-section {
  text-align: left;
  padding: 8px;
  flex: 1;
  border-right: 2px solid black;
}

.right-section {
  text-align: right;
  padding: 8px;
  flex: 1;
  font-weight: bold;
}
    
    .serial-no {
      font-size: 16px;
      font-weight: bold;
      margin: 8px 0;
      text-align: center;
    }
    
    .person-details {
      font-size: 16px;
      margin: 6px 0;
      white-space: pre-line;
      line-height: 1.4;
    }
    
    .village-info {
      font-size: 14px;
      margin: 4px 0;
    }
    
    .phone {
      font-size: 14px;
      margin: 6px 0;
    }
    
    .amount-label {
      font-size: 16px;
      font-weight: bold;
      margin-top: 10px;
    }
    
    .amount {
      font-size: 24px;
      font-weight: bold;
      margin: 8px 0;
    }
    
    .table-title {
  font-size: 16px;
  font-weight: bold;
  margin: 0;  // Changed from margin: 10px 0;
  padding: 8px 0;  // Added padding instead
}
    
    table {
  width: 100%;
  border-collapse: collapse;
  margin: 0;  // Changed from margin: 10px 0;
}


    
    .footer {
  margin-top: 0;  // Changed from margin-top: 15px;
  padding-top: 8px;  // Use padding instead
  font-size: 14px;
}
    
    .thanks {
      margin: 6px 0;
    }
    
    .with-love {
      font-size: 12px;
      margin: 4px 0;
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
        <div class="company-phone">9043606296, 9047556443</div>
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
      <div>$operatorName</div>
    </div>
  </div>
  
  <div class="serial-no">வ.எண் : $serialNo</div>
  
 ${villageName != null && villageName.isNotEmpty ? '<div class="village-info">$villageName</div>' : ''}
${livingPlace != null && livingPlace.isNotEmpty ? '<div class="village-info">$livingPlace</div>' : ''}

<div class="person-details">$personDisplay</div>

${isUncle ? '<div class="uncle-indicator">தாய்மாமன்</div>' : ''}

${phone != null && phone.isNotEmpty ? '<div class="phone">($phone)</div>' : ''}

<div class="amount-label">தொகை</div>
<div class="amount">₹${_formatAmount(amount)}</div>
  
  ${denomTable.isNotEmpty ? '<div class="table-title">நோட்டு விபரம்</div>' : ''}
  ${denomTable.isNotEmpty ? '<table>$denomTable</table>' : ''}
  
  <div class="divider"></div>
  
  <div class="footer">
    <div class="thanks">தங்கள் வருகைக்கு நன்றி!</div>
    <div class="with-love">அன்புடன்...</div>
    ${customerName != null && customerName.isNotEmpty ? '<div class="person-details">$customerName</div>' : ''}
    ${city != null && city.isNotEmpty ? '<div class="village-info">$city</div>' : ''}
    ${customerPhone != null && customerPhone.isNotEmpty ? '<div class="phone">$customerPhone</div>' : ''}
</div>
  </div>
</body>
</html>
''';
  }

  // HTML template for single MOI receipt (OTHERS - Cheque/Advance/UPI)
  static String _generateSingleMoiHtmlOthers({
    required int serialNo,
    required String operatorName,
    required DateTime eventDate,
    required TimeOfDay eventTime,
    String? villageName,
    String? livingPlace,
    String? person1Name,
    String? person1Job,
    String? person2Details,
    String? phone,
    required num amount,
    required String paymentMethod,
    String? customerName,
    String? city,
    String? customerPhone,
    required String logoBase64,
    bool isUncle = false,
  }) {
    // ✅ FIXED: Use current date/time
    final now = DateTime.now();
    final dateStr = DateFormat('dd-MM-yyyy').format(now);
    final timeStr = DateFormat('hh.mm a').format(now);

    // Build person display
    String personDisplay = '';
    if (person1Name != null && person1Name.isNotEmpty) {
      personDisplay += '$person1Name\n';
      if (person1Job != null && person1Job.isNotEmpty) {
        personDisplay += '$person1Job\n';
      }
    }
    if (person2Details != null && person2Details.isNotEmpty) {
      personDisplay += person2Details;
    }

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
      background-color: #1976D2;
      color: white;
      font-size: 18px;
      font-weight: bold;
      padding: 10px;
      margin-bottom: 10px;
    }
    .outer-box {
  border: 3px solid black;
  padding: 0;
}
    
.logo-header {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 8px;
  gap: 6px;
  text-align: center;
}

.logo {
  width: 50px;
  height: 50px;
  object-fit: contain;
}

.company-info {
  width: 100%;
  text-align: center;
}

.company-name {
  font-size: 18px;
  font-weight: bold;
  color: #000;
  margin-bottom: 2px;
}

.tamil-heading {
  font-size: 14px;
  color: #000;
  margin-bottom: 3px;
}

.company-phone {
  font-size: 11px;
  color: #000;
}
    
    .divider {
  border-top: 2px solid black;
  margin: 0;  // Changed from margin: 10px 0;
}
    
    .date-time-row {
  display: flex;
  justify-content: space-between;
  font-size: 14px;
  border-bottom: 2px solid black;
}
.uncle-indicator {
  font-size: 14px;
  font-weight: bold;
  margin: 6px 0 4px 0;
  text-align: center;
  color: #000;
}
.left-section {
  text-align: left;
  padding: 8px;
  flex: 1;
  border-right: 2px solid black;
}

.right-section {
  text-align: right;
  padding: 8px;
  flex: 1;
  font-weight: bold;
}
    
    .serial-no {
      font-size: 18px;
      font-weight: bold;
      margin: 12px 0;
      text-align: center;
    }
    
    .person-details {
      font-size: 16px;
      margin: 8px 0;
      white-space: pre-line;
      line-height: 1.5;
      font-weight: 500;
    }
    
    .village-info {
      font-size: 15px;
      margin: 6px 0;
      font-weight: 500;
    }
    
    .phone {
      font-size: 16px;
      margin: 8px 0;
      font-weight: bold;
    }
    
    .amount-label {
      font-size: 16px;
      font-weight: bold;
      margin-top: 12px;
    }
    
    .amount {
      font-size: 28px;
      font-weight: bold;
      margin: 10px 0;
      color: #000;
    }
    
    .payment-method-box {
  border: 2px solid black;
  padding: 12px;
  margin: 0;  // Changed from margin: 15px 0;
  font-size: 16px;
  font-weight: bold;
  background-color: #f5f5f5;
}

    
    .footer {
  margin-top: 0;  // Changed from margin-top: 15px;
  padding-top: 8px;  // Use padding instead
  font-size: 14px;
}
    
    .thanks {
      margin: 8px 0;
      font-weight: bold;
    }
    
    .with-love {
      font-size: 14px;
      margin: 6px 0;
    }
    
    .footer-person {
      font-size: 16px;
      font-weight: bold;
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
        <div class="company-phone">9043606296, 9047556443</div>
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
      <div>$operatorName</div>
    </div>
  </div>
  
  <div class="serial-no">வ.எண் : $serialNo</div>
  
${villageName != null && villageName.isNotEmpty ? '<div class="village-info">$villageName</div>' : ''}
${livingPlace != null && livingPlace.isNotEmpty ? '<div class="village-info">$livingPlace</div>' : ''}

<div class="person-details">$personDisplay</div>

${isUncle ? '<div class="uncle-indicator">தாய்மாமன்</div>' : ''}

${phone != null && phone.isNotEmpty ? '<div class="phone">($phone)</div>' : ''}

<div class="amount-label">தொகை</div>
<div class="amount">₹${_formatAmount(amount)}</div>
  
  <div class="payment-method-box">Cheque / Advance / UPI</div>
  
  <div class="footer">
    <div class="thanks">தங்கள் வருகைக்கு நன்றி!</div>
    <div class="with-love">அன்புடன்...</div>
    ${customerName != null && customerName.isNotEmpty ? '<div class="footer-person">$customerName</div>' : ''}
    ${city != null && city.isNotEmpty ? '<div class="village-info">$city</div>' : ''}
    ${customerPhone != null && customerPhone.isNotEmpty ? '<div class="phone">$customerPhone</div>' : ''}
  </div>
  </div>
</body>
</html>
''';
  }

  static Future<List<File>> generateSplitGroupReceipts({
    required BuildContext context,
    required String operatorName,
    required DateTime eventDate,
    required TimeOfDay eventTime,
    required List<Map<String, dynamic>> groupEntries,
    String? customerName,
    String? city,
    String? customerPhone,
  }) async {
    List<File> generatedFiles = [];

    for (var entry in groupEntries) {
      // ✅ FIXED: Parse persons data correctly
      String? person1Name;
      String? person1Job;
      String? person2Details;

      if (entry['persons'] != null) {
        List<dynamic> personsList = entry['persons'] as List;
        if (personsList.isNotEmpty) {
          person1Name = personsList[0]['name'];
          person1Job = personsList[0]['job'];
        }
        if (personsList.length > 1) {
          person2Details = personsList[1]['details'];
        }
      }

      // Parse denominations if payment is CASH
      Map<int, int>? denominations;
      if (entry['payment_method'] == 'CASH' && entry['denominations'] != null) {
        denominations = {
          500: entry['denominations']['denom_500'] ?? 0,
          200: entry['denominations']['denom_200'] ?? 0,
          100: entry['denominations']['denom_100'] ?? 0,
          50: entry['denominations']['denom_50'] ?? 0,
          20: entry['denominations']['denom_20'] ?? 0,
          10: entry['denominations']['denom_10'] ?? 0,
          5: entry['denominations']['denom_5'] ?? 0,
          1: entry['denominations']['denom_1'] ?? 0,
        };
      }

      final file = await generateSingleMoiReceipt(
        context: context,
        serialNo: entry['serial_no'],
        operatorName: operatorName,
        eventDate: eventDate,
        eventTime: eventTime,
        villageName: entry['village_name'],
        livingPlace: entry['living_place'],
        person1Name: person1Name,
        person1Job: person1Job,
        person2Details: person2Details,
        phone: entry['phone'],
        amount: entry['amount'],
        paymentMethod: entry['payment_method'],
        denominations: denominations,
        customerName: customerName,
        city: city,
        customerPhone: customerPhone,
        isUncle: entry['is_uncle'] ?? false,
      );

      if (file != null) {
        generatedFiles.add(file);
      }
    }

    return generatedFiles;
  }

  // Generate consolidated group MOI receipt
  static Future<File?> generateGroupMoiReceipt({
    required BuildContext context,
    required int groupId,
    required String operatorName,
    required DateTime eventDate,
    required TimeOfDay eventTime,
    required List<Map<String, dynamic>> groupEntries,
    required num totalAmount,
    Map<int, int>? totalDenominations,
    String? customerName,
    String? city,
    String? customerPhone,
  }) async {
    try {
      final logoBase64 = await _getLogoBase64();
      bool hasOthersPayment = groupEntries.any((entry) => entry['payment_method'] != 'CASH');

      final htmlContent = hasOthersPayment
          ? _generateGroupMoiHtmlOthers(
        groupId: groupId,
        operatorName: operatorName,
        eventDate: eventDate,
        eventTime: eventTime,
        groupEntries: groupEntries,
        totalAmount: totalAmount,
        customerName: customerName,
        city: city,
        customerPhone: customerPhone,
        logoBase64: logoBase64,
      )
          : _generateGroupMoiHtml(
        groupId: groupId,
        operatorName: operatorName,
        eventDate: eventDate,
        eventTime: eventTime,
        groupEntries: groupEntries,
        totalAmount: totalAmount,
        totalDenominations: totalDenominations,
        customerName: customerName,
        city: city,
        customerPhone: customerPhone,
        logoBase64: logoBase64,
      );

      final output = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'moi_group_${groupId}_$timestamp.pdf';
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
                    return pw.Center(
                      child: pw.Image(image, fit: pw.BoxFit.contain),
                    );
                  },
                ),
              );

              final file = File(filePath);
              await file.writeAsBytes(await pdf.save());
              generatedFile = file;
              pdfGenerated = true;
              print('Group MOI PDF generated: $filePath');
            }
          } catch (e) {
            print('Error generating group MOI PDF: $e');
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
      print('Error in generateGroupMoiReceipt: $e');
      return null;
    }
  }

  static String _generateGroupMoiHtml({
    required int groupId,
    required String operatorName,
    required DateTime eventDate,
    required TimeOfDay eventTime,
    required List<Map<String, dynamic>> groupEntries,
    required num totalAmount,
    Map<int, int>? totalDenominations,
    String? customerName,
    String? city,
    String? customerPhone,
    required String logoBase64,
  }) {
    final now = DateTime.now();
    final dateStr = DateFormat('dd-MM-yyyy').format(now);
    final timeStr = DateFormat('hh.mm a').format(now);

    String entriesHtml = '';
    for (var entry in groupEntries) {
      // Build full person display like single receipt
      String personDisplay = '';
      if (entry['persons'] != null) {
        List<dynamic> personsList = entry['persons'] as List;
        if (personsList.isNotEmpty) {
          String name = personsList[0]['name'] ?? '';
          String job = personsList[0]['job'] ?? '';
          if (name.isNotEmpty) {
            personDisplay += '$name\n';
            if (job.isNotEmpty) {
              personDisplay += '$job\n';
            }
          }
        }
        if (personsList.length > 1) {
          String details = personsList[1]['details'] ?? '';
          if (details.isNotEmpty) {
            personDisplay += details;
          }
        }
      }

      String villageName = entry['village_name'] ?? '';
      String livingPlace = entry['living_place'] ?? '';
      String phone = entry['phone'] ?? '';
      bool isUncle = entry['is_uncle'] ?? false;

      var amountValue = entry['amount'];
      int amount = 0;
      if (amountValue is int) {
        amount = amountValue;
      } else if (amountValue is double) {
        amount = amountValue.round();
      } else if (amountValue is num) {
        amount = amountValue.round();
      }

      entriesHtml += '''
    <div class="entry-block">
      <div class="serial-no">வ.எண் : ${entry['serial_no']}</div>
      ${villageName.isNotEmpty ? '<div class="village-info">$villageName</div>' : ''}
      ${livingPlace.isNotEmpty ? '<div class="village-info">$livingPlace</div>' : ''}
      ${personDisplay.isNotEmpty ? '<div class="person-details" style="font-size: 14px; margin: 6px 0; white-space: pre-line;">$personDisplay</div>' : ''}
      ${isUncle ? '<div class="uncle-indicator" style="font-size: 12px; margin: 4px 0;">தாய்மாமன்</div>' : ''}
      ${phone.isNotEmpty ? '<div class="phone" style="font-size: 12px; margin: 4px 0;">($phone)</div>' : ''}
      <div class="amount-label">தொகை</div>
      <div class="entry-amount">₹${_formatAmount(amount)}</div>
    </div>
    <div class="divider"></div>
  ''';
    }

    String denomTable = '';
    if (totalDenominations != null) {
      List<int> denomKeys = [500, 200, 100, 50, 20, 10, 5, 1];

      Map<int, int> receivedDenoms = {};
      Map<int, int> returnDenoms = {};
      num receivedAmount = 0;
      num returnAmount = 0;

      for (int denom in denomKeys) {
        int count = totalDenominations[denom] ?? 0;
        if (count > 0) {
          receivedDenoms[denom] = count;
          receivedAmount += denom * count;
        } else if (count < 0) {
          returnDenoms[denom] = count.abs();
          returnAmount += denom * count.abs();
        }
      }

      if (receivedDenoms.isNotEmpty) {
        for (int denom in denomKeys) {
          if (receivedDenoms.containsKey(denom)) {
            int count = receivedDenoms[denom]!;
            int total = denom * count;
            denomTable += '''
            <tr>
              <td style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold;">$denom</td>
              <td style="border: 2px solid black; padding: 4px; text-align: center;">x</td>
              <td style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold;">$count</td>
              <td style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold;">$total</td>
            </tr>
          ''';
          }
        }

        denomTable += '''
        <tr>
          <td colspan="3" style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold; background-color: #e8f5e9;">Received</td>
          <td style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold; background-color: #e8f5e9;">$receivedAmount</td>
        </tr>
      ''';
      }

      if (returnDenoms.isNotEmpty) {
        denomTable += '''
        <tr>
          <td colspan="3" style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold; background-color: #fff3e0;">Return</td>
          <td style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold; background-color: #fff3e0;">$returnAmount</td>
        </tr>
      ''';

        for (int denom in denomKeys) {
          if (returnDenoms.containsKey(denom)) {
            int count = returnDenoms[denom]!;
            int total = denom * count;
            denomTable += '''
            <tr>
              <td style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold;">$denom</td>
              <td style="border: 2px solid black; padding: 4px; text-align: center;">x</td>
              <td style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold;">$count</td>
              <td style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold;">$total</td>
            </tr>
          ''';
          }
        }
      }
    }

    int displayTotal = totalAmount.round();

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
      background-color: #1976D2;
      color: white;
      font-size: 20px;
      font-weight: bold;
      padding: 8px;
      margin-bottom: 10px;
    }
    .outer-box {
  border: 3px solid black;
  padding: 0;
}

.uncle-indicator {
  font-size: 14px;
  font-weight: bold;
  margin: 6px 0 4px 0;
  text-align: center;
  color: #000;
}
    
.logo-header {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 8px;
  gap: 6px;
  text-align: center;
}

.logo {
  width: 50px;
  height: 50px;
  object-fit: contain;
}

.company-info {
  width: 100%;
  text-align: center;
}

.company-name {
  font-size: 18px;
  font-weight: bold;
  color: #000;
  margin-bottom: 2px;
}

.tamil-heading {
  font-size: 14px;
  color: #000;
  margin-bottom: 3px;
}

.company-phone {
  font-size: 11px;
  color: #000;
}
    
    .divider {
  border-top: 2px solid black;
  margin: 0;  // Changed from margin: 10px 0;
}
    
    .date-time-row {
  display: flex;
  justify-content: space-between;
  font-size: 14px;
  border-bottom: 2px solid black;
}

.left-section {
  text-align: left;
  padding: 8px;
  flex: 1;
  border-right: 2px solid black;
}

.right-section {
  text-align: right;
  padding: 8px;
  flex: 1;
  font-weight: bold;
}
    
    .serial-no {
      font-size: 16px;
      font-weight: bold;
      margin: 8px 0;
    }
    
    .person-name {
      font-size: 16px;
      font-weight: bold;
      margin: 6px 0;
    }
    
    .village-info {
      font-size: 14px;
      margin: 4px 0;
    }
    
    .amount-label {
      font-size: 14px;
      font-weight: bold;
      margin-top: 6px;
    }
    
    .entry-amount {
      font-size: 20px;
      font-weight: bold;
      margin: 4px 0;
    }
    
   .total-section {
  background-color: #f5f5f5;
  padding: 10px;
  margin: 0;  // Changed from margin: 15px 0;
  border: 2px solid black;
}
    
    .total-label {
      font-size: 18px;
      font-weight: bold;
    }
    
    .total-amount {
      font-size: 26px;
      font-weight: bold;
      color: #1976D2;
      margin: 8px 0;
    }
    
    .table-title {
  font-size: 16px;
  font-weight: bold;
  margin: 0;  // Changed from margin: 10px 0;
  padding: 8px 0;  // Added padding instead
}
    
    table {
  width: 100%;
  border-collapse: collapse;
  margin: 0;  // Changed from margin: 10px 0;
}

    
    .footer {
  margin-top: 0;  // Changed from margin-top: 15px;
  padding-top: 8px;  // Use padding instead
  font-size: 14px;
}
    
    .thanks {
      margin: 6px 0;
    }
    
    .with-love {
      font-size: 12px;
      margin: 4px 0;
    }
    
    .footer-name {
      font-size: 16px;
      font-weight: bold;
      margin: 4px 0;
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
        <div class="company-phone">9043606296, 9047556443</div>
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
      <div>$operatorName</div>
    </div>
  </div>
  
  $entriesHtml
  
  <div class="total-section">
    <div class="total-label">மொத்த தொகை</div>
    <div class="total-amount">₹${_formatAmount(totalAmount)}</div>
  </div>
  
  ${denomTable.isNotEmpty ? '<div class="table-title">நோட்டு விபரம்</div>' : ''}
  ${denomTable.isNotEmpty ? '<table>$denomTable</table>' : ''}
  
  <div class="divider"></div>
  
  <div class="footer">
    <div class="thanks">தங்கள் வருகைக்கு நன்றி!</div>
    <div class="with-love">அன்புடன்...</div>
    ${customerName != null && customerName.isNotEmpty ? '<div class="footer-name">$customerName</div>' : ''}
    ${city != null && city.isNotEmpty ? '<div class="village-info">$city</div>' : ''}
    ${customerPhone != null && customerPhone.isNotEmpty ? '<div class="village-info">$customerPhone</div>' : ''}
  </div>
  </div>
</body>
</html>
''';
  }

  static String _generateGroupMoiHtmlOthers({
    required int groupId,
    required String operatorName,
    required DateTime eventDate,
    required TimeOfDay eventTime,
    required List<Map<String, dynamic>> groupEntries,
    required num totalAmount,
    String? customerName,
    String? city,
    String? customerPhone,
    required String logoBase64,
  }) {
    final now = DateTime.now();
    final dateStr = DateFormat('dd-MM-yyyy').format(now);
    final timeStr = DateFormat('hh.mm a').format(now);

    String entriesHtml = '';
    for (var entry in groupEntries) {
      // Build full person display like single receipt
      String personDisplay = '';
      if (entry['persons'] != null) {
        List<dynamic> personsList = entry['persons'] as List;
        if (personsList.isNotEmpty) {
          String name = personsList[0]['name'] ?? '';
          String job = personsList[0]['job'] ?? '';
          if (name.isNotEmpty) {
            personDisplay += '$name\n';
            if (job.isNotEmpty) {
              personDisplay += '$job\n';
            }
          }
        }
        if (personsList.length > 1) {
          String details = personsList[1]['details'] ?? '';
          if (details.isNotEmpty) {
            personDisplay += details;
          }
        }
      }

      String villageName = entry['village_name'] ?? '';
      String livingPlace = entry['living_place'] ?? '';
      String phone = entry['phone'] ?? '';
      bool isUncle = entry['is_uncle'] ?? false;

      var amountValue = entry['amount'];
      int amount = 0;
      if (amountValue is int) {
        amount = amountValue;
      } else if (amountValue is double) {
        amount = amountValue.round();
      } else if (amountValue is num) {
        amount = amountValue.round();
      }

      entriesHtml += '''
    <div class="entry-block">
      <div class="serial-no">வ.எண் : ${entry['serial_no']}</div>
      ${villageName.isNotEmpty ? '<div class="village-info">$villageName</div>' : ''}
      ${livingPlace.isNotEmpty ? '<div class="village-info">$livingPlace</div>' : ''}
      ${personDisplay.isNotEmpty ? '<div class="person-details" style="font-size: 14px; margin: 6px 0; white-space: pre-line;">$personDisplay</div>' : ''}
      ${isUncle ? '<div class="uncle-indicator" style="font-size: 12px; margin: 4px 0;">தாய்மாமன்</div>' : ''}
      ${phone.isNotEmpty ? '<div class="phone" style="font-size: 12px; margin: 4px 0;">($phone)</div>' : ''}
      <div class="amount-label">தொகை</div>
      <div class="entry-amount">₹${_formatAmount(amount)}</div>
    </div>
    <div class="divider"></div>
  ''';
    }

    int displayTotal = totalAmount.round();

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
      background-color: #1976D2;
      color: white;
      font-size: 18px;
      font-weight: bold;
      padding: 10px;
      margin-bottom: 10px;
    }
    .outer-box {
  border: 3px solid black;
  padding: 0;
}

.logo-header {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 8px;
  gap: 6px;
  text-align: center;
}

.logo {
  width: 50px;
  height: 50px;
  object-fit: contain;
}

.company-info {
  width: 100%;
  text-align: center;
}
.uncle-indicator {
  font-size: 14px;
  font-weight: bold;
  margin: 6px 0 4px 0;
  text-align: center;
  color: #000;
}

.company-name {
  font-size: 18px;
  font-weight: bold;
  color: #000;
  margin-bottom: 2px;
}

.tamil-heading {
  font-size: 14px;
  color: #000;
  margin-bottom: 3px;
}

.company-phone {
  font-size: 11px;
  color: #000;
}
    
   .divider {
  border-top: 2px solid black;
  margin: 0;  // Changed from margin: 10px 0;
}
    
    .date-time-row {
  display: flex;
  justify-content: space-between;
  font-size: 14px;
  border-bottom: 2px solid black;
}

.left-section {
  text-align: left;
  padding: 8px;
  flex: 1;
  border-right: 2px solid black;
}

.right-section {
  text-align: right;
  padding: 8px;
  flex: 1;
  font-weight: bold;
}
    
    .entry-block {
  margin: 0;  // Changed from margin: 10px 0;
  padding: 8px 0;
}
    
    .serial-no {
      font-size: 16px;
      font-weight: bold;
      margin: 8px 0;
    }
    
    .person-name {
      font-size: 16px;
      font-weight: bold;
      margin: 6px 0;
    }
    
    .village-info {
      font-size: 14px;
      margin: 4px 0;
    }
    
    .amount-label {
      font-size: 14px;
      font-weight: bold;
      margin-top: 6px;
    }
    
    .entry-amount {
      font-size: 20px;
      font-weight: bold;
      margin: 4px 0;
    }
    
    .total-section {
  background-color: #f5f5f5;
  padding: 10px;
  margin: 0;  // Changed from margin: 15px 0;
  border: 2px solid black;
}
    
    .total-label {
      font-size: 18px;
      font-weight: bold;
    }
    
    .total-amount {
      font-size: 26px;
      font-weight: bold;
      color: #1976D2;
      margin: 8px 0;
    }
    
   .payment-method-box {
  border: 2px solid black;
  padding: 12px;
  margin: 0;  // Changed from margin: 15px 0;
  font-size: 16px;
  font-weight: bold;
  background-color: #f5f5f5;
}

    
    .footer {
  margin-top: 0;  // Changed from margin-top: 15px;
  padding-top: 8px;  // Use padding instead
  font-size: 14px;
}
    
    .thanks {
      margin: 6px 0;
    }
    
    .with-love {
      font-size: 12px;
      margin: 4px 0;
    }
    
    .footer-name {
      font-size: 16px;
      font-weight: bold;
      margin: 4px 0;
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
        <div class="company-phone">9043606296, 9047556443</div>
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
      <div>$operatorName</div>
    </div>
  </div>
  
  $entriesHtml
  
  <div class="total-section">
    <div class="total-label">மொத்த தொகை</div>
   <div class="total-amount">₹${_formatAmount(totalAmount)}</div>
  </div>
  
  <div class="payment-method-box">Cheque / Advance / UPI</div>
  
  <div class="divider"></div>
  
  <div class="footer">
    <div class="thanks">தங்கள் வருகைக்கு நன்றி!</div>
    <div class="with-love">அன்புடன்...</div>
    ${customerName != null && customerName.isNotEmpty ? '<div class="footer-name">$customerName</div>' : ''}
    ${city != null && city.isNotEmpty ? '<div class="village-info">$city</div>' : ''}
    ${customerPhone != null && customerPhone.isNotEmpty ? '<div class="village-info">$customerPhone</div>' : ''}
  </div>
  </div>
</body>
</html>
''';
  }
}