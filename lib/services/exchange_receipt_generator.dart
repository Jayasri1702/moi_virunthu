import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:share_plus/share_plus.dart';

class ExchangeReceiptGenerator {
  // Generate exchange denomination receipt
  static Future<File?> generateExchangeReceipt({
    required BuildContext context,
    required String operatorName,
    required DateTime exchangeDate,
    required TimeOfDay exchangeTime,
    required Map<int, int> receivedDenominations,
    required Map<int, int> returnedDenominations,
  }) async {
    try {
      final htmlContent = _generateExchangeHtml(
        operatorName: operatorName,
        exchangeDate: exchangeDate,
        exchangeTime: exchangeTime,
        receivedDenominations: receivedDenominations,
        returnedDenominations: returnedDenominations,
      );

      final output = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'exchange_receipt_$timestamp.pdf';
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
              print('Exchange receipt PDF generated: $filePath');
            }
          } catch (e) {
            print('Error generating exchange receipt PDF: $e');
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
      print('Error in generateExchangeReceipt: $e');
      return null;
    }
  }

  // Show share dialog
  static void _showShareDialog(BuildContext context, File pdfFile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Receipt Generated'),
        content: const Text('Exchange receipt has been generated successfully!'),
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
                subject: 'Exchange Receipt',
              );
            },
            child: const Text('Share'),
          ),
        ],
      ),
    );
  }

  // HTML template for exchange receipt
  static String _generateExchangeHtml({
    required String operatorName,
    required DateTime exchangeDate,
    required TimeOfDay exchangeTime,
    required Map<int, int> receivedDenominations,
    required Map<int, int> returnedDenominations,
  }) {
    final dateStr = DateFormat('dd-MM-yyyy').format(exchangeDate);
    final timeStr = '${exchangeTime.hour.toString().padLeft(2, '0')}.${exchangeTime.minute.toString().padLeft(2, '0')} ${exchangeTime.hour < 12 ? 'am' : 'pm'}';

    // Calculate received amount
    int receivedTotal = 0;
    String receivedTable = '';
    List<int> denomKeys = [500, 200, 100, 50, 20, 10, 5, 1];

    for (int denom in denomKeys) {
      int count = receivedDenominations[denom] ?? 0;
      if (count > 0) {
        int total = denom * count;
        receivedTotal += total;
        receivedTable += '''
          <tr>
            <td style="border: 2px solid black; padding: 6px; text-align: center; font-weight: bold; font-size: 16px;">$denom</td>
            <td style="border: 2px solid black; padding: 6px; text-align: center; font-size: 16px; font-weight: bold;">x</td>
            <td style="border: 2px solid black; padding: 6px; text-align: center; font-weight: bold; font-size: 16px;">$count</td>
            <td style="border: 2px solid black; padding: 6px; text-align: center; font-weight: bold; font-size: 16px;">$total</td>
          </tr>
        ''';
      }
    }

    // Calculate returned amount
    int returnedTotal = 0;
    String returnedTable = '';

    for (int denom in denomKeys) {
      int count = returnedDenominations[denom] ?? 0;
      if (count > 0) {
        int total = denom * count;
        returnedTotal += total;
        returnedTable += '''
          <tr>
            <td style="border: 2px solid black; padding: 6px; text-align: center; font-weight: bold; font-size: 16px;">$denom</td>
            <td style="border: 2px solid black; padding: 6px; text-align: center; font-size: 16px; font-weight: bold;">x</td>
            <td style="border: 2px solid black; padding: 6px; text-align: center; font-weight: bold; font-size: 16px;">$count</td>
            <td style="border: 2px solid black; padding: 6px; text-align: center; font-weight: bold; font-size: 16px;">$total</td>
          </tr>
        ''';
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
    
    .section-title {
      font-size: 18px;
      font-weight: bold;
      margin: 15px 0 10px 0;
      padding: 8px;
      background-color: #f5f5f5;
      border: 2px solid black;
    }
    
    .received-title {
      background-color: #e3f2fd;
      color: #1976D2;
    }
    
    .returned-title {
      background-color: #e8f5e9;
      color: #388E3C;
    }
    
    table {
      width: 100%;
      border-collapse: collapse;
      margin: 10px 0;
    }
    
    .total-row {
      background-color: #f5f5f5;
      font-weight: bold;
    }
    
    .footer {
      margin-top: 15px;
      font-size: 14px;
      border-top: 2px solid black;
      padding-top: 10px;
    }
    
    .thanks {
      margin: 6px 0;
      font-weight: bold;
    }
  </style>
</head>
<body>
  <div class="header">Exchange Denomination Receipt</div>
  
  <div class="company-name">பேச்சி மொய் டெக்</div>
  <div class="company-phone">9043606296, 9047556443</div>
  
  <div class="divider"></div>
  
  <div class="date-time-row">
    <div class="left-section">
      <div>$dateStr</div>
      <div>$timeStr</div>
    </div>
    <div class="right-section">
      <div>Operator</div>
      <div>$operatorName</div>
    </div>
  </div>
  
  <div class="section-title received-title">Received</div>
  <table>
    $receivedTable
    <tr class="total-row">
      <td colspan="3" style="border: 2px solid black; padding: 8px; text-align: center; font-size: 16px;">Total Received</td>
      <td style="border: 2px solid black; padding: 8px; text-align: center; font-size: 16px;">₹$receivedTotal</td>
    </tr>
  </table>
  
  <div class="divider"></div>
  
  <div class="section-title returned-title">Returned</div>
  <table>
    $returnedTable
    <tr class="total-row">
      <td colspan="3" style="border: 2px solid black; padding: 8px; text-align: center; font-size: 16px;">Total Returned</td>
      <td style="border: 2px solid black; padding: 8px; text-align: center; font-size: 16px;">₹$returnedTotal</td>
    </tr>
  </table>
  
  <div class="footer">
    <div class="thanks">நன்றி! (Thank You)</div>
  </div>
</body>
</html>
''';
  }
}