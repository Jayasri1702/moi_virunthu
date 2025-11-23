import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:share_plus/share_plus.dart';

class DenominationReceiptGenerator {
  // Generate final denomination receipt
  static Future<File?> generateDenominationReceipt({
    required BuildContext context,
    required String customerName,
    required String eventTypeName,
    required String venue,
    required String city,
    required String contactNumber,
    required DateTime eventDate,
    required Map<int, int> denominationCounts,
    required Map<int, int> denominationAmounts,
    required int grandTotal,
    required double totalCashCollected,
    required double computedTotal,
    required double totalWithdrawals,
    required double verupaadu,
    required int peopleCount,
    required double totalOthersAmount, // NEW PARAMETER - sum of all OTHERS payment method entries
  }) async {
    try {
      final htmlContent = _generateDenominationHtml(
        customerName: customerName,
        eventTypeName: eventTypeName,
        venue: venue,
        city: city,
        contactNumber: contactNumber,
        eventDate: eventDate,
        denominationCounts: denominationCounts,
        denominationAmounts: denominationAmounts,
        grandTotal: grandTotal,
        totalCashCollected: totalCashCollected,
        computedTotal: computedTotal,
        totalWithdrawals: totalWithdrawals,
        verupaadu: verupaadu,
        peopleCount: peopleCount,
        totalOthersAmount: totalOthersAmount, // PASS THE NEW PARAMETER
      );

      final output = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'denomination_receipt_$timestamp.pdf';
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
          initialSize: Size(302, 800), // ADD THIS LINE
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
              print('Denomination receipt PDF generated: $filePath');
            }
          } catch (e) {
            print('Error generating denomination receipt PDF: $e');
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

      // Show share dialog if PDF was generated successfully
      final finalFile = generatedFile;
      if (finalFile != null && context.mounted) {
        _showShareDialog(context, finalFile);
      }

      return generatedFile;
    } catch (e) {
      print('Error in generateDenominationReceipt: $e');
      return null;
    }
  }

  // Show share dialog
  static void _showShareDialog(BuildContext context, File pdfFile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Receipt Generated'),
        content: const Text('Denomination receipt has been generated successfully!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await Share.shareXFiles(
                [XFile(pdfFile.path)],
                subject: 'Final Denomination Receipt',
              );
            },
            child: const Text('Share'),
          ),
        ],
      ),
    );
  }

  // Format amount with commas
  static String _formatAmount(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
    );
  }

  // HTML template for denomination receipt
  static String _generateDenominationHtml({
    required String customerName,
    required String eventTypeName,
    required String venue,
    required String city,
    required String contactNumber,
    required DateTime eventDate,
    required Map<int, int> denominationCounts,
    required Map<int, int> denominationAmounts,
    required int grandTotal,
    required double totalCashCollected,
    required double computedTotal,
    required double totalWithdrawals,
    required double verupaadu,
    required int peopleCount,
    required double totalOthersAmount, // NEW PARAMETER
  }) {
    final dateStr = DateFormat('dd-MM-yyyy').format(eventDate);

    // Build denomination table rows - only include non-zero denominations
    String denominationRows = '';
    List<int> denomKeys = [500, 200, 100, 50, 20, 10];

    for (int denom in denomKeys) {
      int count = denominationCounts[denom] ?? 0;
      int amount = denominationAmounts[denom] ?? 0;

      if (count > 0) {
        denominationRows += '''
          <tr>
            <td style="border: 2px solid black; border-top: none; padding: 4px; text-align: center; font-weight: bold; font-size: 14px;">$denom</td>
            <td style="border: 2px solid black; border-top: none; padding: 4px; text-align: center; font-weight: bold; font-size: 14px;">$count</td>
            <td style="border: 2px solid black; border-top: none; padding: 4px; text-align: center; font-weight: bold; font-size: 14px;">${_formatAmount(amount)}</td>
          </tr>
        ''';
      }
    }

    // Handle coins (5 and 1) separately
    int coins5 = denominationCounts[5] ?? 0;
    int coins1 = denominationCounts[1] ?? 0;
    int totalCoins = coins5 + coins1;
    int totalCoinsAmount = (coins5 * 5) + coins1;

    if (totalCoins > 0) {
      denominationRows += '''
        <tr>
          <td style="border: 2px solid black; border-top: none; padding: 4px; text-align: center; font-weight: bold; font-size: 14px;">Coins</td>
          <td style="border: 2px solid black; border-top: none; padding: 4px; text-align: center; font-weight: bold; font-size: 14px;">$totalCoins</td>
          <td style="border: 2px solid black; border-top: none; padding: 4px; text-align: center; font-weight: bold; font-size: 14px;">${_formatAmount(totalCoinsAmount)}</td>
        </tr>
      ''';
    }

    // UPDATED: Use the total of OTHERS payment method entries directly
    double checkAdvanceUPI = totalOthersAmount;

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
      text-align: center;
      background: white;
    }
    
    .company-box {
      border: 2px solid black;
      padding: 8px 6px;
      margin-bottom: 0;
    }
    
    .company-name {
      font-size: 20px;
      font-weight: bold;
      margin-bottom: 4px;
      color: #000;
    }
    
    .company-phone {
      font-size: 13px;
      color: #000;
    }
    
    .customer-info {
      margin: 0;
      border: 2px solid black;
      border-top: none;
      padding: 6px;
      text-align: center;
      line-height: 1.5;
    }
    
    .info-line {
      font-size: 14px;
      margin: 1px 0;
      font-weight: bold;
    }
    
    .section-title {
      font-size: 14px;
      font-weight: bold;
      margin: 0;
      padding: 5px;
      background-color: white;
      border: 2px solid black;
      border-top: none;
    }
    
    table {
      width: 100%;
      border-collapse: collapse;
      margin: 0;
    }
    
    .total-row {
      background-color: #f5f5f5;
      font-weight: bold;
    }
    
    .header {
      background-color: #1976D2;
      color: white;
      font-size: 18px;
      font-weight: bold;
      padding: 10px;
      margin-bottom: 10px;
    }
    
    .summary-item {
      border: 2px solid black;
      border-top: none;
      padding: 5px 6px;
      display: flex;
      justify-content: space-between;
      font-size: 13px;
    }
    
    .summary-label {
      font-weight: 600;
      text-align: left;
    }
    
    .summary-value {
      font-weight: bold;
      text-align: right;
    }
    
    .highlight {
      background-color: #fff3e0;
    }
    
    .highlight-value {
      color: #f57c00;
    }
    
    .footer {
      margin-top: 10px;
      font-size: 11px;
      padding-top: 8px;
    }
    
    .signature-section {
      display: flex;
      justify-content: space-between;
      margin-top: 25px;
      padding-top: 6px;
      font-size: 11px;
    }
    
    .signature-box {
      text-align: center;
      width: 45%;
    }
  </style>
