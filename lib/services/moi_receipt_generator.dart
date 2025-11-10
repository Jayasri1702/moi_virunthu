import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

class MoiReceiptGenerator {
  // Generate single MOI receipt
  static Future<File?> generateSingleMoiReceipt({
    required BuildContext context,
    required int serialNo,
    required String operatorName,
    required DateTime eventDate,
    required TimeOfDay eventTime,
    String? villageName,
    String? livingPlace,
    String? person1Init,
    String? person1Name,
    String? person2Init,
    String? person2Name,
    String? phone,
    required num amount,
    required String paymentMethod,
    Map<int, int>? denominations,
  }) async {
    try {
      // Use different template based on payment method
      final htmlContent = paymentMethod == 'CASH'
          ? _generateSingleMoiHtml(
        serialNo: serialNo,
        operatorName: operatorName,
        eventDate: eventDate,
        eventTime: eventTime,
        villageName: villageName,
        livingPlace: livingPlace,
        person1Init: person1Init,
        person1Name: person1Name,
        person2Init: person2Init,
        person2Name: person2Name,
        phone: phone,
        amount: amount,
        paymentMethod: paymentMethod,
        denominations: denominations,
      )
          : _generateSingleMoiHtmlOthers(
        serialNo: serialNo,
        operatorName: operatorName,
        eventDate: eventDate,
        eventTime: eventTime,
        villageName: villageName,
        livingPlace: livingPlace,
        person1Init: person1Init,
        person1Name: person1Name,
        person2Init: person2Init,
        person2Name: person2Name,
        phone: phone,
        amount: amount,
        paymentMethod: paymentMethod,
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
        onLoadStop: (controller, url) async {
          try {
            await Future.delayed(const Duration(milliseconds: 1500));

            final screenshot = await controller.takeScreenshot();

            if (screenshot != null) {
              final pdf = pw.Document();
              final image = pw.MemoryImage(screenshot);

              pdf.addPage(
                pw.Page(
                  pageFormat: PdfPageFormat(
                    80 * PdfPageFormat.mm,
                    297 * PdfPageFormat.mm,
                    marginAll: 0,
                  ),
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
              print('Single MOI PDF generated: $filePath');
            }
          } catch (e) {
            print('Error generating single MOI PDF: $e');
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
  }) async {
    try {
      // Check if any entry has OTHERS payment method
      bool hasOthersPayment = groupEntries.any((entry) => entry['payment_method'] != 'CASH');

      final htmlContent = hasOthersPayment
          ? _generateGroupMoiHtmlOthers(
        groupId: groupId,
        operatorName: operatorName,
        eventDate: eventDate,
        eventTime: eventTime,
        groupEntries: groupEntries,
        totalAmount: totalAmount,
      )
          : _generateGroupMoiHtml(
        groupId: groupId,
        operatorName: operatorName,
        eventDate: eventDate,
        eventTime: eventTime,
        groupEntries: groupEntries,
        totalAmount: totalAmount,
        totalDenominations: totalDenominations,
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
        onLoadStop: (controller, url) async {
          try {
            await Future.delayed(const Duration(milliseconds: 1500));

            final screenshot = await controller.takeScreenshot();

            if (screenshot != null) {
              final pdf = pw.Document();
              final image = pw.MemoryImage(screenshot);

              pdf.addPage(
                pw.Page(
                  pageFormat: PdfPageFormat(
                    80 * PdfPageFormat.mm,
                    297 * PdfPageFormat.mm,
                    marginAll: 0,
                  ),
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
      print('Error in generateGroupMoiReceipt: $e');
      return null;
    }
  }

  // Generate split group receipts (individual receipts for each entry)
  static Future<List<File>> generateSplitGroupReceipts({
    required BuildContext context,
    required String operatorName,
    required DateTime eventDate,
    required TimeOfDay eventTime,
    required List<Map<String, dynamic>> groupEntries,
  }) async {
    List<File> generatedFiles = [];

    for (var entry in groupEntries) {
      // Parse persons data
      String? person1Init;
      String? person1Name;
      String? person2Init;
      String? person2Name;

      if (entry['persons'] != null) {
        List<dynamic> personsList = entry['persons'] as List;
        if (personsList.isNotEmpty) {
          person1Init = personsList[0]['init'];
          person1Name = personsList[0]['name'];
        }
        if (personsList.length > 1) {
          person2Init = personsList[1]['init'];
          person2Name = personsList[1]['name'];
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
        person1Init: person1Init,
        person1Name: person1Name,
        person2Init: person2Init,
        person2Name: person2Name,
        phone: entry['phone'],
        amount: entry['amount'],
        paymentMethod: entry['payment_method'],
        denominations: denominations,
      );

      if (file != null) {
        generatedFiles.add(file);
      }
    }

    return generatedFiles;
  }

  // HTML template for single MOI receipt
  static String _generateSingleMoiHtml({
    required int serialNo,
    required String operatorName,
    required DateTime eventDate,
    required TimeOfDay eventTime,
    String? villageName,
    String? livingPlace,
    String? person1Init,
    String? person1Name,
    String? person2Init,
    String? person2Name,
    String? phone,
    required num amount,
    required String paymentMethod,
    Map<int, int>? denominations,
  }) {
    final dateStr = DateFormat('dd-MM-yyyy').format(eventDate);
    final timeStr = '${eventTime.hour.toString().padLeft(2, '0')}.${eventTime
        .minute.toString().padLeft(2, '0')} ${eventTime.hour < 12
        ? 'am'
        : 'pm'}';

    // Build person display
    String personDisplay = '';
    if (person1Name != null && person1Name.isNotEmpty) {
      personDisplay += '${person1Init ?? ''}.${person1Name ?? ''}\n';
    }
    if (person2Name != null && person2Name.isNotEmpty) {
      personDisplay += '${person2Init ?? ''}.${person2Name ?? ''}';
    }

    // Build denomination table
    String denomTable = '';
    num receivedAmount = 0; // CHANGED from int to num
    num returnAmount = 0; // CHANGED from int to num

    if (paymentMethod == 'CASH' && denominations != null) {
      List<int> denomKeys = [500, 200, 100, 50, 20, 10, 5, 1];

      for (int denom in denomKeys) {
        int count = denominations[denom] ?? 0;
        if (count > 0) {
          num total = denom * count; // CHANGED from int to num
          receivedAmount += total;
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

      // Calculate return
      returnAmount = receivedAmount - amount;

      if (receivedAmount > 0) {
        denomTable += '''
          <tr>
            <td colspan="3" style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold;">Received</td>
            <td style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold;">$receivedAmount</td>
          </tr>
        ''';
      }

      if (returnAmount > 0) {
        denomTable += '''
          <tr>
            <td colspan="3" style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold;">Return</td>
            <td style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold;">$returnAmount</td>
          </tr>
        ''';

        // Calculate return denominations
        num remaining = returnAmount;
        for (int denom in denomKeys) {
          if (remaining >= denom) {
            int count = remaining ~/ denom;
            remaining = remaining % denom;
            denomTable += '''
              <tr>
                <td style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold;">$denom</td>
                <td style="border: 2px solid black; padding: 4px; text-align: center;">x</td>
                <td style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold;">$count</td>
                <td style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold;">${denom *
                count}</td>
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
    
    .company-name {
      font-size: 22px;
      font-weight: bold;
      margin-bottom: 5px;
      color: #000;
    }
    
    .company-phone {
      font-size: 14px;
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
      border: 2px solid black;
      padding: 8px;
    }
    
    .left-section {
      text-align: left;
    }
    
    .right-section {
      text-align: right;
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
      margin: 10px 0;
    }
    
    table {
      width: 100%;
      border-collapse: collapse;
      margin: 10px 0;
    }
    
    .footer {
      margin-top: 15px;
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
  <div class="header">Single Receipt</div>
  
  <div class="company-name">பேச்சி மொய் டெக்</div>
  <div class="company-phone">9043606296, 9047556443</div>
  
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
  
  ${villageName != null && villageName.isNotEmpty
        ? '<div class="village-info">$villageName</div>'
        : ''}
  ${livingPlace != null && livingPlace.isNotEmpty
        ? '<div class="village-info">$livingPlace</div>'
        : ''}
  
  <div class="person-details">$personDisplay</div>
  
  ${phone != null && phone.isNotEmpty
        ? '<div class="phone">($phone)</div>'
        : ''}
  
  <div class="amount-label">தொகை</div>
  <div class="amount">₹${amount.round()}</div>
  
  ${denomTable.isNotEmpty ? '<div class="table-title">நோட்டு விபரம்</div>' : ''}
  ${denomTable.isNotEmpty ? '<table>$denomTable</table>' : ''}
  
  <div class="divider"></div>
  
  <div class="footer">
    <div class="thanks">தங்கள் வருகைக்கு நன்றி!</div>
    <div class="with-love">அன்புடன்...</div>
    ${person1Name != null ? '<div class="person-details">${person1Init ??
        ''}.${person1Name}</div>' : ''}
    ${villageName != null && villageName.isNotEmpty
        ? '<div class="village-info">$villageName</div>'
        : ''}
    ${phone != null && phone.isNotEmpty
        ? '<div class="phone">$phone</div>'
        : ''}
  </div>
</body>
</html>
''';
  }

  // Replace the _generateGroupMoiHtml method in moi_receipt_generator.dart
// Starting from around line 486

  // Replace the _generateGroupMoiHtml method in moi_receipt_generator.dart
// Starting from around line 486

  static String _generateGroupMoiHtml({
    required int groupId,
    required String operatorName,
    required DateTime eventDate,
    required TimeOfDay eventTime,
    required List<Map<String, dynamic>> groupEntries,
    required num totalAmount,
    Map<int, int>? totalDenominations,
  }) {
    final dateStr = DateFormat('dd-MM-yyyy').format(eventDate);
    final timeStr = '${eventTime.hour.toString().padLeft(2, '0')}.${eventTime
        .minute.toString().padLeft(2, '0')} ${eventTime.hour < 12
        ? 'am'
        : 'pm'}';

    // Build entries list
    String entriesHtml = '';
    for (var entry in groupEntries) {
      String personDisplay = '';
      if (entry['persons'] != null) {
        List<dynamic> personsList = entry['persons'] as List;
        List<String> names = [];
        for (var person in personsList) {
          String name = person['name'] ?? '';
          if (name.isNotEmpty) {
            names.add(name);
          }
        }
        personDisplay = names.join(', ');
      }

      String villageName = entry['village_name'] ?? '';
      String livingPlace = entry['living_place'] ?? '';

      // Safely handle amount - convert to int for display
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
        <div class="person-name">$personDisplay</div>
        ${villageName.isNotEmpty
          ? '<div class="village-info">$villageName</div>'
          : ''}
        ${livingPlace.isNotEmpty
          ? '<div class="village-info">$livingPlace</div>'
          : ''}
        <div class="amount-label">தொகை</div>
        <div class="entry-amount">₹$amount</div>
      </div>
      <div class="divider"></div>
    ''';
    }

    // Build denomination table for total
    String denomTable = '';
    if (totalDenominations != null) {
      List<int> denomKeys = [500, 200, 100, 50, 20, 10, 5, 1];

      for (int denom in denomKeys) {
        int count = totalDenominations[denom] ?? 0;
        if (count > 0) {
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

      // Calculate received amount safely
      int receivedAmount = 0;
      totalDenominations.forEach((denom, count) {
        receivedAmount += (denom * count);
      });

      if (receivedAmount > 0) {
        denomTable += '''
  <tr>
    <td colspan="3" style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold;">Received</td>
    <td style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold;">$receivedAmount</td>
  </tr>
''';
      }
    }

    // Get first entry's details for footer
    String footerName = '';
    String footerVillage = '';
    String footerPhone = '';

    if (groupEntries.isNotEmpty) {
      var firstEntry = groupEntries.first;
      if (firstEntry['persons'] != null &&
          (firstEntry['persons'] as List).isNotEmpty) {
        var person = (firstEntry['persons'] as List).first;
        footerName = '${person['init'] ?? ''}.${person['name'] ?? ''}';
      }
      footerVillage = firstEntry['village_name'] ?? '';
      footerPhone = firstEntry['phone'] ?? '';
    }

    // Convert totalAmount to int for display
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
    
    .company-name {
      font-size: 22px;
      font-weight: bold;
      margin-bottom: 5px;
      color: #000;
    }
    
    .company-phone {
      font-size: 14px;
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
      border: 2px solid black;
      padding: 8px;
    }
    
    .left-section {
      text-align: left;
    }
    
    .right-section {
      text-align: right;
      font-weight: bold;
    }
    
    .entry-block {
      margin: 10px 0;
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
      margin: 15px 0;
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
      margin: 10px 0;
    }
    
    table {
      width: 100%;
      border-collapse: collapse;
      margin: 10px 0;
    }
    
    .footer {
      margin-top: 15px;
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
  <div class="header">Group Moi Receipt</div>
  
  <div class="company-name">பேச்சி மொய் டெக்</div>
  <div class="company-phone">9043606296, 9047556443</div>
  
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
    <div class="total-amount">₹$displayTotal</div>
  </div>
  
  ${denomTable.isNotEmpty ? '<div class="table-title">நோட்டு விபரம்</div>' : ''}
  ${denomTable.isNotEmpty ? '<table>$denomTable</table>' : ''}
  
  <div class="divider"></div>
  
  <div class="footer">
    <div class="thanks">தங்கள் வருகைக்கு நன்றி!</div>
    <div class="with-love">அன்புடன்...</div>
    ${footerName.isNotEmpty ? '<div class="footer-name">$footerName</div>' : ''}
    ${footerVillage.isNotEmpty
        ? '<div class="village-info">$footerVillage</div>'
        : ''}
    ${footerPhone.isNotEmpty
        ? '<div class="village-info">$footerPhone</div>'
        : ''}
  </div>
</body>
</html>
''';
  }


  // Add this method to moi_receipt_generator.dart after _generateSingleMoiHtml

  static String _generateSingleMoiHtmlOthers({
    required int serialNo,
    required String operatorName,
    required DateTime eventDate,
    required TimeOfDay eventTime,
    String? villageName,
    String? livingPlace,
    String? person1Init,
    String? person1Name,
    String? person2Init,
    String? person2Name,
    String? phone,
    required num amount,
    required String paymentMethod,
  }) {
    final dateStr = DateFormat('dd-MM-yyyy').format(eventDate);
    final timeStr = '${eventTime.hour.toString().padLeft(2, '0')}.${eventTime.minute.toString().padLeft(2, '0')} ${eventTime.hour < 12 ? 'am' : 'pm'}';

    // Build person display
    String personDisplay = '';
    if (person1Name != null && person1Name.isNotEmpty) {
      personDisplay += '${person1Init ?? ''}.${person1Name ?? ''}\n';
    }
    if (person2Name != null && person2Name.isNotEmpty) {
      personDisplay += '${person2Init ?? ''}.${person2Name ?? ''}';
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
    
    .company-name {
      font-size: 22px;
      font-weight: bold;
      margin-bottom: 5px;
      color: #000;
    }
    
    .company-phone {
      font-size: 14px;
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
      border: 2px solid black;
      padding: 8px;
    }
    
    .left-section {
      text-align: left;
    }
    
    .right-section {
      text-align: right;
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
      margin: 15px 0;
      font-size: 16px;
      font-weight: bold;
      background-color: #f5f5f5;
    }
    
    .footer {
      margin-top: 15px;
      font-size: 15px;
      border-top: 2px solid black;
      padding-top: 12px;
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
  <div class="header">Check / Advance / UPI Receipt</div>
  
  <div class="company-name">பேச்சி மொய் டெக்</div>
  <div class="company-phone">9043606296, 9047556443</div>
  
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
  
  <div class="person-details">$personDisplay</div>
  
  ${person1Init != null && person1Init.isNotEmpty ? '<div class="village-info">${person1Init}.${person1Name ?? ''}</div>' : ''}
  ${villageName != null && villageName.isNotEmpty ? '<div class="village-info">$villageName</div>' : ''}
  ${livingPlace != null && livingPlace.isNotEmpty ? '<div class="village-info">$livingPlace</div>' : ''}
  
  ${phone != null && phone.isNotEmpty ? '<div class="phone">($phone)</div>' : ''}
  
  <div class="amount-label">தொகை</div>
  <div class="amount">₹${amount.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{2})+(\d)(?!\d))'), (Match m) => '${m[1]},')}}</div>
  
  <div class="payment-method-box">Check / Advance / UPI</div>
  
  <div class="footer">
    <div class="thanks">தங்கள் வருகைக்கு நன்றி!</div>
    <div class="with-love">அன்புடன்...</div>
    ${person1Name != null ? '<div class="footer-person">${person1Init ?? ''}.${person1Name}</div>' : ''}
    ${villageName != null && villageName.isNotEmpty ? '<div class="village-info">$villageName</div>' : ''}
    ${phone != null && phone.isNotEmpty ? '<div class="phone">$phone</div>' : ''}
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
  }) {
    final dateStr = DateFormat('dd-MM-yyyy').format(eventDate);
    final timeStr = '${eventTime.hour.toString().padLeft(2, '0')}.${eventTime.minute.toString().padLeft(2, '0')} ${eventTime.hour < 12 ? 'am' : 'pm'}';

    // Build entries list
    String entriesHtml = '';
    for (var entry in groupEntries) {
      String personDisplay = '';
      if (entry['persons'] != null) {
        List<dynamic> personsList = entry['persons'] as List;
        List<String> names = [];
        for (var person in personsList) {
          String name = person['name'] ?? '';
          if (name.isNotEmpty) {
            names.add(name);
          }
        }
        personDisplay = names.join(', ');
      }

      String villageName = entry['village_name'] ?? '';
      String livingPlace = entry['living_place'] ?? '';

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
        <div class="person-name">$personDisplay</div>
        ${villageName.isNotEmpty ? '<div class="village-info">$villageName</div>' : ''}
        ${livingPlace.isNotEmpty ? '<div class="village-info">$livingPlace</div>' : ''}
        <div class="amount-label">தொகை</div>
        <div class="entry-amount">₹$amount</div>
      </div>
      <div class="divider"></div>
    ''';
    }

    // Get first entry's details for footer
    String footerName = '';
    String footerVillage = '';
    String footerPhone = '';

    if (groupEntries.isNotEmpty) {
      var firstEntry = groupEntries.first;
      if (firstEntry['persons'] != null && (firstEntry['persons'] as List).isNotEmpty) {
        var person = (firstEntry['persons'] as List).first;
        footerName = '${person['init'] ?? ''}.${person['name'] ?? ''}';
      }
      footerVillage = firstEntry['village_name'] ?? '';
      footerPhone = firstEntry['phone'] ?? '';
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
    
    .company-name {
      font-size: 22px;
      font-weight: bold;
      margin-bottom: 5px;
      color: #000;
    }
    
    .company-phone {
      font-size: 14px;
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
      border: 2px solid black;
      padding: 8px;
    }
    
    .left-section {
      text-align: left;
    }
    
    .right-section {
      text-align: right;
      font-weight: bold;
    }
    
    .entry-block {
      margin: 10px 0;
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
      margin: 15px 0;
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
      margin: 15px 0;
      font-size: 16px;
      font-weight: bold;
      background-color: #f5f5f5;
    }
    
    .footer {
      margin-top: 15px;
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
  <div class="header">Group Check / Advance / UPI Receipt</div>
  
  <div class="company-name">பேச்சி மொய் டெக்</div>
  <div class="company-phone">9043606296, 9047556443</div>
  
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
    <div class="total-amount">₹$displayTotal</div>
  </div>
  
  <div class="payment-method-box">Check / Advance / UPI</div>
  
  <div class="divider"></div>
  
  <div class="footer">
    <div class="thanks">தங்கள் வருகைக்கு நன்றி!</div>
    <div class="with-love">அன்புடன்...</div>
    ${footerName.isNotEmpty ? '<div class="footer-name">$footerName</div>' : ''}
    ${footerVillage.isNotEmpty ? '<div class="village-info">$footerVillage</div>' : ''}
    ${footerPhone.isNotEmpty ? '<div class="village-info">$footerPhone</div>' : ''}
  </div>
</body>
</html>
''';
  }
}

