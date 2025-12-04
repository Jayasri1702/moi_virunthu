import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';

class WithdrawalReceiptGenerator {
  static const platform = MethodChannel('com.example.moi_virunthu/whatsapp');
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

  // Generate cash withdrawal receipt
  static Future<File?> generateWithdrawalReceipt({
    required BuildContext context,
    required String operatorName,
    required DateTime withdrawalDate,
    required TimeOfDay withdrawalTime,
    required String requestedBy,
    required num amount,
    required Map<int, int> denominations,
    String? reason,
    bool showDialog = true,
  }) async {
    try {
      final logoBase64 = await _getLogoBase64();
      final fontBase64 = await _getFontBase64();
      final htmlContent = _generateWithdrawalHtml(
        operatorName: operatorName,
        withdrawalDate: withdrawalDate,
        withdrawalTime: withdrawalTime,
        requestedBy: requestedBy,
        amount: amount,
        denominations: denominations,
        reason: reason,
logoBase64: logoBase64,  // ADD THIS
fontBase64: fontBase64,  // ADD THIS
      );

      final output = await getTemporaryDirectory();
      final timestamp = DateTime
          .now()
          .millisecondsSinceEpoch;
      final fileName = 'withdrawal_receipt_$timestamp.pdf';
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
              final pdfHeight = (height / 302) *
                  pdfWidth; // Maintain aspect ratio

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
              print('Withdrawal receipt PDF generated: $filePath');
            }
          } catch (e) {
            print('Error generating withdrawal receipt PDF: $e');
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

      // Show share dialog if PDF was generated successfully and showDialog is true
      final finalFile = generatedFile;
      if (finalFile != null && context.mounted && showDialog) {
        _showShareDialog(context, finalFile);
      }

      return generatedFile;
    } catch (e) {
      print('Error in generateWithdrawalReceipt: $e');
      return null;
    }
  }

  // Send withdrawal receipt to WhatsApp using MethodChannel
  static Future<void> sendToWhatsApp({
    required BuildContext context,
    required String phoneNumber,
    required String operatorName,
    required DateTime withdrawalDate,
    required TimeOfDay withdrawalTime,
    required String requestedBy,
    required num amount,
    required Map<int, int> denominations,
    String? reason,
  }) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
        const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Generate the receipt PDF
      final receiptFile = await generateWithdrawalReceipt(
        context: context,
        operatorName: operatorName,
        withdrawalDate: withdrawalDate,
        withdrawalTime: withdrawalTime,
        requestedBy: requestedBy,
        amount: amount,
        denominations: denominations,
        reason: reason,
        showDialog: false,
      );

      // Close loading indicator
      if (context.mounted) {
        Navigator.pop(context);
      }

      if (receiptFile == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to generate receipt'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Format phone number for WhatsApp
      String cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');

      // Add country code if not present (assuming India +91)
      if (cleanPhone.length == 10) {
        cleanPhone = '91$cleanPhone';
      } else if (cleanPhone.startsWith('+')) {
        cleanPhone = cleanPhone.substring(1);
      }

      // Create WhatsApp message
      final whatsappMessage = 'Cash Withdrawal Receipt\n\n'
          '💰 Amount: ₹${amount.round()}\n'
          '👤 Requested by: $requestedBy\n'
          '📅 Date: ${DateFormat('dd-MM-yyyy').format(withdrawalDate)}\n'
          '⏰ Time: ${withdrawalTime.hour.toString().padLeft(
          2, '0')}:${withdrawalTime.minute.toString().padLeft(2, '0')}\n\n'
          '${reason != null && reason.isNotEmpty ? 'Reason: $reason\n\n' : ''}'
          'Receipt attached below.\n\n'
          'நன்றி!\n'
          'பேச்சி மொய் டெக்';

      // Send via WhatsApp using MethodChannel
      try {
        final result = await platform.invokeMethod('sendToWhatsApp', {
          'phone': cleanPhone,
          'message': whatsappMessage,
          'filePath': receiptFile.path,
        });

        if (context.mounted) {
          if (result == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Opening WhatsApp for $requestedBy'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'WhatsApp not installed. Please install WhatsApp.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (e) {
        print('Error invoking platform method: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error opening WhatsApp: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      print('Error sending to WhatsApp: $e');

      // Close loading indicator if still open
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // Show share dialog
  static void _showShareDialog(BuildContext context, File pdfFile) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('Receipt Generated'),
            content: const Text(
                'Withdrawal receipt has been generated successfully!'),
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
                    subject: 'Cash Withdrawal Receipt',
                  );
                },
                child: const Text('Share'),
              ),
            ],
          ),
    );
  }

  // HTML template for withdrawal receipt
  static String _generateWithdrawalHtml({
    required String operatorName,
    required DateTime withdrawalDate,
    required TimeOfDay withdrawalTime,
    required String requestedBy,
    required num amount,
    required Map<int, int> denominations,
    String? reason,
required String logoBase64,  // ADD THIS
required String fontBase64,  // ADD THIS
  }) {
    final dateStr = DateFormat('dd-MM-yyyy').format(withdrawalDate);

    // Convert to 12-hour format with space before AM/PM
    int hour = withdrawalTime.hour;
    int minute = withdrawalTime.minute;
    String period = hour >= 12 ? 'pm' : 'am';
    int displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final timeStr = '${displayHour.toString().padLeft(2, '0')}.${minute.toString().padLeft(2, '0')} $period';

    // Use proper operator name, fallback to "Operator" if empty or null
    final displayOperatorName = (operatorName.isEmpty ||
        operatorName == 'Unknown')
        ? 'Operator'
        : operatorName;

    // Build denomination table
    String denomTable = '';
    List<int> denomKeys = [500, 200, 100, 50, 20, 10, 5, 1];

    for (int denom in denomKeys) {
      int count = denominations[denom] ?? 0;
      if (count > 0) {
        int total = denom * count;
        denomTable += '''
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
      margin-bottom: 15px;
    }
    
    .outer-box {
      border: 3px solid black;
      padding: 0;
    }
    
    .company-name {
      font-size: 22px;
      font-weight: bold;
      margin-bottom: 5px;
      color: #000;
      padding: 10px 10px 5px 10px;
    }
    
    .company-phone {
      font-size: 14px;
      margin-bottom: 10px;
      color: #000;
      padding: 0 10px 10px 10px;
    }
    
    .divider {
      border-top: 2px solid black;
      margin: 0;
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
    
    .info-box {
      border-bottom: 2px solid black;
      padding: 12px;
      text-align: center;
    }
    
    .info-label {
      font-size: 14px;
      font-weight: bold;
      margin-bottom: 4px;
    }
    
    .info-value {
      font-size: 16px;
      margin-bottom: 8px;
    }
    
    .amount-box {
      background-color: #f5f5f5;
      border-bottom: 2px solid black;
      padding: 12px;
    }
    
    .amount-label {
      font-size: 16px;
      font-weight: bold;
    }
    
    .amount {
      font-size: 28px;
      font-weight: bold;
      color: #d32f2f;
      margin: 8px 0;
    }
    
    .section-title {
      font-size: 18px;
      font-weight: bold;
      padding: 8px;
      background-color: #f5f5f5;
      border-bottom: 2px solid black;
      text-align: center;
    }
    .logo-header {
  display: flex;
  align-items: center;
  padding: 8px;
  gap: 10px;
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
  font-family: 'Altroned', sans-serif;
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
    
    table {
      width: 100%;
      border-collapse: collapse;
      border-bottom: 2px solid black;
    }
    
    .reason-box {
      border-bottom: 2px solid black;
      padding: 10px;
      text-align: left;
      min-height: 60px;
    }
    
    .reason-title {
      font-weight: bold;
      font-size: 14px;
      margin-bottom: 5px;
    }
    
    .reason-text {
      font-size: 13px;
      line-height: 1.4;
    }
    
    .footer {
      padding: 10px;
      font-size: 14px;
    }
    
    .footer-text {
      margin: 6px 0;
      font-weight: bold;
    }
    
    .footer-signature {
      display: flex;
      justify-content: space-between;
      padding-top: 10px;
    }
    
    .footer-left {
      text-align: left;
      flex: 1;
    }
    
    .footer-right {
      text-align: right;
      flex: 1;
      border-left: 2px solid black;
      padding-left: 10px;
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
        <div>$displayOperatorName</div>
      </div>
    </div>
    
    <div class="info-box">
      <div class="info-label">Requested by: $requestedBy</div>
      <div class="info-label">Requested Amt: ₹${amount.round()}</div>
    </div>
    
    <div class="section-title">நோட்டு விபரம்</div>
    <table>
      $denomTable
    </table>
    
    ${reason != null && reason.isNotEmpty ? '''
    <div class="reason-box">
      <div class="reason-title">Reason:</div>
      <div class="reason-text">$reason</div>
    </div>
    ''' : ''}
    
    <div class="footer">
      <div class="footer-signature">
        <div class="footer-left">
          <div class="info-label">Hi Tech Moi</div>
        </div>
        <div class="footer-right">
          <div class="info-label">Amt Received by</div>
          <div class="info-value">$requestedBy</div>
        </div>
      </div>
    </div>
  </div>
</body>
</html>
''';
  }
}