</head>
<body>
<div class="header">Final Denomination Receipt</div>
  <div class="company-box">
    <div class="company-name">பேச்சி மொய் டெக்</div>
  </div>
  
  <div class="customer-info">
    <div class="info-line">$customerName</div>
    <div class="info-line">$eventTypeName</div>
    <div class="info-line">$venue</div>
    <div class="info-line">$contactNumber</div>
    <div class="info-line">நாள் : $dateStr</div>
  </div>
  
  <div class="section-title">DENOMINATION</div>
  
  <table>
    $denominationRows
    <tr class="total-row">
      <td colspan="2" style="border: 2px solid black; border-top: none; padding: 5px; text-align: center; font-size: 13px;">
        ருபாய் கைஇருப்பு
      </td>
      <td style="border: 2px solid black; border-top: none; padding: 5px; text-align: center; font-size: 13px;">${_formatAmount(grandTotal)}</td>
    </tr>
  </table>
  
  <div class="summary-item">
    <span class="summary-label">கம்ப்யூட்டர் தொகை</span>
    <span class="summary-value">${_formatAmount(computedTotal.round())}</span>
  </div>
  
  <div class="summary-item highlight">
    <span class="summary-label">வேருபாடு</span>
    <span class="summary-value highlight-value">${_formatAmount(verupaadu.abs().round())}</span>
  </div>
  
  <div class="summary-item">
    <span class="summary-label">Total Withdrawals</span>
    <span class="summary-value">${_formatAmount(totalWithdrawals.round())}</span>
  </div>
  
  <div class="summary-item">
    <span class="summary-label">Check / Advance / UPI</span>
    <span class="summary-value">${_formatAmount(checkAdvanceUPI.round())}</span>
  </div>
  
  <div class="summary-item" style="border-bottom: 2px solid black;">
    <span class="summary-label">மொய்<br>செய்தவர்களின்<br>எண்ணிக்கை</span>
    <span class="summary-value">$peopleCount</span>
  </div>
  
  <div class="footer">
    <div class="signature-section">
      <div class="signature-box">
        <div>For Petchi Moi Tech</div>
        <div style="margin-top: 30px; border-top: 1px solid black; padding-top: 2px;"></div>
      </div>
      <div class="signature-box">
        <div>Amt received by<br>Customer</div>
        <div style="margin-top: 30px; border-top: 1px solid black; padding-top: 2px;"></div>
      </div>
    </div>
  </div>
</body>
</html>
''';
  }
}