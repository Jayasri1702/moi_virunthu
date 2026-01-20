import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

class DenominationReceiptGenerator {
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
    required double totalOthersAmount,
    // NEW PARAMETERS for withdrawal and exchange counts
    required Map<int, int> totalWithdrawalCounts,
    required Map<int, int> totalExchangeCounts,

  }) async {
    try {
      final logoBase64 = await _getLogoBase64();
      final fontBase64 = await _getFontBase64();
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
        totalOthersAmount: totalOthersAmount,
        totalWithdrawalCounts: totalWithdrawalCounts,
        totalExchangeCounts: totalExchangeCounts,
        logoBase64: logoBase64,
        fontBase64: fontBase64,
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

      return generatedFile;
    } catch (e) {
      print('Error in generateDenominationReceipt: $e');
      return null;
    }
  }

  // ✅ NEW METHOD: Generate denomination receipt with image for thermal printing
  static Future<Map<String, dynamic>?> generateDenominationReceiptWithImage({
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
    required double totalOthersAmount,
    required Map<int, int> totalWithdrawalCounts,
    required Map<int, int> totalExchangeCounts,
  }) async {
    try {
      final logoBase64 = await _getLogoBase64();
      final fontBase64 = await _getFontBase64();

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
        totalOthersAmount: totalOthersAmount,
        totalWithdrawalCounts: totalWithdrawalCounts,
        totalExchangeCounts: totalExchangeCounts,
        logoBase64: logoBase64,
        fontBase64: fontBase64,
      );

      final output = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'denomination_receipt_$timestamp.pdf';
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
              print('Denomination receipt generated: PDF + Image');
            }
          } catch (e) {
            print('Error generating denomination receipt: $e');
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
      print('Error in generateDenominationReceiptWithImage: $e');
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
    required double totalOthersAmount,
    required Map<int, int> totalWithdrawalCounts,
    required Map<int, int> totalExchangeCounts,
    required String logoBase64,
    required String fontBase64,
  }) {
    // ✅ FIXED: Use current date/time for receipt generation
    final eventDateStr = DateFormat('dd-MM-yyyy').format(eventDate);

    // Build denomination table rows
    String denominationRows = '';
    List<int> denomKeys = [500, 200, 100, 50, 20, 10];

    for (int denom in denomKeys) {
      int count = denominationCounts[denom] ?? 0;
      int exchangeCount = totalExchangeCounts[denom] ?? 0;
      int withdrawalCount = totalWithdrawalCounts[denom] ?? 0;

      int finalCount = count + exchangeCount - withdrawalCount;
      int finalAmount = finalCount * denom;

      if (count > 0 || exchangeCount != 0 || withdrawalCount > 0) {
        denominationRows += '''
    <tr>
      <td style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold;">$denom</td>
      <td style="border: 2px solid black; padding: 4px; text-align: center;">x</td>
      <td style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold;">$finalCount</td>
      <td style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold;">$finalAmount</td>
    </tr>
  ''';
      }
    }

    // Handle coins
    int coins5 = denominationCounts[5] ?? 0;
    int coins1 = denominationCounts[1] ?? 0;
    int exchange5 = totalExchangeCounts[5] ?? 0;
    int exchange1 = totalExchangeCounts[1] ?? 0;
    int withdrawal5 = totalWithdrawalCounts[5] ?? 0;
    int withdrawal1 = totalWithdrawalCounts[1] ?? 0;

    int totalCoins = coins5 + coins1 + exchange5 + exchange1 - withdrawal5 - withdrawal1;
    int totalCoinsAmount = (coins5 * 5) + coins1 + (exchange5 * 5) + exchange1 - (withdrawal5 * 5) - withdrawal1;

    if (totalCoins > 0 || (coins5 + coins1) > 0) {
      denominationRows += '''
      <tr>
        <td style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold;">Coins</td>
        <td style="border: 2px solid black; padding: 4px; text-align: center;">x</td>
        <td style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold;">$totalCoins</td>
        <td style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold;">$totalCoinsAmount</td>
      </tr>
    ''';
    }

    int finalBalance = grandTotal - totalWithdrawals.round();

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
  
  .customer-info {
    padding: 8px;
    text-align: center;
    line-height: 1.5;
    border-bottom: 2px solid black;
    font-weight: 700;
  }
  
  .info-line {
    font-size: 14px;
    margin: 2px 0;
    font-weight: 700;
  }
  
  .section-title {
    font-size: 16px;
    font-weight: 700;
    padding: 8px;
    background-color: white;
    border-bottom: 2px solid black;
  }
  
  table {
    width: 100%;
    border-collapse: collapse;
    margin: 0;
    font-weight: 700;
  }
  
  td {
    font-weight: 700;
  }
  
  .summary-item {
    border-bottom: 2px solid black;
    padding: 6px 8px;
    display: flex;
    justify-content: space-between;
    font-size: 14px;
    font-weight: 700;
  }
  
  .summary-label {
    font-weight: 700;
    text-align: left;
  }
  
  .summary-value {
    font-weight: 700;
    text-align: right;
  }
  
  .highlight {
    background-color: #fff3e0;
  }
  
  .highlight-value {
    color: #f57c00;
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
  
  .village-info {
    font-size: 14px;
    font-weight: 700;
    margin: 4px 0;
    word-wrap: break-word;
    line-height: 1.3;
  }
  
  .phone {
    font-size: 14px;
    font-weight: 700;
    margin: 6px 0;
  }
  
  .signature-section {
  padding: 8px;
}

.signature-row {
  display: flex;
  justify-content: space-between;
  margin-top: 8px;
}

.signature-box {
  width: 45%;
  text-align: center;
  padding: 5px;
  min-height: 80px;
  display: flex;
  flex-direction: column;
  justify-content: flex-end;
}

.signature-label {
  font-size: 12px;
  font-weight: 700;
  margin: 2px 0;
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
    
    <div class="customer-info">
  <div class="info-line">$customerName</div>
  <div class="info-line">$eventTypeName</div>
  <div class="info-line">$venue</div>
  <div class="info-line">$city</div>
  <div class="info-line">$contactNumber</div>
  <div class="info-line">நாள் : $eventDateStr</div>
</div>
    
    <div class="section-title">நோட்டு விபரம்</div>
    
    <table>
      $denominationRows
      <tr style="background-color: #e8f5e9;">
        <td colspan="3" style="border: 2px solid black; padding: 6px; text-align: center; font-weight: bold;">ரூபாய் கையிருப்பு</td>
        <td style="border: 2px solid black; padding: 6px; text-align: center; font-weight: bold;">$finalBalance</td>
      </tr>
    </table>
    
    <div class="summary-item">
      <span class="summary-label">பெறப்பட்ட தொகை</span>
      <span class="summary-value">${totalCashCollected.round()}</span>
    </div>
    
    <div class="summary-item">
      <span class="summary-label">Total Withdrawals</span>
      <span class="summary-value">${totalWithdrawals.round()}</span>
    </div>
    
    <div class="summary-item">
      <span class="summary-label">Cheque / Advance / UPI</span>
      <span class="summary-value">${totalOthersAmount.round()}</span>
    </div>
    
    <div class="summary-item">
      <span class="summary-label">கம்ப்யூட்டர் தொகை</span>
      <span class="summary-value">${computedTotal.round()}</span>
    </div>
    
    <div class="summary-item highlight">
      <span class="summary-label">வேறுபாடு</span>
      <span class="summary-value highlight-value">${verupaadu.abs().round()}</span>
    </div>
    
    <div class="summary-item">
      <span class="summary-label">மொய் செய்தவர்களின் எண்ணிக்கை</span>
      <span class="summary-value">$peopleCount</span>
    </div>
    
    <div class="divider"></div>

<div class="signature-section">
  <div class="signature-row">
    <div class="signature-box">
      <div class="signature-label">ஹை-டெக் மொய்</div>
      <div class="signature-label">கையொப்பம்</div>
    </div>
    <div class="signature-box">
      <div class="signature-label">வாடிக்கையாளர்</div>
      <div class="signature-label">கையொப்பம்</div>
    </div>
  </div>
</div>
  </div>
</body>
</html>
''';
  }
}